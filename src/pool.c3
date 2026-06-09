module microvg;

import std::math;

const sz POOL_INIT_CAP @private = 16;
const float STROKE_WIDTH @private = 1;

struct PathPool {
	Path* paths;
	sz used;
	sz cap;
}

fn void PathPool.begin(&self) {
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
    for (sz i = 0; i < self.cap; i++) self.paths[i].free();
    mem::free(self.paths);
    *self = {};
}

fn void pushStrokeSegment(VertexBuffer* vertices, Vec2 a, Vec2 b) @private {
	float dx = b.x - a.x;
	float dy = b.y - a.y;
	float len = math::sqrt(dx * dx + dy * dy);
	if (len <= 0.0001) return;

	float half = STROKE_WIDTH * 0.5;
	float nx = -dy / len * half;
	float ny = dx / len * half;

	Vec2 a0 = { a.x + nx, a.y + ny };
	Vec2 a1 = { a.x - nx, a.y - ny };
	Vec2 b0 = { b.x + nx, b.y + ny };
	Vec2 b1 = { b.x - nx, b.y - ny };

	vertices.push(a0);
	vertices.push(a1);
	vertices.push(b1);

	vertices.push(a0);
	vertices.push(b1);
	vertices.push(b0);
}

fn void pushStrokeJoin(VertexBuffer* vertices, Vec2 p) @private {
	float half = STROKE_WIDTH * 0.5;

	Vec2 p0 = { p.x - half, p.y - half };
	Vec2 p1 = { p.x + half, p.y - half };
	Vec2 p2 = { p.x + half, p.y + half };
	Vec2 p3 = { p.x - half, p.y + half };

	vertices.push(p0);
	vertices.push(p1);
	vertices.push(p2);

	vertices.push(p0);
	vertices.push(p2);
	vertices.push(p3);
}

fn void PathPool.pushDraw(&self, VertexBuffer* vertices) {
	for (sz i = 0; i < self.used; i++) {
		Path* path = &self.paths[i];
		Vec2 start;
		Vec2 pen;

		for (sz c = 0; c < path.count; c++) {
			Cmd cmd = path.cmds[c];

				switch (cmd.type) {
				case CmdType.CLOSE:
					if (pen != start) {
						Vec2 a = path.state.transform(pen);
						Vec2 b = path.state.transform(start);
						pushStrokeSegment(
							vertices,
							a,
							b
						);
						pushStrokeJoin(vertices, a);
						pushStrokeJoin(vertices, b);
					}
					pen = start;

				case CmdType.MOVE_TO:
                    pen = cmd.p0;
                    start = pen;

                case CmdType.LINE_TO:
					Vec2 a = path.state.transform(pen);
					Vec2 b = path.state.transform(cmd.p0);
					pushStrokeSegment(
						vertices,
						a,
						b
					);
					pushStrokeJoin(vertices, a);
					pushStrokeJoin(vertices, b);
					pen = cmd.p0;

			}
		}
	}
}
