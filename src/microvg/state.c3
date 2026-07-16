module microvg;

enum CompositeOp : char {
	SOURCE_OVER,
	SOURCE_IN,
	SOURCE_OUT,
	ATOP,
	DESTINATION_OVER,
	DESTINATION_IN,
	DESTINATION_OUT,
	DESTINATION_ATOP,
	LIGHTER,
	COPY,
	XOR
}

struct CompositeOpState {
	BlendFactor srcRGB;
	BlendFactor dstRGB;
	BlendFactor srcAlpha;
	BlendFactor dstAlpha;
}

struct Scissor {
	Mat2x3 form;
	Vec2 extent;
}

struct State {
	CompositeOpState compositeOp;
	int shapeAA;
	Paint fill;
	Paint stroke;
	float strokeWidth;
	float miterLimit;
	LineJoin lineJoin;
	LineCap lineCap;
	float alpha;
	Mat2x3 form;
	Scissor scissor;
}

fn CompositeOpState CompositeOp.state(self) {
	BlendFactor sfactor;
	BlendFactor dfactor;

	switch (self) {
		case CompositeOp.SOURCE_OVER:
			sfactor = BlendFactor.ONE;
			dfactor = BlendFactor.ONE_MINUS_SRC_ALPHA;

		case CompositeOp.SOURCE_IN:
			sfactor = BlendFactor.DST_ALPHA;
			dfactor = BlendFactor.ZERO;

		case CompositeOp.SOURCE_OUT:
			sfactor = BlendFactor.ONE_MINUS_DST_ALPHA;
			dfactor = BlendFactor.ZERO;

		case CompositeOp.ATOP:
			sfactor = BlendFactor.DST_ALPHA;
			dfactor = BlendFactor.ONE_MINUS_SRC_ALPHA;

		case CompositeOp.DESTINATION_OVER:
			sfactor = BlendFactor.ONE_MINUS_DST_ALPHA;
			dfactor = BlendFactor.ONE;

		case CompositeOp.DESTINATION_IN:
			sfactor = BlendFactor.ZERO;
			dfactor = BlendFactor.SRC_ALPHA;

		case CompositeOp.DESTINATION_OUT:
			sfactor = BlendFactor.ZERO;
			dfactor = BlendFactor.ONE_MINUS_SRC_ALPHA;

		case CompositeOp.DESTINATION_ATOP:
			sfactor = BlendFactor.ONE_MINUS_DST_ALPHA;
			dfactor = BlendFactor.SRC_ALPHA;

		case CompositeOp.LIGHTER:
			sfactor = BlendFactor.ONE;
			dfactor = BlendFactor.ONE;

		case CompositeOp.COPY:
			sfactor = BlendFactor.ONE;
			dfactor = BlendFactor.ZERO;

		case CompositeOp.XOR:
			sfactor = BlendFactor.ONE_MINUS_DST_ALPHA;
			dfactor = BlendFactor.ONE_MINUS_SRC_ALPHA;

		default:
			sfactor = BlendFactor.ONE;
			dfactor = BlendFactor.ZERO;
	}

	CompositeOpState state;
	state.srcRGB = sfactor;
	state.dstRGB = dfactor;
	state.srcAlpha = sfactor;
	state.dstAlpha = dfactor;

	return state;
}
