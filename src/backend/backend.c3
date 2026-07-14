module microvg;

import opengl::gl;

const String VERTEX_SRC @private = `
#version 330 core

void main() {

}
`;

const String FRAGMENT_SRC @private = `
#version 330 core

void main() {

}
`;

struct Backend {
    Shader shader;
}

fn void Backend.init(&self) {

}

fn void Backend.destroy(&self) {

}
