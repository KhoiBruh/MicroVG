module microvg;

import std::core::mem;
import std::math;

struct FrameBuf {
	char* data;
	int count;
	int capacity;
	int elem_size;
}

fn bool FrameBuf.init(&self, int elem_size, int initial_cap) {
	self.elem_size = elem_size;
	self.count = 0;
	self.capacity = initial_cap;
	self.data = mem::malloc((sz)elem_size * initial_cap);
	return self.data != null;
}

fn void* FrameBuf.at(&self, int i) => self.data + i * self.elem_size;

fn int FrameBuf.alloc(&self, int n) {
	while (self.count + n > self.capacity) {
		self.capacity = math::max(self.capacity * 2, self.count + n + 64);
	}
	char* new_data = mem::realloc(self.data, (sz)self.elem_size * self.capacity);
	if (new_data == null) return -1;
	self.data = new_data;

	int ret = self.count;
	self.count += n;
	return ret;
}

fn void FrameBuf.reset(&self) => self.count = 0;

fn void FrameBuf.delete(&self) {
	if (self.data != null) mem::free(self.data);
	self.data = null;
	self.count = 0;
	self.capacity = 0;
}
