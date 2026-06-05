module microvg;

import std::io;
import glfw34;
import opengl;
import opengl::gl;
import microvg::color;
import microvg::paint;
import microvg::state;
import microvg::path;

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

	MicroVG* vg = create(GLType.GL3)!!;
	defer vg.destroy();

	while (!glfw34::windowShouldClose(window)) {
		int window_w;
		int window_h;

		glfw34::getWindowSize(window, &window_w, &window_h);

		gl::clearColor(0.08, 0.09, 0.1, 1);
		gl::clear((gl::GLbitfield) gl::GL_COLOR_BUFFER_BIT);

		vg.beginFrame(window_w, window_h, 1);

		drawDebugScene(vg);
		updateDebugTitle(window, vg);

		vg.endFrame();

		glfw34::swapBuffers(window);

		glfw34::waitEvents();
	}

	return 0;
}

fn void drawDebugScene(MicroVG* vg) {
	drawTransformedTriangle(vg);
	drawBezierShape(vg);
	drawQuadraticCurve(vg);
	drawOpenStroke(vg);
	drawMultiSubpath(vg);
	drawShapeHelpers(vg);
	drawArcToPath(vg);
	drawWindingFill(vg);
	drawConcaveFill(vg);
	drawStrokeStyles(vg);
}

fn void drawTransformedTriangle(MicroVG* vg) {
	vg.save();
	vg.translate(150, -150);
	vg.scale(1.25, 1.25);
	vg.rotate(0.5);

	path::Path tri = vg.makePath();
	tri.moveTo(200, 100);
	tri.lineTo(400, 400);
	tri.lineTo(100, 300);
	tri.close();

	Paint paint = vg.makePaint();
	paint.fill(color::rgba(60, 180, 255));
	paint.stroke(color::rgba(160, 80, 255));
	vg.drawPath(tri, paint);

	vg.restore();
}

fn void drawBezierShape(MicroVG* vg) {
	path::Path curve = vg.makePath();
	curve.moveTo(500, 160);
	curve.bezierTo(550, 20, 700, 320, 820, 160);
	curve.close();

	Paint paint = vg.makePaint();
	paint.fill(color::rgba(255, 120, 80));
	paint.stroke(color::rgba(100, 190, 80), 10);
	vg.drawPath(curve, paint);
}

fn void drawOpenStroke(MicroVG* vg) {
	path::Path line = vg.makePath();
	line.moveTo(520, 300);
	line.lineTo(600, 260);
	line.lineTo(700, 330);
	line.lineTo(820, 280);

	Paint paint = vg.makePaint();
	paint.stroke(color::rgba(245, 210, 75), 8);
	vg.drawPath(line, paint);
}

fn void drawQuadraticCurve(MicroVG* vg) {
	path::Path curve = vg.makePath();
	curve.moveTo(500, 420);
	curve.quadTo(660, 320, 820, 420);

	Paint paint = vg.makePaint();
	paint.stroke(color::rgba(120, 200, 255), 7);
	vg.drawPath(curve, paint);
}

fn void drawMultiSubpath(MicroVG* vg) {
	path::Path path = vg.makePath();
	path.moveTo(80, 420);
	path.lineTo(180, 420);
	path.lineTo(130, 500);
	path.close();
	path.moveTo(230, 420);
	path.lineTo(330, 420);
	path.lineTo(330, 500);
	path.lineTo(230, 500);
	path.close();

	Paint paint = vg.makePaint();
	paint.fill(color::rgba(90, 210, 150));
	paint.stroke(color::rgba(240, 240, 240), 3);
	vg.drawPath(path, paint);
}

