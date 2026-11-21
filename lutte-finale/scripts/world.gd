extends Node3D
# Builds the "Hypermarché" arena: lighting, ground, buildings, obstacles, props.

var obstacles: Array = []        # Array of Rect2 (x, z, w, d) that enemies must avoid
var bounds := Rect2(-38, -56, 76, 92)
var statue_pos := Vector3(18, 0, -30)
var chest_spots: Array = []
var rng := RandomNumberGenerator.new()

func build(seed_value := 1917):
	rng.seed = seed_value
	U.fonts()
	_env()
	_ground()
	_buildings()
	_parking()
	_platforms()
	_landmarks()
	_props()
	_walls()
	_pick_chest_spots()

func _env():
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color(0.3, 0.42, 0.6)
	ps.sky_horizon_color = Color(0.95, 0.72, 0.5)
	ps.ground_horizon_color = Color(0.95, 0.72, 0.5)
	ps.sun_angle_max = 30.0
	sky.sky_material = ps
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 3.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.68, 0.58)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.12
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.2
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-17, -60, 0)
	add_child(sun)

func _ground():
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(300, 300)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.43, 0.46)
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new(); fn.frequency = 0.02
	nt.noise = fn; nt.seamless = true; nt.width = 512; nt.height = 512
	var gr := Gradient.new(); gr.set_color(0, Color(0.86, 0.86, 0.86)); gr.set_color(1, Color(1, 1, 1)); nt.color_ramp = gr
	m.albedo_texture = nt
	m.uv1_scale = Vector3(36, 36, 36)
	m.roughness = 0.95
	g.material_override = m
	add_child(g)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	# lane markings
	var lm := U.solid(Color(0.92, 0.9, 0.82), 0.0, 0.9)
	for i in range(-12, 13):
		U.box(self, Vector3(1.4, 0.02, 0.18), Vector3(i * 3.0, 0.01, -3.0), lm)
		U.box(self, Vector3(1.4, 0.02, 0.18), Vector3(i * 3.0, 0.01, 22.0), lm)
	for row in [-14.0, -28.0]:
		for i in range(-10, 11):
			U.box(self, Vector3(0.12, 0.02, 4.4), Vector3(i * 2.8, 0.01, row), lm)

func _buildings():
	var ref: Node3D = U.scene(U.CC + "building-a.glb").instantiate()
	add_child(ref)
	var h0 := U.world_aabb(ref).size.y
	ref.queue_free()
	var s := 12.0 / maxf(h0, 0.001)
	var names := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
	var i := 0
	for z in range(30, -62, -11):
		U.place(self, U.CC + names[i % names.size()] + ".glb", Vector3(-46, 0, z), -1, PI / 2, s); i += 1
		U.place(self, U.CC + names[(i + 5) % names.size()] + ".glb", Vector3(46, 0, z), -1, -PI / 2, s); i += 1
	var back := ["building-skyscraper-a", "building-c", "building-h", "building-skyscraper-c", "building-e", "building-k", "building-skyscraper-b", "building-g"]
	for j in back.size():
		U.place(self, U.CC + back[j] + ".glb", Vector3(-35 + j * 10, 0, -66 - (8 if "sky" in back[j] else 0)), -1, 0.0, s)
		U.place(self, U.CC + back[(j + 3) % back.size()] + ".glb", Vector3(-35 + j * 10, 0, 46), -1, PI, s)
	# hypermarket facade sign
	U.box(self, Vector3(28, 3.4, 0.6), Vector3(0, 12.0, -60.5), U.solid(Color(0.15, 0.5, 0.28)))
	var t := U.label(self, "HYPERMARCHÉ", Vector3(0, 12.1, -60.1), 300, Color(1, 1, 1), Color(0, 0, 0, 0), false, U.font_main)
	t.outline_size = 0; t.shaded = true
	var promo := U.label(self, "-70 %", Vector3(11, 16, -60.2), 320, Color(1, 0.85, 0.1), Color(0.1, 0.05, 0, 1), false, U.font_main)
	promo.rotation_degrees = Vector3(0, 0, 8)
	var bb := U.box(self, Vector3(10, 4, 0.3), Vector3(-14, 15, -62), U.solid(Color(0.92, 0.9, 0.86)))
	var bt := U.label(self, "ACHETEZ.  CONSOMMEZ.  RECOMMENCEZ.", Vector3(-14, 15.1, -61.8), 110, Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), false, U.font_main)
	bt.outline_size = 0; bt.shaded = true
	# propaganda banners on side buildings
	_banner(Vector3(-41.5, 9.0, -6.0), PI / 2, Vector2(5.0, 6.5), "TRAVAILLEURS DE TOUS LES PAYS, BONKEZ-VOUS")
	_banner(Vector3(41.5, 9.5, -14.0), -PI / 2, Vector2(5.0, 6.5), "LE PLAN QUINQUENNAL SERA BONKÉ EN 4 ANS")
	_banner(Vector3(-41.5, 10.0, -30.0), PI / 2, Vector2(4.0, 5.5), "")
	_banner(Vector3(41.5, 10.0, 8.0), -PI / 2, Vector2(4.0, 5.5), "")
	_banner(Vector3(-41.5, 9.0, 18.0), PI / 2, Vector2(5.0, 6.5), "LE CAPITAL EST UN TIGRE DE PAPIER. BONKEZ LE PAPIER.")

