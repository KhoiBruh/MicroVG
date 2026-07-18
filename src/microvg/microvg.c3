module microvg;

import std::core::mem;
import std::math;

const int INIT_COMMANDS_SIZE = 256;
const int INIT_POINTS_SIZE = 128;
const int INIT_PATHS_SIZE = 16;
const int INIT_VERTS_SIZE = 256;

const int MAX_STATES = 32;

struct MicroVG {
	Params params;
	PathCmd* commands;
	int ccommands;
	int ncommands;
	float commandx, commandy;
	State[MAX_STATES] states;
	int nstates;
	PathCache* cache;
	float tessTol;
	float distTol;
	float fringeWidth;
	float pxRatio;
	int drawCallCount;
	int fillTriCount;
	int strokeTriCount;
	int textTriCount;
}

fn Vertex* Vertex.push(&self, Vec2 pos, Vec2 uv) @inline {
	self.pos = pos;
	self.uv = uv;
	return self + 1;
}

fn Vertex* Vertex.push_xyuv(&self, float x, float y, float u, float v) @inline {
	self.pos = { x, y };
	self.uv = { u, v };
	return self + 1;
}

fn Vertex* Vertex.push_uv(&self, Vec2 pos, float u, float v) @inline {
	self.pos = pos;
	self.uv = { u, v };
	return self + 1;
}

fn void MicroVG.setPxRatio(&self, float ratio) {
	self.tessTol = 0.25f / ratio;
	self.distTol = 0.01f / ratio;
	self.fringeWidth = 1.0f / ratio;
	self.pxRatio = ratio;
}

fn State* MicroVG.getState(&self) => &self.states[self.nstates - 1];

fn MicroVG* createInternal(Params* params) {
	MicroVG* vg = mem::calloc(MicroVG::size);
	if (vg == null) return null;

	vg.params = *params;

	vg.commands = mem::malloc(PathCmd::size * INIT_COMMANDS_SIZE);
	if (vg.commands == null) {
		vg.destroy();
		return null;
	}
	vg.ncommands = 0;
	vg.ccommands = INIT_COMMANDS_SIZE;

	vg.cache = allocPathCache();
	if (vg.cache == null) {
		vg.destroy();
		return null;
	}

	vg.save();
	vg.reset();

	vg.setPxRatio(1.0f);

	if (vg.params.renderCreate(vg.params.userPtr) == 0) {
		vg.destroy();
		return null;
	}

	return vg;
}

fn void MicroVG.destroy(&self) {
	if (self == null) return;
	if (self.commands != null) mem::free(self.commands);
	if (self.cache != null) self.cache.delete();

	if (self.params.renderDelete != null) self.params.renderDelete(self.params.userPtr);

	mem::free(self);
}

fn void MicroVG.beginFrame(&self, float width, float height, float pxRatio) {
	self.nstates = 0;
	self.save();
	self.reset();

	self.setPxRatio(pxRatio);

	self.params.renderViewport(self.params.userPtr, width, height, pxRatio);

	self.drawCallCount = 0;
	self.fillTriCount = 0;
	self.strokeTriCount = 0;
	self.textTriCount = 0;
}

fn void MicroVG.cancelFrame(&self) => self.params.renderCancel(self.params.userPtr);

fn void MicroVG.endFrame(&self) => self.params.renderFlush(self.params.userPtr);

fn void MicroVG.save(&self) {
	if (self.nstates >= MAX_STATES) return;
	if (self.nstates > 0) mem::copy(&self.states[self.nstates], &self.states[self.nstates - 1], State::size);
	self.nstates++;
}

fn void MicroVG.restore(&self) {
	if (self.nstates <= 1) return;
	self.nstates--;
}

fn void MicroVG.reset(&self) {
	State* state = self.getState();
	mem::clear(state, State::size);

	state.fill.color(rgba(255, 255, 255, 255));
	state.stroke.color(rgba(0, 0, 0, 255));
	state.compositeOp = CompositeOp.SOURCE_OVER.state();
	state.shapeAA = 1;
	state.strokeWidth = 1.0f;
	state.miterLimit = 10.0f;
	state.lineCap = LineCap.BUTT;
	state.lineJoin = LineJoin.MITER;
	state.alpha = 1.0f;
	state.form.identity();

	state.scissor.extent.x = -1.0f;
	state.scissor.extent.y = -1.0f;
}

fn void MicroVG.shapeAA(&self, int enabled) {
	State* state = self.getState();
	state.shapeAA = enabled;
}

fn void MicroVG.strokeWidth(&self, float width) {
	State* state = self.getState();
	state.strokeWidth = width;
}

fn void MicroVG.miterLimit(&self, float limit) {
	State* state = self.getState();
	state.miterLimit = limit;
}

fn void MicroVG.lineCap(&self, LineCap cap) {
	State* state = self.getState();
	state.lineCap = cap;
}

fn void MicroVG.lineJoin(&self, LineJoin join) {
	State* state = self.getState();
	state.lineJoin = join;
}

fn void MicroVG.globalAlpha(&self, float alpha) {
	State* state = self.getState();
	state.alpha = alpha;
}

fn void MicroVG.resetTransform(&self) {
	State* state = self.getState();
	state.identity();
}

fn void MicroVG.translate(&self, float x, float y) => self.getState().translate(x, y);

fn void MicroVG.rotate(&self, float angle) => self.getState().rotate(angle);

fn void MicroVG.skewX(&self, float angle) => self.getState().skewX(angle);

fn void MicroVG.skewY(&self, float angle) => self.getState().skewY(angle);

fn void MicroVG.scale(&self, float x, float y) => self.getState().scale(x, y);

fn void MicroVG.currentTransform(&self, float* form) {
	State* state = self.getState();
	if (form == null) return;
	mem::copy(form, &state.form, float::size * 6);
}

fn void MicroVG.strokeColor(&self, Color color) {
	State* state = self.getState();
	state.stroke.color(color);
}

fn void MicroVG.strokePaint(&self, Paint paint) {
	State* state = self.getState();
	state.stroke = paint;
}

fn void MicroVG.fillColor(&self, Color color) {
	State* state = self.getState();
	state.fill.color(color);
}

fn void MicroVG.fillPaint(&self, Paint paint) {
	State* state = self.getState();
	state.fill = paint;
	state.fill.form = state.form * state.fill.form;
}

