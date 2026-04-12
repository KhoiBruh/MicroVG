package microvg.shape

import microvg.shader.ROUND_RECT_FRAG
import microvg.shader.ROUND_RECT_VERT
import microvg.util.TRANSPARENT
import microvg.util.toFloats
import org.lwjgl.opengl.ARBInstancedArrays.glVertexAttribDivisorARB
import org.lwjgl.opengl.GL32C.*

object RoundRectRenderer : ShapeRenderer(ROUND_RECT_FRAG, ROUND_RECT_VERT, 1000, 9) {

	override fun setupInstanced() {
		glVertexAttribPointer(1, 4, GL_FLOAT, false, stride, 0L)
		glEnableVertexAttribArray(1)
		glVertexAttribDivisorARB(1, 1)

		glVertexAttribPointer(2, 4, GL_FLOAT, false, stride, 4L * Float.SIZE_BYTES)
		glEnableVertexAttribArray(2)
		glVertexAttribDivisorARB(2, 1)

		glVertexAttribPointer(3, 1, GL_FLOAT, false, stride, 8L * Float.SIZE_BYTES)
		glEnableVertexAttribArray(3)
		glVertexAttribDivisorARB(3, 1)
	}

	fun draw(
		x: Float, y: Float, w: Float, h: Float,
		radius: Float, color: Int,
		bloomColor: Int = TRANSPARENT,
		bloomRadius: Int = 0,
	) {
		instanced.clear()
		instanced.put(x).put(y).put(w).put(h)
		instanced.put(color.toFloats())
		instanced.put(radius)
		instanced.flip()

		render(1, bloomRadius, bloomColor)
	}
}
