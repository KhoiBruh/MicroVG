module microvg;

import libc;
import std::math;

extern fn float fmodf(float a, float b);
extern fn int printf(char* fmt, ...);

const int NVG_MOVETO   = 0;
const int NVG_LINETO   = 1;
const int NVG_BEZIERTO = 2;
const int NVG_CLOSE    = 3;
const int NVG_WINDING  = 4;

const int NVG_PT_CORNER     = 0x01;
const int NVG_PT_LEFT       = 0x02;
const int NVG_PT_BEVEL      = 0x04;
const int NVG_PR_INNERBEVEL = 0x08;

const int NVG_INIT_COMMANDS_SIZE = 256;
const int NVG_INIT_POINTS_SIZE   = 128;
const int NVG_INIT_PATHS_SIZE    = 16;
const int NVG_INIT_VERTS_SIZE    = 256;

const int NVG_MAX_STATES = 32;

const float NVG_KAPPA90 = 0.5522847493f;

struct NvgState {
    NvgCompositeOperationState compositeOperation;
    int   shapeAntiAlias;
    NvgPaint fill;
    NvgPaint stroke;
    float strokeWidth;
    float miterLimit;
    int   lineJoin;
    int   lineCap;
    float alpha;
    float[6] xform;
    NvgScissor scissor;
}

struct NvgPoint {
    float x, y;
    float dx, dy;
    float len;
    float dmx, dmy;
    char  flags;
}

struct NvgPathCache {
    NvgPoint* points;
    int npoints;
    int cpoints;
    NvgPath* paths;
    int npaths;
    int cpaths;
    NvgVertex* verts;
    int nverts;
    int cverts;
    float[4] bounds;
}

struct NvgContext {
    NvgParams params;
    float* commands;
    int ccommands;
    int ncommands;
    float commandx, commandy;
    NvgState[NVG_MAX_STATES] states;
    int nstates;
    NvgPathCache* cache;
    float tessTol;
    float distTol;
    float fringeWidth;
    float devicePxRatio;
    int drawCallCount;
    int fillTriCount;
    int strokeTriCount;
    int textTriCount;
}

fn float nvgSqrtf(float a) @local { return math::sqrt(a); }
fn float nvgModf(float a, float b) @local { return fmodf(a, b); }
fn float nvgSinf(float a) @local { return math::sin(a); }
fn float nvgCosf(float a) @local { return math::cos(a); }
fn float nvgTanf(float a) @local { return math::tan(a); }
fn float nvgAtan2f(float a, float b) @local { return math::atan2(a, b); }
fn float nvgAcosf(float a) @local { return math::acos(a); }

fn int nvgMini(int a, int b) @local { return a < b ? a : b; }
fn int nvgMaxi(int a, int b) @local { return a > b ? a : b; }
fn int nvgClampi(int a, int mn, int mx) @local { return a < mn ? mn : (a > mx ? mx : a); }
fn float nvgMinf(float a, float b) @local { return a < b ? a : b; }
fn float nvgMaxf(float a, float b) @local { return a > b ? a : b; }
fn float nvgAbsf(float a) @local { return a >= 0.0f ? a : -a; }
fn float nvgSignf(float a) @local { return a >= 0.0f ? 1.0f : -1.0f; }
fn float nvgClampf(float a, float mn, float mx) @local { return a < mn ? mn : (a > mx ? mx : a); }
fn float nvgCross(float dx0, float dy0, float dx1, float dy1) @local { return dx1 * dy0 - dx0 * dy1; }

fn float nvgNormalize(float* x, float* y) @local {
    float d = nvgSqrtf(x[0] * x[0] + y[0] * y[0]);
    if (d > 1e-6f) {
        float id = 1.0f / d;
        x[0] *= id;
        y[0] *= id;
    }
    return d;
}

fn void nvgDeletePathCache(NvgPathCache* c) @local {
    if (c == null) return;
    if (c.points != null) libc::free(c.points);
    if (c.paths  != null) libc::free(c.paths);
    if (c.verts  != null) libc::free(c.verts);
    libc::free(c);
}

fn NvgPathCache* nvgAllocPathCache() @local {
    NvgPathCache* c = (NvgPathCache*)libc::malloc(NvgPathCache::size);
    if (c == null) return null;
    libc::memset(c, 0, NvgPathCache::size);

    c.points = (NvgPoint*)libc::malloc(NvgPoint::size * (usz)NVG_INIT_POINTS_SIZE);
    if (c.points == null) { nvgDeletePathCache(c); return null; }
    c.npoints = 0;
    c.cpoints = NVG_INIT_POINTS_SIZE;

    c.paths = (NvgPath*)libc::malloc(NvgPath::size * (usz)NVG_INIT_PATHS_SIZE);
    if (c.paths == null) { nvgDeletePathCache(c); return null; }
    c.npaths = 0;
    c.cpaths = NVG_INIT_PATHS_SIZE;

    c.verts = (NvgVertex*)libc::malloc(NvgVertex::size * (usz)NVG_INIT_VERTS_SIZE);
    if (c.verts == null) { nvgDeletePathCache(c); return null; }
    c.nverts = 0;
    c.cverts = NVG_INIT_VERTS_SIZE;

    return c;
}

fn void nvgSetDevicePixelRatio(NvgContext* ctx, float ratio) @local {
    ctx.tessTol = 0.25f / ratio;
    ctx.distTol = 0.01f / ratio;
    ctx.fringeWidth = 1.0f / ratio;
    ctx.devicePxRatio = ratio;
}

fn NvgCompositeOperationState nvgCompositeOpState(int op) @local {
    int sfactor;
    int dfactor;

    if (op == COMPOSITE_SOURCE_OVER) {
        sfactor = BLEND_ONE;
        dfactor = BLEND_ONE_MINUS_SRC_ALPHA;
    } else if (op == COMPOSITE_SOURCE_IN) {
        sfactor = BLEND_DST_ALPHA;
        dfactor = BLEND_ZERO;
    } else if (op == COMPOSITE_SOURCE_OUT) {
        sfactor = BLEND_ONE_MINUS_DST_ALPHA;
        dfactor = BLEND_ZERO;
    } else if (op == COMPOSITE_ATOP) {
        sfactor = BLEND_DST_ALPHA;
        dfactor = BLEND_ONE_MINUS_SRC_ALPHA;
    } else if (op == COMPOSITE_DESTINATION_OVER) {
        sfactor = BLEND_ONE_MINUS_DST_ALPHA;
        dfactor = BLEND_ONE;
    } else if (op == COMPOSITE_DESTINATION_IN) {
        sfactor = BLEND_ZERO;
        dfactor = BLEND_SRC_ALPHA;
    } else if (op == COMPOSITE_DESTINATION_OUT) {
        sfactor = BLEND_ZERO;
        dfactor = BLEND_ONE_MINUS_SRC_ALPHA;
    } else if (op == COMPOSITE_DESTINATION_ATOP) {
        sfactor = BLEND_ONE_MINUS_DST_ALPHA;
        dfactor = BLEND_SRC_ALPHA;
    } else if (op == COMPOSITE_LIGHTER) {
        sfactor = BLEND_ONE;
        dfactor = BLEND_ONE;
    } else if (op == COMPOSITE_COPY) {
        sfactor = BLEND_ONE;
        dfactor = BLEND_ZERO;
    } else if (op == COMPOSITE_XOR) {
        sfactor = BLEND_ONE_MINUS_DST_ALPHA;
        dfactor = BLEND_ONE_MINUS_SRC_ALPHA;
    } else {
        sfactor = BLEND_ONE;
        dfactor = BLEND_ZERO;
    }

    NvgCompositeOperationState state;
    state.srcRGB   = sfactor;
    state.dstRGB   = dfactor;
    state.srcAlpha = sfactor;
    state.dstAlpha = dfactor;
    return state;
}

fn NvgState* nvgGetState(NvgContext* ctx) @local {
    return &ctx.states[ctx.nstates - 1];
}

fn void nvgSetPaintColor(NvgPaint* p, NvgColor color) @local {
    libc::memset(p, 0, NvgPaint::size);
    nvgTransformIdentity(&p.xform[0]);
    p.radius = 0.0f;
    p.feather = 1.0f;
    p.innerColor = color;
    p.outerColor = color;
}

fn float nvgHue(float h, float m1, float m2) @local {
    if (h < 0) h += 1;
    if (h > 1) h -= 1;
    if (h < 1.0f / 6.0f) {
        return m1 + (m2 - m1) * h * 6.0f;
    }
    else if (h < 3.0f / 6.0f) {
        return m2;
    }
    else if (h < 4.0f / 6.0f) {
        return m1 + (m2 - m1) * (2.0f / 3.0f - h) * 6.0f;
    }
    return m1;
}

fn NvgContext* nvgCreateInternal(NvgParams* params) {
    NvgContext* ctx = (NvgContext*)libc::malloc(NvgContext::size);
    if (ctx == null) return null;
    libc::memset(ctx, 0, NvgContext::size);

    ctx.params = params[0];

    ctx.commands = (float*)libc::malloc(float::size * (usz)NVG_INIT_COMMANDS_SIZE);
    if (ctx.commands == null) { nvgDeleteInternal(ctx); return null; }
    ctx.ncommands = 0;
    ctx.ccommands = NVG_INIT_COMMANDS_SIZE;

    ctx.cache = nvgAllocPathCache();
    if (ctx.cache == null) { nvgDeleteInternal(ctx); return null; }

    nvgSave(ctx);
    nvgReset(ctx);

    nvgSetDevicePixelRatio(ctx, 1.0f);

    if (ctx.params.renderCreate(ctx.params.userPtr) == 0) { nvgDeleteInternal(ctx); return null; }

    return ctx;
}

