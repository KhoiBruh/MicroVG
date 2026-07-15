module microvg;

import std::core::mem;
import std::math;

const int NVG_PT_CORNER = 0x01;
const int NVG_PT_LEFT = 0x02;
const int NVG_PT_BEVEL = 0x04;
const int NVG_PR_INNERBEVEL = 0x08;

const int INIT_COMMANDS_SIZE = 256;
const int INIT_POINTS_SIZE = 128;
const int INIT_PATHS_SIZE = 16;
const int INIT_VERTS_SIZE = 256;

const int MAX_STATES = 32;

const float KAPPA90 = 0.5522847493f;

struct NvgState {
	NvgCompositeOperationState compositeOperation;
	int shapeAntiAlias;
	NvgPaint fill;
	NvgPaint stroke;
	float strokeWidth;
	float miterLimit;
	LineJoin lineJoin;
	LineCap lineCap;
	float alpha;
	Mat2x3 form;
	NvgScissor scissor;
}

struct NvgPoint {
	float x, y;
	float dx, dy;
	float len;
	float dmx, dmy;
	PathPointFlags flags;
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
	Vec4 bounds;
}

struct NvgContext {
	NvgParams params;
	PathCmd* commands;
	int ccommands;
	int ncommands;
	float commandx, commandy;
	NvgState[MAX_STATES] states;
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

fn float nvgCross(float dx0, float dy0, float dx1, float dy1) @local => dx1 * dy0 - dx0 * dy1;

fn float nvgNormalize(float* x, float* y) @local {
	float d = math::sqrt(x[0] * x[0] + y[0] * y[0]);
	if (d > 1e-6f) {
		float id = 1.0f / d;
		x[0] *= id;
		y[0] *= id;
	}
	return d;
}

fn void nvgDeletePathCache(NvgPathCache* c) @local {
	if (c == null) return;
	if (c.points != null) mem::free(c.points);
	if (c.paths != null) mem::free(c.paths);
	if (c.verts != null) mem::free(c.verts);
	mem::free(c);
}

fn NvgPathCache* nvgAllocPathCache() @local {
	NvgPathCache* c = mem::calloc(NvgPathCache::size);
	if (c == null) return null;

	c.points = mem::malloc(NvgPoint::size * INIT_POINTS_SIZE);
	if (c.points == null) {
		nvgDeletePathCache(c);
		return null;
	}
	c.npoints = 0;
	c.cpoints = INIT_POINTS_SIZE;

	c.paths = mem::malloc(NvgPath::size * INIT_PATHS_SIZE);
	if (c.paths == null) {
		nvgDeletePathCache(c);
		return null;
	}
	c.npaths = 0;
	c.cpaths = INIT_PATHS_SIZE;

	c.verts = mem::malloc(NvgVertex::size * INIT_VERTS_SIZE);
	if (c.verts == null) {
		nvgDeletePathCache(c);
		return null;
	}
	c.nverts = 0;
	c.cverts = INIT_VERTS_SIZE;

	return c;
}

fn void NvgContext.setDevicePixelRatio(&self, float ratio) {
	self.tessTol = 0.25f / ratio;
	self.distTol = 0.01f / ratio;
	self.fringeWidth = 1.0f / ratio;
	self.devicePxRatio = ratio;
}

fn NvgCompositeOperationState nvgCompositeOpState(int op) @local {
	int sfactor;
	int dfactor;

	switch (op) {
		case(int)CompositeOp.SOURCE_OVER:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		case(int)CompositeOp.SOURCE_IN:
			sfactor = BLEND_DST_ALPHA;
			dfactor = BLEND_ZERO;

		case(int)CompositeOp.SOURCE_OUT:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_ZERO;

		case(int)CompositeOp.ATOP:
			sfactor = BLEND_DST_ALPHA;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		case(int)CompositeOp.DESTINATION_OVER:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_ONE;

		case(int)CompositeOp.DESTINATION_IN:
			sfactor = BLEND_ZERO;
			dfactor = BLEND_SRC_ALPHA;

		case(int)CompositeOp.DESTINATION_OUT:
			sfactor = BLEND_ZERO;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		case(int)CompositeOp.DESTINATION_ATOP:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_SRC_ALPHA;

		case(int)CompositeOp.LIGHTER:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ONE;

		case(int)CompositeOp.COPY:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ZERO;

		case(int)CompositeOp.XOR:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		default:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ZERO;
	}

	NvgCompositeOperationState state;
	state.srcRGB = sfactor;
	state.dstRGB = dfactor;
	state.srcAlpha = sfactor;
	state.dstAlpha = dfactor;

	return state;
}

fn NvgState* NvgContext.getState(&self) => &self.states[self.nstates - 1];

fn void nvgSetPaintColor(NvgPaint* p, NvgColor color) @local {
	mem::clear(p, NvgPaint::size);
	nvgTransformIdentity(&p.form);
	p.radius = 0.0f;
	p.feather = 1.0f;
	p.innerColor = color;
	p.outerColor = color;
}

fn float nvgHue(float h, float m1, float m2) @local {
	if (h < 0) h += 1;
	if (h > 1) h -= 1;

	switch {
		case h < 1.0f / 6.0f:
			return m1 + (m2 - m1) * h * 6.0f;

		case h < 3.0f / 6.0f:
			return m2;

		case h < 4.0f / 6.0f:
			return m1 + (m2 - m1) * (2.0f / 3.0f - h) * 6.0f;
	}

	return m1;
}

fn NvgContext* nvgCreateInternal(NvgParams* params) {
	NvgContext* vg = mem::calloc(NvgContext::size);
	if (vg == null) return null;

	vg.params = params[0];

	vg.commands = mem::malloc(PathCmd::size * INIT_COMMANDS_SIZE);
	if (vg.commands == null) {
		vg.destroy();
		return null;
	}
	vg.ncommands = 0;
	vg.ccommands = INIT_COMMANDS_SIZE;

	vg.cache = nvgAllocPathCache();
	if (vg.cache == null) {
		vg.destroy();
		return null;
	}

	vg.save();
	vg.reset();

	vg.setDevicePixelRatio(1.0f);

	if (vg.params.renderCreate(vg.params.userPtr) == 0) {
		vg.destroy();
		return null;
	}

	return vg;
}

fn NvgParams* NvgContext.internalParams(&self) => &self.params;

fn void NvgContext.destroy(&self) {
	if (self == null) return;
	if (self.commands != null) mem::free(self.commands);
	if (self.cache != null) nvgDeletePathCache(self.cache);

	if (self.params.renderDelete != null) self.params.renderDelete(self.params.userPtr);

	mem::free(self);
}

fn void NvgContext.beginFrame(&self, float windowWidth, float windowHeight, float devicePixelRatio) {
	self.nstates = 0;
	self.save();
	self.reset();

	self.setDevicePixelRatio(devicePixelRatio);

	self.params.renderViewport(self.params.userPtr, windowWidth, windowHeight, devicePixelRatio);

	self.drawCallCount = 0;
	self.fillTriCount = 0;
	self.strokeTriCount = 0;
	self.textTriCount = 0;
}

fn void NvgContext.cancelFrame(&self) => self.params.renderCancel(self.params.userPtr);

fn void NvgContext.endFrame(&self) => self.params.renderFlush(self.params.userPtr);

fn NvgColor nvgRgb(char r, char g, char b) => nvgRgba(r, g, b, 255);

fn NvgColor nvgRgbf(float r, float g, float b) => nvgRgbaf(r, g, b, 1.0f);

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
	u = math::clamp(u, 0.0f, 1.0f);
	return c0.lerp(c1, u);
}

