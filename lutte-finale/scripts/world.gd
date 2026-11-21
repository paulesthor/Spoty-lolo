extends Node3D
# Procedural zone generator. A level template (Levels.*) gives the global structure;
# each run gets its own layout: arena shape, BSP lots, lot contents, raised platforms
# with ramps, landmarks, chests/shrines placement, lighting mood. Maps are validated
# (everything reachable) and regenerated if needed.

var template: Dictionary = Levels.HYPERMARCHE
var obstacles: Array = []        # Rect2 (x, z, w, d) that ground enemies must avoid
var bounds := Rect2(-80, -95, 160, 170)
var cuts: Array = []             # Rect2 removed from the arena (filled with buildings)
var lots: Array = []             # [Rect2, kind]
var plateaus: Array = []         # {rect, h, ramps:[{rect, dir(Vector3), top}]}
var chest_spots: Array = []
var shrine_spots: Array = []
var breakable_spots: Array = []
var player_start := Vector3.ZERO
var shape := "rect"
var ambiance := "fin_journee"
var rng := RandomNumberGenerator.new()
var env: Environment
var _bscale := 1.0
var gen_tries := 0
var decor: Node3D
var far_smokes: Array = []

func build(seed_value := 1917, tpl: Dictionary = Levels.HYPERMARCHE):
	template = tpl
	U.fonts()
	var s := seed_value
	for attempt in 6:
		gen_tries = attempt + 1
		rng.seed = s
		_reset()
		_plan_layout()
		if _validate(): break
		s += 7777
	_env()
	_ground()
	_sidewalks()
	_buildings()
	_fill_lots()
	_props()
	decor = load("res://scripts/decor.gd").new()
	add_child(decor)
	decor.build(self)
	_walls()
	_pick_spots()

func _reset():
	obstacles.clear(); cuts.clear(); lots.clear(); plateaus.clear()
	chest_spots.clear(); shrine_spots.clear(); breakable_spots.clear()

# ---------------------------------------------------------------- layout planning (no nodes yet)
func _plan_layout():
	var w := rng.randf_range(template["width"][0], template["width"][1])
	var d := rng.randf_range(template["depth"][0], template["depth"][1])
	bounds = Rect2(-w / 2.0, -d / 2.0 - 10.0, w, d)
	shape = Levels.pick(rng, template["shapes"])
	var b := bounds
	var cw := w * rng.randf_range(0.28, 0.36)
	var cd := d * rng.randf_range(0.28, 0.36)
	match shape:
		"L":
			var corner := rng.randi() % 4
			var cx: float = b.position.x if corner % 2 == 0 else b.end.x - cw
			var cz: float = b.position.y if corner < 2 else b.end.y - cd
			cuts.append(Rect2(cx, cz, cw, cd))
		"croix":
			var kw := cw * 0.8
			var kd := cd * 0.8
			for c in [[b.position.x, b.position.y], [b.end.x - kw, b.position.y], [b.position.x, b.end.y - kd], [b.end.x - kw, b.end.y - kd]]:
				cuts.append(Rect2(c[0], c[1], kw, kd))
		"anneau":
			var iw := w * rng.randf_range(0.2, 0.26)
			var id := d * rng.randf_range(0.2, 0.26)
			var c := b.get_center()
			cuts.append(Rect2(c.x - iw / 2.0 + rng.randf_range(-6, 6), c.y - id / 2.0 + rng.randf_range(-6, 6), iw, id))
	for c in cuts: obstacles.append(c)
	# BSP split of the arena into lots, separated by avenues
	var leaves := []
	_split(Rect2(b.position.x + 4.0, b.position.y + 4.0, b.size.x - 8.0, b.size.y - 8.0), leaves, 0)
	var av: float = template["avenue"] / 2.0
	var usable := []
	for r in leaves:
		var lot: Rect2 = (r as Rect2).grow(-av)
		if lot.size.x < 14.0 or lot.size.y < 14.0: continue
		var hit := false
		for c in cuts:
			if (c as Rect2).grow(2.0).intersects(lot): hit = true
		if not hit: usable.append(lot)
	# the most central lot stays an open square where the player starts
	var centre := b.get_center()
	usable.sort_custom(func(a, c): return a.get_center().distance_to(centre) < c.get_center().distance_to(centre))
	var start_lot: Rect2 = usable.pop_front() if not usable.is_empty() else Rect2(centre.x - 8, centre.y - 8, 16, 16)
	player_start = Vector3(start_lot.get_center().x, 0, start_lot.get_center().y)
	lots.append([start_lot, "start"])
	usable.shuffle()
	# guaranteed lot kinds first, then weighted picks
	var kinds := []
	for k in template["min"]:
		for i in template["min"][k]: kinds.append(k)
	while kinds.size() < usable.size():
		kinds.append(Levels.pick(rng, template["lots"]))
	for i in usable.size():
		lots.append([usable[i], kinds[i]])
	# plan raised platforms (they affect pathing and validation)
	for l in lots:
		if l[1] in PLATEAU_LOTS: _plan_plateaus(l[0], l[1])

const PLATEAU_LOTS := ["quai", "chantier", "passerelle", "estrade"]

func _split(r: Rect2, out: Array, depth: int):
	var mn: float = template["lot_size"][0]
	var mx: float = template["lot_size"][1]
	var can_x := r.size.x > mn * 2.0
	var can_z := r.size.y > mn * 2.0
	if (not can_x and not can_z) or (r.size.x <= mx and r.size.y <= mx and rng.randf() < 0.45 and depth > 1):
		out.append(r); return
	var along_x := can_x and (not can_z or r.size.x > r.size.y * rng.randf_range(0.8, 1.25))
	if along_x:
		var cut := rng.randf_range(mn, r.size.x - mn)
		_split(Rect2(r.position.x, r.position.y, cut, r.size.y), out, depth + 1)
		_split(Rect2(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y), out, depth + 1)
	else:
		var cut := rng.randf_range(mn, r.size.y - mn)
		_split(Rect2(r.position.x, r.position.y, r.size.x, cut), out, depth + 1)
		_split(Rect2(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut), out, depth + 1)

func _plan_plateaus(lot: Rect2, kind: String):
	var h := 3.0 if kind == "quai" else rng.randf_range(2.6, 3.4)
	if kind == "passerelle": h = rng.randf_range(3.8, 4.6)
	if kind == "estrade": h = 2.2
	var pw := lot.size.x * rng.randf_range(0.45, 0.6)
	var pd := lot.size.y * rng.randf_range(0.45, 0.6)
	var px := lot.position.x + rng.randf_range(2.0, lot.size.x - pw - 2.0)
	var pz := lot.position.y + rng.randf_range(2.0, lot.size.y - pd - 2.0)
	var rect := Rect2(px, pz, pw, pd)
	var ramps := []
	var sides := [0, 1, 2, 3]
	sides.shuffle()
	var n := 2 if kind in ["quai", "passerelle", "estrade"] else 1 + rng.randi() % 2
	for i in n:
		var side: int = sides[i]
		var rl := h * 3.2      # ramp length (~17 degrees)
		var rw := 4.0
		var rr: Rect2
		var dir: Vector3      # uphill direction
		match side:
			0: rr = Rect2(px + pw * 0.5 - rw / 2.0, pz - rl, rw, rl); dir = Vector3(0, 0, 1)
			1: rr = Rect2(px + pw * 0.5 - rw / 2.0, pz + pd, rw, rl); dir = Vector3(0, 0, -1)
			2: rr = Rect2(px - rl, pz + pd * 0.5 - rw / 2.0, rl, rw); dir = Vector3(1, 0, 0)
			3: rr = Rect2(px + pw, pz + pd * 0.5 - rw / 2.0, rl, rw); dir = Vector3(-1, 0, 0)
		if not lot.grow(2.0).encloses(rr): continue
		ramps.append({"rect": rr, "dir": dir})
	if ramps.is_empty():
		var rl2 := h * 3.2
		ramps.append({"rect": Rect2(px + pw * 0.5 - 2.0, pz - rl2, 4.0, rl2), "dir": Vector3(0, 0, 1)})
	plateaus.append({"rect": rect, "h": h, "ramps": ramps, "kind": kind})

