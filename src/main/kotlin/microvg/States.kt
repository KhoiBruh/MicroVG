package microvg

import org.joml.Matrix4f
import org.lwjgl.opengl.GL32C.*
import org.lwjgl.system.MemoryUtil.memAllocFloat

object States {

	private var lastVAO = 0
	private var lastBlendSrc = 0
	private var lastBlendDst = 0
	private var lastBlendSrcRGB = 0
	private var lastBlendDstRGB = 0
	private var lastBlend = false
	private var lastDepth = false
	private var lastCull = false

	internal val matrix = Matrix4f()
	val matrixBuffer = memAllocFloat(16)
	private val matrixStack = ArrayDeque<Matrix4f>()

	fun push() = matrixStack.addLast(Matrix4f(matrix))

	fun pop() {
		if (matrixStack.isNotEmpty()) matrix.set(matrixStack.removeLast())
	}

	fun ortho(width: Float, height: Float) {
		matrix.identity().ortho2D(0F, width, height, 0F).get(matrixBuffer)
	}

	fun translate(x: Float, y: Float) {
		matrix.translate(x, y, 0F)
	}

	fun scale(x: Float, y: Float) {
		matrix.scale(x, y, 1F)
	}

	fun scale(s: Float) = scale(s, s)

	fun backup() {
		lastVAO = glGetInteger(GL_VERTEX_ARRAY_BINDING)
		lastBlendSrc = glGetInteger(GL_BLEND_SRC_ALPHA)
		lastBlendDst = glGetInteger(GL_BLEND_DST_ALPHA)
		lastBlendSrcRGB = glGetInteger(GL_BLEND_SRC_RGB)
		lastBlendDstRGB = glGetInteger(GL_BLEND_DST_RGB)
		lastBlend = glIsEnabled(GL_BLEND)
		lastDepth = glIsEnabled(GL_DEPTH_TEST)
		lastCull = glIsEnabled(GL_CULL_FACE)

		glEnable(GL_BLEND)
		glBlendFuncSeparate(
			GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
			GL_ONE, GL_ONE_MINUS_SRC_ALPHA,
		)
		glDisable(GL_DEPTH_TEST)
		glDisable(GL_CULL_FACE)
	}

	fun restore() {
		glBindVertexArray(lastVAO)
		glBlendFuncSeparate(lastBlendSrcRGB, lastBlendDstRGB, lastBlendSrc, lastBlendDst)

		if (!lastBlend) glDisable(GL_BLEND)
		if (lastDepth) glEnable(GL_DEPTH_TEST)
		if (lastCull) glEnable(GL_CULL_FACE)
	}
}
