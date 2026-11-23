# Changelog

All notable changes to the PashuRakshak Android apps (farmer and vet).

## [1.10] - 2026-11-23

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

## [1.9] - 2026-11-23

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

## [1.8] - 2026-11-10

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

## [1.7] - 2026-10-30

- Initial published Android build (versionCode 8) with offline-first farmer and
  vet apps.
