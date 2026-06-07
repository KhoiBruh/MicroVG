module microvg;

const sz VERTEX_INIT_CAP @private = 2048;

struct VertexBuffer {
	float* data;
	sz count;
	sz cap;
}

fn void VertexBuffer.reset(&self) @inline {
	self.count = 0;
}

fn void VertexBuffer.push(&self, float[6] data) {
    if (self.count + 2 > self.cap) {
        sz newCap = self.cap == 0 ? VERTEX_INIT_CAP : self.cap * 2;
        self.data = mem::realloc(self.data, float::size * newCap);
        self.cap = newCap;
    }

    for (sz i = 0; i < data.len; i++) self.data[self.count + i] = data[i];
}

fn void VertexBuffer.destroy(&self) {
    mem::free(self.data);
    *self = {};
}
