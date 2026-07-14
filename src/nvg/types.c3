module microvg;

const float PI = 3.14159265358979323846264338327f;

struct NvgColor {
    union {
        float[4] rgba;
        struct {
            float r, g, b, a;
        }
    }
}

struct NvgPaint {
    Mat2x3    form;
    Vec2      extent;
    float     radius;
    float     feather;
    NvgColor  innerColor;
    NvgColor  outerColor;
    int       image;
}

enum Winding : char { CCW, CW }

enum LineCap : char { BUTT, ROUND, SQUARE }

enum LineJoin : char { ROUND, BEVEL, MITER }

const int BLEND_ZERO                = 1 << 0;
const int BLEND_ONE                 = 1 << 1;
const int BLEND_SRC_COLOR           = 1 << 2;
const int BLEND_ONE_MINUS_SRC_COLOR = 1 << 3;
const int BLEND_DST_COLOR           = 1 << 4;
const int BLEND_ONE_MINUS_DST_COLOR = 1 << 5;
const int BLEND_SRC_ALPHA           = 1 << 6;
const int BLEND_ONE_MINUS_SRC_ALPHA = 1 << 7;
const int BLEND_DST_ALPHA           = 1 << 8;
const int BLEND_ONE_MINUS_DST_ALPHA = 1 << 9;
const int BLEND_SRC_ALPHA_SATURATE  = 1 << 10;

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

struct NvgCompositeOperationState {
    int srcRGB;
    int dstRGB;
    int srcAlpha;
    int dstAlpha;
}

enum PathCommand : char { MOVE, LINE, BEZIER, CLOSE, WINDING }

struct PathCmd {
    PathCommand cmd;
    Vec2 p0, p1, p2;
}

const int IMAGE_GENERATE_MIPMAPS = 1 << 0;
const int IMAGE_REPEATX          = 1 << 1;
const int IMAGE_REPEATY          = 1 << 2;
const int IMAGE_FLIPY            = 1 << 3;
const int IMAGE_PREMULTIPLIED     = 1 << 4;
const int IMAGE_NEAREST           = 1 << 5;

enum TextureType : char { ALPHA, RGBA }

bitstruct PathPointFlags : char {
    bool corner     : 0..0;
    bool left       : 1..1;
    bool bevel      : 2..2;
    bool innerBevel : 3..3;
}

struct NvgScissor {
    Mat2x3 form;
    Vec2   extent;
}

struct NvgVertex {
    float x, y, u, v;
}

struct NvgPath {
    int        first;
    int        count;
    char       closed;
    int        nbevel;
    NvgVertex* fill;
    int        nfill;
    NvgVertex* stroke;
    int        nstroke;
    int        winding;
    int        convex;
}

alias RenderCreate         = fn int(void*);
alias RenderCreateTexture  = fn int(void*, TextureType, int, int, int, char*);
alias RenderDeleteTexture  = fn int(void*, int);
alias RenderUpdateTexture  = fn int(void*, int, int, int, int, int, char*);
alias RenderGetTextureSize = fn int(void*, int, int*, int*);
alias RenderViewport       = fn void(void*, float, float, float);
alias RenderCancel         = fn void(void*);
alias RenderFlush          = fn void(void*);
alias RenderFill           = fn void(void*, NvgPaint*, NvgCompositeOperationState, NvgScissor*, float, float*, NvgPath*, int);
alias RenderStroke         = fn void(void*, NvgPaint*, NvgCompositeOperationState, NvgScissor*, float, float, NvgPath*, int);
alias RenderTriangles      = fn void(void*, NvgPaint*, NvgCompositeOperationState, NvgScissor*, NvgVertex*, int, float);
alias RenderDelete         = fn void(void*);

struct NvgParams {
    void*                userPtr;
    int                  edgeAntiAlias;
    RenderCreate         renderCreate;
    RenderCreateTexture  renderCreateTexture;
    RenderDeleteTexture  renderDeleteTexture;
    RenderUpdateTexture  renderUpdateTexture;
    RenderGetTextureSize renderGetTextureSize;
    RenderViewport       renderViewport;
    RenderCancel         renderCancel;
    RenderFlush          renderFlush;
    RenderFill           renderFill;
    RenderStroke         renderStroke;
    RenderTriangles      renderTriangles;
    RenderDelete         renderDelete;
}
