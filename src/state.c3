module microvg;

// state api
struct State {
	inline Mat2x3 form;
	float alpha;
}

fn void State.reset(&self) {
	self.form = IDENTITY_2X3;
	self.alpha = 1;
}
