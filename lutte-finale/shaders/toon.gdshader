shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool has_tex = true;
uniform float shade_floor = 0.42;
uniform float rim_amount = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float sat = 1.0;
void fragment() {
	vec3 c = has_tex ? texture(tex, UV).rgb * tint.rgb : tint.rgb;
	float l = dot(c, vec3(0.299,0.587,0.114));
	ALBEDO = mix(vec3(l), c, sat);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float d = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = smoothstep(0.0, 0.04, d) * smoothstep(0.3, 0.45, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shade_floor, 1.0, lit);
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * lit;
		SPECULAR_LIGHT += rim_color.rgb * step(0.5, rim) * rim_amount * LIGHT_COLOR / PI;
	} else {
		float lit = smoothstep(0.0, 0.05, d) * smoothstep(0.05, 0.2, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * 0.6;
	}
}
