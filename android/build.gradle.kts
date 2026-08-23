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

subprojects {
    // Modern AGP 8.x requires a namespace. 
    // This block ensures any legacy plugin that might still be in the project gets a fallback namespace.
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val android = extensions.findByName("android")
            try {
                val getNamespace = android?.javaClass?.getMethod("getNamespace")
                if (getNamespace?.invoke(android) == null) {
                    val setNamespace = android?.javaClass?.getMethod("setNamespace", String::class.java)
                    setNamespace?.invoke(android, "com.synthesia.fix.${name.replace(":", ".")}")
                }
            } catch (e: Exception) {}
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
