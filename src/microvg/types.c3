module microvg;

const int BLEND_ZERO = 1 << 0;
const int BLEND_ONE = 1 << 1;
const int BLEND_SRC_COLOR = 1 << 2;
const int BLEND_ONE_MINUS_SRC_COLOR = 1 << 3;
const int BLEND_DST_COLOR = 1 << 4;
const int BLEND_ONE_MINUS_DST_COLOR = 1 << 5;
const int BLEND_SRC_ALPHA = 1 << 6;
const int BLEND_ONE_MINUS_SRC_ALPHA = 1 << 7;
const int BLEND_DST_ALPHA = 1 << 8;
const int BLEND_ONE_MINUS_DST_ALPHA = 1 << 9;
const int BLEND_SRC_ALPHA_SATURATE = 1 << 10;

const int IMAGE_GENERATE_MIPMAPS = 1 << 0;
const int IMAGE_REPEATX = 1 << 1;
const int IMAGE_REPEATY = 1 << 2;
const int IMAGE_FLIPY = 1 << 3;
const int IMAGE_PREMULTIPLIED = 1 << 4;
const int IMAGE_NEAREST = 1 << 5;

enum TextureType : char {
	ALPHA,
	RGBA
}

struct Vertex {
	float x, y, u, v;
}

alias RenderCreate = fn int(void*);
alias RenderCreateTexture = fn int(void*, TextureType, int, int, int, char*);
alias RenderDeleteTexture = fn int(void*, int);
alias RenderUpdateTexture = fn int(void*, int, int, int, int, int, char*);
alias RenderGetTextureSize = fn int(void*, int, int*, int*);
alias RenderViewport = fn void(void*, float, float, float);
alias RenderCancel = fn void(void*);
alias RenderFlush = fn void(void*);
alias RenderFill = fn void(void*, Paint*, CompositeOpState, Scissor*, float, float*, MvgPath*, int);
alias RenderStroke = fn void(void*, Paint*, CompositeOpState, Scissor*, float, float, MvgPath*, int);
alias RenderTriangles = fn void(void*, Paint*, CompositeOpState, Scissor*, Vertex*, int, float);
alias RenderDelete = fn void(void*);

struct Params {
	void* userPtr;
	int edgeAA;
	RenderCreate renderCreate;
	RenderCreateTexture renderCreateTexture;
	RenderDeleteTexture renderDeleteTexture;
	RenderUpdateTexture renderUpdateTexture;
	RenderGetTextureSize renderGetTextureSize;
	RenderViewport renderViewport;
	RenderCancel renderCancel;
	RenderFlush renderFlush;
	RenderFill renderFill;
	RenderStroke renderStroke;
	RenderTriangles renderTriangles;
	RenderDelete renderDelete;
}
