# PashuRakshak - Build System Configuration

This document contains ALL the necessary build files, requirements, and instructions to run the PashuRakshak Android application in Android Studio.

## ⚠️ Prerequisites Required

Before building this project, you MUST install:

### 1. **Java Development Kit (JDK) 17**
   - Download: https://adoptium.net/temurin/releases/?version=17
   - OR use Android Studio's bundled JDK

### 2. **Python 3.x** (for native library alignment)
   - Download: https://www.python.org/downloads/
   - Install with "Add Python to PATH" option checked

### 3. **Android SDK** (Already configured in local.properties)
   - SDK location: C:\Users\piyus\AppData\Local\Android\Sdk

---

## 📁 Project Structure & Build Files

### Root Level Configuration Files:

1. **`build.gradle.kts`** (Main build configuration)
   - Defines plugins and dependency versions
   - Includes 16KB ELF alignment script for native libraries
   - Output directory: `/root-project/build`

2. **`settings.gradle.kts`** (Project modules)
   - Defines included modules: `:core`, `app-farmer`, `app-vet`
   - Output directory: `/root-project/settings.gradle.kts`

3. **`gradle.properties`** (Gradle JVM settings)
   - Memory allocation: 4GB
   - Parallel builds enabled
   - Output directory: `/root-project/gradle.properties`

4. **`local.properties`** (LOCAL CONFIGURATION - NOT IN GIT)
   - Contains:
     - Android SDK path
     - Backblaze B2 credentials (optional)
     - API_BASE_URL (defaults to deployed backend)
     - APP_API_KEY (registration key)
   - **IMPORTANT**: This file is excluded from version control (.gitignore)

5. **`gradlew` & `gradlew.bat`** (Gradle wrapper scripts)
   - Downloads and runs correct Gradle version automatically
   - No manual Gradle installation needed
   - Output directories: `/root-project/gradlew`, `/root-project/gradlew.bat`

### Gradle Directory (`/gradle/`):

6. **`gradle/wrapper/gradle-wrapper.properties`**
   - Gradle version: 9.6.0
   - Distribution URL: https://services.gradle.org/distributions/gradle-9.6.0-bin.zip
   - Output: `/gradle/wrapper/gradle-wrapper.properties`

7. **`gradle/libs.versions.toml`** (Dependency versions)
   - AGP (Android Gradle Plugin): 9.4.1
   - Kotlin: 2.2.10
   - Compose BOM: 2026.09.00
   - All library versions in one place
   - Output: `/gradle/libs.versions.toml`

8. **`gradle/gradle-daemon-jvm.properties`**
   - Daemon JVM configuration
   - Output: `/gradle/gradle-daemon-jvm.properties`

### Module-Level Build Files:

#### Core Module (`/core/`):

9. **`core/build.gradle.kts`**
   - Shared library module
   - Contains all app code
   - Configures:
     - Compile SDK: 37
     - Min SDK: 24 (Android 7.0)
     - Target SDK: 37
     - BuildConfig fields for API keys
   - Dependencies include:
     - Jetpack Compose
     - Navigation Compose
     - libSQL database
     - Firebase Messaging
     - ZXing QR scanning
   - Output: `/core/build.gradle.kts`

#### Farmer App (`/app-farmer/`):

10. **`app-farmer/build.gradle.kts`**
    - Application wrapper module
    - Namespace: com.pashurakshak.app.farmer
    - Firebase configuration (google-services.json)
    - ABI splits disabled: one standalone all-ABI APK per build
    - Release signing config
    - VersionCode: 9, VersionName: 1.8
    - Output: `/app-farmer/build.gradle.kts`

11. **`app-farmer/google-services.json`**
    - Firebase configuration for farmer app
    - Copy from google-services.json.example if needed
    - Output: `/app-farmer/google-services.json`

#### Vet App (`/app-vet/`):

12. **`app-vet/build.gradle.kts`**
    - Application wrapper module
    - Namespace: com.pashurakshak.app.vet
    - Firebase configuration
    - ABI splits disabled: one standalone all-ABI APK per build
    - VersionCode: 9, VersionName: 1.8
    - Output: `/app-vet/build.gradle.kts`

13. **`app-vet/google-services.json`**
    - Firebase configuration for vet app
    - Placeholder provided for builds
    - Replace with actual Firebase config when available
    - Output: `/app-vet/google-services.json`

### Scripts Directory (`/scripts/`):

14. **`scripts/align-elf-16k.py`**
    - Native library alignment script
    - Fixes 16KB page size compatibility for ARM devices
    - Ensures .so files work on all device types
    - Output: `/scripts/align-elf-16k.py`

### Keystore Configuration:

15. **`keystore.properties`** (CREATED - Release signing)
    - Path: `/keystore.properties`
    - Stores release keystore information
    - If missing, falls back to debug signing
    - **IMPORTANT**: Never commit .jks file to Git!

16. **`keystore.properties.example`**
    - Template for creating keystore.properties
    - Shows required format
    - Output: `/keystore.properties.example`

---

## 🔧 Complete Setup Instructions

### Step 1: Install JDK 17
```powershell
# Download and install JDK 17 from:
https://adoptium.net/temurin/releases/?version=17

# Then set JAVA_HOME environment variable:
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot\', 'Machine')

# Restart terminal/command prompt after setting JAVA_HOME
```

