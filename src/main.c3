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

    microvg::NvgContext* vg = glbackend::nvgCreateGl3(glbackend::NVG_ANTIALIAS | glbackend::NVG_STENCIL_STROKES);
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

        microvg::nvgBeginFrame(vg, (float)winW, (float)winH, pxRatio);
        drawScene(vg, (float)winW, (float)winH, (float)t);
        microvg::nvgEndFrame(vg);

        frame++;
        if (screenshot && frame >= 3) {
            saveScreenshot("build/microvg_screenshot.png", fbW, fbH);
            break;
        }

        glfw34::swapBuffers(window);
        glfw34::pollEvents();
    }

    glbackend::nvgDeleteGl3(vg);
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

fn void drawScene(microvg::NvgContext* vg, float w, float h, float t) {
    microvg::nvgBeginPath(vg);
    microvg::nvgRoundedRect(vg, 40.0f, 40.0f, 200.0f, 120.0f, 12.0f);
    microvg::nvgFillColor(vg, microvg::nvgRgba(70, 130, 220, 255));
    microvg::nvgFill(vg);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(255, 255, 255, 200));
    microvg::nvgStrokeWidth(vg, 2.0f);
    microvg::nvgStroke(vg);

    microvg::NvgPaint lg = microvg::nvgLinearGradient(vg, 40.0f, 200.0f, 240.0f, 320.0f,
        microvg::nvgRgba(255, 160, 0, 255), microvg::nvgRgba(255, 32, 120, 255));
    microvg::nvgBeginPath(vg);
    microvg::nvgRoundedRect(vg, 40.0f, 200.0f, 200.0f, 120.0f, 12.0f);
    microvg::nvgFillPaint(vg, lg);
    microvg::nvgFill(vg);

    microvg::NvgPaint rg = microvg::nvgRadialGradient(vg, 360.0f, 100.0f, 10.0f, 60.0f,
        microvg::nvgRgba(255, 255, 255, 255), microvg::nvgRgba(40, 200, 160, 255));
    microvg::nvgBeginPath(vg);
    microvg::nvgCircle(vg, 360.0f, 100.0f, 60.0f);
    microvg::nvgFillPaint(vg, rg);
    microvg::nvgFill(vg);

    microvg::NvgPaint bg = microvg::nvgBoxGradient(vg, 300.0f, 200.0f, 140.0f, 100.0f, 20.0f, 30.0f,
        microvg::nvgRgba(0, 0, 0, 160), microvg::nvgRgba(0, 0, 0, 0));
    microvg::nvgBeginPath(vg);
    microvg::nvgRect(vg, 280.0f, 180.0f, 200.0f, 160.0f);
    microvg::nvgFillPaint(vg, bg);
    microvg::nvgFill(vg);
    microvg::nvgBeginPath(vg);
    microvg::nvgRoundedRect(vg, 300.0f, 200.0f, 140.0f, 100.0f, 10.0f);
    microvg::nvgFillColor(vg, microvg::nvgRgba(90, 90, 110, 255));
    microvg::nvgFill(vg);

    microvg::nvgSave(vg);
    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 540.0f, 120.0f);
    for (int i = 0; i < 6; i++) {
        float fx = 540.0f + (float)i * 60.0f;
        float fy = 120.0f + math::sin(t * 2.0f + (float)i * 0.7f) * 50.0f;
        microvg::nvgLineTo(vg, fx, fy);
    }
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(0, 220, 255, 255));
    microvg::nvgStrokeWidth(vg, 6.0f);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_ROUND);
    microvg::nvgLineJoin(vg, microvg::LINE_JOIN_ROUND);
    microvg::nvgStroke(vg);
    microvg::nvgRestore(vg);

    microvg::nvgSave(vg);
    microvg::nvgTranslate(vg, 620.0f, 340.0f);
    microvg::nvgRotate(vg, t);
    microvg::nvgBeginPath(vg);
    microvg::nvgRect(vg, -40.0f, -40.0f, 80.0f, 80.0f);
    microvg::nvgFillColor(vg, microvg::nvgRgba(230, 90, 60, 230));
    microvg::nvgFill(vg);
    microvg::nvgRestore(vg);

    microvg::nvgSave(vg);
    microvg::nvgScissor(vg, 720.0f, 260.0f, 120.0f, 80.0f);
    microvg::nvgBeginPath(vg);
    microvg::nvgCircle(vg, 780.0f, 320.0f, 70.0f);
    microvg::nvgFillColor(vg, microvg::nvgRgba(255, 220, 60, 255));
    microvg::nvgFill(vg);
    microvg::nvgRestore(vg);

    microvg::NvgPaint eg = microvg::nvgLinearGradient(vg, 720.0f, 40.0f, 960.0f, 200.0f,
        microvg::nvgRgba(100, 200, 255, 255), microvg::nvgRgba(200, 100, 255, 255));
    microvg::nvgBeginPath(vg);
    microvg::nvgEllipse(vg, 840.0f, 120.0f, 100.0f, 60.0f);
    microvg::nvgFillPaint(vg, eg);
    microvg::nvgFill(vg);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(255, 255, 255, 180));
    microvg::nvgStrokeWidth(vg, 3.0f);
    microvg::nvgStroke(vg);

    microvg::nvgBeginPath(vg);
    microvg::nvgArc(vg, 160.0f, 440.0f, 50.0f, microvg::nvgDegToRad(0.0f), microvg::nvgDegToRad(270.0f), microvg::WINDING_CW);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(255, 128, 0, 255));
    microvg::nvgStrokeWidth(vg, 4.0f);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_ROUND);
    microvg::nvgStroke(vg);

    microvg::nvgSave(vg);
    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 300.0f, 400.0f);
    microvg::nvgLineTo(vg, 400.0f, 400.0f);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(255, 80, 80, 255));
    microvg::nvgStrokeWidth(vg, 6.0f);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_BUTT);
    microvg::nvgStroke(vg);

    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 300.0f, 430.0f);
    microvg::nvgLineTo(vg, 400.0f, 430.0f);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(80, 255, 80, 255));
    microvg::nvgStrokeWidth(vg, 6.0f);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_ROUND);
    microvg::nvgStroke(vg);

    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 300.0f, 460.0f);
    microvg::nvgLineTo(vg, 400.0f, 460.0f);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(80, 80, 255, 255));
    microvg::nvgStrokeWidth(vg, 6.0f);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_SQUARE);
    microvg::nvgStroke(vg);
    microvg::nvgRestore(vg);

    microvg::nvgSave(vg);
    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 500.0f, 400.0f);
    microvg::nvgLineTo(vg, 560.0f, 440.0f);
    microvg::nvgLineTo(vg, 620.0f, 400.0f);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(255, 200, 0, 255));
    microvg::nvgStrokeWidth(vg, 5.0f);
    microvg::nvgLineJoin(vg, microvg::LINE_JOIN_BEVEL);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_ROUND);
    microvg::nvgStroke(vg);

    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 500.0f, 460.0f);
    microvg::nvgLineTo(vg, 560.0f, 500.0f);
    microvg::nvgLineTo(vg, 620.0f, 460.0f);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(0, 255, 200, 255));
    microvg::nvgStrokeWidth(vg, 5.0f);
    microvg::nvgLineJoin(vg, microvg::LINE_JOIN_ROUND);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_ROUND);
    microvg::nvgStroke(vg);

    microvg::nvgBeginPath(vg);
    microvg::nvgMoveTo(vg, 500.0f, 520.0f);
    microvg::nvgLineTo(vg, 560.0f, 560.0f);
    microvg::nvgLineTo(vg, 620.0f, 520.0f);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(200, 0, 255, 255));
    microvg::nvgStrokeWidth(vg, 5.0f);
    microvg::nvgLineJoin(vg, microvg::LINE_JOIN_MITER);
    microvg::nvgLineCap(vg, microvg::LINE_CAP_ROUND);
    microvg::nvgStroke(vg);
    microvg::nvgRestore(vg);

    microvg::nvgBeginPath(vg);
    microvg::nvgRoundedRectVarying(vg, 700.0f, 400.0f, 200.0f, 100.0f, 20.0f, 5.0f, 30.0f, 10.0f);
    microvg::NvgPaint rrg = microvg::nvgRadialGradient(vg, 800.0f, 450.0f, 10.0f, 80.0f,
        microvg::nvgRgba(255, 100, 100, 255), microvg::nvgRgba(100, 100, 255, 255));
    microvg::nvgFillPaint(vg, rrg);
    microvg::nvgFill(vg);
    microvg::nvgStrokeColor(vg, microvg::nvgRgba(255, 255, 255, 150));
    microvg::nvgStrokeWidth(vg, 2.0f);
    microvg::nvgStroke(vg);
}
