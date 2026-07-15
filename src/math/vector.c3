module microvg;

alias Vec2 = float[<2>];
alias Vec3 = float[<3>];
alias Vec4 = float[<4>];

macro Vec2 Vec2.normalize(self) {
	float len = self.length();
	if (len < 1e-8f) return { 1, 0 };

	return { self.x / len, self.y / len };
}

macro Vec2 Vec2.lerp(self, Vec2 b, float t) => {
	self.x + (b.x - self.x) * t,
	self.y + (b.y - self.y) * t
};

macro Vec2 Vec2.half(self, Vec2 other) => (self + other) * 0.5;
