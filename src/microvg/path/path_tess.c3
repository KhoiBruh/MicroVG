module microvg;

import std::math;

import microvg::vector;

fn bool MicroVG.tessContour(&self, Vec2f* points, int count, int winding) {
	if (count < 3) return false;

	Vec2f[PATH_POINT_CAP] clean;
	int cleanCount = cleanContour(points, count, &clean[0]);
	if (cleanCount < 3) return false;

	points = &clean[0];
	count = cleanCount;
	winding = polyWind(points, count);
	if (winding == 0) return false;

	if (count == 3) {
		self.pushVertex(points[0]);
		self.pushVertex(points[1]);
		self.pushVertex(points[2]);
		return true;
	}

	int offset = self.vertices.count;

	int[PATH_POINT_CAP] indices;
	for (int i = 0; i < count; i++) indices[i] = i;

	int remaining = count;
	int guard = count * count;

	while (remaining > 3 && guard > 0) {
		bool clipped = false;

		int wind = indexedWind(points, &indices[0], remaining);
		if (wind == 0) break;

		for (int i = 0; i < remaining; i++) {
			int prevIndex = indices[(i + remaining - 1) % remaining];
			int currIndex = indices[i];
			int nextIndex = indices[(i + 1) % remaining];

			if (!isEar(points, &indices[0], remaining, prevIndex, currIndex, nextIndex, wind)) continue;

			self.pushVertex(points[prevIndex]);
			self.pushVertex(points[currIndex]);
			self.pushVertex(points[nextIndex]);

			for (int j = i; j < remaining - 1; j++) indices[j] = indices[j + 1];
			remaining--;
			clipped = true;
			break;
		}

		if (!clipped) break;
		guard--;
	}

	if (remaining == 3) {
		self.pushVertex(points[indices[0]]);
		self.pushVertex(points[indices[1]]);
		self.pushVertex(points[indices[2]]);
		return true;
	}

	self.vertices.count = offset;
	self.tessFails++;
	return false;
}

fn int indexedWind(Vec2f* points, int* indices, int count) {
	float area = 0;
	for (int i = 0; i < count; i++) {
		Vec2f a = points[indices[i]];
		Vec2f b = points[indices[(i + 1) % count]];
		area += a.x * b.y - b.x * a.y;
	}

	if (area > POINT_EPSILON) return 1;
	if (area < -POINT_EPSILON) return -1;
	return 0;
}

fn int cleanContour(Vec2f* points, int count, Vec2f* out) {
	int outCount = 0;

	for (int i = 0; i < count; i++) {
		Vec2f p = points[i];
		if (outCount > 0 && out[outCount - 1].dist(p) <= POINT_EPSILON) continue;
		out[outCount] = p;
		outCount++;
	}

	if (outCount > 1 && out[0].dist(out[outCount - 1]) <= POINT_EPSILON) outCount--;

	bool changed = true;
	while (changed && outCount >= 3) {
		changed = false;

		for (int i = 0; i < outCount; i++) {
			Vec2f prev = out[(i + outCount - 1) % outCount];
			Vec2f curr = out[i];
			Vec2f next = out[(i + 1) % outCount];
			float area = math::abs(cross(prev, curr, next));
			float edge = prev.dist(curr) + curr.dist(next);
			if (area > POINT_EPSILON * edge) continue;

			for (int j = i; j < outCount - 1; j++) out[j] = out[j + 1];
			outCount--;
			changed = true;
			break;
		}
	}

	return outCount;
}

fn bool isEar(Vec2f* points, int* indices, int remaining, int prevIndex, int currIndex, int nextIndex, int winding) {
	Vec2f a = points[prevIndex];
	Vec2f b = points[currIndex];
	Vec2f c = points[nextIndex];

	if (!isConvex(a, b, c, winding)) return false;

	for (int i = 0; i < remaining; i++) {
		int index = indices[i];
		if (index == prevIndex || index == currIndex || index == nextIndex) continue;
		if (triContains(points[index], a, b, c)) return false;
	}

	return true;
}

fn bool isConvex(Vec2f a, Vec2f b, Vec2f c, int winding) {
	float value = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
	if (winding > 0) return value > POINT_EPSILON;
	return value < -POINT_EPSILON;
}

fn bool triContains(Vec2f p, Vec2f a, Vec2f b, Vec2f c) {
	float ab = cross(a, b, p);
	float bc = cross(b, c, p);
	float ca = cross(c, a, p);

	return (ab > POINT_EPSILON && bc > POINT_EPSILON && ca > POINT_EPSILON) ||
		(ab < -POINT_EPSILON && bc < -POINT_EPSILON && ca < -POINT_EPSILON);
}

fn float cross(Vec2f a, Vec2f b, Vec2f c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
