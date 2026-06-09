module microvg;

// --- Path command ---

enum PathCmdType : char { MOVE_TO, LINE_TO, CLOSE }

struct PathCmd {
    PathCmdType type;
    Vec2 pos;
}

// Path là handle cho một đường vẽ trong frame hiện tại.
// Dữ liệu thực (PathCmd[]) sống trong arena của MicroVG.
// Path giữ index bắt đầu và số lượng cmd — không phải pointer trực tiếp.
struct Path {
    MicroVG* vg;
    sz cmdStart;
    sz cmdCount;
    bool closed;
    bool hasStart;
}

fn void Path.moveTo(&self, float x, float y) {
    self.vg.appendPathCmd({ MOVE_TO, {x, y} });
    self.cmdCount++;
    self.hasStart = true;
}

fn void Path.lineTo(&self, float x, float y) {
    if (!self.hasStart) { self.moveTo(x, y); return; }
    self.vg.appendPathCmd({ LINE_TO, {x, y} });
    self.cmdCount++;
}

fn void Path.close(&self) {
    if (!self.hasStart) return;
    self.vg.appendPathCmd({ CLOSE, {} });
    self.cmdCount++;
    self.closed = true;
}
