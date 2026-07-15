module microvg::glbackend;

import microvg;
import opengl::gl;
import std::core::mem;
import std::math;

extern fn int printf(char* fmt, ...);

const int NVG_ANTIALIAS = 1 << 0;
const int NVG_STENCIL_STROKES = 1 << 1;
const int NVG_DEBUG = 1 << 2;
const int NVG_IMAGE_NODELETE = 1 << 16;

enum GlNvgLoc : char {
	VIEWSIZE,
	TEX,
	FRAG,
	MAX_LOCS
}

enum NsvgShader : char {
	FILLGRAD,
	FILLIMG,
	SIMPLE,
	IMG
}

const int GLNVG_FRAG_BINDING = 0;

enum GlNvgCallType : char {
	NONE,
	FILL,
	CONVEXFILL,
	STROKE,
	TRIANGLES
}

struct GlShader {
	uint prog;
	uint frag;
	uint vert;
	int[3] loc;
}

struct GlTexture {
	int id;
	uint tex;
	int width, height;
	TextureType type;
	int flags;
}

struct GlBlend {
	GLenum srcRGB;
	GLenum dstRGB;
	GLenum srcAlpha;
	GLenum dstAlpha;
}

struct GlCall {
	GlNvgCallType type;
	int image;
	int pathOffset;
	int pathCount;
	int triangleOffset;
	int triangleCount;
	int uniformOffset;
	GlBlend blendFunc;
}

struct GlPath {
	int fillOffset;
	int fillCount;
	int strokeOffset;
	int strokeCount;
}

struct GlFragUniforms {
	float[12] scissorMat;
	float[12] paintMat;
	NvgColor innerCol;
	NvgColor outerCol;
	microvg::Vec2 scissorExt;
	microvg::Vec2 scissorScale;
	microvg::Vec2 extent;
	float radius;
	float feather;
	float strokeMult;
	float strokeThr;
	int texType;
	NsvgShader type;
}

struct GlContext {
	GlShader shader;
	GlTexture* textures;
	microvg::Vec2 view;
	int ntextures;
	int ctextures;
	int textureId;
	uint vertBuf;
	uint vertArr;
	uint fragBuf;
	int fragSize;
	int flags;

	GlCall* calls;
	int ccalls;
	int ncalls;
	GlPath* paths;
	int cpaths;
	int npaths;
	NvgVertex* verts;
	int cverts;
	int nverts;
	char* uniforms;
	int cuniforms;
	int nuniforms;

	GLuint boundTexture;
	GLuint stencilMask;
	GLenum stencilFunc;
	GLint stencilFuncRef;
	GLuint stencilFuncMask;
	GlBlend blendFunc;

	int dummyTex;
}

fn void glnvgBindTexture(GlContext* gl, GLuint tex) @local {
	if (gl.boundTexture != tex) {
		gl.boundTexture = tex;
		gl::bindTexture(gl::GL_TEXTURE_2D, tex);
	}
}

fn void glnvgStencilMask(GlContext* gl, GLuint mask) @local {
	if (gl.stencilMask != mask) {
		gl.stencilMask = mask;
		gl::stencilMask(mask);
	}
}

fn void glnvgStencilFunc(GlContext* gl, GLenum func, GLint ref_val, GLuint mask) @local {
	if ((gl.stencilFunc != func) || (gl.stencilFuncRef != ref_val) || (gl.stencilFuncMask != mask)) {
		gl.stencilFunc = func;
		gl.stencilFuncRef = ref_val;
		gl.stencilFuncMask = mask;
		gl::stencilFunc((GLenum)func, ref_val, mask);
	}
}

fn void glnvgBlendFuncSeparate(GlContext* gl, GlBlend* blend) @local {
	if ((gl.blendFunc.srcRGB != blend.srcRGB) ||
	(gl.blendFunc.dstRGB != blend.dstRGB) ||
	(gl.blendFunc.srcAlpha != blend.srcAlpha) ||
	(gl.blendFunc.dstAlpha != blend.dstAlpha)) {
		gl.blendFunc = *blend;
		gl::blendFuncSeparate(blend.srcRGB, blend.dstRGB, blend.srcAlpha, blend.dstAlpha);
	}
}

fn GlTexture* glnvgAllocTexture(GlContext* gl) @local {
	GlTexture* tex = null;
	for (int i = 0; i < gl.ntextures; i++) {
		if (gl.textures[i].id == 0) {
			tex = &gl.textures[i];
			break;
		}
	}
	if (tex == null) {
		if (gl.ntextures + 1 > gl.ctextures) {
			int ctextures = math::max(gl.ntextures + 1, 4) + gl.ctextures / 2;
			GlTexture* textures = mem::realloc(gl.textures, (GlTexture::size * ctextures));
			if (textures == null) return null;
			gl.textures = textures;
			gl.ctextures = ctextures;
		}
		tex = &gl.textures[gl.ntextures++];
	}
	mem::clear(tex, GlTexture::size);
	tex.id = ++gl.textureId;
	return tex;
}

fn GlTexture* glnvgFindTexture(GlContext* gl, int id) @local {
	for (int i = 0; i < gl.ntextures; i++) {
		if (gl.textures[i].id == id) {
			return &gl.textures[i];
		}
	}
	return null;
}

fn int glnvgDeleteTexture(GlContext* gl, int id) @local {
	for (int i = 0; i < gl.ntextures; i++) {
		if (gl.textures[i].id == id) {
			if (gl.textures[i].tex != 0 && (gl.textures[i].flags & NVG_IMAGE_NODELETE) == 0) {
				gl::deleteTextures(1, &gl.textures[i].tex);
			}
			mem::clear(&gl.textures[i], GlTexture::size);
			return 1;
		}
	}
	return 0;
}

