module microvg;

import std::math;

alias Vec2 = float[<2>];
alias Vec3 = float[<3>];
alias Vec4 = float[<4>];

macro Vec2 Vec2.normalize(self) {
    float len = v.length();
    if (len < 1e-8f) return { 1, 0 };

    return { self.x / len, self.y / len };
}

macro Vec2 Vec2.lerp(self, Vec2 b, float t) => {
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t
};


