extends Node3D
# Look-dev scene: "Hypermarché" zone, same layout rendered in several art styles.
# Usage: godot --path . -- style=A out=res://shots/a.png

var style := "A"
var out_path := "res://shots/out.png"
var frame := 0
var rng := RandomNumberGenerator.new()
var toon_shader: Shader = preload("res://shaders/toon.gdshader")
var use_toon := false
var font_main: Font
var font_num: Font
var neon := false
var cam: Camera3D
var hero: Node3D
var anim_nodes: Array = []
var serious := false
var cam_mode := "high"

const CH := "res://assets/mini-characters/"
const CC := "res://assets/city-kit-commercial/"
const CR := "res://assets/city-kit-roads/"
const CAR := "res://assets/car-kit/"
const SHOP := "res://assets/mini-shop/"
const SUB := "res://assets/city-kit-suburban/"

func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("style="): style = a.substr(6)
		if a.begins_with("out="): out_path = a.substr(4)
		if a.begins_with("cam="): cam_mode = a.substr(4)
	rng.seed = 1917
	use_toon = style in ["B", "D"]
	serious = style in ["E", "F"]
	neon = style == "C"
	match style:
		"A": font_main = load("res://fonts/Kenney Future.ttf"); font_num = load("res://fonts/Kenney Future.ttf")
		"B": font_main = load("res://fonts/RussoOne.woff2"); font_num = load("res://fonts/Oswald.woff2")
		"C": font_main = load("res://fonts/Kenney Future Narrow.ttf"); font_num = load("res://fonts/Oswald.woff2")
		"D": font_main = load("res://fonts/Bangers.woff2"); font_num = load("res://fonts/Bangers.woff2")
		_: font_main = load("res://fonts/Oswald.woff2"); font_num = load("res://fonts/Oswald.woff2")
	build_env()
	build_ground()
	build_city()
	build_actors()
	build_fx()
	build_post()
	build_hud()

func _process(_d):
	frame += 1
	if frame == 45:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		img.save_png(out_path)
		print("saved ", out_path)
		get_tree().quit()

# ---------------------------------------------------------------- helpers
func world_aabb(n: Node) -> AABB:
	var res := AABB()
	var first := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = m.global_transform * m.get_aabb()
		if first:
			res = a; first = false
		else:
			res = res.merge(a)
	return res

