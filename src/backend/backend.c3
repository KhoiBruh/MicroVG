module microvg;

import opengl::gl;

// --- GLSL shader sources ---

// Vertex shader: nhận vị trí (vec2) và màu (vec4), áp dụng projection
const String VERTEX_SRC @private = `
	#version 330 core

	layout(location = 0) in vec2 aPos;
	layout(location = 1) in vec4 aColor;

	uniform mat4 uProjection;

	out vec4 vColor;

	void main() {
	    gl_Position = uProjection * vec4(aPos, 0.0, 1.0);
	    vColor = aColor;
	}
`;

// Fragment shader: xuất màu trực tiếp
const String FRAGMENT_SRC @private = `
	#version 330 core

	in vec4 vColor;
	out vec4 fragColor;

	void main() {
	    fragColor = vColor;
	}
`;

// --- Backend ---

struct Backend {
    Shader shader;
    uint vbo;
    uint vao;
    int uProjection;  // uniform location (-1 nếu không tìm thấy)
}

fn void Backend.init(&self) {
    if (!shaderReady()) return;

    // Compile shader program
    self.shader = createShader(VERTEX_SRC, FRAGMENT_SRC);
    if (!self.shader.id) return;

    // Lấy uniform location cho projection matrix
    if (gl::getUniformLocation) {
        self.uProjection = gl::getUniformLocation(self.shader.id, "uProjection");
    }

    // --- Tạo VAO + VBO ---
    if (gl::genVertexArrays) gl::genVertexArrays(1, &self.vao);
    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);

    if (gl::genBuffers) gl::genBuffers(1, &self.vbo);
    if (gl::bindBuffer)  gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, self.vbo);

    // Pre-allocate VBO với VERTEX_INIT_CAP slots, dynamic draw
    if (gl::bufferData) {
        gl::bufferData(
            (GLenum)GL_ARRAY_BUFFER,
            (long)(VERTEX_INIT_CAP * Vertex::size),
            null,
            (GLenum)GL_DYNAMIC_DRAW
        );
    }

    // Vertex attrib 0: aPos = (x, y) — 2 floats, offset 0
    if (gl::vertexAttribPointer) {
        gl::vertexAttribPointer(
            0, 2, (GLenum)GL_FLOAT, (GLboolean)GL_FALSE,
            (int)Vertex::size, null
        );
    }
    if (gl::enableVertexAttribArray) gl::enableVertexAttribArray(0);

    // Vertex attrib 1: aColor = (r, g, b, a) — 4 floats, offset 8 bytes (sau x, y)
    // Offset = 2 floats * 4 bytes/float = 8 bytes
    if (gl::vertexAttribPointer) {
        gl::vertexAttribPointer(
            1, 4, (GLenum)GL_FLOAT, (GLboolean)GL_FALSE,
            (int)Vertex::size, (void*)8
        );
    }
    if (gl::enableVertexAttribArray) gl::enableVertexAttribArray(1);

    // Unbind
    if (gl::bindVertexArray) gl::bindVertexArray(0);
    if (gl::bindBuffer) gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, 0);
}

fn void Backend.flush(
    &self,
    Vertex*   vertices,    sz vertexCount,
    DrawCall* drawCalls,   sz drawCallCount,
    int width, int height
) {
    if (!self.shader.id || !self.vao || !self.vbo) return;
    if (vertexCount == 0 || drawCallCount == 0) return;

    // --- Tính orthographic projection (y-down: top=0, bottom=height) ---
    // ortho(left, right, bottom, top) với bottom=height, top=0 → y đi xuống
    Mat4 proj = IDENTITY_4X4;
    proj.ortho(0.0f, (float)width, (float)height, 0.0f);

    // --- Bind shader và set uniform ---
    self.shader.bind();

    if (gl::uniformMatrix4fv && self.uProjection >= 0) {
        // Mat4 = 4 Vec4 (float[<4>]) = 16 floats liên tiếp, column-major → transpose=false
        gl::uniformMatrix4fv(self.uProjection, 1, (GLboolean)GL_FALSE, (float*)&proj);
    }

    // --- Upload vertex data và draw ---
    if (gl::bindVertexArray) gl::bindVertexArray(self.vao);
    if (gl::bindBuffer) gl::bindBuffer((GLenum)GL_ARRAY_BUFFER, self.vbo);

    if (gl::bufferData) {
        gl::bufferData(
            (GLenum)GL_ARRAY_BUFFER,
            (long)(vertexCount * Vertex::size),
            vertices,
            (GLenum)GL_DYNAMIC_DRAW
        );
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
