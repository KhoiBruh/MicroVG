module microvg;

import std::math;

import microvg::path;
import microvg::state;
import microvg::vector;

fn int MicroVG.flattenPath(
	&self,
	Path p,
	Vec2f* points,
	int pointCap,
	Contour* contours,
	int contourCap
) {
	State* state = self.currentState();
	Vec2f pen = { 0, 0 };
	Vec2f start = { 0, 0 };
	int pointCount = 0;
	int contourCount = 0;
	int contourStart = 0;
	bool hasPen = false;
	bool closed = false;

	for (int i = 0; i < p.count; i++) {
		Cmd* cmd = &self.cmds.items[p.offset + i];

		switch (cmd.type) {
			case CmdType.MOVE:
				finishContour(contours, &contourCount, contourCap, contourStart, pointCount, closed);
				contourStart = pointCount;
				closed = false;

				pen = state.transform(cmd.args[0], cmd.args[1]);
				start = pen;
				appendPoint(points, &pointCount, pointCap, pen);
				hasPen = true;

			case CmdType.LINE:
				pen = state.transform(cmd.args[0], cmd.args[1]);
				appendPoint(points, &pointCount, pointCap, pen);

			case CmdType.QUAD:
				if (!hasPen) continue;
				flattenQuadCmd(state, points, &pointCount, pointCap, pen, cmd);
				pen = state.transform(cmd.args[2], cmd.args[3]);

			case CmdType.BEZIER:
				if (!hasPen) continue;
				flattenBezierCmd(state, points, &pointCount, pointCap, pen, cmd);
				pen = state.transform(cmd.args[4], cmd.args[5]);

			case CmdType.ARC:
				if (!hasPen) continue;
				flattenArcToCmd(state, points, &pointCount, pointCap, pen, cmd);
				pen = state.transform(cmd.args[2], cmd.args[3]);

			case CmdType.CLOSE:
				if (!hasPen) continue;

				appendPoint(points, &pointCount, pointCap, start);
				closed = true;
		}
	}

	finishContour(contours, &contourCount, contourCap, contourStart, pointCount, closed);

	return contourCount;
}

fn void finishContour(Contour* contours, int* count, int cap, int offset, int pointCount, bool closed) {
	int len = pointCount - offset;
	if (len < 2 || *count >= cap) return;

	contours[*count] = { .offset = offset, .count = len, .closed = closed };
	*count += 1;
}

fn void flattenBezierCmd(State* state, Vec2f* points, int* count, int cap, Vec2f pen, Cmd* cmd) {
	Vec2f c1 = state.transform(cmd.args[0], cmd.args[1]);
	Vec2f c2 = state.transform(cmd.args[2], cmd.args[3]);
	Vec2f to = state.transform(cmd.args[4], cmd.args[5]);

	flattenBezier(points, count, cap, pen, c1, c2, to, 0);
}

fn void flattenQuadCmd(State* state, Vec2f* points, int* count, int cap, Vec2f pen, Cmd* cmd) {
	Vec2f control = state.transform(cmd.args[0], cmd.args[1]);
	Vec2f to = state.transform(cmd.args[2], cmd.args[3]);
	Vec2f c1 = pen + (control - pen) * 0.6666667f;
	Vec2f c2 = to + (control - to) * 0.6666667f;

	flattenBezier(points, count, cap, pen, c1, c2, to, 0);
}

fn void flattenArcToCmd(State* state, Vec2f* points, int* count, int cap, Vec2f pen, Cmd* cmd) {
	Vec2f p1 = state.transform(cmd.args[0], cmd.args[1]);
	Vec2f p2 = state.transform(cmd.args[2], cmd.args[3]);
	float radius = cmd.args[4] * state.maxScale();

	if (radius <= 0 || pen.dist(p1) <= POINT_EPSILON || p1.dist(p2) <= POINT_EPSILON) {
		appendPoint(points, count, cap, p1);
		return;
	}

	Vec2f d0 = (pen - p1) / pen.dist(p1);
	Vec2f d1 = (p2 - p1) / p1.dist(p2);
	float cosAngle = math::clamp(d0.dot(d1), -1.0f, 1.0f);
	float angle = math::acos(cosAngle);
	if (angle <= POINT_EPSILON || math::abs(PI - angle) <= POINT_EPSILON) {
		appendPoint(points, count, cap, p1);
		return;
	}

	float tangent = radius / math::tan(angle * 0.5f);
	float maxTangent = math::min(pen.dist(p1), p1.dist(p2));
	if (tangent > maxTangent) tangent = maxTangent;

	float actualRadius = tangent * math::tan(angle * 0.5f);
	Vec2f t0 = p1 + d0 * tangent;
	Vec2f t1 = p1 + d1 * tangent;
	Vec2f bisector = (d0 + d1) / (d0 + d1).length();
	Vec2f center = p1 + bisector * (actualRadius / math::sin(angle * 0.5f));

	appendPoint(points, count, cap, t0);
	flattenArc(points, count, cap, center, t0, t1, d0.x * d1.y - d0.y * d1.x > 0);
}

fn void flattenArc(Vec2f* points, int* count, int cap, Vec2f center, Vec2f from, Vec2f to, bool clockwise) {
	float radius = center.dist(from);
	if (radius <= POINT_EPSILON) return;

	float a0 = math::atan2(from.y - center.y, from.x - center.x);
	float a1 = math::atan2(to.y - center.y, to.x - center.x);
	float da = a1 - a0;

	if (clockwise && da > 0) da -= PI * 2.0f;
	if (!clockwise && da < 0) da += PI * 2.0f;

	int steps = (int) math::ceil(math::abs(da) * radius / 8.0f);
	if (steps < 2) steps = 2;
	if (steps > 64) steps = 64;

	for (int i = 1; i <= steps; i++) {
		float t = (float) i / (float) steps;
		float a = a0 + da * t;
		Vec2f p = {
			center.x + math::cos(a) * radius,
			center.y + math::sin(a) * radius
		};

		appendPoint(points, count, cap, p);
	}
}

fn void appendPoint(Vec2f* points, int* count, int cap, Vec2f p) {
	if (*count >= cap) return;
	if (*count > 0 && points[*count - 1].dist(p) <= POINT_EPSILON) return;

	points[*count] = p;
	*count += 1;
}

fn void flattenBezier(
	Vec2f* points,
	int* count,
	int cap,
	Vec2f p0,
	Vec2f p1,
	Vec2f p2,
	Vec2f p3,
	int level
) {
	float d1 = p1.lineDist(p0, p3);
	float d2 = p2.lineDist(p0, p3);

	if ((d1 + d2) * (d1 + d2) <= CURVE_TOLERANCE || level >= 10) {
		appendPoint(points, count, cap, p3);
		return;
	}

	Vec2f p01 = p0.halfOf(p1);
	Vec2f p12 = p1.halfOf(p2);
	Vec2f p23 = p2.halfOf(p3);
	Vec2f p012 = p01.halfOf(p12);
	Vec2f p123 = p12.halfOf(p23);
	Vec2f p0123 = p012.halfOf(p123);

	flattenBezier(points, count, cap, p0, p01, p012, p0123, level + 1);
	flattenBezier(points, count, cap, p0123, p123, p23, p3, level + 1);
}