fn NvgParams* nvgInternalParams(NvgContext* ctx) {
    return &ctx.params;
}

fn void nvgDeleteInternal(NvgContext* ctx) {
    if (ctx == null) return;
    if (ctx.commands != null) libc::free(ctx.commands);
    if (ctx.cache != null) nvgDeletePathCache(ctx.cache);

    if (ctx.params.renderDelete != null) {
        ctx.params.renderDelete(ctx.params.userPtr);
    }

    libc::free(ctx);
}

fn void nvgBeginFrame(NvgContext* ctx, float windowWidth, float windowHeight, float devicePixelRatio) {
    ctx.nstates = 0;
    nvgSave(ctx);
    nvgReset(ctx);

    nvgSetDevicePixelRatio(ctx, devicePixelRatio);

    ctx.params.renderViewport(ctx.params.userPtr, windowWidth, windowHeight, devicePixelRatio);

    ctx.drawCallCount  = 0;
    ctx.fillTriCount   = 0;
    ctx.strokeTriCount = 0;
    ctx.textTriCount   = 0;
}

fn void nvgCancelFrame(NvgContext* ctx) {
    ctx.params.renderCancel(ctx.params.userPtr);
}

fn void nvgEndFrame(NvgContext* ctx) {
    ctx.params.renderFlush(ctx.params.userPtr);
}

fn NvgColor nvgRgb(char r, char g, char b) {
    return nvgRgba(r, g, b, 255);
}

fn NvgColor nvgRgbf(float r, float g, float b) {
    return nvgRgbaf(r, g, b, 1.0f);
}

fn NvgColor nvgRgba(char r, char g, char b, char a) {
    NvgColor color;
    color.r = r / 255.0f;
    color.g = g / 255.0f;
    color.b = b / 255.0f;
    color.a = a / 255.0f;
    return color;
}

fn NvgColor nvgRgbaf(float r, float g, float b, float a) {
    NvgColor color;
    color.r = r;
    color.g = g;
    color.b = b;
    color.a = a;
    return color;
}

fn NvgColor nvgTransRgba(NvgColor c, char a) {
    c.a = a / 255.0f;
    return c;
}

fn NvgColor nvgTransRgbaf(NvgColor c, float a) {
    c.a = a;
    return c;
}

fn NvgColor nvgLerpRgba(NvgColor c0, NvgColor c1, float u) {
    NvgColor cint;
    libc::memset(&cint, 0, NvgColor::size);
    u = nvgClampf(u, 0.0f, 1.0f);
    float oneminu = 1.0f - u;
    for (int i = 0; i < 4; i++) {
        cint.rgba[i] = c0.rgba[i] * oneminu + c1.rgba[i] * u;
    }
    return cint;
}

fn NvgColor nvgHsl(float h, float s, float l) {
    return nvgHsla(h, s, l, 255);
}

fn NvgColor nvgHsla(float h, float s, float l, char a) {
    NvgColor col;
    h = nvgModf(h, 1.0f);
    if (h < 0.0f) h += 1.0f;
    s = nvgClampf(s, 0.0f, 1.0f);
    l = nvgClampf(l, 0.0f, 1.0f);
    float m2 = l <= 0.5f ? (l * (1 + s)) : (l + s - l * s);
    float m1 = 2 * l - m2;
    col.r = nvgClampf(nvgHue(h + 1.0f / 3.0f, m1, m2), 0.0f, 1.0f);
    col.g = nvgClampf(nvgHue(h, m1, m2), 0.0f, 1.0f);
    col.b = nvgClampf(nvgHue(h - 1.0f / 3.0f, m1, m2), 0.0f, 1.0f);
    col.a = a / 255.0f;
    return col;
}

fn void nvgTransformIdentity(float* t) {
    t[0] = 1.0f; t[1] = 0.0f;
    t[2] = 0.0f; t[3] = 1.0f;
    t[4] = 0.0f; t[5] = 0.0f;
}

fn void nvgTransformTranslate(float* t, float tx, float ty) {
    t[0] = 1.0f; t[1] = 0.0f;
    t[2] = 0.0f; t[3] = 1.0f;
    t[4] = tx;   t[5] = ty;
}

fn void nvgTransformScale(float* t, float sx, float sy) {
    t[0] = sx;   t[1] = 0.0f;
    t[2] = 0.0f; t[3] = sy;
    t[4] = 0.0f; t[5] = 0.0f;
}

fn void nvgTransformRotate(float* t, float a) {
    float cs = nvgCosf(a);
    float sn = nvgSinf(a);
    t[0] = cs;  t[1] = sn;
    t[2] = -sn; t[3] = cs;
    t[4] = 0.0f; t[5] = 0.0f;
}

fn void nvgTransformSkewX(float* t, float a) {
    t[0] = 1.0f; t[1] = 0.0f;
    t[2] = nvgTanf(a); t[3] = 1.0f;
    t[4] = 0.0f; t[5] = 0.0f;
}

fn void nvgTransformSkewY(float* t, float a) {
    t[0] = 1.0f; t[1] = nvgTanf(a);
    t[2] = 0.0f; t[3] = 1.0f;
    t[4] = 0.0f; t[5] = 0.0f;
}

fn void nvgTransformMultiply(float* t, float* s) {
    float t0 = t[0] * s[0] + t[1] * s[2];
    float t2 = t[2] * s[0] + t[3] * s[2];
    float t4 = t[4] * s[0] + t[5] * s[2] + s[4];
    t[1] = t[0] * s[1] + t[1] * s[3];
    t[3] = t[2] * s[1] + t[3] * s[3];
    t[5] = t[4] * s[1] + t[5] * s[3] + s[5];
    t[0] = t0;
    t[2] = t2;
    t[4] = t4;
}

fn void nvgTransformPremultiply(float* t, float* s) {
    float[6] s2;
    libc::memcpy(&s2[0], s, float::size * 6);
    nvgTransformMultiply(&s2[0], t);
    libc::memcpy(t, &s2[0], float::size * 6);
}

fn int nvgTransformInverse(float* inv, float* t) {
    double det = (double)t[0] * t[3] - (double)t[2] * t[1];
    if (det > -1e-6 && det < 1e-6) {
        nvgTransformIdentity(inv);
        return 0;
    }
    double invdet = 1.0 / det;
    inv[0] = (float)((double)t[3] * invdet);
    inv[2] = (float)(-(double)t[2] * invdet);
    inv[4] = (float)(((double)t[2] * t[5] - (double)t[3] * t[4]) * invdet);
    inv[1] = (float)(-(double)t[1] * invdet);
    inv[3] = (float)((double)t[0] * invdet);
    inv[5] = (float)(((double)t[1] * t[4] - (double)t[0] * t[5]) * invdet);
    return 1;
}

fn void nvgTransformPoint(float* dx, float* dy, float* t, float sx, float sy) {
    dx[0] = sx * t[0] + sy * t[2] + t[4];
    dy[0] = sx * t[1] + sy * t[3] + t[5];
}

fn float nvgDegToRad(float deg) {
    return deg / 180.0f * PI;
}

fn float nvgRadToDeg(float rad) {
    return rad / PI * 180.0f;
}

fn void nvgSave(NvgContext* ctx) {
    if (ctx.nstates >= NVG_MAX_STATES) {
        return;
    }
    if (ctx.nstates > 0) {
        libc::memcpy(&ctx.states[ctx.nstates], &ctx.states[ctx.nstates - 1], NvgState::size);
    }
    ctx.nstates++;
}

fn void nvgRestore(NvgContext* ctx) {
    if (ctx.nstates <= 1) {
        return;
    }
    ctx.nstates--;
}

fn void nvgReset(NvgContext* ctx) {
    NvgState* state = nvgGetState(ctx);
    libc::memset(state, 0, NvgState::size);

    nvgSetPaintColor(&state.fill, nvgRgba(255, 255, 255, 255));
    nvgSetPaintColor(&state.stroke, nvgRgba(0, 0, 0, 255));
    state.compositeOperation = nvgCompositeOpState(COMPOSITE_SOURCE_OVER);
    state.shapeAntiAlias = 1;
    state.strokeWidth = 1.0f;
    state.miterLimit = 10.0f;
    state.lineCap = LINE_CAP_BUTT;
    state.lineJoin = LINE_JOIN_MITER;
    state.alpha = 1.0f;
    nvgTransformIdentity(&state.xform[0]);

    state.scissor.extent[0] = -1.0f;
    state.scissor.extent[1] = -1.0f;
}

fn void nvgShapeAntiAlias(NvgContext* ctx, int enabled) {
    NvgState* state = nvgGetState(ctx);
    state.shapeAntiAlias = enabled;
}

fn void nvgStrokeWidth(NvgContext* ctx, float width) {
    NvgState* state = nvgGetState(ctx);
    state.strokeWidth = width;
}

