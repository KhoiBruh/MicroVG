module microvg;

import opengl::gl;

struct Shader {
	uint id;
}

fn uint compile(GLenum type, String source) {
    uint id = gl::createShader(type);

    char* ptr = source.ptr;
    int len = source.len;
    gl::shaderSource(id, 1, &ptr, &len);
    gl::compileShader(id);

    int ok = 0;
    gl::getShaderiv(id, GL_COMPILE_STATUS, &ok);
    if (ok == GL_FALSE) gl::deleteShader(id);

    return id;
}

fn Shader createShader(String vertexSrc, String fragmentSrc) {
    uint vert = compile(GL_VERTEX_SHADER, vertexSrc);
    defer if (vert) gl::deleteShader(vert);

    uint frag = compile(GL_FRAGMENT_SHADER, fragmentSrc);
    defer if (frag) gl::deleteShader(frag);

    uint id = gl::createProgram();
    gl::attachShader(id, vert);
    gl::attachShader(id, frag);
    gl::linkProgram(id);

    int ok = 0;
    gl::getProgramiv(id, GL_LINK_STATUS, &ok);
    if (ok == GL_FALSE) {
        gl::deleteProgram(id);
        return {};
    }

    gl::detachShader(id, vert);
    gl::detachShader(id, frag);

    return { id };
}

fn void Shader.bind(&self) {
	if (self.id) gl::useProgram(self.id);
}

fn void Shader.unbind(&self) => gl::useProgram(0);
