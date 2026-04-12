package microvg

import microvg.builder.Circle
import microvg.builder.RoundRect
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

private val rect = RoundRect(w = 200F, h = 300F, r = 20F)
	.fill(rgba(255, 100, 50, 255))
	.stroke(rgba(255, 255, 255, 255), 2f)
	.blur(radius = 5)

private val circle = Circle()

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

	val winW = IntArray(1)
	val winH = IntArray(1)
	val fbW = IntArray(1)
	val fbH = IntArray(1)

	while (!glfwWindowShouldClose(window)) {
		glfwGetWindowSize(window, winW, winH)
		glfwGetFramebufferSize(window, fbW, fbH)

		glViewport(0, 0, fbW[0], fbH[0])

		glClearColor(0.1f, 0.1f, 0.12f, 1f)
		glClear(GL_COLOR_BUFFER_BIT)

		MicroVG.beginFrame(winW[0] / 2, winH[0] / 2)

		time += 0.016f

		rect
			.size(w = 100F + 20F * sin(time), h = 50F, r = 25F)
			.fill(rgba(255, (100 + 50 * sin(time)).toInt(), 50, 255))
			.shadow(20, color = rgba(255, (100 + 50 * sin(time)).toInt(), 50, 255))
			.draw(x = 100F, y = 100F)

		val radius = 50f + 20f * sin(time * 2f)
		circle
			.fill(rgba(255, 100, 100, 255))
			.shadow(20, color = rgba(255, 50, 50, 128))
			.radius(radius)
			.draw(200F, 300F)

		for (i in 0 until 5) {
			val angle = time + i * (PI.toFloat() * 2f / 5f)
			val x = 640f + 200f * cos(angle)
			val y = 360f + 200f * sin(angle)
			val hue = i / 5f
			val color = hsb(hue, 0.8f, 0.9f)
			Circle(30F).shadow(20, color = color).fill(color).draw(x, y)
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
