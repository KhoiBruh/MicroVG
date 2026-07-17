module microvg;

import std::math;

fn void testSdfSectorDivisionsScalesWithSweep() @test {
	assert(sdfSectorDivisions(0.0f, PI * 0.25f) == 1);
	assert(sdfSectorDivisions(PI * 0.25f, PI * 0.25f) == 1);
	assert(sdfSectorDivisions(PI * 0.5f, PI * 0.25f) == 2);
	assert(sdfSectorDivisions(PI, PI * 0.25f) == 4);
}

fn void testSdfSectorRadiusCircumscribesArc() @test {
	float outer_radius = 10.0f;
	float delta = PI * 0.25f;
	float sector_radius = sdfSectorRadius(outer_radius, delta);

	for (int i = 0; i <= 8; i++) {
		float angle = -delta * 0.5f + delta * (float)i / 8.0f;
		float boundary_radius = sector_radius * math::cos(delta * 0.5f) / math::cos(angle);
		assert(boundary_radius >= outer_radius);
	}

	float large_delta_radius = sdfSectorRadius(outer_radius, PI);
	assert(math::is_finite(large_delta_radius));
	assert(large_delta_radius > 0.0f);
}

fn void testSdfCapPointStaysInOutwardEndpointHalfPlane() @test {
	Vec2 endpoint = { 3.0f, -2.0f };
	Vec2 direction = { 0.6f, 0.8f };

	for (int i = 0; i <= 8; i++) {
		float angle = -PI * 0.5f + PI * (float)i / 8.0f;
		Vec2 point = sdfCapPoint(endpoint, direction, 5.0f, angle);
		float outward_distance = (point.x - endpoint.x) * direction.x + (point.y - endpoint.y) * direction.y;
		assert(outward_distance >= -0.0001f);
	}
}

fn void testSdfCapPointUsesClockwiseNormal() @test {
	Vec2 point = sdfCapPoint({ 0.0f, 0.0f }, { 1.0f, 0.0f }, 5.0f, PI * 0.5f);
	assert(math::abs(point.x) < 0.0001f);
	assert(point.y < 0.0f);
}

fn void assertRoundStrokeFinite(MvgPath* path) @private {
	for (int i = 0; i < path.nroundStroke; i++) {
		Vertex vertex = path.roundStroke[i];
		assert(math::is_finite(vertex.x));
		assert(math::is_finite(vertex.y));
		assert(math::is_finite(vertex.u));
		assert(math::is_finite(vertex.v));
		for (int j = 0; j < 4; j++) assert(math::is_finite(path.roundStrokeData[i * 4 + j]));
	}
}

fn void assertRoundStrokeRadii(MvgPath* path, float inner_radius, float outer_radius) @private {
	for (int i = 0; i < path.nroundStroke; i++) {
		assert(math::abs(path.roundStroke[i].u - inner_radius) < 0.0001f);
		assert(math::abs(path.roundStroke[i].v - outer_radius) < 0.0001f);
	}
}

fn float triangleArea2(Vec2 a, Vec2 b, Vec2 c) @private {
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
}

fn bool trianglesOverlapPositiveArea(Vec2[3] a, Vec2[3] b) @private {
	for (int shape = 0; shape < 2; shape++) {
		Vec2[3]* triangle = (shape == 0) ? &a : &b;
		for (int i = 0; i < 3; i++) {
			Vec2 p0 = (*triangle)[i];
			Vec2 p1 = (*triangle)[(i + 1) % 3];
			Vec2 axis = { -(p1.y - p0.y), p1.x - p0.x };
			float amin = a[0].x * axis.x + a[0].y * axis.y;
			float amax = amin;
			float bmin = b[0].x * axis.x + b[0].y * axis.y;
			float bmax = bmin;
			for (int j = 1; j < 3; j++) {
				float ap = a[j].x * axis.x + a[j].y * axis.y;
				float bp = b[j].x * axis.x + b[j].y * axis.y;
				amin = math::min(amin, ap);
				amax = math::max(amax, ap);
				bmin = math::min(bmin, bp);
				bmax = math::max(bmax, bp);
			}
			if (math::min(amax, bmax) - math::max(amin, bmin) <= 0.0001f) return false;
		}
	}
	return true;
}

fn void assertBodyAndRoundStrokeDoNotOverlap(MvgPath* path) @private {
	assert(path.nroundStroke % 3 == 0);
	for (int i = 0; i + 2 < path.nstroke; i++) {
		Vec2[3] body = {
			{ path.stroke[i].x, path.stroke[i].y },
			{ path.stroke[i + 1].x, path.stroke[i + 1].y },
			{ path.stroke[i + 2].x, path.stroke[i + 2].y }
		};
		if (math::abs(triangleArea2(body[0], body[1], body[2])) <= 0.0001f) continue;
		for (int j = 0; j < path.nroundStroke; j += 3) {
			Vec2[3] round = {
				{ path.roundStroke[j].x, path.roundStroke[j].y },
				{ path.roundStroke[j + 1].x, path.roundStroke[j + 1].y },
				{ path.roundStroke[j + 2].x, path.roundStroke[j + 2].y }
			};
			if (math::abs(triangleArea2(round[0], round[1], round[2])) <= 0.0001f) continue;
			assert(!trianglesOverlapPositiveArea(body, round));
		}
	}
}

