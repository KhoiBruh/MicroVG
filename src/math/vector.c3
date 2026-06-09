module microvg;

alias Vec2 = float[<2>];
alias Vec4 = float[<4>];

fn Vec2 vec2(float x, float y) @inline => { x, y };
fn Vec4 vec4(float x, float y, float z, float w) @inline => { x, y, z, w };


