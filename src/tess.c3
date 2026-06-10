module microvg;

import std::math;

const float AA_SIZE @private = 1.0f;

fn float pathArea(Vec2* pts, int count) {
    float area = 0;
    for (int i = 0; i < count; i++) {
        Vec2 a = pts[i];
        Vec2 b = pts[(i + 1) % count];
        area += a.x * b.y - b.x * a.y;
    }

    return area;
}

fn Vec2 edgeNormal(Vec2 a, Vec2 b, float scale) {
    Vec2 d = b - a;
    float len = d.length();
    if (len < 0.0001) return { 0, 0 };

    return { (-d.y / len) * scale, (d.x / len) * scale };
}

fn void MicroVG.pushCmd(&self, PathType type, Vec2 pt) {
    if (self.cmdCount >= self.cmdCap) {
        sz newCap = self.cmdCap * 2;
        Command* buf = mem::calloc(newCap * Command::size);
        for (sz i = 0; i < self.cmdCount; i++) buf[i] = self.cmds[i];

        mem::free(self.cmds);
        self.cmds = buf;
        self.cmdCap = newCap;
    }

    self.cmds[self.cmdCount++] = { type, pt };
}

fn void MicroVG.pushVert(&self, Vec2 pos, Color c, float a) {
    if (self.vertCount >= self.vertCap) {
        sz newCap = self.vertCap * 2;
        Vertex* buf = mem::calloc(newCap * Vertex::size);
        for (sz i = 0; i < self.vertCount; i++) buf[i] = self.verts[i];

        mem::free(self.verts);
        self.verts = buf;
        self.vertCap = newCap;
    }

    self.verts[self.vertCount++] = { pos, c.alpha(a) };
}

fn void MicroVG.pushCall(&self, sz offset, sz count) {
    if (self.callCount >= self.callCap) {
        sz newCap = self.callCap * 2;
        DrawCall* buf = mem::calloc(newCap * DrawCall::size);
        for (sz i = 0; i < self.callCount; i++) buf[i] = self.calls[i];

        mem::free(self.calls);
        self.calls = buf;
        self.callCap = newCap;
    }

    self.calls[self.callCount++] = { offset, count };
}

fn void MicroVG.pushPath(&self, Path path, Paint paint) {
    State* state = self.currentState();
    float alpha = state.alpha;

    Command* cmds = &self.cmds[path.start];
    Vec2[MAX_PATH_POINTS] pts;
    int ptCount = 0;

    for (sz i = 0; i < path.count; i++) {
        if (cmds[i].type == CLOSE) continue;
        if (ptCount < MAX_PATH_POINTS) pts[ptCount++] = state.form * cmds[i].pos;
    }

    if (ptCount < 2) return;

    if (paint.hasFill && path.closed && ptCount >= 3) {
        sz offset = self.vertCount;
        Color fc = paint.fillColor;

        for (int i = 1; i < ptCount - 1; i++) {
            self.pushVert(pts[0], fc, alpha);
            self.pushVert(pts[i], fc, alpha);
            self.pushVert(pts[i + 1], fc, alpha);
        }

        float side = pathArea(&pts[0], ptCount) > 0 ? -1.0f : 1.0f;
        float aa = AA_SIZE / math::max(self.dpr, 1.0f);

        for (int i = 0; i < ptCount; i++) {
            Vec2 a = pts[i];
            Vec2 b = pts[(i + 1) % ptCount];
            Vec2 n = edgeNormal(a, b, aa * side);
            if (n.x == 0 && n.y == 0) continue;

            self.pushVert(a, fc, alpha);
            self.pushVert(b, fc, alpha);
            self.pushVert(b + n, fc, 0);
            self.pushVert(a, fc, alpha);
            self.pushVert(b + n, fc, 0);
            self.pushVert(a + n, fc, 0);
        }

        sz n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }

    if (paint.hasLine) {
        float hw = paint.lineWidth * 0.5;
        float aa = AA_SIZE / math::max(self.dpr, 1.0f);
        Color lc = paint.lineColor;
        sz offset = self.vertCount;
        int segs = path.closed ? ptCount : ptCount - 1;

        for (int i = 0; i < segs; i++) {
            Vec2 a = pts[i];
            Vec2 b = pts[(i + 1) % ptCount];
            Vec2 d = b - a;
            float len = d.length();
            if (len < 0.0001) continue;

            Vec2 n = { (-d.y / len) * hw, (d.x / len) * hw };
            Vec2 f = { (-d.y / len) * (hw + aa), (d.x / len) * (hw + aa) };

            self.pushVert(a + n, lc, alpha);
            self.pushVert(a - n, lc, alpha);
            self.pushVert(b + n, lc, alpha);
            self.pushVert(a - n, lc, alpha);
            self.pushVert(b - n, lc, alpha);
            self.pushVert(b + n, lc, alpha);

            self.pushVert(a + f, lc, 0);
            self.pushVert(a + n, lc, alpha);
            self.pushVert(b + f, lc, 0);
            self.pushVert(a + n, lc, alpha);
            self.pushVert(b + n, lc, alpha);
            self.pushVert(b + f, lc, 0);

            self.pushVert(a - n, lc, alpha);
            self.pushVert(a - f, lc, 0);
            self.pushVert(b - n, lc, alpha);
            self.pushVert(a - f, lc, 0);
            self.pushVert(b - f, lc, 0);
            self.pushVert(b - n, lc, alpha);
        }

        sz n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }
}
