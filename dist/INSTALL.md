# Installing PashuRakshak on a phone

The APKs in `dist/v<version>/` are signed with the PashuRakshak release key and
can be installed on any Android 7.0+ phone.

## Which file do I install?

| App | File |
|-----|------|
| Farmer | `PashuRakshak-Farmer-v<version>.apk` |
| Vet | `PashuRakshak-Vet-v<version>.apk` |

That's the whole list: one file per app, per version. Each one contains every
CPU architecture (64-bit and 32-bit ARM), so it installs on any Android 7.0+
phone - there is no "arm64" or "universal" variant to choose.

Each file is a complete, standalone APK (not a split bundle), so you can copy
it, send it on WhatsApp as a **document**, or put it on Google Drive and install
it on another phone.

## Install steps

1. Copy the `.apk` to the phone (USB cable, WhatsApp document, Google Drive,
   Telegram, etc.). Do not rename it to `.zip`.
2. Open the file with a file manager.
3. Allow "Install unknown apps" / "Install from this source" for that app when
   Android asks.
4. Tap **Install**.

## Updating an installed copy

Install the new APK over the old one. This works only if both were signed with
the same key. Every APK in `dist/` uses the project release key, so updates
between `dist/` versions work normally.

If the phone already has a copy installed from **Android Studio** (debug build)
or any other build signed with a different key, uninstall it first: Android
refuses to replace an app with a different signature.

## Why does "Share app" from the phone not work?

When you use the phone's **Share app** option, Android copies the *installed*
`base.apk`. For apps installed as split APKs (Play Store / app bundles) that
file is only one piece of the app, so the receiving phone rejects it with:

> App not installed as the package appears to be invalid.

Share the `.apk` file from `dist/` instead. It is the same complete file that
was installed, not a piece of an installation.

## Troubleshooting

| Message | What to do |
|---------|------------|
| **App not installed as the package appears to be invalid** | Use the APK from `dist/` (do not share an installed app) and make sure the file was fully transferred (compare its SHA-256 with `SHA256SUMS.txt`). |
| **App not installed** (no reason) | An older PashuRakshak signed with a different key is installed. Uninstall it, then install again. |
| **There was a problem parsing the package** | The file is corrupt or was renamed/compressed. Re-copy it and check the SHA-256. |
| **App not installed as app isn't compatible with your phone** | Should not happen with these APKs (they bundle all ABIs). Check that the file is complete (SHA-256) and that the phone runs Android 7.0+. |
| **Blocked by Play Protect** | Choose "Install anyway". These APKs are not distributed through Play. |
| **Not enough storage** | Each standalone APK is ~140 MB because it carries every architecture. |

## Verify a download (optional)

```powershell
certutil -hashfile PashuRakshak-Farmer-v1.8.apk SHA256
```

The result must match the same line in `SHA256SUMS.txt`.
