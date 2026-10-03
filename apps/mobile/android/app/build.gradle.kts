plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.codcrafters.clivora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Change this before publishing your own build to a store.
        applicationId = "org.codcrafters.clivora.community"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                val rawPath = keystoreProperties["storeFile"] as String
                storeFile = when {
                    rootProject.file(rawPath).exists() -> rootProject.file(rawPath)
                    file(rawPath).exists() -> file(rawPath)
                    rootProject.file("clivora-upload-keystore.jks").exists() -> rootProject.file("clivora-upload-keystore.jks")
                    else -> rootProject.file(rawPath)
                }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Fail only when a release artifact is requested, so debug builds work without secrets.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Enable R8 optimization as recommended by Google Play Console
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

afterEvaluate {
    listOf("assembleRelease", "bundleRelease", "assembleReleaseUnitTest").forEach { taskName ->
        tasks.findByName(taskName)?.doFirst {
            require(keystorePropertiesFile.exists()) {
                "Release signing is required. android/key.properties is missing."
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
}

// Firebase Cloud Messaging is optional. Push notifications turn on once you add
// your own android/app/google-services.json (see docs/self-hosting.md).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
