shader_type spatial;
render_mode cull_disabled;
// waving cloth (the plane's UV.x runs from the free end to the pole): the pole edge stays still, the free end ripples more and more
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float phase = 0.0;
uniform float amp = 0.16;
uniform float speed = 5.0;
uniform float waves = 2.2;
varying float u_along;
void vertex() {
	float u = 1.0 - UV.x;
	u_along = u;
	float w = sin(u * waves * 6.2832 - TIME * speed + phase);
	VERTEX.x += w * amp * u;
	VERTEX.y += cos(u * waves * 3.1416 - TIME * speed * 0.7 + phase) * amp * 0.25 * u;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.0, 0.0));
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	// folds: darker in the troughs of the wave
	float fold = 0.82 + 0.18 * sin(u_along * waves * 6.2832 - TIME * speed + phase + 1.2);
	ALBEDO = c * fold;
	ROUGHNESS = 0.9;
}
