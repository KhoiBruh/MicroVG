module microvg::types;

import microvg::color;
import microvg::paint;
import microvg::vector;

struct Vertex {
	Vec2f pos;
	Vec2f tex;
}

struct DrawCall {
	int offset;
	int count;
	Color color;
	bool stencilFill;
	FillRule fillRule;
	int coverOffset;
	int coverCount;
}

struct DebugStats {
	int vertices;
	int vertexCap;
	int drawCalls;
	int drawCallCap;
	int commands;
	int commandCap;
	int tessFails;

	int usedBytes;
	int reservedBytes;
}

struct AntiAlias {
	float tessTol; // AA tessellation tolerance
	float distTol; // AA distance tolerance
	float fringe; // AA fringe width
}

fn AntiAlias makeAA(float ratio) => {
	.tessTol = 0.25 / ratio,
	.distTol = 0.01 / ratio,
	.fringe = 1 / ratio
};
