extends Node3D
# 3D propaganda stage used by the title screen and the comrade selection:
# a red tribune before a wall of giant posters, drapes, flags, spotlights and falling leaflets.

var cam: Camera3D
var podiums: Array = []        # Vector3 tops
var spots: Array = []          # SpotLight3D above each podium
var flags: Array = []
var plates: Array = []
var t := 0.0
var rng := RandomNumberGenerator.new()

func build(n_podiums: int, spread := 3.0, arc := 0.6):
	rng.seed = 1917
	U.fonts()
	_env()
	# floor and tribune
	var floor_m := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 60); floor_m.mesh = pm
	floor_m.material_override = U.pbr("PavingStones138", 0.35, Color(0.6, 0.52, 0.48), 0.8)
	add_child(floor_m)
	var sw := maxf(22.0, n_podiums * spread + 5.0)
	U.box(self, Vector3(sw, 0.8, 8), Vector3(0, 0.4, -1.5), U.pbr("Concrete034", 0.4, Color(0.95, 0.9, 0.85)))
	U.box(self, Vector3(sw + 0.2, 0.18, 0.2), Vector3(0, 0.71, 2.52), U.solid(UIK.RED, 0.0, 0.6))
	U.box(self, Vector3(sw + 0.2, 0.5, 0.06), Vector3(0, 0.35, 2.52), U.solid(Color(0.55, 0.05, 0.08), 0.0, 0.8))
	# backdrop: wall of posters between red drapes
	var wall_z := -6.0
	U.box(self, Vector3(sw + 14, 16, 0.4), Vector3(0, 8, wall_z - 0.2), U.pbr("Plaster001", 0.25, Color(0.95, 0.88, 0.78)))
	var idx := [0, 2, 1, 3, 6, 5, 7, 4, 0, 2]
	var npost := 5 if sw <= 22.0 else int(sw / 6.0) | 1
	for i in npost:
		var x := (i - (npost - 1) / 2.0) * 6.0
		var tex: String = U.propaganda_tex(idx[i % idx.size()])
		var mid := i == (npost - 1) / 2
		var size := Vector2(4.6, 6.9) if not mid else Vector2(6.0, 9.0)
		U.poster(self, tex, Vector3(x, 5.6 if not mid else 6.4, wall_z + 0.02), size, 0.0)
	for sx in [-1.0, 1.0]:
		for k in 5:
			var dr := U.cyl(self, 0.55, 15.5, Vector3(sx * (sw * 0.5 + 5.0 - k * 0.9), 7.75, wall_z + 0.6 + k * 0.05), U.solid(Color(0.62 - k * 0.03, 0.04, 0.07), 0.0, 0.9))
			dr.scale = Vector3(1, 1, 0.5)
	U.box(self, Vector3(sw + 12, 1.4, 0.5), Vector3(0, 15.3, wall_z + 0.8), U.solid(Color(0.5, 0.03, 0.06), 0.0, 0.9))
	var star := Label3D.new(); star.text = "★"; star.font = load("res://fonts/Symbols.ttf"); star.font_size = 256; star.pixel_size = 0.016
	star.modulate = Color(1.0, 0.82, 0.3); star.outline_size = 0; star.position = Vector3(0, 12.6, wall_z + 0.3)
	add_child(star)
	# flags on poles at the stage corners
	for sx in [-(sw * 0.5 - 0.5), sw * 0.5 - 0.5]:
		U.cyl(self, 0.07, 7.5, Vector3(sx, 0.8 + 3.75, -1.0), U.solid(Color(0.8, 0.75, 0.6), 0.0, 0.3, 0.9))
		var fl := Node3D.new(); add_child(fl); fl.position = Vector3(sx, 7.4, -1.0)
		U.box(fl, Vector3(0.04, 1.6, 2.6), Vector3(0, 0, 1.33 * (-1.0 if sx > 0 else 1.0)), U.solid(UIK.RED, 0.0, 0.9))
		flags.append(fl)
	# podiums in a shallow arc
	for i in n_podiums:
		var k := (i - (n_podiums - 1) / 2.0)
		var p := Vector3(k * spread, 0.8, -absf(k) * arc + 0.5)
		U.cyl(self, 0.85, 0.5, p + Vector3(0, 0.25, 0), U.pbr("Marble012", 0.6, Color(0.9, 0.75, 0.7)))
		U.cyl(self, 0.92, 0.08, p + Vector3(0, 0.46, 0), U.solid(UIK.GOLD, 0.3, 0.3, 1.0))
		podiums.append(p + Vector3(0, 0.5, 0))
		if n_podiums > 1:
			var plate := U.label(self, "", p + Vector3(0, 0.25, 0.9), 40, UIK.GOLD, Color(0, 0, 0, 1), false, UIK.font("RussoOne"))
			plate.pixel_size = 0.006
			plates.append(plate)
		var sp := SpotLight3D.new()
		sp.position = p + Vector3(0, 9.0, 3.0)
		sp.look_at_from_position(sp.position, p + Vector3(0, 1.0, 0))
		sp.spot_angle = 16.0; sp.spot_range = 16.0; sp.light_energy = 6.0
		sp.light_color = Color(1.0, 0.9, 0.75); sp.shadow_enabled = i == 0 or n_podiums == 1
		add_child(sp)
		spots.append(sp)
	# leaflets and confetti drifting down
	for c in [UIK.RED, UIK.GOLD, UIK.PAPER]:
		var parts := CPUParticles3D.new()
		var q := QuadMesh.new(); q.size = Vector2(0.16, 0.22)
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.roughness = 0.9
		q.material = m
		parts.mesh = q
		parts.amount = 60
		parts.lifetime = 9.0
		parts.preprocess = 9.0
		parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		parts.emission_box_extents = Vector3(sw * 0.6, 0.5, 5)
		parts.position = Vector3(0, 13, 0)
		parts.direction = Vector3(0, -1, 0); parts.spread = 25.0
		parts.gravity = Vector3(0, -0.6, 0)
		parts.initial_velocity_min = 0.6; parts.initial_velocity_max = 1.4
		parts.angular_velocity_min = -180.0; parts.angular_velocity_max = 180.0
		parts.particle_flag_rotate_y = true
		parts.angle_min = 0.0; parts.angle_max = 360.0
		add_child(parts)
	cam = Camera3D.new()
	cam.fov = 42
	add_child(cam)
	cam.make_current()

