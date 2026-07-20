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
    // Some plugins (via file_picker's flutter_plugin_android_lifecycle) require
    // compiling against Android API 36+. Plugin library subprojects otherwise
    // inherit the Flutter SDK's default (34), so force 36 across all of them.
    // Registered here (before evaluationDependsOn below) so afterEvaluate lands
    // before the project is evaluated.
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.let { it.compileSdk = 36 }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
