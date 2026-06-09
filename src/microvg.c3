module microvg;

import std::math;

const int MAX_STATES        @private = 32;
const sz  DRAW_CALL_INIT_CAP @private = 32;
const sz  VERTEX_INIT_CAP    @private = 2048;
const sz  PATH_CMD_INIT_CAP  @private = 256;
const int MAX_PATH_POINTS    @private = 512;

struct Vertex  { float x, y, r, g, b, a; }
struct DrawCall { sz vertexOffset, vertexCount; }

struct MicroVG {
    int   width, height;
    float dpr;

    State[MAX_STATES] states;
    char  stateCount;

    PathCmd* pathCmds;
    sz       pathCmdCount, pathCmdCap;

    Vertex*  vertices;
    sz       vertexCount,  vertexCap;

    DrawCall* drawCalls;
    sz        drawCallCount, drawCallCap;

    Backend backend;
}

// --- Lifecycle ---

fn MicroVG* create() {
    MicroVG* vg = (MicroVG*)mem::calloc(MicroVG::size);

    vg.pathCmdCap  = PATH_CMD_INIT_CAP;
    vg.pathCmds    = (PathCmd*)mem::calloc(PATH_CMD_INIT_CAP * PathCmd::size);
    vg.vertexCap   = VERTEX_INIT_CAP;
    vg.vertices    = (Vertex*)mem::calloc(VERTEX_INIT_CAP * Vertex::size);
    vg.drawCallCap = DRAW_CALL_INIT_CAP;
    vg.drawCalls   = (DrawCall*)mem::calloc(DRAW_CALL_INIT_CAP * DrawCall::size);

    vg.backend.init();
    return vg;
}

fn void MicroVG.destroy(&self) {
    if (!self) return;
    mem::free(self.pathCmds);
    mem::free(self.vertices);
    mem::free(self.drawCalls);
    self.backend.destroy();
    mem::free(self);
}

// --- Frame ---

fn void MicroVG.beginFrame(&self, int width, int height, float dpr) {
    self.width  = width;
    self.height = height;
    self.dpr    = dpr;

    self.pathCmdCount  = 0;
    self.vertexCount   = 0;
    self.drawCallCount = 0;

    self.stateCount = 1;
    self.states[0].reset();
}

fn void MicroVG.endFrame(&self) {
    if (self.drawCallCount == 0) return;
    self.backend.flush(
        self.vertices,  self.vertexCount,
        self.drawCalls, self.drawCallCount,
        self.width, self.height
    );
}

// --- State ---

fn State* MicroVG.currentState(&self) @inline {
    int idx = (int)self.stateCount - 1;
    return &self.states[idx];
}

fn void MicroVG.save(&self) {
    if (self.stateCount >= MAX_STATES) return;
    int cur = (int)self.stateCount - 1;
    self.states[self.stateCount] = self.states[cur];
    self.stateCount++;
}

fn void MicroVG.restore(&self) {
    if (self.stateCount <= 1) return;
    self.stateCount--;
}

fn void MicroVG.reset(&self)           { self.currentState().reset(); }
fn Vec2 MicroVG.transform(&self, Vec2 v) { return self.currentState().form * v; }
fn void MicroVG.translate(&self, float x, float y) { self.currentState().form.translate(x, y); }
fn void MicroVG.scale(&self, float x, float y)     { self.currentState().form.scale(x, y); }
fn void MicroVG.rotate(&self, float rad)            { self.currentState().form.rotate(rad); }
fn void MicroVG.alpha(&self, float a)               { self.currentState().alpha *= a; }

// --- Path & Paint ---

fn Path MicroVG.makePath(&self) {
    return { .vg = self, .cmdStart = self.pathCmdCount };
}

fn Paint MicroVG.makePaint(&self) {
    return {};
}

fn void MicroVG.appendPathCmd(&self, PathCmd cmd) {
    if (self.pathCmdCount >= self.pathCmdCap) {
        sz newCap = self.pathCmdCap * 2;
        PathCmd* buf = (PathCmd*)mem::calloc(newCap * PathCmd::size);
        for (sz i = 0; i < self.pathCmdCount; i++) buf[i] = self.pathCmds[i];
        mem::free(self.pathCmds);
        self.pathCmds   = buf;
        self.pathCmdCap = newCap;
    }
    self.pathCmds[self.pathCmdCount++] = cmd;
}

