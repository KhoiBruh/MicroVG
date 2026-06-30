module microvg;

import std::math;

// Expand a polyline into a continuous antialiased triangle strip.
//
// Geometry follows nanovg's nvg__expandStroke (one strip walked along the path,
// averaged miter at smooth joins, bevels at sharp ones) with one improvement:
// at a bevel the inner side emits a single shared vertex instead of two, so the
// two adjacent segment bands meet on the inner edge without overlapping. That
// removes the inner overdraw nanovg leaves behind (visible when stroke alpha<1).
//
// Antialiasing is carried by UV.x (0..1 across the width); the fragment shader
// fades the outer fringe. The half-width therefore includes half the fringe so
// the opaque core matches lineWidth.
fn void MicroVG.expandStroke(&self, StrokePoint* pts, int n, bool closed, Paint paint, float alpha) {
    float aa = AA_SIZE / max(self.dpr, 1);
    Color lc = paint.lineColor;

    float strokeAlpha = alpha;
    float w = paint.lineWidth * 0.5f;
    // Thin strokes: keep a minimum drawable width and fade by coverage instead,
    // so sub-pixel lines stay visible and steady (nanovg's approach).
    if (paint.lineWidth < aa) {
        float a = math::clamp(paint.lineWidth / aa, 0.0f, 1.0f);
        strokeAlpha *= a * a;
        w = aa * 0.5f;
    }
    float hw = w + aa * 0.5f; // include the fringe in the geometric half-width

    int offset = self.vertCount;

    // Starting cap (open paths only).
    if (!closed) {
        self.strokeCapStart(&pts[0], pts[0].dir, hw, lc, strokeAlpha, paint.lineCap);
    }

    // Walk the points, emitting one strip column (a left/right vertex pair) per
    // point. Joins that exceed a limit emit an extra bevel column.
    int last = closed ? n : n - 1;
    StrokePoint* prev = &pts[(n - 1) % n];
    for (int k = 0; k <= last; k++) {
        int i = k % n;
        StrokePoint* p = &pts[i];

        // Interior joins only; endpoints of an open path get caps instead.
        bool isJoin = closed || (k > 0 && k < n - 1);
        // The closed seal (k == n) just repeats the first column.
        bool seal = closed && k == n;

        if (seal) {
            // Repeat the very first column verbatim to close the loop cleanly.
            Vertex v0 = self.verts[offset];
            Vertex v1 = self.verts[offset + 1];
            self.pushVert(v0.pos, v0.uv, lc, strokeAlpha);
            self.pushVert(v1.pos, v1.uv, lc, strokeAlpha);
        } else if (isJoin && (p.bevel || p.innerBevel)) {
            self.strokeBevel(prev, p, hw, lc, strokeAlpha);
        } else {
            self.pushVert(p.pos + p.dm * hw, UV_LEFT, lc, strokeAlpha);
            self.pushVert(p.pos - p.dm * hw, UV_RIGHT, lc, strokeAlpha);
        }
        prev = p;
    }

    // Ending cap (open paths only).
    if (!closed) {
        StrokePoint* end = &pts[n - 1];
        self.strokeCapEnd(end, end.dir, hw, lc, strokeAlpha, paint.lineCap);
    }

    int count = self.vertCount - offset;
    if (count > 0) self.pushCall(offset, count, TRIANGLE_STRIP);
}

// Bevel (or sharp miter) join, ported from nvg__bevelJoin.
//
// Convention: dl is the LEFT normal of a segment direction (dir.y, -dir.x).
// p0 is the incoming point (carries the arriving edge dir), p1 the corner.
// Outer side emits the two segment-edge points; inner side emits a single
// shared point (our zero-overdraw change) instead of nanovg's overlapping pair.
fn void MicroVG.strokeBevel(&self, StrokePoint* p0, StrokePoint* p1, float hw, Color c, float alpha) {
    Vec2 dl0 = { p0.dir.y, -p0.dir.x };
    Vec2 dl1 = { p1.dir.y, -p1.dir.x };
    Vec2 p = p1.pos;

    // Turn left when the averaged normal points the same way as the left normals.
    bool left = p0.dir.cross(p1.dir) < 0;

    if (left) {
        // Inner = left side (shared point, clamped miter); outer = right side.
        Vec2 inner = p + p1.dm * hw;          // shared inner miter point
        Vec2 o0 = p - dl0 * hw;               // outer, segment 0 edge
        Vec2 o1 = p - dl1 * hw;               // outer, segment 1 edge

        self.pushVert(inner, UV_LEFT, c, alpha);
        self.pushVert(o0, UV_RIGHT, c, alpha);
        self.pushVert(inner, UV_LEFT, c, alpha);
        self.pushVert(o1, UV_RIGHT, c, alpha);
    } else {
        // Inner = right side (shared point); outer = left side.
        Vec2 inner = p - p1.dm * hw;
        Vec2 o0 = p + dl0 * hw;
        Vec2 o1 = p + dl1 * hw;

        self.pushVert(o0, UV_LEFT, c, alpha);
        self.pushVert(inner, UV_RIGHT, c, alpha);
        self.pushVert(o1, UV_LEFT, c, alpha);
        self.pushVert(inner, UV_RIGHT, c, alpha);
    }
}

// Butt / square cap at the path start. Round cap deferred (treated as butt).
fn void MicroVG.strokeCapStart(&self, StrokePoint* p, Vec2 dir, float hw, Color c, float alpha, LineCap cap) {
    Vec2 nrm = { -dir.y, dir.x };
    Vec2 ext = (cap == SQUARE) ? dir * -hw : (Vec2) { 0, 0 };
    self.pushVert(p.pos + nrm * hw + ext, UV_LEFT, c, alpha);
    self.pushVert(p.pos - nrm * hw + ext, UV_RIGHT, c, alpha);
}

fn void MicroVG.strokeCapEnd(&self, StrokePoint* p, Vec2 dir, float hw, Color c, float alpha, LineCap cap) {
    Vec2 nrm = { -dir.y, dir.x };
    Vec2 ext = (cap == SQUARE) ? dir * hw : (Vec2) { 0, 0 };
    self.pushVert(p.pos + nrm * hw + ext, UV_LEFT, c, alpha);
    self.pushVert(p.pos - nrm * hw + ext, UV_RIGHT, c, alpha);
}
