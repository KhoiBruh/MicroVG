module microvg;

import opengl::gl;

const String VERTEX_SRC @private = `
#version 330 core
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec4 aColor;
uniform mat4 uProj;
out vec4 vColor;
void main() {
    gl_Position = uProj * vec4(aPos, 0.0, 1.0);
    vColor = aColor;
}
`;

const String FRAGMENT_SRC @private = `
#version 330 core
in vec4 vColor;
out vec4 fragColor;
void main() {
    fragColor = vColor;
}
`;

struct Backend {
    Shader shader;
    uint vao;
    uint vbo;
    int uProj;
}

fn void Backend.init(&self) {
    if (!shaderReady()) return;

    if (gl::enable) gl::enable((GLenum) GL_BLEND);
    if (gl::blendFunc) gl::blendFunc((GLenum) GL_SRC_ALPHA, (GLenum) GL_ONE_MINUS_SRC_ALPHA);

    self.shader = createShader(VERTEX_SRC, FRAGMENT_SRC);
    if (!self.shader.id) return;

    if (gl::getUniformLocation) self.uProj = gl::getUniformLocation(self.shader.id, "uProj");

    if (gl::genVertexArrays) gl::genVertexArrays(1, &self.vao);
    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);

    if (gl::genBuffers) gl::genBuffers(1, &self.vbo);
    if (gl::bindBuffer) gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, self.vbo);

    if (gl::bufferData) {
        gl::bufferData((GLenum) GL_ARRAY_BUFFER, VERTEX_INIT_CAP * Vertex::size, null, (GLenum) GL_DYNAMIC_DRAW);
    }

    // aPos: vec2 at offset 0
    if (gl::vertexAttribPointer) gl::vertexAttribPointer(0, 2, (GLenum) GL_FLOAT, GL_FALSE, Vertex::size, null);
    if (gl::enableVertexAttribArray) gl::enableVertexAttribArray(0);

    // aColor: vec4 at offset 8
    if (gl::vertexAttribPointer) gl::vertexAttribPointer(1, 4, (GLenum) GL_FLOAT, GL_FALSE, Vertex::size, (void*) 8);
    if (gl::enableVertexAttribArray) gl::enableVertexAttribArray(1);

    if (gl::bindVertexArray) gl::bindVertexArray(0);
    if (gl::bindBuffer) gl::bindBuffer((GLenum) GL_ARRAY_BUFFER, 0);
}

fn void Backend.flush(
    &self,
    Vertex* verts, sz count,
    DrawCall* calls, sz callCount,
    int width, int height
) {
    if (!self.shader.id || !self.vao || !self.vbo) return;
    if (count == 0 || callCount == 0) return;

    Mat4 proj = IDENTITY_4X4;
    proj.ortho(0, width, height, 0);

    self.shader.bind();
    if (gl::uniformMatrix4fv && self.uProj >= 0) {
        gl::uniformMatrix4fv(self.uProj, 1, GL_FALSE, (float*) &proj);
    }

    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);
    if (gl::bindBuffer) gl::bindBuffer((GLenum) GL_ARRAY_BUFFER, self.vbo);
    if (gl::bufferData) gl::bufferData((GLenum) GL_ARRAY_BUFFER, count * Vertex::size, verts, (GLenum) GL_DYNAMIC_DRAW);

    if (gl::drawArrays) {
        for (sz i = 0; i < callCount; i++) {
            DrawCall* dc = &calls[i];
            gl::drawArrays((GLenum) GL_TRIANGLES, (int) dc.offset, (int) dc.count);
        }
    }

    if (gl::bindVertexArray) gl::bindVertexArray(0);
    self.shader.unbind();
}

fn void Backend.destroy(&self) {
    if (self.vao && gl::deleteVertexArrays) {
        gl::deleteVertexArrays(1, &self.vao);
        self.vao = 0;
    }
    
    if (self.vbo && gl::deleteBuffers) { 
	    gl::deleteBuffers(1, &self.vbo);
	    self.vbo = 0;
    }
    
    if (self.shader.id && gl::deleteProgram) {
        gl::deleteProgram(self.shader.id);
        self.shader.id = 0;
    }
}
