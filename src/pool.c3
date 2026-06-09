module microvg;

import std::math;

const sz POOL_INIT_CAP @private = 16;

struct PathPool {
	Path* paths;
	sz used;
	sz cap;
}

fn void PathPool.reset(&self) {
	for (sz i = 0; i < self.used; i++) self.paths[i].reset();
	self.used = 0;
}

fn Path* PathPool.acquire(&self) {
	if (self.used >= self.cap) {
		sz newCap = self.cap == 0 ? POOL_INIT_CAP : self.cap * 2;
		Path* path = mem::realloc(self.paths, Path::size * newCap);
		mem::set(path + self.cap, 0, Path::size * (newCap - self.cap));
		self.paths = path;
		self.cap = newCap;
	}

	return &self.paths[self.used++];
}

fn void PathPool.destroy(&self) {
    if (!self.paths) return;
    for (sz i = 0; i < self.cap; i++) self.paths[i].destroy();
    mem::free(self.paths);
    *self = {};
}

fn void VertexBuffer.pushSegment(&self, Vec2 a, Vec2 b, float width) {
	float dx = b.x - a.x;
	float dy = b.y - a.y;
	float len = math::sqrt(dx * dx + dy * dy);
	if (len <= 0.0001) return;

	float half = width * 0.5;
	float nx = -dy / len * half;
	float ny =  dx / len * half;

	Vec2 a0 = { a.x + nx, a.y + ny };
	Vec2 a1 = { a.x - nx, a.y - ny };
	Vec2 b0 = { b.x + nx, b.y + ny };
	Vec2 b1 = { b.x - nx, b.y - ny };

	self.push(a0); self.push(a1); self.push(b1);
	self.push(a0); self.push(b1); self.push(b0);
}

fn void VertexBuffer.pushJoin(&self, Vec2 p, float width) {
	float half = width * 0.5;

	Vec2 p0 = { p.x - half, p.y - half };
	Vec2 p1 = { p.x + half, p.y - half };
	Vec2 p2 = { p.x + half, p.y + half };
	Vec2 p3 = { p.x - half, p.y + half };

	self.push(p0); self.push(p1); self.push(p2);
	self.push(p0); self.push(p2); self.push(p3);
}

fn void VertexBuffer.pushPolyline(&self, Vec2* pts, sz count, float width, bool closed) {
	if (count < 2) return;

	sz edgeCount = closed ? count : count - 1;
	for (sz i = 0; i < edgeCount; i++) {
		self.pushSegment(pts[i], pts[(i + 1) % count], width);
		self.pushJoin(pts[i], width);
	}

	if (!closed) self.pushJoin(pts[count - 1], width);
}

fn void Path.pushPath(&self, Paint paint) {
	if (!paint.hasLine || paint.lineWidth <= 0) return;

	VertexBuffer* vertices = &self.vg.vertices;

	Vec2* pts = mem::calloc(Vec2::size * self.count);
	defer mem::free(pts);
	sz count = 0;

	for (sz c = 0; c < self.count; c++) {
		Cmd cmd = self.cmds[c];

		switch (cmd.type) {
			case CmdType.MOVE_TO:
				vertices.pushPolyline(pts, count, paint.lineWidth, false);
				count = 0;
				pts[count++] = self.vg.transform(cmd.p0);

			case CmdType.LINE_TO:
				pts[count++] = self.vg.transform(cmd.p0);

			case CmdType.CLOSE:
				vertices.pushPolyline(pts, count, paint.lineWidth, true);
				count = 0;
		}
	}

	vertices.pushPolyline(pts, count, paint.lineWidth, false);
}
