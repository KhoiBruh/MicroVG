module microvg;

struct MicroVG {
	int width;
	int height;
	float dpr;

	Backend backend;

	State[32] states;
	char state;

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

	self.paths.begin();
	self.vertices.reset();
}

fn void MicroVG.endFrame(&self) {
	self.backend.flush(self);
}

fn State* MicroVG.currentState(&self) => &self.states[self.state];

fn Path* MicroVG.makePath(&self) => self.paths.acquire();


