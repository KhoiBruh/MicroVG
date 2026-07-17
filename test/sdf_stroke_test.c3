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
}
