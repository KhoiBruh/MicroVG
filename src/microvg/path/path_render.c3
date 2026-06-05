module microvg;

import microvg::color;
import microvg::paint;
import microvg::path;
import microvg::state;
import microvg::vector;

const int PATH_POINT_CAP = 2048;
const int PATH_CONTOUR_CAP = 128;
const float CURVE_TOLERANCE = 0.25;
const float POINT_EPSILON = 0.0001;
const float STROKE_JOIN_EPSILON = 0.015;
const float PI = 3.14159265;
const int ROUND_STROKE_MAX_STEPS = 32;

struct Contour {
	int offset;
	int count;
	int winding;
	bool closed;
}

fn void MicroVG.drawPath(&self, Path p, Paint paint) {
	if (p.vg != self || paint.vg != self) return;
	if (p.count == 0) return;

	Vec2f[PATH_POINT_CAP] points;
	Contour[PATH_CONTOUR_CAP] contours;
	int contourCount = self.flattenPath(p, &points[0], PATH_POINT_CAP, &contours[0], PATH_CONTOUR_CAP);
	if (contourCount <= 0) return;

	State* state = self.currentState();
	float scale = state.maxScale();
	float fringe = self.aa.fringe / (scale <= 0 ? 1.0f : scale);

	if (paint.hasFill) self.fillPath(&points[0], &contours[0], contourCount, paint.fillRule, applyAlpha(paint.fillCol, state.alpha), fringe);

	for (int i = 0; i < contourCount; i++) {
		Contour contour = contours[i];
		Vec2f* contourPoints = &points[contour.offset];

		if (paint.hasStroke) {
			self.strokePath(
				contourPoints,
				contour.count,
				contour.closed,
				paint.strokeW * scale,
				paint.lineCap,
				paint.lineJoin,
				paint.miterLimit,
				applyAlpha(paint.strokeCol, state.alpha),
				fringe
			);
		}
	}
}

fn Color applyAlpha(Color color, float alpha) => color.alpha(color.a * alpha);