// --- Tessellation ---

fn void MicroVG.pushVertex(&self, float x, float y, Color c, float alpha) {
    if (self.vertexCount >= self.vertexCap) {
        sz newCap = self.vertexCap * 2;
        Vertex* buf = (Vertex*)mem::calloc(newCap * Vertex::size);
        for (sz i = 0; i < self.vertexCount; i++) buf[i] = self.vertices[i];
        mem::free(self.vertices);
        self.vertices  = buf;
        self.vertexCap = newCap;
    }
    self.vertices[self.vertexCount++] = { x, y, c.r, c.g, c.b, c.a * alpha };
}

fn void MicroVG.pushDrawCall(&self, sz offset, sz count) {
    if (self.drawCallCount >= self.drawCallCap) {
        sz newCap = self.drawCallCap * 2;
        DrawCall* buf = (DrawCall*)mem::calloc(newCap * DrawCall::size);
        for (sz i = 0; i < self.drawCallCount; i++) buf[i] = self.drawCalls[i];
        mem::free(self.drawCalls);
        self.drawCalls   = buf;
        self.drawCallCap = newCap;
    }
    self.drawCalls[self.drawCallCount++] = { offset, count };
}

fn void MicroVG.pushPath(&self, Path path, Paint paint) {
    State* state     = self.currentState();
    float  stateAlpha = state.alpha;

    // Collect transformed points (MOVE_TO + LINE_TO only)
    Vec2[MAX_PATH_POINTS] pts;
    int ptCount = 0;
    PathCmd* cmds = &self.pathCmds[path.cmdStart];
    for (sz i = 0; i < path.cmdCount; i++) {
        if (cmds[i].type == CLOSE) continue;
        if (ptCount < MAX_PATH_POINTS) pts[ptCount++] = state.form * vec2(cmds[i].x, cmds[i].y);
    }
    if (ptCount < 2) return;

    // Fill: fan triangulation (convex polygon, closed path only)
    if (paint.hasFill && path.closed && ptCount >= 3) {
        sz offset = self.vertexCount;
        Color fc  = paint.fillColor;
        for (int i = 1; i < ptCount - 1; i++) {
            self.pushVertex(pts[0].x, pts[0].y,       fc, stateAlpha);
            self.pushVertex(pts[i].x, pts[i].y,       fc, stateAlpha);
            self.pushVertex(pts[i+1].x, pts[i+1].y,   fc, stateAlpha);
        }
        sz n = self.vertexCount - offset;
        if (n > 0) self.pushDrawCall(offset, n);
    }

    // Stroke: each segment → quad (2 triangles)
    if (paint.hasLine) {
        float hw   = paint.lineWidth * 0.5f;
        Color lc   = paint.lineColor;
        sz offset  = self.vertexCount;
        int segs   = path.closed ? ptCount : ptCount - 1;

        for (int i = 0; i < segs; i++) {
            Vec2  a  = pts[i];
            Vec2  b  = pts[(i + 1) % ptCount];
            float dx = b.x - a.x;
            float dy = b.y - a.y;
            float len = math::sqrt(dx * dx + dy * dy);
            if (len < 0.0001f) continue;

            float nx = (-dy / len) * hw;
            float ny = ( dx / len) * hw;

            self.pushVertex(a.x + nx, a.y + ny, lc, stateAlpha);
            self.pushVertex(a.x - nx, a.y - ny, lc, stateAlpha);
            self.pushVertex(b.x + nx, b.y + ny, lc, stateAlpha);
            self.pushVertex(a.x - nx, a.y - ny, lc, stateAlpha);
            self.pushVertex(b.x - nx, b.y - ny, lc, stateAlpha);
            self.pushVertex(b.x + nx, b.y + ny, lc, stateAlpha);
        }

        sz n = self.vertexCount - offset;
        if (n > 0) self.pushDrawCall(offset, n);
    }
}
