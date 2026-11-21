extends Node3D
# Builds the "Hypermarché" zone: a large commercial district split in lots
# (parking lots, container yards, plazas, market), surrounded by buildings.

var obstacles: Array = []        # Rect2 (x, z, w, d) that enemies must avoid
var bounds := Rect2(-80, -95, 160, 170)
var chest_spots: Array = []
var shrine_spots: Array = []
var breakable_spots: Array = []
var rng := RandomNumberGenerator.new()
var _bscale := 1.0
var env: Environment

func build(seed_value := 1917):
	rng.seed = seed_value
	U.fonts()
	_env()
	_ground()
	_buildings()
	_lots()
	_props()
	_walls()
	_pick_spots()

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
	if RenderingServer.get_current_rendering_method() == "forward_plus":
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
	self.env = env
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
	var pm := PlaneMesh.new(); pm.size = Vector2(420, 420)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.43, 0.46)
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new(); fn.frequency = 0.02
	nt.noise = fn; nt.seamless = true; nt.width = 512; nt.height = 512
	var gr := Gradient.new(); gr.set_color(0, Color(0.86, 0.86, 0.86)); gr.set_color(1, Color(1, 1, 1)); nt.color_ramp = gr
	m.albedo_texture = nt
	m.uv1_scale = Vector3(50, 50, 50)
	m.roughness = 0.95
	g.material_override = m
	add_child(g)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	# main avenues (lane markings)
	var lm := U.solid(Color(0.92, 0.9, 0.82), 0.0, 0.9)
	for i in range(-26, 27):
		U.box(self, Vector3(1.4, 0.02, 0.18), Vector3(i * 3.0, 0.01, 0.0), lm)
		U.box(self, Vector3(0.18, 0.02, 1.4), Vector3(0.0, 0.01, i * 3.0 - 10.0), lm)

func _bld(path: String, pos: Vector3, rot: float) -> Node3D:
	var n := U.place(self, path, pos, -1, rot, _bscale)
	var a := U.world_aabb(n)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = a.size
	cs.shape = bs
	body.add_child(cs)
	body.position = a.get_center()
	add_child(body)
	return n

func _buildings():
	var ref: Node3D = U.scene(U.CC + "building-a.glb").instantiate()
	add_child(ref)
	_bscale = 12.0 / maxf(U.world_aabb(ref).size.y, 0.001)
	ref.queue_free()
	var names := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
	var sky := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]
	var b := bounds
	var i := 0
	var z := b.end.y + 4.0
	while z > b.position.y - 6.0:
		_bld(U.CC + names[i % names.size()] + ".glb", Vector3(b.position.x - 16, 0, z), PI / 2); i += 1
		_bld(U.CC + names[(i + 5) % names.size()] + ".glb", Vector3(b.end.x + 16, 0, z), -PI / 2); i += 1
		z -= 11.0
	var x := b.position.x - 6.0
	var j := 0
	while x < b.end.x + 8.0:
		var back: String = sky[j % sky.size()] if j % 3 == 0 else names[(j * 3) % names.size()]
		_bld(U.CC + back + ".glb", Vector3(x, 0, b.position.y - 16 - (6 if "sky" in back else 0)), 0.0)
		_bld(U.CC + names[(j * 5 + 2) % names.size()] + ".glb", Vector3(x, 0, b.end.y + 16), PI)
		x += 11.0; j += 1
	# hypermarket facade on the back wall
	var fz := b.position.y - 10.0
	U.box(self, Vector3(34, 3.6, 0.6), Vector3(0, 12.5, fz), U.solid(Color(0.15, 0.5, 0.28)))
	var t := U.label(self, "HYPERMARCHÉ", Vector3(0, 12.6, fz + 0.4), 340, Color(1, 1, 1), Color(0, 0, 0, 0), false, U.font_main)
	t.outline_size = 0; t.shaded = true
	var promo := U.label(self, "-70 %", Vector3(14, 16.5, fz + 0.3), 360, Color(1, 0.85, 0.1), Color(0.1, 0.05, 0, 1), false, U.font_main)
	promo.rotation_degrees = Vector3(0, 0, 8)
	U.box(self, Vector3(12, 4, 0.3), Vector3(-30, 15, fz), U.solid(Color(0.92, 0.9, 0.86)))
	var bt := U.label(self, "ACHETEZ.  CONSOMMEZ.  RECOMMENCEZ.", Vector3(-30, 15.1, fz + 0.2), 120, Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), false, U.font_main)
	bt.outline_size = 0; bt.shaded = true
	# propaganda banners on side buildings
	var lx := b.position.x - 10.5
	var rx := b.end.x + 10.5
	var slogans := ["TRAVAILLEURS DE TOUS LES PAYS, BONKEZ-VOUS", "LE PLAN QUINQUENNAL SERA BONKÉ EN 4 ANS", "LE CAPITAL EST UN TIGRE DE PAPIER. BONKEZ LE PAPIER.", "", "UN SPECTRE HANTE L'HYPERMARCHÉ", ""]
	for k in 6:
		var zz := b.end.y - 20.0 - k * 26.0
		_banner(Vector3(lx if k % 2 == 0 else rx, 9.5, zz), PI / 2 if k % 2 == 0 else -PI / 2, Vector2(5.0, 6.5), slogans[k])

