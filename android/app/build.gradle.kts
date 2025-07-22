
import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")          // <- preferred id
    // The Flutter Gradle Plugin must come last
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.gately.texterace"

    // Provided by the Flutter Gradle plugin
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // You can use 17 if you’ve bumped the JDK in gradle.properties
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true

    }
    kotlinOptions { jvmTarget = "11" }

    defaultConfig {
        applicationId = "com.gately.texterace"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = 35
        versionName = "3.1.5"
    }

    /** --- 🔑 signing --- **/
    signingConfigs {
        // Kotlin-DSL requires create/getByName + "=" assignment
        create("release") {
            keyAlias      = keystoreProperties["keyAlias"]      as String?
            keyPassword   = keystoreProperties["keyPassword"]   as String?
            storePassword = keystoreProperties["storePassword"] as String?
            storeFile     = keystoreProperties["storeFile"]
                ?.let { file(it) }
        }
    }

    buildTypes {
        // Groovy-style `signingConfig signingConfigs.release` doesn’t compile in Kotlin.
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            // Optional production flags
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"),
            //               "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
    // Flutter & plugin dependencies are added automatically.
    // You only need to declare EXTRA ones yourself.

    /* runtime for core-library-desugaring */
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}