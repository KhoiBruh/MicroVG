module microvg;

import std::math;

const float AA_SIZE @private = 1;
const float MITER_LIMIT @private = 4;
const float MIN_DIST @private = 0.0001;
const float SNAP_LINE_WIDTH @private = 1.5;

fn float pathArea(Vec2* pts, int count) {
    float area = 0;
    for (int i = 0; i < count; i++) {
        Vec2 a = pts[i];
        Vec2 b = pts[(i + 1) % count];
        area += a.cross(b);
    }

    return area;
}

fn bool pointInTriangle(Vec2 p, Vec2 a, Vec2 b, Vec2 c) {
    Vec2 v0 = c - a;
    Vec2 v1 = b - a;
    Vec2 v2 = p - a;

    float dot00 = v0.dot(v0);
    float dot01 = v0.dot(v1);
    float dot02 = v0.dot(v2);
    float dot11 = v1.dot(v1);
    float dot12 = v1.dot(v2);

    float invDenom = 1 / (dot00 * dot11 - dot01 * dot01);
    float u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    float v = (dot00 * dot12 - dot01 * dot02) * invDenom;

    return (u >= 0) && (v >= 0) && (u + v < 1);
}

fn Vec2 edgeNormal(Vec2 a, Vec2 b, float scale) {
    Vec2 d = b - a;
    float len = d.length();
    if (len < MIN_DIST) return { 0, 0 };

    return { (-d.y / len) * scale, (d.x / len) * scale };
}

fn float snapCoord(float v, float dpr) => math::floor((v * dpr)) / dpr + 0.5f / dpr;

