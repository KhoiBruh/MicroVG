module microvg;

enum PathType : char { MOVE_TO, LINE_TO, CLOSE }

struct Command {
    PathType type;
    Vec2 pos;
}

struct Path {
    MicroVG* vg;

    sz start;
    sz count;

    bool closed;
    bool started;
}

fn void Path.moveTo(&self, float x, float y) {
    self.vg.pushCmd(MOVE_TO, { x, y });
    self.count++;
    self.started = true;
}

fn void Path.lineTo(&self, float x, float y) {
    if (!self.started) {
        self.moveTo(x, y);
        return;
    }

    self.vg.pushCmd(LINE_TO, { x, y });
    self.count++;
}

fn void Path.close(&self) {
    if (!self.started) return;
    self.vg.pushCmd(CLOSE, { });
    self.count++;
    self.closed = true;
}