func spawn(path: String, pos: Vector3, height := -1.0, rot := 0.0, sc := 1.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	add_child(n)
	n.rotation.y = rot
	if height > 0.0:
		var a := world_aabb(n)
		n.scale = Vector3.ONE * (height / maxf(a.size.y, 0.001))
	else:
		n.scale = Vector3.ONE * sc
	var b := world_aabb(n)
	n.position += Vector3(pos.x - b.get_center().x, pos.y - b.position.y, pos.z - b.get_center().z)
	if use_toon:
		toonify(n)
	if neon:
		roughen(n)
	if serious and "mini-characters" in path:
		for sk in n.find_children("*", "Skeleton3D", true, false):
			var hm = load("res://head_scale.gd").new()
			hm.head_scale = 0.78
			hm.body_scale = 1.12
			sk.add_child(hm)
	if serious:
		mute(n)
	return n

func mute(n: Node):
	# slightly desaturated, rougher materials for a more grounded look
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if src is StandardMaterial3D and mi.get_surface_override_material(i) == null:
				var d: StandardMaterial3D = src.duplicate()
				d.roughness = 0.75
				d.albedo_color = d.albedo_color * Color(0.92, 0.92, 0.92)
				mi.set_surface_override_material(i, d)

func toonify(n: Node, tint := Color(1, 1, 1), sat := 1.0):
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			var sm := ShaderMaterial.new()
			sm.shader = toon_shader
			if src is StandardMaterial3D and src.albedo_texture:
				sm.set_shader_parameter("tex", src.albedo_texture)
				sm.set_shader_parameter("tint", src.albedo_color * tint)
				sm.set_shader_parameter("has_tex", true)
			else:
				sm.set_shader_parameter("has_tex", false)
				var col: Color = src.albedo_color if src is StandardMaterial3D else Color.WHITE
				sm.set_shader_parameter("tint", col * tint)
			sm.set_shader_parameter("sat", sat * (1.25 if style == "D" else 1.0))
			sm.set_shader_parameter("shade_floor", 0.5 if style == "D" else 0.38)
			mi.set_surface_override_material(i, sm)

func roughen(n: Node):
	# slightly glossy materials for the wet night look
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if src is StandardMaterial3D:
				var d: StandardMaterial3D = src.duplicate()
				d.roughness = 0.55
				mi.set_surface_override_material(i, d)

func solid(color: Color, emissive := 0.0, rough := 0.8, metal := 0.0) -> Material:
	if style == "B" and emissive > 0.0: emissive = minf(emissive, 0.5)
	if use_toon and emissive <= 0.0:
		var sm := ShaderMaterial.new()
		sm.shader = toon_shader
		sm.set_shader_parameter("has_tex", false)
		sm.set_shader_parameter("tint", color)
		sm.set_shader_parameter("shade_floor", 0.5 if style == "D" else 0.38)
		return sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m

func box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi

func sprite(tex: String, pos: Vector3, size: float, color: Color, energy := 2.0, billboard := true, rot := Vector3.ZERO) -> MeshInstance3D:
	if style == "B": energy = minf(energy, 1.0)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://fx/" + tex)
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi

func label3d(text: String, pos: Vector3, size: int, color: Color, outline_col := Color.BLACK, billboard := true, fnt: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = fnt if fnt else font_num
	l.font_size = size
	l.outline_size = int(size * 0.18)
	l.modulate = color
	l.outline_modulate = outline_col
	l.pixel_size = 0.01
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = billboard
	l.shaded = false
	l.double_sided = true
	add_child(l)
	return l

func play_anim(n: Node, anim: String, t := -1.0, speed := 1.0):
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		var p: AnimationPlayer = ap
		if p.has_animation(anim):
			p.play(anim, -1, speed)
			var length := p.current_animation_length
			p.seek(t if t >= 0.0 else rng.randf() * length, true)
			if speed == 0.0: p.pause()

# ---------------------------------------------------------------- environment
func build_env():
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.2
	match style:
		"A":
			var sky := Sky.new()
			var ps := ProceduralSkyMaterial.new()
			ps.sky_top_color = Color(0.32, 0.55, 0.86)
			ps.sky_horizon_color = Color(0.78, 0.86, 0.95)
			ps.ground_horizon_color = Color(0.78, 0.86, 0.95)
			ps.ground_bottom_color = Color(0.4, 0.45, 0.5)
			ps.sun_angle_max = 20.0
			sky.sky_material = ps
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 1.0
			env.tonemap_mode = Environment.TONE_MAPPER_AGX
			env.tonemap_exposure = 1.05
			env.ssao_enabled = true
			env.ssao_radius = 1.2
			env.ssao_intensity = 2.5
			env.glow_enabled = true
			env.glow_intensity = 0.6
			env.glow_bloom = 0.05
			env.fog_enabled = true
			env.fog_light_color = Color(0.72, 0.8, 0.92)
			env.fog_density = 0.006
			env.fog_sky_affect = 0.0
			env.adjustment_enabled = true
			env.adjustment_saturation = 1.18
			env.adjustment_contrast = 1.05
			sun.light_color = Color(1.0, 0.93, 0.82)
			sun.light_energy = 1.35
			sun.rotation_degrees = Vector3(-48, -35, 0)
		"B":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.93, 0.87, 0.74)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.85, 0.8, 0.75)
			env.ambient_light_energy = 0.55
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.fog_enabled = true
			env.fog_light_color = Color(0.86, 0.8, 0.68)
			env.fog_density = 0.0015
			env.fog_sky_affect = 0.0
			env.glow_enabled = false
			sun.light_color = Color(1, 0.97, 0.9)
			sun.light_energy = 1.25
			sun.shadow_blur = 0.3
			sun.rotation_degrees = Vector3(-38, -55, 0)
		"C":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.02, 0.02, 0.05)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.25, 0.3, 0.55)
			env.ambient_light_energy = 0.35
			env.tonemap_mode = Environment.TONE_MAPPER_AGX
			env.tonemap_exposure = 1.2
			env.glow_enabled = true
			env.glow_intensity = 1.1
			env.glow_bloom = 0.12
			env.glow_hdr_threshold = 0.9
			env.ssr_enabled = true
			env.ssr_max_steps = 48
			env.ssao_enabled = true
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.025
			env.volumetric_fog_albedo = Color(0.6, 0.65, 0.9)
			env.volumetric_fog_length = 80.0
			env.adjustment_enabled = true
			env.adjustment_contrast = 1.1
			env.adjustment_saturation = 1.1
			sun.light_color = Color(0.45, 0.55, 1.0)
			sun.light_energy = 0.35
			sun.rotation_degrees = Vector3(-35, 140, 0)
		"D":
			var sky2 := Sky.new()
			var ps2 := ProceduralSkyMaterial.new()
			ps2.sky_top_color = Color(0.1, 0.55, 0.95)
			ps2.sky_horizon_color = Color(0.6, 0.9, 1.0)
			ps2.ground_horizon_color = Color(0.6, 0.9, 1.0)
			sky2.sky_material = ps2
			env.background_mode = Environment.BG_SKY
			env.sky = sky2
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.75, 0.82, 1.0)
			env.ambient_light_energy = 0.6
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.fog_enabled = true
			env.fog_light_color = Color(0.7, 0.9, 1.0)
			env.fog_density = 0.007
			env.fog_sky_affect = 0.0
			env.glow_enabled = true
			env.glow_intensity = 0.4
			sun.light_color = Color(1, 0.96, 0.85)
			sun.light_energy = 1.2
			sun.shadow_blur = 0.2
			sun.rotation_degrees = Vector3(-50, -30, 0)
	if serious:
		var sky3 := Sky.new()
		var ps3 := ProceduralSkyMaterial.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky3
		sky3.sky_material = ps3
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 3.0
		env.ssil_enabled = true
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.fog_enabled = true
		env.fog_sky_affect = 0.3
		env.adjustment_enabled = true
		if style == "E":
			ps3.sky_top_color = Color(0.42, 0.5, 0.6)
			ps3.sky_horizon_color = Color(0.72, 0.74, 0.76)
			ps3.ground_horizon_color = Color(0.72, 0.74, 0.76)
			ps3.sky_cover_modulate = Color(1, 1, 1)
			env.ambient_light_energy = 0.9
			env.tonemap_exposure = 1.0
			env.fog_light_color = Color(0.68, 0.7, 0.73)
			env.fog_density = 0.0035
			env.adjustment_saturation = 0.82
			env.adjustment_contrast = 1.08
			sun.light_color = Color(1.0, 0.96, 0.9)
			sun.light_energy = 1.1
			sun.rotation_degrees = Vector3(-42, -30, 0)
		else:
			ps3.sky_top_color = Color(0.3, 0.42, 0.6)
			ps3.sky_horizon_color = Color(0.95, 0.72, 0.5)
			ps3.ground_horizon_color = Color(0.95, 0.72, 0.5)
			ps3.sun_angle_max = 30.0
			env.ambient_light_energy = 0.7
			env.tonemap_exposure = 1.05
			env.fog_light_color = Color(0.8, 0.68, 0.58)
			env.fog_density = 0.004
			env.adjustment_saturation = 0.92
			env.adjustment_contrast = 1.12
			sun.light_color = Color(1.0, 0.72, 0.45)
			sun.light_energy = 1.6
			sun.rotation_degrees = Vector3(-17, -60, 0)
			sun.directional_shadow_max_distance = 120.0
	we.environment = env
	add_child(we)
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 68
	cam.position = Vector3(0.6, 3.4, 6.2)
	var target := Vector3(0, 1.0, -9)
	if serious:
		cam.fov = 55
		if cam_mode == "high":
			cam.position = Vector3(0, 10.5, 12.5); target = Vector3(0, 0.0, -6.0)
		else:
			cam.position = Vector3(0, 7.5, 10.5); target = Vector3(0, 0.3, -6.5)
	add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.make_current()

