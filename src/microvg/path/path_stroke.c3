module microvg;

import std::math;

import microvg::color;
import microvg::paint;
import microvg::vector;

struct StrokeSegment {
	Vec2f a;
	Vec2f b;
	Vec2f dir;
	Vec2f normal;
}

struct StrokeOffsets {
	Vec2f left;
	Vec2f right;
}

fn void MicroVG.strokePath(
	&self,
	Vec2f* points,
	int count,
	bool closed,
	float width,
	LineCap cap,
	LineJoin join,
	float miterLimit,
	Color color
) {
	if (count < 2 || width <= 0 || color.a <= 0) return;

	int pointCount = closed ? count - 1 : count;
	if (pointCount < 2) return;

	int segmentCount = closed ? pointCount : pointCount - 1;
	if (segmentCount <= 0 || segmentCount > PATH_POINT_CAP) return;

	StrokeSegment[PATH_POINT_CAP] segments;
	int validSegments = buildStrokeSegments(points, pointCount, closed, &segments[0], segmentCount);
	if (validSegments <= 0) return;

	int offset = self.vertices.count;
	float half = width * 0.5f;
	float limit = math::max(miterLimit, 1.0f);

	for (int i = 0; i < validSegments; i++) {
		StrokeSegment s = segments[i];
		StrokeOffsets start = strokeBodyOffsets(&segments[0], validSegments, i, true, closed, half, limit, join);
		StrokeOffsets end = strokeBodyOffsets(&segments[0], validSegments, i, false, closed, half, limit, join);
		self.pushStrokeQuad(s.a + start.left, s.a - start.right, s.b - end.right, s.b + end.left);
	}

	if (closed) {
		for (int i = 0; i < validSegments; i++) {
			int prev = i - 1;
			if (prev < 0) prev = validSegments - 1;
			self.pushStrokeJoin(segments[i].a, segments[prev], segments[i], half, join, limit);
		}
	} else {
		self.pushStrokeCap(segments[0].a, segments[0].dir * -1.0f, segments[0].normal, half, cap);
		for (int i = 1; i < validSegments; i++) {
			self.pushStrokeJoin(segments[i].a, segments[i - 1], segments[i], half, join, limit);
		}
		self.pushStrokeCap(segments[validSegments - 1].b, segments[validSegments - 1].dir, segments[validSegments - 1].normal, half, cap);
	}

	self.pushCall(offset, self.vertices.count - offset, color);
}

fn StrokeOffsets strokeBodyOffsets(StrokeSegment* segments, int count, int index, bool start, bool closed, float half, float miterLimit, LineJoin join) {
	StrokeSegment current = segments[index];
	StrokeOffsets offsets = {
		.left = current.normal * half,
		.right = current.normal * half
	};

	if (!closed && start && index == 0) return offsets;
	if (!closed && !start && index == count - 1) return offsets;

	int prevIndex = start ? index - 1 : index;
	int nextIndex = start ? index : index + 1;
	if (prevIndex < 0) prevIndex = count - 1;
	if (nextIndex >= count) nextIndex = 0;

	Vec2f n0 = segments[prevIndex].normal;
	Vec2f n1 = segments[nextIndex].normal;
	Vec2f miter = n0 + n1;
	float len = miter.length();
	if (len <= POINT_EPSILON) return offsets;

	miter = miter / len;
	float denom = miter.dot(n1);
	if (math::abs(denom) <= CURVE_TOLERANCE) return offsets;

	float scale = half / denom;
	float maxScale = half * miterLimit;
	if (math::abs(scale) > maxScale) scale = scale < 0 ? -maxScale : maxScale;
	Vec2f miterOffset = miter * scale;

	if (join != LineJoin.MITER) {
		float turn = segments[prevIndex].dir.x * segments[nextIndex].dir.y - segments[prevIndex].dir.y * segments[nextIndex].dir.x;
		if (isSmoothStrokeTurn(segments[prevIndex], segments[nextIndex], half, turn)) {
			offsets.left = miterOffset;
			offsets.right = miterOffset;
		}

		return offsets;
	}

	offsets.left = miterOffset;
	offsets.right = miterOffset;
	return offsets;
}

fn int buildStrokeSegments(Vec2f* points, int pointCount, bool closed, StrokeSegment* segments, int cap) {
	int count = 0;
	int end = closed ? pointCount : pointCount - 1;

	for (int i = 0; i < end && count < cap; i++) {
		int next = i + 1;
		if (next >= pointCount) next = 0;

		Vec2f a = points[i];
		Vec2f b = points[next];
		Vec2f d = b - a;
		float len = d.length();
		if (len <= POINT_EPSILON) continue;

		Vec2f dir = d / len;
		segments[count] = {
			.a = a,
			.b = b,
			.dir = dir,
			.normal = { -dir.y, dir.x }
		};
		count += 1;
	}

	return count;
}

