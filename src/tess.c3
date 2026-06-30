module microvg;

import std::math;

const float AA_SIZE @private = 1;
const float MITER_LIMIT @private = 4;
const float MIN_DIST @private = 0.0001;
const float SNAP_LINE_WIDTH @private = 1.5;

// UV.x convention for antialiasing: the fragment shader fades alpha toward the
// stroke edges where u -> 0 or u -> 1. u == 0.5 is the solid core/centre line.
const Vec2 UV_LEFT   @private = { 0, 1 };   // outer-left fringe edge
const Vec2 UV_RIGHT  @private = { 1, 1 };   // outer-right fringe edge
const Vec2 UV_CORE   @private = { 0.5, 1 }; // solid interior (fill, centre)

// One precomputed vertex of a path: position, the direction of the edge that
// leaves it, and the averaged miter vector. Shared by fill fringe and stroke so
// the join geometry is only solved once.
struct StrokePoint {
    Vec2 pos;        // transformed position
    Vec2 dir;        // unit direction of the edge leaving this point
    Vec2 dm;         // averaged miter vector (length grows on sharp corners)
    float len;       // length of the edge leaving this point
    bool bevel;      // outer corner exceeds the miter limit -> needs a bevel
    bool innerBevel; // inner corner folds over -> handle inner separately
}

fn float pathArea(Vec2* pts, int count) {
    float area = 0;
    for (int i = 0; i < count; i++) {
        Vec2 a = pts[i];
        Vec2 b = pts[(i + 1) % count];
        area += a.cross(b);
    }

    return area;
}

fn bool pointInTri(Vec2 p, Vec2 a, Vec2 b, Vec2 c) {
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

fn float snapPos(float v, float dpr) => math::floor((v * dpr)) / dpr + 0.5f / dpr;

fn bool shouldSnapLine(Mat2x3 form, float lineWidth) {
    if (lineWidth > SNAP_LINE_WIDTH) return false;
    return abs(form.linear.y) < 0.0001 && abs(form.linear.z) < 0.0001;
}

// Build per-point miter/bevel data for the polyline. Mirrors nvg__calculateJoins:
// each point stores the averaged normal (dm) scaled so that p +/- dm*hw lands on
// the stroke edge, and flags whether the corner must be bevelled.
fn void buildPoints(Vec2* pts, int n, bool closed, float hw, StrokePoint* out) {
    // Edge directions and lengths first.
    int segs = closed ? n : n - 1;
    for (int i = 0; i < n; i++) {
        Vec2 a = pts[i];
        Vec2 b = pts[(i + 1) % n];
        Vec2 d = b - a;
        float len = d.length();
        out[i].pos = a;
        out[i].len = len;
        out[i].dir = len > MIN_DIST ? d / len : (Vec2) { 0, 0 };
        out[i].bevel = false;
        out[i].innerBevel = false;
    }
    // For an open path the last point keeps the previous direction.
    if (!closed && n >= 2) out[n - 1].dir = out[n - 2].dir;

    float miterLimit = MITER_LIMIT;
    float iw = hw > 0 ? 1.0f / hw : 0;
    for (int i = 0; i < n; i++) {
        // dir of the edge arriving at i (prev) and the edge leaving i.
        int prev = (i + n - 1) % n;
        Vec2 d0 = out[prev].dir;
        Vec2 d1 = out[i].dir;

        // Left normals of the two edges (nanovg convention: dl = (dy, -dx)).
        Vec2 dl0 = { d0.y, -d0.x };
        Vec2 dl1 = { d1.y, -d1.x };

        Vec2 dm = (dl0 + dl1) * 0.5f;
        float dmr2 = dm.dot(dm);
        if (dmr2 > 0.000001f) {
            float scale = 1.0f / dmr2;
            if (scale > 600.0f) scale = 600.0f;
            dm *= scale;
        }
        out[i].dm = dm;

        // Inner bevel: averaged miter longer than the shorter adjacent segment.
        float limit = max(1.01f, min(out[prev].len, out[i].len) * iw);
        if (dmr2 * limit * limit < 1.0f) out[i].innerBevel = true;

        // Outer bevel: miter exceeds the miter limit.
        if (dmr2 * miterLimit * miterLimit < 1.0f) out[i].bevel = true;
    }

    if (segs == 0) {} // silence unused on degenerate input
}

fn void MicroVG.pushPath(&self, Path path, Paint paint) {
    State* state = self.currentState();
    float alpha = state.alpha;

	bool snapLine = paint.hasLine && !paint.hasFill && shouldSnapLine(state.form, paint.lineWidth);
	float snapDpr = max(self.dpr, 1);
    Command* cmds = &self.cmds[path.start];
    Vec2[MAX_PATH_POINTS] pts;
    int ptCount = 0;

    for (int i = 0; i < path.count; i++) {
        if (cmds[i].type == CLOSE) continue;
        if (ptCount < MAX_PATH_POINTS) {
            Vec2 pt = state.form * cmds[i].pos;
            if (snapLine) pt = { snapPos(pt.x, snapDpr), snapPos(pt.y, snapDpr) };
            pts[ptCount++] = pt;
        }
    }

    if (ptCount < 2) return;

    float hw = max(paint.lineWidth * 0.5f, MIN_DIST);
    StrokePoint[MAX_PATH_POINTS] spts;
    buildPoints(&pts[0], ptCount, path.closed, hw, &spts[0]);

    if (paint.hasFill && path.closed && ptCount >= 3) {
        self.tessFill(&pts[0], &spts[0], ptCount, paint, alpha);
    }

    if (paint.hasLine) {
        self.expandStroke(&spts[0], ptCount, path.closed, paint, alpha);
    }
}
