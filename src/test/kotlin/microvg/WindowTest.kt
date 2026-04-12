package microvg

import microvg.util.*
import org.lwjgl.glfw.Callbacks.glfwFreeCallbacks
import org.lwjgl.glfw.GLFW.*
import org.lwjgl.glfw.GLFWErrorCallback
import org.lwjgl.opengl.GL
import org.lwjgl.opengl.GL32C.*
import org.lwjgl.system.MemoryUtil.NULL
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

fun main() {
	GLFWErrorCallback.createPrint(System.err).set()

	check(glfwInit()) { "Failed to initialize GLFW" }

	glfwDefaultWindowHints()
	glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE)
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE)
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)

	val width = 1280
	val height = 720
	val window = glfwCreateWindow(width, height, "MicroVG Test", NULL, NULL)
	check(window != NULL) { "Failed to create GLFW window" }

	glfwSetKeyCallback(window) { win, key, _, action, _ ->
		if (key == GLFW_KEY_ESCAPE && action == GLFW_RELEASE) {
			glfwSetWindowShouldClose(win, true)
		}
	}

	glfwMakeContextCurrent(window)
	glfwSwapInterval(1)
	glfwShowWindow(window)

	GL.createCapabilities()

	var time = 0f

	while (!glfwWindowShouldClose(window)) {
		glClearColor(0.1f, 0.1f, 0.12f, 1f)
		glClear(GL_COLOR_BUFFER_BIT)

		MicroVG.beginFrame(width, height)

		time += 0.016f

		// Animated circle
		push()
		translate(640f, 360f)
		val radius = 50f + 20f * sin(time * 2f)
		circle(200f, 100f, radius, rgba(255, 100, 100, 255), rgba(255, 50, 50, 128), 10)
		pop()

		// Rounded rect
		push()
		translate(600f, 300f)
		scale(1f + 0.2f * sin(time))
		rect(50f, 50f, 200f, 100f, 20f, rgba(100, 200, 255, 200))
		pop()

		// Multiple circles
		for (i in 0 until 5) {
			val angle = time + i * (PI.toFloat() * 2f / 5f)
			val x = 640f + 200f * cos(angle)
			val y = 360f + 200f * sin(angle)
			val hue = i / 5f
			val color = hsb(hue, 0.8f, 0.9f)
			circle(x, y, 30f, color)
		}

		MicroVG.endFrame()

		glfwSwapBuffers(window)
		glfwPollEvents()
	}

	glfwFreeCallbacks(window)
	glfwDestroyWindow(window)
	glfwTerminate()
	glfwSetErrorCallback(null)?.free()
}
