import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// One Flutter define selects both native packaging and the Dart interface.
// Keeping this in Gradle properties avoids daemon/environment inheritance.
val novaTv = providers.gradleProperty("dart-defines").orNull.orEmpty()
    .split(",").any { encoded ->
        runCatching {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) == "NOVA_TV=true"
        }.getOrDefault(false)
    }
logger.lifecycle("NOVA Android target: ${if (novaTv) "TV" else "mobile"}")

android {
    namespace = "app.nova.iptv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (novaTv) "app.nova.iptv.tv" else "app.nova.iptv"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // gradle.properties disables ABI offsets: split and universal APKs
        // share pubspec's versionCode and can update each other.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets.getByName("main") {
        if (novaTv) {
            manifest.srcFile("src/tv/AndroidManifest.xml")
            res.srcDir("src/tv/res")
            java.srcDir("src/tv/kotlin")
        }
    }

    signingConfigs {
        create("novaRelease") {
            storeFile = rootProject.file("../.signing/nova-android-release.p12")
            storePassword = System.getenv("NOVA_ANDROID_STORE_PASSWORD")
            keyAlias = "nova-android"
            keyPassword = System.getenv("NOVA_ANDROID_STORE_PASSWORD")
            storeType = "PKCS12"
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            signingConfig = signingConfigs.getByName("novaRelease")
            isMinifyEnabled = false
            isShrinkResources = false
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
    if (novaTv) {
        val media3Version = "1.11.1"
        implementation("androidx.media3:media3-exoplayer:$media3Version")
        implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
        implementation("androidx.media3:media3-exoplayer-dash:$media3Version")
        implementation("androidx.media3:media3-ui:$media3Version")
    }
}
