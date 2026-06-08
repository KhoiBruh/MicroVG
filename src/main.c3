import std::io;

import glfw34;

import opengl;
import opengl::gl;

import microvg;

fn int main(String[] args) {
	if (!glfw34::init()) {
		io::printn("failed to initialize glfw");
		return 1;
	}
	defer glfw34::terminate();

	glfw34::windowHint(glfw34::CONTEXT_VERSION_MAJOR, 3);
	glfw34::windowHint(glfw34::CONTEXT_VERSION_MINOR, 3);
	glfw34::windowHint(glfw34::OPENGL_PROFILE, glfw34::OPENGL_CORE_PROFILE);
	glfw34::windowHint(glfw34::STENCIL_BITS, 8);

	GlfwWindow* window = glfw34::createWindow(960, 540, "MicroVG", null, null);
	if (!window) {
		io::printn("failed to create window");
		return 1;
	}
	defer glfw34::destroyWindow(window);

	glfw34::makeContextCurrent(window);
	glfw34::swapInterval(1);

	if (catch err = opengl::init((gl::GLLoadFn) &glfw34::getProcAddress)) {
		io::printn("failed to initialize opengl");
		return 1;
	}

	MicroVG* vg = microvg::create()!!;
	defer vg.destroy();

	int window_w;
    int window_h;

	while (!glfw34::windowShouldClose(window)) {
		glfw34::getWindowSize(window, &window_w, &window_h);

		gl::clearColor(0.08, 0.09, 0.1, 1);
		gl::clear((gl::GLbitfield) gl::GL_COLOR_BUFFER_BIT);

		vg.beginFrame(window_w, window_h, 1);

		microvg::Path* path = vg.makePath();
		path.moveTo(200, 300);
        path.lineTo(300, 300);
        path.lineTo(300, 400);
        path.lineTo(200, 400);
        path.lineTo(200, 300);
        path.close();

        vg.endFrame();

		glfw34::swapBuffers(window);
		glfw34::pollEvents();
	}

	return 0;
}