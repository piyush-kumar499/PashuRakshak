# PashuRakshak v1.9

| | |
|---|---|
| Version name | 1.9 |
| Version code | 10 |
| Build date | 2026-11-23 13:15:25 +05:30 |
| Git commit | 352574e (main) |
| Signing key | PashuRakshak release keystore |
| Signing cert SHA-256 | 4c22286b58b4cde8e7fbba742bdf2f6ffdc78c0d4ddd7d1728843d665d276ee4 |

## APKs in this release

Two standalone APKs: one for the farmer app, one for the vet app. Each one
contains every CPU architecture, so there is nothing to choose and nothing else
to download.

| App | File | Size | ABIs inside |
|-----|------|------|-------------|
| farmer | `PashuRakshak-Farmer-v1.9.apk` | 141.2 MB | arm64-v8a, armeabi-v7a, x86, x86_64 |
| vet | `PashuRakshak-Vet-v1.9.apk` | 141.2 MB | arm64-v8a, armeabi-v7a, x86, x86_64 |

## Release notes

### Apps

- Every client now uses the new backend at
  `https://pashurakshak-jvyd.onrender.com`: the Android apps read it through
  `BuildConfig.API_BASE_URL`, the government portal and the vet registration
  site through `VITE_API_BASE_URL`.
- Rebuilt and re-signed farmer and vet release APKs against the new backend.

### Backend and build

- The previous Render service was suspended; a replacement web service was
  deployed from `shared-backend/render.yaml` (same Turso database, so all users,
  cases and registered app keys carried over).
- Node is pinned to LTS 20-22 (`>=20 <23`) so Render no longer picks a
  just-released major version that breaks installs.

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
certutil -hashfile PashuRakshak-Farmer-v1.9.apk SHA256
```

Compare the result with `SHA256SUMS.txt`.
