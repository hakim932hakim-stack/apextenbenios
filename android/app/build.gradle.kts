plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.apexparty.yeniapex"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.apexparty.yeniapex"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}


flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // AndroidX Media (for VideoPlaybackService)
    implementation("androidx.media:media:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
    
    // 🔥 Media3 (ExoPlayer) - Native Video Player
    implementation("androidx.media3:media3-exoplayer:1.2.0")
    implementation("androidx.media3:media3-common:1.2.0")
    implementation("androidx.media3:media3-exoplayer-hls:1.2.0") // 🔥 HLS support (.m3u8)
    implementation("androidx.media3:media3-exoplayer-dash:1.2.0") // 🔥 DASH support (.mpd)
}