# ---------------------------------------------------------------- validation (flood fill on a 2 m grid)
func _validate() -> bool:
	var cell := 2.0
	var nx := int(bounds.size.x / cell)
	var nz := int(bounds.size.y / cell)
	var blocked := {}
	var free_count := 0
	for ix in nx:
		for iz in nz:
			var p := Vector2(bounds.position.x + (ix + 0.5) * cell, bounds.position.y + (iz + 0.5) * cell)
			var b := false
			for c in cuts:
				if (c as Rect2).has_point(p): b = true; break
			if b: blocked[Vector2i(ix, iz)] = true
			else: free_count += 1
	var sx := int((player_start.x - bounds.position.x) / cell)
	var sz := int((player_start.z - bounds.position.y) / cell)
	var seen := {Vector2i(sx, sz): true}
	var stack := [Vector2i(sx, sz)]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz: continue
			if seen.has(n) or blocked.has(n): continue
			seen[n] = true
			stack.append(n)
	return seen.size() >= free_count * 0.98

# ---------------------------------------------------------------- ground height (plateaus and ramps)
func plateau_at(p: Vector3) -> int:
	for i in plateaus.size():
		if (plateaus[i]["rect"] as Rect2).has_point(Vector2(p.x, p.z)): return i
	return -1

func ramp_at(p: Vector3) -> Array:
	for i in plateaus.size():
		for r in plateaus[i]["ramps"]:
			if (r["rect"] as Rect2).has_point(Vector2(p.x, p.z)): return [i, r]
	return []

# height of a ramp at p (0 at the bottom, plateau height at the top)
func ramp_height(p: Vector3, i: int, r: Dictionary) -> float:
	var rect: Rect2 = r["rect"]
	var dir: Vector3 = r["dir"]
	var k := 0.0
	if dir.z > 0.5: k = (p.z - rect.position.y) / rect.size.y
	elif dir.z < -0.5: k = (rect.end.y - p.z) / rect.size.y
	elif dir.x > 0.5: k = (p.x - rect.position.x) / rect.size.x
	else: k = (rect.end.x - p.x) / rect.size.x
	return clampf(k, 0.0, 1.0) * plateaus[i]["h"]

# ---------------------------------------------------------------- lighting
func _env():
	ambiance = Levels.pick(rng, template["ambiances"])
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.2
	env.fog_enabled = true
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	match ambiance:
		"fin_journee":
			ps.sky_top_color = Color(0.3, 0.42, 0.6); ps.sky_horizon_color = Color(0.95, 0.72, 0.5); ps.ground_horizon_color = Color(0.95, 0.72, 0.5)
			env.ambient_light_energy = 0.7; env.fog_light_color = Color(0.8, 0.68, 0.58); env.fog_density = 0.004
			env.adjustment_saturation = 0.92; env.adjustment_contrast = 1.12
			sun.light_color = Color(1.0, 0.72, 0.45); sun.light_energy = 1.6; sun.rotation_degrees = Vector3(-17, -60, 0)
		"couvert":
			ps.sky_top_color = Color(0.42, 0.5, 0.6); ps.sky_horizon_color = Color(0.72, 0.74, 0.76); ps.ground_horizon_color = Color(0.72, 0.74, 0.76)
			env.ambient_light_energy = 0.75; env.fog_light_color = Color(0.62, 0.64, 0.7); env.fog_density = 0.0028
			env.adjustment_saturation = 0.95; env.adjustment_contrast = 1.16
			sun.light_color = Color(1.0, 0.96, 0.9); sun.light_energy = 1.1; sun.rotation_degrees = Vector3(-42, -30, 0)
		"aube":
			ps.sky_top_color = Color(0.25, 0.32, 0.55); ps.sky_horizon_color = Color(0.95, 0.6, 0.65); ps.ground_horizon_color = Color(0.95, 0.6, 0.65)
			env.ambient_light_energy = 0.65; env.fog_light_color = Color(0.75, 0.62, 0.68); env.fog_density = 0.005
			env.adjustment_saturation = 0.9; env.adjustment_contrast = 1.1
			sun.light_color = Color(1.0, 0.75, 0.7); sun.light_energy = 1.3; sun.rotation_degrees = Vector3(-14, 120, 0)
		"nuit":
			ps.sky_top_color = Color(0.05, 0.06, 0.14); ps.sky_horizon_color = Color(0.35, 0.2, 0.4); ps.ground_horizon_color = Color(0.35, 0.2, 0.4)
			env.ambient_light_energy = 0.85; env.fog_light_color = Color(0.3, 0.25, 0.4); env.fog_density = 0.005
			env.adjustment_saturation = 1.05; env.adjustment_contrast = 1.1
			sun.light_color = Color(0.65, 0.7, 1.0); sun.light_energy = 0.9; sun.rotation_degrees = Vector3(-35, 40, 0)
	# stylised poster sky (colours from the mood above)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sm.set_shader_parameter("top_col", ps.sky_top_color)
	sm.set_shader_parameter("horizon_col", ps.sky_horizon_color)
	sm.set_shader_parameter("ground_col", ps.sky_horizon_color.darkened(0.45))
	sm.set_shader_parameter("offset", Vector2(rng.randf() * 50.0, rng.randf() * 50.0))
	match ambiance:
		"fin_journee": sm.set_shader_parameter("cloud_col", Color(1.0, 0.86, 0.7)); sm.set_shader_parameter("cloud_shadow", Color(0.72, 0.52, 0.55))
		"couvert": sm.set_shader_parameter("cloud_col", Color(0.86, 0.87, 0.9)); sm.set_shader_parameter("cloud_shadow", Color(0.55, 0.58, 0.64)); sm.set_shader_parameter("cloud_amount", 0.95); sm.set_shader_parameter("cloud_scale", 1.0)
		"aube": sm.set_shader_parameter("cloud_col", Color(1.0, 0.8, 0.8)); sm.set_shader_parameter("cloud_shadow", Color(0.6, 0.45, 0.6))
		"nuit": sm.set_shader_parameter("cloud_col", Color(0.28, 0.24, 0.38)); sm.set_shader_parameter("cloud_shadow", Color(0.12, 0.1, 0.2)); sm.set_shader_parameter("cloud_amount", 0.5); sm.set_shader_parameter("stars", 0.9)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true; env.ssao_radius = 1.5; env.ssao_intensity = 3.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	we.environment = env
	add_child(we)
	add_child(sun)