# ---------------------------------------------------------------- ground
func build_ground():
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(260, 260)
	g.mesh = pm
	var col := Color(0.42, 0.43, 0.46)
	if style == "B": col = Color(0.55, 0.52, 0.47)
	if style == "C": col = Color(0.06, 0.065, 0.08)
	if style == "D": col = Color(0.5, 0.52, 0.58)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new(); fn.frequency = 0.02
	nt.noise = fn; nt.seamless = true; nt.width = 512; nt.height = 512
	var gr := Gradient.new(); gr.set_color(0, Color(0.86, 0.86, 0.86)); gr.set_color(1, Color(1, 1, 1)); nt.color_ramp = gr
	m.albedo_texture = nt
	m.uv1_scale = Vector3(30, 30, 30)
	m.roughness = 0.18 if neon else 0.95
	g.material_override = solid(col) if use_toon else m
	add_child(g)
	# parking lines and sidewalk curbs
	var line_col := Color(0.92, 0.9, 0.82) if style != "C" else Color(0.7, 0.72, 0.8)
	var lm := solid(line_col, 0.0, 0.9)
	for row in [-14.0, -26.0]:
		for i in range(-9, 10):
			box(Vector3(0.12, 0.02, 4.2), Vector3(i * 2.8, 0.01, row), lm)
	for i in range(-12, 13):
		box(Vector3(1.4, 0.02, 0.18), Vector3(i * 3.0, 0.01, -3.0), lm)
	var curb := solid(Color(0.7, 0.69, 0.66) if style != "C" else Color(0.15, 0.15, 0.2))
	box(Vector3(70, 0.25, 6), Vector3(0, 0.12, -44), curb)
	box(Vector3(6, 0.25, 80), Vector3(-17, 0.12, -10), curb)
	box(Vector3(6, 0.25, 80), Vector3(17, 0.12, -10), curb)

# ---------------------------------------------------------------- city
func build_city():
	# reference scale from building-a
	var ref: Node3D = load(CC + "building-a.glb").instantiate()
	add_child(ref)
	var h0 := world_aabb(ref).size.y
	ref.queue_free()
	var s := 11.0 / maxf(h0, 0.001)
	# back row: big "hypermarket" made of wide buildings + skyscrapers behind
	var back := ["building-skyscraper-a", "building-c", "building-h", "building-skyscraper-c", "building-e", "building-k", "building-skyscraper-b"]
	for i in back.size():
		spawn(CC + back[i] + ".glb", Vector3(-30 + i * 10, 0.25, -52 - (8 if "sky" in back[i] else 0)), -1, 0.0, s)
	# side rows
	var left := ["building-a", "building-d", "building-g", "building-l", "building-b"]
	var right := ["building-f", "building-i", "building-n", "building-j", "building-m"]
	for i in left.size():
		spawn(CC + left[i] + ".glb", Vector3(-24, 0.25, 4 - i * 11), -1, PI / 2, s)
		spawn(CC + right[i] + ".glb", Vector3(24, 0.25, 4 - i * 11), -1, -PI / 2, s)
	# hypermarket facade sign
	var sign_col := Color(0.15, 0.55, 0.3)
	if style == "B": sign_col = Color(0.8, 0.07, 0.14)
	if neon: sign_col = Color(0.1, 0.9, 0.5)
	var facade := box(Vector3(26, 3.2, 0.6), Vector3(0, 11.5, -46.5), solid(sign_col, 2.5 if neon else 0.0))
	var t := label3d("HYPERMARCHÉ", Vector3(0, 11.6, -46.1), 260, Color(1, 1, 1) if not neon else Color(2.4, 2.4, 2.4), Color(0, 0, 0, 0), false, font_main)
	t.outline_size = 0
	var promo := label3d("-70 %", Vector3(10.5, 15.2, -46.2), 300, Color(1, 0.85, 0.1) if not neon else Color(4, 3, 0.4), Color(0.1, 0.05, 0, 1), false, font_main)
	promo.rotation_degrees = Vector3(0, 0, 8)
	# burger sign left, bank right
	box(Vector3(0.6, 2.4, 7), Vector3(-20.8, 7.5, -12), solid(Color(0.85, 0.2, 0.1), 2.5 if neon else 0.0))
	var b1 := label3d("BURGER ROYAL", Vector3(-20.4, 7.5, -12), 150, Color(1, 0.9, 0.3) * (3.0 if neon else 1.0), Color(0, 0, 0, 0), false, font_main)
	b1.rotation_degrees = Vector3(0, 90, 0)
	box(Vector3(0.6, 2.4, 7), Vector3(20.8, 8.5, -20), solid(Color(0.12, 0.2, 0.45), 2.0 if neon else 0.0))
	var b2 := label3d("BANQUE PRIVÉE", Vector3(20.4, 8.5, -20), 140, Color(1, 0.82, 0.35) * (3.0 if neon else 1.0), Color(0, 0, 0, 0), false, font_main)
	b2.rotation_degrees = Vector3(0, -90, 0)
	# street lights
	for z in [-6.0, -18.0, -30.0]:
		for x in [-13.0, 13.0]:
			spawn(CR + "light-square.glb", Vector3(x, 0, z), 6.5, PI / 2 if x < 0 else -PI / 2)
			if neon:
				var ol := OmniLight3D.new()
				ol.light_color = Color(1.0, 0.75, 0.45)
				ol.light_energy = 3.0
				ol.omni_range = 11.0
				ol.position = Vector3(x + (1.5 if x < 0 else -1.5), 6.0, z)
				ol.light_volumetric_fog_energy = 1.5
				add_child(ol)
	if neon:
		for p in [[Vector3(-19, 8, -12), Color(1, 0.3, 0.1)], [Vector3(19, 8, -20), Color(0.3, 0.5, 1)], [Vector3(0, 10, -43), Color(0.1, 1, 0.5)], [Vector3(-8, 4, -2), Color(1, 0.1, 0.3)]]:
			var o := OmniLight3D.new()
			o.light_color = p[1]; o.light_energy = 6.0; o.omni_range = 18.0; o.position = p[0]
			o.light_volumetric_fog_energy = 2.0
			add_child(o)
	# parked cars
	var cars := ["sedan", "suv", "taxi", "hatchback-sports", "van", "suv-luxury", "sedan-sports", "police", "delivery"]
	for i in 9:
		var x := -11.2 + i * 2.8
		if absf(x) < 2.0: continue
		spawn(CAR + cars[i % cars.size()] + ".glb", Vector3(x, 0, -26 + rng.randf_range(-0.4, 0.4)), 1.5, PI / 2 + rng.randf_range(-0.08, 0.08))
	for i in [-4, -3, 3, 4]:
		spawn(CAR + cars[(i + 9) % cars.size()] + ".glb", Vector3(i * 2.8, 0, -14), 1.5, -PI / 2)
	# shopping carts, cones, dumpsters, trees
	for i in 10:
		spawn(SHOP + "shopping-cart.glb", Vector3(rng.randf_range(-13, 13), 0, rng.randf_range(-36, -6)), 1.1, rng.randf() * TAU)
	for i in 6:
		spawn(CR + "construction-cone.glb", Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-30, 0)), 0.7, rng.randf() * TAU)
	spawn(CR + "dumpster.glb", Vector3(-14.5, 0.25, -34), 1.6, PI / 2)
	spawn(CR + "dumpster.glb", Vector3(14.5, 0.25, -8), 1.6, -PI / 2)
	for z in [-2.0, -24.0, -38.0]:
		spawn(SUB + "tree-large.glb", Vector3(-17, 0.25, z), 5.5, rng.randf() * TAU)
		spawn(SUB + "tree-large.glb", Vector3(17, 0.25, z - 6), 5.5, rng.randf() * TAU)
	# Statue du Leader + red flags
	var red := Color(0.78, 0.06, 0.12)
	box(Vector3(3, 2.2, 3), Vector3(9.5, 1.1, -33), solid(Color(0.55, 0.52, 0.5)))
	var statue := spawn(CH + "character-male-b.glb", Vector3(9.5, 2.2, -33), 5.2, 0.4)
	play_anim(statue, "emote-yes", 0.25, 0.0)
	var bronze := solid(Color(0.75, 0.12, 0.12), 0.0, 0.45, 0.3) if style != "C" else solid(Color(0.9, 0.1, 0.15), 1.2)
	for m in statue.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = bronze
	for fx in [6.5, 12.5]:
		box(Vector3(0.15, 7, 0.15), Vector3(fx, 3.5, -33), solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
		var flag := box(Vector3(2.4, 1.5, 0.05), Vector3(fx + 1.25, 6.2, -33), solid(red, 1.5 if neon else 0.0))
		flag.rotation_degrees = Vector3(0, 0, -4)
	if serious:
		for fx in [6.5, 12.5]:
			var s2 := Label3D.new(); s2.text = "☭"; s2.font = load("res://fonts/Symbols.ttf"); s2.font_size = 128; s2.pixel_size = 0.008
			s2.modulate = Color(1, 0.8, 0.25); s2.outline_size = 0; s2.position = Vector3(fx + 1.25, 6.2, -32.95); s2.shaded = true
			add_child(s2)
		banner(Vector3(-20.5, 9.0, -14.0), PI / 2, Vector2(5.0, 6.5), "TRAVAILLEURS DE TOUS LES PAYS, BONKEZ-VOUS")
		banner(Vector3(20.5, 9.5, -9.0), -PI / 2, Vector2(5.0, 6.5), "LE PLAN QUINQUENNAL SERA BONKÉ EN 4 ANS")
		banner(Vector3(-20.5, 10.0, -27.0), PI / 2, Vector2(4.0, 5.5), "", true)
		banner(Vector3(20.5, 10.0, -30.0), -PI / 2, Vector2(4.0, 5.5), "", true)
		# capitalist billboard opposite
		var bb := box(Vector3(9, 4, 0.3), Vector3(-6, 14.5, -50), solid(Color(0.92, 0.9, 0.86)))
		var bt := label3d("ACHETEZ.  CONSOMMEZ.  RECOMMENCEZ.", Vector3(-6, 14.6, -49.8), 110, Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), false, font_main)
		bt.outline_size = 0; bt.shaded = true
		# giant matryoshka near the statue (stacked spheres)
		var mp := Vector3(-9.5, 0, -30)
		var mr := solid(Color(0.75, 0.08, 0.1), 0.0, 0.5)
		var body := MeshInstance3D.new(); var sb := SphereMesh.new(); sb.radius = 1.6; sb.height = 4.0; body.mesh = sb; body.material_override = mr; body.position = mp + Vector3(0, 2.0, 0); add_child(body)
		var hd := MeshInstance3D.new(); var sh := SphereMesh.new(); sh.radius = 1.2; sh.height = 2.3; hd.mesh = sh; hd.material_override = mr; hd.position = mp + Vector3(0, 4.6, 0); add_child(hd)
		var face := MeshInstance3D.new(); var sf := SphereMesh.new(); sf.radius = 0.75; sf.height = 1.3; face.mesh = sf; face.material_override = solid(Color(0.96, 0.85, 0.72)); face.position = mp + Vector3(0, 4.55, 0.62); add_child(face)
		var apron := MeshInstance3D.new(); var sa := SphereMesh.new(); sa.radius = 1.05; sa.height = 2.4; apron.mesh = sa; apron.material_override = solid(Color(0.96, 0.85, 0.3)); apron.position = mp + Vector3(0, 1.9, 0.75); add_child(apron)
		for ex in [-0.25, 0.25]:
			var ey := MeshInstance3D.new(); var se := SphereMesh.new(); se.radius = 0.09; se.height = 0.18; ey.mesh = se; ey.material_override = solid(Color(0.05, 0.05, 0.1)); ey.position = mp + Vector3(ex, 4.7, 1.33); add_child(ey)
	# charge zone ring around statue
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 5.3; tm.outer_radius = 5.5
	ring.mesh = tm; ring.scale = Vector3(1, 0.05, 1); ring.position = Vector3(9.5, 0.05, -33)
	ring.material_override = solid(Color(1, 0.75, 0.15), 3.0)
	add_child(ring)
	# chest
	var cbox := box(Vector3(1.2, 0.8, 0.8), Vector3(-6.5, 0.4, -10.5), solid(Color(0.95, 0.68, 0.15), 0.0, 0.4, 0.6), Vector3(0, 0.3, 0))
	box(Vector3(1.24, 0.12, 0.84), Vector3(-6.5, 0.62, -10.5), solid(Color(0.35, 0.2, 0.1)), Vector3(0, 0.3, 0))
	var cl := OmniLight3D.new(); cl.light_color = Color(1, 0.8, 0.3); cl.light_energy = 1.5; cl.omni_range = 3.0; cl.position = Vector3(-6.5, 1.2, -10.5)
	add_child(cl)

