module microvg::gl;

import opengl::gl;

alias GLenum     = uint;
alias GLbitfield = uint;
alias GLboolean  = opengl::gl::GLboolean;
alias GLbyte     = opengl::gl::GLbyte;
alias GLshort    = opengl::gl::GLshort;
alias GLint      = opengl::gl::GLint;
alias GLsizei    = opengl::gl::GLsizei;
alias GLubyte    = opengl::gl::GLubyte;
alias GLushort   = opengl::gl::GLushort;
alias GLuint     = opengl::gl::GLuint;
alias GLfloat    = opengl::gl::GLfloat;
alias GLchar     = opengl::gl::GLchar;
alias GLintptr   = opengl::gl::GLintptr;
alias GLsizeiptr = opengl::gl::GLsizeiptr;

const GLenum FALSE = 0;
const GLenum TRUE  = 1;

const GLenum NO_ERROR     = 0;
const GLenum INVALID_ENUM = 0x0500;

const GLenum TRIANGLES      = 0x0004;
const GLenum TRIANGLE_STRIP = 0x0005;
const GLenum TRIANGLE_FAN   = 0x0006;

const GLenum ZERO                = 0;
const GLenum ONE                 = 1;
const GLenum SRC_COLOR           = 0x0300;
const GLenum ONE_MINUS_SRC_COLOR = 0x0301;
const GLenum SRC_ALPHA           = 0x0302;
const GLenum ONE_MINUS_SRC_ALPHA = 0x0303;
const GLenum DST_ALPHA           = 0x0304;
const GLenum ONE_MINUS_DST_ALPHA = 0x0305;
const GLenum DST_COLOR           = 0x0306;
const GLenum ONE_MINUS_DST_COLOR = 0x0307;
const GLenum SRC_ALPHA_SATURATE  = 0x0308;

const GLenum CULL_FACE    = 0x0B44;
const GLenum DEPTH_TEST   = 0x0B71;
const GLenum STENCIL_TEST = 0x0B90;
const GLenum BLEND        = 0x0BE2;
const GLenum SCISSOR_TEST = 0x0C11;

const GLenum FRONT = 0x0404;
const GLenum BACK  = 0x0405;
const GLenum CW    = 0x0900;
const GLenum CCW   = 0x0901;

const GLenum NEVER    = 0x0200;
const GLenum LESS     = 0x0201;
const GLenum EQUAL    = 0x0202;
const GLenum LEQUAL   = 0x0203;
const GLenum GREATER  = 0x0204;
const GLenum NOTEQUAL = 0x0205;
const GLenum GEQUAL   = 0x0206;
const GLenum ALWAYS   = 0x0207;

const GLenum KEEP      = 0x1E00;
const GLenum ZERO_OP   = 0;
const GLenum INCR      = 0x1E02;
const GLenum DECR      = 0x1E03;
const GLenum INCR_WRAP = 0x8507;
const GLenum DECR_WRAP = 0x8508;

const GLenum BYTE           = 0x1400;
const GLenum UNSIGNED_BYTE  = 0x1401;
const GLenum SHORT          = 0x1402;
const GLenum UNSIGNED_SHORT = 0x1403;
const GLenum INT            = 0x1404;
const GLenum UNSIGNED_INT   = 0x1405;
const GLenum FLOAT          = 0x1406;

const GLenum RED       = 0x1903;
const GLenum RGBA      = 0x1908;
const GLenum LUMINANCE = 0x1909;
const GLenum R8        = 0x8229;

const GLenum TEXTURE_2D             = 0x0DE1;
const GLenum TEXTURE0               = 0x84C0;
const GLenum TEXTURE_MAG_FILTER     = 0x2800;
const GLenum TEXTURE_MIN_FILTER     = 0x2801;
const GLenum TEXTURE_WRAP_S         = 0x2802;
const GLenum TEXTURE_WRAP_T         = 0x2803;
const GLenum NEAREST                = 0x2600;
const GLenum LINEAR                 = 0x2601;
const GLenum NEAREST_MIPMAP_NEAREST = 0x2700;
const GLenum LINEAR_MIPMAP_LINEAR   = 0x2703;
const GLenum CLAMP_TO_EDGE          = 0x812F;
const GLenum REPEAT                 = 0x2901;
const GLenum GENERATE_MIPMAP        = 0x8191;

