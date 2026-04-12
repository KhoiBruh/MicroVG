plugins {
	kotlin("jvm") version "2.0.21"
}

group = "microvg"
version = "0.0.1"

kotlin.jvmToolchain(21)

repositories {
	mavenCentral()
}

val lwjgl = "3.4.1"
val joml = "1.10.8"
val jomlPrimitives = "1.10.0"
val lwjglNatives = "natives-windows"

dependencies {
	implementation(platform("org.lwjgl:lwjgl-bom:$lwjgl"))

	implementation(group = "org.lwjgl", name = "lwjgl")
	implementation(group = "org.lwjgl", name = "lwjgl-glfw")
	implementation(group = "org.lwjgl", name = "lwjgl-msdfgen")
	implementation(group = "org.lwjgl", name = "lwjgl-opengl")
	implementation(group = "org.lwjgl", name = "lwjgl-stb")

	implementation(group = "org.lwjgl", name = "lwjgl", classifier = lwjglNatives)
	implementation(group = "org.lwjgl", name = "lwjgl-glfw", classifier = lwjglNatives)
	implementation(group = "org.lwjgl", name = "lwjgl-msdfgen", classifier = lwjglNatives)
	implementation(group = "org.lwjgl", name = "lwjgl-opengl", classifier = lwjglNatives)
	implementation(group = "org.lwjgl", name = "lwjgl-stb", classifier = lwjglNatives)

	implementation(group = "org.joml", name = "joml", version = joml)
	implementation(group = "org.joml", name = "joml-primitives", version = jomlPrimitives)
}