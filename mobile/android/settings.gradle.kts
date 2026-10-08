pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Versions match Flutter 3.47.5's own app template (gradle_utils.dart):
// Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0. They are the combination this SDK is
// tested against, and the older Gradle 8.14 + AGP 8.11.1 set cannot run under
// Android Studio's bundled JDK 25 (Flutter's Gradle plugin rejects it).
// AGP >= 8.12.1 is also what share_plus 13 requires.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