func _ground():
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(500, 500)
	g.mesh = pm
	# textured asphalt (trading floor tiles in La Bourse), tinted per zone
	var gc: Color = template.get("ground", Color(0.42, 0.43, 0.46))
	var tint := Color(gc.r * 2.0, gc.g * 2.0, gc.b * 2.0)
	var m: StandardMaterial3D
	if template.get("id", "") == "bourse":
		m = U.pbr("Marble012", 0.08, Color(0.42, 0.4, 0.48), 0.6)
	else:
		m = U.pbr("Asphalt031", 0.18, tint, 0.7)
	g.material_override = m
	add_child(g)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	# avenue lane markings around each lot
	var lm := U.solid(Color(0.92, 0.9, 0.82), 0.0, 0.9)
	for l in lots:
		var r: Rect2 = l[0]
		var z := r.end.y + 2.0
		var x := r.position.x
		while x < r.end.x:
			U.box(self, Vector3(1.4, 0.02, 0.18), Vector3(x + 0.7, 0.01, z), lm)
			x += 3.0

# ---------------------------------------------------------------- buildings (border + cuts)
func _bld(path: String, pos: Vector3, rot: float) -> Node3D:
	var n := U.place(self, path, pos, -1, rot, _bscale)
	U.detailize(n, ["Plaster001", "Bricks105", "Plaster001", "Concrete034"][rng.randi() % 4], 0.35)
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

const BNAMES := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
const SKY := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]

func _buildings():
	var ref: Node3D = U.scene(U.CC + "building-a.glb").instantiate()
	add_child(ref)
	_bscale = 12.0 / maxf(U.world_aabb(ref).size.y, 0.001)
	ref.queue_free()
	var b := bounds
	var i := rng.randi() % 14
	var z := b.end.y + 4.0
	while z > b.position.y - 6.0:
		_dress(_bld(U.CC + BNAMES[i % 14] + ".glb", Vector3(b.position.x - 16, 0, z), PI / 2), Vector3(1, 0, 0)); i += 1
		_dress(_bld(U.CC + BNAMES[(i + 5) % 14] + ".glb", Vector3(b.end.x + 16, 0, z), -PI / 2), Vector3(-1, 0, 0)); i += 1
		z -= 11.0
	var x := b.position.x - 6.0
	var j := rng.randi() % 5
	while x < b.end.x + 8.0:
		var back: String = SKY[j % 5] if rng.randf() < template.get("sky_ratio", 0.33) else BNAMES[(j * 3) % 14]
		_dress(_bld(U.CC + back + ".glb", Vector3(x, 0, b.position.y - 16 - (6 if "sky" in back else 0)), 0.0), Vector3(0, 0, 1))
		var front_b: String = SKY[(j + 2) % 5] if rng.randf() < template.get("sky_ratio", 0.33) * 0.6 else BNAMES[(j * 5 + 2) % 14]
		_dress(_bld(U.CC + front_b + ".glb", Vector3(x, 0, b.end.y + 16 + (6 if "sky" in front_b else 0)), PI), Vector3(0, 0, -1))
		x += 11.0; j += 1
	# cut areas: blocks of buildings facing the arena
	for c in cuts:
		var r: Rect2 = c
		var cx := r.position.x + 6.0
		while cx < r.end.x - 2.0:
			var cz := r.position.y + 6.0
			while cz < r.end.y - 2.0:
				var cb: String = SKY[rng.randi() % 5] if rng.randf() < template.get("sky_ratio", 0.33) * 0.5 else BNAMES[rng.randi() % 14]
				_bld(U.CC + cb + ".glb", Vector3(cx, 0, cz), [0.0, PI / 2, PI, -PI / 2][rng.randi() % 4])
				cz += 11.0
			cx += 11.0
	_skyline()
	# hypermarket facade on the back wall
	var fz := b.position.y - 10.0
	var fac: Array = template["facade"]
	var steel := U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8)
	# the big signs stand on steel pylons (they used to hover in front of the buildings)
	for sx in [-15.0, 15.0]: U.box(self, Vector3(0.5, 10.8, 0.5), Vector3(sx, 5.4, fz - 0.4), steel)
	for sx in [-34.5, -25.5]: U.box(self, Vector3(0.35, 13.2, 0.35), Vector3(sx, 6.6, fz - 0.3), steel)
	U.box(self, Vector3(34, 3.6, 0.6), Vector3(0, 12.5, fz), U.solid(fac[3]))
	var t := U.label(self, fac[0], Vector3(0, 12.6, fz + 0.4), 340, Color(1, 1, 1), Color(0, 0, 0, 0), false, U.font_main)
	t.outline_size = 0; t.shaded = template["id"] != "bourse"
	var promo := U.label(self, fac[1], Vector3(13.5, 12.9, fz + 0.36), 220, Color(1, 0.85, 0.1) if template["id"] != "bourse" else Color(0.3, 1, 0.4), Color(0.1, 0.05, 0, 1), false, U.font_main)
	promo.rotation_degrees = Vector3(0, 0, 8)
	U.box(self, Vector3(12, 4, 0.3), Vector3(-30, 15, fz), U.solid(Color(0.92, 0.9, 0.86)))
	var bt := U.label(self, fac[2], Vector3(-30, 15.1, fz + 0.2), 120, Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), false, U.font_main)
	bt.width = 11.0 / bt.pixel_size; bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.outline_size = 0; bt.shaded = true
	var slogans: Array = template["slogans"].duplicate()
	slogans.append_array(["", ""])
	slogans.shuffle()
	for k in 6:
		var zz := b.end.y - 20.0 - k * (b.size.y - 30.0) / 6.0
		_banner(Vector3(b.position.x - 10.5 if k % 2 == 0 else b.end.x + 10.5, 9.5, zz), PI / 2 if k % 2 == 0 else -PI / 2, Vector2(5.0, 6.5), slogans[k])

