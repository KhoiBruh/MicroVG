module microvg;

import opengl::gl;

struct Shader { uint id; }

fn bool shaderReady()
=> gl::createShader && gl::shaderSource && gl::compileShader && gl::getShaderiv &&
   gl::createProgram && gl::attachShader && gl::linkProgram && gl::getProgramiv &&
   gl::deleteShader && gl::deleteProgram && gl::useProgram && gl::getUniformLocation;

fn uint compile(uint type, String source) {
    uint id = gl::createShader((GLenum)type);

    char* ptr = source.ptr;
    int   len = source.len;
    gl::shaderSource(id, 1, &ptr, &len);
    gl::compileShader(id);

    int ok = 0;
    gl::getShaderiv(id, (GLenum)GL_COMPILE_STATUS, &ok);
    if (ok == GL_FALSE) gl::deleteShader(id);

    return id;
}

fn Shader createShader(String vertexSrc, String fragmentSrc) {
    if (!shaderReady()) return {};

    uint vert = compile(GL_VERTEX_SHADER,   vertexSrc);
    defer if (vert) gl::deleteShader(vert);

    uint frag = compile(GL_FRAGMENT_SHADER, fragmentSrc);
    defer if (frag) gl::deleteShader(frag);

    uint id = gl::createProgram();
    gl::attachShader(id, vert);
    gl::attachShader(id, frag);
    gl::linkProgram(id);

    int ok = 0;
    gl::getProgramiv(id, (GLenum)GL_LINK_STATUS, &ok);
    if (ok == GL_FALSE) { gl::deleteProgram(id); return {}; }

    gl::detachShader(id, vert);
    gl::detachShader(id, frag);

    return { id };
}

fn void Shader.bind(&self)   { if (self.id && gl::useProgram) gl::useProgram(self.id); }
fn void Shader.unbind(&self) { if (gl::useProgram) gl::useProgram(0); }
