module microvg;

const sz CMD_INIT_CAP @private = 64;

enum CmdType : char {
	MOVE_TO,
	LINE_TO,

	CLOSE
}

struct Cmd {
	CmdType type;
	float[6] points;
}

struct Path {
	Cmd* cmds;
	sz count;
	sz cap;
}

fn void Path.reset(&self) @inline {
	self.count = 0;
}

fn void Path.push(&self, CmdType type, float[6] points = { }) {
	if (self.count >= self.cap) {
		sz newCap = self.cap == 0 ? CMD_INIT_CAP : self.cap * 2;
		self.cmds = mem::realloc(self.cmds, Cmd::size * newCap);
		self.cap = newCap;
	}

	self.cmds[self.count++] = { type, points };
}

fn void Path.free(&self) {
	mem::free(self.cmds);
	*self = {};
}

fn void Path.close(&self) => self.push(
	CmdType.CLOSE
);

fn void Path.moveTo(&self, float x, float y) => self.push(
	CmdType.MOVE_TO, { x, y, 0, 0, 0, 0 }
);

fn void Path.lineTo(&self, float x, float y) => self.push(
	CmdType.LINE_TO, { x, y, 0, 0, 0, 0 }
);
