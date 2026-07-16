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
	int srcRGB;
	int dstRGB;
	int srcAlpha;
	int dstAlpha;
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
	int sfactor;
	int dfactor;

	switch (self) {
		case CompositeOp.SOURCE_OVER:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		case CompositeOp.SOURCE_IN:
			sfactor = BLEND_DST_ALPHA;
			dfactor = BLEND_ZERO;

		case CompositeOp.SOURCE_OUT:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_ZERO;

		case CompositeOp.ATOP:
			sfactor = BLEND_DST_ALPHA;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		case CompositeOp.DESTINATION_OVER:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_ONE;

		case CompositeOp.DESTINATION_IN:
			sfactor = BLEND_ZERO;
			dfactor = BLEND_SRC_ALPHA;

		case CompositeOp.DESTINATION_OUT:
			sfactor = BLEND_ZERO;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		case CompositeOp.DESTINATION_ATOP:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_SRC_ALPHA;

		case CompositeOp.LIGHTER:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ONE;

		case CompositeOp.COPY:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ZERO;

		case CompositeOp.XOR:
			sfactor = BLEND_ONE_MINUS_DST_ALPHA;
			dfactor = BLEND_ONE_MINUS_SRC_ALPHA;

		default:
			sfactor = BLEND_ONE;
			dfactor = BLEND_ZERO;
	}

	CompositeOpState state;
	state.srcRGB = sfactor;
	state.dstRGB = dfactor;
	state.srcAlpha = sfactor;
	state.dstAlpha = dfactor;

	return state;
}