fn void assertBodyFiniteAndBounded(MvgPath* path, float limit) @private {
	assert(path.strokeData != null);
	for (int i = 0; i < path.nstroke; i++) {
		Vertex vertex = path.stroke[i];
		assert(math::is_finite(vertex.x));
		assert(math::is_finite(vertex.y));
		assert(math::is_finite(vertex.u));
		assert(math::is_finite(vertex.v));
		assert(math::abs(vertex.x) <= limit);
		assert(math::abs(vertex.y) <= limit);
		for (int j = 0; j < 4; j++) assert(math::is_finite(path.strokeData[i * 4 + j]));
	}
}

fn void prepareSdfStrokePath(MicroVG* vg) @private {
	MvgPath* path = &vg.cache.paths[0];
	Point* p0 = &vg.cache.points[path.first + path.count - 1];
	Point* p1 = &vg.cache.points[path.first];
	for (int i = 0; i < path.count; i++) {
		p0.dx = p1.x - p0.x;
		p0.dy = p1.y - p0.y;
		p0.len = nvgNormalize(&p0.dx, &p0.dy);
		p0 = p1;
		p1++;
	}
}

fn void testRoundCapsAreNotInsertedIntoBodyStrip() @test {
	MicroVG vg = {};
	vg.cache = allocPathCache();
	assert(vg.cache != null);
	defer vg.cache.delete();
	vg.setPxRatio(1.0f);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 20.0f, 0.0f }, PT_CORNER);
	prepareSdfStrokePath(&vg);

	assert(vg.expandStroke(5.0f, 1.0f, LineCap.ROUND, LineJoin.MITER, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assert(path.nstroke == 4);
	assert(path.nroundStroke == 12);
	assert(path.nroundStroke % 3 == 0);
	assert(path.roundStroke != null);
	assert(path.roundStrokeData != null);
	assert(path.nroundStroke == sdfRoundStrokeVertexCount(path, &vg.cache.points[path.first], LineCap.ROUND, LineJoin.MITER));

	for (int i = 0; i < 6; i++) {
		assert(path.roundStroke[i].x <= 0.0001f);
		assert(path.roundStrokeData[i * 4] == 0.0f);
		assert(path.roundStrokeData[i * 4 + 1] == 0.0f);
		assert(path.roundStrokeData[i * 4 + 2] == 1.0f);
		assert(path.roundStrokeData[i * 4 + 3] == 1.0f);
	}
	for (int i = 6; i < 12; i++) {
		assert(path.roundStroke[i].x >= 19.9999f);
		assert(path.roundStrokeData[i * 4] == 20.0f);
		assert(path.roundStrokeData[i * 4 + 1] == 0.0f);
		assert(path.roundStrokeData[i * 4 + 2] == 1.0f);
		assert(path.roundStrokeData[i * 4 + 3] == 1.0f);
	}
	assertRoundStrokeFinite(path);
	assertRoundStrokeRadii(path, 5.0f, 6.0f);

	MicroVG zeroAaVg = {};
	zeroAaVg.cache = allocPathCache();
	assert(zeroAaVg.cache != null);
	defer zeroAaVg.cache.delete();
	zeroAaVg.setPxRatio(1.0f);
	zeroAaVg.addPath();
	zeroAaVg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	zeroAaVg.addPoint({ 20.0f, 0.0f }, PT_CORNER);
	prepareSdfStrokePath(&zeroAaVg);
	assert(zeroAaVg.expandStroke(5.0f, 0.0f, LineCap.ROUND, LineJoin.MITER, 10.0f) == 1);
	assertRoundStrokeRadii(&zeroAaVg.cache.paths[0], 5.0f, 5.0f);
}

fn void testRoundLeftJoinSweepsOuterSector() @test {
	MicroVG vg = {};
	vg.cache = allocPathCache();
	assert(vg.cache != null);
	defer vg.cache.delete();
	vg.setPxRatio(1.0f);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, -10.0f }, PT_CORNER);
	prepareSdfStrokePath(&vg);

	assert(vg.expandStroke(5.0f, 1.0f, LineCap.BUTT, LineJoin.ROUND, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assert(vg.cache.points[path.first + 1].flags.left);
	assert(path.nroundStroke > 0);
	assert(path.nroundStroke % 3 == 0);
	assert(path.nroundStroke == sdfRoundStrokeVertexCount(path, &vg.cache.points[path.first], LineCap.BUTT, LineJoin.ROUND));
	assertRoundStrokeRadii(path, 5.0f, 6.0f);

	bool has_positive_x = false;
	bool has_positive_y = false;
	for (int i = 0; i < path.nroundStroke; i += 3) {
		assert(math::abs(path.roundStroke[i].x - 10.0f) < 0.0001f);
		assert(math::abs(path.roundStroke[i].y) < 0.0001f);
		for (int j = 1; j < 3; j++) {
			Vertex vertex = path.roundStroke[i + j];
			assert(vertex.x >= 9.9999f);
			assert(vertex.y >= -0.0001f);
			if (vertex.x > 10.0001f) has_positive_x = true;
			if (vertex.y > 0.0001f) has_positive_y = true;
		}
	}
	assert(has_positive_x);
	assert(has_positive_y);
	assertRoundStrokeFinite(path);
	assertBodyAndRoundStrokeDoNotOverlap(path);
	assert(path.nstroke == 17);
}

fn void testRoundRightJoinSweepsOuterSector() @test {
	MicroVG vg = {};
	vg.cache = allocPathCache();
	assert(vg.cache != null);
	defer vg.cache.delete();
	vg.setPxRatio(1.0f);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 10.0f, 10.0f }, PT_CORNER);
	prepareSdfStrokePath(&vg);

	assert(vg.expandStroke(5.0f, 1.0f, LineCap.BUTT, LineJoin.ROUND, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assert(!vg.cache.points[path.first + 1].flags.left);
	assert(path.nroundStroke > 0);
	assert(path.nroundStroke % 3 == 0);
	assert(path.nroundStroke == sdfRoundStrokeVertexCount(path, &vg.cache.points[path.first], LineCap.BUTT, LineJoin.ROUND));
	assertRoundStrokeRadii(path, 5.0f, 6.0f);

	bool has_positive_x = false;
	bool has_negative_y = false;
	for (int i = 0; i < path.nroundStroke; i += 3) {
		assert(math::abs(path.roundStroke[i].x - 10.0f) < 0.0001f);
		assert(math::abs(path.roundStroke[i].y) < 0.0001f);
		for (int j = 1; j < 3; j++) {
			Vertex vertex = path.roundStroke[i + j];
			assert(vertex.x >= 9.9999f);
			assert(vertex.y <= 0.0001f);
			if (vertex.x > 10.0001f) has_positive_x = true;
			if (vertex.y < -0.0001f) has_negative_y = true;
		}
	}
	assert(has_positive_x);
	assert(has_negative_y);
	assertRoundStrokeFinite(path);
	assertBodyAndRoundStrokeDoNotOverlap(path);
	assert(path.nstroke == 17);
}

fn void assertClosedRoundJoinMeshDoesNotOverlap(bool reverse) @private {
	MicroVG vg = {};
	vg.cache = allocPathCache();
	assert(vg.cache != null);
	defer vg.cache.delete();
	vg.setPxRatio(1.0f);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	if (reverse) {
		vg.addPoint({ 0.0f, 10.0f }, PT_CORNER);
		vg.addPoint({ 10.0f, 10.0f }, PT_CORNER);
		vg.addPoint({ 10.0f, 0.0f }, PT_CORNER);
	} else {
		vg.addPoint({ 10.0f, 0.0f }, PT_CORNER);
		vg.addPoint({ 10.0f, 10.0f }, PT_CORNER);
		vg.addPoint({ 0.0f, 10.0f }, PT_CORNER);
	}
	vg.cache.paths[0].closed = 1;
	prepareSdfStrokePath(&vg);

	assert(vg.expandStroke(5.0f, 1.0f, LineCap.BUTT, LineJoin.ROUND, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assertBodyAndRoundStrokeDoNotOverlap(path);
	assert(path.nstroke == 38);
	assert(path.nroundStroke == 24);
	assert(path.nroundStroke % 3 == 0);
	assertBodyFiniteAndBounded(path, 20.0f);
	assertRoundStrokeFinite(path);
}

fn void testClosedCounterClockwiseRoundJoinsDoNotOverlapSectors() @test {
	assertClosedRoundJoinMeshDoesNotOverlap(false);
}

fn void testClosedClockwiseRoundJoinsDoNotOverlapSectors() @test {
	assertClosedRoundJoinMeshDoesNotOverlap(true);
}

fn void testShortRoundJoinHasExactFiniteBoundedBody() @test {
	MicroVG vg = {};
	vg.cache = allocPathCache();
	assert(vg.cache != null);
	defer vg.cache.delete();
	vg.setPxRatio(1.0f);
	vg.addPath();
	vg.addPoint({ 0.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 4.0f, 0.0f }, PT_CORNER);
	vg.addPoint({ 4.0f, -10.0f }, PT_CORNER);
	prepareSdfStrokePath(&vg);

	assert(vg.expandStroke(5.0f, 1.0f, LineCap.BUTT, LineJoin.ROUND, 10.0f) == 1);
	MvgPath* path = &vg.cache.paths[0];
	assert(vg.cache.points[path.first + 1].flags.innerBevel);
	assertBodyAndRoundStrokeDoNotOverlap(path);
	assert(path.nstroke == 17);
	assert(path.nroundStroke == 6);
	assertBodyFiniteAndBounded(path, 20.0f);
	assertRoundStrokeFinite(path);
}