fn void nvgMiterLimit(NvgContext* ctx, float limit) {
    NvgState* state = nvgGetState(ctx);
    state.miterLimit = limit;
}

fn void nvgLineCap(NvgContext* ctx, int cap) {
    NvgState* state = nvgGetState(ctx);
    state.lineCap = cap;
}

fn void nvgLineJoin(NvgContext* ctx, int join) {
    NvgState* state = nvgGetState(ctx);
    state.lineJoin = join;
}

fn void nvgGlobalAlpha(NvgContext* ctx, float alpha) {
    NvgState* state = nvgGetState(ctx);
    state.alpha = alpha;
}

fn void nvgTransform(NvgContext* ctx, float a, float b, float c, float d, float e, float f) {
    NvgState* state = nvgGetState(ctx);
    float[6] t = { a, b, c, d, e, f };
    nvgTransformPremultiply(&state.xform[0], &t[0]);
}

fn void nvgResetTransform(NvgContext* ctx) {
    NvgState* state = nvgGetState(ctx);
    nvgTransformIdentity(&state.xform[0]);
}

fn void nvgTranslate(NvgContext* ctx, float x, float y) {
    NvgState* state = nvgGetState(ctx);
    float[6] t;
    nvgTransformTranslate(&t[0], x, y);
    nvgTransformPremultiply(&state.xform[0], &t[0]);
}

fn void nvgRotate(NvgContext* ctx, float angle) {
    NvgState* state = nvgGetState(ctx);
    float[6] t;
    nvgTransformRotate(&t[0], angle);
    nvgTransformPremultiply(&state.xform[0], &t[0]);
}

fn void nvgSkewX(NvgContext* ctx, float angle) {
    NvgState* state = nvgGetState(ctx);
    float[6] t;
    nvgTransformSkewX(&t[0], angle);
    nvgTransformPremultiply(&state.xform[0], &t[0]);
}

fn void nvgSkewY(NvgContext* ctx, float angle) {
    NvgState* state = nvgGetState(ctx);
    float[6] t;
    nvgTransformSkewY(&t[0], angle);
    nvgTransformPremultiply(&state.xform[0], &t[0]);
}

fn void nvgScale(NvgContext* ctx, float x, float y) {
    NvgState* state = nvgGetState(ctx);
    float[6] t;
    nvgTransformScale(&t[0], x, y);
    nvgTransformPremultiply(&state.xform[0], &t[0]);
}

fn void nvgCurrentTransform(NvgContext* ctx, float* xform) {
    NvgState* state = nvgGetState(ctx);
    if (xform == null) return;
    libc::memcpy(xform, &state.xform[0], float::size * 6);
}

fn void nvgStrokeColor(NvgContext* ctx, NvgColor color) {
    NvgState* state = nvgGetState(ctx);
    nvgSetPaintColor(&state.stroke, color);
}

fn void nvgStrokePaint(NvgContext* ctx, NvgPaint paint) {
    NvgState* state = nvgGetState(ctx);
    state.stroke = paint;
    nvgTransformMultiply(&state.stroke.xform[0], &state.xform[0]);
}

fn void nvgFillColor(NvgContext* ctx, NvgColor color) {
    NvgState* state = nvgGetState(ctx);
    nvgSetPaintColor(&state.fill, color);
}

fn void nvgFillPaint(NvgContext* ctx, NvgPaint paint) {
    NvgState* state = nvgGetState(ctx);
    state.fill = paint;
    nvgTransformMultiply(&state.fill.xform[0], &state.xform[0]);
}

fn int nvgCreateImageRgba(NvgContext* ctx, int w, int h, int imageFlags, char* data) {
    return ctx.params.renderCreateTexture(ctx.params.userPtr, TEXTURE_RGBA, w, h, imageFlags, data);
}

fn void nvgUpdateImage(NvgContext* ctx, int image, char* data) {
    int w, h;
    ctx.params.renderGetTextureSize(ctx.params.userPtr, image, &w, &h);
    ctx.params.renderUpdateTexture(ctx.params.userPtr, image, 0, 0, w, h, data);
}

fn void nvgImageSize(NvgContext* ctx, int image, int* w, int* h) {
    ctx.params.renderGetTextureSize(ctx.params.userPtr, image, w, h);
}

fn void nvgDeleteImage(NvgContext* ctx, int image) {
    ctx.params.renderDeleteTexture(ctx.params.userPtr, image);
}

fn NvgPaint nvgLinearGradient(NvgContext* ctx, float sx, float sy, float ex, float ey,
                                NvgColor icol, NvgColor ocol) {
    NvgPaint p;
    float large = 1e5f;
    libc::memset(&p, 0, NvgPaint::size);

    float dx = ex - sx;
    float dy = ey - sy;
    float d = nvgSqrtf(dx * dx + dy * dy);
    if (d > 0.0001f) {
        dx /= d;
        dy /= d;
    } else {
        dx = 0;
        dy = 1;
    }

    p.xform[0] = dy;  p.xform[1] = -dx;
    p.xform[2] = dx;  p.xform[3] = dy;
    p.xform[4] = sx - dx * large; p.xform[5] = sy - dy * large;

    p.extent[0] = large;
    p.extent[1] = large + d * 0.5f;

    p.radius = 0.0f;

    p.feather = nvgMaxf(1.0f, d);

    p.innerColor = icol;
    p.outerColor = ocol;

    return p;
}

fn NvgPaint nvgRadialGradient(NvgContext* ctx, float cx, float cy, float inr, float outr,
                               NvgColor icol, NvgColor ocol) {
    NvgPaint p;
    float r = (inr + outr) * 0.5f;
    float f = (outr - inr);
    libc::memset(&p, 0, NvgPaint::size);

    nvgTransformIdentity(&p.xform[0]);
    p.xform[4] = cx;
    p.xform[5] = cy;

    p.extent[0] = r;
    p.extent[1] = r;

    p.radius = r;

    p.feather = nvgMaxf(1.0f, f);

    p.innerColor = icol;
    p.outerColor = ocol;

    return p;
}

fn NvgPaint nvgBoxGradient(NvgContext* ctx, float x, float y, float w, float h, float r, float f,
                            NvgColor icol, NvgColor ocol) {
    NvgPaint p;
    libc::memset(&p, 0, NvgPaint::size);

    nvgTransformIdentity(&p.xform[0]);
    p.xform[4] = x + w * 0.5f;
    p.xform[5] = y + h * 0.5f;

    p.extent[0] = w * 0.5f;
    p.extent[1] = h * 0.5f;

    p.radius = r;

    p.feather = nvgMaxf(1.0f, f);

    p.innerColor = icol;
    p.outerColor = ocol;

    return p;
}

fn NvgPaint nvgImagePattern(NvgContext* ctx, float cx, float cy, float w, float h, float angle,
                             int image, float alpha) {
    NvgPaint p;
    libc::memset(&p, 0, NvgPaint::size);

    nvgTransformRotate(&p.xform[0], angle);
    p.xform[4] = cx;
    p.xform[5] = cy;

    p.extent[0] = w;
    p.extent[1] = h;

    p.image = image;

    p.outerColor = nvgRgbaf(1, 1, 1, alpha);
    p.innerColor = p.outerColor;

    return p;
}

fn void nvgScissor(NvgContext* ctx, float x, float y, float w, float h) {
    NvgState* state = nvgGetState(ctx);

    w = nvgMaxf(0.0f, w);
    h = nvgMaxf(0.0f, h);

    nvgTransformIdentity(&state.scissor.xform[0]);
    state.scissor.xform[4] = x + w * 0.5f;
    state.scissor.xform[5] = y + h * 0.5f;
    nvgTransformMultiply(&state.scissor.xform[0], &state.xform[0]);

    state.scissor.extent[0] = w * 0.5f;
    state.scissor.extent[1] = h * 0.5f;
}

fn void nvgIsectRects(float* dst, float ax, float ay, float aw, float ah,
                       float bx, float by, float bw, float bh) @local {
    float minx = nvgMaxf(ax, bx);
    float miny = nvgMaxf(ay, by);
    float maxx = nvgMinf(ax + aw, bx + bw);
    float maxy = nvgMinf(ay + ah, by + bh);
    dst[0] = minx;
    dst[1] = miny;
    dst[2] = nvgMaxf(0.0f, maxx - minx);
    dst[3] = nvgMaxf(0.0f, maxy - miny);
}

fn void nvgIntersectScissor(NvgContext* ctx, float x, float y, float w, float h) {
    NvgState* state = nvgGetState(ctx);
    float[6] pxform;
    float[6] invxorm;
    float[4] rect;

    if (state.scissor.extent[0] < 0) {
        nvgScissor(ctx, x, y, w, h);
        return;
    }

    libc::memcpy(&pxform[0], &state.scissor.xform[0], float::size * 6);
    float ex = state.scissor.extent[0];
    float ey = state.scissor.extent[1];
    nvgTransformInverse(&invxorm[0], &state.xform[0]);
    nvgTransformMultiply(&pxform[0], &invxorm[0]);
    float tex = ex * nvgAbsf(pxform[0]) + ey * nvgAbsf(pxform[2]);
    float tey = ex * nvgAbsf(pxform[1]) + ey * nvgAbsf(pxform[3]);

    nvgIsectRects(&rect[0], pxform[4] - tex, pxform[5] - tey, tex * 2, tey * 2, x, y, w, h);

    nvgScissor(ctx, rect[0], rect[1], rect[2], rect[3]);
}

