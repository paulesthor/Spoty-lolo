shader_type spatial;
// inverted-hull ink outline (comic / poster look) for key characters
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;
uniform float width = 0.025;
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.04, 1.0);
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = ink.rgb; }
