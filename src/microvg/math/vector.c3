module microvg::vector;

import std::math;

alias Vec2f = float[<2>];
alias Vec3f = float[<3>];
alias Vec4f = float[<4>];

fn Vec2f Vec2f.halfOf(self, Vec2f other) => (self + other) * 0.5;

fn float Vec2f.lenSQ(self) => self.dot(self);
fn float Vec3f.lenSQ(self) => self.dot(self);
fn float Vec4f.lenSQ(self) => self.dot(self);

fn float Vec2f.dist(self, Vec2f other) => (self - other).length();
fn float Vec2f.distSQ(self, Vec2f other) => (self - other).lenSQ();
fn float Vec3f.dist(self, Vec3f other) => (self - other).length();
fn float Vec3f.distSQ(self, Vec3f other) => (self - other).lenSQ();
fn float Vec4f.dist(self, Vec4f other) => (self - other).length();
fn float Vec4f.distSQ(self, Vec4f other) => (self - other).lenSQ();

fn Vec2f Vec2f.lerp(self, Vec2f other, float t) => self * (1 - t) + other * t;
fn Vec3f Vec3f.lerp(self, Vec3f other, float t) => self * (1 - t) + other * t;
fn Vec4f Vec4f.lerp(self, Vec4f other, float t) => self * (1 - t) + other * t;

fn float Vec2f.lineDist(self, Vec2f a, Vec2f b) {
	Vec2f ab = b - a;
	float len = ab.lenSQ();
	if (len <= 0.0001) return self.dist(a);

	float t = (self - a).dot(ab) / len;
	t = math::clamp(t, 0, 1);
	Vec2f closest = a + ab * t;

	return self.dist(closest);
}