# ---------------------------------------------------------------- actors
func build_actors():
	# hero (Stakhanov) seen from behind, running
	hero = spawn(CH + ("character-male-b.glb" if serious else "character-worker.glb"), Vector3(0, 0, 0), 1.75, PI)
	if serious: attach_head(hero, ["chapka"])
	play_anim(hero, "sprint", 0.12, 0.0)
	# hammer in right hand
	var arm = _bone_attach(hero, "arm-right")
	var hammer := Node3D.new()
	var handle := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.035; cy.bottom_radius = 0.035; cy.height = 1.0
	handle.mesh = cy; handle.material_override = solid(Color(0.55, 0.33, 0.15)); handle.position = Vector3(0, 0.45, 0)
	hammer.add_child(handle)
	var head := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.42, 0.2, 0.2)
	head.mesh = hb; head.material_override = solid(Color(0.5, 0.52, 0.56), 0.0, 0.35, 0.9); head.position = Vector3(0.0, 0.95, 0)
	hammer.add_child(head)
	if arm:
		arm.add_child(hammer)
		var ww: float = arm.get_meta("w")
		hammer.scale = Vector3.ONE * ww * 1.1
		hammer.position = Vector3(-ww * 0.1, -ww * 0.75, ww * 0.15)
		hammer.rotation_degrees = Vector3(-60, 0, 0)
	# red scarf
	var scarf := box(Vector3(0.5, 0.12, 0.45), Vector3(0, 1.05, 0.05), solid(Color(0.8, 0.07, 0.14), 0.4 if neon else 0.0))
	# horde of capitalists
	var types := ["character-male-d", "character-male-d", "character-female-d", "character-male-e", "character-female-e", "character-male-c", "character-male-a", "character-female-a"]
	var placed := []
	var n := 0
	var tries := 0
	while n < 70 and tries < 2000:
		tries += 1
		var z := rng.randf_range(-4.5, -40.0)
		var spread: float = lerp(4.0, 12.0, clamp(-z / 25.0, 0.0, 1.0))
		var x := rng.randf_range(-spread, spread)
		var p := Vector3(x, 0, z)
		if p.distance_to(Vector3(-6.5, 0, -10.5)) < 1.6 or p.distance_to(Vector3(9.5, 0, -33)) < 2.5: continue
		if absf(z + 26) < 1.5 or absf(z + 14) < 1.3: continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 1.15: ok = false; break
		if not ok: continue
		placed.append(p)
		var e := spawn(CH + types[rng.randi() % types.size()] + ".glb", p, rng.randf_range(1.55, 1.85), atan2(-p.x, -p.z) + rng.randf_range(-0.3, 0.3))
		play_anim(e, "walk" if rng.randf() < 0.7 else "sprint")
		if serious: _dress_capitalist(e)
		n += 1
	if serious:
		for i in 16:
			var ang := rng.randf_range(-PI * 0.95, PI * 0.95) + PI
			var rad := rng.randf_range(3.2, 7.5)
			var p2 := Vector3(sin(ang) * rad, 0, cos(ang) * rad - 1.0)
			if p2.z < -4.0 or p2.z > 2.5: continue
			var e2 := spawn(CH + types[rng.randi() % types.size()] + ".glb", p2, rng.randf_range(1.55, 1.85), atan2(-p2.x, -p2.z) + rng.randf_range(-0.3, 0.3))
			play_anim(e2, "walk")
			_dress_capitalist(e2)
	# elite: Golden Boy (gold, big)
	var gb := spawn(CH + "character-male-d.glb", Vector3(3.8, 0, -11), 3.4, 0.25)
	play_anim(gb, "walk", 0.3)
	var gold := solid(Color(1.0, 0.72, 0.2), 0.0, 0.25, 1.0) if not use_toon else solid(Color(1.0, 0.75, 0.2))
	for m in gb.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = gold
	if serious: attach_head(gb, ["tophat", "cigar", "monocle"])
	label3d("GOLDEN BOY", Vector3(3.8, 4.7, -11), 64, Color(1, 0.85, 0.3), Color(0.1, 0.05, 0, 1))
	var hpbg := label3d("▬▬▬▬▬▬▬▬▬▬", Vector3(3.8, 3.85, -11), 40, Color(0.8, 0.1, 0.1), Color(0, 0, 0, 1))
	# enemies thrown by the tractor
	var tr := spawn(CAR + "tractor.glb", Vector3(-7.5, 0, -7.5), 2.4, PI / 2 + 0.25)
	for i in 3:
		var fly := spawn(CH + "character-male-d.glb", Vector3(-5.2 + i * 0.6, 1.2 + i * 0.9, -7.2 - i * 0.7), 1.7, rng.randf() * TAU)
		fly.rotation = Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.5, 1.5))
		play_anim(fly, "die", 0.2, 0.0)
	for i in 6:
		sprite("smoke_04.png", Vector3(-9.5 - i * 0.7, 0.6, -7.8 + i * 0.2), 1.6 + i * 0.3, Color(0.7, 0.65, 0.6, 0.35), 1.0)
	# dying enemy
	var dead := spawn(CH + "character-female-d.glb", Vector3(-2.5, 0, -6), 1.7, 0.6)
	play_anim(dead, "die", 0.5, 0.0)

