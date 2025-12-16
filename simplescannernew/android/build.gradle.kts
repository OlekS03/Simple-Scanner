import org.gradle.kotlin.dsl.closureOf

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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ADD THIS BLOCK AT THE VERY END OF android/build.gradle.kts
allprojects {
    // This immediately applies the configuration to all subprojects (plugins)
    if (name != "app") { // Exclude the main app module, as it has its own settings
        afterEvaluate {
            if (plugins.hasPlugin("com.android.library")) {
                extensions.configure(com.android.build.gradle.BaseExtension::class) {
                    // Force minimum API 34 to resolve the 'lStar' resource issue
                    compileSdkVersion(34)
                }
            }
        }
    }
}