package microvg.shader

import microvg.MicroVG
import microvg.States
import org.joml.Matrix4f
import org.lwjgl.opengl.GL32C.*
import org.lwjgl.system.MemoryUtil.memAllocFloat

class Shader(fragment: String, vertex: String) {

	private val program = createShader(fragment, vertex)
	private val uniforms = HashMap<String, Int>()
	private val lastTextures = ArrayList<Int>()
	private var lastProgram = 0

	fun bind() {
		lastProgram = glGetInteger(GL_CURRENT_PROGRAM)
		glUseProgram(program)
	}

	fun unbind() {
		lastTextures.forEachIndexed { index, last ->
			glActiveTexture(GL_TEXTURE0 + index)
			glBindTexture(GL_TEXTURE_2D, last)
		}

		lastTextures.clear()
		glActiveTexture(GL_TEXTURE0)
		glUseProgram(lastProgram)
	}

	fun location(uniform: String) = uniforms.computeIfAbsent(uniform) {
		glGetUniformLocation(program, uniform)
	}

	fun ortho() {
		glUniformMatrix4fv(location("uProjection"), false, States.matrixBuffer)
	}

	fun uniform(uniform: String, vararg value: Int) = when (value.size) {
		1 -> glUniform1i(location(uniform), value[0])
		2 -> glUniform2i(location(uniform), value[0], value[1])
		3 -> glUniform3i(location(uniform), value[0], value[1], value[2])
		4 -> glUniform4i(location(uniform), value[0], value[1], value[2], value[3])
		else -> error("Undefined uniform $uniform")
	}

	fun uniform(uniform: String, vararg value: Float) = when (value.size) {
		1 -> glUniform1f(location(uniform), value[0])
		2 -> glUniform2f(location(uniform), value[0], value[1])
		3 -> glUniform3f(location(uniform), value[0], value[1], value[2])
		4 -> glUniform4f(location(uniform), value[0], value[1], value[2], value[3])
		else -> error("Undefined uniform $uniform")
	}

	private fun createShader(fragment: String, vertex: String): Int {
		if (fragment.isBlank() || vertex.isBlank()) return 0

		val fragmentId = glCreateShader(GL_FRAGMENT_SHADER)
		val vertexId = glCreateShader(GL_VERTEX_SHADER)

		glShaderSource(fragmentId, fragment)
		glCompileShader(fragmentId)

		if (glGetShaderi(fragmentId, GL_COMPILE_STATUS) == GL_FALSE) {
			glGetShaderInfoLog(fragmentId, 1024)
			println("Fragment shader compilation failed for $fragment")
			glDeleteShader(fragmentId)
			glDeleteShader(vertexId)
			return 0
		}

		glShaderSource(vertexId, vertex)
		glCompileShader(vertexId)

		if (glGetShaderi(vertexId, GL_COMPILE_STATUS) == GL_FALSE) {
			glGetShaderInfoLog(vertexId, 1024)
			println("Vertex shader compilation failed for $vertex")
			glDeleteShader(fragmentId)
			glDeleteShader(vertexId)
			return 0
		}

		val programId = glCreateProgram()
		glAttachShader(programId, fragmentId)
		glAttachShader(programId, vertexId)
		glLinkProgram(programId)

		if (glGetProgrami(programId, GL_LINK_STATUS) == GL_FALSE) {
			glGetProgramInfoLog(programId, 1024)
			println("Shader program linking failed")
			glDeleteProgram(programId)
			glDeleteShader(fragmentId)
			glDeleteShader(vertexId)
			return 0
		}

		glValidateProgram(programId)
		glDeleteShader(fragmentId)
		glDeleteShader(vertexId)

		return programId
	}
}