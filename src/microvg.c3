module microvg;

import std::math;

// --- Constants ---

const int MAX_STATES @private = 32;
const sz DRAW_CALL_INIT_CAP @private = 32;
const sz VERTEX_INIT_CAP @private = 2048;
const sz PATH_CMD_INIT_CAP @private = 256;

// Số điểm tối đa trên stack khi tessellate một path
const int MAX_PATH_POINTS @private = 512;

// --- GPU vertex layout: [x, y, r, g, b, a] ---

struct Vertex {
    float x;
    float y;
    float r;
    float g;
    float b;
    float a;
}

// Mỗi draw call = một lệnh glDrawArrays
struct DrawCall {
    sz vertexOffset;
    sz vertexCount;
}

// --- MicroVG context ---

struct MicroVG {
    // Kích thước frame
    int width;
    int height;
    float dpr;

    // State stack (không allocate, dùng mảng tĩnh tối đa MAX_STATES)
    State[MAX_STATES] states;
    char stateCount;

    // Arena cho PathCmd (tất cả cmds của mọi path trong frame này)
    // Được reset mỗi beginFrame, không free/alloc mỗi frame
    PathCmd* pathCmds;
    sz pathCmdCount;
    sz pathCmdCap;

    // CPU vertex buffer (được tessellate từ paths)
    Vertex* vertices;
    sz vertexCount;
    sz vertexCap;

    // Danh sách draw calls (được reset mỗi beginFrame)
    DrawCall* drawCalls;
    sz drawCallCount;
    sz drawCallCap;

    // OpenGL backend
    Backend backend;
}

// --- Lifecycle ---

