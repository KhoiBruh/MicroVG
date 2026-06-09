module microvg;

import std::math;

const ichar MAX_STATES @private = 32;
const int MAX_PATH_POINTS @private = 512;
const sz DRAW_CALL_INIT_CAP @private = 32;
const sz VERTEX_INIT_CAP @private = 2048;
const sz PATH_CMD_INIT_CAP @private = 256;

struct Vertex {
	Vec2 pos;
	Color color;
}

struct DrawCall {
	sz offset;
	sz count;
}

struct MicroVG {
    int width, height;
    float dpr;

    State[MAX_STATES] states;
    ichar stateCount;

    Command* cmds;
    sz cmdCount, cmdCap;

    Vertex* verts;
    sz vertCount, vertCap;

    DrawCall* calls;
    sz callCount, callCap;

    Backend backend;
}

fn MicroVG* create() {
    MicroVG* vg = mem::calloc(MicroVG::size);

    vg.cmdCap = PATH_CMD_INIT_CAP;
    vg.cmds = mem::calloc(PATH_CMD_INIT_CAP * Command::size);
    vg.vertCap = VERTEX_INIT_CAP;
    vg.verts = mem::calloc(VERTEX_INIT_CAP * Vertex::size);
    vg.callCap = DRAW_CALL_INIT_CAP;
    vg.calls = mem::calloc(DRAW_CALL_INIT_CAP * DrawCall::size);

    vg.backend.init();
    return vg;
}

fn void MicroVG.destroy(&self) {
    if (!self) return;
    mem::free(self.cmds);
    mem::free(self.verts);
    mem::free(self.calls);
    self.backend.destroy();
    mem::free(self);
}

fn void MicroVG.beginFrame(&self, int width, int height, float dpr) {
    self.width = width;
    self.height = height;
    self.dpr = dpr;

    self.cmdCount = 0;
    self.vertCount = 0;
    self.callCount = 0;

    self.stateCount = 1;
    self.states[0].reset();
}

fn void MicroVG.endFrame(&self) {
    if (self.callCount == 0) return;
    self.backend.flush(
        self.verts, self.vertCount,
        self.calls, self.callCount,
        self.width, self.height
    );
}

fn State* MicroVG.currentState(&self) {
    ichar idx = self.stateCount - 1;
    return &self.states[idx];
}

fn void MicroVG.save(&self) {
    if (self.stateCount >= MAX_STATES) return;
    ichar cur = self.stateCount - 1;
    self.states[self.stateCount] = self.states[cur];
    self.stateCount++;
}

fn void MicroVG.restore(&self) {
    if (self.stateCount <= 1) return;
    self.stateCount--;
}

fn void MicroVG.reset(&self) => self.currentState().reset();

fn Vec2 MicroVG.transform(&self, Vec2 v) => self.currentState().form * v;

fn void MicroVG.translate(&self, float x, float y) => self.currentState().form.translate(x, y);

fn void MicroVG.scale(&self, float x, float y) => self.currentState().form.scale(x, y);

fn void MicroVG.rotate(&self, float rad) => self.currentState().form.rotate(rad);

fn void MicroVG.alpha(&self, float a) => self.currentState().alpha = a;

fn Path MicroVG.makePath(&self) => { .vg = self, .start = self.cmdCount };

fn Paint MicroVG.makePaint(&self) => {};
