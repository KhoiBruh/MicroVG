module microvg;

alias Vec2 = float[<2>];
alias Vec3 = float[<3>];
alias Vec4 = float[<4>];

macro Vec2 Vec2.normalize(self) {
	float len = self.length();
	if (len < 0.0001f) return { 1, 0 };

	return { self.x / len, self.y / len };
}

macro Vec2 Vec2.half(self, Vec2 other) => (self + other) * 0.5;