fn NvgColor nvgHsl(float h, float s, float l) => nvgHsla(h, s, l, 255);

fn NvgColor nvgHsla(float h, float s, float l, char a) {
	NvgColor col;
	h = h % 1.0f;
	if (h < 0.0f) h += 1.0f;
	s = math::clamp(s, 0.0f, 1.0f);
	l = math::clamp(l, 0.0f, 1.0f);
	float m2 = l <= 0.5f ?(l * (1 + s)) :(l + s - l * s);
	float m1 = 2 * l - m2;
	col.r = math::clamp(nvgHue(h + 1.0f / 3.0f, m1, m2), 0.0f, 1.0f);
	col.g = math::clamp(nvgHue(h, m1, m2), 0.0f, 1.0f);
	col.b = math::clamp(nvgHue(h - 1.0f / 3.0f, m1, m2), 0.0f, 1.0f);
	col.a = a / 255.0f;
	return col;
}

fn void nvgTransformIdentity(Mat2x3* t) {
	*t = IDENTITY_2X3;
}

fn void nvgTransformTranslate(Mat2x3* t, float tx, float ty) {
	*t = { { 1, 0, 0, 1 }, { tx, ty } };
}

fn void nvgTransformScale(Mat2x3* t, float sx, float sy) {
	*t = { { sx, 0, 0, sy }, { 0, 0 } };
}

fn void nvgTransformRotate(Mat2x3* t, float a) {
	float cs = math::cos(a);
	float sn = math::sin(a);
	*t = { { cs, sn, -sn, cs }, { 0, 0 } };
}

fn void nvgTransformSkewX(Mat2x3* t, float a) {
	*t = { { 1, 0, math::tan(a), 1 }, { 0, 0 } };
}

fn void nvgTransformSkewY(Mat2x3* t, float a) {
	*t = { { 1, math::tan(a), 0, 1 }, { 0, 0 } };
}

fn void nvgTransformMultiply(Mat2x3* t, Mat2x3* s) {
	*t = *s * *t;
}

fn void nvgTransformPremultiply(Mat2x3* t, Mat2x3* s) {
	*t = *t * *s;
}

fn int nvgTransformInverse(Mat2x3* inv, Mat2x3* t) {
	*inv = t.inverse();
	float det = t.linear.x * t.linear.w - t.linear.z * t.linear.y;
	if (det > -1e-6f && det < 1e-6f) return 0;
	return 1;
}

fn float nvgDegToRad(float deg) => deg / 180.0f * PI;

fn float nvgRadToDeg(float rad) => rad / PI * 180.0f;

fn void NvgContext.save(&self) {
	if (self.nstates >= MAX_STATES) return;
	if (self.nstates > 0) mem::copy(&self.states[self.nstates], &self.states[self.nstates - 1], NvgState::size);
	self.nstates++;
}

fn void NvgContext.restore(&self) {
	if (self.nstates <= 1) return;
	self.nstates--;
}

fn void NvgContext.reset(&self) {
	NvgState* state = self.getState();
	mem::clear(state, NvgState::size);

	nvgSetPaintColor(&state.fill, nvgRgba(255, 255, 255, 255));
	nvgSetPaintColor(&state.stroke, nvgRgba(0, 0, 0, 255));
	state.compositeOperation = nvgCompositeOpState((int)CompositeOp.SOURCE_OVER);
	state.shapeAntiAlias = 1;
	state.strokeWidth = 1.0f;
	state.miterLimit = 10.0f;
	state.lineCap = LineCap.BUTT;
	state.lineJoin = LineJoin.MITER;
	state.alpha = 1.0f;
	nvgTransformIdentity(&state.form);

	state.scissor.extent.x = -1.0f;
	state.scissor.extent.y = -1.0f;
}

fn void NvgContext.shapeAntiAlias(&self, int enabled) {
	NvgState* state = self.getState();
	state.shapeAntiAlias = enabled;
}

fn void NvgContext.strokeWidth(&self, float width) {
	NvgState* state = self.getState();
	state.strokeWidth = width;
}

fn void NvgContext.miterLimit(&self, float limit) {
	NvgState* state = self.getState();
	state.miterLimit = limit;
}

fn void NvgContext.lineCap(&self, LineCap cap) {
	NvgState* state = self.getState();
	state.lineCap = cap;
}

fn void NvgContext.lineJoin(&self, LineJoin join) {
	NvgState* state = self.getState();
	state.lineJoin = join;
}

fn void NvgContext.globalAlpha(&self, float alpha) {
	NvgState* state = self.getState();
	state.alpha = alpha;
}

fn void NvgContext.transform(&self, float a, float b, float c, float d, float e, float f) {
	NvgState* state = self.getState();
	Mat2x3 t = { { a, b, c, d }, { e, f } };
	nvgTransformPremultiply(&state.form, &t);
}

fn void NvgContext.resetTransform(&self) {
	NvgState* state = self.getState();
	nvgTransformIdentity(&state.form);
}

fn void NvgContext.translate(&self, float x, float y) {
	NvgState* state = self.getState();
	Mat2x3 t;
	nvgTransformTranslate(&t, x, y);
	nvgTransformPremultiply(&state.form, &t);
}

fn void NvgContext.rotate(&self, float angle) {
	NvgState* state = self.getState();
	Mat2x3 t;
	nvgTransformRotate(&t, angle);
	nvgTransformPremultiply(&state.form, &t);
}

fn void NvgContext.skewX(&self, float angle) {
	NvgState* state = self.getState();
	Mat2x3 t;
	nvgTransformSkewX(&t, angle);
	nvgTransformPremultiply(&state.form, &t);
}

fn void NvgContext.skewY(&self, float angle) {
	NvgState* state = self.getState();
	Mat2x3 t;
	nvgTransformSkewY(&t, angle);
	nvgTransformPremultiply(&state.form, &t);
}

fn void NvgContext.scale(&self, float x, float y) {
	NvgState* state = self.getState();
	Mat2x3 t;
	nvgTransformScale(&t, x, y);
	nvgTransformPremultiply(&state.form, &t);
}

fn void NvgContext.currentTransform(&self, float* form) {
	NvgState* state = self.getState();
	if (form == null) return;
	mem::copy(form, &state.form, float::size * 6);
}

fn void NvgContext.strokeColor(&self, NvgColor color) {
	NvgState* state = self.getState();
	nvgSetPaintColor(&state.stroke, color);
}

fn void NvgContext.strokePaint(&self, NvgPaint paint) {
	NvgState* state = self.getState();
	state.stroke = paint;
	nvgTransformMultiply(&state.stroke.form, &state.form);
}

fn void NvgContext.fillColor(&self, NvgColor color) {
	NvgState* state = self.getState();
	nvgSetPaintColor(&state.fill, color);
}

fn void NvgContext.fillPaint(&self, NvgPaint paint) {
	NvgState* state = self.getState();
	state.fill = paint;
	nvgTransformMultiply(&state.fill.form, &state.form);
}

fn int NvgContext.createImageRgba(&self, int w, int h, int imageFlags, char* data) =>
self.params.renderCreateTexture(self.params.userPtr, TextureType.RGBA, w, h, imageFlags, data);