fn void glnvgDumpShaderError(uint shader, char* name, char* type) @local {
	char[513] str = {};
	int len = 0;
	gl::getShaderInfoLog(shader, 512, &len, &str[0]);
	if (len > 512) len = 512;
	str[len] = 0;
	printf("Shader %s/%s error:\n%s\n", name, type, &str[0]);
}

fn void glnvgDumpProgramError(uint prog, char* name) @local {
	char[513] str = {};
	int len = 0;
	gl::getProgramInfoLog(prog, 512, &len, &str[0]);
	if (len > 512) len = 512;
	str[len] = 0;
	printf("Program %s error:\n%s\n", name, &str[0]);
}

fn void glnvgCheckError(GlContext* gl, char* str) @local {
	if ((gl.flags & NVG_DEBUG) == 0) return;
	GLenum err = gl::getError();
	if (err != gl::GL_NO_ERROR) printf("Error %08x after %s\n", err, str);
}

fn int glnvgCreateShader(GlShader* shader, char* name, char* header, char* opts, char* vshader, char* fshader) @local {
	int status;
	uint prog, vert, frag;
	char*[3] str;
	str[0] = header;
	str[1] = opts != null ? opts : "";
	mem::clear(shader, GlShader::size);

	prog = gl::createProgram();
	vert = gl::createShader(gl::GL_VERTEX_SHADER);
	frag = gl::createShader(gl::GL_FRAGMENT_SHADER);
	str[2] = vshader;
	gl::shaderSource(vert, 3, &str[0], null);
	str[2] = fshader;
	gl::shaderSource(frag, 3, &str[0], null);

	gl::compileShader(vert);
	gl::getShaderiv(vert, gl::GL_COMPILE_STATUS, &status);
	if (status != gl::GL_TRUE) {
		glnvgDumpShaderError(vert, name, "vert");
		return 0;
	}

	gl::compileShader(frag);
	gl::getShaderiv(frag, gl::GL_COMPILE_STATUS, &status);
	if (status != gl::GL_TRUE) {
		glnvgDumpShaderError(frag, name, "frag");
		return 0;
	}

	gl::attachShader(prog, vert);
	gl::attachShader(prog, frag);

	gl::bindAttribLocation(prog, 0, "vertex");
	gl::bindAttribLocation(prog, 1, "tcoord");

	gl::linkProgram(prog);
	gl::getProgramiv(prog, gl::GL_LINK_STATUS, &status);
	if (status != gl::GL_TRUE) {
		glnvgDumpProgramError(prog, name);
		return 0;
	}

	shader.prog = prog;
	shader.vert = vert;
	shader.frag = frag;

	return 1;
}

fn void glnvgDeleteShader(GlShader* shader) @local {
	if (shader.prog != 0) gl::deleteProgram(shader.prog);
	if (shader.vert != 0) gl::deleteShader(shader.vert);
	if (shader.frag != 0) gl::deleteShader(shader.frag);
}

fn void glnvgGetUniforms(GlShader* shader) @local {
	shader.loc[GlNvgLoc.VIEWSIZE] = gl::getUniformLocation(shader.prog, "viewSize");
	shader.loc[GlNvgLoc.TEX] = gl::getUniformLocation(shader.prog, "tex");
	shader.loc[GlNvgLoc.FRAG] = (int) gl::getUniformBlockIndex(shader.prog, "frag");
}

fn void glnvgXformToMat3x4(float* m3, Mat2x3* t) @local {
	m3[0] = t.linear.x;
	m3[1] = t.linear.y;
	m3[2] = 0.0f;
	m3[3] = 0.0f;
	m3[4] = t.linear.z;
	m3[5] = t.linear.w;
	m3[6] = 0.0f;
	m3[7] = 0.0f;
	m3[8] = t.trans.x;
	m3[9] = t.trans.y;
	m3[10] = 1.0f;
	m3[11] = 0.0f;
}

fn NvgColor glnvgPremulColor(NvgColor c) @local {
	c.r *= c.a;
	c.g *= c.a;
	c.b *= c.a;
	return c;
}

fn int glnvgConvertPaint(GlContext* gl, GlFragUniforms* frag, NvgPaint* paint, NvgScissor* scissor, float width, float fringe, float strokeThr) @local {
	GlTexture* tex = null;
	Mat2x3 invxform;

	mem::clear(frag, GlFragUniforms::size);

	frag.innerCol = glnvgPremulColor(paint.innerColor);
	frag.outerCol = glnvgPremulColor(paint.outerColor);

	if (scissor.extent.x < -0.5f || scissor.extent.y < -0.5f) {
		mem::clear(&frag.scissorMat[0], 12 * float::size);
		frag.scissorExt.x = 1.0f;
		frag.scissorExt.y = 1.0f;
		frag.scissorScale.x = 1.0f;
		frag.scissorScale.y = 1.0f;
	}
	else {
		microvg::nvgTransformInverse(&invxform, &scissor.form);
		glnvgXformToMat3x4(&frag.scissorMat[0], &invxform);
		frag.scissorExt.x = scissor.extent.x;
		frag.scissorExt.y = scissor.extent.y;
		frag.scissorScale.x = math::sqrt(scissor.form.linear.x * scissor.form.linear.x + scissor.form.linear.z * scissor.form.linear.z) / fringe;
		frag.scissorScale.y = math::sqrt(scissor.form.linear.y * scissor.form.linear.y + scissor.form.linear.w * scissor.form.linear.w) / fringe;
	}

	frag.extent = paint.extent;
	frag.strokeMult = (width * 0.5f + fringe * 0.5f) / fringe;
	frag.strokeThr = strokeThr;

	if (paint.image != 0) {
		tex = glnvgFindTexture(gl, paint.image);
		if (tex == null) return 0;
		if ((tex.flags & microvg::IMAGE_FLIPY) != 0) {
			Mat2x3 m1;
			Mat2x3 m2;
			microvg::nvgTransformTranslate(&m1, 0.0f, frag.extent.y * 0.5f);
			microvg::nvgTransformMultiply(&m1, &paint.form);
			microvg::nvgTransformScale(&m2, 1.0f, -1.0f);
			microvg::nvgTransformMultiply(&m2, &m1);
			microvg::nvgTransformTranslate(&m1, 0.0f, -frag.extent.y * 0.5f);
			microvg::nvgTransformMultiply(&m1, &m2);
			microvg::nvgTransformInverse(&invxform, &m1);
		}
		else {
			microvg::nvgTransformInverse(&invxform, &paint.form);
		}
		frag.type = (NsvgShader.FILLIMG);
		if (tex.type == TextureType.RGBA) {
			frag.texType = (tex.flags & microvg::IMAGE_PREMULTIPLIED) ? 0 : 1;
		}
		else {
			frag.texType = 2;
		}
	}
	else {
		frag.type = (NsvgShader.FILLGRAD);
		frag.radius = paint.radius;
		frag.feather = paint.feather;
		microvg::nvgTransformInverse(&invxform, &paint.form);
	}

	glnvgXformToMat3x4(&frag.paintMat[0], &invxform);

	return 1;
}

