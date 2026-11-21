shader_type sky;
// Stylised poster sky: smooth gradient, soft sun halo, flat-shaded clouds with crisp edges, stars at night.
uniform vec3 top_col : source_color = vec3(0.3, 0.42, 0.6);
uniform vec3 horizon_col : source_color = vec3(0.95, 0.72, 0.5);
uniform vec3 ground_col : source_color = vec3(0.45, 0.4, 0.38);
uniform vec3 cloud_col : source_color = vec3(1.0, 0.92, 0.82);
uniform vec3 cloud_shadow : source_color = vec3(0.7, 0.6, 0.62);
uniform float cloud_amount = 0.75;
uniform float cloud_scale = 1.4;
uniform float stars = 0.0;
uniform vec2 offset = vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_col, top_col, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) col = mix(horizon_col, ground_col, clamp(-h * 5.0, 0.0, 1.0));
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (smoothstep(0.9993, 0.9996, sd) * 2.0 + pow(sd, 12.0) * 0.35) * (1.0 - stars);
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * cloud_scale + offset;
		float n = fbm(uv);
		float c = smoothstep(0.52, 0.56, n) * cloud_amount * smoothstep(0.0, 0.18, h);
		float lit = smoothstep(0.52, 0.75, fbm(uv + vec2(0.06, 0.04)));
		vec3 cc = mix(cloud_col, cloud_shadow, lit * 0.8);
		col = mix(col, cc, c);
		if (stars > 0.0) {
			vec2 g = floor(d.xz / max(h, 0.05) * 90.0);
			float s = step(0.996, hash(g)) * smoothstep(0.1, 0.4, h) * (1.0 - c);
			col += vec3(s) * stars;
		}
	}
	COLOR = col;
}