fn void NvgContext.updateImage(&self, int image, char* data) {
	int w, h;
	self.params.renderGetTextureSize(self.params.userPtr, image, &w, &h);
	self.params.renderUpdateTexture(self.params.userPtr, image, 0, 0, w, h, data);
}

fn void NvgContext.imageSize(&self, int image, int* w, int* h) =>
self.params.renderGetTextureSize(self.params.userPtr, image, w, h);

fn void NvgContext.deleteImage(&self, int image) =>
self.params.renderDeleteTexture(self.params.userPtr, image);

fn NvgPaint NvgContext.linearGradient(
&self, float sx, float sy, float ex, float ey,
NvgColor icol, NvgColor ocol
) {
	NvgPaint p;
	float large = 1e5f;
	mem::clear(&p, NvgPaint::size);

	float dx = ex - sx;
	float dy = ey - sy;
	float d = math::sqrt(dx * dx + dy * dy);
	if (d > 0.0001f) {
		dx /= d;
		dy /= d;
	}
	else {
		dx = 0;
		dy = 1;
	}

	p.form.linear.x = dy;
	p.form.linear.y = -dx;
	p.form.linear.z = dx;
	p.form.linear.w = dy;
	p.form.trans.x = sx - dx * large;
	p.form.trans.y = sy - dy * large;

	p.extent.x = large;
	p.extent.y = large + d * 0.5f;

	p.radius = 0.0f;

	p.feather = math::max(1.0f, d);

	p.innerColor = icol;
	p.outerColor = ocol;

	return p;
}

fn NvgPaint NvgContext.radialGradient(
&self, float cx, float cy, float inr, float outr,
NvgColor icol, NvgColor ocol
) {
	NvgPaint p;
	float r = (inr + outr) * 0.5f;
	float f = (outr - inr);
	mem::clear(&p, NvgPaint::size);

	nvgTransformIdentity(&p.form);
	p.form.trans.x = cx;
	p.form.trans.y = cy;

	p.extent.x = r;
	p.extent.y = r;

	p.radius = r;

	p.feather = math::max(1.0f, f);

	p.innerColor = icol;
	p.outerColor = ocol;

	return p;
}

fn NvgPaint NvgContext.boxGradient(
&self, float x, float y, float w, float h, float r, float f,
NvgColor icol, NvgColor ocol
) {
	NvgPaint p;
	mem::clear(&p, NvgPaint::size);

	nvgTransformIdentity(&p.form);
	p.form.trans.x = x + w * 0.5f;
	p.form.trans.y = y + h * 0.5f;

	p.extent.x = w * 0.5f;
	p.extent.y = h * 0.5f;

	p.radius = r;

	p.feather = math::max(1.0f, f);

	p.innerColor = icol;
	p.outerColor = ocol;

	return p;
}

fn NvgPaint NvgContext.imagePattern(
&self, float cx, float cy, float w, float h,
float angle, int image, float alpha
) {
	NvgPaint p;
	mem::clear(&p, NvgPaint::size);

	nvgTransformRotate(&p.form, angle);
	p.form.trans.x = cx;
	p.form.trans.y = cy;

	p.extent.x = w;
	p.extent.y = h;

	p.image = image;

	p.outerColor = nvgRgbaf(1, 1, 1, alpha);
	p.innerColor = p.outerColor;

	return p;
}

fn void NvgContext.scissor(&self, float x, float y, float w, float h) {
	NvgState* state = self.getState();

	w = math::max(0.0f, w);
	h = math::max(0.0f, h);

	nvgTransformIdentity(&state.scissor.form);
	state.scissor.form.trans.x = x + w * 0.5f;
	state.scissor.form.trans.y = y + h * 0.5f;
	nvgTransformMultiply(&state.scissor.form, &state.form);

	state.scissor.extent.x = w * 0.5f;
	state.scissor.extent.y = h * 0.5f;
}

fn Vec4 nvgIsectRect(
float ax, float ay, float aw, float ah,
float bx, float by, float bw, float bh
) @local {
	float minx = math::max(ax, bx);
	float miny = math::max(ay, by);
	float maxx = math::min(ax + aw, bx + bw);
	float maxy = math::min(ay + ah, by + bh);
	return { minx, miny, math::max(0.0f, maxx - minx), math::max(0.0f, maxy - miny) };
}

fn void NvgContext.intersectScissor(&self, float x, float y, float w, float h) {
	NvgState* state = self.getState();

	if (state.scissor.extent.x < 0) {
		self.scissor(x, y, w, h);
		return;
	}

	Mat2x3 pform = state.scissor.form;
	Mat2x3 invxorm;
	Vec2 ex = state.scissor.extent;
	nvgTransformInverse(&invxorm, &state.form);
	nvgTransformMultiply(&pform, &invxorm);
	float tex = ex.x * math::abs(pform.linear.x) + ex.y * math::abs(pform.linear.z);
	float tey = ex.x * math::abs(pform.linear.y) + ex.y * math::abs(pform.linear.w);

	Vec4 r = nvgIsectRect(pform.trans.x - tex, pform.trans.y - tey, tex * 2, tey * 2, x, y, w, h);
	self.scissor(r.x, r.y, r.z, r.w);
}

fn void NvgContext.resetScissor(&self) {
	NvgState* state = self.getState();
	mem::clear(&state.scissor.form, Mat2x3::size);
	state.scissor.extent.x = -1.0f;
	state.scissor.extent.y = -1.0f;
}

fn void NvgContext.globalCompositeOperation(&self, int op) {
	NvgState* state = self.getState();
	state.compositeOperation = nvgCompositeOpState(op);
}

fn void NvgContext.globalCompositeBlendFunc(&self, int sfactor, int dfactor) =>
self.globalCompositeBlendFuncSeparate(sfactor, dfactor, sfactor, dfactor);

fn void NvgContext.globalCompositeBlendFuncSeparate(
&self, int srcRGB, int dstRGB,
int srcAlpha, int dstAlpha
) {
	NvgCompositeOperationState op;
	op.srcRGB = srcRGB;
	op.dstRGB = dstRGB;
	op.srcAlpha = srcAlpha;
	op.dstAlpha = dstAlpha;

	NvgState* state = self.getState();
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
	}
	else if (t > 1) {
		t = 1;
	}
	ddx = px + t * pqx - x;
	ddy = py + t * pqy - y;
	return ddx * ddx + ddy * ddy;
}

fn void NvgContext.appendCommands(&self, PathCmd* cmds, int ncmds) {
	NvgState* state = self.getState();

	if (self.ncommands + ncmds > self.ccommands) {
		int ccommands = self.ncommands + ncmds + self.ccommands / 2;
		PathCmd* commands = mem::realloc(self.commands, PathCmd::size * ccommands);
		if (commands == null) return;
		self.commands = commands;
		self.ccommands = ccommands;
	}

	PathCmd last = cmds[ncmds - 1];
	if (last.cmd != PathCommand.CLOSE && last.cmd != PathCommand.WINDING) {
		if (last.cmd == PathCommand.BEZIER) {
			self.commandx = last.p2.x;
			self.commandy = last.p2.y;
		}
		else {
			self.commandx = last.p0.x;
			self.commandy = last.p0.y;
		}
	}

	mem::copy(&self.commands[self.ncommands], cmds, ncmds * PathCmd::size);

	for (int i = 0; i < ncmds; i++) {
		PathCmd* cmd = &self.commands[self.ncommands + i];

		if (cmd.cmd == PathCommand.MOVE || cmd.cmd == PathCommand.LINE) {
			cmd.p0 = state.form * cmd.p0;
		}
		else if (cmd.cmd == PathCommand.BEZIER) {
			cmd.p0 = state.form * cmd.p0;
			cmd.p1 = state.form * cmd.p1;
			cmd.p2 = state.form * cmd.p2;
		}
	}

	self.ncommands += ncmds;
}