const GLenum UNPACK_ALIGNMENT   = 0x0CF5;
const GLenum UNPACK_ROW_LENGTH  = 0x0CF2;
const GLenum UNPACK_SKIP_ROWS   = 0x0CF3;
const GLenum UNPACK_SKIP_PIXELS = 0x0CF4;

const GLenum ARRAY_BUFFER                    = 0x8892;
const GLenum UNIFORM_BUFFER                  = 0x8A11;
const GLenum STREAM_DRAW                     = 0x88E0;
const GLenum UNIFORM_BUFFER_OFFSET_ALIGNMENT = 0x8A34;

const GLenum FRAGMENT_SHADER = 0x8B30;
const GLenum VERTEX_SHADER   = 0x8B31;
const GLenum COMPILE_STATUS  = 0x8B81;
const GLenum LINK_STATUS     = 0x8B82;

const GLboolean GL_FALSE_B = 0;
const GLboolean GL_TRUE_B  = 1;

alias OGLenum = opengl::gl::GLenum;

fn void   glEnable(GLenum cap) => opengl::gl::enable((OGLenum)cap);
fn void   glDisable(GLenum cap) => opengl::gl::disable((OGLenum)cap);
fn GLenum glGetError() => (GLenum)opengl::gl::getError();
fn void   glGetIntegerv(GLenum pname, GLint* data) => opengl::gl::getIntegerv((OGLenum)pname, data);
fn void   glFinish() => opengl::gl::finish();

fn void glColorMask(GLboolean red, GLboolean green, GLboolean blue, GLboolean alpha) => opengl::gl::colorMask(red, green, blue, alpha);
fn void glCullFace(GLenum mode) => opengl::gl::cullFace((OGLenum)mode);
fn void glFrontFace(GLenum mode) => opengl::gl::frontFace((OGLenum)mode);
fn void glBlendFuncSeparate(GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha) => opengl::gl::blendFuncSeparate((OGLenum)srcRGB, (OGLenum)dstRGB, (OGLenum)srcAlpha, (OGLenum)dstAlpha);

fn void glStencilMask(GLuint mask) => opengl::gl::stencilMask(mask);
fn void glStencilFunc(GLenum func, GLint ref, GLuint mask) => opengl::gl::stencilFunc((OGLenum)func, ref, mask);
fn void glStencilOp(GLenum sfail, GLenum dpfail, GLenum dppass) => opengl::gl::stencilOp((OGLenum)sfail, (OGLenum)dpfail, (OGLenum)dppass);
fn void glStencilOpSeparate(GLenum face, GLenum sfail, GLenum dpfail, GLenum dppass) => opengl::gl::stencilOpSeparate((OGLenum)face, (OGLenum)sfail, (OGLenum)dpfail, (OGLenum)dppass);

fn void glDrawArrays(GLenum mode, GLint first, GLsizei count) => opengl::gl::drawArrays((OGLenum)mode, first, count);

fn void glGenTextures(GLsizei n, GLuint* textures) => opengl::gl::genTextures(n, textures);
fn void glDeleteTextures(GLsizei n, GLuint* textures) => opengl::gl::deleteTextures(n, textures);
fn void glBindTexture(GLenum target, GLuint texture) => opengl::gl::bindTexture((OGLenum)target, texture);
fn void glActiveTexture(GLenum texture) => opengl::gl::activeTexture((OGLenum)texture);
fn void glTexImage2D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, void* pixels) => opengl::gl::texImage2D((OGLenum)target, level, internalformat, width, height, border, (OGLenum)format, (OGLenum)type, pixels);
fn void glTexSubImage2D(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, void* pixels) => opengl::gl::texSubImage2D((OGLenum)target, level, xoffset, yoffset, width, height, (OGLenum)format, (OGLenum)type, pixels);
fn void glTexParameteri(GLenum target, GLenum pname, GLint param) => opengl::gl::texParameteri((OGLenum)target, (OGLenum)pname, param);
fn void glPixelStorei(GLenum pname, GLint param) => opengl::gl::pixelStorei((OGLenum)pname, param);
fn void glGenerateMipmap(GLenum target) => opengl::gl::generateMipmap((OGLenum)target);

