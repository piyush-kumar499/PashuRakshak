# PashuRakshak v1.8

| | |
|---|---|
| Version name | 1.8 |
| Version code | 9 |
| Build date | 2026-11-10 20:14:16 +05:30 |
| Git commit | f318294 (main) |
| Signing key | PashuRakshak release keystore |
| Signing cert SHA-256 | 4c22286b58b4cde8e7fbba742bdf2f6ffdc78c0d4ddd7d1728843d665d276ee4 |

## APKs in this release

Two standalone APKs: one for the farmer app, one for the vet app. Each one
contains every CPU architecture, so there is nothing to choose and nothing else
to download.

| App | File | Size | ABIs inside |
|-----|------|------|-------------|
| farmer | `PashuRakshak-Farmer-v1.8.apk` | 141.2 MB | arm64-v8a, armeabi-v7a, x86, x86_64 |
| vet | `PashuRakshak-Vet-v1.8.apk` | 141.2 MB | arm64-v8a, armeabi-v7a, x86, x86_64 |

## Release notes

### Apps

- Farmer and vet AI chat now keeps conversation history and, for vets, uses the
  selected case as context for answers.
- Sync is more resilient: null fields no longer abort a sync pass and locally
  queued changes are pushed when the connection returns.
- Verified case resolution flow and OTP fixes.
- Backend calls use the deployed Render endpoint.
- Distribution is now one standalone APK per app: every version folder under
  `dist/` contains only `PashuRakshak-Farmer-v<version>.apk` and
  `PashuRakshak-Vet-v<version>.apk`. Each file bundles every CPU architecture,
  so a single file installs on any phone (no per-ABI variants).

### Build and distribution

- Release builds are signed with the project release keystore and the build now
  fails (for `dist` builds) instead of silently falling back to the debug key.
  A debug-signed build cannot be updated by a release-signed one, which is a
  common cause of "App not installed".
- Added `build-dist.bat` / `scripts/build-dist.ps1`: builds both apps, verifies
  the signature and APK contents, and publishes versioned APKs plus
  `SHA256SUMS.txt`, `VERSION_INFO.md` and `metadata.json` under
  `dist/v<version>/`.
- Fixed the build scripts so they find a JDK automatically (Android Studio's
  bundled JBR is used when `JAVA_HOME` is unset or invalid).

## Install

1. Copy the `.apk` file to the phone (USB, WhatsApp document, Google Drive...).
2. Open it and allow "Install unknown apps" for the app you opened it with.
3. If a previous copy of PashuRakshak is installed with a **different signing
   key** (for example a debug build installed from Android Studio), uninstall
   it first. Updates signed with the same key install straight over the old one.

Never share the app from the phone's "Share app" dialog: that copies the
installed base APK, which can be incomplete. Share this `.apk` file instead.

## Verify the download (optional)

```
certutil -hashfile PashuRakshak-Farmer-v1.8.apk SHA256
```

Compare the result with `SHA256SUMS.txt`.
