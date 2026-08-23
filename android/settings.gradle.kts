pluginManagement {
    // TOTAL PROCESS WIPE: Forcefully resolve Java 25 crash and AGP environment conflicts
    run {
        System.setProperty("java.version", "17.0.12")
        System.setProperty("java.specification.version", "17")
        System.setProperty("ANDROID_USER_HOME", "C:/Users/Thomas/.android")
        System.clearProperty("ANDROID_PREFS_ROOT")
        System.clearProperty("ANDROID_SDK_HOME")
        
        try {
            val processEnvClass = Class.forName("java.lang.ProcessEnvironment")
            val fields = listOf("theEnvironment", "theCaseInsensitiveEnvironment")
            for (fieldName in fields) {
                try {
                    val field = processEnvClass.getDeclaredField(fieldName)
                    field.isAccessible = true
                    val env = field.get(null) as MutableMap<String, String>
                    env.remove("ANDROID_PREFS_ROOT")
                    env.remove("ANDROID_SDK_HOME")
                    env["ANDROID_USER_HOME"] = "C:\\Users\\Thomas\\.android"
                } catch (e: Exception) {}
            }
        } catch (e: Exception) {}
    }

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

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
