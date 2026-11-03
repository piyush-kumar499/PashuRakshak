# Release checklist

- [ ] Bump `versionCode` / `versionName` in both app modules
- [ ] Point clients at the current backend URL
- [ ] Rebuild web bundles (`gov-portal`, `vet-registration`)
- [ ] Build signed release APKs and verify signatures
- [ ] Copy APKs and web dist into `dist/v<version>/`
- [ ] Update `CHANGELOG.md`
- [ ] Tag the commit and push
- [ ] Smoke test install-over-update on a physical device