func _banner(pos: Vector3, rot_y: float, size: Vector2, text: String):
	# propaganda boards on two posts (free-standing, so they never hover)
	var side := Vector3(cos(rot_y), 0, -sin(rot_y))
	for sd in [-1.0, 1.0]:
		var pp: Vector3 = pos + side * sd * (size.x * 0.5 - 0.15) - Vector3(sin(rot_y), 0, cos(rot_y)) * 0.1
		U.box(self, Vector3(0.22, pos.y + size.y * 0.5, 0.22), Vector3(pp.x, (pos.y + size.y * 0.5) / 2.0, pp.z), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
	U.box(self, Vector3(size.x + 0.2, size.y + 0.2, 0.08), pos, U.solid(Color(0.25, 0.22, 0.2), 0.0, 0.9), Vector3(0, rot_y, 0))
	var fwd := Vector3(sin(rot_y), 0, cos(rot_y))
	var idx := rng.randi()
	U.poster(self, U.propaganda_tex(idx), pos + fwd * 0.05, size, rot_y)
	U.poster(self, U.propaganda_tex(idx + 3), pos - fwd * 0.05, size, rot_y + PI)

func add_obstacle(n: Node3D, collide := true, pad := 0.0) -> AABB:
	var a := U.world_aabb(n).grow(pad)
	obstacles.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	if collide: _static_box(a.get_center(), a.size)
	return a

func _static_box(center: Vector3, size: Vector3, rot := Vector3.ZERO):
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = center
	body.rotation = rot
	add_child(body)

# ---------------------------------------------------------------- lot contents
func _fill_lots():
	for l in lots:
		var r: Rect2 = l[0]
		_lot_floor(r, l[1])
		match l[1]:
			"parking": _lot_parking(r)
			"containers": _lot_containers(r)
			"market": _lot_market(r)
			"plaza": _lot_plaza(r)
			"square": _lot_square(r)
			"station": _lot_station(r)
			"empty": _lot_empty(r)
			"start": _lot_empty(r, true)
			"bureaux": _lot_bureaux(r)
			"corbeille": _lot_corbeille(r)
			"ecrans": _lot_ecrans(r)
			"coffre": _lot_coffre(r)
	for i in plateaus.size(): _build_plateau(i)

func _v(x: float, z: float) -> Vector3:
	return Vector3(x, 0, z)

func _lot_parking(r: Rect2):
	var cars := ["sedan", "suv", "taxi", "hatchback-sports", "suv-luxury", "sedan-sports", "police"]
	var lm := U.solid(Color(0.92, 0.9, 0.82), 0.0, 0.9)
	var horizontal := r.size.x >= r.size.y
	var rows := maxi(1, int((r.size.y if horizontal else r.size.x) / 12.0))
	for row in rows:
		var off := (row + 0.5) * (r.size.y if horizontal else r.size.x) / rows
		var length := r.size.x if horizontal else r.size.y
		var n := int(length / 3.6)
		for i in n:
			var along := i * 3.6 + 1.8
			var p := _v(r.position.x + along, r.position.y + off) if horizontal else _v(r.position.x + off, r.position.y + along)
			if horizontal: U.box(self, Vector3(0.12, 0.02, 4.4), p + Vector3(-1.4, 0.01, 0), lm)
			else: U.box(self, Vector3(4.4, 0.02, 0.12), p + Vector3(0, 0.01, -1.4), lm)
			if rng.randf() < 0.42 or i == n / 2: continue
			var rot := (PI / 2 if horizontal else 0.0) + (PI if rng.randf() < 0.5 else 0.0)
			var car := U.place(self, U.CAR + cars[rng.randi() % cars.size()] + ".glb", p, 1.5, rot)
			add_obstacle(car)
	for i in 2:
		var cp := _v(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if _blocked(cp, 1.0): continue
		U.place(self, U.SHOP + "shopping-cart.glb", cp, 1.1, rng.randf() * TAU)
		small_obstacle(cp, 0.6)

func _lot_containers(r: Rect2):
	# a little maze: grid of container slots, randomly filled, some stacked
	var kinds := ["shipping-container-a", "shipping-container-b", "shipping-container-c"]
	var cx := r.position.x + 4.0
	while cx < r.end.x - 4.0:
		var cz := r.position.y + 3.0
		while cz < r.end.y - 3.0:
			if rng.randf() < 0.48:
				var rot := 0.0 if rng.randf() < 0.6 else PI / 2
				var c := U.place(self, U.IND + kinds[rng.randi() % 3] + ".glb", _v(cx, cz), 2.3, rot)
				U.detailize(c, "CorrugatedSteel009", 0.6)
				add_obstacle(c)
				if rng.randf() < 0.25:
					var top := U.place(self, U.IND + kinds[rng.randi() % 3] + ".glb", Vector3(cx, 2.3, cz), 2.3, rot)
					add_obstacle(top)
			cz += 7.0
		cx += 8.5

func _lot_market(r: Rect2):
	var foods := ["bread", "cheese", "apple", "burger", "carrot", "cake", "donut", "fish", "banana"]
	var cols := maxi(1, int(r.size.x / 9.0))
	var rows := maxi(1, int(r.size.y / 10.0))
	for ix in cols:
		for iz in rows:
			if rng.randf() < 0.2: continue
			var p := _v(r.position.x + (ix + 0.5) * r.size.x / cols, r.position.y + (iz + 0.5) * r.size.y / rows)
			var counter := U.box(self, Vector3(3.2, 1.0, 1.2), p + Vector3(0, 0.5, 0), U.solid(Color(0.55, 0.38, 0.22)))
			U.box(self, Vector3(3.6, 0.12, 2.0), p + Vector3(0, 2.6, 0.2), U.solid(Color(0.8, 0.12, 0.12) if (ix + iz) % 2 == 0 else Color(0.9, 0.85, 0.75)))
			for pole in [-1.6, 1.6]:
				U.box(self, Vector3(0.1, 2.6, 0.1), p + Vector3(pole, 1.3, 1.0), U.solid(Color(0.3, 0.3, 0.3)))
			for f in 3:
				var path: String = U.FOOD + foods[rng.randi() % foods.size()] + ".glb"
				if ResourceLoader.exists(path):
					U.place(self, path, p + Vector3(-1.05 + f * 1.05, 1.0, 0), 0.3, rng.randf() * TAU)
			add_obstacle(counter)

func _lot_plaza(r: Rect2):
	var c := _v(r.get_center().x, r.get_center().y)
	shrine_spots.append(c)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var tp := c + Vector3(cos(a), 0, sin(a)) * clampf(minf(r.size.x, r.size.y) * 0.45, 9.5, 12.0)
		if not r.grow(-1.0).has_point(Vector2(tp.x, tp.z)): continue
		U.nature(self, ["maple_tree_1", "maple_tree_2", "normal_tree_1", "normal_tree_3", "maple_tree_4", "normal_tree_4"][rng.randi() % 6], tp, rng.randf_range(5.5, 7.0), rng.randf() * TAU)
		_undergrowth(tp)
		obstacles.append(Rect2(tp.x - 0.5, tp.z - 0.5, 1.0, 1.0))      # trunk: nothing else gets placed on it

func _lot_square(r: Rect2):
	var c := _v(r.get_center().x, r.get_center().y)
	if rng.randf() < 0.5:
		_matryoshka(c)
	else:
		var basin := U.cyl(self, 3.0, 0.8, c + Vector3(0, 0.4, 0), U.solid(Color(0.6, 0.58, 0.55)))
		U.cyl(self, 2.7, 0.1, c + Vector3(0, 0.75, 0), U.solid(Color(0.3, 0.5, 0.7), 0.0, 0.1))
		U.cyl(self, 0.3, 2.4, c + Vector3(0, 1.2, 0), U.solid(Color(0.6, 0.58, 0.55)))
		obstacles.append(Rect2(c.x - 3, c.z - 3, 6, 6)); _static_box(c + Vector3(0, 0.4, 0), Vector3(6, 0.8, 6))
	for i in 6:
		var a := rng.randf() * TAU
		var tp := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(7.0, minf(r.size.x, r.size.y) * 0.45)
		if _blocked(tp, 1.5): continue
		if i % 2 == 0:
			U.nature(self, ["birch_tree_1", "birch_tree_2", "normal_tree_2", "maple_tree_3"][rng.randi() % 4], tp, rng.randf_range(5.0, 6.5), rng.randf() * TAU)
			_undergrowth(tp)
		else:
			U.nature(self, ["bush_large", "bush_large_flowers", "bush_flowers", "bush"][rng.randi() % 4], tp, rng.randf_range(1.2, 1.8), rng.randf() * TAU)
			obstacles.append(Rect2(tp.x - 1.0, tp.z - 1.0, 2.0, 2.0))
		obstacles.append(Rect2(tp.x - 0.5, tp.z - 0.5, 1.0, 1.0))

func _matryoshka(mp: Vector3):
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

func _lot_station(r: Rect2):
	# petrol station: canopy on pillars, pumps, a small shop
	var c := _v(r.get_center().x, r.get_center().y)
	U.box(self, Vector3(14, 0.5, 9), c + Vector3(0, 4.5, 0), U.solid(Color(0.85, 0.12, 0.12)))
	U.label(self, "PÉTROLE DU PEUPLE", c + Vector3(0, 4.5, 4.6), 90, Color(1, 0.95, 0.85), Color(0, 0, 0, 0), false, U.font_main)
	for px in [-5.5, 5.5]:
		for pz in [-3.5, 3.5]:
			U.box(self, Vector3(0.4, 4.5, 0.4), c + Vector3(px, 2.25, pz), U.solid(Color(0.8, 0.8, 0.8)))
	for px in [-3.0, 3.0]:
		var pump := U.box(self, Vector3(0.9, 1.6, 0.6), c + Vector3(px, 0.8, 0), U.solid(Color(0.9, 0.85, 0.2)))
		add_obstacle(pump)
	var shop := U.box(self, Vector3(8, 3.5, 5), c + Vector3(0, 1.75, -r.size.y * 0.3), U.solid(Color(0.85, 0.82, 0.75)))
	add_obstacle(shop)

func _lot_empty(r: Rect2, start := false):
	for i in (2 if start else 5):
		var cp := _v(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if _blocked(cp, 0.8): continue
		U.place(self, U.CR + "construction-cone.glb", cp, 0.7, rng.randf() * TAU)
		small_obstacle(cp, 0.4)

func _build_plateau(i: int):
	var pl: Dictionary = plateaus[i]
	var r: Rect2 = pl["rect"]
	var h: float = pl["h"]
	var col: Color = {"quai": Color(0.55, 0.53, 0.5), "chantier": Color(0.75, 0.6, 0.25), "passerelle": Color(0.45, 0.55, 0.62), "estrade": Color(0.55, 0.12, 0.14)}.get(pl["kind"], Color(0.6, 0.6, 0.6))
	var c := Vector3(r.get_center().x, h / 2.0, r.get_center().y)
	var mi := U.box(self, Vector3(r.size.x, h, r.size.y), c, U.pbr("Marble012" if pl["kind"] == "estrade" else "Concrete034", 0.3, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6), 1.0))
	_plateau_dress(r, h, pl["kind"], col)
	_static_box(c, Vector3(r.size.x, h, r.size.y))
	# railing posts and stripes so the edge reads clearly
	U.box(self, Vector3(r.size.x, 0.12, r.size.y), Vector3(c.x, h + 0.06, c.z), U.pbr("PavingStones138" if pl["kind"] != "estrade" else "Marble012", 0.45, Color(1, 1, 1) if pl["kind"] != "estrade" else Color(1.2, 0.5, 0.5), 0.9))
	if pl["kind"] == "chantier":
		for k in 4:
			U.box(self, Vector3(0.2, 2.5, 0.2), Vector3(r.position.x + 0.5 + k * (r.size.x - 1.0) / 3.0, h + 1.25, r.position.y + 0.5), U.solid(Color(0.4, 0.4, 0.42), 0.0, 0.4, 0.8))
		U.box(self, Vector3(r.size.x - 0.6, 0.9, 0.08), Vector3(c.x, h + 2.6, r.position.y + 0.5), U.solid(Color(0.15, 0.15, 0.17)))
		U.label(self, "CHANTIER DU PEUPLE", Vector3(c.x, h + 2.6, r.position.y + 0.44), 80, Color(1, 0.85, 0.3), Color(0, 0, 0, 1), false)
	elif pl["kind"] == "passerelle":
		var glass := U.solid(Color(0.6, 0.8, 0.95, 0.35), 0.3, 0.1, 0.2)
		U.box(self, Vector3(r.size.x, 1.0, 0.08), Vector3(c.x, h + 0.5, r.position.y), glass)
		U.box(self, Vector3(r.size.x, 1.0, 0.08), Vector3(c.x, h + 0.5, r.end.y), glass)
		U.label(self, "PASSERELLE DES CADRES · ACCÈS INTERDIT AU PEUPLE", Vector3(c.x, h * 0.3, r.position.y - 0.12), 60, Color(1, 1, 1), Color(0, 0, 0, 1), false)
	elif pl["kind"] == "estrade":
		U.label(self, "ESTRADE DES ACTIONNAIRES", Vector3(c.x, h * 0.55, r.position.y - 0.12), 70, Color(1, 0.85, 0.3), Color(0, 0, 0, 1), false)
		for k in 2:
			U.place(self, U.CAR + "box.glb", Vector3(r.position.x + 2.0 + k * 1.5, h, r.position.y + 2.0), 0.9, rng.randf() * TAU)
	else:
		U.label(self, "QUAI DE CHARGEMENT", Vector3(c.x, h * 0.82, r.position.y - 0.12), 70, Color(1, 1, 1), Color(0, 0, 0, 1), false)
		for k in 3:
			U.place(self, U.CAR + "box.glb", Vector3(r.position.x + 2.0 + k * 1.5, h, r.position.y + 2.0), 0.9, rng.randf() * TAU)
	for rp in pl["ramps"]:
		var rr: Rect2 = rp["rect"]
		var dir: Vector3 = rp["dir"]
		var length: float = rr.size.y if absf(dir.z) > 0.5 else rr.size.x
		var width: float = rr.size.x if absf(dir.z) > 0.5 else rr.size.y
		var ang := atan2(h, length)
		var slope := sqrt(h * h + length * length)
		var rc := Vector3(rr.get_center().x, h / 2.0, rr.get_center().y)
		var rot := Vector3.ZERO
		var size := Vector3(width, 0.3, slope)
		if absf(dir.z) > 0.5:
			rot = Vector3(ang if dir.z < 0 else -ang, 0, 0)
		else:
			size = Vector3(slope, 0.3, width)
			rot = Vector3(0, 0, -ang if dir.x < 0 else ang)
		var ramp := U.box(self, size, rc, U.pbr("Concrete034", 0.4, Color(0.9, 0.9, 0.88)), rot)
		_static_box(rc, size, rot)
	# ground enemies treat the plateau body as an obstacle (they use the ramps)
	obstacles.append(r)

func _props():
	var b := bounds
	for z in range(int(b.position.y) + 10, int(b.end.y), 18):
		for x in [b.position.x + 3.0, b.end.x - 3.0]:
			var p := Vector3(x, 0, z)
			if not _in_cut(p):
				U.place(self, U.CR + "light-square.glb", p, 6.5, PI / 2 if x < 0 else -PI / 2)
				small_obstacle(p, 0.6)
	for i in 12:
		var p := free_spot(6.0, 3.0)
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
	for c in cuts:
		var r: Rect2 = c
		walls.append([Vector3(r.get_center().x, 4, r.get_center().y), Vector3(r.size.x, 8, r.size.y)])
	for w in walls: _static_box(w[0], w[1])

func _in_cut(p: Vector3) -> bool:
	for c in cuts:
		if (c as Rect2).grow(1.0).has_point(Vector2(p.x, p.z)): return true
	return false

func inside(p: Vector3) -> bool:
	return bounds.grow(-1.0).has_point(Vector2(p.x, p.z)) and not _in_cut(p)

func _blocked(p: Vector3, pad: float) -> bool:
	for r in obstacles:
		if (r as Rect2).grow(pad).has_point(Vector2(p.x, p.z)): return true
	for pl in plateaus:
		for rp in pl["ramps"]:
			if (rp["rect"] as Rect2).grow(pad).has_point(Vector2(p.x, p.z)): return true
	for s in shrine_spots:
		if p.distance_to(s) < 6.0: return true
	return false

func free_spot(min_from_start := 6.0, pad := 1.5) -> Vector3:
	for i in 300:
		var p := Vector3(rng.randf_range(bounds.position.x + 4, bounds.end.x - 4), 0, rng.randf_range(bounds.position.y + 4, bounds.end.y - 4))
		if inside(p) and not _blocked(p, pad) and p.distance_to(player_start) >= min_from_start: return p
	return player_start + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))

