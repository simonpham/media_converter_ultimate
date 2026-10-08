import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envProps = Properties()
val envPropsFile = rootProject.file("../../../.assets/env.props")
if (envPropsFile.exists()) {
    println("🔧 Loading selected env.props configs...")
    envPropsFile.reader(Charsets.UTF_8).use { reader ->
        envProps.load(reader)
    }
} else {
    println("🔧 No env.props configs found.")
}
// Without env.props (e.g. a fresh clone), build under the default ID and sign
// release builds with the debug key. See .assets/env.props.example.
val packageName = envProps.getProperty("androidAppPackageName") ?: "io.sofluffy.mcu"
val releaseStoreFile = envProps.getProperty("androidStoreFile")
    ?.let { rootProject.file("../../../.assets/$it") }
    ?.takeIf { it.exists() }

android {
    namespace = "io.sofluffy.mcu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = packageName
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                keyAlias = envProps.getProperty("androidKeyAlias")
                keyPassword = envProps.getProperty("androidKeyPassword")
                storeFile = releaseStoreFile
                storePassword = envProps.getProperty("androidStoreFilePassword")
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
