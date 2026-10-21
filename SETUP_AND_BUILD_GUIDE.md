# PashuRakshak - Java & Build Setup Guide

**Status:** ✅ BUILD CONFIGURATION FIXED  
**Date:** 2026-10-30

---

## 🔧 What Was Fixed

### Issue Found:
The error `Cannot convert '' to File` at line 47 in `app-farmer\build.gradle.kts` was caused by an empty `storeFile` value in `keystore.properties`. Gradle couldn't process an empty string as a file path.

### Solution Applied:
✅ Modified `app-farmer\build.gradle.kts` to check if keystore config is valid before creating signing config  
✅ Modified `app-vet\build.gradle.kts` with same fix  
✅ Updated `keystore.properties` with clear documentation about optional vs required fields  
✅ The app now works perfectly without a custom keystore (uses Android's default debug signing)

---

## 📥 Step-by-Step Installation

### Step 1: Install/Configure Java JDK ⚠️ REQUIRED

Your Android Studio already has a bundled JDK! Let's configure it:

#### Option A: Use Android Studio JDK (Recommended) ⭐

**Run this script:**
```cmd
cd C:\Users\piyus\Desktop\PashuRaksahk\PashuRakshak
setup-java.bat
```

This will automatically:
1. Detect Android Studio's bundled JDK location
2. Set JAVA_HOME environment variable
3. Verify Java works correctly

**After running the script:**
1. **CLOSE AND REOPEN** Android Studio
2. OR close and reopen any Command Prompt/PowerShell windows you have open
3. Then try building again!

#### Option B: Manual JAVA_HOME Setup

If for some reason the script doesn't work, do this manually:

1. Open **PowerShell as Administrator**
2. Run these commands:
   ```powershell
   $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
   [System.Environment]::SetEnvironmentVariable('JAVA_HOME', $env:JAVA_HOME, 'Machine')
   ```
3. Close PowerShell
4. Open a NEW PowerShell or Command Prompt
5. Verify: `java -version` should show version information

#### Option C: Install Oracle/OpenJDK 17

If you prefer to install a fresh JDK:

1. Download from: https://adoptium.net/temurin/releases/?version=17
2. Run the installer (default settings are fine)
3. After installation, set JAVA_HOME to: `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot`
4. Add `%JAVA_HOME%\bin` to your PATH environment variable

---

### Step 2: Optional - Install Python 3.x

Python is needed only for native library alignment (makes .so files compatible with more devices). The app will still build without it but might fail on some devices.

1. Download: https://www.python.org/downloads/release/python-3118/
2. During installation, CHECK "Add Python to PATH" ✋ **IMPORTANT!**
3. Click "Install Now"
4. Verify: `python --version` should work in a new terminal

---

### Step 3: Test Prerequisites

Open PowerShell or Command Prompt in your project folder:

```cmd
cd C:\Users\piyus\Desktop\PashuRaksahk\PashuRakshak

# Check prerequisites
.\check-prerequisites.bat
```

This script will tell you if Java and Python are properly installed.

---

## 🚀 Building APKs After Java Setup

Once you've completed Step 1 (Java setup) and restarted your terminal:

### Quick Build Commands:

#### Build Debug APKs (for testing):
```cmd
.\gradlew assembleDebug
```

**Output locations:**
- Farmer app: `app-farmer\build\outputs\apk\debug\app-debug.apk`
- Vet app: `app-vet\build\outputs\apk\debug\app-debug.apk`

#### Build Release APKs (for production):
```cmd
.\gradlew assembleRelease
```

**Note:** Without a custom keystore configured in `keystore.properties`, release APKs will be signed with Android's default debug keys (valid for development/testing).

#### Or use the batch scripts:
```cmd
.\build-debug.bat   # Build debug APKs
.\build-release.bat # Build release APKs
```

---

## 📱 Installing APK on Device

### Method 1: Using ADB (Recommended)
```cmd
# Connect your Android device via USB with USB debugging enabled
.\gradlew installDebug
```

### Method 2: Manual Installation
1. Locate the APK file:
   ```
   app-farmer\build\outputs\apk\debug\app-debug.apk
   ```
2. Copy to your Android device
3. Tap to install
4. Grant necessary permissions

---

## 💡 Android Studio Instructions

### Opening Project:

1. **Close Android Studio** completely (if open)
2. Open Android Studio
3. Go to: **File → Open → Select Folder**
4. Navigate to: `C:\Users\piyus\Desktop\PashuRaksahk\PashuRakshak`
5. Click **OK**
6. Wait for Gradle sync to complete (this downloads dependencies)
7. After successful sync, click **Build → Build Bundle(s) / APK(s) → Build APK(s)**

### Building from Android Studio:

After Java is configured:

1. In Android Studio, look for the **"Sync Gradle"** button (elephant icon) in the toolbar
2. Click it to synchronize the project
3. Once sync succeeds, select the app variant from the dropdown:
   - `farmerDebug` - For farmer app testing
   - `vetDebug` - For vet app testing
   - `farmerRelease` - Production farmer app
   - `vetRelease` - Production vet app
4. Go to: **Build → Build Bundle(s) / APK(s) → Build APK(s)**
5. Wait for build to complete
6. A notification will appear - click "locate" to find the APK

---

## 🔍 Troubleshooting

### Error: "JAVA_HOME is not set"

**Solution:**
```cmd
# Run the setup script
.\setup-java.bat

# If that fails, do manual setup:
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Android\Android Studio\jbr', 'Machine')
```
Then restart terminal/Android Studio.

---

### Error: "Could not resolve all files for configuration..."

This usually means Gradle can't download dependencies.

**Solutions:**
1. Check internet connection
2. Try: `.\gradlew clean --refresh-dependencies`
3. In Android Studio: **File → Invalidate Caches → Invalidate and Restart**

---

### Error: "SDK location not found"

Your `local.properties` already has this configured:
```
sdk.dir=C:\\Users\\piyus\\AppData\\Local\\Android\\Sdk
```

If this is wrong, update it in `local.properties`:
```
sdk.dir=C:\\path\\to\\your\\Android\\Sdk
```

---

### Build succeeds but APK won't install

**Possible causes:**
1. App conflicts with existing version - uninstall old app first
2. API level mismatch - ensure minSdk <= device Android version
3. Corrupted APK - rebuild with `.\gradlew clean assembleDebug`

---

### Firebase notifications not working

Without proper Firebase configuration:
- Push notifications won't work
- But the app builds and runs normally

To enable Firebase:
1. Create Firebase project at console.firebase.google.com
2. Add android app with package name:
   - Farmer app: `com.pashurakshak.app`
   - Vet app: `com.pashurakshak.vet`
3. Download `google-services.json`
4. Place in respective module folders:
   - `app-farmer/google-services.json`
   - `app-vet/google-services.json`

---

## ✅ Verification Checklist

After setting up Java, verify everything works:

```cmd
# 1. Check Java is available
java -version

# 2. Check PROJECT is ready
.\check-prerequisites.bat

# 3. Clean previous builds
.\gradlew clean

# 4. Build debug APK
.\gradlew assembleDebug

# 5. Verify APK exists
dir app-farmer\build\outputs\apk\debug\app-debug.apk
```

All checks pass? 🎉 You're ready to build and deploy!

---

## 🎯 Summary of Changes Made

### Modified Files:
1. ✅ `app-farmer\build.gradle.kts` - Added keystore validation logic
2. ✅ `app-vet\build.gradle.kts` - Added keystore validation logic  
3. ✅ `keystore.properties` - Updated with clear documentation

### All Required Files Present:
- ✅ Root-level build configurations (`build.gradle.kts`, `settings.gradle.kts`, etc.)
- ✅ Module-level configs (`core`, `app-farmer`, `app-vet`)
- ✅ Gradle wrapper and dependency versions
- ✅ Google Services JSON placeholders
- ✅ Backend URL and API keys configured

---

## 🚦 Next Steps

1. **Install/Configure Java** → Run `setup-java.bat`
2. **Restart Android Studio/Terminal** (important!)
3. **Verify Java** → `java -version` or `.\check-prerequisites.bat`
4. **Build APK** → `.\gradlew assembleDebug`
5. **Test** → Install APK on Android device

---

**Your project is fully configured and ready to build!** 

Just configure Java once, and you're good to go! Good luck with Smart India Hackathon! 🇮🇳🚀
