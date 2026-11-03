allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some older plugins (e.g. flutter_webrtc 0.12.x) still compile against android-31,
// which fails the AAR metadata check once newer androidx libs are pulled in.
// Raise any library compileSdk below 36 to 36.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val current = androidExt.javaClass.methods
            .firstOrNull { it.name == "getCompileSdkVersion" && it.parameterCount == 0 }
            ?.invoke(androidExt) as? String
        val level = current?.removePrefix("android-")?.toIntOrNull()
        if (level != null && level < 36) {
            androidExt.javaClass.methods
                .firstOrNull {
                    it.name == "setCompileSdkVersion" &&
                        it.parameterTypes.contentEquals(arrayOf(Int::class.javaPrimitiveType))
                }
                ?.invoke(androidExt, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins {

  id("com.google.gms.google-services") version "4.4.2" apply false
}