package microvg.shape

import microvg.shader.CIRCLE_FRAG
import microvg.shader.CIRCLE_VERT
import microvg.util.TRANSPARENT
import microvg.util.toFloats
import org.lwjgl.opengl.ARBInstancedArrays.glVertexAttribDivisorARB
import org.lwjgl.opengl.GL32C.*

object CircleRenderer : ShapeRenderer(CIRCLE_FRAG, CIRCLE_VERT, 1000, 7) {

	override fun setupInstanced() {
		glVertexAttribPointer(1, 3, GL_FLOAT, false, stride, 0L)
		glEnableVertexAttribArray(1)
		glVertexAttribDivisorARB(1, 1)

		glVertexAttribPointer(2, 4, GL_FLOAT, false, stride, 3L * Float.SIZE_BYTES)
		glEnableVertexAttribArray(2)
		glVertexAttribDivisorARB(2, 1)
	}

	fun draw(
		cx: Float, cy: Float, radius: Float, color: Int,
		bloomColor: Int = TRANSPARENT,
		bloomRadius: Int = 0,
	) {
		instanced.clear()
		instanced.put(cx).put(cy).put(radius)
		instanced.put(color.toFloats())
		instanced.flip()

		render(1, bloomRadius, bloomColor)
	}
}
