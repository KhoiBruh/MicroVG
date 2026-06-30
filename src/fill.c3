module microvg;

import std::math;

// Convex/simple polygon fill via ear clipping, plus an antialiased fringe built
// from the shared StrokePoint data so the fringe stays tight at corners.
fn void MicroVG.tessFill(&self, Vec2* pts, StrokePoint* spts, int ptCount, Paint paint, float alpha) {
    int offset = self.vertCount;
    Color fc = paint.fillColor;
    bool ccw = pathArea(pts, ptCount) > 0;

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

            float cross = (b - a).cross(c - b);
            if (ccw ? cross < MIN_DIST : cross > -MIN_DIST) continue;

            bool isEar = true;
            for (int j = 0; j < remain; j++) {
                int idx = indices[j];
                if (idx == prev || idx == curr || idx == next) continue;
                if (pointInTri(pts[idx], a, b, c)) {
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
            self.pushTri(pts[indices[0]], pts[indices[1]], pts[indices[2]], fc, alpha);
            for (int j = 1; j < remain - 1; j++) indices[j] = indices[j + 1];
            remain--;
        }
    }

    // Antialiased fringe: a thin band of width aa around the outline, using the
    // shared miter vectors so adjacent edges meet cleanly at corners.
    float aa = AA_SIZE / max(self.dpr, 1);
    float side = ccw ? -1 : 1;
    for (int i = 0; i < ptCount; i++) {
        int next = (i + 1) % ptCount;
        Vec2 a = pts[i];
        Vec2 b = pts[next];
        Vec2 oa = a + spts[i].dm * (aa * side);
        Vec2 ob = b + spts[next].dm * (aa * side);
        // Inner edge solid (u=0.5), outer edge faded (u=0).
        self.pushVertTri(a, U_CORE, b, U_CORE, ob, U_LEFT, fc, alpha);
        self.pushVertTri(a, U_CORE, ob, U_LEFT, oa, U_LEFT, fc, alpha);
    }

    int n = self.vertCount - offset;
    if (n > 0) self.pushCall(offset, n, TRIANGLES);
}
