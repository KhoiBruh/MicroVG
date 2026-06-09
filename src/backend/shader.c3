module microvg;

import opengl::gl;

struct Shader {
	uint id;
}

fn uint compile(uint type, String source) {
	uint id = gl::createShader((GLenum) type);

	char* sourcePtr = source.ptr;
    int sourceLen = source.len;
    gl::shaderSource(id, 1, &sourcePtr, &sourceLen);
    gl::compileShader(id);

	int compiled = 0;
	gl::getShaderiv(id, (GLenum) GL_COMPILE_STATUS, &compiled);
	if (compiled == GL_FALSE) {
		gl::deleteShader(id);
	}

	return id;
}

fn bool shaderReady()
=> gl::createShader && gl::shaderSource && gl::compileShader && gl::getShaderiv &&
	gl::createProgram && gl::attachShader && gl::linkProgram && gl::getProgramiv &&
	gl::deleteShader && gl::deleteProgram && gl::useProgram && gl::getUniformLocation;

fn Shader createShader(String vertexSrc, String fragmentSrc) {
	if (!shaderReady()) return {};

	uint vertex = compile(GL_VERTEX_SHADER, vertexSrc);
	defer if (vertex) gl::deleteShader(vertex);

	uint fragment = compile(GL_FRAGMENT_SHADER, fragmentSrc);
	defer if (fragment) gl::deleteShader(fragment);

	uint id = gl::createProgram();

	gl::attachShader(id, vertex);
    gl::attachShader(id, fragment);
    gl::linkProgram(id);

    int linked = 0;
    gl::getProgramiv(id, (GLenum) GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE) {
    	gl::deleteProgram(id);
    }

    gl::detachShader(id, vertex);
    gl::detachShader(id, fragment);

    return { id };
}

fn void Shader.bind(&self) {
	if (self.id && gl::useProgram) gl::useProgram(self.id);
}

fn void Shader.unbind(&self) {
	if (gl::useProgram) gl::useProgram(0);
}