fn void NvgContext.clearPathCache(&self) {
	self.cache.npoints = 0;
	self.cache.npaths = 0;
}

fn NvgPath* NvgContext.lastPath(&self) {
	if (self.cache.npaths > 0) return &self.cache.paths[self.cache.npaths - 1];
	return null;
}

fn void NvgContext.addPath(&self) {
	if (self.cache.npaths + 1 > self.cache.cpaths) {
		int cpaths = self.cache.npaths + 1 + self.cache.cpaths / 2;
		NvgPath* paths = mem::realloc(self.cache.paths, NvgPath::size * cpaths);
		if (paths == null) return;
		self.cache.paths = paths;
		self.cache.cpaths = cpaths;
	}
	NvgPath* path = &self.cache.paths[self.cache.npaths];
	mem::clear(path, NvgPath::size);
	path.first = self.cache.npoints;
	path.winding = (int)Winding.CCW;

	self.cache.npaths++;
}

fn NvgPoint* NvgContext.lastPoint(&self) {
	if (self.cache.npoints > 0) return &self.cache.points[self.cache.npoints - 1];
	return null;
}

fn void NvgContext.addPoint(&self, float x, float y, int flags) {
	NvgPath* path = self.lastPath();
	if (path == null) return;

	if (path.count > 0 && self.cache.npoints > 0) {
		NvgPoint* pt = self.lastPoint();
		if (nvgPtEquals(pt.x, pt.y, x, y, self.distTol)) {
			pt.flags = (PathPointFlags)(char)((int)pt.flags | flags);
			return;
		}
	}

	if (self.cache.npoints + 1 > self.cache.cpoints) {
		int cpoints = self.cache.npoints + 1 + self.cache.cpoints / 2;
		NvgPoint* points = mem::realloc(self.cache.points, NvgPoint::size * cpoints);
		if (points == null) return;
		self.cache.points = points;
		self.cache.cpoints = cpoints;
	}

	NvgPoint* pt = &self.cache.points[self.cache.npoints];
	mem::clear(pt, NvgPoint::size);
	pt.x = x;
	pt.y = y;
	pt.flags = (PathPointFlags)(char)flags;

	self.cache.npoints++;
	path.count++;
}

fn void NvgContext.closePathCache(&self) {
	NvgPath* path = self.lastPath();
	if (path == null) return;
	path.closed = 1;
}

fn void NvgContext.pathWindingCache(&self, int winding) {
	NvgPath* path = self.lastPath();
	if (path == null) return;
	path.winding = winding;
}

