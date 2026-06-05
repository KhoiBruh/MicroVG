module microvg::backend;

import opengl::gl;

import microvg;
import microvg::types;
import microvg::shader;

const String GL3_VERTEX =
"#version 330 core \n"
"layout(location = 0) in vec2 aPos; \n"
"layout(location = 1) in vec2 aUv; \n"
"out float vCoverage; \n"
"uniform vec2 uViewSize; \n"
"void main() { \n"
"    vec2 p = aPos / uViewSize * 2.0 - 1.0; \n"
"    vCoverage = aUv.x; \n"
"    gl_Position = vec4(p.x, -p.y, 0.0, 1.0); \n"
"} \n";

const String GL3_FRAGMENT =
"#version 330 core \n"
"uniform vec4 uColor; \n"
"in float vCoverage; \n"
"out vec4 outColor; \n"
"void main() { \n"
"    float alpha = uColor.a * vCoverage; \n"
"    outColor = vec4(uColor.rgb * alpha, alpha); \n"
"} \n";

const String GL2_VERTEX =
"#version 120 \n"
"attribute vec2 aPos; \n"
"attribute vec2 aUv; \n"
"varying float vCoverage; \n"
"uniform vec2 uViewSize; \n"
"void main() { \n"
"    vec2 p = aPos / uViewSize * 2.0 - 1.0; \n"
"    vCoverage = aUv.x; \n"
"    gl_Position = vec4(p.x, -p.y, 0.0, 1.0); \n"
"} \n";

const String GL2_FRAGMENT =
"#version 120 \n"
"uniform vec4 uColor; \n"
"varying float vCoverage; \n"
"void main() { \n"
"    float alpha = uColor.a * vCoverage; \n"
"    gl_FragColor = vec4(uColor.rgb * alpha, alpha); \n"
"} \n";

const uint ATTRIB_POS = 0;
const uint ATTRIB_UV = 1;

enum GLType { GL2, GL3 }

struct Backend {
	GLType type;

	Shader shader;

	uint vbo;
	uint vao;
}

fn void? Backend.init(&self, GLType backend) {
	if (backend != GLType.GL2 && backend != GLType.GL3) return microvg::UNSUPPORTED_BACKEND~;

	if (!gl::genBuffers) return microvg::BACKEND_NOT_READY~;

	gl::genBuffers(1, &self.vbo);
	if (!self.vbo) return microvg::BACKEND_NOT_READY~;

	if (backend == GLType.GL3 && gl::genVertexArrays) gl::genVertexArrays(1, &self.vao);

	if (backend == GLType.GL3) {
		self.shader = shader::create(GL3_VERTEX, GL3_FRAGMENT)!;
	} else {
		AttributeBind[2] attribs = {
			{ "aPos", ATTRIB_POS },
			{ "aUv", ATTRIB_UV },
		};
		self.shader = shader::create(GL2_VERTEX, GL2_FRAGMENT, &attribs[0], 2)!;
	}

	return;
}

fn void Backend.destroy(&self) {
	if (!self) return;

	self.shader.destroy();
	if (self.vbo && gl::deleteBuffers) gl::deleteBuffers(1, &self.vbo);
	if (self.vao && gl::deleteVertexArrays) gl::deleteVertexArrays(1, &self.vao);

	self.vbo = 0;
	self.vao = 0;
}

fn void Backend.view(self, int w, int h, float pxRatio) {
	if (gl::viewport) gl::viewport(0, 0, (int) (w * pxRatio), (int) (h * pxRatio));
}

