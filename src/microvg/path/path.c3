module microvg::path;

import std::math;

import microvg;
import microvg::matrix;
import microvg::constant;

enum CmdType {
	MOVE,
	LINE,
	QUAD,
	BEZIER,
	ARC,
	CLOSE
}

struct Cmd {
	CmdType type;
	float[6] args;
}

struct Path {
	MicroVG* vg;

	int offset;
	int count;
}

fn void Path.moveTo(&self, float x, float y) {
	Cmd cmd = { .type = CmdType.MOVE, .args = { x, y, 0, 0, 0, 0 } };
	self.vg.cmds.push(cmd);
	self.count++;
}

fn void Path.lineTo(&self, float x, float y) {
	Cmd cmd = { .type = CmdType.LINE, .args = { x, y, 0, 0, 0, 0 } };
	self.vg.cmds.push(cmd);
	self.count++;
}

fn void Path.quadTo(&self, float cx, float cy, float x, float y) {
	Cmd cmd = { .type = CmdType.QUAD, .args = { cx, cy, x, y, 0, 0 } };
	self.vg.cmds.push(cmd);
	self.count++;
}

fn void Path.bezierTo(&self, float c1x, float c1y, float c2x, float c2y, float x, float y) {
	Cmd cmd = { .type = CmdType.BEZIER, .args = { c1x, c1y, c2x, c2y, x, y } };
	self.vg.cmds.push(cmd);
	self.count++;
}

fn void Path.arcTo(&self, float x1, float y1, float x2, float y2, float radius) {
	Cmd cmd = { .type = CmdType.ARC, .args = { x1, y1, x2, y2, radius, 0 } };
	self.vg.cmds.push(cmd);
	self.count++;
}

fn void Path.rect(&self, float x, float y, float w, float h) {
	self.moveTo(x, y);
	self.lineTo(x + w, y);
	self.lineTo(x + w, y + h);
	self.lineTo(x, y + h);
	self.close();
}

fn void Path.roundedRect(&self, float x, float y, float w, float h, float r) {
	float radius = clampRadius(r, w, h);
	if (radius <= 0) {
		self.rect(x, y, w, h);
		return;
	}

	float right = x + w;
	float bottom = y + h;
	float k = radius * constant::KAPPA_90;

	self.moveTo(x + radius, y);
	self.lineTo(right - radius, y);
	self.bezierTo(right - radius + k, y, right, y + radius - k, right, y + radius);
	self.lineTo(right, bottom - radius);
	self.bezierTo(right, bottom - radius + k, right - radius + k, bottom, right - radius, bottom);
	self.lineTo(x + radius, bottom);
	self.bezierTo(x + radius - k, bottom, x, bottom - radius + k, x, bottom - radius);
	self.lineTo(x, y + radius);
	self.bezierTo(x, y + radius - k, x + radius - k, y, x + radius, y);
	self.close();
}

fn void Path.circle(&self, float cx, float cy, float r) {
	self.ellipse(cx, cy, r, r);
}

fn void Path.ellipse(&self, float cx, float cy, float rx, float ry) {
	if (rx <= 0 || ry <= 0) return;

	float kx = rx * constant::KAPPA_90;
	float ky = ry * constant::KAPPA_90;

	self.moveTo(cx + rx, cy);
	self.bezierTo(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
	self.bezierTo(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
	self.bezierTo(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
	self.bezierTo(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);
	self.close();
}

fn void Path.close(&self) {
	Cmd cmd = { .type = CmdType.CLOSE };
	self.vg.cmds.push(cmd);
	self.count++;
}

fn float clampRadius(float r, float w, float h) {
	if (r <= 0) return 0;

	float maxRadius = math::min(math::abs(w), math::abs(h)) * 0.5;
	return math::min(r, maxRadius);
}
