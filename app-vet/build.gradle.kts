import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// Vet app — applicationId com.pashurakshak.vet. Register this package in the
// Firebase Console and drop google-services.json here to enable FCM push;
// the project builds fine without it (the plugin is only applied when the
// file exists).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing: reads root keystore.properties. `dist` builds pass
// -PrequireReleaseSigning=true and fail when the keystore is missing; a plain
// `assembleRelease` falls back to debug signing so local builds still work.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    // R/BuildConfig namespace must differ from :core's (com.pashurakshak.app).
    namespace = "com.pashurakshak.app.vet"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.pashurakshak.vet"
        minSdk {
            version = release(24)
        }
        targetSdk {
            version = release(37)
        }
        versionCode = 12
        versionName = "1.11"
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
            // sign with the debug key so local builds work, but such an APK is
            // never published (build-dist.ps1 rejects it): it cannot update a
            // release install and causes "App not installed" on other phones.
            signingConfig = if (hasKeystoreConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Same distribution strategy as the farmer app: one standalone, all-ABI
    // APK per release and no ABI splits, so a single file installs everywhere.
}

dependencies {
    implementation(project(":core"))
}
