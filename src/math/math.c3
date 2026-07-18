module microvg;

import std::math;

const float PI = 3.14159265358979323846264338327f;

const float KAPPA90 = 0.5522847493f;

macro float toRad(float deg) => deg / 180.0f * PI;

macro float toDeg(float rad) => rad / PI * 180.0f;

macro float float.sign(self) => self < 0 ? -1 : 1;

fn float normalize(float* x, float* y) {
	float d = math::sqrt(x[0] * x[0] + y[0] * y[0]);
	if (d > 1e-6f) {
		float id = 1.0f / d;
		x[0] *= id;
		y[0] *= id;
	}
	return d;
}

fn bool ptEquals(Vec2 a, Vec2 b, float tol) {
	Vec2 d = b - a;
	return d.dot(d) < tol * tol;
}

fn float distPtSeg(Vec2 p, Vec2 q0, Vec2 q1) {
	Vec2 pq = q1 - q0;
	Vec2 d = p - q0;
	float t = d.dot(pq);
	float dd = pq.dot(pq);
	if (dd > 0) t /= dd;
	if (t < 0) {
		t = 0;
	}
	else if (t > 1) {
		t = 1;
	}

	Vec2 r = q0 + pq * t - p;
	return r.dot(r);
}

fn Vec4 isectRect(
float ax, float ay, float aw, float ah,
float bx, float by, float bw, float bh
) {
	float minx = math::max(ax, bx);
	float miny = math::max(ay, by);
	float maxx = math::min(ax + aw, bx + bw);
	float maxy = math::min(ay + ah, by + bh);
	return { minx, miny, math::max(0.0f, maxx - minx), math::max(0.0f, maxy - miny) };
}

fn float triArea2(Vec2 a, Vec2 b, Vec2 c) => (c - a).cross(b - a);

fn float polyArea(Point* pts, int npts) {
	float area = 0;
	for (int i = 2; i < npts; i++) {
		Point* a = &pts[0];
		Point* b = &pts[i - 1];
		Point* c = &pts[i];
		area += triArea2(a.pos, b.pos, c.pos);
	}

	return area * 0.5f;
}

fn void polyReverse(Point* pts, int npts) {
	int i = 0;
	int j = npts - 1;
	while (i < j) {
		Point tmp = pts[i];
		pts[i] = pts[j];
		pts[j] = tmp;
		i++;
		j--;
	}
}

fn int curveDivs(float r, float arc, float tol) {
	float da = math::acos(r / (r + tol)) * 2.0f;
	return math::max(2, (int)math::ceil(arc / da));
}
