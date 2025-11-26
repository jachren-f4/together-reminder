plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.togetherremind.togetherremind"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID is set per flavor below
        applicationId = "com.togetherremind.togetherremind"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // White-label support: Each brand is a separate flavor
    flavorDimensions += "brand"
    productFlavors {
        create("togetherremind") {
            dimension = "brand"
            applicationId = "com.togetherremind.togetherremind"
            resValue("string", "app_name", "TogetherRemind")
        }
        // Future brands - uncomment when ready
        // create("holycouples") {
        //     dimension = "brand"
        //     applicationId = "com.togetherremind.holycouples"
        //     resValue("string", "app_name", "Holy Couples")
        // }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
