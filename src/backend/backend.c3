module microvg;

import opengl::gl;

const String VERTEX_SRC @private = `
#version 330 core
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aUV;
layout(location = 2) in vec4 aColor;
uniform mat4 uProj;
out vec2 vUV;
out vec4 vColor;
void main() {
    gl_Position = uProj * vec4(aPos, 0.0, 1.0);
    vUV = aUV;
    vColor = aColor;
}
`;

const String FRAGMENT_SRC @private = `
#version 330 core
in vec2 vUV;
in vec4 vColor;
out vec4 fragColor;
void main() {
    // vUV.x runs 0..1 across the stroke width; fade alpha toward the edges.
    // vUV.x == 0.5 is the solid core, 0 and 1 are the outer fringe.
    float edge = 1.0 - abs(vUV.x * 2.0 - 1.0);
    float aa = clamp(edge / fwidth(edge), 0.0, 1.0);
    fragColor = vec4(vColor.rgb, vColor.a * aa);
}
`;

struct Backend {
    Shader shader;
    uint vao;
    uint vbo;
    int uProj;
}

fn void Backend.init(&self) {
    gl::enable(GL_BLEND);
    gl::blendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    self.shader = createShader(VERTEX_SRC, FRAGMENT_SRC);
    if (!self.shader.id) return;

    self.uProj = gl::getUniformLocation(self.shader.id, "uProj");

    gl::genVertexArrays(1, &self.vao);
    gl::bindVertexArray(self.vao);

    gl::genBuffers(1, &self.vbo);
    gl::bindBuffer(GL_ARRAY_BUFFER, self.vbo);

    gl::bufferData(GL_ARRAY_BUFFER, VERTEX_INIT_CAP * Vertex::size, null, GL_DYNAMIC_DRAW);

    // aPos: vec2 at offset 0
    gl::vertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, Vertex::size, null);
    gl::enableVertexAttribArray(0);

    // aUV: vec2 at offset 8
    gl::vertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, Vertex::size, (void*) 8);
    gl::enableVertexAttribArray(1);

    // aColor: vec4 at offset 16
    gl::vertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, Vertex::size, (void*) 16);
    gl::enableVertexAttribArray(2);

    gl::bindVertexArray(0);
    gl::bindBuffer(GL_ARRAY_BUFFER, 0);
}

fn void Backend.flush(
    &self,
    Vertex* verts, int count,
    DrawCall* calls, int callCount,
    int width, int height
) {
    if (!self.shader.id || !self.vao || !self.vbo) return;
    if (count == 0 || callCount == 0) return;

    Mat4 proj = IDENTITY_4X4;
    proj.ortho(0, width, height, 0);

    self.shader.bind();
    if (self.uProj >= 0) gl::uniformMatrix4fv(self.uProj, 1, GL_FALSE, (float*) &proj);

    gl::bindVertexArray(self.vao);
    gl::bindBuffer(GL_ARRAY_BUFFER, self.vbo);
    gl::bufferData(GL_ARRAY_BUFFER, count * Vertex::size, verts, GL_DYNAMIC_DRAW);

	for (sz i = 0; i < callCount; i++) {
        DrawCall* dc = &calls[i];
        GLenum mode = dc.mode == TRIANGLE_STRIP ? GL_TRIANGLE_STRIP : GL_TRIANGLES;
        gl::drawArrays(mode, dc.offset, dc.count);
    }

    gl::bindVertexArray(0);
    self.shader.unbind();
}

fn void Backend.destroy(&self) {
    if (self.vao) {
        gl::deleteVertexArrays(1, &self.vao);
        self.vao = 0;
    }
    
    if (self.vbo) {
	    gl::deleteBuffers(1, &self.vbo);
	    self.vbo = 0;
    }
    
    if (self.shader.id) {
        gl::deleteProgram(self.shader.id);
        self.shader.id = 0;
    }
}
