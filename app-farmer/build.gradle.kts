import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// Farmer app — applicationId must match the Firebase package in
// google-services.json (com.pashurakshak.app). Applies the Google Services
// plugin only when that file is present so the project builds before Firebase
// is configured (copy google-services.json.example → google-services.json).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing: reads root keystore.properties. Falls back to the debug
// signing config so `assembleRelease` always produces an installable (signed)
// APK even when the release keystore has not been configured.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    // R/BuildConfig namespace must differ from :core's (com.pashurakshak.app).
    namespace = "com.pashurakshak.app.farmer"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.pashurakshak.app"
        minSdk {
            version = release(24)
        }
        targetSdk {
            version = release(37)
        }
        versionCode = 11
        versionName = "1.10"
    }

    // Resolve the configured keystore relative to the ROOT project (not this
    // module) and only treat it as configured when the file really exists.
    val releaseStorePath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
    val releaseStoreFile = if (releaseStorePath.isEmpty()) null else rootProject.file(releaseStorePath)
    val hasKeystoreConfig = releaseStoreFile != null && releaseStoreFile.exists()
    // `dist` builds pass -PrequireReleaseSigning=true: they must never silently
    // fall back to the debug key, because a debug-signed APK cannot update an
    // installation signed with the release key ("App not installed").
    val requireReleaseSigning = providers.gradleProperty("requireReleaseSigning")
        .map { it.toBoolean() }
        .getOrElse(false)
    if (requireReleaseSigning && !hasKeystoreConfig) {
        throw GradleException(
            "Release signing requested but no keystore was found. " +
                "Check keystore.properties (storeFile=${releaseStorePath.ifEmpty { "<not set>" }}).",
        )
    }

    signingConfigs {
        if (hasKeystoreConfig) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        // Debug builds are signed with the release keystore whenever it is
        // configured. Without this, a debug APK (Android Studio "Run", or
        // assembleDebug) is signed with the machine-local debug key, and
        // installing a published release APK over it fails with "package
        // conflicts with an existing package"
        // (INSTALL_FAILED_UPDATE_INCOMPATIBLE) because the signatures differ.
        // One key for both build types makes debug and release interchangeable.
        debug {
            signingConfig = if (hasKeystoreConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // A release build MUST be signed. Without a production keystore we
            // sign with the debug key; an unsigned release APK makes Android
            // say "App not installed as package appears to be invalid".
            signingConfig = if (hasKeystoreConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Distribution is one standalone APK per app (see scripts/build-dist.ps1),
    // so no ABI splits: Gradle emits a single "fat" APK that contains the native
    // libraries for every supported architecture and installs on any phone.
}

dependencies {
    implementation(project(":core"))
}