fn void Backend.flush(
	&self,
	Buffer{ Vertex } vertices,
	Buffer{ DrawCall } calls,
	float viewW,
	float viewH
) {
	if (!self || !vertices.items || vertices.count <= 0 || !calls.items || calls.count <= 0) return;
	if (!drawReady()) return;

	if (gl::enable) gl::enable((gl::GLenum) gl::GL_BLEND);
	if (gl::blendFunc) gl::blendFunc(
		(gl::GLenum) gl::GL_ONE,
		(gl::GLenum) gl::GL_ONE_MINUS_SRC_ALPHA
	);
	if (gl::clearStencil) gl::clearStencil(0);

	if (self.vao && gl::bindVertexArray) gl::bindVertexArray(self.vao);

	gl::bindBuffer((gl::GLenum) gl::GL_ARRAY_BUFFER, self.vbo);
	gl::bufferData(
		(gl::GLenum) gl::GL_ARRAY_BUFFER,
		vertices.count * Vertex::size,
		vertices.items,
		(gl::GLenum) gl::GL_DYNAMIC_DRAW
	);

	self.shader.bind();
	self.shader.uniform2f("uViewSize", viewW, viewH);

	setupVertex();

	for (int i = 0; i < calls.count; i++) {
		DrawCall* call = &calls.items[i];

		if (call.count == 0) continue;
		if (call.stencilFill) {
			self.drawStencilFill(call);
			continue;
		}

		self.shader.uniform4f("uColor",
			call.color.r,
			call.color.g,
			call.color.b,
			call.color.a
		);

		gl::drawArrays((gl::GLenum) gl::GL_TRIANGLES, call.offset, call.count);
	}

	if (gl::disableVertexAttribArray) {
		gl::disableVertexAttribArray(ATTRIB_POS);
		gl::disableVertexAttribArray(ATTRIB_UV);
	}

	self.shader.unbind();
	gl::bindBuffer((gl::GLenum) gl::GL_ARRAY_BUFFER, 0);
	if (self.vao && gl::bindVertexArray) gl::bindVertexArray(0);
}

fn void Backend.drawStencilFill(&self, DrawCall* call) {
	if (!stencilReady() || call.coverCount == 0) return;

	gl::enable((gl::GLenum) gl::GL_STENCIL_TEST);
	gl::clear((gl::GLbitfield) gl::GL_STENCIL_BUFFER_BIT);
	gl::colorMask(0, 0, 0, 0);
	gl::stencilMask(0xff);
	gl::stencilFunc((gl::GLenum) gl::GL_ALWAYS, 0, 0xff);

	if (call.fillRule == FillRule.EVEN_ODD) {
		gl::stencilOp((gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_INVERT);
	} else {
		gl::stencilOpSeparate((gl::GLenum) gl::GL_FRONT, (gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_INCR_WRAP);
		gl::stencilOpSeparate((gl::GLenum) gl::GL_BACK, (gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_DECR_WRAP);
	}

	gl::drawArrays((gl::GLenum) gl::GL_TRIANGLES, call.offset, call.count);

	gl::colorMask(1, 1, 1, 1);
	gl::stencilOp((gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_KEEP, (gl::GLenum) gl::GL_KEEP);
	gl::stencilMask(0);
	gl::stencilFunc((gl::GLenum) gl::GL_NOTEQUAL, 0, 0xff);

	self.shader.uniform4f("uColor",
		call.color.r,
		call.color.g,
		call.color.b,
		call.color.a
	);

	gl::drawArrays((gl::GLenum) gl::GL_TRIANGLES, call.coverOffset, call.coverCount);

	gl::stencilMask(0xff);
	gl::disable((gl::GLenum) gl::GL_STENCIL_TEST);
}

fn bool drawReady()
=> gl::bindBuffer && gl::bufferData && gl::drawArrays &&
	gl::enableVertexAttribArray && gl::vertexAttribPointer &&
	gl::uniform2f && gl::uniform4f;

fn bool stencilReady()
=> gl::enable && gl::disable && gl::clear && gl::clearStencil && gl::colorMask &&
	gl::stencilMask && gl::stencilFunc && gl::stencilOp && gl::stencilOpSeparate;

fn void setupVertex() {
	gl::enableVertexAttribArray(ATTRIB_POS);
	gl::vertexAttribPointer(ATTRIB_POS, 2, (gl::GLenum) gl::GL_FLOAT, 0, Vertex::size, null);

	gl::enableVertexAttribArray(ATTRIB_UV);
	gl::vertexAttribPointer(ATTRIB_UV, 2, (gl::GLenum) gl::GL_FLOAT, 0, Vertex::size, (void*) (2 * float::size));
}
