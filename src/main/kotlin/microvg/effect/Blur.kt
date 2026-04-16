package microvg.effect

import microvg.MicroVG
import microvg.shader.BLUR_FRAG
import microvg.shader.BLUR_VERT
import microvg.shader.Shader
import org.lwjgl.opengl.GL32C.*

object Blur {
	var active = false
		private set

	private val shader = Shader(BLUR_FRAG, BLUR_VERT)
	private val vao = glGenVertexArrays()
	private val vbo = glGenBuffers()

	private var fbo1 = 0
	private var tex1 = 0
	private var fbo2 = 0
	private var tex2 = 0
	private var lastW = 0
	private var lastH = 0

	private const val DOWNSAMPLE = 4

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

	private fun checkFBOs(width: Int, height: Int) {
		val tw = width / DOWNSAMPLE
		val th = height / DOWNSAMPLE

		if (lastW != tw || lastH != th) {
			lastW = tw
			lastH = th

			if (fbo1 != 0) {
				glDeleteFramebuffers(intArrayOf(fbo1, fbo2))
				glDeleteTextures(intArrayOf(tex1, tex2))
			}

			fbo1 = glGenFramebuffers()
			tex1 = createTexture(tw, th)
			glBindFramebuffer(GL_FRAMEBUFFER, fbo1)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex1, 0)

			fbo2 = glGenFramebuffers()
			tex2 = createTexture(tw, th)
			glBindFramebuffer(GL_FRAMEBUFFER, fbo2)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex2, 0)
		}
	}

	private fun createTexture(w: Int, h: Int): Int {
		val tex = glGenTextures()
		glBindTexture(GL_TEXTURE_2D, tex)
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, 0L)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
		return tex
	}

	fun apply(radius: Int, block: () -> Unit) {
		if (radius <= 0) {
			block()
			return
		}

		val screenW = MicroVG.width
		val screenH = MicroVG.height

		checkFBOs(screenW, screenH)

		val prevFbo = glGetInteger(GL_DRAW_FRAMEBUFFER_BINDING)
		val tw = lastW
		val th = lastH

		glDisable(GL_BLEND)
		glDisable(GL_DEPTH_TEST)

		shader.bind()
		glBindVertexArray(vao)

		glBindFramebuffer(GL_FRAMEBUFFER, fbo1)
		glViewport(0, 0, tw, th)

		glActiveTexture(GL_TEXTURE0)
//		glBindTexture(GL_TEXTURE_2D, mc.framebuffer.colorAttachment)
		shader.uniform("uTexture", 0)
		shader.uniform("uDir", 1f / tw, 0f)
		shader.uniform("uRadius", radius)
		glDrawArrays(GL_TRIANGLES, 0, 6)

		glBindFramebuffer(GL_FRAMEBUFFER, fbo2)
		glBindTexture(GL_TEXTURE_2D, tex1)
		shader.uniform("uDir", 0f, 1f / th)
		glDrawArrays(GL_TRIANGLES, 0, 6)

		glBindVertexArray(0)

		glBindFramebuffer(GL_FRAMEBUFFER, prevFbo)
		glViewport(0, 0, screenW, screenH)

		glEnable(GL_BLEND)

		glActiveTexture(GL_TEXTURE1)
		glBindTexture(GL_TEXTURE_2D, tex2)

		active = true
		block()
		active = false

		shader.unbind()
	}
}