fn void nvgResetScissor(NvgContext* ctx) {
    NvgState* state = nvgGetState(ctx);
    libc::memset(&state.scissor.xform[0], 0, float::size * 6);
    state.scissor.extent[0] = -1.0f;
    state.scissor.extent[1] = -1.0f;
}

fn void nvgGlobalCompositeOperation(NvgContext* ctx, int op) {
    NvgState* state = nvgGetState(ctx);
    state.compositeOperation = nvgCompositeOpState(op);
}

fn void nvgGlobalCompositeBlendFunc(NvgContext* ctx, int sfactor, int dfactor) {
    nvgGlobalCompositeBlendFuncSeparate(ctx, sfactor, dfactor, sfactor, dfactor);
}

fn void nvgGlobalCompositeBlendFuncSeparate(NvgContext* ctx, int srcRGB, int dstRGB,
                                              int srcAlpha, int dstAlpha) {
    NvgCompositeOperationState op;
    op.srcRGB   = srcRGB;
    op.dstRGB   = dstRGB;
    op.srcAlpha = srcAlpha;
    op.dstAlpha = dstAlpha;

    NvgState* state = nvgGetState(ctx);
    state.compositeOperation = op;
}

fn int nvgPtEquals(float x1, float y1, float x2, float y2, float tol) @local {
    float dx = x2 - x1;
    float dy = y2 - y1;
    return (int)(dx * dx + dy * dy < tol * tol);
}

fn float nvgDistPtSeg(float x, float y, float px, float py, float qx, float qy) @local {
    float pqx = qx - px;
    float pqy = qy - py;
    float ddx = x - px;
    float ddy = y - py;
    float d = pqx * pqx + pqy * pqy;
    float t = pqx * ddx + pqy * ddy;
    if (d > 0) t /= d;
    if (t < 0) {
        t = 0;
    } else if (t > 1) {
        t = 1;
    }
    ddx = px + t * pqx - x;
    ddy = py + t * pqy - y;
    return ddx * ddx + ddy * ddy;
}

fn void nvgAppendCommands(NvgContext* ctx, float* vals, int nvals) @local {
    NvgState* state = nvgGetState(ctx);

    if (ctx.ncommands + nvals > ctx.ccommands) {
        int ccommands = ctx.ncommands + nvals + ctx.ccommands / 2;
        float* commands = (float*)libc::realloc(ctx.commands, float::size * (usz)ccommands);
        if (commands == null) return;
        ctx.commands = commands;
        ctx.ccommands = ccommands;
    }

    if ((int)vals[0] != NVG_CLOSE && (int)vals[0] != NVG_WINDING) {
        ctx.commandx = vals[nvals - 2];
        ctx.commandy = vals[nvals - 1];
    }

    int i = 0;
    while (i < nvals) {
        int cmd = (int)vals[i];
        switch (cmd) {
        case NVG_MOVETO:
            nvgTransformPoint(&vals[i + 1], &vals[i + 2], &state.xform[0], vals[i + 1], vals[i + 2]);
            i += 3;
            break;
        case NVG_LINETO:
            nvgTransformPoint(&vals[i + 1], &vals[i + 2], &state.xform[0], vals[i + 1], vals[i + 2]);
            i += 3;
            break;
        case NVG_BEZIERTO:
            nvgTransformPoint(&vals[i + 1], &vals[i + 2], &state.xform[0], vals[i + 1], vals[i + 2]);
            nvgTransformPoint(&vals[i + 3], &vals[i + 4], &state.xform[0], vals[i + 3], vals[i + 4]);
            nvgTransformPoint(&vals[i + 5], &vals[i + 6], &state.xform[0], vals[i + 5], vals[i + 6]);
            i += 7;
            break;
        case NVG_CLOSE:
            i++;
            break;
        case NVG_WINDING:
            i += 2;
            break;
        default:
            i++;
        }
    }

    libc::memcpy(&ctx.commands[ctx.ncommands], vals, (usz)nvals * float::size);

    ctx.ncommands += nvals;
}

fn void nvgClearPathCache(NvgContext* ctx) @local {
    ctx.cache.npoints = 0;
    ctx.cache.npaths = 0;
}

fn NvgPath* nvgLastPath(NvgContext* ctx) @local {
    if (ctx.cache.npaths > 0) {
        return &ctx.cache.paths[ctx.cache.npaths - 1];
    }
    return null;
}

fn void nvgAddPath(NvgContext* ctx) @local {
    if (ctx.cache.npaths + 1 > ctx.cache.cpaths) {
        int cpaths = ctx.cache.npaths + 1 + ctx.cache.cpaths / 2;
        NvgPath* paths = (NvgPath*)libc::realloc(ctx.cache.paths, NvgPath::size * (usz)cpaths);
        if (paths == null) return;
        ctx.cache.paths = paths;
        ctx.cache.cpaths = cpaths;
    }
    NvgPath* path = &ctx.cache.paths[ctx.cache.npaths];
    libc::memset(path, 0, NvgPath::size);
    path.first = ctx.cache.npoints;
    path.winding = WINDING_CCW;

    ctx.cache.npaths++;
}

fn NvgPoint* nvgLastPoint(NvgContext* ctx) @local {
    if (ctx.cache.npoints > 0) {
        return &ctx.cache.points[ctx.cache.npoints - 1];
    }
    return null;
}

fn void nvgAddPoint(NvgContext* ctx, float x, float y, int flags) @local {
    NvgPath* path = nvgLastPath(ctx);
    if (path == null) return;

    if (path.count > 0 && ctx.cache.npoints > 0) {
        NvgPoint* pt = nvgLastPoint(ctx);
        if (nvgPtEquals(pt.x, pt.y, x, y, ctx.distTol)) {
            pt.flags = (char)(pt.flags | flags);
            return;
        }
    }

    if (ctx.cache.npoints + 1 > ctx.cache.cpoints) {
        int cpoints = ctx.cache.npoints + 1 + ctx.cache.cpoints / 2;
        NvgPoint* points = (NvgPoint*)libc::realloc(ctx.cache.points, NvgPoint::size * (usz)cpoints);
        if (points == null) return;
        ctx.cache.points = points;
        ctx.cache.cpoints = cpoints;
    }

    NvgPoint* pt = &ctx.cache.points[ctx.cache.npoints];
    libc::memset(pt, 0, NvgPoint::size);
    pt.x = x;
    pt.y = y;
    pt.flags = (char)flags;

    ctx.cache.npoints++;
    path.count++;
}

fn void nvgClosePathCache(NvgContext* ctx) @local {
    NvgPath* path = nvgLastPath(ctx);
    if (path == null) return;
    path.closed = 1;
}

fn void nvgPathWindingCache(NvgContext* ctx, int winding) @local {
    NvgPath* path = nvgLastPath(ctx);
    if (path == null) return;
    path.winding = winding;
}

fn float nvgGetAverageScale(float* t) @local {
    float sx = nvgSqrtf(t[0] * t[0] + t[2] * t[2]);
    float sy = nvgSqrtf(t[1] * t[1] + t[3] * t[3]);
    return (sx + sy) * 0.5f;
}

fn NvgVertex* nvgAllocTempVerts(NvgContext* ctx, int nverts) @local {
    if (nverts > ctx.cache.cverts) {
        int cverts = (nverts + 0xff) & ~0xff;
        NvgVertex* verts = (NvgVertex*)libc::realloc(ctx.cache.verts, NvgVertex::size * (usz)cverts);
        if (verts == null) return null;
        ctx.cache.verts = verts;
        ctx.cache.cverts = cverts;
    }

    return ctx.cache.verts;
}

fn float nvgTriarea2(float ax, float ay, float bx, float by, float cx, float cy) @local {
    float abx = bx - ax;
    float aby = by - ay;
    float acx = cx - ax;
    float acy = cy - ay;
    return acx * aby - abx * acy;
}

fn float nvgPolyArea(NvgPoint* pts, int npts) @local {
    float area = 0;
    for (int i = 2; i < npts; i++) {
        NvgPoint* a = &pts[0];
        NvgPoint* b = &pts[i - 1];
        NvgPoint* c = &pts[i];
        area += nvgTriarea2(a.x, a.y, b.x, b.y, c.x, c.y);
    }
    return area * 0.5f;
}

fn void nvgPolyReverse(NvgPoint* pts, int npts) @local {
    int i = 0;
    int j = npts - 1;
    while (i < j) {
        NvgPoint tmp = pts[i];
        pts[i] = pts[j];
        pts[j] = tmp;
        i++;
        j--;
    }
}

fn void nvgVset(NvgVertex* vtx, float x, float y, float u, float v) @local {
    vtx.x = x;
    vtx.y = y;
    vtx.u = u;
    vtx.v = v;
}