fn NvgVertex* NvgContext.allocTempVerts(&self, int nverts) {
	if (nverts > self.cache.cverts) {
		int cverts = (nverts + 0xff) & ~0xff;
		NvgVertex* verts = mem::realloc(self.cache.verts, NvgVertex::size * cverts);
		if (verts == null) return null;
		self.cache.verts = verts;
		self.cache.cverts = cverts;
	}

	return self.cache.verts;
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

fn void NvgContext.tesselateBezier(&self,
float x1, float y1, float x2, float y2,
float x3, float y3, float x4, float y4,
int level, int type
) {
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
	float d2 = math::abs(((x2 - x4) * dy - (y2 - y4) * dx));
	float d3 = math::abs(((x3 - x4) * dy - (y3 - y4) * dx));

	if ((d2 + d3) * (d2 + d3) < self.tessTol * (dx * dx + dy * dy)) {
		self.addPoint(x4, y4, type);
		return;
	}

	float x234 = (x23 + x34) * 0.5f;
	float y234 = (y23 + y34) * 0.5f;
	float x1234 = (x123 + x234) * 0.5f;
	float y1234 = (y123 + y234) * 0.5f;

	self.tesselateBezier(x1, y1, x12, y12, x123, y123, x1234, y1234, level + 1, 0);
	self.tesselateBezier(x1234, y1234, x234, y234, x34, y34, x4, y4, level + 1, type);
}

fn void NvgContext.flattenPaths(&self) {
	NvgPathCache* cache = self.cache;

	if (cache.npaths > 0) return;

	for (int i = 0; i < self.ncommands; i++) {
		PathCmd* cmd = &self.commands[i];

		switch (cmd.cmd) {
			case PathCommand.MOVE:
				self.addPath();
				self.addPoint(cmd.p0.x, cmd.p0.y, NVG_PT_CORNER);

			case PathCommand.LINE:
				self.addPoint(cmd.p0.x, cmd.p0.y, NVG_PT_CORNER);

			case PathCommand.BEZIER:
				NvgPoint* last = self.lastPoint();
				if (last != null) self.tesselateBezier(
				last.x, last.y,
				cmd.p0.x, cmd.p0.y,
				cmd.p1.x, cmd.p1.y,
				cmd.p2.x, cmd.p2.y,
				0, NVG_PT_CORNER
				);

			case PathCommand.CLOSE:
				self.closePathCache();

			case PathCommand.WINDING:
				self.pathWindingCache((int)cmd.p0.x);
		}
	}

	cache.bounds.x = 1e6f;
	cache.bounds.y = 1e6f;
	cache.bounds.z = -1e6f;
	cache.bounds.w = -1e6f;

	for (int j = 0; j < cache.npaths; j++) {
		NvgPath* path = &cache.paths[j];
		NvgPoint* pts = &cache.points[path.first];

		NvgPoint* p0 = &pts[path.count - 1];
		NvgPoint* p1 = &pts[0];
		if (nvgPtEquals(p0.x, p0.y, p1.x, p1.y, self.distTol)) {
			path.count--;
			p0 = &pts[path.count - 1];
			path.closed = 1;
		}

		if (path.count > 2) {
			float area = nvgPolyArea(pts, path.count);
			if (path.winding == (int)Winding.CCW && area < 0.0f) nvgPolyReverse(pts, path.count);
			if (path.winding == (int)Winding.CW && area > 0.0f) nvgPolyReverse(pts, path.count);
		}

		for (int k = 0; k < path.count; k++) {
			p0.dx = p1.x - p0.x;
			p0.dy = p1.y - p0.y;
			p0.len = nvgNormalize(&p0.dx, &p0.dy);
			cache.bounds.x = math::min(cache.bounds.x, p0.x);
			cache.bounds.y = math::min(cache.bounds.y, p0.y);
			cache.bounds.z = math::max(cache.bounds.z, p0.x);
			cache.bounds.w = math::max(cache.bounds.w, p0.y);
			p0 = p1;
			p1++;
		}
	}
}

fn int nvgCurveDivs(float r, float arc, float tol) @local {
	float da = math::acos(r / (r + tol)) * 2.0f;
	return math::max(2, (int)math::ceil(arc / da));
}

fn void nvgChooseBevel(
int bevel, NvgPoint* p0, NvgPoint* p1, float w,
float* x0, float* y0, float* x1, float* y1
) @local {
	if (bevel) {
		x0[0] = p1.x + p0.dy * w;
		y0[0] = p1.y - p0.dx * w;
		x1[0] = p1.x + p1.dy * w;
		y1[0] = p1.y - p1.dx * w;
	}
	else {
		x0[0] = p1.x + p1.dmx * w;
		y0[0] = p1.y + p1.dmy * w;
		x1[0] = p1.x + p1.dmx * w;
		y1[0] = p1.y + p1.dmy * w;
	}
}

fn NvgVertex* nvgRoundJoin(
NvgVertex* dst, NvgPoint* p0, NvgPoint* p1,
float lw, float rw, float lu, float ru, int ncap, float fringe
) @local {
	float dlx0 = p0.dy;
	float dly0 = -p0.dx;
	float dlx1 = p1.dy;
	float dly1 = -p1.dx;

	if (p1.flags.left) {
		float lx0, ly0, lx1, ly1;
		nvgChooseBevel((int)p1.flags & NVG_PR_INNERBEVEL, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);
		float a0 = math::atan2(-dly0, -dlx0);
		float a1 = math::atan2(-dly1, -dlx1);
		if (a1 > a0) a1 -= PI * 2;

		nvgVset(dst, lx0, ly0, lu, 1);
		dst++;
		nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
		dst++;

		int n = math::clamp((int)math::ceil(((a0 - a1) / PI) * ncap), 2, ncap);
		for (int i = 0; i < n; i++) {
			float u = i / (float)(n - 1);
			float a = a0 + u * (a1 - a0);
			float rx = p1.x + math::cos(a) * rw;
			float ry = p1.y + math::sin(a) * rw;
			nvgVset(dst, p1.x, p1.y, 0.5f, 1);
			dst++;
			nvgVset(dst, rx, ry, ru, 1);
			dst++;
		}

		nvgVset(dst, lx1, ly1, lu, 1);
		dst++;
		nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
		dst++;
	}
	else {
		float rx0, ry0, rx1, ry1;
		nvgChooseBevel((int)p1.flags & NVG_PR_INNERBEVEL, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);
		float a0 = math::atan2(dly0, dlx0);
		float a1 = math::atan2(dly1, dlx1);
		if (a1 < a0) a1 += PI * 2;

		nvgVset(dst, p1.x + dlx0 * rw, p1.y + dly0 * rw, lu, 1);
		dst++;
		nvgVset(dst, rx0, ry0, ru, 1);
		dst++;

		int n = math::clamp((int)math::ceil(((a1 - a0) / PI) * ncap), 2, ncap);
		for (int i = 0; i < n; i++) {
			float u = i / (float)(n - 1);
			float a = a0 + u * (a1 - a0);
			float lx = p1.x + math::cos(a) * lw;
			float ly = p1.y + math::sin(a) * lw;
			nvgVset(dst, lx, ly, lu, 1);
			dst++;
			nvgVset(dst, p1.x, p1.y, 0.5f, 1);
			dst++;
		}

		nvgVset(dst, p1.x + dlx1 * rw, p1.y + dly1 * rw, lu, 1);
		dst++;
		nvgVset(dst, rx1, ry1, ru, 1);
		dst++;
	}

	return dst;
}

fn NvgVertex* nvgBevelJoin(
NvgVertex* dst, NvgPoint* p0, NvgPoint* p1,
float lw, float rw, float lu, float ru, float fringe
) @local {
	float dlx0 = p0.dy;
	float dly0 = -p0.dx;
	float dlx1 = p1.dy;
	float dly1 = -p1.dx;

	if (p1.flags.left) {
		float lx0, ly0, lx1, ly1;
		nvgChooseBevel((int)p1.flags & NVG_PR_INNERBEVEL, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);

		nvgVset(dst, lx0, ly0, lu, 1);
		dst++;
		nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
		dst++;

		if (p1.flags.bevel) {
			nvgVset(dst, lx0, ly0, lu, 1);
			dst++;
			nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
			dst++;

			nvgVset(dst, lx1, ly1, lu, 1);
			dst++;
			nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
			dst++;
		}
		else {
			float rx0 = p1.x - p1.dmx * rw;
			float ry0 = p1.y - p1.dmy * rw;

			nvgVset(dst, p1.x, p1.y, 0.5f, 1);
			dst++;
			nvgVset(dst, p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
			dst++;

			nvgVset(dst, rx0, ry0, ru, 1);
			dst++;
			nvgVset(dst, rx0, ry0, ru, 1);
			dst++;

			nvgVset(dst, p1.x, p1.y, 0.5f, 1);
			dst++;
			nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
			dst++;
		}

		nvgVset(dst, lx1, ly1, lu, 1);
		dst++;
		nvgVset(dst, p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
		dst++;
	}
	else {
		float rx0, ry0, rx1, ry1;
		nvgChooseBevel((int)p1.flags & NVG_PR_INNERBEVEL, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);

		nvgVset(dst, p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1);
		dst++;
		nvgVset(dst, rx0, ry0, ru, 1);
		dst++;

		if (p1.flags.bevel) {
			nvgVset(dst, p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1);
			dst++;
			nvgVset(dst, rx0, ry0, ru, 1);
			dst++;

			nvgVset(dst, p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1);
			dst++;
			nvgVset(dst, rx1, ry1, ru, 1);
			dst++;
		}
		else {
			float lx0 = p1.x + p1.dmx * lw;
			float ly0 = p1.y + p1.dmy * lw;

			nvgVset(dst, p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1);
			dst++;
			nvgVset(dst, p1.x, p1.y, 0.5f, 1);
			dst++;

			nvgVset(dst, lx0, ly0, lu, 1);
			dst++;
			nvgVset(dst, lx0, ly0, lu, 1);
			dst++;

			nvgVset(dst, p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1);
			dst++;
			nvgVset(dst, p1.x, p1.y, 0.5f, 1);
			dst++;
		}

		nvgVset(dst, p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1);
		dst++;
		nvgVset(dst, rx1, ry1, ru, 1);
		dst++;
	}

	return dst;
}

fn NvgVertex* nvgButtCapStart(
NvgVertex* dst, NvgPoint* p,
float dx, float dy, float w, float d,
float aa, float u0, float u1
) @local {
	float px = p.x - dx * d;
	float py = p.y - dy * d;
	float dlx = dy;
	float dly = -dx;

	nvgVset(dst, px + dlx * w - dx * aa, py + dly * w - dy * aa, u0, 0);
	dst++;
	nvgVset(dst, px - dlx * w - dx * aa, py - dly * w - dy * aa, u1, 0);
	dst++;
	nvgVset(dst, px + dlx * w, py + dly * w, u0, 1);
	dst++;
	nvgVset(dst, px - dlx * w, py - dly * w, u1, 1);
	dst++;

	return dst;
}

fn NvgVertex* nvgButtCapEnd(
NvgVertex* dst, NvgPoint* p,
float dx, float dy, float w, float d,
float aa, float u0, float u1
) @local {
	float px = p.x + dx * d;
	float py = p.y + dy * d;
	float dlx = dy;
	float dly = -dx;

	nvgVset(dst, px + dlx * w, py + dly * w, u0, 1);
	dst++;
	nvgVset(dst, px - dlx * w, py - dly * w, u1, 1);
	dst++;
	nvgVset(dst, px + dlx * w + dx * aa, py + dly * w + dy * aa, u0, 0);
	dst++;
	nvgVset(dst, px - dlx * w + dx * aa, py - dly * w + dy * aa, u1, 0);
	dst++;

	return dst;
}

fn NvgVertex* nvgRoundCapStart(
NvgVertex* dst, NvgPoint* p,
float dx, float dy, float w, int ncap,
float aa, float u0, float u1
) @local {
	float px = p.x;
	float py = p.y;
	float dlx = dy;
	float dly = -dx;

	for (int i = 0; i < ncap; i++) {
		float a = i / (float)(ncap - 1) * PI;
		float ax = math::cos(a) * w;
		float ay = math::sin(a) * w;
		nvgVset(dst, px - dlx * ax - dx * ay, py - dly * ax - dy * ay, u0, 1);
		dst++;
		nvgVset(dst, px, py, 0.5f, 1);
		dst++;
	}

	nvgVset(dst, px + dlx * w, py + dly * w, u0, 1);
	dst++;
	nvgVset(dst, px - dlx * w, py - dly * w, u1, 1);
	dst++;

	return dst;
}

fn NvgVertex* nvgRoundCapEnd(
NvgVertex* dst, NvgPoint* p,
float dx, float dy, float w, int ncap,
float aa, float u0, float u1
) @local {
	float px = p.x;
	float py = p.y;
	float dlx = dy;
	float dly = -dx;

	nvgVset(dst, px + dlx * w, py + dly * w, u0, 1);
	dst++;
	nvgVset(dst, px - dlx * w, py - dly * w, u1, 1);
	dst++;

	for (int i = 0; i < ncap; i++) {
		float a = i / (float)(ncap - 1) * PI;
		float ax = math::cos(a) * w;
		float ay = math::sin(a) * w;
		nvgVset(dst, px, py, 0.5f, 1);
		dst++;
		nvgVset(dst, px - dlx * ax + dx * ay, py - dly * ax + dy * ay, u0, 1);
		dst++;
	}

	return dst;
}

fn void NvgContext.calculateJoins(&self, float w, LineJoin lineJoin, float miterLimit) {
	NvgPathCache* cache = self.cache;
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

		p1.flags = { .corner = p1.flags.corner };

			float cross = p1.dx * p0.dy - p0.dx * p1.dy;
			if (cross > 0.0f) {
				nleft++;
				p1.flags.left = true;
			}

			float limit = math::max(1.01f, math::min(p0.len, p1.len) * iw);
			if ((dmr2 * limit * limit) < 1.0f) p1.flags.innerBevel = true;

			if (p1.flags.corner) {
				if ((dmr2 * miterLimit * miterLimit) < 1.0f || lineJoin == LineJoin.BEVEL || lineJoin == LineJoin.ROUND) {
					p1.flags.bevel = true;
				}
			}

			if ((p1.flags.bevel || p1.flags.innerBevel)) path.nbevel++;

			p0 = p1;
			p1++;
		}

		path.convex = (nleft == path.count) ? 1 : 0;
	}
}

fn int NvgContext.expandStroke(&self, float w, float fringe, LineCap lineCap, LineJoin lineJoin, float miterLimit) {
	NvgPathCache* cache = self.cache;
	float aa = fringe;
	float u0 = 0.0f;
	float u1 = 1.0f;
	int ncap = nvgCurveDivs(w, PI, self.tessTol);

	w += aa * 0.5f;

	if (aa == 0.0f) {
		u0 = 0.5f;
		u1 = 0.5f;
	}

	self.calculateJoins(w, lineJoin, miterLimit);

	int cverts = 0;
	for (int i = 0; i < cache.npaths; i++) {
		NvgPath* path = &cache.paths[i];
		int loop = (path.closed == 0) ? 0 : 1;

		if (lineJoin == LineJoin.ROUND) {
			cverts += (path.count + path.nbevel * (ncap + 2) + 1) * 2;
		}
		else {
			cverts += (path.count + path.nbevel * 5 + 1) * 2;
		}

		if (loop == 0) {
			if (lineCap == LineCap.ROUND) {
				cverts += (ncap * 2 + 2) * 2;
			}
			else {
				cverts += (3 + 3) * 2;
			}
		}
	}

	NvgVertex* verts = self.allocTempVerts(cverts);
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
		}
		else {
			p0 = &pts[0];
			p1 = &pts[1];
			s = 1;
			e = path.count - 1;
		}

		if (loop == 0) {
			dx = p1.x - p0.x;
			dy = p1.y - p0.y;
			nvgNormalize(&dx, &dy);

			switch (lineCap) {
				case LineCap.BUTT:
					dst = nvgButtCapStart(dst, p0, dx, dy, w, -aa * 0.5f, aa, u0, u1);

				case LineCap.SQUARE:
					dst = nvgButtCapStart(dst, p0, dx, dy, w, w - aa, aa, u0, u1);

				case LineCap.ROUND:
					dst = nvgRoundCapStart(dst, p0, dx, dy, w, ncap, aa, u0, u1);
			}
		}

		for (int j = s; j < e; j++) {
			if ((p1.flags.bevel || p1.flags.innerBevel)) {
				if (lineJoin == LineJoin.ROUND) {
					dst = nvgRoundJoin(dst, p0, p1, w, w, u0, u1, ncap, aa);
				}
				else {
					dst = nvgBevelJoin(dst, p0, p1, w, w, u0, u1, aa);
				}
			}
			else {
				nvgVset(dst, p1.x + (p1.dmx * w), p1.y + (p1.dmy * w), u0, 1);
				dst++;
				nvgVset(dst, p1.x - (p1.dmx * w), p1.y - (p1.dmy * w), u1, 1);
				dst++;
			}
			p0 = p1;
			p1++;
		}

		if (loop) {
			nvgVset(dst, verts[0].x, verts[0].y, u0, 1);
			dst++;
			nvgVset(dst, verts[1].x, verts[1].y, u1, 1);
			dst++;
		}
		else {
			dx = p1.x - p0.x;
			dy = p1.y - p0.y;
			nvgNormalize(&dx, &dy);

			switch (lineCap) {
				case LineCap.BUTT:
					dst = nvgButtCapEnd(dst, p1, dx, dy, w, -aa * 0.5f, aa, u0, u1);

				case LineCap.SQUARE:
					dst = nvgButtCapEnd(dst, p1, dx, dy, w, w - aa, aa, u0, u1);

				case LineCap.ROUND:
					dst = nvgRoundCapEnd(dst, p1, dx, dy, w, ncap, aa, u0, u1);
			}
		}

		path.nstroke = (int)(dst - verts);

		verts = dst;
	}

	return 1;
}

