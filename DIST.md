# Building installable APKs (dist)

`dist/` is the distribution folder. Every published version lives in its own
folder, so you can always go back to an older build:

```
dist/
  README.md            <- index of every published version
  INSTALL.md           <- how to install on a phone + troubleshooting
  v1.8/
    PashuRakshak-Farmer-v1.8.apk   <- farmer app, installs on any phone
    PashuRakshak-Vet-v1.8.apk      <- vet app, installs on any phone
    SHA256SUMS.txt     <- checksums
    VERSION_INFO.md    <- version, commit, signer, release notes
    metadata.json      <- machine-readable version record
  v1.7/
    ...
```

Each version folder contains exactly **two APKs** - one for the farmer app and
one for the vet app. Both are standalone "fat" APKs that bundle the native
libraries for every CPU architecture, so there is no per-ABI choice to make.

## Restore the project on a new machine

The private GitHub repository is the backup. A fresh clone rebuilds without any
manual configuration:

```powershell
git clone https://github.com/piyush-kumar499/PashuRakshak.git
cd PashuRakshak
build-dist.bat
```

What is in the repository: all Kotlin source, resources, the Gradle wrapper and
version catalog, the build scripts, the release keystore (`keystore/`) and
`keystore.properties`. You only need a JDK 17+ and the Android SDK - both are
installed with Android Studio, and the scripts locate them automatically.

`local.properties` is committed **without** `sdk.dir` on purpose: `sdk.dir` is a
machine-specific absolute path. The build scripts detect the SDK and export
`ANDROID_HOME`, so the same file works on every machine.

The built APKs are not stored in git (they are ~141 MB); run `build-dist.bat`
to regenerate them. The keystore is included, so rebuilds keep the same
signature and install over existing copies.

## Build a release

Double-click `build-dist.bat` (or run it from a terminal):

```powershell
.\build-dist.bat
```

It will:

1. find a JDK (your `JAVA_HOME`, Android Studio's bundled JBR, or `java` on PATH);
2. build `:app-farmer:assembleRelease` and `:app-vet:assembleRelease` with
   `-PrequireReleaseSigning=true`;
3. verify every APK with `apksigner`:
   - APK Signature Scheme v2 present,
   - signer certificate equals the release keystore's certificate,
   - `versionCode` and package name match the source,
   - native libraries for `arm64-v8a` **and** `armeabi-v7a` are bundled, so the
     same file installs on every phone;
4. copy the APKs to `dist/v<version>/` as `PashuRakshak-Farmer-v<version>.apk`
   and `PashuRakshak-Vet-v<version>.apk`, and write the checksums, version info
   and metadata;
5. refresh the version index in `dist/README.md`.

For a faster incremental build: `.\build-dist.bat -SkipClean`.

## Bump the version

Edit **both** files and keep them in sync:

- `app-farmer/build.gradle.kts` -> `versionCode`, `versionName`
- `app-vet/build.gradle.kts` -> `versionCode`, `versionName`

`versionCode` must increase for every release (Android only accepts an update
when the new code is higher and the signing key is the same). `versionName` is
what appears in the folder name (`dist/v1.8`, `dist/v1.9`, ...).

Add the release notes to `CHANGELOG.md` under `## [<version>]`; the build script
copies that section into `VERSION_INFO.md`.

## Signing

Release APKs are signed with `keystore/pashurakshak-release.jks` as configured
by `keystore.properties` (both files are git-ignored - keep backups!).

The certificate fingerprint is:

```
SHA-256: 4C:22:28:6B:58:B4:CD:E8:E7:FB:BA:74:2B:DF:2F:6F:FD:C7:8C:0D:4D:DD:7D:17:28:84:3D:66:5D:27:6E:E4
```

Keep this keystore safe. If it is lost, future releases get a different
signature and every phone has to uninstall the app before updating. If it is
leaked, anyone can publish updates that Android will accept.

Debug builds (`build-debug.bat`) are signed with the machine's debug key and
must never be distributed: they cannot update a release install.

## "App not installed as package appears to be invalid"

That error appears when the APK you are trying to install is incomplete,
corrupt, or not signed correctly. The usual causes, in order:

1. **You shared the app from the phone's "Share app" menu.** Android copies the
   installed `base.apk`, which for split/bundled installs is only part of the
   app. Share the `.apk` file from `dist/` instead.
2. **The build was signed with a different key** than the installed copy (for
   example a debug build). Uninstall the old copy first.
3. **The file got truncated/corrupted** in transfer (WhatsApp, Bluetooth...).
   Compare the SHA-256 with `SHA256SUMS.txt`.
4. **The APK was modified after signing.** Never run `zipalign`/`apksigner`
   manually on a published APK; the build already aligns native libraries
   before packaging.

The `build-dist.ps1` script verifies every APK before copying it into `dist/`,
so a published file is always properly signed. Install the APKs from `dist/`
and the error will not occur.
