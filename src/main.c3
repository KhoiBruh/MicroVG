import glfw34;
import opengl::gl;
import std::io;

fn void main() {
    if (!glfw34::init()) {
        io::printn("Failed to initialize GLFW");
        return;
    }

    glfw34::windowHint(glfw34::CONTEXT_VERSION_MAJOR, 3);
    glfw34::windowHint(glfw34::CONTEXT_VERSION_MINOR, 3);
    glfw34::windowHint(glfw34::OPENGL_PROFILE, glfw34::OPENGL_CORE_PROFILE);

    glfw34::GlfwWindow* window = glfw34::createWindow(800, 600, "MicroVG C3", null, null);
    if (!window) {
        io::printn("Failed to create GLFW window");
        glfw34::terminate();
        return;
    }

    glfw34::makeContextCurrent(window);

    while (!glfw34::windowShouldClose(window)) {
        gl::clearColor(0.2f, 0.3f, 0.3f, 1.0f);
        gl::clear(gl::GL_COLOR_BUFFER_BIT);

        glfw34::swapBuffers(window);
        glfw34::pollEvents();
    }

    glfw34::terminate();
}
