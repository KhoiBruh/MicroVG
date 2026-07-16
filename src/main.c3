import microvg;
import microvg::glbackend;
import glfw34;
import opengl;
import opengl::gl;
import std::core::mem;
import std::io;
import std::math;

extern fn int stbi_write_png(char* filename, int w, int h, int comp, void* data, int strideInBytes);

GlfwWindow* window;

fn void keyCallback(GlfwWindow* win, int key, int scancode, int action, int mods) {
    if (key == glfw34::KEY_ESCAPE && action == (int)glfw34::PRESS) {
        glfw34::setWindowShouldClose(win, glfw34::TRUE);
    }
}

fn void main(String[] args) {
    bool screenshot = false;
    foreach (a : args) {
        if (a == "screenshot") screenshot = true;
    }

    if (glfw34::init() == 0) {
        io::printn("Failed to init GLFW");
        return;
    }

    glfw34::windowHint(glfw34::CONTEXT_VERSION_MAJOR, 3);
    glfw34::windowHint(glfw34::CONTEXT_VERSION_MINOR, 3);
    glfw34::windowHint(glfw34::OPENGL_PROFILE, glfw34::OPENGL_CORE_PROFILE);
    glfw34::windowHint(glfw34::OPENGL_FORWARD_COMPAT, glfw34::TRUE);
    glfw34::windowHint(glfw34::SAMPLES, 4);

    window = glfw34::createWindow(1000, 600, "MicroVG Demo", null, null);
    if (window == null) {
        io::printn("Failed to create window");
        glfw34::terminate();
        return;
    }
    glfw34::setKeyCallback(window, &keyCallback);
    glfw34::makeContextCurrent(window);

    int loaded = opengl::init((GLLoadFn)&glfw34::getProcAddress) ?? -1;
    if (loaded <= 0) {
        io::printn("Failed to load OpenGL");
        glfw34::terminate();
        return;
    }
    io::printfn("OpenGL loaded (version tag %d)", loaded);

    microvg::MicroVG* vg = glbackend::nvgCreateGl3(glbackend::ANTIALIAS | glbackend::STENCIL_STROKES);
    defer vg.destroy();

    if (vg == null) {
        io::printn("Failed to create NanoVG context");
        glfw34::terminate();
        return;
    }

    glfw34::swapInterval(1);

    int frame = 0;
    while (glfw34::windowShouldClose(window) == 0) {
        int winW, winH;
        int fbW, fbH;
        glfw34::getWindowSize(window, &winW, &winH);
        glfw34::getFramebufferSize(window, &fbW, &fbH);
        float pxRatio = winW > 0 ? (float)fbW / (float)winW : 1.0f;

        gl::viewport(0, 0, fbW, fbH);
        gl::clearColor(0.12f, 0.12f, 0.14f, 1.0f);
        gl::clear(gl::GL_COLOR_BUFFER_BIT | gl::GL_DEPTH_BUFFER_BIT | gl::GL_STENCIL_BUFFER_BIT);

        double t = screenshot ? 1.0 : glfw34::getTime();

        vg.beginFrame((float)winW, (float)winH, pxRatio);
        drawScene(vg, (float)winW, (float)winH, (float)t);
        vg.endFrame();

        frame++;
        if (screenshot && frame >= 3) {
            saveScreenshot("build/microvg_screenshot.png", fbW, fbH);
            break;
        }

        glfw34::swapBuffers(window);
        glfw34::pollEvents();
    }

    glfw34::terminate();
    io::printn("Demo finished.");
}

fn void saveScreenshot(char* path, int w, int h) {
    if (w <= 0 || h <= 0) return;
    sz size = (sz)(w * h * 4);
    char* pixels = mem::malloc(size);
    if (pixels == null) return;
    defer mem::free(pixels);

    gl::readPixels(0, 0, w, h, gl::GL_RGBA, gl::GL_UNSIGNED_BYTE, pixels);

    char* flipped = mem::malloc(size);
    if (flipped == null) return;
    defer mem::free(flipped);
    int stride = w * 4;
    for (int y = 0; y < h; y++) {
        mem::copy(&flipped[y * stride], &pixels[(h - 1 - y) * stride], stride);
    }

    int ok = stbi_write_png(path, w, h, 4, flipped, stride);
    if (ok != 0) {
        io::printfn("Saved screenshot (%dx%d)", w, h);
    } else {
        io::printn("Failed to write screenshot");
    }
}

