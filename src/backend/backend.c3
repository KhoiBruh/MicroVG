module microvg;

import opengl::gl;

faultdef BACKEND_NOT_READY;

const String VERTEX @private =
	"#version 330 core \n"
    "layout(location = 0) in vec2 aPos; \n"
    "uniform mat4 uProj; \n"
    "void main() { \n"
        "gl_Position = uProj * vec4(aPos, 0.0, 1.0); \n"
    "} \n"
;

const String FRAGMENT @private =
	"#version 330 core \n"
    "uniform vec4 uColor; \n"
    "out vec4 outColor; \n"
    "void main() { \n"
        "outColor = uColor; \n"
    "} \n"
;

struct Backend {
	Shader shader;
	uint vbo;
	uint vao;
}

fn void? Backend.init(&self) {
	if (gl::genBuffers) gl::genBuffers(1, &self.vbo);
    if (gl::genVertexArrays) gl::genVertexArrays(1, &self.vao);
    if (!self.vbo || !self.vao) return BACKEND_NOT_READY~;

	gl::bindVertexArray(self.vao);
    gl::bindBuffer((GLenum) gl::GL_ARRAY_BUFFER, self.vbo);
    gl::vertexAttribPointer(0, 2, (GLenum) gl::GL_FLOAT, 0, float::size * 2, null);
    gl::enableVertexAttribArray(0);
    gl::bindVertexArray(0);

	self.shader = createShader(VERTEX, FRAGMENT)!;

	return;
}

fn void Backend.flush(&self, MicroVG* vg) {
	if (vg.vertices.count == 0) return;

	Mat4f proj = vg.currentState().to4x4();
	proj.ortho(0, vg.width, vg.height, 0);

	if (gl::enable) gl::enable((GLenum) gl::GL_BLEND);
    if (gl::blendFunc) gl::blendFunc(
    	(GLenum) gl::GL_ONE,
    	(GLenum) gl::GL_ONE_MINUS_SRC_ALPHA
    );

	self.shader.bind();
	self.shader.uniform(proj);

    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);
    if (gl::bindBuffer) {
        gl::bindBuffer((GLenum) gl::GL_ARRAY_BUFFER, self.vbo);
	    gl::bufferData(
	        (GLenum) gl::GL_ARRAY_BUFFER,
	        vg.vertices.count * float::size,
	        vg.vertices.data,
	        (GLenum) gl::GL_DYNAMIC_DRAW
	    );
    }

    gl::drawArrays((GLenum) gl::GL_LINES, 0, (int) vg.vertices.count / 2);

	gl::bindVertexArray(0);
    self.shader.unbind();
}
