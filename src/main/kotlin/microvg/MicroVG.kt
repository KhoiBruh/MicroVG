package microvg

import org.lwjgl.opengl.GL32C.*

object MicroVG {

	internal var width = 0
	internal var height = 0

	fun beginFrame(width: Int, height: Int, pixelRatio: Int = 1) {
		States.matrix.identity().ortho2D(
			0F,
			width.toFloat(),
			height.toFloat(),
			0F
		).get(States.matrixBuffer)

		States.backup()
	}

	fun endFrame() {
		States.restore()
	}
}