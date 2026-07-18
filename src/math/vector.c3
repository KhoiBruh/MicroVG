module microvg;

import std::math;

alias Vec2 = float[<2>];
alias Vec3 = float[<3>];
alias Vec4 = float[<4>];

fn float Vec2.atan2(self) @inline => math::atan2(self.y, self.x);
fn Vec2 Vec2.cw(self) @inline => { self.y, -self.x };
fn Vec2 Vec2.ccw(self) @inline => { -self.y, self.x };

fn float Vec2.normalize(&self) {
	float len = self.length();
	if (len > 0.0001f) {
		float id = 1 / len;
		self.x *= id;
		self.y *= id;
	}

	return len;
}

fn Vec2 Vec2.half(self, Vec2 other) => (self + other) * 0.5;