fn void drawShapeHelpers(MicroVG* vg) {
	Paint paint = vg.makePaint();
	paint.fill(color::rgba(180, 120, 240, 180));
	paint.stroke(color::rgba(240, 240, 240), 2);

	path::Path rect = vg.makePath();
	rect.rect(60, 40, 110, 70);
	vg.drawPath(rect, paint);

	path::Path rounded = vg.makePath();
	rounded.roundedRect(210, 40, 130, 70, 18);
	vg.drawPath(rounded, paint);

	path::Path circle = vg.makePath();
	circle.circle(420, 75, 38);
	vg.drawPath(circle, paint);

	path::Path ellipse = vg.makePath();
	ellipse.ellipse(540, 75, 58, 34);
	vg.drawPath(ellipse, paint);
}

fn void drawArcToPath(MicroVG* vg) {
	path::Path path = vg.makePath();
	path.moveTo(650, 50);
	path.lineTo(780, 50);
	path.arcTo(850, 50, 850, 120, 36);
	path.lineTo(850, 145);

	Paint paint = vg.makePaint();
	paint.stroke(color::rgba(255, 155, 70), 6);
	vg.drawPath(path, paint);
}

fn void drawWindingFill(MicroVG* vg) {
	path::Path path = vg.makePath();
	path.rect(350, 350, 110, 110);
	path.rect(380, 380, 50, 50);

	Paint paint = vg.makePaint();
	paint.fill(color::rgba(80, 210, 210, 210));
	paint.rule(FillRule.EVEN_ODD);
	paint.stroke(color::rgba(240, 240, 240), 2);
	vg.drawPath(path, paint);
}

fn void drawConcaveFill(MicroVG* vg) {
	path::Path path = vg.makePath();
	path.moveTo(690, 390);
	path.lineTo(820, 390);
	path.lineTo(820, 500);
	path.lineTo(755, 460);
	path.lineTo(690, 500);
	path.lineTo(725, 445);
	path.close();

	Paint paint = vg.makePaint();
	paint.fill(color::rgba(230, 90, 145, 210));
	paint.stroke(color::rgba(240, 240, 240), 2);
	vg.drawPath(path, paint);
}

fn void drawStrokeStyles(MicroVG* vg) {
	path::Path roundPath = vg.makePath();
	roundPath.moveTo(450, 250);
	roundPath.lineTo(500, 205);
	roundPath.lineTo(550, 250);
	roundPath.lineTo(600, 205);

	Paint roundPaint = vg.makePaint();
	roundPaint.stroke(color::rgba(120, 220, 180), 16);
	roundPaint.cap(LineCap.ROUND);
	roundPaint.join(LineJoin.ROUND);
	vg.drawPath(roundPath, roundPaint);

	path::Path bevelPath = vg.makePath();
	bevelPath.moveTo(665, 250);
	bevelPath.lineTo(715, 205);
	bevelPath.lineTo(765, 250);
	bevelPath.lineTo(815, 205);

	Paint bevelPaint = vg.makePaint();
	bevelPaint.stroke(color::rgba(255, 175, 90), 16);
	bevelPaint.cap(LineCap.SQUARE);
	bevelPaint.join(LineJoin.BEVEL);
	vg.drawPath(bevelPath, bevelPaint);

	path::Path miterPath = vg.makePath();
	miterPath.moveTo(500, 340);
	miterPath.lineTo(610, 285);
	miterPath.lineTo(720, 340);

	Paint miterPaint = vg.makePaint();
	miterPaint.stroke(color::rgba(225, 235, 110), 16);
	miterPaint.cap(LineCap.BUTT);
	miterPaint.join(LineJoin.MITER);
	miterPaint.miter(6);
	vg.drawPath(miterPath, miterPaint);
}

fn void updateDebugTitle(GlfwWindow* window, MicroVG* vg) {
	DebugStats stats = vg.debugStats();
	glfw34::setWindowTitle(window, "MicroVG Debug");
	io::printfn(
		"MicroVG Debug | vertices %d/%d | calls %d/%d | commands %d/%d | tess fails %d | memory %d bytes/%d bytes",
		stats.vertices,
		stats.vertexCap,
		stats.drawCalls,
		stats.drawCallCap,
		stats.commands,
		stats.commandCap,
		stats.tessFails,
		stats.usedBytes,
		stats.reservedBytes
	);
}