func _pick_spots():
	var tries := 0
	while shrine_spots.size() < 9 and tries < 400:
		tries += 1
		var p := free_spot(18.0, 7.0)
		var ok := true
		for q in shrine_spots:
			if p.distance_to(q) < 24.0: ok = false
		if ok: shrine_spots.append(p)
	tries = 0
	while chest_spots.size() < 16 and tries < 800:
		tries += 1
		var p := free_spot(8.0, 1.5)
		var ok := true
		for q in chest_spots + shrine_spots:
			if p.distance_to(q) < 14.0: ok = false
		if ok: chest_spots.append(p)
	# a couple of chests on top of plateaus (reward for climbing)
	for pl in plateaus:
		var r: Rect2 = pl["rect"]
		chest_spots.append(Vector3(r.get_center().x + 1.5, pl["h"], r.get_center().y))
	for i in 100:
		breakable_spots.append(free_spot(5.0, 1.6))

# push a point out of obstacles (for ground enemies); returns corrected position
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

# ---------------------------------------------------------------- zone 2 / zone 3 lots
# open-space: rows of desks with screens (low obstacles)
func _lot_bureaux(r: Rect2):
	var desk := U.solid(Color(0.85, 0.85, 0.82), 0.0, 0.7)
	var scr := U.solid(Color(0.1, 0.12, 0.15), 0.0, 0.3)
	var glow := U.solid(Color(0.4, 0.7, 1.0), 2.0)
	var rows := maxi(1, int(r.size.y / 8.0))
	for iz in rows:
		var z := r.position.y + (iz + 0.5) * r.size.y / rows
		var x := r.position.x + 3.0
		while x < r.end.x - 5.0:
			if rng.randf() < 0.75:
				var dk := U.box(self, Vector3(3.6, 0.9, 1.6), Vector3(x + 1.8, 0.45, z), desk)
				U.box(self, Vector3(0.8, 0.55, 0.06), Vector3(x + 1.0, 1.2, z - 0.4), scr)
				U.box(self, Vector3(0.7, 0.45, 0.02), Vector3(x + 1.0, 1.2, z - 0.36), glow)
				U.box(self, Vector3(0.8, 0.55, 0.06), Vector3(x + 2.6, 1.2, z - 0.4), scr)
				add_obstacle(dk)
			x += 5.5
	var c := _v(r.get_center().x, r.get_center().y)
	_lot_sign(c, "OPEN SPACE", Color(1, 1, 1))