fn GlFragUniforms* glnvgFragUniformPtr(GlContext* gl, int i) @local {
	return (GlFragUniforms*)&gl.uniforms[i];
}

fn void glnvgSetUniforms(GlContext* gl, int uniformOffset, int image) @local {
	GlTexture* tex = null;
	gl::bindBufferRange(gl::GL_UNIFORM_BUFFER, GLNVG_FRAG_BINDING, gl.fragBuf, uniformOffset, GlFragUniforms::size);

	if (image != 0) {
		tex = glnvgFindTexture(gl, image);
	}
	if (tex == null) {
		tex = glnvgFindTexture(gl, gl.dummyTex);
	}
	glnvgBindTexture(gl, tex != null ? tex.tex : 0);
	glnvgCheckError(gl, "tex paint tex");
}

fn void glnvgFill(GlContext* gl, GlCall* call) @local {
	GlPath* paths = &gl.paths[call.pathOffset];
	int npaths = call.pathCount;

	gl::enable(gl::GL_STENCIL_TEST);
	glnvgStencilMask(gl, 0xff);
	glnvgStencilFunc(gl, gl::GL_ALWAYS, 0, 0xff);
	gl::colorMask(gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE);

	glnvgSetUniforms(gl, call.uniformOffset, 0);
	glnvgCheckError(gl, "fill simple");

	gl::stencilOpSeparate(gl::GL_FRONT, gl::GL_KEEP, gl::GL_KEEP, gl::GL_INCR_WRAP);
	gl::stencilOpSeparate(gl::GL_BACK, gl::GL_KEEP, gl::GL_KEEP, gl::GL_DECR_WRAP);
	gl::disable(gl::GL_CULL_FACE);
	for (int i = 0; i < npaths; i++) {
		gl::drawArrays(gl::GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
	}
	gl::enable(gl::GL_CULL_FACE);

	gl::colorMask(gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE);

	glnvgSetUniforms(gl, call.uniformOffset + gl.fragSize, call.image);
	glnvgCheckError(gl, "fill fill");

	if (gl.flags & NVG_ANTIALIAS) {
		glnvgStencilFunc(gl, gl::GL_EQUAL, 0x00, 0xff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_KEEP);
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}

	glnvgStencilFunc(gl, gl::GL_NOTEQUAL, 0x0, 0xff);
	gl::stencilOp(gl::GL_ZERO, gl::GL_ZERO, gl::GL_ZERO);
	gl::drawArrays(gl::GL_TRIANGLE_STRIP, call.triangleOffset, call.triangleCount);

	gl::disable(gl::GL_STENCIL_TEST);
}

fn void glnvgConvexFill(GlContext* gl, GlCall* call) @local {
	GlPath* paths = &gl.paths[call.pathOffset];
	int npaths = call.pathCount;

	glnvgSetUniforms(gl, call.uniformOffset, call.image);
	glnvgCheckError(gl, "convex fill");

	for (int i = 0; i < npaths; i++) {
		gl::drawArrays(gl::GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
		if (paths[i].strokeCount > 0) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}
}

fn void glnvgStroke(GlContext* gl, GlCall* call) @local {
	GlPath* paths = &gl.paths[call.pathOffset];
	int npaths = call.pathCount;

	if (gl.flags & NVG_STENCIL_STROKES) {
		gl::enable(gl::GL_STENCIL_TEST);
		glnvgStencilMask(gl, 0xff);

		glnvgStencilFunc(gl, gl::GL_EQUAL, 0x0, 0xff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_INCR);
		glnvgSetUniforms(gl, call.uniformOffset + gl.fragSize, call.image);
		glnvgCheckError(gl, "stroke fill 0");
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}

		glnvgSetUniforms(gl, call.uniformOffset, call.image);
		glnvgStencilFunc(gl, gl::GL_EQUAL, 0x00, 0xff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_KEEP);
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}

		gl::colorMask(gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE, gl::GL_FALSE);
		glnvgStencilFunc(gl, gl::GL_ALWAYS, 0x0, 0xff);
		gl::stencilOp(gl::GL_ZERO, gl::GL_ZERO, gl::GL_ZERO);
		glnvgCheckError(gl, "stroke fill 1");
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
		gl::colorMask(gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE);

		gl::disable(gl::GL_STENCIL_TEST);
	}
	else {
		glnvgSetUniforms(gl, call.uniformOffset, call.image);
		glnvgCheckError(gl, "stroke fill");
		for (int i = 0; i < npaths; i++) {
			gl::drawArrays(gl::GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
		}
	}
}

fn void glnvgTriangles(GlContext* gl, GlCall* call) @local {
	glnvgSetUniforms(gl, call.uniformOffset, call.image);
	glnvgCheckError(gl, "triangles fill");
	gl::drawArrays(gl::GL_TRIANGLES, call.triangleOffset, call.triangleCount);
}

fn void glnvgRenderCancel(void* up) @local {
	GlContext* gl = (GlContext*)up;
	gl.nverts = 0;
	gl.npaths = 0;
	gl.ncalls = 0;
	gl.nuniforms = 0;
}

fn GLenum glnvgConvertBlendFuncFactor(int factor) @local {
	if (factor == microvg::BLEND_ZERO)                return gl::GL_ZERO;
	if (factor == microvg::BLEND_ONE)                 return gl::GL_ONE;
	if (factor == microvg::BLEND_SRC_COLOR)           return gl::GL_SRC_COLOR;
	if (factor == microvg::BLEND_ONE_MINUS_SRC_COLOR) return gl::GL_ONE_MINUS_SRC_COLOR;
	if (factor == microvg::BLEND_DST_COLOR)           return gl::GL_DST_COLOR;
	if (factor == microvg::BLEND_ONE_MINUS_DST_COLOR) return gl::GL_ONE_MINUS_DST_COLOR;
	if (factor == microvg::BLEND_SRC_ALPHA)           return gl::GL_SRC_ALPHA;
	if (factor == microvg::BLEND_ONE_MINUS_SRC_ALPHA) return gl::GL_ONE_MINUS_SRC_ALPHA;
	if (factor == microvg::BLEND_DST_ALPHA)           return gl::GL_DST_ALPHA;
	if (factor == microvg::BLEND_ONE_MINUS_DST_ALPHA) return gl::GL_ONE_MINUS_DST_ALPHA;
	if (factor == microvg::BLEND_SRC_ALPHA_SATURATE)  return gl::GL_SRC_ALPHA_SATURATE;
	return gl::GL_INVALID_ENUM;
}

fn GlBlend glnvgBlendCompositeOperation(NvgCompositeOperationState op) @local {
	GlBlend blend;
	blend.srcRGB = glnvgConvertBlendFuncFactor(op.srcRGB);
	blend.dstRGB = glnvgConvertBlendFuncFactor(op.dstRGB);
	blend.srcAlpha = glnvgConvertBlendFuncFactor(op.srcAlpha);
	blend.dstAlpha = glnvgConvertBlendFuncFactor(op.dstAlpha);
	if (blend.srcRGB == gl::GL_INVALID_ENUM || blend.dstRGB == gl::GL_INVALID_ENUM ||
	blend.srcAlpha == gl::GL_INVALID_ENUM || blend.dstAlpha == gl::GL_INVALID_ENUM) {
		blend.srcRGB = gl::GL_ONE;
		blend.dstRGB = gl::GL_ONE_MINUS_SRC_ALPHA;
		blend.srcAlpha = gl::GL_ONE;
		blend.dstAlpha = gl::GL_ONE_MINUS_SRC_ALPHA;
	}
	return blend;
}

fn int glnvgMaxVertCount(NvgPath* paths, int npaths) @local {
	int count = 0;
	for (int i = 0; i < npaths; i++) {
		count += paths[i].nfill;
		count += paths[i].nstroke;
	}
	return count;
}

fn GlCall* glnvgAllocCall(GlContext* gl) @local {
	if (gl.ncalls + 1 > gl.ccalls) {
		int ccalls = math::max(gl.ncalls + 1, 128) + gl.ccalls / 2;
		GlCall* calls = mem::realloc(gl.calls, GlCall::size * ccalls);
		if (calls == null) return null;
		gl.calls = calls;
		gl.ccalls = ccalls;
	}
	GlCall* ret = &gl.calls[gl.ncalls++];
	mem::clear(ret, GlCall::size);
	return ret;
}

fn int glnvgAllocPaths(GlContext* gl, int n) @local {
	if (gl.npaths + n > gl.cpaths) {
		int cpaths = math::max(gl.npaths + n, 128) + gl.cpaths / 2;
		GlPath* paths = mem::realloc(gl.paths, GlPath::size * cpaths);
		if (paths == null) return -1;
		gl.paths = paths;
		gl.cpaths = cpaths;
	}
	int ret = gl.npaths;
	gl.npaths += n;
	return ret;
}

fn int glnvgAllocVerts(GlContext* gl, int n) @local {
	if (gl.nverts + n > gl.cverts) {
		int cverts = math::max(gl.nverts + n, 4096) + gl.cverts / 2;
		NvgVertex* verts = mem::realloc(gl.verts, NvgVertex::size * cverts);
		if (verts == null) return -1;
		gl.verts = verts;
		gl.cverts = cverts;
	}
	int ret = gl.nverts;
	gl.nverts += n;
	return ret;
}

fn int glnvgAllocFragUniforms(GlContext* gl, int n) @local {
	int structSize = gl.fragSize;
	if (gl.nuniforms + n > gl.cuniforms) {
		int cuniforms = math::max(gl.nuniforms + n, 128) + gl.cuniforms / 2;
		char* uniforms = mem::realloc(gl.uniforms, (sz)structSize * cuniforms);
		if (uniforms == null) return -1;
		gl.uniforms = uniforms;
		gl.cuniforms = cuniforms;
	}
	int ret = gl.nuniforms * structSize;
	gl.nuniforms += n;
	return ret;
}

fn void glnvgVset(NvgVertex* vtx, float x, float y, float u, float v) @local {
	vtx.x = x;
	vtx.y = y;
	vtx.u = u;
	vtx.v = v;
}

fn int glnvgRenderCreate(void* up) @local {
	GlContext* gl = (GlContext*)up;
	int align = 4;

	char* shaderHeader = `
		#version 150 core
		#define NANOVG_GL3 1
		#define USE_UNIFORMBUFFER 1
	`;

	char* fillVertShader = `
		#ifdef NANOVG_GL3
			uniform vec2 viewSize;
			in vec2 vertex;
			in vec2 tcoord;
			out vec2 ftcoord;
			out vec2 fpos;
		#else
			uniform vec2 viewSize;
			attribute vec2 vertex;
			attribute vec2 tcoord;
			varying vec2 ftcoord;
			varying vec2 fpos;
		#endif
		void main(void) {
			ftcoord = tcoord;
			fpos = vertex;
			gl_Position = vec4(2.0*vertex.x/viewSize.x - 1.0, 1.0 - 2.0*vertex.y/viewSize.y, 0, 1);
		}
	`;

	char* fillFragShader = `
		#ifdef GL_ES
		#if defined(GL_FRAGMENT_PRECISION_HIGH) || defined(NANOVG_GL3)
		 precision highp float;
		#else
		 precision mediump float;
		#endif
		#endif
		#ifdef NANOVG_GL3
		#ifdef USE_UNIFORMBUFFER
			layout(std140) uniform frag {
				mat3 scissorMat;
				mat3 paintMat;
				vec4 innerCol;
				vec4 outerCol;
				vec2 scissorExt;
				vec2 scissorScale;
				vec2 extent;
				float radius;
				float feather;
				float strokeMult;
				float strokeThr;
				int texType;
				int type;
			};
		#else
			uniform vec4 frag[UNIFORMARRAY_SIZE];
		#endif
			uniform sampler2D tex;
			in vec2 ftcoord;
			in vec2 fpos;
			out vec4 outColor;
		#else
			uniform vec4 frag[UNIFORMARRAY_SIZE];
			uniform sampler2D tex;
			varying vec2 ftcoord;
			varying vec2 fpos;
		#endif
		#ifndef USE_UNIFORMBUFFER
			#define scissorMat mat3(frag[0].xyz, frag[1].xyz, frag[2].xyz)
			#define paintMat mat3(frag[3].xyz, frag[4].xyz, frag[5].xyz)
			#define innerCol frag[6]
			#define outerCol frag[7]
			#define scissorExt frag[8].xy
			#define scissorScale frag[8].zw
			#define extent frag[9].xy
			#define radius frag[9].z
			#define feather frag[9].w
			#define strokeMult frag[10].x
			#define strokeThr frag[10].y
			#define texType int(frag[10].z)
			#define type int(frag[10].w)
		#endif

		float sdroundrect(vec2 pt, vec2 ext, float rad) {
			vec2 ext2 = ext - vec2(rad,rad);
			vec2 d = abs(pt) - ext2;
			return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rad;
		}

		float scissorMask(vec2 p) {
			vec2 sc = (abs((scissorMat * vec3(p,1.0)).xy) - scissorExt);
			sc = vec2(0.5,0.5) - sc * scissorScale;
			return clamp(sc.x,0.0,1.0) * clamp(sc.y,0.0,1.0);
		}
		#ifdef EDGE_AA
		float strokeMask() {
			return min(1.0, (1.0-abs(ftcoord.x*2.0-1.0))*strokeMult) * min(1.0, ftcoord.y);
		}
		#endif

		void main(void) {
			vec4 result;
			float scissor = scissorMask(fpos);
		#ifdef EDGE_AA
			float strokeAlpha = strokeMask();
			if (strokeAlpha < strokeThr) discard;
		#else
			float strokeAlpha = 1.0;
		#endif
			if (type == 0) {
				vec2 pt = (paintMat * vec3(fpos,1.0)).xy;
				float d = clamp((sdroundrect(pt, extent, radius) + feather*0.5) / feather, 0.0, 1.0);
				vec4 color = mix(innerCol,outerCol,d);
				color *= strokeAlpha * scissor;
				result = color;
			} else if (type == 1) {
				vec2 pt = (paintMat * vec3(fpos,1.0)).xy / extent;
		#ifdef NANOVG_GL3
				vec4 color = texture(tex, pt);
		#else
				vec4 color = texture2D(tex, pt);
		#endif
				if (texType == 1) color = vec4(color.xyz*color.w,color.w);
				if (texType == 2) color = vec4(color.x);
				color *= innerCol;
				color *= strokeAlpha * scissor;
				result = color;
			} else if (type == 2) {
				result = vec4(1,1,1,1);
			} else if (type == 3) {
		#ifdef NANOVG_GL3
				vec4 color = texture(tex, ftcoord);
		#else
				vec4 color = texture2D(tex, ftcoord);
		#endif
				if (texType == 1) color = vec4(color.xyz*color.w,color.w);
				if (texType == 2) color = vec4(color.x);
				color *= scissor;
				result = color * innerCol;
			}
		#ifdef NANOVG_GL3
			outColor = result;
		#else
			gl_FragColor = result;
		#endif
		}
	`;

	glnvgCheckError(gl, "init");

	if (gl.flags & NVG_ANTIALIAS) {
		if (glnvgCreateShader(&gl.shader, "shader", shaderHeader, "#define EDGE_AA 1\n", fillVertShader, fillFragShader) == 0) {
			return 0;
		}
	}
	else {
		if (glnvgCreateShader(&gl.shader, "shader", shaderHeader, null, fillVertShader, fillFragShader) == 0) {
			return 0;
		}
	}

	glnvgCheckError(gl, "uniform locations");
	glnvgGetUniforms(&gl.shader);

	gl::genVertexArrays(1, &gl.vertArr);
	gl::genBuffers(1, &gl.vertBuf);

	gl::uniformBlockBinding(gl.shader.prog, (GLuint) gl.shader.loc[GlNvgLoc.FRAG], GLNVG_FRAG_BINDING);
	gl::genBuffers(1, &gl.fragBuf);
	gl::getIntegerv(gl::GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &align);
	gl.fragSize = (int)(GlFragUniforms::size) + align - (int)(GlFragUniforms::size) % align;

	gl.dummyTex = glnvgRenderCreateTexture(gl, TextureType.ALPHA, 1, 1, 0, null);

	glnvgCheckError(gl, "create done");

	return 1;
}

fn int glnvgRenderCreateTexture(void* up, TextureType type, int w, int h, int imageFlags, char* data) @local {
	GlContext* gl = (GlContext*)up;
	GlTexture* tex = glnvgAllocTexture(gl);

	if (tex == null) return 0;

	gl::genTextures(1, &tex.tex);
	tex.width = w;
	tex.height = h;
	tex.type = type;
	tex.flags = imageFlags;
	glnvgBindTexture(gl, tex.tex);

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 1);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, tex.width);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, 0);

	if (type == TextureType.RGBA) {
		gl::texImage2D(gl::GL_TEXTURE_2D, 0, (GLint) gl::GL_RGBA, w, h, 0, (GLint) gl::GL_RGBA, gl::GL_UNSIGNED_BYTE, data);
	}
	else {
		gl::texImage2D(gl::GL_TEXTURE_2D, 0, (GLint) gl::GL_RED, w, h, 0, (GLint) gl::GL_RED, gl::GL_UNSIGNED_BYTE, data);
	}

	if (imageFlags & microvg::IMAGE_GENERATE_MIPMAPS) {
		if (imageFlags & microvg::IMAGE_NEAREST) {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, (GLint) gl::GL_NEAREST_MIPMAP_NEAREST);
		}
		else {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, (GLint) gl::GL_LINEAR_MIPMAP_LINEAR);
		}
	}
	else {
		if (imageFlags & microvg::IMAGE_NEAREST) {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, (GLint) gl::GL_NEAREST);
		}
		else {
			gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, (GLint) gl::GL_LINEAR);
		}
	}

	if (imageFlags & microvg::IMAGE_NEAREST) {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, (GLint) gl::GL_NEAREST);
	}
	else {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, (GLint) gl::GL_LINEAR);
	}

	if (imageFlags & microvg::IMAGE_REPEATX) {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, (GLint) gl::GL_REPEAT);
	}
	else {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, (GLint) gl::GL_CLAMP_TO_EDGE);
	}

	if (imageFlags & microvg::IMAGE_REPEATY) {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, (GLint) gl::GL_REPEAT);
	}
	else {
		gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, (GLint) gl::GL_CLAMP_TO_EDGE);
	}

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 4);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, 0);

	if (imageFlags & microvg::IMAGE_GENERATE_MIPMAPS) gl::generateMipmap(gl::GL_TEXTURE_2D);

	glnvgCheckError(gl, "create tex");
	glnvgBindTexture(gl, 0);

	return tex.id;
}

