# =============================================================================
#  PashuRakshak - build and publish installable APKs into /dist
# =============================================================================
#  Usage (from the repository root):
#      .\build-dist.bat                       # clean build + publish
#      .\build-dist.bat -SkipClean            # faster incremental build
#
#  What this script does:
#    1. Finds a usable JDK (JAVA_HOME, Android Studio's bundled JBR, or PATH).
#    2. Builds signed release APKs for the farmer and vet apps.
#    3. FAILS the build if the APKs are not signed with the project release
#       keystore (a debug-signed "release" APK cannot update a release install
#       and is a common cause of "App not installed" on other phones).
#    4. Publishes exactly TWO standalone APKs per version -- one farmer, one vet
#       -- into dist\v<version>\, together with SHA256SUMS.txt, VERSION_INFO.md
#       and metadata.json for version tracking:
#
#           dist\v<version>\PashuRakshak-Farmer-v<version>.apk
#           dist\v<version>\PashuRakshak-Vet-v<version>.apk
#
#       Each file is the universal build (all ABIs inside), so one file installs
#       on every phone. Per-ABI split APKs are still produced by Gradle but are
#       deliberately not published.
#    5. Refreshes dist\README.md (the version index).
# =============================================================================

[CmdletBinding()]
param(
    [switch]$SkipClean,
    [string]$Notes = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Write-Step([string]$text) {
    Write-Host ""
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Fail([string]$text) {
    Write-Host ""
    Write-Host "ERROR: $text" -ForegroundColor Red
    exit 1
}

# Runs a native executable and captures merged stdout/stderr without letting
# PowerShell 5.1 turn the command's stderr into a terminating error.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$IncludeStderr
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $exitCode = 0
    $lines = @()
    try {
        if ($IncludeStderr) {
            $lines = & $FilePath @Arguments 2>&1
        } else {
            # Capture stdout only. Tools such as apksigner print JVM warnings on
            # stderr; merging them in PowerShell 5.1 drops the real report.
            $lines = & $FilePath @Arguments 2>$null
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = (($lines | ForEach-Object { "$_" }) -join "`n")
    }
}

# ---------------------------------------------------------------------------
# 1. JDK
# ---------------------------------------------------------------------------
function Resolve-JavaHome {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        return $env:JAVA_HOME
    }
    $candidates = @(
        "C:\Program Files\Android\Android Studio\jbr",
        "C:\Program Files\Android\Android Studio\jre",
        (Join-Path $env:LOCALAPPDATA "Programs\Android Studio\jbr"),
        "C:\Program Files\Eclipse Adoptium\jdk-21.0.5.11-hotspot",
        "C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate "bin\java.exe"))) {
            return $candidate
        }
    }
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        return (Split-Path -Parent (Split-Path -Parent $java.Source))
    }
    return $null
}

Write-Step "Locating Java"
$javaHome = Resolve-JavaHome
if (-not $javaHome) {
    Fail "No JDK found. Install Android Studio (bundled JBR) or a JDK 17+ and set JAVA_HOME."
}
$env:JAVA_HOME = $javaHome
$env:PATH = (Join-Path $javaHome "bin") + ";" + $env:PATH
$javaResult = Invoke-Native (Join-Path $javaHome "bin\java.exe") @("-version") -IncludeStderr
$javaVersion = ($javaResult.Output -split "`n")[0]
Write-Host "    JAVA_HOME = $javaHome"
Write-Host "    $javaVersion"

# ---------------------------------------------------------------------------
# 2. Version + signing configuration
# ---------------------------------------------------------------------------
Write-Step "Reading version and signing configuration"

