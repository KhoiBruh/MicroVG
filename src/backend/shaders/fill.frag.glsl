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
	in vec4 fstroke;
	out vec4 outColor;
#else
	uniform sampler2D tex;
	varying vec2 ftcoord;
	varying vec2 fpos;
	varying vec4 fstroke;
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

float scissorCoverage(vec2 p) {
	vec2 sc = (abs((scissorMat * vec3(p,1.0)).xy) - scissorExt);
	sc = vec2(0.5,0.5) - sc * scissorScale;
	return clamp(sc.x,0.0,1.0) * clamp(sc.y,0.0,1.0);
}
#ifdef EDGE_AA
float bodyStrokeCoverage() {
	return min(1.0, (1.0-abs(ftcoord.x*2.0-1.0))*strokeMult) * min(1.0, ftcoord.y);
}

float roundStrokeCoverage() {
	if (fstroke.z <= 0.0) return 1.0;
	float inner = fstroke.z * (strokeMult - 0.5);
	float outer = fstroke.z * (strokeMult + 0.5);
	return 1.0 - smoothstep(inner, outer, length(fpos - fstroke.xy));
}
#endif

vec4 paintColor() {
	if (type == 0) {
		vec2 pt = (paintMat * vec3(fpos,1.0)).xy;
		float d;
		if (texType == 0) {
			d = clamp(pt.x / max(extent.x, 1e-6), 0.0, 1.0);
		} else if (texType == 1) {
			float dist = length(pt);
			d = clamp((dist - radius + feather * 0.5) / feather, 0.0, 1.0);
		} else {
			d = clamp((sdroundrect(pt, extent, radius) + feather*0.5) / feather, 0.0, 1.0);
		}
		vec4 color = mix(innerCol,outerCol,d);
		return color;
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
		return color;
	} else if (type == 2) {
		return vec4(1,1,1,1);
	} else if (type == 3) {
#ifdef NANOVG_GL3
		vec4 color = texture(tex, ftcoord);
#else
		vec4 color = texture2D(tex, ftcoord);
#endif
		if (texType == 1) color = vec4(color.xyz*color.w,color.w);
		if (texType == 2) color = vec4(color.x);
		return color * innerCol;
	}
	return vec4(0,0,0,0);
}

void main(void) {
	vec4 result = paintColor();
	float scissor = scissorCoverage(fpos);
#ifdef EDGE_AA
	float strokeCoverage = fstroke.w > 0.5 ? roundStrokeCoverage() : bodyStrokeCoverage();
	if (fstroke.w <= 0.5 && strokeCoverage < strokeThr) discard;
	if (type == 0 || type == 1) result *= strokeCoverage;
#endif
	if (type != 2) result *= scissor;
#ifdef NANOVG_GL3
	outColor = result;
#else
	gl_FragColor = result;
#endif
}
