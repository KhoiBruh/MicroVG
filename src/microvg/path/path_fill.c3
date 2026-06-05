module microvg;

import microvg::color;
import microvg::paint;
import microvg::vector;

import std::math;

fn void MicroVG.fillPath(&self, Vec2f* points, Contour* contours, int contourCount, FillRule rule, Color color, float fringe) {
	if (contourCount <= 0 || color.a <= 0) return;

	int offset = self.vertices.count;
	Vec2f min = { 0, 0 };
	Vec2f max = { 0, 0 };
	bool hasBounds = false;
	bool hasTriangles = false;

	for (int i = 0; i < contourCount; i++) {
		Contour* contour = &contours[i];
		int count = pointCount(contour);
		if (count < 3) continue;

		contour.winding = polyWind(&points[contour.offset], count);
		if (contour.winding == 0) continue;
		contourBounds(&points[contour.offset], count, &min, &max, &hasBounds);
		if (self.tessContour(&points[contour.offset], count, contour.winding)) hasTriangles = true;
	}

	if (!hasBounds || !hasTriangles) return;

	int coverOffset = self.vertices.count;
	self.coverQuad(min, max);
	self.pushFillCall(offset, coverOffset - offset, color, rule, coverOffset, self.vertices.count - coverOffset);

	if (fringe <= 0) return;

	int fringeOffset = self.vertices.count;
	for (int i = 0; i < contourCount; i++) {
		Contour* contour = &contours[i];
		int count = pointCount(contour);
		if (count < 3 || contour.winding == 0) continue;
		self.fillFringe(&points[contour.offset], count, contour.winding, fringe);
	}

	int fringeCount = self.vertices.count - fringeOffset;
	if (fringeCount > 0) self.pushCall(fringeOffset, fringeCount, color);
}

// Emit an outward-fading band along the contour edge: inner vertices at full
// coverage (overlapping the solid stencil fill), outer vertices at zero coverage.
fn void MicroVG.fillFringe(&self, Vec2f* points, int count, int winding, float fringe) {
	// Outward normal sign: for positive signed area (winding > 0) the right-hand
	// normal { dir.y, -dir.x } points outward; flip for the opposite winding.
	float side = winding > 0 ? 1.0f : -1.0f;
	Vec2f[PATH_POINT_CAP] outer;

	for (int i = 0; i < count; i++) {
		Vec2f p = points[i];
		Vec2f prev = points[i == 0 ? count - 1 : i - 1];
		Vec2f next = points[(i + 1) % count];
		Vec2f d0 = p - prev;
		Vec2f d1 = next - p;
		float len0 = d0.length();
		float len1 = d1.length();
		if (len0 <= POINT_EPSILON || len1 <= POINT_EPSILON) {
			outer[i] = p;
			continue;
		}

		Vec2f dir0 = d0 / len0;
		Vec2f dir1 = d1 / len1;
		Vec2f n0 = { dir0.y * side, -dir0.x * side };
		Vec2f n1 = { dir1.y * side, -dir1.x * side };
		Vec2f miter = n0 + n1;
		float miterLen = miter.length();
		if (miterLen <= POINT_EPSILON) {
			outer[i] = p + n1 * fringe;
			continue;
		}

		miter = miter / miterLen;
		float denom = miter.dot(n1);
		if (math::abs(denom) <= POINT_EPSILON) {
			outer[i] = p + n1 * fringe;
			continue;
		}

		float scale = fringe / denom;
		float maxScale = fringe * 4.0f;
		if (math::abs(scale) > maxScale) scale = scale < 0 ? -maxScale : maxScale;
		outer[i] = p + miter * scale;
	}

	for (int i = 0; i < count; i++) {
		int next = (i + 1) % count;
		self.pushFringeQuad(points[i], points[next], outer[next], outer[i]);
	}
}

// Two triangles for a fringe quad: inner edge (innerA, innerB) at coverage 1,
// outer edge (outerB, outerA) at coverage 0.
fn void MicroVG.pushFringeQuad(&self, Vec2f innerA, Vec2f innerB, Vec2f outerB, Vec2f outerA) {
	self.pushAA(innerA, 1.0f);
	self.pushAA(innerB, 1.0f);
	self.pushAA(outerB, 0.0f);

	self.pushAA(innerA, 1.0f);
	self.pushAA(outerB, 0.0f);
	self.pushAA(outerA, 0.0f);
}

fn int pointCount(Contour* contour) {
	if (contour.closed && contour.count > 1) return contour.count - 1;
	return contour.count;
}

fn int polyWind(Vec2f* points, int count) {
	float value = area(points, count);
	if (value > POINT_EPSILON) return 1;
	if (value < -POINT_EPSILON) return -1;
	return 0;
}

fn float area(Vec2f* points, int count) {
	float value = 0;
	for (int i = 0; i < count; i++) {
		Vec2f a = points[i];
		Vec2f b = points[(i + 1) % count];
		value += a.x * b.y - b.x * a.y;
	}

	return value * 0.5f;
}

fn void contourBounds(Vec2f* points, int count, Vec2f* min, Vec2f* max, bool* hasBounds) {
	for (int i = 0; i < count; i++) {
		Vec2f p = points[i];
		if (!*hasBounds) {
			*min = p;
			*max = p;
			*hasBounds = true;
			continue;
		}

		if (p.x < min.x) min.x = p.x;
		if (p.y < min.y) min.y = p.y;
		if (p.x > max.x) max.x = p.x;
		if (p.y > max.y) max.y = p.y;
	}
}

fn void MicroVG.coverQuad(&self, Vec2f min, Vec2f max) {
	self.pushVertex({ min.x, min.y });
	self.pushVertex({ max.x, min.y });
	self.pushVertex({ max.x, max.y });

	self.pushVertex({ min.x, min.y });
	self.pushVertex({ max.x, max.y });
	self.pushVertex({ min.x, max.y });
}
