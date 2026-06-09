module microvg;

const char MAX_STATES @private = 32;
const sz DRAW_CALL_INIT_CAP @private = 32;
const sz VERTEX_INIT_CAP @private = 2048;

struct MicroVG {
	int width;
	int height;
	float dpr;

	Backend backend;

	State[MAX_STATES] states;
	ichar state;

	PathPool paths;
	DrawCallBuffer calls;
	VertexBuffer vertices;
}

fn MicroVG*? create() {
	MicroVG* vg = mem::calloc(MicroVG::size);

	if (catch err = vg.backend.init()) {
    	vg.destroy();
    	return BACKEND_NOT_READY~;
    }

	vg.calls.init(DRAW_CALL_INIT_CAP);
	vg.vertices.init(VERTEX_INIT_CAP);

	return vg;
}

fn void MicroVG.destroy(&self) {
	if (!self) return;

	self.calls.destroy();
	self.paths.destroy();
	self.vertices.destroy();
	mem::free(self);
}

fn void MicroVG.beginFrame(&self, int width, int height, float dpr) {
	self.width = width;
	self.height = height;
	self.dpr = dpr;

	self.reset();
	self.paths.reset();
	self.calls.reset();
	self.vertices.reset();
}

fn void MicroVG.endFrame(&self) {
	self.backend.flush(self);
}

fn State MicroVG.currentState(&self) => self.states[self.state];

fn void MicroVG.reset(&self) {
	self.state = 0;
	self.states[0].reset();
}

fn void MicroVG.save(&self) {
	if (self.state >= MAX_STATES - 1) return;
	self.states[self.state++] = self.states[self.state];
}

fn void MicroVG.restore(&self) {
	if (self.state == 0) return;
	self.state--;
}

fn Vec2 MicroVG.transform(&self, Vec2 v) => self.currentState().transform(v);

fn void MicroVG.scale(&self, float x, float y) => self.currentState().scale(x, y);

fn void MicroVG.translate(&self, float x, float y) => self.currentState().translate(x, y);

fn void MicroVG.rotate(&self, float rad) => self.currentState().rotate(rad);

fn void MicroVG.alpha(&self, float alpha) {
	State state = self.currentState();
	state.alpha = alpha;
}

fn Path* MicroVG.makePath(&self) {
	Path* path = self.paths.acquire();
	path.state = self.currentState();

	return path;
}

fn Paint MicroVG.makePaint(&self) => {};

fn void MicroVG.pushPath(&self, Path* path, Paint paint) {
	int first = (int) self.vertices.count / 2;
	int count = (int) self.vertices.count / 2 - first;
	path.pushDraw(&self.vertices, paint);

	if (count == 0) return;
	self.calls.push({ first, count, paint });
}


