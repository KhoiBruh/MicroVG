module microvg;

const sz POOL_INIT_CAP @private = 16;

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

fn void PathPool.pushDraw(&self, VertexBuffer* vertices) {
	for (sz i = 0; i < self.used; i++) {
		Path* path = &self.paths[i];
		Vec2f start;
		Vec2f pen;

		for (sz c = 0; c < path.count; c++) {
			Cmd cmd = path.cmds[c];

			switch (cmd.type) {
				case CmdType.CLOSE:
					if (pen != start) {
						vertices.push(pen);
						vertices.push(start);
					}
					pen = start;

				case CmdType.MOVE_TO:
                    pen = cmd.p0;
                    start = pen;

                case CmdType.LINE_TO:
                    vertices.push(pen);
                    vertices.push(cmd.p0);
                    pen = cmd.p0;

			}
		}
	}
}