func _banner(pos: Vector3, rot_y: float, size: Vector2, text: String):
	var b := U.box(self, Vector3(size.x, size.y, 0.08), pos, U.solid(Color(0.72, 0.05, 0.1), 0.0, 0.9), Vector3(0, rot_y, 0))
	var fwd := Vector3(sin(rot_y), 0, cos(rot_y))
	var s := Label3D.new(); s.text = "☭"; s.font = load("res://fonts/Symbols.ttf"); s.font_size = 256
	s.pixel_size = size.y * 0.55 / 256.0; s.modulate = Color(1, 0.8, 0.25); s.outline_size = 0; s.shaded = true
	s.position = pos + fwd * 0.06 + Vector3(0, size.y * (0.14 if text != "" else 0.0), 0); s.rotation = Vector3(0, rot_y, 0)
	add_child(s)
	if text != "":
		var t := Label3D.new(); t.text = text; t.font = U.font_main; t.font_size = 96
		t.pixel_size = size.y * 0.12 / 96.0; t.modulate = Color(0.98, 0.92, 0.8); t.outline_size = 0; t.shaded = true
		t.width = size.x / t.pixel_size * 0.92; t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.position = pos + fwd * 0.06 + Vector3(0, -size.y * 0.28, 0); t.rotation = Vector3(0, rot_y, 0)
		add_child(t)

func add_obstacle(n: Node3D, collide := true, pad := 0.0) -> AABB:
	var a := U.world_aabb(n)
	a = a.grow(pad)
	obstacles.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = a.size
		cs.shape = bs
		body.add_child(cs)
		body.position = a.get_center()
		add_child(body)
	return a

func _parking():
	var cars := ["sedan", "suv", "taxi", "hatchback-sports", "van", "suv-luxury", "sedan-sports", "police", "delivery", "truck"]
	for row in [-14.0, -28.0]:
		for i in range(-10, 10):
			if rng.randf() < 0.35: continue
			if absi(i) <= 1: continue
			var x := -26.6 + (i + 10) * 2.8 - 1.4
			var c := U.place(self, U.CAR + cars[rng.randi() % cars.size()] + ".glb", Vector3(x + 1.4, 0, row + rng.randf_range(-0.3, 0.3)), 1.5, PI / 2 * (1 if rng.randf() < 0.5 else -1))
			add_obstacle(c)

func _platforms():
	# shipping containers you can jump on (enemies walk around them)
	var spots := [[Vector3(-24, 0, 10), 0.0], [Vector3(-20, 0, 10), 0.0], [Vector3(26, 0, -44), PI / 2], [Vector3(26, 0, 4), PI / 2], [Vector3(-28, 0, -46), 0.0]]
	var kinds := ["shipping-container-a", "shipping-container-b", "shipping-container-c"]
	for i in spots.size():
		var c := U.place(self, U.IND + kinds[i % 3] + ".glb", spots[i][0], 2.3, spots[i][1])
		add_obstacle(c)
	# a second level on one stack
	var top := U.place(self, U.IND + "shipping-container-c.glb", Vector3(-22, 2.3, 10), 2.3, PI / 2)
	add_obstacle(top)

