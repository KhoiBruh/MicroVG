module microvg::paint;

import microvg;
import microvg::color;

enum FillRule {
	NON_ZERO,
	EVEN_ODD
}

enum LineCap {
	BUTT,
	SQUARE,
	ROUND
}

enum LineJoin {
	MITER,
	BEVEL,
	ROUND
}

struct Paint {
	MicroVG* vg;

	Color fillCol;
	Color strokeCol;
	float strokeW;
	LineCap lineCap;
	LineJoin lineJoin;
	float miterLimit;
	FillRule fillRule;

	bool hasFill;
	bool hasStroke;
}

fn Paint MicroVG.makePaint(&self) => {
	.vg = self,
	.fillRule = FillRule.NON_ZERO,
	.lineCap = LineCap.BUTT,
	.lineJoin = LineJoin.ROUND,
	.miterLimit = 4
};

fn void Paint.fill(&self, Color color) {
	self.fillCol = color;
	self.hasFill = true;
}

fn void Paint.rule(&self, FillRule rule) {
	self.fillRule = rule;
}

fn void Paint.stroke(&self, Color color, float width = 1) {
	self.strokeCol = color;
	self.strokeW = width;
	self.hasStroke = true;
}

fn void Paint.cap(&self, LineCap cap) {
	self.lineCap = cap;
}

fn void Paint.join(&self, LineJoin join) {
	self.lineJoin = join;
}

fn void Paint.miter(&self, float limit) {
	self.miterLimit = limit;
}