# trading pit: ring of desks around a giant ticker screen
func _lot_corbeille(r: Rect2):
	var c := _v(r.get_center().x, r.get_center().y)
	shrine_spots.append(c + Vector3(0, 0, minf(r.size.x, r.size.y) * 0.46))
	var rad := minf(r.size.x, r.size.y) * 0.32
	var n := 10
	for i in n:
		if i % 4 == 0: continue      # openings
		var a := TAU * i / n
		var p := c + Vector3(cos(a), 0, sin(a)) * rad
		var dk := U.box(self, Vector3(2.6, 1.0, 1.2), p + Vector3(0, 0.5, 0), U.solid(Color(0.3, 0.2, 0.15), 0.0, 0.5), Vector3(0, -a + PI / 2, 0))
		add_obstacle(dk)
	_ticker(c, 6.0)

func _ticker(p: Vector3, h: float):
	U.box(self, Vector3(0.5, h, 0.5), p + Vector3(0, h / 2.0, 0), U.solid(Color(0.2, 0.2, 0.22)))
	obstacles.append(Rect2(p.x - 0.6, p.z - 0.6, 1.2, 1.2))
	_static_box(p + Vector3(0, h / 2.0, 0), Vector3(0.5, h, 0.5))
	for k in 4:
		var rot := k * PI / 2
		var fwd := Vector3(sin(rot), 0, cos(rot))
		U.box(self, Vector3(4.0, 2.2, 0.15), p + Vector3(0, h + 1.1, 0) + fwd * 0.3, U.solid(Color(0.05, 0.05, 0.07)), Vector3(0, rot, 0))
		var up := rng.randf() < 0.5
		var t := U.label(self, ("+%d %%" if up else "-%d %%") % rng.randi_range(3, 99), p + Vector3(0, h + 1.1, 0) + fwd * 0.4, 160, Color(0.3, 1, 0.4) if up else Color(1, 0.25, 0.2), Color(0, 0, 0, 0), false, U.font_main)
		t.rotation = Vector3(0, rot, 0); t.outline_size = 0

func _lot_ecrans(r: Rect2):
	var cols := maxi(1, int(r.size.x / 12.0))
	var rows := maxi(1, int(r.size.y / 12.0))
	for ix in cols:
		for iz in rows:
			if rng.randf() < 0.3: continue
			_ticker(_v(r.position.x + (ix + 0.5) * r.size.x / cols, r.position.y + (iz + 0.5) * r.size.y / rows), rng.randf_range(3.5, 5.5))

# bank vault: stacks of gold bars to hide behind
func _lot_coffre(r: Rect2):
	var gold := U.solid(Color(1.0, 0.75, 0.25), 0.6, 0.25, 1.0)
	for i in int(r.size.x * r.size.y / 140.0):
		var p := _v(rng.randf_range(r.position.x + 3, r.end.x - 3), rng.randf_range(r.position.y + 3, r.end.y - 3))
		var h := rng.randf_range(0.6, 1.6)
		var bx := U.box(self, Vector3(2.2, h, 1.4), p + Vector3(0, h / 2.0, 0), gold)
		add_obstacle(bx)
	var c := _v(r.get_center().x, r.get_center().y)
	_lot_sign(c, "RÉSERVES FÉDÉRALES (À REDISTRIBUER)", Color(1, 0.85, 0.3))

# hanging sign over a lot: readable from afar, never a giant billboard in the camera's face
func _lot_sign(c: Vector3, text: String, col: Color):
	# a real sign: board on two posts, text on both faces
	var wdt := 0.42 * text.length() * 0.55 + 1.0
	var steel := U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8)
	for sx in [-1.0, 1.0]:
		U.box(self, Vector3(0.14, 3.0, 0.14), c + Vector3(sx * (wdt * 0.5 - 0.2), 1.5, 0), steel)
	U.box(self, Vector3(wdt, 0.9, 0.1), c + Vector3(0, 3.2, 0), U.solid(Color(0.08, 0.08, 0.1)))
	for f in [1.0, -1.0]:
		var l := U.label(self, text, c + Vector3(0, 3.2, 0.07 * f), 52, col, Color(0, 0, 0, 0), false)
		l.outline_size = 0
		l.rotation.y = 0.0 if f > 0.0 else PI
	small_obstacle(c, 0.4)