func find_node_named(n: Node, nm: String) -> Node3D:
	for c in n.find_children("*", "", true, false):
		if c.name == nm and c is Node3D: return c
	return null

# ---------------------------------------------------------------- weapon FX
func build_fx():
	var red := Color(1.0, 0.15, 0.1)
	var orange := Color(1.0, 0.55, 0.15)
	var gold := Color(1.0, 0.8, 0.25)
	# hammer shockwave
	for r in [[1.5, 0.9], [2.1, 0.5]]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = r[0] - 0.07; tm.outer_radius = r[0]
		ring.mesh = tm; ring.scale = Vector3(1, 0.08, 1); ring.position = Vector3(0, 0.06, -0.3)
		var m := solid(Color(1.0, 0.25, 0.12, r[1]), 4.0)
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	sprite("circle_05.png", Vector3(0, 0.04, -0.3), 4.6, Color(1, 0.35, 0.15, 0.35), 2.0, false, Vector3(-PI / 2, 0, 0))
	# kalach bullets (tracers) heading into the horde
	for i in 7:
		var a := rng.randf_range(-0.5, 0.5)
		var d := rng.randf_range(3.0, 14.0)
		var p := Vector3(sin(a) * d, 1.0, -cos(a) * d)
		var t := sprite("trace_01.png", p, 1.4, gold, 4.0, false, Vector3(PI / 2, a, 0))
		t.scale = Vector3(0.35, 2.2, 1)
		var bullet := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.08; sm.height = 0.16
		bullet.mesh = sm; bullet.material_override = solid(gold, 6.0); bullet.position = p + Vector3(sin(a), 0, -cos(a)) * 0.7
		add_child(bullet)
	# sickle boomerang arc
	for i in 9:
		var ang := -0.6 + i * 0.16
		var p := Vector3(-3.0 + cos(ang) * 4.0, 1.3, -5.5 + sin(ang) * 4.0)
		sprite("spark_05.png", p, 0.5 + i * 0.07, red, 3.0)
	var sick := MeshInstance3D.new()
	var st := TorusMesh.new(); st.inner_radius = 0.38; st.outer_radius = 0.5
	sick.mesh = st; sick.scale = Vector3(1, 0.2, 1); sick.position = Vector3(1.0, 1.3, -6.0); sick.rotation = Vector3(0.4, 0, 0.3)
	sick.material_override = solid(Color(0.85, 0.85, 0.9), 0.0, 0.2, 1.0)
	add_child(sick)
	sprite("slash_02.png", Vector3(1.0, 1.3, -6.0), 2.4, red, 3.0)
	# molotov fire pool
	var fp := Vector3(5.5, 0, -15)
	sprite("scorch_02.png", fp + Vector3(0, 0.03, 0), 5.0, Color(0.2, 0.1, 0.05, 0.9), 1.0, false, Vector3(-PI / 2, 0, 0))
	for i in 14:
		var o := Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.6, 1.6))
		var hgt := rng.randf_range(0.9, 2.0)
		var f := sprite("flame_0%d.png" % (1 + i % 4), fp + o + Vector3(0, hgt * 0.45, 0), hgt, orange if i % 3 else red, 3.0)
	var fl := OmniLight3D.new(); fl.light_color = orange; fl.light_energy = 5.0; fl.omni_range = 7.0; fl.position = fp + Vector3(0, 1.2, 0)
	fl.light_volumetric_fog_energy = 2.0
	add_child(fl)
	# hit sparks + red stars where enemies die
	for p in [Vector3(-2.5, 1.0, -6), Vector3(2.2, 1.3, -8.5), Vector3(-1.2, 1.2, -12), Vector3(3.8, 2.2, -11)]:
		sprite("star_06.png", p, 1.8, red, 3.5)
		sprite("spark_04.png", p, 1.4, gold, 3.0)
	# spoutnik orbiting with laser
	var sp := MeshInstance3D.new(); var ss := SphereMesh.new(); ss.radius = 0.22; ss.height = 0.44
	sp.mesh = ss; sp.material_override = solid(Color(0.85, 0.85, 0.88), 0.0, 0.2, 1.0); sp.position = Vector3(1.4, 2.3, -0.6)
	add_child(sp)
	for k in 4:
		var ant := MeshInstance3D.new(); var ac := CylinderMesh.new(); ac.top_radius = 0.01; ac.bottom_radius = 0.01; ac.height = 0.9
		ant.mesh = ac; ant.material_override = solid(Color(0.8, 0.8, 0.8), 0.0, 0.3, 1.0)
		ant.position = sp.position + Vector3(-0.3 + k * 0.05, -0.25, 0.3 - k * 0.15)
		ant.rotation = Vector3(0.9, k * 0.5, 0.6)
		add_child(ant)
	var target := Vector3(2.2, 1.3, -8.5)
	var beam := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 0.035; bc.bottom_radius = 0.035; bc.height = sp.position.distance_to(target)
	beam.mesh = bc; beam.material_override = solid(Color(0.3, 0.9, 1.0), 8.0)
	beam.position = (sp.position + target) / 2.0
	beam.look_at_from_position(beam.position, target, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	# XP gems (green rubles) + coins
	for i in 30:
		var gp := Vector3(rng.randf_range(-7, 7), 0.35, rng.randf_range(-16, -1.5))
		var gem := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.16; gs.height = 0.38; gs.radial_segments = 4; gs.rings = 2
		gem.mesh = gs; gem.material_override = solid(Color(0.2, 0.95, 0.45), 2.5); gem.position = gp
		gem.rotation = Vector3(0, rng.randf() * TAU, 0)
		add_child(gem)
	# damage numbers
	var nums := [["128", Vector3(-1.3, 2.4, -7.5), Color(1, 1, 1)], ["412", Vector3(2.5, 2.8, -8.8), Color(1, 0.85, 0.2)], ["CRIT 1 024", Vector3(4.6, 5.0, -11), Color(1, 0.25, 0.2)], ["87", Vector3(-3.6, 2.6, -10), Color(1, 1, 1)], ["256", Vector3(5.2, 2.6, -14), Color(1, 0.6, 0.2)], ["64", Vector3(0.4, 2.3, -12.5), Color(1, 1, 1)]]
	for d in nums:
		var fs: int = 90 if d[0].begins_with("CRIT") else 70
		if serious: fs = int(fs * 0.8)
		label3d(d[0], d[1], fs, d[2], Color(0.08, 0.04, 0.02, 1))

# ---------------------------------------------------------------- post process
func build_post():
	var mode := 0
	var outline := 0.0
	var vign := 0.2
	var grain := 0.0
	var aberr := 0.0
	var sat := 1.0
	var con := 1.0
	match style:
		"A": vign = 0.18
		"E", "F": vign = 0.32; grain = 0.025; sat = 0.95; con = 1.03
		"B": mode = 1; outline = 1.0; vign = 0.3; grain = 0.06
		"C": vign = 0.5; grain = 0.05; aberr = 0.006
		"D": mode = 2; outline = 1.0; vign = 0.08; sat = 1.2; con = 1.06
	if outline > 0.0:
		var q := MeshInstance3D.new()
		q.mesh = QuadMesh.new()
		q.extra_cull_margin = 16384.0
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var om := ShaderMaterial.new()
		om.shader = load("res://shaders/outline.gdshader")
		om.render_priority = 127
		om.set_shader_parameter("outline", outline)
		om.set_shader_parameter("outline_px", 1.7 if style == "B" else 1.4)
		if style == "D": om.set_shader_parameter("ink", Color(0.05, 0.05, 0.12))
		q.material_override = om
		cam.add_child(q)
		q.position = Vector3(0, 0, -0.5)
	var cl := CanvasLayer.new()
	cl.layer = 0
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.size = Vector2(1920, 1080)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grade.gdshader")
	gm.set_shader_parameter("mode", mode)
	gm.set_shader_parameter("vignette", vign)
	gm.set_shader_parameter("grain", grain)
	gm.set_shader_parameter("aberration", aberr)
	gm.set_shader_parameter("saturation", sat)
	gm.set_shader_parameter("contrast", con)
	cr.material = gm
	cl.add_child(cr)

# ---------------------------------------------------------------- HUD
func build_hud():
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(root)
	var c_bg: Color; var c_fg: Color; var c_acc: Color; var c_xp: Color; var c_hp: Color; var radius := 10; var border := 0
	match style:
		"A": c_bg = Color(0.08, 0.1, 0.16, 0.78); c_fg = Color.WHITE; c_acc = Color(1, 0.8, 0.2); c_xp = Color(0.25, 0.85, 1.0); c_hp = Color(0.95, 0.25, 0.3); radius = 14
		"B": c_bg = Color(0.93, 0.87, 0.74, 0.96); c_fg = Color(0.08, 0.06, 0.05); c_acc = Color(0.78, 0.06, 0.12); c_xp = Color(0.78, 0.06, 0.12); c_hp = Color(0.78, 0.06, 0.12); radius = 0; border = 4
		"C": c_bg = Color(0.02, 0.02, 0.06, 0.6); c_fg = Color(0.9, 0.95, 1.0); c_acc = Color(1, 0.2, 0.35); c_xp = Color(0.2, 1, 0.6); c_hp = Color(1, 0.15, 0.3); radius = 4; border = 2
		"E", "F": c_bg = Color(0.06, 0.06, 0.07, 0.72); c_fg = Color(0.92, 0.9, 0.86); c_acc = Color(0.85, 0.2, 0.18); c_xp = Color(0.85, 0.78, 0.55); c_hp = Color(0.75, 0.15, 0.15); radius = 2; border = 1
		"D": c_bg = Color(1, 0.95, 0.4, 0.97); c_fg = Color(0.05, 0.05, 0.12); c_acc = Color(0.95, 0.15, 0.2); c_xp = Color(0.2, 0.6, 1.0); c_hp = Color(0.95, 0.15, 0.2); radius = 18; border = 5
	var border_col := c_fg if style != "C" else c_acc
	if serious: border_col = Color(1, 1, 1, 0.18)
	# XP bar
	_bar(root, Rect2(0, 0, 1920, 26), 0.58, Color(0, 0, 0, 0.65), c_xp, 0, 0, border_col)
	_lbl(root, "NIV 21", Vector2(18, 1), 22, Color.WHITE if style != "B" else Color(0.95, 0.9, 0.8), font_main)
	# timer
	var tl := _lbl(root, "06:12", Vector2(860, 34), 84, c_fg if style in ["B", "D"] else Color.WHITE, font_num)
	tl.size = Vector2(200, 100); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_color_override("font_outline_color", c_bg if style in ["B", "D"] else Color(0, 0, 0, 0.8))
	tl.add_theme_constant_override("outline_size", 18)
	var zl := _lbl(root, "ZONE 1/3  ·  HYPERMARCHÉ", Vector2(760, 128), 22, c_acc, font_main)
	zl.size = Vector2(400, 30); zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9) if style != "B" else c_bg)
	zl.add_theme_constant_override("outline_size", 8)
	# HP
	_panel(root, Rect2(24, 44, 380, 54), c_bg, radius, border, border_col)
	_bar(root, Rect2(36, 56, 270, 30), 0.74, Color(0, 0, 0, 0.35), c_hp, radius / 2, 0, border_col)
	_lbl(root, "156 / 210", Vector2(316, 58), 24, c_fg, font_num)
	# currencies
	_panel(root, Rect2(1540, 44, 356, 54), c_bg, radius, border, border_col)
	_lbl(root, "312 RBL", Vector2(1560, 54), 30, c_acc if style != "C" else Color(1, 0.85, 0.3), font_num)
	_lbl(root, "1 847 KO", Vector2(1730, 54), 30, c_fg, font_num)
	# weapons
	var weapons := ["MARTEAU", "KALACH", "FAUCILLE", "MOLOTOV", "SPOUTNIK", ""]
	var lv := [7, 5, 4, 3, 2, 0]
	_lbl(root, "ARMES", Vector2(26, 900), 20, c_fg if style in ["B", "D"] else Color.WHITE, font_main).add_theme_constant_override("outline_size", 6)
	for i in 6:
		var r := Rect2(24 + i * 108, 930, 98, 98)
		_panel(root, r, c_bg if weapons[i] != "" else Color(c_bg.r, c_bg.g, c_bg.b, 0.4), radius, border, border_col)
		if weapons[i] != "":
			var wl := _lbl(root, weapons[i], r.position + Vector2(4, 32), 15, c_fg, font_main)
			wl.size = Vector2(90, 30); wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var ll := _lbl(root, "NV " + str(lv[i]), r.position + Vector2(30, 66), 18, c_acc, font_num)
		else:
			var ll := _lbl(root, "+", r.position + Vector2(36, 18), 48, Color(c_fg.r, c_fg.g, c_fg.b, 0.4), font_num)
	# decrees
	var dec := ["PRODUCTIVITÉ", "CADENCE", "EXPANSION", ""]
	for i in 4:
		var r := Rect2(24 + i * 160, 860, 150, 34)
		_panel(root, r, c_acc if dec[i] != "" else Color(0, 0, 0, 0.25), 6 if radius > 0 else 0, 0, border_col)
		if dec[i] != "":
			var dl := _lbl(root, dec[i], r.position + Vector2(0, 5), 16, Color.WHITE if style != "D" else c_fg, font_main)
			dl.size = Vector2(150, 30); dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# familiar
	_panel(root, Rect2(1740, 900, 156, 128), c_bg, radius, border, border_col)
	_lbl(root, "FAMILIER", Vector2(1758, 912), 16, c_acc, font_main)
	_lbl(root, "LAÏKA", Vector2(1758, 950), 34, c_fg, font_num)
	_lbl(root, "LÉGENDAIRE", Vector2(1758, 994), 15, c_fg, font_main)
	# style tag
	var names := {"A": "TEST A  ·  JOUET COLORÉ", "B": "TEST B  ·  AFFICHE DE PROPAGANDE", "C": "TEST C  ·  NÉON NOCTURNE", "D": "TEST D  ·  BANDE DESSINÉE", "E": "TEST A2  ·  JOUR COUVERT", "F": "TEST A3  ·  FIN DE JOURNÉE"}
	var tag := _lbl(root, names[style], Vector2(1280, 1040), 22, Color.WHITE, font_main)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 8)

