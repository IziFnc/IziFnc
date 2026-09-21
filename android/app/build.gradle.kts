import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release: android/key.properties (NUNCA versionado, ver
// android/.gitignore) aponta para o keystore em _local/keys/. Sem esse arquivo
// (CI, outra maquina) o build de release cai na chave de debug e continua
// funcionando, so que o APK nao serve para distribuir.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKey = keystoreProperties.containsKey("storeFile")

android {
    namespace = "com.getulio.izifnc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador unico na Play Store. NAO MUDAR depois de publicar: um id novo
        // e um app novo, e quem ja instalou perde os dados locais.
        applicationId = "com.getulio.izifnc"
        // Versao PESSOAL (feat 0024): `IZIFNC_PESSOAL=1` (ver tool/build_pessoal.sh)
        // instala como outro app ("IziFnc Pessoal", id ".pessoal"), lado a lado com a
        // versao normal. Ela leva as chaves de IA embutidas no build e NAO se distribui.
        if (System.getenv("IZIFNC_PESSOAL") == "1") {
            applicationIdSuffix = ".pessoal"
            manifestPlaceholders["appLabel"] = "IziFnc Pessoal"
        } else {
            manifestPlaceholders["appLabel"] = "IziFnc"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