### Step 2: Install Python 3.x
```powershell
# Download Python 3.11+ from:
https://www.python.org/downloads/release/python-3118/

# During installation, CHECK "Add Python to PATH"
```

### Step 3: Generate Release Keystore (Optional but Recommended)
```powershell
# Navigate to project root
cd C:\Users\piyus\Desktop\PashuRaksahk\PashuRakshak

# Create keystores folder
mkdir keystore

# Generate release keystore
keytool -genkeypair -v -keystore keystore/pashurakshak-release.jks -alias pashurakshak -keyalg RSA -keysize 4096 -validity 10000
```

Update `keystore.properties` with your keystore values if you created one above.

### Step 4: Configure Android SDK (Already Done)
Your local.properties already has:
```
sdk.dir=C:\\Users\\piyus\\AppData\\Local\\Android\\Sdk
```

### Step 5: Sync Gradle in Android Studio
1. Open Android Studio
2. File → Open → Select project folder
3. Click "Sync Gradle" or "Open Gradle Project"
4. Wait for dependencies to download

### Step 6: Build APKs

#### Debug APK (For testing):
```powershell
./gradlew assembleDebug
```
Output locations:
- Farmer app: `/app-farmer/build/outputs/apk/debug/app-debug.apk`
- Vet app: `/app-vet/build/outputs/apk/debug/app-debug.apk`

#### Release APK (For production):
```powershell
./gradlew assembleRelease
```
Output locations:
- Farmer app: `/app-farmer/build/outputs/apk/release/app-release.apk`
- Vet app: `/app-vet/build/outputs/apk/release/app-release.apk`

#### All APKs (Debug + Release + Universal):
```powershell
./gradlew build
```

---

## 📦 Output APK Locations

After successful build, APKs will be in:

### Farmer App:
- **Debug**: `app-farmer/build/outputs/apk/debug/app-farmer-debug.apk`
- **Release**: `app-farmer/build/outputs/apk/release/app-farmer-release.apk` (all ABIs)

### Vet App:
- **Debug**: `app-vet/build/outputs/apk/debug/app-vet-debug.apk`
- **Release**: `app-vet/build/outputs/apk/release/app-vet-release.apk` (all ABIs)

---

## 🎯 Distribution Strategy

Each app is built as **one standalone APK** that bundles the native libraries
for every supported architecture (`arm64-v8a`, `armeabi-v7a`, `x86`,
`x86_64`). That means a single file installs on modern phones, old 32-bit
phones and emulators alike.

`build-dist.bat` publishes exactly two files per version:

- `dist/v<version>/PashuRakshak-Farmer-v<version>.apk`
- `dist/v<version>/PashuRakshak-Vet-v<version>.apk`

The trade-off is size (~140 MB per APK). If smaller downloads ever matter more
than simplicity, re-enable `splits { abi { ... } }` in the two
`build.gradle.kts` files and publish the per-ABI outputs instead.

---

## 🔐 Security Notes

Files **NOT** committed to Git:
- `local.properties` (SDK paths, API keys)
- `keystore.properties` (Release signing keys)
- `*.jks` files (Keystore files)

Files that **MUST** be kept updated in project root:
- All `gradle*` configuration files ✅ DONE
- All `build.gradle.kts` files ✅ DONE
- All wrapper files ✅ DONE

---

## 🚀 Quick Start Commands

```bash
# From project root directory
cd C:\Users\piyus\Desktop\PashuRaksahk\PashuRakshak

# Clean previous builds
.\gradlew clean

# Build debug APK
.\gradlew assembleDebug

# Build release APK (requires keystore)
.\gradlew assembleRelease

# Build everything
.\gradlew build

# Install on connected device/emulator
.\gradlew installDebug

# View build report
.\gradlew tasks | findstr "assemble"
```

---

## ✅ Current Status

All necessary files are now present in this repository:

✅ Root-level build configurations
✅ Module-level build files
✅ Gradle wrapper and versions
✅ Dependency management (libs.versions.toml)
✅ Local properties with deployed backend defaults
✅ Keystore properties template
✅ Google services JSON placeholders
✅ Python alignment script for native libraries

The only requirements you need to install:
1. Java JDK 17
2. Python 3.x

Once installed, simply open in Android Studio and click "Sync Gradle"!

---

## 🛠️ Troubleshooting

### Error: JAVA_HOME not set
- Set JAVA_HOME environment variable to JDK 17 installation path
- Restart Android Studio

### Error: Python not found
- Install Python 3.x
- Check "Add Python to PATH" during installation
- Restart terminal

### Error: keystore.properties missing
- Using debug signing fallback (works for builds)
- Create production keystore following Step 3 above

### Error: google-services.json missing
- Vet app has placeholder file (works for builds)
- Create Firebase project and replace with actual config

### Error: Native library alignment fails
- The app will still work but might fail on 16KB page size devices
- Install Python to fix this issue

---

## 📞 Support

If you encounter issues:
1. Ensure JDK 17 and Python are installed
2. Check JAVA_HOME is set correctly
3. Verify Android SDK path in local.properties
4. Try `.\gradlew clean` then rebuild
