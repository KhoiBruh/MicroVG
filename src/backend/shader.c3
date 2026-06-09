module microvg;

import opengl::gl;

faultdef SHADER_NOT_READY;
faultdef SHADER_CREATE_FAILED;
faultdef SHADER_COMPILE_FAILED;
faultdef SHADER_LINK_FAILED;

struct Shader {
	uint id;
	int uProj;
	int uColor;
}

fn uint? compile(uint type, String source) @private {
	uint id = gl::createShader((GLenum) type);
	if (!id) return SHADER_CREATE_FAILED~;

	char* sourcePtr = source.ptr;
    int sourceLen = source.len;
    gl::shaderSource(id, 1, &sourcePtr, &sourceLen);
    gl::compileShader(id);

	int compiled = 0;
	gl::getShaderiv(id, (GLenum) GL_COMPILE_STATUS, &compiled);
	if (compiled == GL_FALSE) {
		gl::deleteShader(id);
		return SHADER_COMPILE_FAILED~;
	}

	return id;
}

fn bool shaderReady()
=> gl::createShader && gl::shaderSource && gl::compileShader && gl::getShaderiv &&
	gl::createProgram && gl::attachShader && gl::linkProgram && gl::getProgramiv &&
	gl::deleteShader && gl::deleteProgram && gl::useProgram && gl::getUniformLocation;

fn Shader? createShader(String vertexSrc, String fragmentSrc) {
	if (!shaderReady()) return SHADER_NOT_READY~;

	uint vertex = compile(GL_VERTEX_SHADER, vertexSrc)!;
	defer if (vertex) gl::deleteShader(vertex);

	uint fragment = compile(GL_FRAGMENT_SHADER, fragmentSrc)!;
	defer if (fragment) gl::deleteShader(fragment);

	uint id = gl::createProgram();
	if (!id) return SHADER_CREATE_FAILED~;

	gl::attachShader(id, vertex);
    gl::attachShader(id, fragment);
    gl::linkProgram(id);

    int linked = 0;
    gl::getProgramiv(id, (GLenum) GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE) {
    	gl::deleteProgram(id);
    	return SHADER_LINK_FAILED~;
    }

    gl::detachShader(id, vertex);
    gl::detachShader(id, fragment);

    int uProj = gl::getUniformLocation(id, "uProj");
    int uColor = gl::getUniformLocation(id, "uColor");

    return { id, uProj, uColor };
}

fn void Shader.bind(&self) {
	if (self.id && gl::useProgram) gl::useProgram(self.id);
}

fn void Shader.unbind(&self) {
	if (gl::useProgram) gl::useProgram(0);
}

fn void Shader.uniform(&self, Mat4 proj) {
	gl::uniformMatrix4fv(self.uProj, 1, 0, &proj.col0.x);
    gl::uniform4f(self.uColor, 1, 1, 1, 1);
}