fn int glnvgRenderDeleteTexture(void* up, int image) @local {
	GlContext* gl = (GlContext*)up;
	return glnvgDeleteTexture(gl, image);
}

fn int glnvgRenderUpdateTexture(void* up, int image, int x, int y, int w, int h, char* data) @local {
	GlContext* gl = (GlContext*)up;
	GlTexture* tex = glnvgFindTexture(gl, image);

	if (tex == null) return 0;
	glnvgBindTexture(gl, tex.tex);

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 1);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, tex.width);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, x);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, y);

	if (tex.type == TextureType.RGBA) {
		gl::texSubImage2D(gl::GL_TEXTURE_2D, 0, x, y, w, h, (GLint) gl::GL_RGBA, gl::GL_UNSIGNED_BYTE, data);
	}
	else {
		gl::texSubImage2D(gl::GL_TEXTURE_2D, 0, x, y, w, h, (GLint) gl::GL_RED, gl::GL_UNSIGNED_BYTE, data);
	}

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 4);
	gl::pixelStorei(gl::GL_UNPACK_ROW_LENGTH, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_PIXELS, 0);
	gl::pixelStorei(gl::GL_UNPACK_SKIP_ROWS, 0);

	glnvgBindTexture(gl, 0);

	return 1;
}

fn int glnvgRenderGetTextureSize(void* up, int image, int* w, int* h) @local {
	GlContext* gl = (GlContext*)up;
	GlTexture* tex = glnvgFindTexture(gl, image);
	if (tex == null) return 0;
	*w = tex.width;
	*h = tex.height;
	return 1;
}

