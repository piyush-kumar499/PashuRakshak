# PashuRakshak Android releases

Every folder here is one published version of both Android apps (farmer and
vet), signed with the project release keystore. Each folder holds exactly two
standalone APKs -- `PashuRakshak-Farmer-v<version>.apk` and
`PashuRakshak-Vet-v<version>.apk` -- and each one installs on any phone.
Share those `.apk` files; do not share the app installed on a phone.

| Version | Code | Built | Commit | APKs |
|---------|------|-------|--------|------|
| [1.11](v1.11/VERSION_INFO.md) | 12 | 2026-11-24 07:15:12 +05:30 | 3acfde8 | farmer, vet |
| [1.10](v1.10/VERSION_INFO.md) | 11 | 2026-11-23 21:41:57 +05:30 | 4c0f9a1 | farmer, vet |
| [1.9](v1.9/VERSION_INFO.md) | 10 | 2026-11-23 13:15:25 +05:30 | 352574e | farmer, vet |
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
