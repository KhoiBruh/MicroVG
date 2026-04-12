package microvg

import org.lwjgl.opengl.GL32C.*

object MicroVG {

	internal var width = 0
	internal var height = 0

	fun beginFrame(width: Int, height: Int) {
		this.width = width
		this.height = height

		States.ortho(width.toFloat(), height.toFloat())
		States.backup()
	}

	fun endFrame() {
		States.restore()
	}

	fun push() = States.push()

	fun pop() = States.pop()

	fun translate(x: Float, y: Float) = States.translate(x, y)

	fun scale(x: Float, y: Float) = States.scale(x, y)

	fun scale(s: Float) = States.scale(s)
}