function Get-AppConfig([string]$module) {
    $file = Join-Path $root "$module\build.gradle.kts"
    if (-not (Test-Path $file)) { Fail "Missing $file" }
    $text = Get-Content $file -Raw
    $nameMatch = [regex]::Match($text, 'versionName\s*=\s*"([^"]+)"')
    $codeMatch = [regex]::Match($text, 'versionCode\s*=\s*(\d+)')
    if (-not $nameMatch.Success -or -not $codeMatch.Success) {
        Fail "Could not read versionName/versionCode from $file"
    }
    return [pscustomobject]@{
        Module      = $module
        VersionName = $nameMatch.Groups[1].Value
        VersionCode = [int]$codeMatch.Groups[1].Value
    }
}

$farmerConfig = Get-AppConfig "app-farmer"
$vetConfig = Get-AppConfig "app-vet"
if ($farmerConfig.VersionName -ne $vetConfig.VersionName) {
    Fail "Farmer ($($farmerConfig.VersionName)) and vet ($($vetConfig.VersionName)) versions differ. Keep them in sync."
}
$versionName = $farmerConfig.VersionName

$keystorePropsPath = Join-Path $root "keystore.properties"
if (-not (Test-Path $keystorePropsPath)) {
    Fail "keystore.properties is missing. Copy keystore.properties.example and point it at a valid release keystore."
}
$keystoreProps = @{}
Get-Content $keystorePropsPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $idx = $line.IndexOf("=")
        if ($idx -gt 0) {
            $keystoreProps[$line.Substring(0, $idx).Trim()] = $line.Substring($idx + 1).Trim()
        }
    }
}
$storeFile = $keystoreProps["storeFile"]
if (-not $storeFile) { Fail "storeFile is not set in keystore.properties" }
$keystorePath = Join-Path $root $storeFile
if (-not (Test-Path $keystorePath)) {
    Fail "Release keystore not found at $keystorePath. Create it (see BUILD_SYSTEM.md) before publishing."
}
$storePass = $keystoreProps["storePassword"]
$keyAlias = $keystoreProps["keyAlias"]
$keyPass = $keystoreProps["keyPassword"]

$keytool = Join-Path $javaHome "bin\keytool.exe"
if (-not (Test-Path $keytool)) { Fail "keytool.exe not found in $javaHome\bin" }
$keytoolResult = Invoke-Native $keytool @("-list", "-v", "-keystore", $keystorePath, "-storepass", $storePass, "-alias", $keyAlias)
if ($keytoolResult.ExitCode -ne 0) {
    Fail "Could not open the release keystore. Check keystore.properties passwords.`n$($keytoolResult.Output)"
}
$keytoolOut = $keytoolResult.Output
$sha256Match = [regex]::Match($keytoolOut, "SHA256:\s*([0-9A-Fa-f:]+)")
if (-not $sha256Match.Success) { Fail "Could not read the release certificate SHA-256 fingerprint." }
$expectedCertSha256 = $sha256Match.Groups[1].Value.Replace(":", "").ToLowerInvariant()

Write-Host "    Version    = $versionName (versionCode $($farmerConfig.VersionCode))"
Write-Host "    Keystore   = $keystorePath"
Write-Host "    Cert SHA256= $expectedCertSha256"

