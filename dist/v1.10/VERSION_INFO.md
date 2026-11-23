# PashuRakshak v1.10

| | |
|---|---|
| Version name | 1.10 |
| Version code | 11 |
| Build date | 2026-11-23 21:41:57 +05:30 |
| Git commit | 4c0f9a1 (main) |
| Signing key | PashuRakshak release keystore |
| Signing cert SHA-256 | 4c22286b58b4cde8e7fbba742bdf2f6ffdc78c0d4ddd7d1728843d665d276ee4 |

## APKs in this release

Two standalone APKs: one for the farmer app, one for the vet app. Each one
contains every CPU architecture, so there is nothing to choose and nothing else
to download.

| App | File | Size | ABIs inside |
|-----|------|------|-------------|
| farmer | `PashuRakshak-Farmer-v1.10.apk` | 141.2 MB | arm64-v8a, armeabi-v7a, x86, x86_64 |
| vet | `PashuRakshak-Vet-v1.10.apk` | 141.2 MB | arm64-v8a, armeabi-v7a, x86, x86_64 |

## Release notes

### Install and update fixes

- Debug builds are now signed with the release keystore when it is configured.
  Previously a debug APK (Android Studio "Run", or `assembleDebug`) carried the
  machine-local debug key while published APKs carried the release key. Same
  package name, different signatures, so installing a release APK over a debug
  install failed with "package conflicts with an existing package"
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Debug and release builds are now
  interchangeable and update each other normally.
- Version code bumped to 11 so v1.10 installs over v1.9 without a downgrade
  error.

> One-time note: a phone still holding a **debug-signed** build from before this
> release must uninstall that app once. Android cannot replace an installed
> signature, so this applies to any APK installed before v1.10.

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
certutil -hashfile PashuRakshak-Farmer-v1.10.apk SHA256
```

Compare the result with `SHA256SUMS.txt`.
