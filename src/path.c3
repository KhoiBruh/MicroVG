module microvg;

// --- Path command ---

enum PathCmdType : char {
    MOVE_TO,
    LINE_TO,
    CLOSE
}

struct PathCmd {
    PathCmdType type;
    float x;
    float y;
}

// --- Path ---
// Path là handle đại diện cho một đường vẽ.
// Dữ liệu cmds sống trong arena của MicroVG.
// Path chỉ giữ: index bắt đầu vào arena, số lượng cmds, và trạng thái.
// Tương tác với dữ liệu qua back-reference vg.

struct Path {
    MicroVG* vg;       // back-reference tới context
    sz cmdStart;       // vị trí bắt đầu trong vg.pathCmds (index, không phải pointer)
    sz cmdCount;       // số lượng cmds của path này
    bool closed;       // path đã được đóng?
    bool hasStart;     // moveTo đã được gọi?
}

fn void Path.moveTo(&self, float x, float y) {
    PathCmd cmd;
    cmd.type = MOVE_TO;
    cmd.x = x;
    cmd.y = y;
    self.vg.appendPathCmd(cmd);
    self.cmdCount++;
    self.hasStart = true;
}

fn void Path.lineTo(&self, float x, float y) {
    // Nếu chưa có điểm bắt đầu, treat như moveTo
    if (!self.hasStart) {
        self.moveTo(x, y);
        return;
    }
    PathCmd cmd;
    cmd.type = LINE_TO;
    cmd.x = x;
    cmd.y = y;
    self.vg.appendPathCmd(cmd);
    self.cmdCount++;
}

fn void Path.close(&self) {
    if (!self.hasStart) return;
    PathCmd cmd;
    cmd.type = CLOSE;
    cmd.x = 0;
    cmd.y = 0;
    self.vg.appendPathCmd(cmd);
    self.cmdCount++;
    self.closed = true;
}