fn void glnvgRenderViewport(void* up, float width, float height, float devicePixelRatio) @local {
	GlContext* gl = (GlContext*)up;
	gl.view.x = width;
	gl.view.y = height;
}

fn void glnvgRenderFlush(void* up) @local {
	GlContext* gl = (GlContext*)up;

	if (gl.ncalls > 0) {

		gl::useProgram(gl.shader.prog);

		gl::enable(gl::GL_CULL_FACE);
		gl::cullFace(gl::GL_BACK);
		gl::frontFace(gl::GL_CCW);
		gl::enable(gl::GL_BLEND);
		gl::disable(gl::GL_DEPTH_TEST);
		gl::disable(gl::GL_SCISSOR_TEST);
		gl::colorMask(gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE, gl::GL_TRUE);
		gl::stencilMask(0xffffffff);
		gl::stencilOp(gl::GL_KEEP, gl::GL_KEEP, gl::GL_KEEP);
		gl::stencilFunc(gl::GL_ALWAYS, 0, 0xffffffff);
		gl::activeTexture(gl::GL_TEXTURE0);
		gl::bindTexture(gl::GL_TEXTURE_2D, 0);
		gl.boundTexture = (GLuint)0;
		gl.stencilMask = (GLuint)0xffffffff;
		gl.stencilFunc = gl::GL_ALWAYS;
		gl.stencilFuncRef = (GLint)0;
		gl.stencilFuncMask = (GLuint)0xffffffff;
		gl.blendFunc.srcRGB = gl::GL_INVALID_ENUM;
		gl.blendFunc.srcAlpha = gl::GL_INVALID_ENUM;
		gl.blendFunc.dstRGB = gl::GL_INVALID_ENUM;
		gl.blendFunc.dstAlpha = gl::GL_INVALID_ENUM;

		gl::bindBuffer(gl::GL_UNIFORM_BUFFER, gl.fragBuf);
		gl::bufferData(gl::GL_UNIFORM_BUFFER, (gl::GLsizeiptr)(gl.nuniforms * gl.fragSize), gl.uniforms, gl::GL_STREAM_DRAW);

		gl::bindVertexArray(gl.vertArr);
		gl::bindBuffer(gl::GL_ARRAY_BUFFER, gl.vertBuf);
		gl::bufferData(gl::GL_ARRAY_BUFFER, (gl::GLsizeiptr)(gl.nverts * NvgVertex::size), gl.verts, gl::GL_STREAM_DRAW);
		gl::enableVertexAttribArray(0);
		gl::enableVertexAttribArray(1);
		gl::vertexAttribPointer(0, 2, gl::GL_FLOAT, gl::GL_FALSE, NvgVertex::size, (void*)(usz)0);
		gl::vertexAttribPointer(1, 2, gl::GL_FLOAT, gl::GL_FALSE, NvgVertex::size, (void*)(usz)(2 * float::size));

		gl::uniform1i(gl.shader.loc[(GlNvgLoc.TEX)], 0);
		gl::uniform2fv(gl.shader.loc[(GlNvgLoc.VIEWSIZE)], 1, &gl.view[0]);

		gl::bindBuffer(gl::GL_UNIFORM_BUFFER, gl.fragBuf);

		for (int i = 0; i < gl.ncalls; i++) {
			GlCall* call = &gl.calls[i];
			glnvgBlendFuncSeparate(gl, &call.blendFunc);
			if (call.type == (GlNvgCallType.FILL)) {
				glnvgFill(gl, call);
			}
			else if (call.type == (GlNvgCallType.CONVEXFILL)) {
				glnvgConvexFill(gl, call);
			}
			else if (call.type == (GlNvgCallType.STROKE)) {
				glnvgStroke(gl, call);
			}
			else if (call.type == (GlNvgCallType.TRIANGLES)) {
				glnvgTriangles(gl, call);
			}
		}

		gl::disableVertexAttribArray(0);
		gl::disableVertexAttribArray(1);
		gl::bindVertexArray(0);
		gl::disable(gl::GL_CULL_FACE);
		gl::bindBuffer(gl::GL_ARRAY_BUFFER, 0);
		gl::useProgram(0);
		glnvgBindTexture(gl, 0);
	}

	gl.nverts = 0;
	gl.npaths = 0;
	gl.ncalls = 0;
	gl.nuniforms = 0;
}

