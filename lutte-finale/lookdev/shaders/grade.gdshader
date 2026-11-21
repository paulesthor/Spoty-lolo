shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0;
uniform vec4 ink : source_color = vec4(0.07,0.06,0.05,1.0);
uniform vec4 paper : source_color = vec4(0.93,0.87,0.74,1.0);
uniform vec4 red : source_color = vec4(0.80,0.07,0.14,1.0);
uniform vec4 gold : source_color = vec4(0.88,0.66,0.15,1.0);
uniform float vignette = 0.25;
uniform float grain = 0.0;
uniform float aberration = 0.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	if (aberration > 0.0) {
		vec2 dir = (uv - 0.5) * aberration;
		c = vec3(texture(screen_tex, uv + dir).r, texture(screen_tex, uv).g, texture(screen_tex, uv - dir).b);
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (mode == 1) {
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float s = (mx - mn) / (mx + 0.0001);
		float redness = smoothstep(0.58, 0.4, max(c.g, c.b) / max(c.r, 0.001)) * smoothstep(0.25, 0.42, c.r);
		float goldness = smoothstep(0.3, 0.18, c.b / max(c.r, 0.001)) * smoothstep(0.55, 0.7, c.g / max(c.r, 0.001)) * smoothstep(0.4, 0.6, c.r) * (1.0 - redness);
		float lp = clamp((l - 0.12) * 1.45, 0.0, 1.0);
		lp = floor(lp * 4.0 + 0.5) / 4.0;
		vec3 mono = mix(ink.rgb, paper.rgb, lp);
		vec3 r = red.rgb * mix(0.6, 1.1, smoothstep(0.15, 0.7, l));
		vec3 g = gold.rgb * mix(0.65, 1.1, smoothstep(0.3, 0.8, l));
		c = mix(mono, r, redness);
		c = mix(c, g, goldness);
		vec2 cell = FRAGCOORD.xy / 6.0;
		float dotp = length(fract(cell) - 0.5);
		float shadow = 1.0 - smoothstep(0.2, 0.55, lp);
		c = mix(c, ink.rgb, step(dotp, 0.34 * shadow) * 0.4);
	} else if (mode == 2) {
		c = mix(vec3(l), c, saturation);
		c = (c - 0.5) * contrast + 0.5;
		vec2 cell = mat2(vec2(0.707,-0.707), vec2(0.707,0.707)) * FRAGCOORD.xy / 7.0;
		float dotp = length(fract(cell) - 0.5);
		float shadow = 1.0 - smoothstep(0.18, 0.5, l);
		c = mix(c, c * 0.45, step(dotp, 0.42 * shadow));
	} else {
		c = mix(vec3(l), c, saturation);
		c = (c - 0.5) * contrast + 0.5;
	}
	float v = smoothstep(0.9, 0.25, length((uv - 0.5) * vec2(1.5, 1.0)));
	c *= mix(1.0 - vignette, 1.0, v);
	c += (hash(FRAGCOORD.xy) - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
