module microvg;

alias Vec2f = float[<2>];
alias Vec4f = float[<4>];

fn Vec2f vec2(float x, float y) @inline => { x, y };
fn Vec4f vec4(float x, float y, float z, float w) @inline => { x, y, z, w };