func _panel(parent: Control, r: Rect2, col: Color, radius: int, border: int, bcol: Color) -> Panel:
	var p := Panel.new()
	p.position = r.position; p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = bcol
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

func _bar(parent: Control, r: Rect2, v: float, bg: Color, fg: Color, radius: int, border: int, bcol: Color):
	_panel(parent, r, bg, radius, border, bcol)
	_panel(parent, Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * v, r.size.y - 6)), fg, radius, 0, bcol)

func _lbl(parent: Control, t: String, pos: Vector2, size: int, col: Color, fnt: Font) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_override("font", fnt)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- silly accessories
func head_frame(n: Node) -> Array:
	var sks := n.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return []
	var sk: Skeleton3D = sks[0]
	var hb := sk.find_bone("head")
	var hm = find_node_named(n, "head-mesh")
	if hb < 0 or hm == null: return []
	var a: AABB = (sk.global_transform.affine_inverse() * hm.global_transform) * (hm as MeshInstance3D).get_aabb()
	var origin := sk.get_bone_global_rest(hb).origin
	return [sk, a, origin]

func attach_head(n: Node, kinds: Array):
	var f := head_frame(n)
	if f.is_empty(): return
	var sk: Skeleton3D = f[0]
	var a: AABB = f[1]
	var o: Vector3 = f[2]
	var w := a.size.x
	var top := a.end.y - o.y
	var cz := a.get_center().z - o.z
	var front := a.end.z - o.z
	var ba := BoneAttachment3D.new()
	ba.bone_name = "head"
	sk.add_child(ba)
	var root := Node3D.new()
	ba.add_child(root)
	for k in kinds:
		match k:
			"chapka":
				var fur := solid(Color(0.5, 0.42, 0.33), 0.0, 1.0)
				var dark := solid(Color(0.33, 0.26, 0.2), 0.0, 1.0)
				_cyl(root, w * 0.5, w * 0.3, Vector3(0, top + w * 0.05, cz), dark)
				var crown := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = w * 0.5; sp.height = w * 0.45
				crown.mesh = sp; crown.material_override = dark; crown.position = Vector3(0, top + w * 0.18, cz); root.add_child(crown)
				var band := MeshInstance3D.new(); var tb := TorusMesh.new(); tb.inner_radius = w * 0.46; tb.outer_radius = w * 0.66
				band.mesh = tb; band.material_override = fur; band.position = Vector3(0, top - w * 0.06, cz); band.scale = Vector3(1, 1.5, 1); root.add_child(band)
				for sx in [-1.0, 1.0]:
					var flap := _box(root, Vector3(w * 0.16, w * 0.62, w * 0.5), Vector3(sx * w * 0.6, top - w * 0.42, cz), fur)
					flap.rotation = Vector3(0, 0, sx * 0.12)
				for zz in [1.0, -1.0]:
					_box(root, Vector3(w * 0.2, w * 0.2, w * 0.04), Vector3(0, top - w * 0.02, cz + zz * w * 0.66), solid(Color(0.85, 0.08, 0.1), 0.5), Vector3(0, 0, PI / 4))
					var st := Label3D.new(); st.text = "★"; st.font = load("res://fonts/Symbols.ttf"); st.font_size = 64; st.pixel_size = w * 0.0036
					st.modulate = Color(1, 0.8, 0.2); st.outline_size = 0; st.position = Vector3(0, top - w * 0.02, cz + zz * w * 0.69); st.shaded = false
					st.rotation = Vector3(0, 0 if zz > 0 else PI, 0)
					root.add_child(st)
			"tophat":
				var blk := solid(Color(0.06, 0.06, 0.07), 0.0, 0.5)
				_cyl(root, w * 0.52, w * 0.04, Vector3(0, top, cz), blk)
				_cyl(root, w * 0.34, w * 0.62, Vector3(0, top + w * 0.31, cz), blk)
				_cyl(root, w * 0.35, w * 0.09, Vector3(0, top + w * 0.08, cz), solid(Color(0.95, 0.72, 0.2), 0.0, 0.3, 1.0))
			"cigar":
				var c := _cyl(root, w * 0.045, w * 0.38, Vector3(w * 0.12, top - w * 0.78, front + w * 0.16), solid(Color(0.4, 0.22, 0.1)))
				c.rotation = Vector3(PI / 2 - 0.25, 0.35, 0)
				var tip := _cyl(root, w * 0.047, w * 0.04, Vector3(w * 0.19, top - w * 0.73, front + w * 0.33), solid(Color(1, 0.4, 0.1), 4.0))
				tip.rotation = c.rotation
			"monocle":
				var m := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = w * 0.09; tm.outer_radius = w * 0.115
				m.mesh = tm; m.material_override = solid(Color(1, 0.8, 0.3), 0.0, 0.2, 1.0)
				m.position = Vector3(w * 0.2, top - w * 0.48, front + w * 0.02); m.rotation = Vector3(PI / 2, 0, 0)
				root.add_child(m)
			"glasses_gold":
				for sx in [-1.0, 1.0]:
					_box(root, Vector3(w * 0.26, w * 0.13, w * 0.03), Vector3(sx * w * 0.2, top - w * 0.48, front + w * 0.02), solid(Color(0.05, 0.05, 0.06), 0.0, 0.1))

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 16
	m.mesh = c; m.material_override = mat; m.position = pos
	parent.add_child(m)
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size
	m.mesh = b; m.material_override = mat; m.position = pos; m.rotation = rot
	parent.add_child(m)
	return m

