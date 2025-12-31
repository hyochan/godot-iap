import groovy.json.JsonSlurper

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val pluginName = "GodotIap"
val pluginPackageName = "dev.hyo.godotiap"

// Read OpenIAP version from shared config
val openiapVersions = JsonSlurper().parse(file("../openiap-versions.json")) as Map<*, *>
val openiapGoogleVersion = openiapVersions["google"] as String

android {
    namespace = pluginPackageName
    compileSdk = 34

    defaultConfig {
        minSdk = 24

        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // OpenIAP Google package from Maven Central (version from openiap-versions.json)
    implementation("io.github.hyochan.openiap:openiap-google:$openiapGoogleVersion")

    // Godot Android library
    // For local development: Place godot-lib.aar in libs/ folder
    // For production: This will be provided by Godot's export process
    compileOnly(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))

    // Kotlin coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

// Copy the built AAR to the addons directory for Godot
tasks.register<Copy>("copyDebugAarToAddons") {
    dependsOn("assembleDebug")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("${project.name}-debug.aar")
    into("../Example/addons/godot-iap/android/")
    rename { "${pluginName}.debug.aar" }
}

tasks.register<Copy>("copyReleaseAarToAddons") {
    dependsOn("assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("${project.name}-release.aar")
    into("../Example/addons/godot-iap/android/")
    rename { "${pluginName}.release.aar" }
}
