import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Der Signaturschluessel der Freigabe-APK ─────────────────────────────
//
// Android erlaubt ein Update nur, wenn es mit DEMSELBEN Schluessel signiert
// ist wie die installierte Fassung. Lange stand hier der *Debug*-Schluessel
// -- den legt das SDK auf jedem Rechner selbst an, und er ist auf jedem ein
// anderer. Kam das Update von einem anderen Mac, lehnte Android es ab
// (INSTALL_FAILED_UPDATE_INCOMPATIBLE), und dann half nur Deinstallieren --
// was die App-Daten auf dem Geraet mitnimmt.
//
// `android/key.properties` zeigt auf einen eigenen Schluessel. Sie steht in
// .gitignore und entsteht durch `./deploy/schluessel-anlegen.sh`.
//
// FEHLT SIE, WIRD WEITER MIT DEM DEBUG-SCHLUESSEL SIGNIERT. Das ist
// Absicht: wer das Repository frisch auscheckt, soll bauen koennen, ohne
// erst einen Schluessel anzulegen. Der Hinweis unten sagt, was dabei
// herauskommt -- stillschweigend darf das nicht passieren, denn man merkt
// es sonst erst auf dem Geraet.
val schluesselDatei = rootProject.file("key.properties")
val eigenerSchluessel = schluesselDatei.exists()
val schluessel = Properties().apply {
    if (eigenerSchluessel) FileInputStream(schluesselDatei).use { load(it) }
}

if (!eigenerSchluessel) {
    logger.lifecycle(
        "\n  Hinweis: android/key.properties fehlt -- die Freigabe-APK wird " +
        "mit dem\n  Debug-Schluessel signiert. Sie laesst sich dann nur auf " +
        "Geraeten\n  aktualisieren, die schon eine Fassung von genau diesem " +
        "Rechner haben.\n  Eigenen Schluessel anlegen: " +
        "./deploy/schluessel-anlegen.sh\n"
    )
}

android {
    namespace = "com.example.productivity"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring (required by flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.productivity"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        // Nur anlegen, wenn es die Datei gibt. Ein signingConfig ohne
        // storeFile laesst den Build mit einer Meldung abbrechen, die das
        // eigentliche Problem nicht nennt.
        if (eigenerSchluessel) {
            create("release") {
                storeFile = file(schluessel.getProperty("storeFile"))
                storePassword = schluessel.getProperty("storePassword")
                keyAlias = schluessel.getProperty("keyAlias")
                keyPassword = schluessel.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (eigenerSchluessel) {
                signingConfigs.getByName("release")
            } else {
                // Damit `flutter run --release` auch ohne Schluessel laeuft.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Stand frueher als kotlinOptions-Block innerhalb von android { }. Kotlin 2.4
// hat die alte Schreibweise nicht nur verworfen, sondern entfernt: der Build
// bricht dort mit "Using 'jvmTarget: String' is an error" ab. Diese Form
// entspricht der aktuellen Flutter-Vorlage.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
