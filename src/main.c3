import std::io;

import glfw34;

import opengl;
import opengl::gl;

import microvg;

fn void screenshot(int w, int h, String path) {
	sz npix = (sz)w * (sz)h * 3;
	char* pixels = mem::malloc(npix);
	defer mem::free(pixels);
	gl::readPixels(0, 0, w, h, GL_RGB, GL_UNSIGNED_BYTE, pixels);

	File? f = file::open(path, "wb");
	if (catch f) return;
	defer (void) f.close();

	// PPM (P6), flipped vertically (GL origin is bottom-left).
	io::fprintf(&f, "P6\n%d %d\n255\n", w, h)!!;
	for (int y = h - 1; y >= 0; y--) {
		f.write(((char[]) pixels[(usz)(y * w * 3) .. (usz)(y * w * 3 + w * 3 - 1)]))!!;
	}
}

fn int main(String[] args) {
	if (!glfw34::init()) {
		io::printn("failed to initialize glfw");
		return 1;
	}
	defer glfw34::terminate();

	glfw34::windowHint(glfw34::CONTEXT_VERSION_MAJOR, 3);
	glfw34::windowHint(glfw34::CONTEXT_VERSION_MINOR, 3);
	glfw34::windowHint(glfw34::OPENGL_PROFILE, glfw34::OPENGL_CORE_PROFILE);

	GlfwWindow* window = glfw34::createWindow(960, 540, "MicroVG", null, null);
	if (!window) {
		io::printn("failed to create window");
		return 1;
	}
	defer glfw34::destroyWindow(window);

	glfw34::makeContextCurrent(window);
	glfw34::swapInterval(1);

	if (catch err = opengl::init((GLLoadFn) &glfw34::getProcAddress)) {
		io::printn("failed to initialize opengl");
		return 1;
	}

	MicroVG* vg = microvg::create();
	defer vg.destroy();

	int window_w;
    int window_h;

	bool shot = args.len > 1 && args[1] == "--shot";
	int frame = 0;

	while (!glfw34::windowShouldClose(window)) {
		glfw34::getWindowSize(window, &window_w, &window_h);

		gl::clearColor(0.08, 0.09, 0.1, 1);
		gl::clear(GL_COLOR_BUFFER_BIT);

		vg.beginFrame(window_w, window_h, 1);

		vg.save();
		vg.scale(2, 2);
		vg.rotate(0.5);
		vg.translate(40, -350);

		microvg::Path path = vg.makePath();
		path.moveTo(200, 300);
        path.lineTo(300, 300);
        path.lineTo(300, 400);
        path.lineTo(200, 400);
        path.close();

		microvg::Paint paint = vg.makePaint();
		paint.line(microvg::rgba(255, 0, 0), 20);
		paint.fill(microvg::rgba(255, 255, 0));
		paint.join(LineJoin.MITER);

		vg.pushPath(path, paint);

		vg.restore();

		microvg::Path capLine = vg.makePath();
		capLine.moveTo(50, 100);
		capLine.lineTo(300, 700);

		microvg::Paint cap = vg.makePaint();
		cap.line(microvg::rgba(0, 255, 0), 10);
		cap.cap(microvg::LineCap.FLAT);

		vg.pushPath(capLine, cap);

		// Acute zigzag at half alpha: tests inner-join overdraw. If inner edges
		// overlapped, the creases would show as darker bands.
		vg.save();
		vg.alpha(0.5);
		microvg::Path zig = vg.makePath();
		zig.moveTo(120, 430);
		zig.lineTo(165, 660);
		zig.lineTo(230, 430);
		zig.lineTo(295, 660);
		zig.lineTo(360, 430);

		microvg::Paint zigPaint = vg.makePaint();
		zigPaint.line(microvg::rgba(80, 180, 255), 26);
		zigPaint.join(LineJoin.MITER);
		vg.pushPath(zig, zigPaint);
		vg.restore();

        vg.endFrame();

		glfw34::swapBuffers(window);
		glfw34::pollEvents();

		frame++;
		if (shot && frame >= 2) {
			screenshot(window_w, window_h, "shot.ppm");
			break;
		}
	}

	return 0;
}
