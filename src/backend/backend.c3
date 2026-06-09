module microvg;

import opengl::gl;

const String VERTEX_SRC @private = `#version 330 core
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec4 aColor;
uniform mat4 uProjection;
out vec4 vColor;
void main() {
    gl_Position = uProjection * vec4(aPos, 0.0, 1.0);
    vColor = aColor;
}
`;

const String FRAGMENT_SRC @private = `#version 330 core
in vec4 vColor;
out vec4 fragColor;
void main() {
    fragColor = vColor;
}
`;

struct Backend {
    Shader shader;
    uint   vao, vbo;
    int    uProjection;
}

fn void Backend.init(&self) {
    if (!shaderReady()) return;

    self.shader = createShader(VERTEX_SRC, FRAGMENT_SRC);
    if (!self.shader.id) return;

    if (gl::getUniformLocation) {
        self.uProjection = gl::getUniformLocation(self.shader.id, "uProjection");
    }

    if (gl::genVertexArrays) gl::genVertexArrays(1, &self.vao);
    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);

    if (gl::genBuffers) gl::genBuffers(1, &self.vbo);
    if (gl::bindBuffer) gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, self.vbo);

    if (gl::bufferData) {
        gl::bufferData((GLenum)GL_ARRAY_BUFFER,
            (long)(VERTEX_INIT_CAP * Vertex::size), null, (GLenum)GL_DYNAMIC_DRAW);
    }

    // aPos: vec2 at offset 0
    if (gl::vertexAttribPointer) {
        gl::vertexAttribPointer(0, 2, (GLenum)GL_FLOAT, (GLboolean)GL_FALSE, (int)Vertex::size, null);
    }
    if (gl::enableVertexAttribArray) gl::enableVertexAttribArray(0);

    // aColor: vec4 at offset 8
    if (gl::vertexAttribPointer) {
        gl::vertexAttribPointer(1, 4, (GLenum)GL_FLOAT, (GLboolean)GL_FALSE, (int)Vertex::size, (void*)8);
    }
    if (gl::enableVertexAttribArray) gl::enableVertexAttribArray(1);

    if (gl::bindVertexArray) gl::bindVertexArray(0);
    if (gl::bindBuffer) gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, 0);
}

fn void Backend.flush(
    &self,
    Vertex* vertices, sz vertexCount,
    DrawCall* drawCalls, sz drawCallCount,
    int width, int height
) {
    if (!self.shader.id || !self.vao || !self.vbo) return;
    if (vertexCount == 0 || drawCallCount == 0) return;

    // Orthographic projection, y-down (top = 0, bottom = height)
    Mat4 proj = IDENTITY_4X4;
    proj.ortho(0.0f, (float)width, (float)height, 0.0f);

    self.shader.bind();
    if (gl::uniformMatrix4fv && self.uProjection >= 0) {
        gl::uniformMatrix4fv(self.uProjection, 1, (GLboolean)GL_FALSE, (float*)&proj);
    }

    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);
    if (gl::bindBuffer) gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, self.vbo);
    if (gl::bufferData) {
        gl::bufferData((GLenum)GL_ARRAY_BUFFER,
            (long)(vertexCount * Vertex::size), vertices, (GLenum)GL_DYNAMIC_DRAW);
    }

    if (gl::drawArrays) {
        for (sz i = 0; i < drawCallCount; i++) {
            DrawCall* dc = &drawCalls[i];
            gl::drawArrays((GLenum)GL_TRIANGLES, (int)dc.vertexOffset, (int)dc.vertexCount);
        }
    }

    if (gl::bindVertexArray) gl::bindVertexArray(0);
    self.shader.unbind();
}

fn void Backend.destroy(&self) {
    if (self.vao && gl::deleteVertexArrays) { gl::deleteVertexArrays(1, &self.vao); self.vao = 0; }
    if (self.vbo && gl::deleteBuffers)      { gl::deleteBuffers(1, &self.vbo);       self.vbo = 0; }
    if (self.shader.id && gl::deleteProgram) { gl::deleteProgram(self.shader.id); self.shader.id = 0; }
}
