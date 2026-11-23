allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    if (name == "flutter_nearby_connections") {
        plugins.withId("com.android.library") {
            val androidExtension = extensions.getByName("android")
            androidExtension.javaClass
                .getMethod("setNamespace", String::class.java)
                .invoke(androidExtension, "com.nankai.flutter_nearby_connections")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Align Java and Kotlin JVM targets for Android modules.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>()
        .configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }

    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                    )
                }
            }
    }
}

// file_picker sets Java 11 in its own build script after the shared defaults.
// Apply the Java target after project configuration to match Kotlin's JVM 17.
gradle.projectsEvaluated {
    project(":file_picker").tasks.withType<org.gradle.api.tasks.compile.JavaCompile>()
        .configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
}