fn void glnvgRenderFill(void* up, NvgPaint* paint, NvgCompositeOperationState compositeOperation, NvgScissor* scissor, float fringe, float* bounds, NvgPath* paths, int npaths) @local {
	GlContext* gl = (GlContext*)up;
	GlCall* call = glnvgAllocCall(gl);
	NvgVertex* quad;
	GlFragUniforms* frag;
	int maxverts, offset;

	if (call == null) return;

	call.type = (GlNvgCallType.FILL);
	call.triangleCount = 4;
	call.pathOffset = glnvgAllocPaths(gl, npaths);
	if (call.pathOffset == -1) {
		if (gl.ncalls > 0) gl.ncalls--;
		return;
	}
	call.pathCount = npaths;
	call.image = paint.image;
	call.blendFunc = glnvgBlendCompositeOperation(compositeOperation);

	if (npaths == 1 && paths[0].convex) {
		call.type = (GlNvgCallType.CONVEXFILL);
		call.triangleCount = 0;
	}

	maxverts = glnvgMaxVertCount(paths, npaths) + call.triangleCount;
	offset = glnvgAllocVerts(gl, maxverts);
	if (offset == -1) {
		if (gl.ncalls > 0) gl.ncalls--;
		return;
	}

	for (int i = 0; i < npaths; i++) {
		GlPath* copy = &gl.paths[call.pathOffset + i];
		NvgPath* path = &paths[i];
		mem::clear(copy, GlPath::size);
		if (path.nfill > 0) {
			copy.fillOffset = offset;
			copy.fillCount = path.nfill;
			mem::copy(&gl.verts[offset], path.fill, NvgVertex::size * path.nfill);
			offset += path.nfill;
		}
		if (path.nstroke > 0) {
			copy.strokeOffset = offset;
			copy.strokeCount = path.nstroke;
			mem::copy(&gl.verts[offset], path.stroke, NvgVertex::size * path.nstroke);
			offset += path.nstroke;
		}
	}

	if (call.type == (GlNvgCallType.FILL)) {
		call.triangleOffset = offset;
		quad = &gl.verts[call.triangleOffset];
		glnvgVset(&quad[0], bounds[2], bounds[3], 0.5f, 1.0f);
		glnvgVset(&quad[1], bounds[2], bounds[1], 0.5f, 1.0f);
		glnvgVset(&quad[2], bounds[0], bounds[3], 0.5f, 1.0f);
		glnvgVset(&quad[3], bounds[0], bounds[1], 0.5f, 1.0f);

		call.uniformOffset = glnvgAllocFragUniforms(gl, 2);
		if (call.uniformOffset == -1) {
			if (gl.ncalls > 0) gl.ncalls--;
			return;
		}
		frag = glnvgFragUniformPtr(gl, call.uniformOffset);
		mem::clear(frag, GlFragUniforms::size);
		frag.strokeThr = -1.0f;
		frag.type = (NsvgShader.SIMPLE);
		glnvgConvertPaint(gl, glnvgFragUniformPtr(gl, call.uniformOffset + gl.fragSize), paint, scissor, fringe, fringe, -1.0f);
	}
	else {
		call.uniformOffset = glnvgAllocFragUniforms(gl, 1);
		if (call.uniformOffset == -1) {
			if (gl.ncalls > 0) gl.ncalls--;
			return;
		}
		glnvgConvertPaint(gl, glnvgFragUniformPtr(gl, call.uniformOffset), paint, scissor, fringe, fringe, -1.0f);
	}
}

