module microvg;

// Buffer growth + low-level append for commands, vertices and draw calls.

fn void MicroVG.pushCmd(&self, PathType type, Vec2 pt) {
    if (self.cmdCount >= self.cmdCap) {
        int newCap = self.cmdCap * 2;
        Command* buf = mem::calloc(newCap * Command::size);
        for (int i = 0; i < self.cmdCount; i++) buf[i] = self.cmds[i];

        mem::free(self.cmds);
        self.cmds = buf;
        self.cmdCap = newCap;
    }

    self.cmds[self.cmdCount++] = { type, pt };
}

fn void MicroVG.pushVert(&self, Vec2 pos, Vec2 uv, Color c, float a) {
    if (self.vertCount >= self.vertCap) {
        int newCap = self.vertCap * 2;
        Vertex* buf = mem::calloc(newCap * Vertex::size);
        for (int i = 0; i < self.vertCount; i++) buf[i] = self.verts[i];

        mem::free(self.verts);
        self.verts = buf;
        self.vertCap = newCap;
    }

    self.verts[self.vertCount++] = { pos, uv, c.alpha(a) };
}

fn void MicroVG.pushCall(&self, int offset, int count, DrawMode mode) {
    if (self.callCount >= self.callCap) {
        int newCap = self.callCap * 2;
        DrawCall* buf = mem::calloc(newCap * DrawCall::size);
        for (int i = 0; i < self.callCount; i++) buf[i] = self.calls[i];

        mem::free(self.calls);
        self.calls = buf;
        self.callCap = newCap;
    }

    self.calls[self.callCount++] = { offset, count, mode };
}
