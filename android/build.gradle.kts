allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Plugins mit veralteter compileSdk anheben.
//
// Bis AGP 8 hat die Flutter-Gradle-Erweiterung das selbst getan. AGP 9 tut es
// nicht mehr, und Plugins, die noch eine alte Fassung deklarieren, lassen
// checkReleaseAarMetadata auflaufen: porcupine_flutter und
// flutter_voice_processor stehen auf 31, waehrend andere Abhaengigkeiten
// mindestens 33 verlangen. Beides sind veroeffentlichte Pakete -- daran laesst
// sich nichts aendern ausser hier.
//
// Der Zugriff laeuft ueber Reflection, weil das Android-Gradle-Plugin im
// Wurzelprojekt gar nicht angewendet wird und seine Typen hier deshalb nicht
// bekannt sind. Angehoben wird nur, nie abgesenkt: ein Plugin, das bewusst
// hoeher steht, bleibt unangetastet.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val gelesen = runCatching {
            android.javaClass.getMethod("getCompileSdkVersion").invoke(android) as? String
        }.getOrNull()
        val aktuell = gelesen?.removePrefix("android-")?.toIntOrNull() ?: return@afterEvaluate
        if (aktuell >= 36) return@afterEvaluate

        runCatching {
            android.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(android, 36)
            logger.lifecycle("compileSdk von ${project.name}: $aktuell -> 36")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    project.evaluationDependsOn(":app")
}