func _env():
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.07, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.42, 0.4)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true; env.glow_intensity = 0.4
	env.fog_enabled = true; env.fog_light_color = Color(0.3, 0.15, 0.14); env.fog_density = 0.012
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_color = Color(1.0, 0.8, 0.6); sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)

# a comrade on a podium (idle, facing the camera)
func place_hero(char_id: String, i: int, skin := 0, locked := false) -> Node3D:
	var holder := Node3D.new(); add_child(holder)
	holder.position = podiums[i]
	var m := Chars.build_hero(holder, char_id, skin)
	m.position = Vector3.ZERO
	m.scale *= 1.25
	var ap := U.anim_player(m)
	Chars.set_loops(ap)
	if ap and ap.has_animation("2H_Melee_Idle"):
		ap.play("2H_Melee_Idle"); ap.seek(rng.randf() * 1.0, true)
	if locked:
		var black := U.solid(Color(0.02, 0.02, 0.025), 0.0, 0.9)
		for g in m.find_children("*", "MeshInstance3D", true, false): (g as MeshInstance3D).material_override = black
		for l in m.find_children("*", "Label3D", true, false): (l as Label3D).visible = false
		var q := U.label(holder, "?", Vector3(0, 3.0, 0), 220, UIK.GOLD, Color(0, 0, 0, 1))
		q.font = UIK.font("RussoOne")
	else:
		Chars.outline(m, 0.02)
	return holder

func _process(d: float):
	t += d
	for i in flags.size():
		var fl: Node3D = flags[i]
		fl.rotation.y = sin(t * 1.2 + i) * 0.35
		fl.rotation.x = sin(t * 2.7 + i) * 0.05