fn void nvgTesselateBezier(NvgContext* ctx,
    float x1, float y1, float x2, float y2,
    float x3, float y3, float x4, float y4,
    int level, int type) @local
{
    if (level > 10) return;

    float x12 = (x1 + x2) * 0.5f;
    float y12 = (y1 + y2) * 0.5f;
    float x23 = (x2 + x3) * 0.5f;
    float y23 = (y2 + y3) * 0.5f;
    float x34 = (x3 + x4) * 0.5f;
    float y34 = (y3 + y4) * 0.5f;
    float x123 = (x12 + x23) * 0.5f;
    float y123 = (y12 + y23) * 0.5f;

    float dx = x4 - x1;
    float dy = y4 - y1;
    float d2 = nvgAbsf(((x2 - x4) * dy - (y2 - y4) * dx));
    float d3 = nvgAbsf(((x3 - x4) * dy - (y3 - y4) * dx));

    if ((d2 + d3) * (d2 + d3) < ctx.tessTol * (dx * dx + dy * dy)) {
        nvgAddPoint(ctx, x4, y4, type);
        return;
    }

    float x234 = (x23 + x34) * 0.5f;
    float y234 = (y23 + y34) * 0.5f;
    float x1234 = (x123 + x234) * 0.5f;
    float y1234 = (y123 + y234) * 0.5f;

    nvgTesselateBezier(ctx, x1, y1, x12, y12, x123, y123, x1234, y1234, level + 1, 0);
    nvgTesselateBezier(ctx, x1234, y1234, x234, y234, x34, y34, x4, y4, level + 1, type);
}

fn void nvgFlattenPaths(NvgContext* ctx) @local {
    NvgPathCache* cache = ctx.cache;

    if (cache.npaths > 0) {
        return;
    }

    int i = 0;
    while (i < ctx.ncommands) {
        int cmd = (int)ctx.commands[i];
        switch (cmd) {
        case NVG_MOVETO: {
            nvgAddPath(ctx);
            float* p = &ctx.commands[i + 1];
            nvgAddPoint(ctx, p[0], p[1], NVG_PT_CORNER);
            i += 3;
            break;
        }
        case NVG_LINETO: {
            float* p = &ctx.commands[i + 1];
            nvgAddPoint(ctx, p[0], p[1], NVG_PT_CORNER);
            i += 3;
            break;
        }
        case NVG_BEZIERTO: {
            NvgPoint* last = nvgLastPoint(ctx);
            if (last != null) {
                float* cp1 = &ctx.commands[i + 1];
                float* cp2 = &ctx.commands[i + 3];
                float* p   = &ctx.commands[i + 5];
                nvgTesselateBezier(ctx, last.x, last.y, cp1[0], cp1[1], cp2[0], cp2[1], p[0], p[1], 0, NVG_PT_CORNER);
            }
            i += 7;
            break;
        }
        case NVG_CLOSE:
            nvgClosePathCache(ctx);
            i++;
            break;
        case NVG_WINDING:
            nvgPathWindingCache(ctx, (int)ctx.commands[i + 1]);
            i += 2;
            break;
        default:
            i++;
        }
    }

    cache.bounds[0] = 1e6f;
    cache.bounds[1] = 1e6f;
    cache.bounds[2] = -1e6f;
    cache.bounds[3] = -1e6f;

    for (int j = 0; j < cache.npaths; j++) {
        NvgPath* path = &cache.paths[j];
        NvgPoint* pts = &cache.points[path.first];

        NvgPoint* p0 = &pts[path.count - 1];
        NvgPoint* p1 = &pts[0];
        if (nvgPtEquals(p0.x, p0.y, p1.x, p1.y, ctx.distTol)) {
            path.count--;
            p0 = &pts[path.count - 1];
            path.closed = 1;
        }

        if (path.count > 2) {
            float area = nvgPolyArea(pts, path.count);
            if (path.winding == WINDING_CCW && area < 0.0f) {
                nvgPolyReverse(pts, path.count);
            }
            if (path.winding == WINDING_CW && area > 0.0f) {
                nvgPolyReverse(pts, path.count);
            }
        }

        for (int k = 0; k < path.count; k++) {
            p0.dx = p1.x - p0.x;
            p0.dy = p1.y - p0.y;
            p0.len = nvgNormalize(&p0.dx, &p0.dy);
            cache.bounds[0] = nvgMinf(cache.bounds[0], p0.x);
            cache.bounds[1] = nvgMinf(cache.bounds[1], p0.y);
            cache.bounds[2] = nvgMaxf(cache.bounds[2], p0.x);
            cache.bounds[3] = nvgMaxf(cache.bounds[3], p0.y);
            p0 = p1;
            p1++;
        }
    }
}

fn int nvgCurveDivs(float r, float arc, float tol) @local {
    float da = nvgAcosf(r / (r + tol)) * 2.0f;
    return nvgMaxi(2, (int)math::ceil(arc / da));
}

fn void nvgChooseBevel(int bevel, NvgPoint* p0, NvgPoint* p1, float w,
                        float* x0, float* y0, float* x1, float* y1) @local {
    if (bevel) {
        x0[0] = p1.x + p0.dy * w;
        y0[0] = p1.y - p0.dx * w;
        x1[0] = p1.x + p1.dy * w;
        y1[0] = p1.y - p1.dx * w;
    } else {
        x0[0] = p1.x + p1.dmx * w;
        y0[0] = p1.y + p1.dmy * w;
        x1[0] = p1.x + p1.dmx * w;
        y1[0] = p1.y + p1.dmy * w;
    }
}

fn NvgVertex* nvgRoundJoin(NvgVertex* dst, NvgPoint* p0, NvgPoint* p1,
    float lw, float rw, float lu, float ru, int ncap, float fringe) @local
{
    float dlx0 = p0.dy;
    float dly0 = -p0.dx;
    float dlx1 = p1.dy;
    float dly1 = -p1.dx;

    if (p1.flags & NVG_PT_LEFT) {
        float lx0, ly0, lx1, ly1;
        nvgChooseBevel(p1.flags & NVG_PR_INNERBEVEL, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);
        float a0 = nvgAtan2f(-dly0, -dlx0);
        float a1 = nvgAtan2f(-dly1, -dlx1);
        if (a1 > a0) a1 -= PI * 2;

        nvgVset(dst, lx0, ly0, lu, 1); dst++;
        nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1); dst++;

        int n = nvgClampi((int)math::ceil(((a0 - a1) / PI) * ncap), 2, ncap);
        for (int i = 0; i < n; i++) {
            float u = i / (float)(n - 1);
            float a = a0 + u * (a1 - a0);
            float rx = p1.x + nvgCosf(a) * rw;
            float ry = p1.y + nvgSinf(a) * rw;
            nvgVset(dst, p1.x, p1.y, 0.5f, 1); dst++;
            nvgVset(dst, rx, ry, ru, 1); dst++;
        }

        nvgVset(dst, lx1, ly1, lu, 1); dst++;
        nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1); dst++;

    } else {
        float rx0, ry0, rx1, ry1;
        nvgChooseBevel(p1.flags & NVG_PR_INNERBEVEL, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);
        float a0 = nvgAtan2f(dly0, dlx0);
        float a1 = nvgAtan2f(dly1, dlx1);
        if (a1 < a0) a1 += PI * 2;

        nvgVset(dst, p1.x + dlx0 * rw, p1.y + dly0 * rw, lu, 1); dst++;
        nvgVset(dst, rx0, ry0, ru, 1); dst++;

        int n = nvgClampi((int)math::ceil(((a1 - a0) / PI) * ncap), 2, ncap);
        for (int i = 0; i < n; i++) {
            float u = i / (float)(n - 1);
            float a = a0 + u * (a1 - a0);
            float lx = p1.x + nvgCosf(a) * lw;
            float ly = p1.y + nvgSinf(a) * lw;
            nvgVset(dst, lx, ly, lu, 1); dst++;
            nvgVset(dst, p1.x, p1.y, 0.5f, 1); dst++;
        }

        nvgVset(dst, p1.x + dlx1 * rw, p1.y + dly1 * rw, lu, 1); dst++;
        nvgVset(dst, rx1, ry1, ru, 1); dst++;

    }
    return dst;
}

fn NvgVertex* nvgBevelJoin(NvgVertex* dst, NvgPoint* p0, NvgPoint* p1,
    float lw, float rw, float lu, float ru, float fringe) @local
{
    float dlx0 = p0.dy;
    float dly0 = -p0.dx;
    float dlx1 = p1.dy;
    float dly1 = -p1.dx;

    if (p1.flags & NVG_PT_LEFT) {
        float lx0, ly0, lx1, ly1;
        nvgChooseBevel(p1.flags & NVG_PR_INNERBEVEL, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);

        nvgVset(dst, lx0, ly0, lu, 1); dst++;
        nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1); dst++;

        if (p1.flags & NVG_PT_BEVEL) {
            nvgVset(dst, lx0, ly0, lu, 1); dst++;
            nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1); dst++;

            nvgVset(dst, lx1, ly1, lu, 1); dst++;
            nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1); dst++;
        } else {
            float rx0 = p1.x - p1.dmx * rw;
            float ry0 = p1.y - p1.dmy * rw;

            nvgVset(dst, p1.x, p1.y, 0.5f, 1); dst++;
            nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1); dst++;

            nvgVset(dst, rx0, ry0, ru, 1); dst++;
            nvgVset(dst, rx0, ry0, ru, 1); dst++;

            nvgVset(dst, p1.x, p1.y, 0.5f, 1); dst++;
            nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1); dst++;
        }

        nvgVset(dst, lx1, ly1, lu, 1); dst++;
        nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1); dst++;

    } else {
        float rx0, ry0, rx1, ry1;
        nvgChooseBevel(p1.flags & NVG_PR_INNERBEVEL, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);

        nvgVset(dst, p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1); dst++;
        nvgVset(dst, rx0, ry0, ru, 1); dst++;

        if (p1.flags & NVG_PT_BEVEL) {
            nvgVset(dst, p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1); dst++;
            nvgVset(dst, rx0, ry0, ru, 1); dst++;

            nvgVset(dst, p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1); dst++;
            nvgVset(dst, rx1, ry1, ru, 1); dst++;
        } else {
            float lx0 = p1.x + p1.dmx * lw;
            float ly0 = p1.y + p1.dmy * lw;

            nvgVset(dst, p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1); dst++;
            nvgVset(dst, p1.x, p1.y, 0.5f, 1); dst++;

            nvgVset(dst, lx0, ly0, lu, 1); dst++;
            nvgVset(dst, lx0, ly0, lu, 1); dst++;

            nvgVset(dst, p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1); dst++;
            nvgVset(dst, p1.x, p1.y, 0.5f, 1); dst++;
        }

        nvgVset(dst, p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1); dst++;
        nvgVset(dst, rx1, ry1, ru, 1); dst++;
    }

    return dst;
}