fn int NvgContext.expandFill(&self, float w, LineJoin lineJoin, float miterLimit) {
	NvgPathCache* cache = self.cache;
	float aa = self.fringeWidth;
	int fringe = (int)(w > 0.0f);

	self.calculateJoins(w, lineJoin, miterLimit);

	int cverts = 0;
	for (int i = 0; i < cache.npaths; i++) {
		NvgPath* path = &cache.paths[i];
		cverts += path.count + path.nbevel + 1;
		if (fringe) {
			cverts += (path.count + path.nbevel * 5 + 1) * 2;
		}
	}

	NvgVertex* verts = self.allocTempVerts(cverts);
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
				if (p1.flags.bevel) {
					float dlx0 = p0.dy;
					float dly0 = -p0.dx;
					float dlx1 = p1.dy;
					float dly1 = -p1.dx;
					if (p1.flags.left) {
						float lx = p1.x + p1.dmx * woff;
						float ly = p1.y + p1.dmy * woff;
						nvgVset(dst, lx, ly, 0.5f, 1);
						dst++;
					}
					else {
						float lx0 = p1.x + dlx0 * woff;
						float ly0 = p1.y + dly0 * woff;
						float lx1 = p1.x + dlx1 * woff;
						float ly1 = p1.y + dly1 * woff;
						nvgVset(dst, lx0, ly0, 0.5f, 1);
						dst++;
						nvgVset(dst, lx1, ly1, 0.5f, 1);
						dst++;
					}
				}
				else {
					nvgVset(dst, p1.x + (p1.dmx * woff), p1.y + (p1.dmy * woff), 0.5f, 1);
					dst++;
				}
				p0 = p1;
				p1++;
			}
		}
		else {
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
				if ((p1.flags.bevel || p1.flags.innerBevel)) {
					dst = nvgBevelJoin(dst, p0, p1, lw, rw, lu, ru, self.fringeWidth);
				}
				else {
					nvgVset(dst, p1.x + (p1.dmx * lw), p1.y + (p1.dmy * lw), lu, 1);
					dst++;
					nvgVset(dst, p1.x - (p1.dmx * rw), p1.y - (p1.dmy * rw), ru, 1);
					dst++;
				}
				p0 = p1;
				p1++;
			}

			nvgVset(dst, verts[0].x, verts[0].y, lu, 1);
			dst++;
			nvgVset(dst, verts[1].x, verts[1].y, ru, 1);
			dst++;

			path.nstroke = (int)(dst - verts);
			verts = dst;
		}
		else {
			path.stroke = null;
			path.nstroke = 0;
		}
	}

	return 1;
}