func _landmarks():
	# Statue du Leader (charge shrine)
	var sp := statue_pos
	var ped := U.box(self, Vector3(3, 2.2, 3), sp + Vector3(0, 1.1, 0), U.solid(Color(0.55, 0.52, 0.5)))
	var statue := U.place(self, U.CH + "character-male-b.glb", sp + Vector3(0, 2.2, 0), 5.2, 0.4)
	U.play_anim(statue, "emote-yes", 0.25, 0.0)
	var ap := U.anim_player(statue)
	if ap: ap.pause()
	var bronze := U.solid(Color(0.75, 0.12, 0.12), 0.0, 0.45, 0.3)
	for m in statue.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = bronze
	add_obstacle(ped)
	for fx in [-3.0, 3.0]:
		var pole := U.box(self, Vector3(0.15, 7, 0.15), sp + Vector3(fx, 3.5, 0), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
		var flag := U.box(self, Vector3(2.4, 1.5, 0.05), sp + Vector3(fx + 1.25, 6.2, 0), U.solid(Color(0.72, 0.05, 0.1)))
		flag.rotation_degrees = Vector3(0, 0, -4)
		var s2 := Label3D.new(); s2.text = "☭"; s2.font = load("res://fonts/Symbols.ttf"); s2.font_size = 128; s2.pixel_size = 0.008
		s2.modulate = Color(1, 0.8, 0.25); s2.outline_size = 0; s2.position = sp + Vector3(fx + 1.25, 6.2, 0.05); s2.shaded = true
		add_child(s2)
	# giant matryoshka
	var mp := Vector3(-20, 0, -36)
	var mr := U.solid(Color(0.75, 0.08, 0.1), 0.0, 0.5)
	U.sphere(self, 1.6, mp + Vector3(0, 2.0, 0), mr, 4.0)
	U.sphere(self, 1.2, mp + Vector3(0, 4.6, 0), mr, 2.3)
	U.sphere(self, 0.75, mp + Vector3(0, 4.55, 0.62), U.solid(Color(0.96, 0.85, 0.72)), 1.3)
	U.sphere(self, 1.05, mp + Vector3(0, 1.9, 0.75), U.solid(Color(0.96, 0.85, 0.3)), 2.4)
	for ex in [-0.25, 0.25]:
		U.sphere(self, 0.09, mp + Vector3(ex, 4.7, 1.33), U.solid(Color(0.05, 0.05, 0.1)))
	obstacles.append(Rect2(mp.x - 1.6, mp.z - 1.6, 3.2, 3.2))
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 1.6; cy.height = 5.5
	cs.shape = cy; body.add_child(cs); body.position = mp + Vector3(0, 2.75, 0); add_child(body)

func _props():
	for z in [-8.0, -20.0, -34.0, -48.0, 4.0, 16.0, 28.0]:
		for x in [-35.0, 35.0]:
			var l := U.place(self, U.CR + "light-square.glb", Vector3(x, 0, z), 6.5, PI / 2 if x < 0 else -PI / 2)
	for z in [-2.0, -24.0, -40.0, 12.0, 26.0]:
		U.place(self, U.SUB + "tree-large.glb", Vector3(-37, 0, z), 5.5, rng.randf() * TAU)
		U.place(self, U.SUB + "tree-large.glb", Vector3(37, 0, z - 6), 5.5, rng.randf() * TAU)
	for i in 22:
		var p := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-52, 30))
		if _blocked(p, 2.0): continue
		U.place(self, U.SHOP + "shopping-cart.glb", p, 1.1, rng.randf() * TAU)
	for i in 14:
		var p := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-52, 30))
		if _blocked(p, 1.0): continue
		U.place(self, U.CR + "construction-cone.glb", p, 0.7, rng.randf() * TAU)
	for p in [Vector3(-34, 0, -20), Vector3(34, 0, 0), Vector3(30, 0, 24)]:
		var d := U.place(self, U.CR + "dumpster.glb", p, 1.6, PI / 2)
		add_obstacle(d)

func _walls():
	var b := bounds
	var walls := [
		[Vector3(b.position.x - 1, 4, b.get_center().y), Vector3(2, 8, b.size.y + 4)],
		[Vector3(b.end.x + 1, 4, b.get_center().y), Vector3(2, 8, b.size.y + 4)],
		[Vector3(b.get_center().x, 4, b.position.y - 1), Vector3(b.size.x + 4, 8, 2)],
		[Vector3(b.get_center().x, 4, b.end.y + 1), Vector3(b.size.x + 4, 8, 2)],
	]
	for w in walls:
		var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = w[1]
		cs.shape = bs; body.add_child(cs); body.position = w[0]; add_child(body)

func _blocked(p: Vector3, pad: float) -> bool:
	for r in obstacles:
		if (r as Rect2).grow(pad).has_point(Vector2(p.x, p.z)): return true
	if p.distance_to(statue_pos) < 5.0: return true
	return false

func _pick_chest_spots():
	var tries := 0
	while chest_spots.size() < 7 and tries < 500:
		tries += 1
		var p := Vector3(rng.randf_range(-33, 33), 0, rng.randf_range(-50, 28))
		if _blocked(p, 1.5) or p.length() < 6.0: continue
		var ok := true
		for q in chest_spots:
			if p.distance_to(q) < 12.0: ok = false
		if ok: chest_spots.append(p)

# push a point out of obstacles (for enemies); returns corrected position
func resolve(p: Vector3, r: float) -> Vector3:
	for o in obstacles:
		var rect: Rect2 = o
		var g := rect.grow(r)
		if g.has_point(Vector2(p.x, p.z)):
			var dl := p.x - g.position.x
			var dr := g.end.x - p.x
			var dt := p.z - g.position.y
			var db := g.end.y - p.z
			var m := minf(minf(dl, dr), minf(dt, db))
			if m == dl: p.x = g.position.x
			elif m == dr: p.x = g.end.x
			elif m == dt: p.z = g.position.y
			else: p.z = g.end.y
	p.x = clampf(p.x, bounds.position.x + r, bounds.end.x - r)
	p.z = clampf(p.z, bounds.position.y + r, bounds.end.y - r)
	return p