fn NvgVertex* nvgButtCapStart(NvgVertex* dst, NvgPoint* p,
    float dx, float dy, float w, float d,
    float aa, float u0, float u1) @local
{
    float px = p.x - dx * d;
    float py = p.y - dy * d;
    float dlx = dy;
    float dly = -dx;
    nvgVset(dst, px + dlx * w - dx * aa, py + dly * w - dy * aa, u0, 0); dst++;
    nvgVset(dst, px - dlx * w - dx * aa, py - dly * w - dy * aa, u1, 0); dst++;
    nvgVset(dst, px + dlx * w, py + dly * w, u0, 1); dst++;
    nvgVset(dst, px - dlx * w, py - dly * w, u1, 1); dst++;
    return dst;
}

fn NvgVertex* nvgButtCapEnd(NvgVertex* dst, NvgPoint* p,
    float dx, float dy, float w, float d,
    float aa, float u0, float u1) @local
{
    float px = p.x + dx * d;
    float py = p.y + dy * d;
    float dlx = dy;
    float dly = -dx;
    nvgVset(dst, px + dlx * w, py + dly * w, u0, 1); dst++;
    nvgVset(dst, px - dlx * w, py - dly * w, u1, 1); dst++;
    nvgVset(dst, px + dlx * w + dx * aa, py + dly * w + dy * aa, u0, 0); dst++;
    nvgVset(dst, px - dlx * w + dx * aa, py - dly * w + dy * aa, u1, 0); dst++;
    return dst;
}

fn NvgVertex* nvgRoundCapStart(NvgVertex* dst, NvgPoint* p,
    float dx, float dy, float w, int ncap,
    float aa, float u0, float u1) @local
{
    float px = p.x;
    float py = p.y;
    float dlx = dy;
    float dly = -dx;
    for (int i = 0; i < ncap; i++) {
        float a = i / (float)(ncap - 1) * PI;
        float ax = nvgCosf(a) * w;
        float ay = nvgSinf(a) * w;
        nvgVset(dst, px - dlx * ax - dx * ay, py - dly * ax - dy * ay, u0, 1); dst++;
        nvgVset(dst, px, py, 0.5f, 1); dst++;
    }
    nvgVset(dst, px + dlx * w, py + dly * w, u0, 1); dst++;
    nvgVset(dst, px - dlx * w, py - dly * w, u1, 1); dst++;
    return dst;
}

fn NvgVertex* nvgRoundCapEnd(NvgVertex* dst, NvgPoint* p,
    float dx, float dy, float w, int ncap,
    float aa, float u0, float u1) @local
{
    float px = p.x;
    float py = p.y;
    float dlx = dy;
    float dly = -dx;
    nvgVset(dst, px + dlx * w, py + dly * w, u0, 1); dst++;
    nvgVset(dst, px - dlx * w, py - dly * w, u1, 1); dst++;
    for (int i = 0; i < ncap; i++) {
        float a = i / (float)(ncap - 1) * PI;
        float ax = nvgCosf(a) * w;
        float ay = nvgSinf(a) * w;
        nvgVset(dst, px, py, 0.5f, 1); dst++;
        nvgVset(dst, px - dlx * ax + dx * ay, py - dly * ax + dy * ay, u0, 1); dst++;
    }
    return dst;
}

fn void nvgCalculateJoins(NvgContext* ctx, float w, int lineJoin, float miterLimit) @local {
    NvgPathCache* cache = ctx.cache;
    float iw = 0.0f;

    if (w > 0.0f) iw = 1.0f / w;

    for (int i = 0; i < cache.npaths; i++) {
        NvgPath* path = &cache.paths[i];
        NvgPoint* pts = &cache.points[path.first];
        NvgPoint* p0 = &pts[path.count - 1];
        NvgPoint* p1 = &pts[0];
        int nleft = 0;

        path.nbevel = 0;

        for (int j = 0; j < path.count; j++) {
            float dlx0 = p0.dy;
            float dly0 = -p0.dx;
            float dlx1 = p1.dy;
            float dly1 = -p1.dx;
            p1.dmx = (dlx0 + dlx1) * 0.5f;
            p1.dmy = (dly0 + dly1) * 0.5f;
            float dmr2 = p1.dmx * p1.dmx + p1.dmy * p1.dmy;
            if (dmr2 > 0.000001f) {
                float scale = 1.0f / dmr2;
                if (scale > 600.0f) {
                    scale = 600.0f;
                }
                p1.dmx *= scale;
                p1.dmy *= scale;
            }

            p1.flags = (p1.flags & NVG_PT_CORNER) ? (char)NVG_PT_CORNER : (char)0;

            float cross = p1.dx * p0.dy - p0.dx * p1.dy;
            if (cross > 0.0f) {
                nleft++;
                p1.flags = (char)(p1.flags | NVG_PT_LEFT);
            }

            float limit = nvgMaxf(1.01f, nvgMinf(p0.len, p1.len) * iw);
            if ((dmr2 * limit * limit) < 1.0f) {
                p1.flags = (char)(p1.flags | NVG_PR_INNERBEVEL);
            }

            if (p1.flags & NVG_PT_CORNER) {
                if ((dmr2 * miterLimit * miterLimit) < 1.0f || lineJoin == LINE_JOIN_BEVEL || lineJoin == LINE_JOIN_ROUND) {
                    p1.flags = (char)(p1.flags | NVG_PT_BEVEL);
                }
            }

            if ((p1.flags & (NVG_PT_BEVEL | NVG_PR_INNERBEVEL)) != 0) {
                path.nbevel++;
            }

            p0 = p1;
            p1++;
        }

        path.convex = (nleft == path.count) ? 1 : 0;
    }
}

fn int nvgExpandStroke(NvgContext* ctx, float w, float fringe, int lineCap, int lineJoin, float miterLimit) @local {
    NvgPathCache* cache = ctx.cache;
    float aa = fringe;
    float u0 = 0.0f;
    float u1 = 1.0f;
    int ncap = nvgCurveDivs(w, PI, ctx.tessTol);

    w += aa * 0.5f;

    if (aa == 0.0f) {
        u0 = 0.5f;
        u1 = 0.5f;
    }

    nvgCalculateJoins(ctx, w, lineJoin, miterLimit);

    int cverts = 0;
    for (int i = 0; i < cache.npaths; i++) {
        NvgPath* path = &cache.paths[i];
        int loop = (path.closed == 0) ? 0 : 1;
        if (lineJoin == LINE_JOIN_ROUND) {
            cverts += (path.count + path.nbevel * (ncap + 2) + 1) * 2;
        }
        else {
            cverts += (path.count + path.nbevel * 5 + 1) * 2;
        }
        if (loop == 0) {
            if (lineCap == LINE_CAP_ROUND) {
                cverts += (ncap * 2 + 2) * 2;
            } else {
                cverts += (3 + 3) * 2;
            }
        }
    }

    NvgVertex* verts = nvgAllocTempVerts(ctx, cverts);
    if (verts == null) return 0;

    for (int i = 0; i < cache.npaths; i++) {
        NvgPath* path = &cache.paths[i];
        NvgPoint* pts = &cache.points[path.first];
        NvgPoint* p0;
        NvgPoint* p1;
        int s, e, loop;
        float dx, dy;

        path.fill = null;
        path.nfill = 0;

        loop = (path.closed == 0) ? 0 : 1;
        NvgVertex* dst = verts;
        path.stroke = dst;

        if (loop) {
            p0 = &pts[path.count - 1];
            p1 = &pts[0];
            s = 0;
            e = path.count;
        } else {
            p0 = &pts[0];
            p1 = &pts[1];
            s = 1;
            e = path.count - 1;
        }

        if (loop == 0) {
            dx = p1.x - p0.x;
            dy = p1.y - p0.y;
            nvgNormalize(&dx, &dy);
            if (lineCap == LINE_CAP_BUTT) {
                dst = nvgButtCapStart(dst, p0, dx, dy, w, -aa * 0.5f, aa, u0, u1);
            }
            else if (lineCap == LINE_CAP_SQUARE) {
                dst = nvgButtCapStart(dst, p0, dx, dy, w, w - aa, aa, u0, u1);
            }
            else if (lineCap == LINE_CAP_ROUND) {
                dst = nvgRoundCapStart(dst, p0, dx, dy, w, ncap, aa, u0, u1);
            }
        }

        for (int j = s; j < e; j++) {
            if ((p1.flags & (NVG_PT_BEVEL | NVG_PR_INNERBEVEL)) != 0) {
                if (lineJoin == LINE_JOIN_ROUND) {
                    dst = nvgRoundJoin(dst, p0, p1, w, w, u0, u1, ncap, aa);
                } else {
                    dst = nvgBevelJoin(dst, p0, p1, w, w, u0, u1, aa);
                }
            } else {
                nvgVset(dst, p1.x + (p1.dmx * w), p1.y + (p1.dmy * w), u0, 1); dst++;
                nvgVset(dst, p1.x - (p1.dmx * w), p1.y - (p1.dmy * w), u1, 1); dst++;
            }
            p0 = p1;
            p1++;
        }

        if (loop) {
            nvgVset(dst, verts[0].x, verts[0].y, u0, 1); dst++;
            nvgVset(dst, verts[1].x, verts[1].y, u1, 1); dst++;
        } else {
            dx = p1.x - p0.x;
            dy = p1.y - p0.y;
            nvgNormalize(&dx, &dy);
            if (lineCap == LINE_CAP_BUTT) {
                dst = nvgButtCapEnd(dst, p1, dx, dy, w, -aa * 0.5f, aa, u0, u1);
            }
            else if (lineCap == LINE_CAP_SQUARE) {
                dst = nvgButtCapEnd(dst, p1, dx, dy, w, w - aa, aa, u0, u1);
            }
            else if (lineCap == LINE_CAP_ROUND) {
                dst = nvgRoundCapEnd(dst, p1, dx, dy, w, ncap, aa, u0, u1);
            }
        }

        path.nstroke = (int)(dst - verts);

        verts = dst;
    }

    return 1;
}

