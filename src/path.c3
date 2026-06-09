module microvg;

const sz CMD_INIT_CAP @private = 64;

enum CmdType : char {
	MOVE_TO,
	LINE_TO,
	CLOSE
}

struct Cmd {
	CmdType type;
	Vec2 p0;
	Vec2 p1;
	Vec2 p2;
}

struct Path {
	State state;
	Cmd* cmds;
	sz count;
	sz cap;
}

fn void Path.reset(&self) @inline {
	self.count = 0;
}

fn void Path.push(&self, Cmd cmd) {
	if (self.count >= self.cap) {
		sz newCap = self.cap == 0 ? CMD_INIT_CAP : self.cap * 2;
		self.cmds = mem::realloc(self.cmds, Cmd::size * newCap);
		self.cap = newCap;
	}

	self.cmds[self.count++] = cmd;
}

fn void Path.free(&self) {
	mem::free(self.cmds);
	*self = {};
}

fn void Path.close(&self) => self.push(
	{ .type = CmdType.CLOSE }
);

fn void Path.moveTo(&self, float x, float y) => self.push(
	{ .type = CmdType.MOVE_TO, .p0 = { x, y } }
);

fn void Path.lineTo(&self, float x, float y) => self.push(
	{ .type = CmdType.LINE_TO, .p0 = { x, y } }
);
