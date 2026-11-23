plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val pawmateReleaseSigning = mapOf(
    "storeFile" to System.getenv("PAWMATE_ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("PAWMATE_ANDROID_STORE_PASSWORD"),
    "keyAlias" to System.getenv("PAWMATE_ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("PAWMATE_ANDROID_KEY_PASSWORD"),
)
val pawmateReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val pawmateReleaseSigningComplete = pawmateReleaseSigning.values.all {
    !it.isNullOrBlank()
}

if (pawmateReleaseTaskRequested && !pawmateReleaseSigningComplete) {
    throw GradleException(
        "PawMate Android release signing is not configured. " +
            "Set PAWMATE_ANDROID_KEYSTORE_PATH, PAWMATE_ANDROID_STORE_PASSWORD, " +
            "PAWMATE_ANDROID_KEY_ALIAS and PAWMATE_ANDROID_KEY_PASSWORD. " +
            "Release builds never fall back to the Android debug key.",
    )
}

android {
    namespace = "com.pawmate.pawmate_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pawmate.pawmate_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (pawmateReleaseSigningComplete) {
            create("pawmateRelease") {
                storeFile = file(pawmateReleaseSigning.getValue("storeFile")!!)
                storePassword = pawmateReleaseSigning.getValue("storePassword")!!
                keyAlias = pawmateReleaseSigning.getValue("keyAlias")!!
                keyPassword = pawmateReleaseSigning.getValue("keyPassword")!!
            }
        }
    }

    buildTypes {
        release {
            if (pawmateReleaseSigningComplete) {
                signingConfig = signingConfigs.getByName("pawmateRelease")
            }
        }
    }
}

flutter {
    source = "../.."
}