func _banner(pos: Vector3, rot_y: float, size: Vector2, text: String):
	U.box(self, Vector3(size.x, size.y, 0.08), pos, U.solid(Color(0.72, 0.05, 0.1), 0.0, 0.9), Vector3(0, rot_y, 0))
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
	var a := U.world_aabb(n).grow(pad)
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

# ---------------------------------------------------------------- lots
func _lots():
	# 4 x 4 grid of lots; the two central avenues (x=0, z=-10) stay open
	var cols := 4
	var rows := 4
	var cw := bounds.size.x / cols
	var ch := bounds.size.y / rows
	var kinds := ["parking", "parking", "parking", "containers", "containers", "plaza", "market", "market", "parking", "containers", "plaza", "parking", "market", "empty", "containers", "parking"]
	var order := range(cols * rows)
	for k in range(order.size() - 1, 0, -1):
		var r := rng.randi() % (k + 1)
		var tmp = kinds[k]; kinds[k] = kinds[r]; kinds[r] = tmp
	for i in cols * rows:
		var cx := bounds.position.x + cw * (i % cols) + cw / 2.0
		var cz := bounds.position.y + ch * (i / cols) + ch / 2.0
		var c := Vector3(cx + (6.0 if cx < 0 else -6.0), 0, cz + (5.0 if cz < -10 else -5.0))
		match kinds[i]:
			"parking": _lot_parking(c)
			"containers": _lot_containers(c)
			"plaza": _lot_plaza(c)
			"market": _lot_market(c)
	_landmarks()

func _lot_parking(c: Vector3):
	var cars := ["sedan", "suv", "taxi", "hatchback-sports", "van", "suv-luxury", "sedan-sports", "police", "delivery", "truck"]
	var lm := U.solid(Color(0.92, 0.9, 0.82), 0.0, 0.9)
	for row in [-7.0, 7.0]:
		for i in range(-5, 6):
			U.box(self, Vector3(0.12, 0.02, 4.4), c + Vector3(i * 2.8, 0.01, row), lm)
			if rng.randf() < 0.4: continue
			var car := U.place(self, U.CAR + cars[rng.randi() % cars.size()] + ".glb", c + Vector3(i * 2.8 + 1.4, 0, row + rng.randf_range(-0.3, 0.3)), 1.5, PI / 2 * (1 if rng.randf() < 0.5 else -1))
			add_obstacle(car)
	for i in 3:
		U.place(self, U.SHOP + "shopping-cart.glb", c + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-3, 3)), 1.1, rng.randf() * TAU)

func _lot_containers(c: Vector3):
	var kinds := ["shipping-container-a", "shipping-container-b", "shipping-container-c"]
	var spots := [[Vector3(-6, 0, -5), 0.0], [Vector3(-2, 0, -5), 0.0], [Vector3(6, 0, 4), PI / 2], [Vector3(-8, 0, 7), PI / 2], [Vector3(9, 0, -6), 0.0]]
	for i in spots.size():
		if rng.randf() < 0.2: continue
		var cont := U.place(self, U.IND + kinds[(i + rng.randi()) % 3] + ".glb", c + spots[i][0], 2.3, spots[i][1])
		add_obstacle(cont)
	var top := U.place(self, U.IND + "shipping-container-c.glb", c + Vector3(-4, 2.3, -5), 2.3, PI / 2)
	add_obstacle(top)
	if rng.randf() < 0.6:
		var tank := U.place(self, U.IND + "detail-tank.glb", c + Vector3(3, 0, -9), 3.5, 0.0)
		add_obstacle(tank)

