module microvg;

const float AA_SIZE @private = 1;
const float MITER_LIMIT @private = 4;
const float MIN_DIST @private = 0.0001;

fn float pathArea(Vec2* pts, int count) {
    float area = 0;
    for (int i = 0; i < count; i++) {
        Vec2 a = pts[i];
        Vec2 b = pts[(i + 1) % count];
        area += a.dot(b);
    }

    return area;
}

fn Vec2 edgeNormal(Vec2 a, Vec2 b, float scale) {
    Vec2 d = b - a;
    float len = d.length();
    if (len < MIN_DIST) return { 0, 0 };

    return { (-d.y / len) * scale, (d.x / len) * scale };
}

fn void MicroVG.pushTri(&self, Vec2 a, Vec2 b, Vec2 c, Color color, float alpha) {
    self.pushVert(a, color, alpha);
    self.pushVert(b, color, alpha);
    self.pushVert(c, color, alpha);
}

fn void MicroVG.pushQuad(&self, Vec2 a, Vec2 b, Vec2 c, Vec2 d, Color color, float alpha) {
    self.pushVert(a, color, alpha);
    self.pushVert(b, color, alpha);
    self.pushVert(c, color, alpha);
    self.pushVert(a, color, alpha);
    self.pushVert(c, color, alpha);
    self.pushVert(d, color, alpha);
}

fn void MicroVG.pushQuadGradient(&self, Vec2 a, Vec2 b, Vec2 c, Vec2 d, Color color, float alpha1, float alpha2) {
    self.pushVert(a, color, alpha1);
    self.pushVert(b, color, alpha1);
    self.pushVert(c, color, alpha2);
    self.pushVert(a, color, alpha1);
    self.pushVert(c, color, alpha2);
    self.pushVert(d, color, alpha2);
}

fn void MicroVG.pushStrokeJoin(&self, Vec2 prev, Vec2 p, Vec2 next, Color color, float alpha, float hw, float aa, LineJoin join) {
    Vec2 a = p - prev;
    Vec2 b = next - p;
    float alen = a.length();
    float blen = b.length();
    if (alen < MIN_DIST || blen < MIN_DIST) return;

    Vec2 ad = a / alen;
    Vec2 bd = b / blen;
    float turn = ad.cross(bd);
    if (abs(turn) < MIN_DIST) return;

    // Unit left-hand normals of each edge direction
    Vec2 na = { -ad.y, ad.x };
    Vec2 nb = { -bd.y, bd.x };

    // side = -1 for left turn  → outer corner is on the RIGHT (-na direction)
    // side = +1 for right turn → outer corner is on the LEFT  (+na direction)
    float side = turn > 0 ? -1 : 1;

    // Outer corners of the two segment quads at point P
    Vec2 oa = na * (hw * side);
    Vec2 ob = nb * (hw * side);
    
    // Outer AA corners of the two segment quads
    Vec2 fa = na * ((hw + aa) * side);
    Vec2 fb = nb * ((hw + aa) * side);

    if (join == MITER) {
        Vec2 dm = na.half(nb);
        float dmr2 = dm.dot(dm);

        if (dmr2 > MIN_DIST) {
            float scale = 1 / dmr2;
            dm *= scale;
			float miterRatio = dm.length();
            if (miterRatio <= MITER_LIMIT) {
				Vec2 mp = p + dm * hw * side;
                self.pushTri(p + oa, p + ob, mp, color, alpha);

                // Miter AA
				Vec2 mpe = p + dm * (hw + aa) * side;
                self.pushQuadGradient(p + oa, mp, mpe, p + fa, color, alpha, 0);
                self.pushQuadGradient(mp, p + ob, p + fb, mpe, color, alpha, 0);
                
                self.pushTri(p, p + oa, p + ob, color, alpha);
                return;
            }
        }
    }

    // BEVEL (or miter fallback): fill the outer gap with a simple triangle.
    self.pushTri(p, p + oa, p + ob, color, alpha);
    
    // Bevel AA quad
    self.pushQuadGradient(p + oa, p + ob, p + fb, p + fa, color, alpha, 0);
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

        float side = pathArea(&pts[0], ptCount) > 0 ? -1 : 1;
        float aa = AA_SIZE / max(self.dpr, 1);

        for (int i = 0; i < ptCount; i++) {
            Vec2 a = pts[i];
            Vec2 b = pts[(i + 1) % ptCount];
            Vec2 n = edgeNormal(a, b, aa * side);
            if (n.x == 0 && n.y == 0) continue;

            self.pushQuadGradient(a, b, b + n, a + n, fc, alpha, 0);
        }

        sz n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }

    if (paint.hasLine) {
        float hw = paint.lineWidth * 0.5;
        float aa = AA_SIZE / max(self.dpr, 1);
        Color lc = paint.lineColor;
        sz offset = self.vertCount;
        int segs = path.closed ? ptCount : ptCount - 1;

        for (int i = 0; i < segs; i++) {
            Vec2 a = pts[i];
            Vec2 b = pts[(i + 1) % ptCount];
            Vec2 d = b - a;
            float len = d.length();
            if (len < MIN_DIST) continue;

            Vec2 n = { (-d.y / len) * hw, (d.x / len) * hw };
            Vec2 f = { (-d.y / len) * (hw + aa), (d.x / len) * (hw + aa) };

            self.pushQuad(a + n, a - n, b - n, b + n, lc, alpha);
            self.pushQuadGradient(a + n, b + n, b + f, a + f, lc, alpha, 0);
            self.pushQuadGradient(b - n, a - n, a - f, b - f, lc, alpha, 0);
        }

        int joinStart = path.closed ? 0 : 1;
        int joinEnd = path.closed ? ptCount : ptCount - 1;
        for (int i = joinStart; i < joinEnd; i++) {
            Vec2 prev = pts[(i + ptCount - 1) % ptCount];
            Vec2 p = pts[i];
            Vec2 next = pts[(i + 1) % ptCount];
            self.pushStrokeJoin(prev, p, next, lc, alpha, hw, aa, paint.lineJoin);
        }

        sz n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }
}