fn void drawScene(microvg::MicroVG* vg, float w, float h, float t) {
    vg.beginPath();
    vg.roundedRect(40.0f, 40.0f, 200.0f, 120.0f, 12.0f);
    vg.fillColor(microvg::rgba(70, 130, 220, 255));
    vg.fill();
    vg.strokeColor(microvg::rgba(255, 255, 255, 200));
    vg.strokeWidth(2.0f);
    vg.stroke();

    microvg::Paint lg = vg.linearGradient(40.0f, 200.0f, 240.0f, 320.0f,
        microvg::rgba(255, 160, 0, 255), microvg::rgba(255, 32, 120, 255));
    vg.beginPath();
    vg.roundedRect(40.0f, 200.0f, 200.0f, 120.0f, 12.0f);
    vg.fillPaint(lg);
    vg.fill();

    microvg::Paint rg = vg.radialGradient(360.0f, 100.0f, 10.0f, 60.0f,
        microvg::rgba(255, 255, 255, 255), microvg::rgba(40, 200, 160, 255));
    vg.beginPath();
    vg.circle(360.0f, 100.0f, 60.0f);
    vg.fillPaint(rg);
    vg.fill();

    microvg::Paint bg = vg.boxGradient(300.0f, 200.0f, 140.0f, 100.0f, 20.0f, 30.0f,
        microvg::rgba(255, 0, 0, 160), microvg::rgba(0, 0, 0, 0));
    vg.beginPath();
    vg.rect(280.0f, 180.0f, 200.0f, 160.0f);
    vg.fillPaint(bg);
    vg.fill();
    vg.beginPath();
    vg.roundedRect(300.0f, 200.0f, 140.0f, 100.0f, 10.0f);
    vg.fillColor(microvg::rgba(90, 90, 110, 255));
    vg.fill();

    vg.save();
    vg.beginPath();
    vg.moveTo(540.0f, 120.0f);
    for (int i = 0; i < 6; i++) {
        float fx = 540.0f + (float)i * 60.0f;
        float fy = 120.0f + math::sin(t * 2.0f + (float)i * 0.7f) * 50.0f;
        vg.lineTo(fx, fy);
    }
    vg.strokeColor(microvg::rgba(0, 220, 255, 255));
    vg.strokeWidth(6.0f);
    vg.lineCap(LineCap.ROUND);
    vg.lineJoin(LineJoin.ROUND);
    vg.stroke();
    vg.restore();

    vg.save();
    vg.translate(620.0f, 340.0f);
    vg.rotate(t);
    vg.beginPath();
    vg.rect(-40.0f, -40.0f, 80.0f, 80.0f);
    vg.fillColor(microvg::rgba(230, 90, 60, 230));
    vg.fill();
    vg.restore();

    vg.save();
    vg.scissor(720.0f, 260.0f, 120.0f, 80.0f);
    vg.beginPath();
    vg.circle(780.0f, 320.0f, 70.0f);
    vg.fillColor(microvg::rgba(255, 220, 60, 255));
    vg.fill();
    vg.restore();

    microvg::Paint eg = vg.linearGradient(720.0f, 40.0f, 960.0f, 200.0f,
        microvg::rgba(100, 200, 255, 255), microvg::rgba(200, 100, 255, 255));
    vg.beginPath();
    vg.ellipse(840.0f, 120.0f, 100.0f, 60.0f);
    vg.fillPaint(eg);
    vg.fill();
    vg.strokeColor(microvg::rgba(255, 255, 255, 180));
    vg.strokeWidth(3.0f);
    vg.stroke();

    vg.beginPath();
    vg.arc(160.0f, 440.0f, 50.0f, microvg::toRad(0.0f), microvg::toRad(270.0f), (int)Winding.CW);
    vg.strokeColor(microvg::rgba(255, 128, 0, 255));
    vg.strokeWidth(4.0f);
    vg.lineCap(LineCap.ROUND);
    vg.stroke();

    vg.save();
    vg.beginPath();
    vg.moveTo(300.0f, 400.0f);
    vg.lineTo(400.0f, 400.0f);
    vg.strokeColor(microvg::rgba(255, 80, 80, 255));
    vg.strokeWidth(6.0f);
    vg.lineCap(LineCap.BUTT);
    vg.stroke();

    vg.beginPath();
    vg.moveTo(300.0f, 430.0f);
    vg.lineTo(400.0f, 430.0f);
    vg.strokeColor(microvg::rgba(80, 255, 80, 255));
    vg.strokeWidth(6.0f);
    vg.lineCap(LineCap.ROUND);
    vg.stroke();

    vg.beginPath();
    vg.moveTo(300.0f, 460.0f);
    vg.lineTo(400.0f, 460.0f);
    vg.strokeColor(microvg::rgba(80, 80, 255, 255));
    vg.strokeWidth(6.0f);
    vg.lineCap(LineCap.SQUARE);
    vg.stroke();
    vg.restore();

    vg.save();
    vg.beginPath();
    vg.moveTo(500.0f, 400.0f);
    vg.lineTo(560.0f, 440.0f);
    vg.lineTo(620.0f, 400.0f);
    vg.strokeColor(microvg::rgba(255, 200, 0, 255));
    vg.strokeWidth(5.0f);
    vg.lineJoin(LineJoin.BEVEL);
    vg.lineCap(LineCap.ROUND);
    vg.stroke();

    vg.beginPath();
    vg.moveTo(500.0f, 460.0f);
    vg.lineTo(560.0f, 500.0f);
    vg.lineTo(620.0f, 460.0f);
    vg.strokeColor(microvg::rgba(0, 255, 200, 255));
    vg.strokeWidth(5.0f);
    vg.lineJoin(LineJoin.ROUND);
    vg.lineCap(LineCap.ROUND);
    vg.stroke();

    vg.beginPath();
    vg.moveTo(500.0f, 520.0f);
    vg.lineTo(560.0f, 560.0f);
    vg.lineTo(620.0f, 520.0f);
    vg.strokeColor(microvg::rgba(200, 0, 255, 255));
    vg.strokeWidth(5.0f);
    vg.lineJoin(LineJoin.MITER);
    vg.lineCap(LineCap.ROUND);
    vg.stroke();
    vg.restore();

    vg.beginPath();
    vg.roundedRectVarying(700.0f, 400.0f, 200.0f, 100.0f, 20.0f, 5.0f, 30.0f, 10.0f);
    microvg::Paint rrg = vg.radialGradient(800.0f, 450.0f, 10.0f, 80.0f,
        microvg::rgba(255, 100, 100, 255), microvg::rgba(100, 100, 255, 255));
    vg.fillPaint(rrg);
    vg.fill();
    vg.strokeColor(microvg::rgba(255, 255, 255, 150));
    vg.strokeWidth(2.0f);
    vg.stroke();
}