fn int nvgExpandFill(NvgContext* ctx, float w, int lineJoin, float miterLimit) @local {
    NvgPathCache* cache = ctx.cache;
    float aa = ctx.fringeWidth;
    int fringe = (int)(w > 0.0f);

    nvgCalculateJoins(ctx, w, lineJoin, miterLimit);

    int cverts = 0;
    for (int i = 0; i < cache.npaths; i++) {
        NvgPath* path = &cache.paths[i];
        cverts += path.count + path.nbevel + 1;
        if (fringe) {
            cverts += (path.count + path.nbevel * 5 + 1) * 2;
        }
    }

    NvgVertex* verts = nvgAllocTempVerts(ctx, cverts);
    if (verts == null) return 0;

    int convex = (int)(cache.npaths == 1 && cache.paths[0].convex != 0);

    for (int i = 0; i < cache.npaths; i++) {
        NvgPath* path = &cache.paths[i];
        NvgPoint* pts = &cache.points[path.first];
        NvgPoint* p0;
        NvgPoint* p1;
        float rw, lw, woff;
        float ru, lu;

        woff = 0.5f * aa;
        NvgVertex* dst = verts;
        path.fill = dst;

        if (fringe) {
            p0 = &pts[path.count - 1];
            p1 = &pts[0];
            for (int j = 0; j < path.count; j++) {
                if (p1.flags & NVG_PT_BEVEL) {
                    float dlx0 = p0.dy;
                    float dly0 = -p0.dx;
                    float dlx1 = p1.dy;
                    float dly1 = -p1.dx;
                    if (p1.flags & NVG_PT_LEFT) {
                        float lx = p1.x + p1.dmx * woff;
                        float ly = p1.y + p1.dmy * woff;
                        nvgVset(dst, lx, ly, 0.5f, 1); dst++;
                    } else {
                        float lx0 = p1.x + dlx0 * woff;
                        float ly0 = p1.y + dly0 * woff;
                        float lx1 = p1.x + dlx1 * woff;
                        float ly1 = p1.y + dly1 * woff;
                        nvgVset(dst, lx0, ly0, 0.5f, 1); dst++;
                        nvgVset(dst, lx1, ly1, 0.5f, 1); dst++;
                    }
                } else {
                    nvgVset(dst, p1.x + (p1.dmx * woff), p1.y + (p1.dmy * woff), 0.5f, 1); dst++;
                }
                p0 = p1;
                p1++;
            }
        } else {
            for (int j = 0; j < path.count; j++) {
                nvgVset(dst, pts[j].x, pts[j].y, 0.5f, 1);
                dst++;
            }
        }

        path.nfill = (int)(dst - verts);
        verts = dst;

        if (fringe) {
            lw = w + woff;
            rw = w - woff;
            lu = 0;
            ru = 1;
            dst = verts;
            path.stroke = dst;

            if (convex) {
                lw = woff;
                lu = 0.5f;
            }

            p0 = &pts[path.count - 1];
            p1 = &pts[0];

            for (int j = 0; j < path.count; j++) {
                if ((p1.flags & (NVG_PT_BEVEL | NVG_PR_INNERBEVEL)) != 0) {
                    dst = nvgBevelJoin(dst, p0, p1, lw, rw, lu, ru, ctx.fringeWidth);
                } else {
                    nvgVset(dst, p1.x + (p1.dmx * lw), p1.y + (p1.dmy * lw), lu, 1); dst++;
                    nvgVset(dst, p1.x - (p1.dmx * rw), p1.y - (p1.dmy * rw), ru, 1); dst++;
                }
                p0 = p1;
                p1++;
            }

            nvgVset(dst, verts[0].x, verts[0].y, lu, 1); dst++;
            nvgVset(dst, verts[1].x, verts[1].y, ru, 1); dst++;

            path.nstroke = (int)(dst - verts);
            verts = dst;
        } else {
            path.stroke = null;
            path.nstroke = 0;
        }
    }

    return 1;
}

fn void nvgBeginPath(NvgContext* ctx) {
    ctx.ncommands = 0;
    nvgClearPathCache(ctx);
}