fn void NvgContext.beginPath(&self) {
	self.ncommands = 0;
	self.clearPathCache();
}

fn void NvgContext.moveTo(&self, float x, float y) {
	PathCmd cmd = { .cmd = PathCommand.MOVE, .p0 = { x, y } };
	self.appendCommands(&cmd, 1);
}

fn void NvgContext.lineTo(&self, float x, float y) {
	PathCmd cmd = { .cmd = PathCommand.LINE, .p0 = { x, y } };
	self.appendCommands(&cmd, 1);
}

fn void NvgContext.bezierTo(&self, float c1x, float c1y, float c2x, float c2y, float x, float y) {
	PathCmd cmd = { .cmd = PathCommand.BEZIER, .p0 = { c1x, c1y }, .p1 = { c2x, c2y }, .p2 = { x, y } };
	self.appendCommands(&cmd, 1);
}

fn void NvgContext.quadTo(&self, float cx, float cy, float x, float y) {
	float x0 = self.commandx;
	float y0 = self.commandy;
	PathCmd cmd = {
		.cmd = PathCommand.BEZIER,
		.p0 = { x0 + 2.0f / 3.0f * (cx - x0), y0 + 2.0f / 3.0f * (cy - y0) },
		.p1 = { x + 2.0f / 3.0f * (cx - x), y + 2.0f / 3.0f * (cy - y) },
		.p2 = { x, y }
	};
	self.appendCommands(&cmd, 1);
}

fn void NvgContext.arcTo(&self, float x1, float y1, float x2, float y2, float radius) {
	float x0 = self.commandx;
	float y0 = self.commandy;

	if (self.ncommands == 0) return;

	if (nvgPtEquals(x0, y0, x1, y1, self.distTol) ||
	nvgPtEquals(x1, y1, x2, y2, self.distTol) ||
	nvgDistPtSeg(x1, y1, x0, y0, x2, y2) < self.distTol * self.distTol ||
	radius < self.distTol) {
		self.lineTo(x1, y1);
		return;
	}

	float dx0 = x0 - x1;
	float dy0 = y0 - y1;
	float dx1 = x2 - x1;
	float dy1 = y2 - y1;
	nvgNormalize(&dx0, &dy0);
	nvgNormalize(&dx1, &dy1);
	float a = math::acos(dx0 * dx1 + dy0 * dy1);
	float d = radius / math::tan(a / 2.0f);

	if (d > 10000.0f) {
		self.lineTo(x1, y1);
		return;
	}

	float cx, cy, a0, a1;
	int dir;

	if (nvgCross(dx0, dy0, dx1, dy1) > 0.0f) {
		cx = x1 + dx0 * d + dy0 * radius;
		cy = y1 + dy0 * d + -dx0 * radius;
		a0 = math::atan2(dx0, -dy0);
		a1 = math::atan2(-dx1, dy1);
		dir = (int)Winding.CW;
	}
	else {
		cx = x1 + dx0 * d + -dy0 * radius;
		cy = y1 + dy0 * d + dx0 * radius;
		a0 = math::atan2(-dx0, dy0);
		a1 = math::atan2(dx1, -dy1);
		dir = (int)Winding.CCW;
	}

	self.arc(cx, cy, radius, a0, a1, dir);
}

fn void NvgContext.closePath(&self) {
	PathCmd cmd = { .cmd = PathCommand.CLOSE };
	self.appendCommands(&cmd, 1);
}

fn void NvgContext.pathWinding(&self, int dir) {
	PathCmd cmd = { .cmd = PathCommand.WINDING, .p0 = { (float)dir, 0.0f } };
	self.appendCommands(&cmd, 1);
}

fn void NvgContext.arc(&self, float cx, float cy, float r, float a0, float a1, int dir) {
	float a, da, hda, kappa;
	float dx, dy, x, y;
	float tanx, tany, px, py;
	float ptanx, ptany;
	PathCmd[108] cmds;
	int ndivs, ncmds;
	PathCommand firstCmd = self.ncommands > 0 ? PathCommand.LINE : PathCommand.MOVE;

	da = a1 - a0;
	if (dir == (int)Winding.CW) {
		if (math::abs(da) >= PI * 2) {
			da = PI * 2;
		}
		else {
			while (da < 0.0f) da += PI * 2;
		}
	}
	else {
		if (math::abs(da) >= PI * 2) {
			da = -PI * 2;
		}
		else {
			while (da > 0.0f) da -= PI * 2;
		}
	}

	ndivs = math::max(1, math::min((int)(math::abs(da) / (PI * 0.5f) + 0.5f), 5));
	hda = (da / (float)ndivs) / 2.0f;
	kappa = math::abs(4.0f / 3.0f * (1.0f - math::cos(hda)) / math::sin(hda));

	if (dir == (int)Winding.CCW) kappa = -kappa;

	ncmds = 0;
	for (int i = 0; i <= ndivs; i++) {
		a = a0 + da * (i / (float)ndivs);
		dx = math::cos(a);
		dy = math::sin(a);
		x = cx + dx * r;
		y = cy + dy * r;
		tanx = -dy * r * kappa;
		tany = dx * r * kappa;

		if (i == 0) {
			cmds[ncmds].cmd = firstCmd;
			cmds[ncmds].p0 = { x, y };
			ncmds++;
		}
		else {
			cmds[ncmds].cmd = PathCommand.BEZIER;
			cmds[ncmds].p0 = { px + ptanx, py + ptany };
			cmds[ncmds].p1 = { x - tanx, y - tany };
			cmds[ncmds].p2 = { x, y };
			ncmds++;
		}
		px = x;
		py = y;
		ptanx = tanx;
		ptany = tany;
	}

	self.appendCommands(&cmds[0], ncmds);
}

