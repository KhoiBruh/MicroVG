module microvg;

struct State {
	inline Mat2x3 form;
	float alpha;
}

fn void State.reset(&self) {
	self.form = IDENTITY_2X3;
	self.alpha = 1;
}

fn State* MicroVG.currentState(&self) {
    ichar idx = self.stateCount - 1;
    return &self.states[idx];
}

fn void MicroVG.save(&self) {
    if (self.stateCount >= MAX_STATES) return;
    ichar cur = self.stateCount - 1;
    self.states[self.stateCount] = self.states[cur];
    self.stateCount++;
}

fn void MicroVG.restore(&self) {
    if (self.stateCount <= 1) return;
    self.stateCount--;
}

fn void MicroVG.reset(&self) => self.currentState().reset();

fn Vec2 MicroVG.transform(&self, Vec2 v) => self.currentState().form * v;

fn void MicroVG.translate(&self, float x, float y) => self.currentState().form.translate(x, y);

fn void MicroVG.scale(&self, float x, float y) => self.currentState().form.scale(x, y);

fn void MicroVG.rotate(&self, float rad) => self.currentState().form.rotate(rad);

fn void MicroVG.alpha(&self, float a) => self.currentState().alpha = a;