fn void glnvgRenderStroke(void* up, NvgPaint* paint, NvgCompositeOperationState compositeOperation, NvgScissor* scissor, float fringe, float strokeWidth, NvgPath* paths, int npaths) @local {
	GlContext* gl = (GlContext*)up;
	GlCall* call = glnvgAllocCall(gl);
	int maxverts, offset;

	if (call == null) return;

	call.type = (GlNvgCallType.STROKE);
	call.pathOffset = glnvgAllocPaths(gl, npaths);
	if (call.pathOffset == -1) {
		if (gl.ncalls > 0) gl.ncalls--;
		return;
	}
	call.pathCount = npaths;
	call.image = paint.image;
	call.blendFunc = glnvgBlendCompositeOperation(compositeOperation);

	maxverts = glnvgMaxVertCount(paths, npaths);
	offset = glnvgAllocVerts(gl, maxverts);
	if (offset == -1) {
		if (gl.ncalls > 0) gl.ncalls--;
		return;
	}

	for (int i = 0; i < npaths; i++) {
		GlPath* copy = &gl.paths[call.pathOffset + i];
		NvgPath* path = &paths[i];
		mem::clear(copy, GlPath::size);
		if (path.nstroke) {
			copy.strokeOffset = offset;
			copy.strokeCount = path.nstroke;
			mem::copy(&gl.verts[offset], path.stroke, NvgVertex::size * path.nstroke);
			offset += path.nstroke;
		}
	}

	if (gl.flags & NVG_STENCIL_STROKES) {
		call.uniformOffset = glnvgAllocFragUniforms(gl, 2);
		if (call.uniformOffset == -1) {
			if (gl.ncalls > 0) gl.ncalls--;
			return;
		}

		glnvgConvertPaint(gl, glnvgFragUniformPtr(gl, call.uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
		glnvgConvertPaint(gl, glnvgFragUniformPtr(gl, call.uniformOffset + gl.fragSize), paint, scissor, strokeWidth, fringe, 1.0f - 0.5f / 255.0f);
	}
	else {
		call.uniformOffset = glnvgAllocFragUniforms(gl, 1);
		if (call.uniformOffset == -1) {
			if (gl.ncalls > 0) gl.ncalls--;
			return;
		}
		glnvgConvertPaint(gl, glnvgFragUniformPtr(gl, call.uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
	}
}

fn void glnvgRenderTriangles(void* up, NvgPaint* paint, NvgCompositeOperationState compositeOperation, NvgScissor* scissor, NvgVertex* verts, int nverts, float fringe) @local {
	GlContext* gl = (GlContext*)up;
	GlCall* call = glnvgAllocCall(gl);
	GlFragUniforms* frag;

	if (call == null) return;

	call.type = (GlNvgCallType.TRIANGLES);
	call.image = paint.image;
	call.blendFunc = glnvgBlendCompositeOperation(compositeOperation);

	call.triangleOffset = glnvgAllocVerts(gl, nverts);
	if (call.triangleOffset == -1) {
		if (gl.ncalls > 0) gl.ncalls--;
		return;
	}
	call.triangleCount = nverts;

	mem::copy(&gl.verts[call.triangleOffset], verts, NvgVertex::size * nverts);

	call.uniformOffset = glnvgAllocFragUniforms(gl, 1);
	if (call.uniformOffset == -1) {
		if (gl.ncalls > 0) gl.ncalls--;
		return;
	}
	frag = glnvgFragUniformPtr(gl, call.uniformOffset);
	glnvgConvertPaint(gl, frag, paint, scissor, 1.0f, fringe, -1.0f);
	frag.type = (NsvgShader.IMG);
}

fn void glnvgRenderDelete(void* up) @local {
	GlContext* gl = (GlContext*)up;
	if (gl == null) return;

	glnvgDeleteShader(&gl.shader);

	if (gl.fragBuf != 0) gl::deleteBuffers(1, &gl.fragBuf);
	if (gl.vertArr != 0) gl::deleteVertexArrays(1, &gl.vertArr);
	if (gl.vertBuf != 0) gl::deleteBuffers(1, &gl.vertBuf);

	for (int i = 0; i < gl.ntextures; i++) {
		if (gl.textures[i].tex != 0 && (gl.textures[i].flags & NVG_IMAGE_NODELETE) == 0) {
			gl::deleteTextures(1, &gl.textures[i].tex);
		}
	}
	mem::free(gl.textures);

	mem::free(gl.paths);
	mem::free(gl.verts);
	mem::free(gl.uniforms);
	mem::free(gl.calls);

	mem::free(gl);
}

fn NvgContext* nvgCreateGl3(int flags) {
	NvgParams params;
	NvgContext* ctx = null;
	GlContext* gl = mem::calloc(GlContext::size);
	if (gl == null) return null;

	mem::clear(&params, NvgParams::size);
	params.renderCreate = &glnvgRenderCreate;
	params.renderCreateTexture = &glnvgRenderCreateTexture;
	params.renderDeleteTexture = &glnvgRenderDeleteTexture;
	params.renderUpdateTexture = &glnvgRenderUpdateTexture;
	params.renderGetTextureSize = &glnvgRenderGetTextureSize;
	params.renderViewport = &glnvgRenderViewport;
	params.renderCancel = &glnvgRenderCancel;
	params.renderFlush = &glnvgRenderFlush;
	params.renderFill = &glnvgRenderFill;
	params.renderStroke = &glnvgRenderStroke;
	params.renderTriangles = &glnvgRenderTriangles;
	params.renderDelete = &glnvgRenderDelete;
	params.userPtr = gl;
	params.edgeAntiAlias = (flags & NVG_ANTIALIAS) ? 1 : 0;

	gl.flags = flags;

	ctx = microvg::nvgCreateInternal(&params);
	if (ctx == null) return null;

	return ctx;
}