fn int MicroVG.createImageRgba(&self, int w, int h, int imageFlags, char* data) =>
self.params.renderCreateTexture(self.params.userPtr, TextureType.RGBA, w, h, imageFlags, data);

fn void MicroVG.updateImage(&self, int image, char* data) {
	int w, h;
	self.params.renderGetTextureSize(self.params.userPtr, image, &w, &h);
	self.params.renderUpdateTexture(self.params.userPtr, image, 0, 0, w, h, data);
}

fn void MicroVG.imageSize(&self, int image, int* w, int* h) =>
self.params.renderGetTextureSize(self.params.userPtr, image, w, h);

fn void MicroVG.deleteImage(&self, int image) =>
self.params.renderDeleteTexture(self.params.userPtr, image);

fn Paint MicroVG.linearGradient(
&self, float sx, float sy, float ex, float ey,
Color icol, Color ocol
) {
	Paint p;
	mem::clear(&p, Paint::size);
	p.gradientType = GradientType.LINEAR;

	Vec2 d = { ex - sx, ey - sy };
	float len = d.length();
	if (len < 1e-6f) {
		p.form.identity();
		p.innerColor = icol;
		p.outerColor = ocol;
		p.feather = 1.0f;
		return p;
	}
	d = d.normalize();

	p.form.linear = { d.x, d.y, -d.y, d.x };
	p.form.trans = { sx, sy };
	p.extent = { len, 0.0f };

	p.radius = 0.0f;
	p.feather = 0.0f;
	p.image = 0;

	p.innerColor = icol;
	p.outerColor = ocol;

	return p;
}

fn Paint MicroVG.radialGradient(
&self, float cx, float cy, float inr, float outr,
Color icol, Color ocol
) {
	Paint p;
	mem::clear(&p, Paint::size);
	p.gradientType = GradientType.RADIAL;

	float r = (inr + outr) * 0.5f;
	float f = outr - inr;

	p.form.identity();

	p.form.trans = { cx, cy };
	p.extent = { r, r };

	p.radius = r;
	p.feather = math::max(1.0f, f);
	p.image = 0;

	p.innerColor = icol;
	p.outerColor = ocol;

	return p;
}

fn Paint MicroVG.boxGradient(
&self, float x, float y, float w, float h, float r, float f,
Color icol, Color ocol
) {
	Paint p;
	mem::clear(&p, Paint::size);
	p.gradientType = GradientType.BOX;

	p.form.identity();
	p.form.trans = { x + w * 0.5f, y + h * 0.5f };
	p.extent = { w * 0.5f, h * 0.5f };

	p.radius = r;
	p.feather = math::max(1.0f, f);
	p.image = 0;

	p.innerColor = icol;
	p.outerColor = ocol;

	return p;
}

fn Paint MicroVG.imagePattern(
&self, float cx, float cy, float w, float h,
float angle, int image, float alpha
) {
	Paint p;
	mem::clear(&p, Paint::size);
	p.gradientType = GradientType.LINEAR;

	p.form.identity();
	p.form.rotate(angle);
	p.form.trans.x = cx;
	p.form.trans.y = cy;

	p.extent.x = w;
	p.extent.y = h;

	p.image = image;

	p.outerColor = rgbaf(1, 1, 1, alpha);
	p.innerColor = p.outerColor;

	return p;
}

fn void MicroVG.scissor(&self, float x, float y, float w, float h) {
	State* state = self.getState();

	w = math::max(0.0f, w);
	h = math::max(0.0f, h);

	state.scissor.form.identity();
	state.scissor.form.trans = { x + w * 0.5f, y + h * 0.5f };
	state.scissor.form = state.form * state.scissor.form;

	state.scissor.extent = { w * 0.5f, h * 0.5f };
}

fn void MicroVG.intersectScissor(&self, float x, float y, float w, float h) {
	State* state = self.getState();

	if (state.scissor.extent.x < 0) {
		self.scissor(x, y, w, h);
		return;
	}

	Mat2x3 pform = state.scissor.form;
	Mat2x3 invform;
	Vec2 ex = state.scissor.extent;
	invform = state.form.inverse();
	pform = invform * pform;
	float tex = ex.x * math::abs(pform.linear.x) + ex.y * math::abs(pform.linear.z);
	float tey = ex.x * math::abs(pform.linear.y) + ex.y * math::abs(pform.linear.w);

	Vec4 r = isectRect(pform.trans.x - tex, pform.trans.y - tey, tex * 2, tey * 2, x, y, w, h);
	self.scissor(r.x, r.y, r.z, r.w);
}

fn void MicroVG.resetScissor(&self) {
	State* state = self.getState();
	mem::clear(&state.scissor.form, Mat2x3::size);
	state.scissor.extent.x = -1.0f;
	state.scissor.extent.y = -1.0f;
}

fn void MicroVG.globalCompositeOp(&self, CompositeOp op) {
	State* state = self.getState();
	state.compositeOp = op.state();
}

fn void MicroVG.globalCompositeBlendFunc(&self, BlendFactor sfactor, BlendFactor dfactor) =>
self.globalCompositeBlendFuncSeparate(sfactor, dfactor, sfactor, dfactor);

fn void MicroVG.globalCompositeBlendFuncSeparate(
&self, BlendFactor srcRGB, BlendFactor dstRGB,
BlendFactor srcAlpha, BlendFactor dstAlpha
) {
	CompositeOpState op;
	op.srcRGB = srcRGB;
	op.dstRGB = dstRGB;
	op.srcAlpha = srcAlpha;
	op.dstAlpha = dstAlpha;

	State* state = self.getState();
	state.compositeOp = op;
}

