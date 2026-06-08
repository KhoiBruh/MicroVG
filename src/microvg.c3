module microvg;

struct MicroVG {
	int width;
	int height;
	float dpr;

	Backend backend;

	State[32] states;
	ichar state;

	PathPool paths;
	VertexBuffer vertices;
}

fn MicroVG*? create() {
	MicroVG* vg = mem::calloc(MicroVG::size);

	if (catch err = vg.backend.init()) {
    	vg.destroy();
    	return BACKEND_NOT_READY~;
    }

	return vg;
}

fn void MicroVG.destroy(&self) {
	if (!self) return;

	self.paths.destroy();
	self.vertices.destroy();
	mem::free(self);
}

fn void MicroVG.beginFrame(&self, int width, int height, float dpr) {
	self.width = width;
	self.height = height;
	self.dpr = dpr;

	self.reset();
	self.paths.begin();
	self.vertices.reset();
}

fn void MicroVG.endFrame(&self) {
	self.paths.pushDraw(&self.vertices);
	self.backend.flush(self);
}

fn State MicroVG.currentState(&self) => self.states[self.state];

fn void MicroVG.reset(&self) {
	self.state = 0;
	self.states[0].reset();
}

fn void MicroVG.save(&self) {
	if (self.state >= 31) return;

	self.states[self.state++] = self.states[self.state];
}

fn void MicroVG.restore(&self) {
	if (self.state == 0) return;
	self.state--;
}

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