func banner(pos: Vector3, rot_y: float, size: Vector2, text: String, sym := true):
	var red := solid(Color(0.72, 0.05, 0.1), 0.0, 0.9)
	var b := box(Vector3(size.x, size.y, 0.08), pos, red, Vector3(0, rot_y, 0))
	var fwd := Vector3(sin(rot_y), 0, cos(rot_y))
	if sym:
		var s := Label3D.new(); s.text = "☭"; s.font = load("res://fonts/Symbols.ttf"); s.font_size = 256
		s.pixel_size = size.y * 0.55 / 256.0; s.modulate = Color(1, 0.8, 0.25); s.outline_size = 0; s.shaded = true
		s.position = pos + fwd * 0.06 + Vector3(0, size.y * 0.14, 0); s.rotation = Vector3(0, rot_y, 0)
		add_child(s)
	if text != "":
		var t := Label3D.new(); t.text = text; t.font = font_main; t.font_size = 96
		t.pixel_size = size.y * 0.13 / 96.0; t.modulate = Color(0.98, 0.92, 0.8); t.outline_size = 0; t.shaded = true
		t.width = size.x / t.pixel_size * 0.92; t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.position = pos + fwd * 0.06 + Vector3(0, -size.y * (0.28 if sym else 0.0), 0); t.rotation = Vector3(0, rot_y, 0)
		add_child(t)

func _dress_capitalist(e: Node):
	var k := []
	var r := rng.randf()
	if r < 0.4: k.append("tophat")
	elif r < 0.55: k.append("glasses_gold")
	if rng.randf() < 0.3: k.append("cigar")
	if "tophat" in k and rng.randf() < 0.3: k.append("monocle")
	if not k.is_empty(): attach_head(e, k)

func _bone_attach(n: Node, bone: String) -> Node3D:
	var f := head_frame(n)
	if f.is_empty(): return null
	var sk: Skeleton3D = f[0]
	if sk.find_bone(bone) < 0: return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var holder := Node3D.new()
	holder.set_meta("w", (f[1] as AABB).size.x)
	ba.add_child(holder)
	return holder
