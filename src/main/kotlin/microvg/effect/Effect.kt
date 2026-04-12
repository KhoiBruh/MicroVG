package microvg.effect

import org.lwjgl.opengl.GL32C.*
import microvg.shader.Shader

sealed class Effect(
	fragment: String,
	vertex: String
) {
	var active = false
		private set

	private val shader = Shader(fragment, vertex)
	private val vao = glGenVertexArrays()
	private val vbo = glGenBuffers()

	init {
		glBindVertexArray(vao)
		glBindBuffer(GL_ARRAY_BUFFER, vbo)
		glBufferData(
			GL_ARRAY_BUFFER,
			floatArrayOf(
				-1f, -1f, 1f, -1f, 1f, 1f,
				-1f, -1f, 1f, 1f, -1f, 1f,
			),
			GL_STATIC_DRAW,
		)
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, 0L)
		glEnableVertexAttribArray(0)
		glBindVertexArray(0)
	}

	private fun createTexture(w: Int, h: Int): Int {
		val tex = glGenTextures()
		glBindTexture(GL_TEXTURE_2D, tex)
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, 0L)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
		return tex
	}
}