package microvg.shader

const val BLUR_FRAG = """
	
	#version 330 core
	
	in vec2 vUv;
	out vec4 fragColor;
	
	uniform sampler2D uTexture;
	uniform vec2 uDir;
	uniform int uRadius;
	
	void main() {
	    vec3 color = vec3(0.0);
	    float total = 0.0;
	
	    float sigma = max(uRadius / 2.0, 0.1);
	
	    for (int i = -uRadius; i <= uRadius; i++) {
	        float weight = exp(-0.5 * (i / sigma) * (i / sigma));
	        color += texture(uTexture, vUv + uDir * i).rgb * weight;
	        total += weight;
	    }
	
	    fragColor = vec4(color / total, 1.0);
	}

"""

const val BLUR_VERT = """
	
	#version 330 core
	
	layout (location = 0) in vec2 aPos;
	
	out vec2 vUv;
	
	void main() {
	    vUv = aPos * 0.5 + 0.5;
	    gl_Position = vec4(aPos, 0.0, 1.0);
	}

"""
