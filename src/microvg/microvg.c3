module microvg;

import microvg::path;
import microvg::color;
import microvg::state;
import microvg::types;
import microvg::buffer;
import microvg::backend;
import microvg::constant;


faultdef OUT_OF_MEMORY;
faultdef BACKEND_NOT_READY;
faultdef UNSUPPORTED_BACKEND;

struct MicroVG {
	Backend backend;

	int viewW;
	int viewH;
	float pixelRatio;
	AntiAlias aa;

	Buffer{ Vertex } vertices;
	Buffer{ DrawCall } calls;
	Buffer{ Cmd } cmds;
	int tessFails;

	State[constant::MAX_STATES] states;
	int state;

	Allocator alloc;
}

fn MicroVG*? create(GLType type = GLType.GL3, Allocator alloc = mem) {
	MicroVG* vg = alloc::calloc(alloc, MicroVG::size);

	vg.alloc = alloc;
	vg.backend.type = type;

	vg.vertices.init(alloc, constant::VERTEX_CAP);
	vg.calls.init(alloc, constant::CALL_CAP);
	vg.cmds.init(alloc, constant::CMD_CAP);

	if (catch err = vg.backend.init(type)) {
		vg.calls.free();
		vg.cmds.free();
		vg.vertices.free();
		alloc::free(alloc, vg);

		return BACKEND_NOT_READY~;
	}

	vg.reset();

	return vg;
}

fn void MicroVG.destroy(&self) {
	if (!self) return;

	Allocator alloc = self.alloc;
	self.backend.destroy();
	self.calls.free();
	self.cmds.free();
	self.vertices.free();
	alloc::free(alloc, self);
}

fn void MicroVG.beginFrame(&self, int w, int h, float ratio) {
	self.viewW = w;
	self.viewH = h;
	self.pixelRatio = ratio;

	self.aa = types::makeAA(ratio);

	self.vertices.clear();
	self.calls.clear();
	self.cmds.clear();
	self.tessFails = 0;

	self.reset();
	self.backend.view(w, h, ratio);
}

fn void MicroVG.endFrame(&self) => self.backend.flush(
	self.vertices,
	self.calls,
	self.viewW,
	self.viewH
);

fn State* MicroVG.currentState(&self) => &self.states[self.state];

fn void MicroVG.reset(&self) {
	self.state = 0;
	self.states[0] = state::defaultState();
}

fn void MicroVG.save(&self) {
	if (self.state >= constant::MAX_STATES - 1) return;

	self.states[self.state + 1] = self.states[self.state];
	self.state++;
}

fn void MicroVG.restore(&self) {
	if (self.state == 0) return;
	self.state--;
}

fn void MicroVG.translate(&self, float x, float y) {
	State* state = self.currentState();
	state.translate(x, y);
}

fn void MicroVG.scale(&self, float x, float y) {
	State* state = self.currentState();
	state.scale(x, y);
}

fn void MicroVG.rotate(&self, float rad) {
	State* state = self.currentState();
	state.rotate(rad);
}

fn void MicroVG.alpha(&self, float a) {
	State* state = self.currentState();
	state.setAlpha(a);
}

fn DebugStats MicroVG.debugStats(&self) => {
	.vertices = self.vertices.count,
	.vertexCap = self.vertices.capacity,
	.drawCalls = self.calls.count,
	.drawCallCap = self.calls.capacity,
	.commands = self.cmds.count,
	.commandCap = self.cmds.capacity,
	.tessFails = self.tessFails,

	.usedBytes =
		self.vertices.count * Vertex::size +
		self.calls.count * DrawCall::size +
		self.cmds.count * Cmd::size,

	.reservedBytes =
		MicroVG::size +
		self.vertices.capacity * Vertex::size +
		self.calls.capacity * DrawCall::size +
		self.cmds.capacity * Cmd::size
};

fn void MicroVG.pushVertex(&self, Vec2f pos, Vec2f tex = { 1, 0 }) {
	self.vertices.push({ pos, tex });
}

fn void MicroVG.pushCall(&self, int offset, int count, Color color)
=> self.calls.push({ .offset = offset, .count = count, .color = color });

fn void MicroVG.pushFillCall(&self, int offset, int count, Color color, FillRule rule, int coverOffset, int coverCount)
=> self.calls.push({ offset, count, color, true, rule, coverOffset, coverCount });

fn Path MicroVG.makePath(&self) => { self, self.cmds.count, 0 };