fn bool isSmoothStrokeTurn(StrokeSegment prev, StrokeSegment next, float half, float turn) {
	if (math::abs(turn) <= STROKE_JOIN_EPSILON) return true;

	float dot = prev.dir.dot(next.dir);
	if (dot < 0.0f) return false;

	float arcError = half * (1.0f - dot);
	return arcError <= 0.25f;
}

fn void MicroVG.pushStrokeQuad(&self, Vec2f a, Vec2f b, Vec2f c, Vec2f d) {
	self.pushVertex(a);
	self.pushVertex(b);
	self.pushVertex(c);
	self.pushVertex(a);
	self.pushVertex(c);
	self.pushVertex(d);
}

fn void MicroVG.pushStrokeJoin(&self, Vec2f p, StrokeSegment prev, StrokeSegment next, float half, LineJoin join, float miterLimit) {
	float turn = prev.dir.x * next.dir.y - prev.dir.y * next.dir.x;
	if (isSmoothStrokeTurn(prev, next, half, turn)) return;

	Vec2f a;
	Vec2f b;
	if (turn > 0) {
		a = p - prev.normal * half;
		b = p - next.normal * half;
	} else {
		a = p + prev.normal * half;
		b = p + next.normal * half;
	}

	if (join == LineJoin.ROUND) {
		self.pushRoundFan(p, a, b, half, turn < 0);
		return;
	}

	if (join == LineJoin.MITER) {
		Vec2f miter;
		float side = turn > 0 ? -1.0f : 1.0f;
		if (lineIntersection(p + prev.normal * half * side, prev.dir, p + next.normal * half * side, next.dir, &miter)) {
			if (p.dist(miter) <= half * miterLimit) {
				self.pushVertex(p);
				self.pushVertex(a);
				self.pushVertex(miter);
				self.pushVertex(p);
				self.pushVertex(miter);
				self.pushVertex(b);
				return;
			}
		}
	}

	self.pushVertex(p);
	self.pushVertex(a);
	self.pushVertex(b);
}

fn void MicroVG.pushStrokeCap(&self, Vec2f p, Vec2f dir, Vec2f normal, float half, LineCap cap) {
	if (cap == LineCap.BUTT) return;

	Vec2f left = p + normal * half;
	Vec2f right = p - normal * half;

	if (cap == LineCap.SQUARE) {
		Vec2f end = dir * half;
		self.pushStrokeQuad(left, right, right + end, left + end);
		return;
	}

	self.pushRoundCap(p, dir, half);
}

fn void MicroVG.pushRoundCap(&self, Vec2f center, Vec2f dir, float radius) {
	float mid = math::atan2(dir.y, dir.x);
	float a0 = mid - PI * 0.5f;
	float a1 = mid + PI * 0.5f;
	int steps = (int) math::ceil(PI * radius / 4.0f);
	if (steps < 4) steps = 4;
	if (steps > ROUND_STROKE_MAX_STEPS) steps = ROUND_STROKE_MAX_STEPS;

	Vec2f prev = {
		center.x + math::cos(a0) * radius,
		center.y + math::sin(a0) * radius
	};

	for (int i = 1; i <= steps; i++) {
		float t = (float) i / (float) steps;
		float a = a0 + (a1 - a0) * t;
		Vec2f next = {
			center.x + math::cos(a) * radius,
			center.y + math::sin(a) * radius
		};

		self.pushVertex(center);
		self.pushVertex(prev);
		self.pushVertex(next);
		prev = next;
	}
}

fn void MicroVG.pushRoundFan(&self, Vec2f center, Vec2f from, Vec2f to, float radius, bool clockwise) {
	float a0 = math::atan2(from.y - center.y, from.x - center.x);
	float a1 = math::atan2(to.y - center.y, to.x - center.x);
	float da = a1 - a0;

	if (clockwise && da > 0) da -= PI * 2.0f;
	if (!clockwise && da < 0) da += PI * 2.0f;

	int steps = (int) math::ceil(math::abs(da) * radius / 4.0f);
	if (steps < 2) steps = 2;
	if (steps > ROUND_STROKE_MAX_STEPS) steps = ROUND_STROKE_MAX_STEPS;

	Vec2f prev = from;
	for (int i = 1; i <= steps; i++) {
		float t = (float) i / (float) steps;
		float a = a0 + da * t;
		Vec2f next = {
			center.x + math::cos(a) * radius,
			center.y + math::sin(a) * radius
		};

		self.pushVertex(center);
		self.pushVertex(prev);
		self.pushVertex(next);
		prev = next;
	}
}

fn bool lineIntersection(Vec2f p, Vec2f r, Vec2f q, Vec2f s, Vec2f* out) {
	float cross = r.x * s.y - r.y * s.x;
	if (math::abs(cross) <= POINT_EPSILON) return false;

	Vec2f qp = q - p;
	float t = (qp.x * s.y - qp.y * s.x) / cross;
	*out = p + r * t;
	return true;
}