fn void glGenBuffers(GLsizei n, GLuint* buffers) => opengl::gl::genBuffers(n, buffers);
fn void glDeleteBuffers(GLsizei n, GLuint* buffers) => opengl::gl::deleteBuffers(n, buffers);
fn void glBindBuffer(GLenum target, GLuint buffer) => opengl::gl::bindBuffer((OGLenum)target, buffer);
fn void glBufferData(GLenum target, GLsizeiptr size, void* data, GLenum usage) => opengl::gl::bufferData((OGLenum)target, size, data, (OGLenum)usage);
fn void glBindBufferRange(GLenum target, GLuint index, GLuint buffer, GLintptr offset, GLsizeiptr size) => opengl::gl::bindBufferRange((OGLenum)target, index, buffer, offset, size);

fn void glGenVertexArrays(GLsizei n, GLuint* arrays) => opengl::gl::genVertexArrays(n, arrays);
fn void glDeleteVertexArrays(GLsizei n, GLuint* arrays) => opengl::gl::deleteVertexArrays(n, arrays);
fn void glBindVertexArray(GLuint array) => opengl::gl::bindVertexArray(array);
fn void glEnableVertexAttribArray(GLuint index) => opengl::gl::enableVertexAttribArray(index);
fn void glDisableVertexAttribArray(GLuint index) => opengl::gl::disableVertexAttribArray(index);
fn void glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, void* pointer) => opengl::gl::vertexAttribPointer(index, size, (OGLenum)type, normalized, stride, pointer);

fn GLuint glCreateProgram() => opengl::gl::createProgram();
fn GLuint glCreateShader(GLenum shaderType) => opengl::gl::createShader((OGLenum)shaderType);
fn void   glShaderSource(GLuint shader, GLsizei count, char** string, GLint* length) => opengl::gl::shaderSource(shader, count, string, length);
fn void   glCompileShader(GLuint shader) => opengl::gl::compileShader(shader);
fn void   glGetShaderiv(GLuint shader, GLenum pname, GLint* params) => opengl::gl::getShaderiv(shader, (OGLenum)pname, params);
fn void   glGetShaderInfoLog(GLuint shader, GLsizei maxLength, GLsizei* length, GLchar* infoLog) => opengl::gl::getShaderInfoLog(shader, maxLength, length, infoLog);
fn void   glAttachShader(GLuint program, GLuint shader) => opengl::gl::attachShader(program, shader);
fn void   glBindAttribLocation(GLuint program, GLuint index, char* name) => opengl::gl::bindAttribLocation(program, index, name);
fn void   glLinkProgram(GLuint program) => opengl::gl::linkProgram(program);
fn void   glGetProgramiv(GLuint program, GLenum pname, GLint* params) => opengl::gl::getProgramiv(program, (OGLenum)pname, params);
fn void   glGetProgramInfoLog(GLuint program, GLsizei maxLength, GLsizei* length, GLchar* infoLog) => opengl::gl::getProgramInfoLog(program, maxLength, length, infoLog);
fn void   glDeleteProgram(GLuint program) => opengl::gl::deleteProgram(program);
fn void   glDeleteShader(GLuint shader) => opengl::gl::deleteShader(shader);
fn void   glUseProgram(GLuint program) => opengl::gl::useProgram(program);

fn GLint  glGetUniformLocation(GLuint program, char* name) => opengl::gl::getUniformLocation(program, name);
fn GLuint glGetUniformBlockIndex(GLuint program, char* uniformBlockName) => opengl::gl::getUniformBlockIndex(program, uniformBlockName);
fn void   glUniformBlockBinding(GLuint program, GLuint uniformBlockIndex, GLuint uniformBlockBinding) => opengl::gl::uniformBlockBinding(program, uniformBlockIndex, uniformBlockBinding);
fn void   glUniform1i(GLint location, GLint v0) => opengl::gl::uniform1i(location, v0);
fn void   glUniform2fv(GLint location, GLsizei count, GLfloat* value) => opengl::gl::uniform2fv(location, count, value);
fn void   glUniform4fv(GLint location, GLsizei count, GLfloat* value) => opengl::gl::uniform4fv(location, count, value);