# ---------------------------------------------------------------------------
# 3. Android SDK + apksigner
# ---------------------------------------------------------------------------
function Resolve-AndroidSdk {
    $localProps = Join-Path $root "local.properties"
    if (Test-Path $localProps) {
        foreach ($line in Get-Content $localProps) {
            if ($line -match '^\s*sdk\.dir\s*=\s*(.+)$') {
                $path = $Matches[1].Trim().Replace("\\", "\").Replace("\:", ":")
                if (Test-Path $path) { return $path }
            }
        }
    }
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { return $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) { return $env:ANDROID_SDK_ROOT }
    $default = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    if (Test-Path $default) { return $default }
    return $null
}

Write-Step "Locating Android SDK build-tools"
$sdk = Resolve-AndroidSdk
if (-not $sdk) { Fail "Android SDK not found. Install it with Android Studio, or set sdk.dir in local.properties or ANDROID_HOME." }

# local.properties is committed WITHOUT sdk.dir so the repository stays
# portable; Gradle/AGP then take the SDK from these environment variables.
# This is what lets a fresh clone build with no manual setup.
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

# If an older copy of local.properties still points at a path that does not
# exist on this machine, drop that line - otherwise Gradle fails before it ever
# looks at ANDROID_HOME.
$localPropsPath = Join-Path $root "local.properties"
if (Test-Path $localPropsPath) {
    $removedStaleSdkDir = $false
    $keptLines = foreach ($line in Get-Content $localPropsPath) {
        if ($line -match '^\s*sdk\.dir\s*=(.*)$') {
            $value = $Matches[1].Trim().Replace('\:', ':').Replace('\\', '\')
            if ($value -and -not (Test-Path $value)) {
                $removedStaleSdkDir = $true
                continue
            }
        }
        $line
    }
    if ($removedStaleSdkDir) {
        # UTF-8 without BOM: a BOM would corrupt the first properties key.
        [System.IO.File]::WriteAllLines(
            $localPropsPath,
            [string[]]$keptLines,
            (New-Object System.Text.UTF8Encoding($false))
        )
        Write-Host "    removed a stale sdk.dir from local.properties"
    }
}

$buildToolsRoot = Join-Path $sdk "build-tools"
if (-not (Test-Path $buildToolsRoot)) { Fail "No build-tools installed under $buildToolsRoot" }
$buildTools = Get-ChildItem $buildToolsRoot -Directory |
    Sort-Object { [version]($_.Name -replace '[^0-9\.].*$', '') } -Descending |
    Select-Object -First 1
$apksigner = Join-Path $buildTools.FullName "apksigner.bat"
if (-not (Test-Path $apksigner)) { Fail "apksigner.bat not found in $($buildTools.FullName)" }
Write-Host "    Build-tools = $($buildTools.Name)"

# ---------------------------------------------------------------------------
# 4. Build
# ---------------------------------------------------------------------------
Write-Step "Building signed release APKs (this can take a few minutes)"
if (-not $SkipClean) {
    # Do the "clean" ourselves instead of running Gradle's clean task. On Windows
    # the clean task fails hard when a stray process (a leftover Gradle daemon,
    # an antivirus scanner, the IDE) still holds a file in <module>\build, which
    # aborts the whole build. Deleting best-effort with retries is good enough:
    # Gradle rebuilds anything that is missing.
    Write-Host "    removing previous build outputs"
    foreach ($relative in @("core\build", "app-farmer\build", "app-vet\build")) {
        $path = Join-Path $root $relative
        if (-not (Test-Path $path)) { continue }
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            cmd /c "rmdir /s /q `"$path`"" 2>$null
            if (-not (Test-Path $path)) { break }
            Start-Sleep -Seconds 2
        }
        if (Test-Path $path) {
            Write-Host "    warning: could not fully delete $relative (in use); continuing anyway" -ForegroundColor Yellow
        }
    }
}
$gradleArgs = @(
    ":app-farmer:assembleRelease",
    ":app-vet:assembleRelease",
    "-PrequireReleaseSigning=true",
    "--console=plain",
    "--stacktrace"
)
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& (Join-Path $root "gradlew.bat") @gradleArgs
$gradleExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousEap
if ($gradleExitCode -ne 0) {
    Fail "Gradle build failed. Scroll up for the first error."
}

# ---------------------------------------------------------------------------
# 5. Collect, verify and publish
# ---------------------------------------------------------------------------
function Find-StandaloneApk([string]$module) {
    # With ABI splits disabled Gradle emits exactly one release APK per app:
    # <module>-release.apk. Split/universal names are still tolerated in case an
    # older build directory is present.
    $dir = Join-Path $root "$module\build\outputs\apk\release"
    if (-not (Test-Path $dir)) { return $null }
    $exact = Join-Path $dir "$module-release.apk"
    if (Test-Path $exact) { return (Get-Item $exact) }
    foreach ($pattern in @("*-universal-release.apk", "*-release.apk")) {
        $candidate = Get-ChildItem $dir -Filter $pattern -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($candidate) { return $candidate }
    }
    return $null
}

function Get-ApkAbis([string]$apkPath) {
    # A universal APK contains every architecture; a split APK only one.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
    try {
        $abis = @()
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -match '^lib/([^/]+)/.+\.so$') {
                if ($abis -notcontains $Matches[1]) { $abis += $Matches[1] }
            }
        }
        return ($abis | Sort-Object)
    } finally {
        $zip.Dispose()
    }
}

Write-Step "Verifying signatures"
$apps = @(
    [pscustomobject]@{ Key = "farmer"; Title = "Farmer"; Module = "app-farmer"; Package = "com.pashurakshak.app" },
    [pscustomobject]@{ Key = "vet"; Title = "Vet"; Module = "app-vet"; Package = "com.pashurakshak.vet" }
)
$published = @()
foreach ($app in $apps) {
    $apk = Find-StandaloneApk $app.Module
    if (-not $apk) {
        Fail "No release APK found for $($app.Module). Expected $($app.Module)\build\outputs\apk\release\$($app.Module)-release.apk."
    }

    $verifyResult = Invoke-Native $apksigner @("verify", "--verbose", "--print-certs", $apk.FullName)
    $verify = $verifyResult.Output
    if ($verify -notmatch "Verifies") {
        Fail "Signature verification failed for $($apk.Name):`n$verify"
    }
    if ($verify -notmatch "Verified using v2 scheme \(APK Signature Scheme v2\):\s*true") {
        Fail "$($apk.Name) is not APK Signature Scheme v2 signed. Refusing to publish."
    }
    if ($verify -notmatch "Verified using v1 scheme \(JAR signing\):\s*true") {
        Write-Host "    note: v1 (JAR) signature absent - expected with minSdk 24; v2/v3 are used." -ForegroundColor DarkGray
    }
    $certMatch = [regex]::Match($verify, "Signer #1 certificate SHA-256 digest:\s*([0-9A-Fa-f]+)")
    if (-not $certMatch.Success) { Fail "Could not read signer certificate from $($apk.Name)." }
    $actualCert = $certMatch.Groups[1].Value.ToLowerInvariant()
    if ($actualCert -ne $expectedCertSha256) {
        Fail @"
$($apk.Name) is NOT signed with the project release keystore.

  expected: $expectedCertSha256
  actual  : $actualCert

This usually means the release keystore was not found or the build fell back to
the debug key. Installing that APK over an existing release install fails with
"App not installed". Fix keystore.properties and rebuild.
"@
    }
    if ($verify -match "CN=Android Debug") {
        Fail "$($apk.Name) is debug-signed. Refusing to publish it as a release."
    }

    # Sanity-check the manifest: right package, right version.
    $aapt2 = Join-Path $buildTools.FullName "aapt2.exe"
    if (Test-Path $aapt2) {
        $badging = (Invoke-Native $aapt2 @("dump", "badging", $apk.FullName)).Output
        if ($badging -notmatch "package: name='$([regex]::Escape($app.Package))'") {
            Fail "$($apk.Name) does not declare the expected package $($app.Package)."
        }
        if ($badging -notmatch "versionCode='$($farmerConfig.VersionCode)'") {
            Fail "$($apk.Name) does not have versionCode $($farmerConfig.VersionCode)."
        }
    }

    # The published APK must be standalone: it has to carry the native libraries
    # for every phone architecture, otherwise a phone that needs a missing ABI
    # would crash or refuse to install.
    $abis = @(Get-ApkAbis $apk.FullName)
    foreach ($required in @("arm64-v8a", "armeabi-v7a")) {
        if ($abis -notcontains $required) {
            Fail "$($apk.Name) is missing native libraries for $required (found: $($abis -join ', ')). It would not install on every phone."
        }
    }
    if ($abis.Count -lt 2) {
        Fail "$($apk.Name) only contains $($abis -join ', '); a standalone APK must bundle all ABIs."
    }

    $published += [pscustomobject]@{
        App    = $app.Title
        AppKey = $app.Key
        Source = $apk.FullName
        Abis   = $abis
        Size   = $apk.Length
        Sha256 = (Get-FileHash $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    Write-Host "    OK  $($apk.Name)  ($([math]::Round($apk.Length / 1MB, 1)) MB, ABIs: $($abis -join ', '))"
}

if ($published.Count -eq 0) { Fail "No release APKs were produced." }

$versionDir = Join-Path $root "dist\v$versionName"
New-Item -ItemType Directory -Force -Path $versionDir | Out-Null

# Remove stale copies from an earlier run of the same version.
Get-ChildItem $versionDir -Filter "*.apk" -File -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Step "Publishing to dist\v$versionName"
$manifestApks = @()
foreach ($item in $published) {
    # One standalone APK per app per version: PashuRakshak-Farmer-v1.8.apk etc.
    $fileName = "PashuRakshak-$($item.App)-v$versionName.apk"
    $target = Join-Path $versionDir $fileName
    Copy-Item $item.Source $target -Force
    $hash = (Get-FileHash $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestApks += [pscustomobject]@{
        app    = $item.AppKey
        file   = $fileName
        abis   = @($item.Abis)
        sizeMb = [math]::Round($item.Size / 1MB, 1)
        sha256 = $hash
    }
    Write-Host "    $fileName"
}

# SHA256SUMS.txt
$sums = foreach ($apk in $manifestApks) { "$($apk.sha256)  $($apk.file)" }
$sums | Set-Content (Join-Path $versionDir "SHA256SUMS.txt") -Encoding ASCII

# metadata.json (read by dist\README.md generation)
$gitCommit = ""
$gitBranch = ""
try {
    $gitCommit = (Invoke-Native "git" @("rev-parse", "--short", "HEAD")).Output.Trim()
    $gitBranch = (Invoke-Native "git" @("rev-parse", "--abbrev-ref", "HEAD")).Output.Trim()
} catch { }
$buildDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$metadata = [ordered]@{
    versionName = $versionName
    versionCode = $farmerConfig.VersionCode
    buildDate   = $buildDate
    gitCommit   = "$gitCommit"
    gitBranch   = "$gitBranch"
    signedWith  = "PashuRakshak release keystore"
    certSha256  = $expectedCertSha256
    apks        = $manifestApks
}
$jsonText = $metadata | ConvertTo-Json -Depth 4
# UTF-8 without BOM so Node/Python/other tools can parse metadata.json.
[System.IO.File]::WriteAllText(
    (Join-Path $versionDir "metadata.json"),
    $jsonText,
    (New-Object System.Text.UTF8Encoding($false))
)

# Release notes: explicit -Notes wins, otherwise the matching section of
# CHANGELOG.md, otherwise a generic line.
$changelogSection = ""
$changelogPath = Join-Path $root "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $changelogText = Get-Content $changelogPath -Raw
    $pattern = "(?ms)^##\s*\[?v?$([regex]::Escape($versionName))\]?.*?(?=^##\s|\z)"
    $sectionMatch = [regex]::Match($changelogText, $pattern)
    if ($sectionMatch.Success) { $changelogSection = $sectionMatch.Value.Trim() }
}
if (-not $Notes) {
    if ($changelogSection) {
        # Drop the "## [x.y]" heading; the surrounding text already says v1.8.
        $sectionLines = @($changelogSection -split "`r?`n")
        $Notes = ($sectionLines | Select-Object -Skip 1) -join "`n"
        $Notes = $Notes.Trim()
    } else {
        $Notes = "See git history for the changes included in this build."
    }
}

$apkTable = ($manifestApks | ForEach-Object {
    "| $($_.app) | ``$($_.file)`` | $($_.sizeMb) MB | $($_.abis -join ', ') |"
}) -join "`n"

$versionInfo = @"
# PashuRakshak v$versionName

| | |
|---|---|
| Version name | $versionName |
| Version code | $($farmerConfig.VersionCode) |
| Build date | $buildDate |
| Git commit | $gitCommit ($gitBranch) |
| Signing key | PashuRakshak release keystore |
| Signing cert SHA-256 | $expectedCertSha256 |

## APKs in this release

Two standalone APKs: one for the farmer app, one for the vet app. Each one
contains every CPU architecture, so there is nothing to choose and nothing else
to download.

| App | File | Size | ABIs inside |
|-----|------|------|-------------|
$apkTable

## Release notes

$Notes

## Install

1. Copy the ``.apk`` file to the phone (USB, WhatsApp document, Google Drive...).
2. Open it and allow "Install unknown apps" for the app you opened it with.
3. If a previous copy of PashuRakshak is installed with a **different signing
   key** (for example a debug build installed from Android Studio), uninstall
   it first. Updates signed with the same key install straight over the old one.

Never share the app from the phone's "Share app" dialog: that copies the
installed base APK, which can be incomplete. Share this ``.apk`` file instead.

## Verify the download (optional)

``````
certutil -hashfile PashuRakshak-Farmer-v$versionName.apk SHA256
``````

Compare the result with ``SHA256SUMS.txt``.
"@
$versionInfo | Set-Content (Join-Path $versionDir "VERSION_INFO.md") -Encoding UTF8

# ---------------------------------------------------------------------------
# 6. Version index
# ---------------------------------------------------------------------------
Write-Step "Refreshing dist\README.md"
$distRoot = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
$rows = @()
$versionDirs = Get-ChildItem $distRoot -Directory -Filter "v*" |
    Sort-Object { try { [version](($_.Name).Substring(1)) } catch { [version]"0.0" } } -Descending
foreach ($dir in $versionDirs) {
    $metaPath = Join-Path $dir.FullName "metadata.json"
    if (Test-Path $metaPath) {
        try {
            $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
            $apkNames = ($meta.apks | ForEach-Object { $_.app }) -join ", "
            $rows += "| [$($meta.versionName)]($($dir.Name)/VERSION_INFO.md) | $($meta.versionCode) | $($meta.buildDate) | $($meta.gitCommit) | $apkNames |"
        } catch {
            $rows += "| $($dir.Name.Substring(1)) | ? | ? | ? | (metadata unreadable) |"
        }
    } else {
        $apkCount = (Get-ChildItem $dir.FullName -Filter "*.apk" -File -ErrorAction SilentlyContinue).Count
        $rows += "| $($dir.Name.Substring(1)) | ? | ? | ? | $apkCount APK(s) |"
    }
}

$index = @"
# PashuRakshak Android releases

Every folder here is one published version of both Android apps (farmer and
vet), signed with the project release keystore. Each folder holds exactly two
standalone APKs -- ``PashuRakshak-Farmer-v<version>.apk`` and
``PashuRakshak-Vet-v<version>.apk`` -- and each one installs on any phone.
Share those ``.apk`` files; do not share the app installed on a phone.

| Version | Code | Built | Commit | APKs |
|---------|------|-------|--------|------|
$($rows -join "`n")

## Build a new release

``````
.\build-dist.bat
``````

This builds both apps, verifies their signatures and adds a new ``v<version>``
folder with ``VERSION_INFO.md``, ``SHA256SUMS.txt`` and ``metadata.json``.
Bump ``versionCode``/``versionName`` in ``app-farmer/build.gradle.kts`` and
``app-vet/build.gradle.kts`` before publishing a new version.

See ``INSTALL.md`` for installation and troubleshooting.
"@
$index | Set-Content (Join-Path $distRoot "README.md") -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Release v$versionName published" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Get-ChildItem $versionDir | ForEach-Object {
    Write-Host ("  {0,-48} {1,8:N1} MB" -f $_.Name, ($_.Length / 1MB))
}
Write-Host ""
Write-Host "Folder: $versionDir"