fn void nvgMoveTo(NvgContext* ctx, float x, float y) {
    float[*] vals = { (float)NVG_MOVETO, x, y };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgLineTo(NvgContext* ctx, float x, float y) {
    float[*] vals = { (float)NVG_LINETO, x, y };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgBezierTo(NvgContext* ctx, float c1x, float c1y, float c2x, float c2y, float x, float y) {
    float[*] vals = { (float)NVG_BEZIERTO, c1x, c1y, c2x, c2y, x, y };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgQuadTo(NvgContext* ctx, float cx, float cy, float x, float y) {
    float x0 = ctx.commandx;
    float y0 = ctx.commandy;
    float[*] vals = {
        (float)NVG_BEZIERTO,
        x0 + 2.0f / 3.0f * (cx - x0), y0 + 2.0f / 3.0f * (cy - y0),
        x  + 2.0f / 3.0f * (cx - x),  y  + 2.0f / 3.0f * (cy - y),
        x, y
    };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgArcTo(NvgContext* ctx, float x1, float y1, float x2, float y2, float radius) {
    float x0 = ctx.commandx;
    float y0 = ctx.commandy;

    if (ctx.ncommands == 0) {
        return;
    }

    if (nvgPtEquals(x0, y0, x1, y1, ctx.distTol) ||
        nvgPtEquals(x1, y1, x2, y2, ctx.distTol) ||
        nvgDistPtSeg(x1, y1, x0, y0, x2, y2) < ctx.distTol * ctx.distTol ||
        radius < ctx.distTol) {
        nvgLineTo(ctx, x1, y1);
        return;
    }

    float dx0 = x0 - x1;
    float dy0 = y0 - y1;
    float dx1 = x2 - x1;
    float dy1 = y2 - y1;
    nvgNormalize(&dx0, &dy0);
    nvgNormalize(&dx1, &dy1);
    float a = nvgAcosf(dx0 * dx1 + dy0 * dy1);
    float d = radius / nvgTanf(a / 2.0f);

    if (d > 10000.0f) {
        nvgLineTo(ctx, x1, y1);
        return;
    }

    float cx, cy, a0, a1;
    int dir;
    if (nvgCross(dx0, dy0, dx1, dy1) > 0.0f) {
        cx = x1 + dx0 * d + dy0 * radius;
        cy = y1 + dy0 * d + -dx0 * radius;
        a0 = nvgAtan2f(dx0, -dy0);
        a1 = nvgAtan2f(-dx1, dy1);
        dir = WINDING_CW;
    } else {
        cx = x1 + dx0 * d + -dy0 * radius;
        cy = y1 + dy0 * d + dx0 * radius;
        a0 = nvgAtan2f(-dx0, dy0);
        a1 = nvgAtan2f(dx1, -dy1);
        dir = WINDING_CCW;
    }

    nvgArc(ctx, cx, cy, radius, a0, a1, dir);
}

fn void nvgClosePath(NvgContext* ctx) {
    float[*] vals = { (float)NVG_CLOSE };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgPathWinding(NvgContext* ctx, int dir) {
    float[*] vals = { (float)NVG_WINDING, (float)dir };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgArc(NvgContext* ctx, float cx, float cy, float r, float a0, float a1, int dir) {
    float a = 0; float da = 0; float hda = 0; float kappa = 0;
    float dx = 0; float dy = 0; float x = 0; float y = 0; float tanx = 0; float tany = 0;
    float px = 0; float py = 0; float ptanx = 0; float ptany = 0;
    float[3 + 5 * 7 + 100] vals;
    int ndivs, nvals;
    int move = ctx.ncommands > 0 ? NVG_LINETO : NVG_MOVETO;

    da = a1 - a0;
    if (dir == WINDING_CW) {
        if (nvgAbsf(da) >= PI * 2) {
            da = PI * 2;
        } else {
            while (da < 0.0f) da += PI * 2;
        }
    } else {
        if (nvgAbsf(da) >= PI * 2) {
            da = -PI * 2;
        } else {
            while (da > 0.0f) da -= PI * 2;
        }
    }

    ndivs = nvgMaxi(1, nvgMini((int)(nvgAbsf(da) / (PI * 0.5f) + 0.5f), 5));
    hda = (da / (float)ndivs) / 2.0f;
    kappa = nvgAbsf(4.0f / 3.0f * (1.0f - nvgCosf(hda)) / nvgSinf(hda));

    if (dir == WINDING_CCW) {
        kappa = -kappa;
    }

    nvals = 0;
    for (int i = 0; i <= ndivs; i++) {
        a = a0 + da * (i / (float)ndivs);
        dx = nvgCosf(a);
        dy = nvgSinf(a);
        x = cx + dx * r;
        y = cy + dy * r;
        tanx = -dy * r * kappa;
        tany = dx * r * kappa;

        if (i == 0) {
            vals[nvals] = (float)move; nvals++;
            vals[nvals] = x; nvals++;
            vals[nvals] = y; nvals++;
        } else {
            vals[nvals] = (float)NVG_BEZIERTO; nvals++;
            vals[nvals] = px + ptanx; nvals++;
            vals[nvals] = py + ptany; nvals++;
            vals[nvals] = x - tanx; nvals++;
            vals[nvals] = y - tany; nvals++;
            vals[nvals] = x; nvals++;
            vals[nvals] = y; nvals++;
        }
        px = x;
        py = y;
        ptanx = tanx;
        ptany = tany;
    }

    nvgAppendCommands(ctx, &vals[0], nvals);
}

fn void nvgRect(NvgContext* ctx, float x, float y, float w, float h) {
    float[*] vals = {
        (float)NVG_MOVETO, x, y,
        (float)NVG_LINETO, x, y + h,
        (float)NVG_LINETO, x + w, y + h,
        (float)NVG_LINETO, x + w, y,
        (float)NVG_CLOSE
    };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgRoundedRect(NvgContext* ctx, float x, float y, float w, float h, float r) {
    nvgRoundedRectVarying(ctx, x, y, w, h, r, r, r, r);
}

fn void nvgRoundedRectVarying(NvgContext* ctx, float x, float y, float w, float h,
                               float radTopLeft, float radTopRight,
                               float radBottomRight, float radBottomLeft) {
    if (radTopLeft < 0.1f && radTopRight < 0.1f && radBottomRight < 0.1f && radBottomLeft < 0.1f) {
        nvgRect(ctx, x, y, w, h);
        return;
    }
    float halfw = nvgAbsf(w) * 0.5f;
    float halfh = nvgAbsf(h) * 0.5f;
    float rxBL = nvgMinf(radBottomLeft, halfw) * nvgSignf(w);
    float ryBL = nvgMinf(radBottomLeft, halfh) * nvgSignf(h);
    float rxBR = nvgMinf(radBottomRight, halfw) * nvgSignf(w);
    float ryBR = nvgMinf(radBottomRight, halfh) * nvgSignf(h);
    float rxTR = nvgMinf(radTopRight, halfw) * nvgSignf(w);
    float ryTR = nvgMinf(radTopRight, halfh) * nvgSignf(h);
    float rxTL = nvgMinf(radTopLeft, halfw) * nvgSignf(w);
    float ryTL = nvgMinf(radTopLeft, halfh) * nvgSignf(h);
    float[*] vals = {
        (float)NVG_MOVETO, x, y + ryTL,
        (float)NVG_LINETO, x, y + h - ryBL,
        (float)NVG_BEZIERTO, x, y + h - ryBL * (1 - NVG_KAPPA90), x + rxBL * (1 - NVG_KAPPA90), y + h, x + rxBL, y + h,
        (float)NVG_LINETO, x + w - rxBR, y + h,
        (float)NVG_BEZIERTO, x + w - rxBR * (1 - NVG_KAPPA90), y + h, x + w, y + h - ryBR * (1 - NVG_KAPPA90), x + w, y + h - ryBR,
        (float)NVG_LINETO, x + w, y + ryTR,
        (float)NVG_BEZIERTO, x + w, y + ryTR * (1 - NVG_KAPPA90), x + w - rxTR * (1 - NVG_KAPPA90), y, x + w - rxTR, y,
        (float)NVG_LINETO, x + rxTL, y,
        (float)NVG_BEZIERTO, x + rxTL * (1 - NVG_KAPPA90), y, x, y + ryTL * (1 - NVG_KAPPA90), x, y + ryTL,
        (float)NVG_CLOSE
    };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgEllipse(NvgContext* ctx, float cx, float cy, float rx, float ry) {
    float[*] vals = {
        (float)NVG_MOVETO, cx - rx, cy,
        (float)NVG_BEZIERTO, cx - rx, cy + ry * NVG_KAPPA90, cx - rx * NVG_KAPPA90, cy + ry, cx, cy + ry,
        (float)NVG_BEZIERTO, cx + rx * NVG_KAPPA90, cy + ry, cx + rx, cy + ry * NVG_KAPPA90, cx + rx, cy,
        (float)NVG_BEZIERTO, cx + rx, cy - ry * NVG_KAPPA90, cx + rx * NVG_KAPPA90, cy - ry, cx, cy - ry,
        (float)NVG_BEZIERTO, cx - rx * NVG_KAPPA90, cy - ry, cx - rx, cy - ry * NVG_KAPPA90, cx - rx, cy,
        (float)NVG_CLOSE
    };
    nvgAppendCommands(ctx, &vals[0], vals.len);
}

fn void nvgCircle(NvgContext* ctx, float cx, float cy, float r) {
    nvgEllipse(ctx, cx, cy, r, r);
}

fn void nvgFill(NvgContext* ctx) {
    NvgState* state = nvgGetState(ctx);
    NvgPaint fillPaint = state.fill;

    nvgFlattenPaths(ctx);
    if (ctx.params.edgeAntiAlias && state.shapeAntiAlias) {
        nvgExpandFill(ctx, ctx.fringeWidth, LINE_JOIN_MITER, 2.4f);
    }
    else {
        nvgExpandFill(ctx, 0.0f, LINE_JOIN_MITER, 2.4f);
    }

    fillPaint.innerColor.a *= state.alpha;
    fillPaint.outerColor.a *= state.alpha;

    ctx.params.renderFill(ctx.params.userPtr, &fillPaint, state.compositeOperation, &state.scissor,
        ctx.fringeWidth, &ctx.cache.bounds[0], ctx.cache.paths, ctx.cache.npaths);

    for (int i = 0; i < ctx.cache.npaths; i++) {
        NvgPath* path = &ctx.cache.paths[i];
        ctx.fillTriCount += path.nfill - 2;
        ctx.fillTriCount += path.nstroke - 2;
        ctx.drawCallCount += 2;
    }
}

fn void nvgStroke(NvgContext* ctx) {
    NvgState* state = nvgGetState(ctx);
    float scale = nvgGetAverageScale(&state.xform[0]);
    float strokeWidth = nvgClampf(state.strokeWidth * scale, 0.0f, 200.0f);
    NvgPaint strokePaint = state.stroke;

    if (strokeWidth < ctx.fringeWidth) {
        float alpha = nvgClampf(strokeWidth / ctx.fringeWidth, 0.0f, 1.0f);
        strokePaint.innerColor.a *= alpha * alpha;
        strokePaint.outerColor.a *= alpha * alpha;
        strokeWidth = ctx.fringeWidth;
    }

    strokePaint.innerColor.a *= state.alpha;
    strokePaint.outerColor.a *= state.alpha;

    nvgFlattenPaths(ctx);

    if (ctx.params.edgeAntiAlias && state.shapeAntiAlias) {
        nvgExpandStroke(ctx, strokeWidth * 0.5f, ctx.fringeWidth, state.lineCap, state.lineJoin, state.miterLimit);
    }
    else {
        nvgExpandStroke(ctx, strokeWidth * 0.5f, 0.0f, state.lineCap, state.lineJoin, state.miterLimit);
    }

    ctx.params.renderStroke(ctx.params.userPtr, &strokePaint, state.compositeOperation, &state.scissor,
        ctx.fringeWidth, strokeWidth, ctx.cache.paths, ctx.cache.npaths);

    for (int i = 0; i < ctx.cache.npaths; i++) {
        NvgPath* path = &ctx.cache.paths[i];
        ctx.strokeTriCount += path.nstroke - 2;
        ctx.drawCallCount++;
    }
}