fn MicroVG* create() {
    MicroVG* vg = (MicroVG*)mem::calloc(MicroVG::size);

    vg.pathCmdCap = PATH_CMD_INIT_CAP;
    vg.pathCmds = (PathCmd*)mem::calloc(PATH_CMD_INIT_CAP * PathCmd::size);

    vg.vertexCap = VERTEX_INIT_CAP;
    vg.vertices = (Vertex*)mem::calloc(VERTEX_INIT_CAP * Vertex::size);

    vg.drawCallCap = DRAW_CALL_INIT_CAP;
    vg.drawCalls = (DrawCall*)mem::calloc(DRAW_CALL_INIT_CAP * DrawCall::size);

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

    // Reset arenas (tái dùng bộ nhớ, không free/alloc)
    self.pathCmdCount = 0;
    self.vertexCount  = 0;
    self.drawCallCount = 0;

    // Reset state stack về identity
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

// --- State API ---

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

fn void MicroVG.reset(&self) {
    self.currentState().reset();
}

fn Vec2 MicroVG.transform(&self, Vec2 v) {
    return self.currentState().form * v;
}

fn void MicroVG.translate(&self, float x, float y) {
    self.currentState().form.translate(x, y);
}

fn void MicroVG.scale(&self, float x, float y) {
    self.currentState().form.scale(x, y);
}

fn void MicroVG.rotate(&self, float rad) {
    self.currentState().form.rotate(rad);
}

fn void MicroVG.alpha(&self, float a) {
    self.currentState().alpha *= a;
}

// --- Path API ---

fn Path MicroVG.makePath(&self) {
    Path p;
    p.vg       = self;
    p.cmdStart = self.pathCmdCount;
    p.cmdCount = 0;
    p.closed   = false;
    p.hasStart = false;
    return p;
}

// appendPathCmd: được gọi từ Path.moveTo/lineTo/close
// Tự mở rộng arena nếu cần (copy + free old, alloc new)
fn void MicroVG.appendPathCmd(&self, PathCmd cmd) {
    if (self.pathCmdCount >= self.pathCmdCap) {
        sz newCap = self.pathCmdCap * 2;
        PathCmd* newBuf = (PathCmd*)mem::calloc(newCap * PathCmd::size);
        for (sz i = 0; i < self.pathCmdCount; i++) {
            newBuf[i] = self.pathCmds[i];
        }
        mem::free(self.pathCmds);
        self.pathCmds   = newBuf;
        self.pathCmdCap = newCap;
    }
    self.pathCmds[self.pathCmdCount] = cmd;
    self.pathCmdCount++;
}

// --- Paint API ---

fn Paint MicroVG.makePaint(&self) {
    Paint p;
    return p;
}

// --- Tessellation helpers ---

fn void MicroVG.pushVertex(&self, float x, float y, Color c, float alpha) {
    if (self.vertexCount >= self.vertexCap) {
        sz newCap = self.vertexCap * 2;
        Vertex* newBuf = (Vertex*)mem::calloc(newCap * Vertex::size);
        for (sz i = 0; i < self.vertexCount; i++) {
            newBuf[i] = self.vertices[i];
        }
        mem::free(self.vertices);
        self.vertices   = newBuf;
        self.vertexCap  = newCap;
    }
    Vertex v;
    v.x = x;
    v.y = y;
    v.r = c.r;
    v.g = c.g;
    v.b = c.b;
    v.a = c.a * alpha;
    self.vertices[self.vertexCount] = v;
    self.vertexCount++;
}

fn void MicroVG.pushDrawCall(&self, sz offset, sz count) {
    if (self.drawCallCount >= self.drawCallCap) {
        sz newCap = self.drawCallCap * 2;
        DrawCall* newBuf = (DrawCall*)mem::calloc(newCap * DrawCall::size);
        for (sz i = 0; i < self.drawCallCount; i++) {
            newBuf[i] = self.drawCalls[i];
        }
        mem::free(self.drawCalls);
        self.drawCalls    = newBuf;
        self.drawCallCap  = newCap;
    }
    DrawCall dc;
    dc.vertexOffset = offset;
    dc.vertexCount  = count;
    self.drawCalls[self.drawCallCount] = dc;
    self.drawCallCount++;
}

// --- pushPath: tessellate path + paint → GPU vertex buffer ---

fn void MicroVG.pushPath(&self, Path path, Paint paint) {
    State* state = self.currentState();
    float stateAlpha = state.alpha;

    // Bước 1: Thu thập các điểm đã transform
    Vec2[MAX_PATH_POINTS] pts;
    int ptCount = 0;

    PathCmd* cmds = &self.pathCmds[path.cmdStart];
    for (sz i = 0; i < path.cmdCount; i++) {
        PathCmd cmd = cmds[i];
        // CLOSE không tạo điểm — chỉ MOVE_TO và LINE_TO tạo điểm
        if (cmd.type == CLOSE) continue;
        if (ptCount < MAX_PATH_POINTS) {
            pts[ptCount] = state.form * vec2(cmd.x, cmd.y);
            ptCount++;
        }
    }

    if (ptCount < 2) return;

    // Bước 2: Fill — fan triangulation (convex polygon)
    // Chỉ khi path đã đóng và có ít nhất 3 điểm
    if (paint.hasFill && path.closed && ptCount >= 3) {
        sz offset = self.vertexCount;
        Color fc  = paint.fillColor;

        // Fan từ pts[0]: tam giác (0, i, i+1)
        for (int i = 1; i < ptCount - 1; i++) {
            self.pushVertex(pts[0].x, pts[0].y, fc, stateAlpha);
            self.pushVertex(pts[i].x, pts[i].y, fc, stateAlpha);
            self.pushVertex(pts[i + 1].x, pts[i + 1].y, fc, stateAlpha);
        }

        sz vtxCount = self.vertexCount - offset;
        if (vtxCount > 0) self.pushDrawCall(offset, vtxCount);
    }

    // Bước 3: Stroke — mỗi segment → quad → 2 tam giác
    if (paint.hasLine) {
        float hw  = paint.lineWidth * 0.5f;
        Color lc  = paint.lineColor;
        sz offset = self.vertexCount;

        // Path đóng: vẽ thêm segment cuối nối về điểm đầu
        int totalSegs = path.closed ? ptCount : (ptCount - 1);

        for (int i = 0; i < totalSegs; i++) {
            Vec2 a = pts[i];
            Vec2 b = pts[(i + 1) % ptCount];

            float dx  = b.x - a.x;
            float dy  = b.y - a.y;
            float len = math::sqrt(dx * dx + dy * dy);
            if (len < 0.0001f) continue;

            // Normal perpendicular (đơn vị), nhân với half-width
            float nx = (-dy / len) * hw;
            float ny = ( dx / len) * hw;

            // 4 góc của quad: A = a ± n,  B = b ± n
            float ax0 = a.x + nx;  float ay0 = a.y + ny;
            float ax1 = a.x - nx;  float ay1 = a.y - ny;
            float bx0 = b.x + nx;  float by0 = b.y + ny;
            float bx1 = b.x - nx;  float by1 = b.y - ny;

            // Tam giác 1
            self.pushVertex(ax0, ay0, lc, stateAlpha);
            self.pushVertex(ax1, ay1, lc, stateAlpha);
            self.pushVertex(bx0, by0, lc, stateAlpha);

            // Tam giác 2
            self.pushVertex(ax1, ay1, lc, stateAlpha);
            self.pushVertex(bx1, by1, lc, stateAlpha);
            self.pushVertex(bx0, by0, lc, stateAlpha);
        }

        sz vtxCount = self.vertexCount - offset;
        if (vtxCount > 0) self.pushDrawCall(offset, vtxCount);
    }
}
