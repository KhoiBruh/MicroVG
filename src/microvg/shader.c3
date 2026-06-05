module microvg::shader;

import opengl::gl;

import microvg::matrix;

faultdef SHADER_BACKEND_NOT_READY;
faultdef SHADER_CREATE_FAILED;
faultdef SHADER_COMPILE_FAILED;
faultdef SHADER_LINK_FAILED;

struct Shader {
	uint id;
}

struct AttributeBind {
	String name;
	uint location;
}

fn Shader? create(String vertexSource, String fragmentSource, AttributeBind* attribs = null, int attribCount = 0) {
	if (!isReady()) return SHADER_BACKEND_NOT_READY~;

	uint vertex = compile(gl::GL_VERTEX_SHADER, vertexSource)!;
	defer if (vertex) gl::deleteShader(vertex);

	uint fragment = compile(gl::GL_FRAGMENT_SHADER, fragmentSource)!;
	defer if (fragment) gl::deleteShader(fragment);

	uint program = gl::createProgram();
	if (!program) return SHADER_CREATE_FAILED~;

	gl::attachShader(program, vertex);
	gl::attachShader(program, fragment);

	if (attribs && gl::bindAttribLocation) {
		for (int i = 0; i < attribCount; i++) {
			ZString zname = attribs[i].name.zstr_tcopy();
			gl::bindAttribLocation(program, attribs[i].location, zname);
		}
	}

	gl::linkProgram(program);

	int linked = 0;
	gl::getProgramiv(program, (gl::GLenum) gl::GL_LINK_STATUS, &linked);
	if (linked == gl::GL_FALSE) {
		gl::deleteProgram(program);
		return SHADER_LINK_FAILED~;
	}

	gl::detachShader(program, vertex);
	gl::detachShader(program, fragment);

	return { program };
}

fn void Shader.bind(&self) {
	if (self.id && gl::useProgram) gl::useProgram(self.id);
}

fn void Shader.unbind(&self) {
	if (gl::useProgram) gl::useProgram(0);
}

fn void Shader.destroy(&self) {
	if (!self || !self.id) return;
	gl::deleteProgram(self.id);
	self.id = 0;
}

fn int Shader.uniform(&self, String name) {
	if (!self.id) return -1;
	ZString zname = name.zstr_tcopy();
	return gl::getUniformLocation(self.id, zname);
}

fn void Shader.uniform1f(&self, String name, float x) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform1f(loc, x);
}

fn void Shader.uniform2f(&self, String name, float x, float y) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform2f(loc, x, y);
}

fn void Shader.uniform3f(&self, String name, float x, float y, float z) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform3f(loc, x, y, z);
}

fn void Shader.uniform4f(&self, String name, float x, float y, float z, float w) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform4f(loc, x, y, z, w);
}

fn void Shader.uniform1i(&self, String name, int x) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform1i(loc, x);
}

fn void Shader.uniform2i(&self, String name, int x, int y) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform2i(loc, x, y);
}

fn void Shader.uniform3i(&self, String name, int x, int y, int z) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform3i(loc, x, y, z);
}

fn void Shader.uniform4i(&self, String name, int x, int y, int z, int w) {
	int loc = self.uniform(name);
	if (loc >= 0) gl::uniform4i(loc, x, y, z, w);
}

fn bool isReady()
=> gl::createShader && gl::shaderSource && gl::compileShader && gl::getShaderiv &&
	gl::createProgram && gl::attachShader && gl::linkProgram && gl::getProgramiv &&
	gl::deleteShader && gl::deleteProgram && gl::useProgram && gl::getUniformLocation;

fn uint? compile(uint stage, String source) @private {
	uint shader = gl::createShader((gl::GLenum) stage);
	if (!shader) return SHADER_CREATE_FAILED~;

	char* sourcePtr = source.ptr;
	int sourceLen = (int) source.len;
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
