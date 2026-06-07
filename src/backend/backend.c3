module microvg;

import opengl::gl;

faultdef BACKEND_NOT_READY;
faultdef SHADER_BACKEND_NOT_READY;
faultdef SHADER_CREATE_FAILED;
faultdef SHADER_COMPILE_FAILED;
faultdef SHADER_LINK_FAILED;

const String VERTEX @private =
	"#version 330 core \n"
    "layout(location = 0) in vec2 a_pos; \n"
    "uniform mat4 u_proj; \n"
    "void main() { \n"
        "gl_Position = u_proj * vec4(a_pos, 0.0, 1.0); \n"
    "} \n"
;

const String FRAGMENT @private =
	"#version 330 core \n"
    "uniform vec4 u_color; \n"
    "out vec4 frag_color; \n"
    "void main() { \n"
        "frag_color = u_color; \n"
    "} \n"
;

struct Backend {
	uint program;
	uint vbo;
	uint vao;

	int uProj;
	int uColor;
}

fn uint? compile(uint stage, String source) @private {
	uint shader = gl::createShader((gl::GLenum) stage);
	if (!shader) return SHADER_CREATE_FAILED~;

	char* sourcePtr = source.ptr;
	int sourceLen = source.len;
	gl::shaderSource(shader, 1, &sourcePtr, &sourceLen);
	gl::compileShader(shader);

	int compiled = 0;
	gl::getShaderiv(shader, (gl::GLenum) gl::GL_COMPILE_STATUS, &compiled);
	if (compiled == gl::GL_FALSE) {
		gl::deleteShader(shader);
		return SHADER_COMPILE_FAILED~;
	}

	return shader;
}

fn bool isReady()
=> gl::createShader && gl::shaderSource && gl::compileShader && gl::getShaderiv &&
	gl::createProgram && gl::attachShader && gl::linkProgram && gl::getProgramiv &&
	gl::deleteShader && gl::deleteProgram && gl::useProgram && gl::getUniformLocation;

fn uint? createShader(String vertexSrc, String fragmentSrc) {
	if (!isReady()) return SHADER_BACKEND_NOT_READY~;

	uint vertex = compile(gl::GL_VERTEX_SHADER, vertexSrc)!;
	defer if (vertexSrc) gl::deleteShader(vertex);

	uint fragment = compile(gl::GL_FRAGMENT_SHADER, fragmentSrc)!;
	defer if (fragmentSrc) gl::deleteShader(fragment);

	uint program = gl::createProgram();
	if (!program) return SHADER_CREATE_FAILED~;

	gl::attachShader(program, vertex);
	gl::attachShader(program, fragment);
	gl::linkProgram(program);

	int linked = 0;
	gl::getProgramiv(program, (gl::GLenum) gl::GL_LINK_STATUS, &linked);
	if (linked == gl::GL_FALSE) {
		gl::deleteProgram(program);
		return SHADER_LINK_FAILED~;
	}

	gl::detachShader(program, vertex);
	gl::detachShader(program, fragment);

	return program;
}

fn void? Backend.init(&self) {
	if (!gl::genBuffers) return BACKEND_NOT_READY~;

	gl::genBuffers(1, &self.vbo);
	if (!self.vbo) return BACKEND_NOT_READY~;

	if (gl::genVertexArrays) gl::genVertexArrays(1, &self.vao);
	self.program = createShader(VERTEX, FRAGMENT)!;

	return;
}

fn void Backend.flush(&self, MicroVG* vg) {
	if (vg.vertices.count == 0) return;

	Mat4f proj = vg.currentState().to4x4();
	proj.ortho(0, vg.width, vg.height, 0);

	if (gl::enable) gl::enable((gl::GLenum) gl::GL_BLEND);
    if (gl::blendFunc) gl::blendFunc(
    	(gl::GLenum) gl::GL_ONE,
    	(gl::GLenum) gl::GL_ONE_MINUS_SRC_ALPHA
    );

    gl::useProgram(self.program);
    gl::uniformMatrix4fv(self.uProj, 1, 0, &proj.col0.x);
    gl::uniform4f(self.uColor, 1, 1, 1, 1);

    if (self.vao && gl::bindVertexArray) gl::bindVertexArray(self.vao);
    if (self.vbo && gl::bindBuffer) {
        gl::bindBuffer((gl::GLenum) gl::GL_ARRAY_BUFFER, self.vbo);
	    gl::bufferData(
	        (gl::GLenum) gl::GL_ARRAY_BUFFER,
	        vg.vertices.count * VertexBuffer::size,
	        vg.vertices.data,
	        (gl::GLenum) gl::GL_DYNAMIC_DRAW
	    );
    }

    gl::drawArrays((GLenum) gl::GL_LINES, 0, (int) vg.vertices.count / 2);

	gl::bindVertexArray(0);
    gl::useProgram(0);
}
