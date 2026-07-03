# Contributing

Thanks for taking a look at PashuRakshak.

## Layout
- `app-farmer` — farmer Android app
- `app-vet` — veterinarian Android app
- `gov-portal` — district level web dashboard
- `vet-registration` — vet onboarding web app
- `shared-backend` — Node/Express API and SQLite store
- `core` — shared Kotlin modules

## Before opening a PR
1. Run `./gradlew :app-farmer:assembleDebug` and `:app-vet:assembleDebug`.
2. Start the backend with `node shared-backend/index.js`.
3. Keep commits focused; one concern per commit.

## Reporting issues
Include the app version, device model and the exact screen where it failed.