fn void NvgContext.rect(&self, float x, float y, float w, float h) {
	PathCmd[*] cmds = {
		{ .cmd = PathCommand.MOVE, .p0 = { x, y } },
		{ .cmd = PathCommand.LINE, .p0 = { x, y + h } },
		{ .cmd = PathCommand.LINE, .p0 = { x + w, y + h } },
		{ .cmd = PathCommand.LINE, .p0 = { x + w, y } },
		{ .cmd = PathCommand.CLOSE }
	};

	self.appendCommands(&cmds[0], cmds.len);
}

fn void NvgContext.roundedRect(&self, float x, float y, float w, float h, float r) =>
self.roundedRectVarying(x, y, w, h, r, r, r, r);

fn void NvgContext.roundedRectVarying(
&self, float x, float y, float w, float h,
float radTopLeft, float radTopRight,
float radBottomRight, float radBottomLeft
) {
	if (radTopLeft < 0.1f && radTopRight < 0.1f && radBottomRight < 0.1f && radBottomLeft < 0.1f) {
		self.rect(x, y, w, h);
		return;
	}

	float halfw = math::abs(w) * 0.5f;
	float halfh = math::abs(h) * 0.5f;
	float rxBL = math::min(radBottomLeft, halfw) * ((w) >= 0.0f ? 1.0f : -1.0f);
	float ryBL = math::min(radBottomLeft, halfh) * ((h) >= 0.0f ? 1.0f : -1.0f);
	float rxBR = math::min(radBottomRight, halfw) * ((w) >= 0.0f ? 1.0f : -1.0f);
	float ryBR = math::min(radBottomRight, halfh) * ((h) >= 0.0f ? 1.0f : -1.0f);
	float rxTR = math::min(radTopRight, halfw) * ((w) >= 0.0f ? 1.0f : -1.0f);
	float ryTR = math::min(radTopRight, halfh) * ((h) >= 0.0f ? 1.0f : -1.0f);
	float rxTL = math::min(radTopLeft, halfw) * ((w) >= 0.0f ? 1.0f : -1.0f);
	float ryTL = math::min(radTopLeft, halfh) * ((h) >= 0.0f ? 1.0f : -1.0f);

	PathCmd[*] cmds = {
		{ .cmd = PathCommand.MOVE, .p0 = { x, y + ryTL } },
		{ .cmd = PathCommand.LINE, .p0 = { x, y + h - ryBL } },
		{
			.cmd = PathCommand.BEZIER,
			.p0 = { x, y + h - ryBL * (1 - KAPPA90) },
			.p1 = { x + rxBL * (1 - KAPPA90), y + h }, .p2 = { x + rxBL, y + h }
		},
		{ .cmd = PathCommand.LINE, .p0 = { x + w - rxBR, y + h } },
		{
			.cmd = PathCommand.BEZIER,
			.p0 = { x + w - rxBR * (1 - KAPPA90), y + h },
			.p1 = { x + w, y + h - ryBR * (1 - KAPPA90) },
			.p2 = { x + w, y + h - ryBR }
		},
		{ .cmd = PathCommand.LINE, .p0 = { x + w, y + ryTR } },
		{
			.cmd = PathCommand.BEZIER,
			.p0 = { x + w, y + ryTR * (1 - KAPPA90) },
			.p1 = { x + w - rxTR * (1 - KAPPA90), y },
			.p2 = { x + w - rxTR, y }
		},
		{ .cmd = PathCommand.LINE, .p0 = { x + rxTL, y } },
		{
			.cmd = PathCommand.BEZIER,
			.p0 = { x + rxTL * (1 - KAPPA90), y },
			.p1 = { x, y + ryTL * (1 - KAPPA90) },
			.p2 = { x, y + ryTL }
		},
		{ .cmd = PathCommand.CLOSE }
	};

	self.appendCommands(&cmds[0], cmds.len);
}

fn void NvgContext.ellipse(&self, float cx, float cy, float rx, float ry) {
	PathCmd[*] cmds = {
		{ .cmd = PathCommand.MOVE, .p0 = { cx - rx, cy } },
		{ .cmd = PathCommand.BEZIER, .p0 = { cx - rx, cy + ry * KAPPA90 }, .p1 = { cx - rx * KAPPA90, cy + ry }, .p2 = { cx, cy + ry } },
		{ .cmd = PathCommand.BEZIER, .p0 = { cx + rx * KAPPA90, cy + ry }, .p1 = { cx + rx, cy + ry * KAPPA90 }, .p2 = { cx + rx, cy } },
		{ .cmd = PathCommand.BEZIER, .p0 = { cx + rx, cy - ry * KAPPA90 }, .p1 = { cx + rx * KAPPA90, cy - ry }, .p2 = { cx, cy - ry } },
		{ .cmd = PathCommand.BEZIER, .p0 = { cx - rx * KAPPA90, cy - ry }, .p1 = { cx - rx, cy - ry * KAPPA90 }, .p2 = { cx - rx, cy } },
		{ .cmd = PathCommand.CLOSE }
	};
	self.appendCommands(&cmds[0], cmds.len);
}

fn void NvgContext.circle(&self, float cx, float cy, float r) {
	self.ellipse(cx, cy, r, r);
}

fn void NvgContext.fill(&self) {
	NvgState* state = self.getState();
	NvgPaint fillPaint = state.fill;

	self.flattenPaths();
	if (self.params.edgeAntiAlias && state.shapeAntiAlias) {
		self.expandFill(self.fringeWidth, LineJoin.MITER, 2.4f);
	}
	else {
		self.expandFill(0.0f, LineJoin.MITER, 2.4f);
	}

	fillPaint.innerColor.a *= state.alpha;
	fillPaint.outerColor.a *= state.alpha;

	self.params.renderFill(self.params.userPtr, &fillPaint, state.compositeOperation, &state.scissor,
	self.fringeWidth, &self.cache.bounds[0], self.cache.paths, self.cache.npaths);

	for (int i = 0; i < self.cache.npaths; i++) {
		NvgPath* path = &self.cache.paths[i];
		self.fillTriCount += path.nfill - 2;
		self.fillTriCount += path.nstroke - 2;
		self.drawCallCount += 2;
	}
}

fn void NvgContext.stroke(&self) {
	NvgState* state = self.getState();
	float scale = state.form.averageScale();
	float strokeWidth = math::clamp(state.strokeWidth * scale, 0.0f, 200.0f);
	NvgPaint strokePaint = state.stroke;

	if (strokeWidth < self.fringeWidth) {
		float alpha = math::clamp(strokeWidth / self.fringeWidth, 0.0f, 1.0f);
		strokePaint.innerColor.a *= alpha * alpha;
		strokePaint.outerColor.a *= alpha * alpha;
		strokeWidth = self.fringeWidth;
	}

	strokePaint.innerColor.a *= state.alpha;
	strokePaint.outerColor.a *= state.alpha;

	self.flattenPaths();

	if (self.params.edgeAntiAlias && state.shapeAntiAlias) {
		self.expandStroke(strokeWidth * 0.5f, self.fringeWidth, state.lineCap, state.lineJoin, state.miterLimit);
	}
	else {
		self.expandStroke(strokeWidth * 0.5f, 0.0f, state.lineCap, state.lineJoin, state.miterLimit);
	}

	self.params.renderStroke(self.params.userPtr, &strokePaint, state.compositeOperation, &state.scissor,
	self.fringeWidth, strokeWidth, self.cache.paths, self.cache.npaths);

	for (int i = 0; i < self.cache.npaths; i++) {
		NvgPath* path = &self.cache.paths[i];
		self.strokeTriCount += path.nstroke - 2;
		self.drawCallCount++;
	}
}
