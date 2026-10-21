# Changelog

All notable changes to the PashuRakshak Android apps (farmer and vet).

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
