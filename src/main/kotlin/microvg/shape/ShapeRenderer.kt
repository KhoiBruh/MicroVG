package microvg.shape

import microvg.MicroVG
import microvg.effect.Blur
import microvg.shader.Shader
import microvg.util.toFloats
import microvg.util.toInt
import org.lwjgl.opengl.ARBInstancedArrays.glVertexAttribDivisorARB
import org.lwjgl.opengl.GL32C.*
import org.lwjgl.system.MemoryUtil.memAllocFloat

sealed class ShapeRenderer(
	fragment: String,
	vertex: String,
	val maxShapes: Int,
	size: Int
) {
	private val shader = Shader(fragment, vertex)
	val vao = glGenVertexArrays()
	val vbo = glGenBuffers()
	val ebo = glGenBuffers()
	val ibo = glGenBuffers()
	val instanced = memAllocFloat(maxShapes * size)
	val stride = size * Float.SIZE_BYTES

	init {
		glBindVertexArray(vao)

		glBindBuffer(GL_ARRAY_BUFFER, vbo)
		glBufferData(GL_ARRAY_BUFFER, floatArrayOf(0f, 0f, 1f, 0f, 1f, 1f, 0f, 1f), GL_STATIC_DRAW)
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 2 * Float.SIZE_BYTES, 0L)
		glEnableVertexAttribArray(0)
		glVertexAttribDivisorARB(0, 0)

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, intArrayOf(0, 1, 2, 2, 3, 0), GL_STATIC_DRAW)

		glBindBuffer(GL_ARRAY_BUFFER, ibo)
		glBufferData(GL_ARRAY_BUFFER, (maxShapes * stride).toLong(), GL_DYNAMIC_DRAW)

		setupInstanced()

		glBindVertexArray(0)
	}

	abstract fun setupInstanced()

	protected fun render(
		instances: Int,
		bloomRadius: Int,
		bloomColor: Int,
		preDraw: (Shader) -> Unit = {}
	) {
		glBindBuffer(GL_ARRAY_BUFFER, ibo)
		glBufferSubData(GL_ARRAY_BUFFER, 0L, instanced)

		shader.bind()
		shader.ortho()

		shader.uniform("uBloomRadius", bloomRadius)
		shader.uniform("uBloomColor", *bloomColor.toFloats())

		shader.uniform("uUseBlur", Blur.active.toInt())
		shader.uniform("uBlurTex", 1)
		shader.uniform("uScreenSize", MicroVG.width, MicroVG.height)

		preDraw(shader)

		glBindVertexArray(vao)
		glDrawElementsInstanced(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0L, instances)
		glBindVertexArray(0)
		shader.unbind()
	}
}