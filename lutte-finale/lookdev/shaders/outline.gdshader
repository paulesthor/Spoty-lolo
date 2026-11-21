shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform float outline = 1.0;
uniform float outline_px = 1.5;
uniform vec4 ink : source_color = vec4(0.07,0.06,0.05,1.0);
void vertex() { POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0); }
float lin_depth(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 o = outline_px / VIEWPORT_SIZE;
	float d0 = lin_depth(uv, INV_PROJECTION_MATRIX);
	float d1 = lin_depth(uv + vec2(o.x, 0.0), INV_PROJECTION_MATRIX);
	float d2 = lin_depth(uv - vec2(o.x, 0.0), INV_PROJECTION_MATRIX);
	float d3 = lin_depth(uv + vec2(0.0, o.y), INV_PROJECTION_MATRIX);
	float d4 = lin_depth(uv - vec2(0.0, o.y), INV_PROJECTION_MATRIX);
	float dd = abs(d1 + d2 + d3 + d4 - 4.0 * d0) / max(d0, 0.001);
	vec3 n0 = texture(normal_tex, uv).xyz * 2.0 - 1.0;
	vec3 n1 = texture(normal_tex, uv + vec2(o.x, 0.0)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, uv + vec2(0.0, o.y)).xyz * 2.0 - 1.0;
	float nd = (1.0 - dot(n0, n1)) + (1.0 - dot(n0, n2));
	float fade = 1.0 - smoothstep(35.0, 110.0, d0);
	float edge = max(smoothstep(0.06, 0.16, dd), smoothstep(0.3, 0.7, nd)) * fade * outline;
	ALBEDO = ink.rgb;
	ALPHA = clamp(edge, 0.0, 1.0);
}