fn void MicroVG.appendCommands(&self, PathCmd* cmds, int ncmds) {
	State* state = self.getState();

	if (self.ncommands + ncmds > self.ccommands) {
		int ccommands = math::max(self.ncommands + ncmds, self.ccommands + self.ccommands / 2);
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

fn void MicroVG.clearPathCache(&self) {
	for (int i = 0; i < self.cache.npaths; i++) {
		if (self.cache.paths[i].triFill != null) {
			mem::free(self.cache.paths[i].triFill);
			self.cache.paths[i].triFill = null;
			self.cache.paths[i].ntriFill = 0;
		}
	}
	self.cache.npoints = 0;
	self.cache.npaths = 0;
}

fn MvgPath* MicroVG.lastPath(&self) {
	if (self.cache.npaths > 0) return &self.cache.paths[self.cache.npaths - 1];
	return null;
}

fn void MicroVG.addPath(&self) {
	if (self.cache.npaths + 1 > self.cache.cpaths) {
		int cpaths = math::max(self.cache.npaths + 1, self.cache.cpaths + self.cache.cpaths / 2);
		MvgPath* paths = mem::realloc(self.cache.paths, MvgPath::size * cpaths);
		if (paths == null) return;
		self.cache.paths = paths;
		self.cache.cpaths = cpaths;
	}
	MvgPath* path = &self.cache.paths[self.cache.npaths];
	mem::clear(path, MvgPath::size);
	path.first = self.cache.npoints;
	path.winding = Winding.CCW;

	self.cache.npaths++;
}

fn Point* MicroVG.lastPoint(&self) {
	if (self.cache.npoints > 0) return &self.cache.points[self.cache.npoints - 1];
	return null;
}

fn void MicroVG.addPoint(&self, Vec2 pt, PathPointFlags flags) {
	MvgPath* path = self.lastPath();
	if (path == null) return;

	if (path.count > 0 && self.cache.npoints > 0) {
		Point* lastPt = self.lastPoint();
		if (ptEquals( { lastPt.pos.x, lastPt.pos.y }, pt, self.distTol)) {
			lastPt.flags = lastPt.flags | flags;
			return;
		}
	}

	if (self.cache.npoints + 1 > self.cache.cpoints) {
		int cpoints = math::max(self.cache.npoints + 1, self.cache.cpoints + self.cache.cpoints / 2);
		Point* points = mem::realloc(self.cache.points, Point::size * cpoints);
		if (points == null) return;
		self.cache.points = points;
		self.cache.cpoints = cpoints;
	}

	Point* newPt = &self.cache.points[self.cache.npoints];
	mem::clear(newPt, Point::size);
	newPt.pos.x = pt.x;
	newPt.pos.y = pt.y;
	newPt.flags = flags;

	self.cache.npoints++;
	path.count++;
}

fn void MicroVG.closePathCache(&self) {
	MvgPath* path = self.lastPath();
	if (path == null) return;
	path.closed = 1;
}

fn void MicroVG.pathWindingCache(&self, int winding) {
	MvgPath* path = self.lastPath();
	if (path == null) return;
	path.winding = (Winding)winding;
}

fn Vertex* MicroVG.allocTempVerts(&self, int nverts) {
	if (nverts > self.cache.cverts) {
		int cverts = math::max((nverts + 0xff) & ~0xff, self.cache.cverts + self.cache.cverts / 2);
		Vertex* verts = mem::realloc(self.cache.verts, Vertex::size * cverts);
		if (verts == null) return null;
		self.cache.verts = verts;
		self.cache.cverts = cverts;
	}

	return self.cache.verts;
}

fn void MicroVG.tesselateBezier(&self,
Vec2 p0, Vec2 p1, Vec2 p2, Vec2 p3,
PathPointFlags type
) {
	Vec2 chord = p3 - p0;
	float chord_len2 = chord.dot(chord);

	float max_dev = 0.0f;
	if (chord_len2 > 1e-12f) {
		float chord_len = math::sqrt(chord_len2);
		float dev1 = math::abs((p1 - p0).cross(chord)) / chord_len;
		float dev2 = math::abs((p2 - p0).cross(chord)) / chord_len;
		max_dev = math::max(dev1, dev2);
	}

	int nsteps;
	if (max_dev <= self.tessTol) {
		nsteps = 2;
	}
	else {
		nsteps = (int)math::ceil(math::sqrt(max_dev / self.tessTol));
	}
	nsteps = math::clamp(nsteps, 2, 4096);

	float h = 1.0f / (float)nsteps;
	float h2 = h * h;
	float h3 = h2 * h;

	Vec2 pa = p0;
	Vec2 pb = (p1 - p0) * 3.0f;
	Vec2 pc = (p2 - p1 * 2.0f + p0) * 3.0f;
	Vec2 pd = p3 - p2 * 3.0f + p1 * 3.0f - p0;

	Vec2 f = pa;
	Vec2 df = pb * h + pc * h2 + pd * h3;
	Vec2 d2f = pc * (2.0f * h2) + pd * (6.0f * h3);
	Vec2 d3f = pd * (6.0f * h3);

	for (int i = 1; i < nsteps; i++) {
		f = f + df;
		df = df + d2f;
		d2f = d2f + d3f;
		self.addPoint(f, PT_NONE);
	}

	self.addPoint(p3, type);
}

fn void MicroVG.flattenPaths(&self) {
	PathCache* cache = self.cache;

	if (cache.npaths > 0) return;

	for (int i = 0; i < self.ncommands; i++) {
		PathCmd* cmd = &self.commands[i];

		switch (cmd.cmd) {
			case PathCommand.MOVE:
				self.addPath();
				self.addPoint(cmd.p0, PT_CORNER);

			case PathCommand.LINE:
				self.addPoint(cmd.p0, PT_CORNER);

			case PathCommand.BEZIER:
				Point* last = self.lastPoint();
				if (last != null) self.tesselateBezier(
				{ last.pos.x, last.pos.y },
				cmd.p0, cmd.p1, cmd.p2,
				PT_CORNER
				);

			case PathCommand.CLOSE:
				self.closePathCache();

			case PathCommand.WINDING:
				self.pathWindingCache((int)cmd.p0.x);
		}
	}

	cache.bounds = { 1e6f, 1e6f, -1e6f, -1e6f };

	for (int j = 0; j < cache.npaths; j++) {
		MvgPath* path = &cache.paths[j];
		Point* pts = &cache.points[path.first];

		Point* p0 = &pts[path.count - 1];
		Point* p1 = &pts[0];
		if (path.count > 1 && ptEquals( { p0.pos.x, p0.pos.y }, { p1.pos.x, p1.pos.y }, self.distTol)) {
			path.count--;
			p0 = &pts[path.count - 1];
			path.closed = 1;
		}

		if (path.count < 2) continue;

		if (path.count > 2) {
			float area = polyArea(pts, path.count);
			if (path.winding == Winding.CCW && area < 0.0f) polyReverse(pts, path.count);
			if (path.winding == Winding.CW && area > 0.0f) polyReverse(pts, path.count);
		}

		for (int k = 0; k < path.count; k++) {
			p0.dir.x = p1.pos.x - p0.pos.x;
			p0.dir.y = p1.pos.y - p0.pos.y;
			p0.len = normalize(&p0.dir.x, &p0.dir.y);
			cache.bounds = {
				math::min(cache.bounds.x, p0.pos.x),
				math::min(cache.bounds.y, p0.pos.y),
				math::max(cache.bounds.z, p0.pos.x),
				math::max(cache.bounds.w, p0.pos.y)
			};
			p0 = p1;
			p1++;
		}
	}
}

fn void chooseBevel(
bool bevel, Point* p0, Point* p1, float w,
float* x0, float* y0, float* x1, float* y1
) {
	if (bevel) {
		x0[0] = p1.pos.x + p0.dir.y * w;
		y0[0] = p1.pos.y - p0.dir.x * w;
		x1[0] = p1.pos.x + p1.dir.y * w;
		y1[0] = p1.pos.y - p1.dir.x * w;
	}
	else {
		x0[0] = p1.pos.x + p1.miter.x * w;
		y0[0] = p1.pos.y + p1.miter.y * w;
		x1[0] = p1.pos.x + p1.miter.x * w;
		y1[0] = p1.pos.y + p1.miter.y * w;
	}
}

fn Vertex* roundJoin(
Vertex* dst, Point* p0, Point* p1,
float lw, float rw, float lu, float ru, int ncap, float fringe
) {
	Vec2 v0 = { p0.pos.x, p0.pos.y };
	Vec2 v1 = { p1.pos.x, p1.pos.y };
	Vec2 d0 = { p0.dir.y, -p0.dir.x };
	Vec2 d1 = { p1.dir.y, -p1.dir.x };

	if (p1.flags.left) {
		float lx0, ly0, lx1, ly1;
		chooseBevel(p1.flags.innerBevel, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);
		float a0 = math::atan2(-d0.y, -d0.x);
		float a1 = math::atan2(-d1.y, -d1.x);
		if (a1 > a0) a1 -= PI * 2;

		dst = dst.push_xyuv(lx0, ly0, lu, 1);
		dst = dst.push_uv(v1 - d0 * rw, ru, 1);

		int n = math::clamp((int)math::ceil(((a0 - a1) / PI) * ncap), 2, ncap);
		for (int i = 0; i < n; i++) {
			float u = i / (float) (n - 1);
			float a = a0 + u * (a1 - a0);
			Vec2 r = {
				v1.x + math::cos(a) * rw,
				v1.y + math::sin(a) * rw
			};
			dst = dst.push_uv(v1, 0.5f, 1);
			dst = dst.push_uv(r, ru, 1);
		}

		dst = dst.push_xyuv(lx1, ly1, lu, 1);
		dst = dst.push_uv(v1 - d1 * rw, ru, 1);
	}
	else {
		float rx0, ry0, rx1, ry1;
		chooseBevel(p1.flags.innerBevel, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);
		float a0 = math::atan2(d0.y, d0.x);
		float a1 = math::atan2(d1.y, d1.x);
		if (a1 < a0) a1 += PI * 2;

		dst = dst.push_uv(v1 + d0 * rw, lu, 1);
		dst = dst.push_xyuv(rx0, ry0, ru, 1);

		int n = math::clamp((int)math::ceil(((a1 - a0) / PI) * ncap), 2, ncap);
		for (int i = 0; i < n; i++) {
			float u = i / (float)(n - 1);
			float a = a0 + u * (a1 - a0);
			float lx = p1.pos.x + math::cos(a) * lw;
			float ly = p1.pos.y + math::sin(a) * lw;
			dst = dst.push_xyuv(lx, ly, lu, 1);
			dst = dst.push_uv(v1, 0.5f, 1);
		}

		dst = dst.push_uv(v1 + d1 * rw, lu, 1);
		dst = dst.push_xyuv(rx1, ry1, ru, 1);
	}

	return dst;
}

fn Vertex* bevelJoin(
Vertex* dst, Point* p0, Point* p1,
float lw, float rw, float lu, float ru, float fringe
) {
	float dlx0 = p0.dir.y;
	float dly0 = -p0.dir.x;
	float dlx1 = p1.dir.y;
	float dly1 = -p1.dir.x;

	if (p1.flags.left) {
		float lx0, ly0, lx1, ly1;
		chooseBevel(p1.flags.innerBevel, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);

		dst = dst.push_xyuv(lx0, ly0, lu, 1);
		dst = dst.push_xyuv(p1.pos.x - dlx0 * rw, p1.pos.y - dly0 * rw, ru, 1);

		if (p1.flags.bevel) {
			dst = dst.push_xyuv(lx0, ly0, lu, 1);
			dst = dst.push_xyuv(p1.pos.x - dlx0 * rw, p1.pos.y - dly0 * rw, ru, 1);

			dst = dst.push_xyuv(lx1, ly1, lu, 1);
			dst = dst.push_xyuv(p1.pos.x - dlx1 * rw, p1.pos.y - dly1 * rw, ru, 1);
		}
		else {
			float rx0 = p1.pos.x - p1.miter.x * rw;
			float ry0 = p1.pos.y - p1.miter.y * rw;

			dst = dst.push_xyuv(p1.pos.x, p1.pos.y, 0.5f, 1);
			dst = dst.push_xyuv(p1.pos.x - dlx0 * rw, p1.pos.y - dly0 * rw, ru, 1);

			dst = dst.push_xyuv(rx0, ry0, ru, 1);
			dst = dst.push_xyuv(rx0, ry0, ru, 1);

			dst = dst.push_xyuv(p1.pos.x, p1.pos.y, 0.5f, 1);
			dst = dst.push_xyuv(p1.pos.x - dlx1 * rw, p1.pos.y - dly1 * rw, ru, 1);
		}

		dst = dst.push_xyuv(lx1, ly1, lu, 1);
		dst = dst.push_xyuv(p1.pos.x - dlx1 * rw, p1.pos.y - dly1 * rw, ru, 1);
	}
	else {
		float rx0, ry0, rx1, ry1;
		chooseBevel(p1.flags.innerBevel, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);

		dst = dst.push_xyuv(p1.pos.x + dlx0 * lw, p1.pos.y + dly0 * lw, lu, 1);
		dst = dst.push_xyuv(rx0, ry0, ru, 1);

		if (p1.flags.bevel) {
			dst = dst.push_xyuv(p1.pos.x + dlx0 * lw, p1.pos.y + dly0 * lw, lu, 1);
			dst = dst.push_xyuv(rx0, ry0, ru, 1);

			dst = dst.push_xyuv(p1.pos.x + dlx1 * lw, p1.pos.y + dly1 * lw, lu, 1);
			dst = dst.push_xyuv(rx1, ry1, ru, 1);
		}
		else {
			float lx0 = p1.pos.x + p1.miter.x * lw;
			float ly0 = p1.pos.y + p1.miter.y * lw;

			dst = dst.push_xyuv(p1.pos.x + dlx0 * lw, p1.pos.y + dly0 * lw, lu, 1);
			dst = dst.push_xyuv(p1.pos.x, p1.pos.y, 0.5f, 1);

			dst = dst.push_xyuv(lx0, ly0, lu, 1);
			dst = dst.push_xyuv(lx0, ly0, lu, 1);

			dst = dst.push_xyuv(p1.pos.x + dlx1 * lw, p1.pos.y + dly1 * lw, lu, 1);
			dst = dst.push_xyuv(p1.pos.x, p1.pos.y, 0.5f, 1);
		}

		dst = dst.push_xyuv(p1.pos.x + dlx1 * lw, p1.pos.y + dly1 * lw, lu, 1);
		dst = dst.push_xyuv(rx1, ry1, ru, 1);
	}

	return dst;
}

fn Vertex* buttCapStart(
Vertex* dst, Vec2 pos, Vec2 dir,
float w, float d, float aa, Vec2 uv
) {
	Vec2 cap = pos - dir * d;
	Vec2 normal = { dir.y, -dir.x };

	dst = dst.push_uv(cap + normal * w - dir * aa, uv.x, 0);
	dst = dst.push_uv(cap - normal * w - dir * aa, uv.y, 0);
	dst = dst.push_uv(cap + normal * w, uv.x, 1);
	dst = dst.push_uv(cap - normal * w, uv.y, 1);

	return dst;
}

fn Vertex* buttCapEnd(
Vertex* dst, Vec2 pos, Vec2 dir,
float w, float d, float aa, Vec2 uv
) {
	Vec2 cap = pos + dir * d;
	Vec2 normal = { dir.y, -dir.x };

	dst = dst.push_uv(cap + normal * w, uv.x, 1);
	dst = dst.push_uv(cap - normal * w, uv.y, 1);
	dst = dst.push_uv(cap + normal * w + dir * aa, uv.x, 0);
	dst = dst.push_uv(cap - normal * w + dir * aa, uv.y, 0);

	return dst;
}

fn Vertex* roundCapStart(
Vertex* dst, Vec2 pos, Vec2 dir,
float w, int ncap, float aa, Vec2 uv
) {
	Vec2 normal = { dir.y, -dir.x };

	for (int i = 0; i < ncap; i++) {
		float a = i / (float)(ncap - 1) * PI;
		Vec2 arc = { math::cos(a) * w, math::sin(a) * w };

		dst = dst.push_uv(pos - normal * arc.x - dir * arc.y, uv.x, 1);
		dst = dst.push_uv(pos, 0.5f, 1);
	}

	dst = dst.push_uv(pos + normal * w, uv.x, 1);
	dst = dst.push_uv(pos - normal * w, uv.y, 1);

	return dst;
}

fn Vertex* roundCapEnd(
Vertex* dst, Vec2 pos, Vec2 dir,
float w, int ncap, float aa, Vec2 uv
) {
	Vec2 normal = { dir.y, -dir.x };

	dst = dst.push_uv(pos + normal * w, uv.x, 1);
	dst = dst.push_uv(pos - normal * w, uv.y, 1);

	for (int i = 0; i < ncap; i++) {
		float a = i / (float)(ncap - 1) * PI;
		Vec2 arc = { math::cos(a) * w, math::sin(a) * w };
		dst = dst.push_uv(pos, 0.5f, 1);
		dst = dst.push_uv(pos - normal * arc.x + dir * arc.y, uv.x, 1);
	}

	return dst;
}

fn void MicroVG.calculateJoins(&self, float w, LineJoin lineJoin, float miterLimit) {
	PathCache* cache = self.cache;
	float iw = 0.0f;

	if (w > 0.0f) iw = 1.0f / w;

	for (int i = 0; i < cache.npaths; i++) {
		MvgPath* path = &cache.paths[i];
		if (path.count < 2) {
			path.nbevel = 0;
			path.convex = false;
			continue;
		}
		Point* pts = &cache.points[path.first];
		Point* p0 = &pts[path.count - 1];
		Point* p1 = &pts[0];
		int nleft = 0;

		path.nbevel = 0;

		for (int j = 0; j < path.count; j++) {
			float dlx0 = p0.dir.y;
			float dly0 = -p0.dir.x;
			float dlx1 = p1.dir.y;
			float dly1 = -p1.dir.x;
			p1.miter.x = (dlx0 + dlx1) * 0.5f;
			p1.miter.y = (dly0 + dly1) * 0.5f;

			float dmr2 = p1.miter.x * p1.miter.x + p1.miter.y * p1.miter.y;
			if (dmr2 > 0.000001f) {
				float scale = 1.0f / dmr2;
				if (scale > 600.0f) {
					scale = 600.0f;
				}
				p1.miter.x *= scale;
				p1.miter.y *= scale;
			}

			p1.flags = { .corner = p1.flags.corner };

			float cross = p1.dir.x * p0.dir.y - p0.dir.x * p1.dir.y;
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

		path.convex = nleft == path.count;
	}
}

fn int MicroVG.expandStroke(&self, float w, float fringe, LineCap lineCap, LineJoin lineJoin, float miterLimit) {
	PathCache* cache = self.cache;
	float aa = fringe;
	float u0 = 0.0f;
	float u1 = 1.0f;
	int ncap = curveDivs(w, PI, self.tessTol);

	w += aa * 0.5f;

	if (aa == 0.0f) {
		u0 = 0.5f;
		u1 = 0.5f;
	}

	self.calculateJoins(w, lineJoin, miterLimit);

	int cverts = 0;
	for (int i = 0; i < cache.npaths; i++) {
		MvgPath* path = &cache.paths[i];
		if (path.count < 2) continue;
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

	Vertex* verts = cache.verts;
	if (cverts > 0) {
		verts = self.allocTempVerts(cverts);
		if (verts == null) return 0;
	}

	for (int i = 0; i < cache.npaths; i++) {
		MvgPath* path = &cache.paths[i];
		Point* pts = &cache.points[path.first];
		Point* p0;
		Point* p1;
		int s, e, loop;
		float dx, dy;

		path.fill = null;
		path.nfill = 0;
		if (path.count < 2) {
			path.stroke = null;
			path.nstroke = 0;
			continue;
		}

		loop = (path.closed == 0) ? 0 : 1;
		Vertex* dst = verts;
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
			dx = p1.pos.x - p0.pos.x;
			dy = p1.pos.y - p0.pos.y;
			normalize(&dx, &dy);

			switch (lineCap) {
				case LineCap.BUTT:
					dst = buttCapStart(dst, { p0.pos.x, p0.pos.y }, { dx, dy }, w, -aa * 0.5f, aa, { u0, u1 });

				case LineCap.SQUARE:
					dst = buttCapStart(dst, { p0.pos.x, p0.pos.y }, { dx, dy }, w, w - aa, aa, { u0, u1 });

				case LineCap.ROUND:
					dst = roundCapStart(dst, { p0.pos.x, p0.pos.y }, { dx, dy }, w, ncap, aa, { u0, u1 });
			}
		}

		for (int j = s; j < e; j++) {
			if ((p1.flags.bevel || p1.flags.innerBevel)) {
				if (lineJoin == LineJoin.ROUND) {
					dst = roundJoin(dst, p0, p1, w, w, u0, u1, ncap, aa);
				}
				else {
					dst = bevelJoin(dst, p0, p1, w, w, u0, u1, aa);
				}
			}
			else {
				dst = dst.push_xyuv(p1.pos.x + (p1.miter.x * w), p1.pos.y + (p1.miter.y * w), u0, 1);
				dst = dst.push_xyuv(p1.pos.x - (p1.miter.x * w), p1.pos.y - (p1.miter.y * w), u1, 1);
			}
			p0 = p1;
			p1++;
		}

		if (loop) {
			dst = dst.push_xyuv(verts[0].pos.x, verts[0].pos.y, u0, 1);
			dst = dst.push_xyuv(verts[1].pos.x, verts[1].pos.y, u1, 1);
		}
		else {
			dx = p1.pos.x - p0.pos.x;
			dy = p1.pos.y - p0.pos.y;
			normalize(&dx, &dy);

			switch (lineCap) {
				case LineCap.BUTT:
					dst = buttCapEnd(dst, { p1.pos.x, p1.pos.y }, { dx, dy }, w, -aa * 0.5f, aa, { u0, u1 });

				case LineCap.SQUARE:
					dst = buttCapEnd(dst, { p1.pos.x, p1.pos.y }, { dx, dy }, w, w - aa, aa, { u0, u1 });

				case LineCap.ROUND:
					dst = roundCapEnd(dst, { p1.pos.x, p1.pos.y }, { dx, dy }, w, ncap, aa, { u0, u1 });
			}
		}

		path.nstroke = (int)(dst - verts);

		verts = dst;
	}

	return 1;
}

fn bool earPointInTriangle(Vec2 pt, Vec2 a, Vec2 b, Vec2 c) @local {
	float d1 = (b.x - a.x) * (pt.y - a.y) - (b.y - a.y) * (pt.x - a.x);
	float d2 = (c.x - b.x) * (pt.y - b.y) - (c.y - b.y) * (pt.x - b.x);
	float d3 = (a.x - c.x) * (pt.y - c.y) - (a.y - c.y) * (pt.x - c.x);

	bool has_neg = (d1 <= -1e-6f) || (d2 <= -1e-6f) || (d3 <= -1e-6f);
	bool has_pos = (d1 >= 1e-6f) || (d2 >= 1e-6f) || (d3 >= 1e-6f);
	return !(has_neg && has_pos);
}

fn int earClipTriangulate(Vertex* verts, int nverts, int* out_indices) @local {
	if (nverts < 3) return 0;
	if (nverts == 3) {
		out_indices[0] = 0; out_indices[1] = 1; out_indices[2] = 2;
		return 3;
	}

	int* indices = mem::malloc((sz)nverts * int::size);
	for (int i = 0; i < nverts; i++) indices[i] = i;

	int n = nverts;
	int tri_count = 0;
	int max_iter = nverts * nverts * 2;

	while (n > 2 && tri_count < nverts - 2) {
		bool found = false;
		for (int i = 0; i < n; i++) {
			int p = indices[(i + n - 1) % n];
			int c = indices[i];
			int nx = indices[(i + 1) % n];

			Vec2 prev = verts[p].pos;
			Vec2 curr = verts[c].pos;
			Vec2 next = verts[nx].pos;

			float cross = (curr.x - prev.x) * (next.y - curr.y) - (curr.y - prev.y) * (next.x - curr.x);
			if (cross >= 0) continue;

			bool is_ear = true;
			for (int j = 0; j < n; j++) {
				if (indices[j] == p || indices[j] == c || indices[j] == nx) continue;
				Vec2 pt = verts[indices[j]].pos;
				if (earPointInTriangle(pt, prev, curr, next)) {
					is_ear = false;
					break;
				}
			}

			if (is_ear) {
				out_indices[tri_count * 3] = p;
				out_indices[tri_count * 3 + 1] = c;
				out_indices[tri_count * 3 + 2] = nx;
				tri_count++;

				for (int j = i; j < n - 1; j++) indices[j] = indices[j + 1];
				n--;
				found = true;
				break;
			}

			max_iter--;
			if (max_iter <= 0) break;
		}

		if (!found || max_iter <= 0) break;
	}

	mem::free(indices);
	return tri_count * 3;
}

fn bool earClipFill(MvgPath* path, Vertex* fanVerts, int nfan) @local {
	if (nfan < 3) return false;
	if (nfan == 3) {
		path.triFill = mem::malloc(3 * Vertex::size);
		if (path.triFill == null) return false;
		path.triFill[0] = fanVerts[0];
		path.triFill[1] = fanVerts[1];
		path.triFill[2] = fanVerts[2];
		path.ntriFill = 3;
		return true;
	}

	int max_indices = (nfan - 2) * 3;
	int* tri_indices = mem::malloc((sz)max_indices * int::size);
	if (tri_indices == null) return false;

	int ntri = earClipTriangulate(fanVerts, nfan, tri_indices);
	if (ntri == 0) {
		mem::free(tri_indices);
		return false;
	}

	Vertex* triVerts = mem::malloc((sz)ntri * Vertex::size);
	if (triVerts == null) {
		mem::free(tri_indices);
		return false;
	}

	for (int i = 0; i < ntri; i++) {
		triVerts[i] = fanVerts[tri_indices[i]];
	}

	mem::free(tri_indices);

	path.triFill = triVerts;
	path.ntriFill = ntri;
	return true;
}

fn int MicroVG.expandFill(&self, float w, LineJoin lineJoin, float miterLimit) {
	PathCache* cache = self.cache;
	float aa = self.fringeWidth;
	bool fringe = w > 0.0f;

	self.calculateJoins(w, lineJoin, miterLimit);

	int cverts = 0;
	for (int i = 0; i < cache.npaths; i++) {
		MvgPath* path = &cache.paths[i];
		cverts += path.count + path.nbevel + 1;
		if (fringe) cverts += (path.count + path.nbevel * 5 + 1) * 2;
	}

	Vertex* verts = self.allocTempVerts(cverts);
	if (verts == null) return 0;

	bool convex = cache.npaths == 1 && cache.paths[0].convex;

	for (int i = 0; i < cache.npaths; i++) {
		MvgPath* path = &cache.paths[i];
		Point* pts = &cache.points[path.first];
		Point* p0;
		Point* p1;
		float rw, lw, woff;
		float ru, lu;

		woff = 0.5f * aa;
		Vertex* dst = verts;
		path.fill = dst;

		if (fringe) {
			p0 = &pts[path.count - 1];
			p1 = &pts[0];
			for (int j = 0; j < path.count; j++) {
				if (p1.flags.bevel) {
					float dlx0 = p0.dir.y;
					float dly0 = -p0.dir.x;
					float dlx1 = p1.dir.y;
					float dly1 = -p1.dir.x;
					if (p1.flags.left) {
						float lx = p1.pos.x + p1.miter.x * woff;
						float ly = p1.pos.y + p1.miter.y * woff;
						dst = dst.push_xyuv(lx, ly, 0.5f, 1);
					}
					else {
						float lx0 = p1.pos.x + dlx0 * woff;
						float ly0 = p1.pos.y + dly0 * woff;
						float lx1 = p1.pos.x + dlx1 * woff;
						float ly1 = p1.pos.y + dly1 * woff;
						dst = dst.push_xyuv(lx0, ly0, 0.5f, 1);
						dst = dst.push_xyuv(lx1, ly1, 0.5f, 1);
					}
				}
				else {
					dst = dst.push_xyuv(p1.pos.x + (p1.miter.x * woff), p1.pos.y + (p1.miter.y * woff), 0.5f, 1);
				}
				p0 = p1;
				p1++;
			}
		}
		else {
			for (int j = 0; j < path.count; j++) {
				dst = dst.push_xyuv(pts[j].pos.x, pts[j].pos.y, 0.5f, 1);
			}
		}

		path.nfill = (int)(dst - verts);
		verts = dst;

		if (!path.convex && path.nfill > 3) {
			earClipFill(path, path.fill, path.nfill);
		}

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
					dst = bevelJoin(dst, p0, p1, lw, rw, lu, ru, self.fringeWidth);
				}
				else {
					dst = dst.push_xyuv(p1.pos.x + (p1.miter.x * lw), p1.pos.y + (p1.miter.y * lw), lu, 1);
					dst = dst.push_xyuv(p1.pos.x - (p1.miter.x * rw), p1.pos.y - (p1.miter.y * rw), ru, 1);
				}
				p0 = p1;
				p1++;
			}

			dst = dst.push_xyuv(verts[0].pos.x, verts[0].pos.y, lu, 1);
			dst = dst.push_xyuv(verts[1].pos.x, verts[1].pos.y, ru, 1);

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

fn void MicroVG.beginPath(&self) {
	self.ncommands = 0;
	self.clearPathCache();
}

fn void MicroVG.moveTo(&self, float x, float y) {
	PathCmd cmd = { .cmd = PathCommand.MOVE, .p0 = { x, y } };
	self.appendCommands(&cmd, 1);
}

fn void MicroVG.lineTo(&self, float x, float y) {
	PathCmd cmd = { .cmd = PathCommand.LINE, .p0 = { x, y } };
	self.appendCommands(&cmd, 1);
}

fn void MicroVG.bezierTo(&self, float c1x, float c1y, float c2x, float c2y, float x, float y) {
	PathCmd cmd = { .cmd = PathCommand.BEZIER, .p0 = { c1x, c1y }, .p1 = { c2x, c2y }, .p2 = { x, y } };
	self.appendCommands(&cmd, 1);
}

fn void MicroVG.quadTo(&self, float cx, float cy, float x, float y) {
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

fn void MicroVG.arcTo(&self, float x1, float y1, float x2, float y2, float radius) {
	float x0 = self.commandx;
	float y0 = self.commandy;

	if (self.ncommands == 0) return;

	if (
	ptEquals( { x0, y0 }, { x1, y1 }, self.distTol) ||
	ptEquals( { x1, y1 }, { x2, y2 }, self.distTol) ||
	distPtSeg( { x1, y1 }, { x0, y0 }, { x2, y2 }) < self.distTol * self.distTol ||
	radius < self.distTol
	) {
		self.lineTo(x1, y1);
		return;
	}

	float dx0 = x0 - x1;
	float dy0 = y0 - y1;
	float dx1 = x2 - x1;
	float dy1 = y2 - y1;
	normalize(&dx0, &dy0);
	normalize(&dx1, &dy1);
	float a = math::acos(dx0 * dx1 + dy0 * dy1);
	float d = radius / math::tan(a / 2.0f);

	if (d > 10000.0f) {
		self.lineTo(x1, y1);
		return;
	}

	float cx, cy, a0, a1;
	Winding dir;

	Vec2 v0 = { dx0, dy0 };
	Vec2 v1 = { dx1, dy1 };
	if (v1.cross(v0) > 0.0f) {
		cx = x1 + dx0 * d + dy0 * radius;
		cy = y1 + dy0 * d + -dx0 * radius;
		a0 = math::atan2(dx0, -dy0);
		a1 = math::atan2(-dx1, dy1);
		dir = Winding.CW;
	}
	else {
		cx = x1 + dx0 * d + -dy0 * radius;
		cy = y1 + dy0 * d + dx0 * radius;
		a0 = math::atan2(-dx0, dy0);
		a1 = math::atan2(dx1, -dy1);
		dir = Winding.CCW;
	}

	self.arc(cx, cy, radius, a0, a1, dir);
}

fn void MicroVG.closePath(&self) {
	PathCmd cmd = { .cmd = PathCommand.CLOSE };
	self.appendCommands(&cmd, 1);
}

fn void MicroVG.pathWinding(&self, Winding dir) {
	PathCmd cmd = { .cmd = PathCommand.WINDING, .p0 = { dir.ordinal, 0.0f } };
	self.appendCommands(&cmd, 1);
}

fn void MicroVG.arc(&self, float cx, float cy, float r, float a0, float a1, Winding dir) {
	float a, da, hda, kappa;
	float dx, dy, x, y;
	float tanx, tany, px, py;
	float ptanx, ptany;
	PathCmd[108] cmds;
	int ndivs, ncmds;
	PathCommand firstCmd = self.ncommands > 0 ? PathCommand.LINE : PathCommand.MOVE;

	da = a1 - a0;
	if (dir == Winding.CW) {
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

	if (dir == Winding.CCW) kappa = -kappa;

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

fn void MicroVG.rect(&self, float x, float y, float w, float h) {
	PathCmd[*] cmds = {
		{ .cmd = PathCommand.MOVE, .p0 = { x, y } },
		{ .cmd = PathCommand.LINE, .p0 = { x, y + h } },
		{ .cmd = PathCommand.LINE, .p0 = { x + w, y + h } },
		{ .cmd = PathCommand.LINE, .p0 = { x + w, y } },
		{ .cmd = PathCommand.CLOSE }
	};

	self.appendCommands(&cmds[0], cmds.len);
}

fn void MicroVG.roundedRect(&self, float x, float y, float w, float h, float r) =>
self.roundedRectVarying(x, y, w, h, r, r, r, r);

fn void MicroVG.roundedRectVarying(
&self, float x, float y, float w, float h,
float topLeft, float topRight,
float bottomRight, float bottomLeft
) {
	if (topLeft < 0.1f && topRight < 0.1f && bottomRight < 0.1f && bottomLeft < 0.1f) {
		self.rect(x, y, w, h);
		return;
	}

	float halfw = math::abs(w) * 0.5f;
	float halfh = math::abs(h) * 0.5f;
	float rxBL = math::min(bottomLeft, halfw) * w.sign();
	float ryBL = math::min(bottomLeft, halfh) * h.sign();
	float rxBR = math::min(bottomRight, halfw) * w.sign();
	float ryBR = math::min(bottomRight, halfh) * h.sign();
	float rxTR = math::min(topRight, halfw) * w.sign();
	float ryTR = math::min(topRight, halfh) * h.sign();
	float rxTL = math::min(topLeft, halfw) * w.sign();
	float ryTL = math::min(topLeft, halfh) * h.sign();

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

fn void MicroVG.ellipse(&self, float cx, float cy, float rx, float ry) {
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

fn void MicroVG.circle(&self, float cx, float cy, float r) => self.ellipse(cx, cy, r, r);

fn void MicroVG.fill(&self) {
	State* state = self.getState();
	Paint fillPaint = state.fill;

	self.flattenPaths();
	if (self.params.edgeAA && state.shapeAA) {
		self.expandFill(self.fringeWidth, LineJoin.MITER, 2.4f);
	}
	else {
		self.expandFill(0.0f, LineJoin.MITER, 2.4f);
	}

	fillPaint.innerColor.a *= state.alpha;
	fillPaint.outerColor.a *= state.alpha;

	self.params.renderFill(self.params.userPtr, &fillPaint, state.compositeOp, &state.scissor,
	self.fringeWidth, &self.cache.bounds[0], self.cache.paths, self.cache.npaths);

	for (int i = 0; i < self.cache.npaths; i++) {
		MvgPath* path = &self.cache.paths[i];
		if (path.triFill != null) {
			self.fillTriCount += path.ntriFill / 3;
		}
		else {
			self.fillTriCount += path.nfill - 2;
		}
		self.fillTriCount += path.nstroke - 2;
		self.drawCallCount += 2;
	}
}

fn void MicroVG.stroke(&self) {
	State* state = self.getState();
	float scale = state.form.averageScale();
	float strokeWidth = math::clamp(state.strokeWidth * scale, 0.0f, 200.0f);
	Paint strokePaint = state.stroke;

	if (strokeWidth < self.fringeWidth) {
		float alpha = math::clamp(strokeWidth / self.fringeWidth, 0.0f, 1.0f);
		strokePaint.innerColor.a *= alpha * alpha;
		strokePaint.outerColor.a *= alpha * alpha;
		strokeWidth = self.fringeWidth;
	}

	strokePaint.innerColor.a *= state.alpha;
	strokePaint.outerColor.a *= state.alpha;

	self.flattenPaths();

	if (self.params.edgeAA && state.shapeAA) {
		self.expandStroke(strokeWidth * 0.5f, self.fringeWidth, state.lineCap, state.lineJoin, state.miterLimit);
	}
	else {
		self.expandStroke(strokeWidth * 0.5f, 0.0f, state.lineCap, state.lineJoin, state.miterLimit);
	}

	self.params.renderStroke(self.params.userPtr, &strokePaint, state.compositeOp, &state.scissor,
	self.fringeWidth, strokeWidth, self.cache.paths, self.cache.npaths);

	for (int i = 0; i < self.cache.npaths; i++) {
		MvgPath* path = &self.cache.paths[i];
		self.strokeTriCount += path.nstroke - 2;
		self.drawCallCount++;
	}
}
