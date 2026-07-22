import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releasePropertiesFile.exists()) {
    FileInputStream(releasePropertiesFile).use(releaseProperties::load)
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseTaskRequested && !releasePropertiesFile.exists()) {
    throw GradleException(
        "Release signing credentials are missing. Copy key.properties.example " +
            "to key.properties and point it to the private upload keystore.",
    )
}
fun requiredReleaseProperty(name: String): String {
    val value = releaseProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty() || value.startsWith("REPLACE_")) {
        throw GradleException("key.properties is missing a real $name value.")
    }
    return value
}

android {
    namespace = "app.toauner.toauner_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.toauner.toauner_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releasePropertiesFile.exists()) {
            create("release") {
                keyAlias = requiredReleaseProperty("keyAlias")
                keyPassword = requiredReleaseProperty("keyPassword")
                storeFile = rootProject.file(requiredReleaseProperty("storeFile"))
                storePassword = requiredReleaseProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releasePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
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