# facades for raised platforms: base band, pillars, window strips or hazard stripes
func _plateau_dress(r: Rect2, h: float, kind: String, col: Color):
	var dark := U.solid(col.darkened(0.35), 0.0, 0.8)
	var pil := U.solid(col.lightened(0.12), 0.0, 0.7)
	var sides := [[Vector3(r.get_center().x, 0, r.position.y - 0.03), r.size.x, 0.0], [Vector3(r.get_center().x, 0, r.end.y + 0.03), r.size.x, 0.0],
		[Vector3(r.position.x - 0.03, 0, r.get_center().y), r.size.y, PI / 2], [Vector3(r.end.x + 0.03, 0, r.get_center().y), r.size.y, PI / 2]]
	for sd in sides:
		var c: Vector3 = sd[0]
		var length: float = sd[1]
		var rot := Vector3(0, sd[2], 0)
		U.box(self, Vector3(length, 0.5, 0.08), c + Vector3(0, 0.25, 0), dark, rot)
		var n := int(length / 4.0)
		for k in n + 1:
			var off := -length / 2.0 + k * length / maxf(n, 1)
			var pc: Vector3 = c + Vector3(off, 0, 0).rotated(Vector3.UP, sd[2]) + Vector3(0, h / 2.0, 0)
			U.box(self, Vector3(0.35, h, 0.14), pc, pil, rot)
		match kind:
			"passerelle":
				U.box(self, Vector3(length * 0.98, h * 0.35, 0.1), c + Vector3(0, h * 0.62, 0), U.solid(Color(0.35, 0.6, 0.85), 0.6, 0.1, 0.4), rot)
			"chantier":
				for k in int(length / 1.6):
					var off2 := -length / 2.0 + 0.8 + k * 1.6
					var stripe := U.box(self, Vector3(0.6, 0.35, 0.1), c + Vector3(off2, 0, 0).rotated(Vector3.UP, sd[2]) + Vector3(0, h - 0.3, 0), U.solid(Color(0.95, 0.75, 0.1) if k % 2 == 0 else Color(0.1, 0.1, 0.1)), rot)
			"quai":
				for k in int(length / 5.0):
					var off3 := -length / 2.0 + 2.5 + k * 5.0
					U.box(self, Vector3(2.6, h * 0.65, 0.1), c + Vector3(off3, 0, 0).rotated(Vector3.UP, sd[2]) + Vector3(0, h * 0.4, 0), U.solid(Color(0.45, 0.47, 0.5), 0.0, 0.5, 0.6), rot)
			"estrade":
				U.box(self, Vector3(length, 0.25, 0.1), c + Vector3(0, h - 0.2, 0), U.solid(Color(1, 0.8, 0.3), 0.5, 0.3, 1.0), rot)

# sidewalks with a kerb around every lot: gives the ground a street structure
func _sidewalks():
	var walk := U.pbr("PavingStones138", 0.45, Color(0.95, 0.93, 0.9) if template.get("id", "") != "bourse" else Color(0.7, 0.68, 0.75), 0.9)
	var kerb := U.pbr("Concrete034", 0.5, Color(1.05, 1.05, 1.02), 0.8)
	for l in lots:
		var r: Rect2 = (l[0] as Rect2).grow(1.4)
		for e in [[Vector3(r.get_center().x, 0, r.position.y + 0.7), Vector2(r.size.x, 1.4)], [Vector3(r.get_center().x, 0, r.end.y - 0.7), Vector2(r.size.x, 1.4)],
				[Vector3(r.position.x + 0.7, 0, r.get_center().y), Vector2(1.4, r.size.y - 2.8)], [Vector3(r.end.x - 0.7, 0, r.get_center().y), Vector2(1.4, r.size.y - 2.8)]]:
			var c: Vector3 = e[0]
			var sz: Vector2 = e[1]
			var m := U.box(self, Vector3(sz.x, 0.06, sz.y), c + Vector3(0, 0.03, 0), walk)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for e2 in [[Vector3(r.get_center().x, 0, r.position.y), Vector3(r.size.x, 0.12, 0.12)], [Vector3(r.get_center().x, 0, r.end.y), Vector3(r.size.x, 0.12, 0.12)],
				[Vector3(r.position.x, 0, r.get_center().y), Vector3(0.12, 0.12, r.size.y)], [Vector3(r.end.x, 0, r.get_center().y), Vector3(0.12, 0.12, r.size.y)]]:
			var k := U.box(self, e2[1], (e2[0] as Vector3) + Vector3(0, 0.06, 0), kerb)
			k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# small footprint that later placements (props, chests, shrines) must avoid; enemies slide around it
func small_obstacle(p: Vector3, half: float):
	obstacles.append(Rect2(p.x - half, p.z - half, half * 2.0, half * 2.0))

# grass tufts and flowers at the foot of a tree (visual only, around the trunk)
func _undergrowth(p: Vector3):
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var q := p + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.8, 1.8)
		U.nature(self, ["grass_large", "grass_small", "flower_2_clump", "flower_4_clump", "plant_1"][rng.randi() % 5], q, rng.randf_range(0.35, 0.7), rng.randf() * TAU)

# each lot gets its own floor: paving on squares and markets, concrete in yards, marble in the stock exchange
func _lot_floor(r: Rect2, kind: String):
	var bourse: bool = template.get("id", "") == "bourse"
	var mat: Material = null
	match kind:
		"plaza", "square", "start", "market":
			mat = U.pbr("PavingStones138", 0.5, Color(0.88, 0.85, 0.8) if not bourse else Color(0.62, 0.6, 0.7), 0.6)
		"containers", "chantier", "quai", "station":
			mat = U.pbr("Concrete034", 0.2, Color(0.95, 0.93, 0.9), 0.8)
		"bureaux":
			mat = U.pbr("Concrete034", 0.35, Color(0.58, 0.6, 0.64), 0.5)
		"corbeille", "coffre", "ecrans", "estrade":
			mat = U.pbr("Marble012", 0.2, Color(0.75, 0.62, 0.55), 0.6)
		"passerelle":
			mat = U.pbr("PavingStones138", 0.35, Color(0.85, 0.85, 0.9), 0.9)
	if mat == null: return
	var f := U.box(self, Vector3(r.size.x, 0.04, r.size.y), Vector3(r.get_center().x, 0.02, r.get_center().y), mat)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# distant city silhouette beyond the arena (fog fades it): towers, factory chimneys, lit windows at night
