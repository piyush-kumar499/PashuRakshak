# PashuRakshak Android releases

Every folder here is one published version of both Android apps (farmer and
vet), signed with the project release keystore. Each folder holds exactly two
standalone APKs -- `PashuRakshak-Farmer-v<version>.apk` and
`PashuRakshak-Vet-v<version>.apk` -- and each one installs on any phone.
Share those `.apk` files; do not share the app installed on a phone.

| Version | Code | Built | Commit | APKs |
|---------|------|-------|--------|------|
| [1.8](v1.8/VERSION_INFO.md) | 9 | 2026-11-10 20:14:16 +05:30 | f318294 | farmer, vet |

## Build a new release

```
.\build-dist.bat
```

This builds both apps, verifies their signatures and adds a new `v<version>`
folder with `VERSION_INFO.md`, `SHA256SUMS.txt` and `metadata.json`.
Bump `versionCode`/`versionName` in `app-farmer/build.gradle.kts` and
`app-vet/build.gradle.kts` before publishing a new version.

See `INSTALL.md` for installation and troubleshooting.
