module microvg;

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

        sz n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }

    if (paint.hasLine) {
        float hw = paint.lineWidth * 0.5;
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

            self.pushVert(a + n, lc, alpha);
            self.pushVert(a - n, lc, alpha);
            self.pushVert(b + n, lc, alpha);
            self.pushVert(a - n, lc, alpha);
            self.pushVert(b - n, lc, alpha);
            self.pushVert(b + n, lc, alpha);
        }

        sz n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }
}