func _skyline():
	var night: bool = ambiance == "nuit"
	var c := bounds.get_center()
	var dark := U.solid(Color(0.32, 0.3, 0.34) if not night else Color(0.08, 0.08, 0.12), 0.0, 0.9)
	var win := U.solid(Color(1.0, 0.8, 0.45), 3.0)
	var rad := maxf(bounds.size.x, bounds.size.y) * 0.5 + 70.0
	var n := 46
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.03, 0.03)
		var r := rad + rng.randf_range(0.0, 40.0)
		var p := Vector3(c.x + cos(a) * r, 0, c.y + sin(a) * r)
		var h := rng.randf_range(18.0, 60.0) * (1.4 if template.get("id", "") != "hypermarche" else 0.8)
		var wd := rng.randf_range(8.0, 18.0)
		var b := U.box(self, Vector3(wd, h, wd), p + Vector3(0, h / 2.0, 0), dark, Vector3(0, -a, 0))
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if night and rng.randf() < 0.8:
			for k in 6:
				var wy := rng.randf_range(4.0, h - 2.0)
				var wp := p + Vector3(-cos(a), 0, -sin(a)) * (wd * 0.5 + 0.05) + Vector3(0, wy, 0)
				var wl := U.box(self, Vector3(rng.randf_range(1.0, 3.0), 0.5, 0.1), wp, win, Vector3(0, -a + PI / 2, 0))
				wl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif template.get("id", "") == "hypermarche" and i % 9 == 0:
			var ch := U.cyl(self, 1.6, h * 1.6, p + Vector3(0, h * 0.8, 0), U.solid(Color(0.45, 0.25, 0.2), 0.0, 0.9))
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			U.cyl(self, 1.7, 1.2, p + Vector3(0, h * 1.4, 0), U.solid(Color(0.85, 0.85, 0.82)))
			far_smokes.append({"p": p + Vector3(0, h * 1.62, 0), "t": 0.0, "s": 9.0})

# building dressing on the face that looks at the arena: giant painted murals, shop signs,
# rooftop stars, water tanks, antennas and neon at night. Everything sits on the building's box.
func _dress(n: Node3D, face: Vector3):
	var a := U.world_aabb(n)
	if a.size.y < 4.0: return
	var c := a.get_center()
	var half: float = (a.size.x if absf(face.x) > 0.5 else a.size.z) * 0.5
	var depth: float = (a.size.z if absf(face.x) > 0.5 else a.size.x) * 0.5
	var front: Vector3 = Vector3(c.x, 0, c.z) + face * (depth + 0.06)
	var rot := atan2(face.x, face.z)
	var roll := rng.randf()
	var bid: String = template.get("id", "hypermarche")
	var ad_ratio: float = {"hypermarche": 0.25, "quartier": 0.5, "bourse": 0.6}.get(bid, 0.3)
	if roll < 0.32 and a.size.y > 9.0:
		# mural: a poster painted over most of the facade
		var mh := minf(a.size.y * 0.55, 11.0)
		var mw := minf(mh / 1.5, half * 1.6)
		mh = mw * 1.5
		var tex: String = U.ad_tex(rng.randi()) if rng.randf() < ad_ratio else U.propaganda_tex(rng.randi())
		var my := a.position.y + a.size.y * 0.55
		var wp := _wall_plane(n, face, my - mh * 0.5, my + mh * 0.5)
		if wp > -1e8:
			var lat := Vector3(c.x, 0, c.z) - face * Vector3(c.x, 0, c.z).dot(face)
			U.poster(self, tex, lat + face * (wp + 0.05) + Vector3(0, my, 0), Vector2(mw, mh), rot)
	elif roll < 0.6:
		# shop / office sign over the ground floor
		var names := {"hypermarche": ["BOULANGERIE D'ÉTAT", "COOPÉRATIVE N°7", "LAVERIE DU PEUPLE", "KIOSQUE PRAVDA", "PHARMACIE CENTRALE"],
			"quartier": ["CABINET DE CONSEIL", "STARTUP NATION", "COWORKING PREMIUM", "BANQUE PRIVÉE", "AGENCE DE NOTATION"],
			"bourse": ["COURTIER 24/7", "PARADIS FISCAL VOYAGES", "BIJOUTERIE", "CLUB PRIVÉ", "MONTRES DE LUXE"]}
		var txt: String = names[bid][rng.randi() % 5]
		var col: Color = [Color(0.72, 0.08, 0.1), Color(0.12, 0.25, 0.45), Color(0.15, 0.35, 0.22), Color(0.1, 0.1, 0.12)][rng.randi() % 4]
		# the wall plane at sign height: the furthest-out part of the building that spans 2.9-3.9 m
		var wall := -1e9
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var ma: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if ma.position.y > a.position.y + 2.9 or ma.end.y < a.position.y + 3.9: continue
			var ext: float = ma.get_center().dot(face) + absf((ma.size * 0.5).dot(face))
			wall = maxf(wall, ext)
		if wall < -1e8: return
		var lateral := Vector3(c.x, 0, c.z) - face * Vector3(c.x, 0, c.z).dot(face)
		var sp := lateral + face * (wall + 0.06) + Vector3(0, a.position.y + 3.4, 0)
		U.box(self, Vector3(minf(half * 1.7, 8.0), 1.0, 0.16), sp, U.solid(col, 0.25 if ambiance == "nuit" else 0.0, 0.6), Vector3(0, rot, 0))
		var l := U.label(self, txt, sp + face * 0.1, 64, Color(1, 0.95, 0.85), Color(0, 0, 0, 0), false, U.font_main)
		l.rotation.y = rot; l.outline_size = 0; l.pixel_size = 0.009
		l.width = minf(half * 1.6, 7.6) / l.pixel_size; l.autowrap_mode = TextServer.AUTOWRAP_OFF
	# rooftop items stand on the highest roof part (setbacks would leave them hovering)
	var best_top := -1.0
	var top := Vector3(c.x, a.end.y, c.z)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var ma: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		if ma.end.y > best_top and ma.size.x > 2.0 and ma.size.z > 2.0:
			best_top = ma.end.y
			top = Vector3(ma.get_center().x, ma.end.y, ma.get_center().z)
	depth = 0.0
	var r2 := rng.randf()
	if r2 < 0.25:
		var st := Label3D.new(); st.text = "★"; st.font = load("res://fonts/Symbols.ttf"); st.font_size = 256; st.pixel_size = 0.012
		st.modulate = Color(0.95, 0.12, 0.12); st.outline_size = 0; st.shaded = ambiance != "nuit"
		st.position = top + Vector3(0, 1.9, 0) + face * (depth * 0.6); st.rotation.y = rot
		add_child(st)
		U.box(self, Vector3(0.2, 1.0, 0.2), top + Vector3(0, 0.5, 0) + face * (depth * 0.6), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
	elif r2 < 0.45:
		var tk := U.place(self, U.IND + "detail-tank.glb", top + face * (-depth * 0.3), 3.2, rng.randf() * TAU)
	elif r2 < 0.6:
		U.cyl(self, 0.05, 4.0, top + Vector3(0, 2.0, 0), U.solid(Color(0.2, 0.2, 0.22), 0.0, 0.4, 0.8))
		U.cyl(self, 0.04, 1.6, top + Vector3(0, 3.2, 0), U.solid(Color(0.2, 0.2, 0.22), 0.0, 0.4, 0.8)).rotation.z = PI / 2
		if ambiance == "nuit": U.sphere(self, 0.15, top + Vector3(0, 4.05, 0), U.solid(Color(1, 0.1, 0.1), 5.0))

# outermost wall plane (along `face`) of the building parts that cover the whole height range
func _wall_plane(n: Node, face: Vector3, y0: float, y1: float) -> float:
	var wall := -1e9
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var ma: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		if ma.position.y > y0 + 0.05 or ma.end.y < y1 - 0.05: continue
		wall = maxf(wall, ma.get_center().dot(face) + absf((ma.size * 0.5).dot(face)))
	return wall