fn bool shouldSnapStroke(Mat2x3 form, float lineWidth) {
    if (lineWidth > SNAP_LINE_WIDTH) return false;
    return abs(form.linear.y) < 0.0001 && abs(form.linear.z) < 0.0001;
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

fn void MicroVG.pushLineCap(&self, Vec2 p, Vec2 dir, float hw, float aa, Color color, float alpha, LineCap cap) {
    if (cap == ROUND) {
        return;
    }

    Vec2 n = { -dir.y, dir.x };
    
    float extLen = (cap == SQUARE) ? hw : 0;
    Vec2 ext = dir * extLen;
    Vec2 eAA = dir * aa;

    Vec2 left = n * hw;
    Vec2 right = -n * hw;
    Vec2 fLeft = n * (hw + aa);
    Vec2 fRight = -n * (hw + aa);

    Vec2 p0 = p;
    Vec2 p1 = p + ext;

    if (cap == SQUARE) {
        self.pushQuad(p0 + left, p0 + right, p1 + right, p1 + left, color, alpha);
        
        self.pushQuadGradient(p0 + left, p1 + left, p1 + fLeft, p0 + fLeft, color, alpha, 0);
        self.pushQuadGradient(p0 + right, p1 + right, p1 + fRight, p0 + fRight, color, alpha, 0);
    }

    self.pushQuadGradient(p1 + left, p1 + right, p1 + right + eAA, p1 + left + eAA, color, alpha, 0);

    self.pushVert(p1 + left, color, alpha);
    self.pushVert(p1 + left + eAA, color, 0);
    self.pushVert(p1 + fLeft, color, 0);
    
    self.pushVert(p1 + right, color, alpha);
    self.pushVert(p1 + right + eAA, color, 0);
    self.pushVert(p1 + fRight, color, 0);
}

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

fn void MicroVG.pushVert(&self, Vec2 pos, Color c, float a) {
    if (self.vertCount >= self.vertCap) {
        int newCap = self.vertCap * 2;
        Vertex* buf = mem::calloc(newCap * Vertex::size);
        for (int i = 0; i < self.vertCount; i++) buf[i] = self.verts[i];

        mem::free(self.verts);
        self.verts = buf;
        self.vertCap = newCap;
    }

    self.verts[self.vertCount++] = { pos, c.alpha(a) };
}

fn void MicroVG.pushCall(&self, int offset, int count) {
    if (self.callCount >= self.callCap) {
        int newCap = self.callCap * 2;
        DrawCall* buf = mem::calloc(newCap * DrawCall::size);
        for (int i = 0; i < self.callCount; i++) buf[i] = self.calls[i];

        mem::free(self.calls);
        self.calls = buf;
        self.callCap = newCap;
    }

    self.calls[self.callCount++] = { offset, count };
}

fn void MicroVG.pushPath(&self, Path path, Paint paint) {
    State* state = self.currentState();
    float alpha = state.alpha;

	bool snapStroke = paint.hasLine && !paint.hasFill && shouldSnapStroke(state.form, paint.lineWidth);
	float snapDpr = max(self.dpr, 1);
    Command* cmds = &self.cmds[path.start];
    Vec2[MAX_PATH_POINTS] pts;
    int ptCount = 0;

    for (int i = 0; i < path.count; i++) {
        if (cmds[i].type == CLOSE) continue;
        if (ptCount < MAX_PATH_POINTS) {
            Vec2 pt = state.form * cmds[i].pos;
            if (snapStroke) pt = { snapCoord(pt.x, snapDpr), snapCoord(pt.y, snapDpr) };
            pts[ptCount++] = pt;
        }
    }

    if (ptCount < 2) return;

    if (paint.hasFill && path.closed && ptCount >= 3) {
        int offset = self.vertCount;
        Color fc = paint.fillColor;
        bool ccw = pathArea(&pts[0], ptCount) > 0;
        float side = ccw ? -1 : 1;

        int[MAX_PATH_POINTS] indices;
        for (int i = 0; i < ptCount; i++) indices[i] = i;

        int remain = ptCount;
        while (remain > 2) {
            bool earFound = false;
            for (int i = 0; i < remain; i++) {
                int prev = indices[(i + remain - 1) % remain];
                int curr = indices[i];
                int next = indices[(i + 1) % remain];

                Vec2 a = pts[prev];
                Vec2 b = pts[curr];
                Vec2 c = pts[next];

                // Check if internal angle is convex based on path winding
                float cross = (b - a).cross(c - b);
                if (ccw ? cross < MIN_DIST : cross > -MIN_DIST) continue;

                // Check if any other point is inside this triangle
                bool isEar = true;
                for (int j = 0; j < remain; j++) {
                    int idx = indices[j];
                    if (idx == prev || idx == curr || idx == next) continue;
                    if (pointInTriangle(pts[idx], a, b, c)) {
                        isEar = false;
                        break;
                    }
                }

                if (isEar) {
                    self.pushTri(a, b, c, fc, alpha);
                    for (int j = i; j < remain - 1; j++) indices[j] = indices[j + 1];
                    remain--;
                    earFound = true;
                    break;
                }
            }
            
            if (!earFound) {
                // Fallback for self-intersecting or complex polygons: just strip an ear.
                self.pushTri(pts[indices[0]], pts[indices[1]], pts[indices[2]], fc, alpha);
                for (int j = 1; j < remain - 1; j++) indices[j] = indices[j + 1];
                remain--;
            }
        }

        float aa = AA_SIZE / max(self.dpr, 1);

        for (int i = 0; i < ptCount; i++) {
            Vec2 a = pts[i];
            Vec2 b = pts[(i + 1) % ptCount];
            Vec2 n = edgeNormal(a, b, aa * side);
            if (n.x == 0 && n.y == 0) continue;

            self.pushQuadGradient(a, b, b + n, a + n, fc, alpha, 0);
        }

        int n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }

    if (paint.hasLine) {
        float hw = paint.lineWidth * 0.5;
        float aa = AA_SIZE / max(self.dpr, 1);
        Color lc = paint.lineColor;
        int offset = self.vertCount;
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

        if (!path.closed && ptCount >= 2) {
            Vec2 p0 = pts[0];
            Vec2 p1 = pts[1];
            Vec2 d0 = p1 - p0;
            float len0 = d0.length();
            if (len0 >= MIN_DIST) self.pushLineCap(p0, -(d0 / len0), hw, aa, lc, alpha, paint.lineCap);

            Vec2 pEnd = pts[ptCount - 1];
            Vec2 pPrev = pts[ptCount - 2];
            Vec2 dEnd = pEnd - pPrev;
            float lenEnd = dEnd.length();
            if (lenEnd >= MIN_DIST) self.pushLineCap(pEnd, dEnd / lenEnd, hw, aa, lc, alpha, paint.lineCap);
        }

        int n = self.vertCount - offset;
        if (n > 0) self.pushCall(offset, n);
    }
}