func _lot_market(c: Vector3):
	# stalls: counters with food and awnings
	var foods := ["bread", "cheese", "apple", "burger", "carrot", "cake", "donut", "fish", "banana"]
	for i in 6:
		var p := c + Vector3((i % 3 - 1) * 8.0, 0, (i / 3 - 0.5) * 10.0)
		var counter := U.box(self, Vector3(3.2, 1.0, 1.2), p + Vector3(0, 0.5, 0), U.solid(Color(0.55, 0.38, 0.22)))
		var aw := U.box(self, Vector3(3.6, 0.12, 2.0), p + Vector3(0, 2.6, 0.2), U.solid(Color(0.8, 0.12, 0.12) if i % 2 == 0 else Color(0.9, 0.85, 0.75)))
		for pole in [-1.6, 1.6]:
			U.box(self, Vector3(0.1, 2.6, 0.1), p + Vector3(pole, 1.3, 1.0), U.solid(Color(0.3, 0.3, 0.3)))
		for f in 3:
			var path: String = U.FOOD + foods[rng.randi() % foods.size()] + ".glb"
			if ResourceLoader.exists(path):
				U.place(self, path, p + Vector3(-1.0 + f, 1.0, 0), 0.35, rng.randf() * TAU)
		add_obstacle(counter)

func _lot_plaza(c: Vector3):
	shrine_spots.append(c)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		U.place(self, U.SUB + "tree-large.glb", c + Vector3(cos(a), 0, sin(a)) * 9.0, 5.0, rng.randf() * TAU)

func _landmarks():
	# giant matryoshka near the centre-back
	var mp := Vector3(-22, 0, -48)
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
	for z in range(int(bounds.position.y) + 10, int(bounds.end.y), 16):
		for x in [bounds.position.x + 3.0, bounds.end.x - 3.0]:
			U.place(self, U.CR + "light-square.glb", Vector3(x, 0, z), 6.5, PI / 2 if x < 0 else -PI / 2)
	for i in 30:
		var p := Vector3(rng.randf_range(bounds.position.x + 3, bounds.end.x - 3), 0, rng.randf_range(bounds.position.y + 3, bounds.end.y - 3))
		if _blocked(p, 2.0): continue
		U.place(self, U.CR + "construction-cone.glb", p, 0.7, rng.randf() * TAU)
	for i in 8:
		var p := Vector3(rng.randf_range(bounds.position.x + 5, bounds.end.x - 5), 0, rng.randf_range(bounds.position.y + 5, bounds.end.y - 5))
		if _blocked(p, 3.0) or p.length() < 8.0: continue
		var d := U.place(self, U.CR + "dumpster.glb", p, 1.6, rng.randf() * TAU)
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
	for s in shrine_spots:
		if p.distance_to(s) < 6.0: return true
	return false

func free_spot(min_from_center := 6.0, pad := 1.5) -> Vector3:
	for i in 200:
		var p := Vector3(rng.randf_range(bounds.position.x + 4, bounds.end.x - 4), 0, rng.randf_range(bounds.position.y + 4, bounds.end.y - 4))
		if not _blocked(p, pad) and p.length() >= min_from_center: return p
	return Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))

func _pick_spots():
	# extra shrine spots in open ground (in addition to plazas)
	while shrine_spots.size() < 9:
		var p := free_spot(18.0, 5.0)
		var ok := true
		for q in shrine_spots:
			if p.distance_to(q) < 25.0: ok = false
		if ok: shrine_spots.append(p)
		elif rng.randf() < 0.05: shrine_spots.append(p)
	var tries := 0
	while chest_spots.size() < 16 and tries < 800:
		tries += 1
		var p := free_spot(8.0, 1.5)
		var ok := true
		for q in chest_spots + shrine_spots:
			if p.distance_to(q) < 14.0: ok = false
		if ok: chest_spots.append(p)
	for i in 90:
		breakable_spots.append(free_spot(5.0, 1.0))

# push a point out of obstacles (for enemies); returns corrected position
func resolve(p: Vector3, r: float) -> Vector3:
	for o in obstacles:
		var g: Rect2 = (o as Rect2).grow(r)
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
