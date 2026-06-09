module microvg;

import std::math;

alias Vec2 = float[<2>];
alias Vec3 = float[<3>];
alias Vec4 = float[<4>];

fn Vec2 vec2(float x, float y) @inline => { x, y };
fn Vec4 vec4(float x, float y, float z, float w) @inline => { x, y, z, w };

fn Vec2 vec2_zero() @inline => { 0, 0 };

fn float vec2_len(Vec2 v) @inline => math::sqrt(v.x * v.x + v.y * v.y);

fn Vec2 vec2_normalize(Vec2 v) @inline {
    float len = vec2_len(v);
    if (len < 1e-8f) return { 1, 0 };
    return { v.x / len, v.y / len };
}

fn Vec2 vec2_lerp(Vec2 a, Vec2 b, float t) @inline => {
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t
};
