shader_type canvas_item;
// "Affiche de propagande" grade: warm paper highlights, cool ink shadows, reds pushed,
// gentle vignette and animated print grain. Drawn under the HUD.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation = 1.06;
uniform float contrast = 1.08;
uniform vec3 shadow_tint = vec3(0.86, 0.88, 1.06);
uniform vec3 light_tint = vec3(1.07, 1.0, 0.88);
uniform float red_boost = 0.18;
uniform float vignette = 0.28;
uniform float grain = 0.03;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	float redness = clamp((c.r - max(c.g, c.b)) * 2.5, 0.0, 1.0);
	c = mix(c, c * vec3(1.0 + red_boost, 1.0 - red_boost * 0.4, 1.0 - red_boost * 0.4), redness);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_tint, light_tint, smoothstep(0.05, 0.85, l));
	float v = smoothstep(0.95, 0.3, length((uv - 0.5) * vec2(1.45, 1.0)));
	c *= mix(1.0 - vignette, 1.0, v);
	c += (hash(FRAGCOORD.xy + fract(TIME * 7.0) * 100.0) - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
