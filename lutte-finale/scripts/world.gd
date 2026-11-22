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
var sun_light: DirectionalLight3D
var ruins: Array = []        # Berlin: {n, top: [pieces], a} (phase 2 collapses them further)
var bunker := {}             # Berlin: {rect, center, roof, block, lights}
var _bscale := 1.0
var gen_tries := 0
var decor: Node3D
var far_smokes: Array = []
var blocks: Array = []           # Rect2 lots turned into blocks of tall buildings (also in cuts)
var area_k := 1.0                # map area relative to the first prototype maps (counts scale with it)
var occluders: Array = []        # {aabb, c, meshes:[[mi, mat]], occ, ghost}: tall pieces that fade out when they hide the player
var _ghost_mat: StandardMaterial3D
var _ghost_t := 0.0
var lots2                        # themed lot builders (lots.gd)

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
	area_k = (bounds.size.x * bounds.size.y) / (165.0 * 175.0)
	lots2 = load("res://scripts/lots.gd").new()
	lots2.w = self
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
	call_deferred("_batch")

func _batch():
	var keep: Array = []
	if decor:
		for b in decor.blinkers: keep.append(b["n"])
		for sp in decor.spinners: keep.append(sp["n"])
	var n1 := U.batch_static(self, keep)
	var n2 := U.batch_static(decor, keep) if decor else 0
	print("[world] batched %d static meshes · bounds %s" % [n1 + n2, bounds])
	# small props are not drawn beyond what the gameplay camera can make out
	var culled := 0
	for g in find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = g
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null: continue
		var ab: AABB = gi.global_transform * gi.get_aabb()
		if ab.size.x < 7.0 and ab.size.z < 7.0 and ab.size.y < 12.0:
			# small props vanish at 62 m, trees and tall props a bit further (maps are big now)
			gi.visibility_range_end = 62.0 if (ab.size.y < 6.0 and ab.size.x < 5.0 and ab.size.z < 5.0) else 85.0
			gi.visibility_range_end_margin = 6.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			culled += 1
	print("[world] distance-culled %d small props" % culled)

func _reset():
	obstacles.clear(); cuts.clear(); lots.clear(); plateaus.clear(); blocks.clear()
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
	if template.get("bunker", false) and not usable.is_empty():
		# Berlin: the biggest lot away from the start becomes the bunker
		var bi := 0
		var best := -1.0
		for i in usable.size():
			var ur0: Rect2 = usable[i]
			var sc: float = minf(ur0.size.x, ur0.size.y) * 10.0 + ur0.get_center().distance_to(Vector2(player_start.x, player_start.z)) * 0.2
			if sc > best: best = sc; bi = i
		var tmp: Rect2 = usable[bi]; usable[bi] = usable[0]; usable[0] = tmp
		kinds.append("bunker")
	for k in template["min"]:
		for i in template["min"][k]: kinds.append(k)
	while kinds.size() < usable.size():
		kinds.append(Levels.pick(rng, template["lots"]))
	var n_min := 1 if template.get("bunker", false) else 0
	for k in template["min"]: n_min += int(template["min"][k])
	for i in usable.size():
		var ur: Rect2 = usable[i]
		# some lots become blocks of tall buildings: the map can't be read in one glance any more
		if i >= n_min and rng.randf() < float(template.get("blocks", 0.0)) and ur.get_center().distance_to(Vector2(player_start.x, player_start.z)) > 36.0:
			blocks.append(ur); cuts.append(ur); obstacles.append(ur)
			continue
		lots.append([usable[i], kinds[i]])
	# plan raised platforms (they affect pathing and validation)
	for l in lots:
		if l[1] in PLATEAU_LOTS: _plan_plateaus(l[0], l[1])

const PLATEAU_LOTS := ["quai", "chantier", "passerelle", "estrade", "piste"]

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
	if kind == "piste": h = rng.randf_range(4.0, 5.0)
	var pw := lot.size.x * rng.randf_range(0.45, 0.6)
	var pd := lot.size.y * rng.randf_range(0.45, 0.6)
	var px := lot.position.x + rng.randf_range(2.0, lot.size.x - pw - 2.0)
	var pz := lot.position.y + rng.randf_range(2.0, lot.size.y - pd - 2.0)
	var rect := Rect2(px, pz, pw, pd)
	var ramps := []
	var sides := [0, 1, 2, 3]
	sides.shuffle()
	var n := 2 if kind in ["quai", "passerelle", "estrade", "piste"] else 1 + rng.randi() % 2
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
	sun.shadow_enabled = int(Meta.opt("quality")) > 0
	sun.add_to_group("sun")
	sun.directional_shadow_max_distance = 48.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS     # 2 passes instead of 4
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
	sun_light = sun

func _ground():
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(700, 700)
	if template.get("skyline", "") == "sea":
		pm.size = Vector2(bounds.size.x + 110.0, bounds.size.y + 110.0)
		g.position = Vector3(bounds.get_center().x, 0, bounds.get_center().y)
	g.mesh = pm
	# textured asphalt (trading floor tiles in La Bourse), tinted per zone
	var gc: Color = template.get("ground", Color(0.42, 0.43, 0.46))
	var tint := Color(gc.r * 2.0, gc.g * 2.0, gc.b * 2.0)
	var m: StandardMaterial3D
	var gt: String = template.get("ground_tex", "Asphalt031")
	if template.get("id", "") == "bourse":
		m = U.pbr("Marble012", 0.08, Color(0.42, 0.4, 0.48), 0.6)
	elif gt != "Asphalt031":
		m = U.pbr(gt, 0.12, tint, 0.8)
	else:
		m = U.pbr("Asphalt031", 0.18, tint, 0.7)
	g.material_override = m
	add_child(g)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	if gt in ["Snow010A", "Ground080"]: return      # no road markings in the snow or the sand
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

const BORDER_OUT := 9.0      # the ring of buildings stands just behind the boundary wall

const BNAMES := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
const SKY := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]

func _buildings():
	var ref: Node3D = U.scene(U.CC + "building-a.glb").instantiate()
	add_child(ref)
	_bscale = 12.0 / maxf(U.world_aabb(ref).size.y, 0.001)
	ref.queue_free()
	var b := bounds
	var style: String = template.get("border", "city")
	var z := b.end.y + 4.0
	while z > b.position.y - 6.0:
		_tall_piece(style, Vector3(b.position.x - BORDER_OUT, 0, z), Vector3(1, 0, 0))
		_tall_piece(style, Vector3(b.end.x + BORDER_OUT, 0, z), Vector3(-1, 0, 0))
		z -= 11.0
	var x := b.position.x - 6.0
	while x < b.end.x + 8.0:
		_tall_piece(style, Vector3(x, 0, b.position.y - BORDER_OUT), Vector3(0, 0, 1), true)
		_tall_piece(style, Vector3(x, 0, b.end.y + BORDER_OUT), Vector3(0, 0, -1), true)
		x += 11.0
	# cut areas (arena shape) and inner blocks: tall buildings facing the avenues
	for c in cuts:
		_fill_block(c, template.get("block", "city") if blocks.has(c) else style)
	_skyline()
	# hypermarket facade on the back wall
	var fz := b.position.y - 2.4
	var fac: Array = template["facade"]
	var steel := U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8)
	# the big signs stand on steel pylons (they used to hover in front of the buildings)
	for sx in [-15.0, 15.0]: U.box(self, Vector3(0.5, 10.8, 0.5), Vector3(sx, 5.4, fz - 0.4), steel)
	for sx in [-34.5, -25.5]: U.box(self, Vector3(0.35, 13.2, 0.35), Vector3(sx, 6.6, fz - 0.3), steel)
	U.box(self, Vector3(34, 3.6, 0.6), Vector3(0, 12.5, fz), U.solid(fac[3]))
	var t := U.label(self, fac[0], Vector3(0, 12.6, fz + 0.32), 340, Color(1, 1, 1), Color(0, 0, 0, 0), false, U.font_main)
	U.fit_label(t, 32.0, 3.2)
	t.outline_size = 0; t.shaded = template["id"] != "bourse"
	var promo := U.label(self, fac[1], Vector3(13.5, 12.9, fz + 0.36), 220, Color(1, 0.85, 0.1) if template["id"] != "bourse" else Color(0.3, 1, 0.4), Color(0.1, 0.05, 0, 1), false, U.font_main)
	promo.rotation_degrees = Vector3(0, 0, 8)
	U.box(self, Vector3(12, 4, 0.3), Vector3(-30, 15, fz), U.solid(Color(0.92, 0.9, 0.86)))
	var bt := U.label(self, fac[2], Vector3(-30, 15.1, fz + 0.2), 120, Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), false, U.font_main)
	bt.width = 11.0 / bt.pixel_size; bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.outline_size = 0; bt.shaded = true
	_perimeter_wall()

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
			"bunker": _lot_bunker(r)
			_: lots2.build(l[1], r)
	for i in plateaus.size():
		if plateaus[i]["kind"] != "container": _build_plateau(i)

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
				var ca := add_obstacle(c)
				if rng.randf() < 0.25:
					var top := U.place(self, U.IND + kinds[rng.randi() % 3] + ".glb", Vector3(cx, 2.3, cz), 2.3, rot)
					ca = add_obstacle(top)
				# the roof is a platform: capitalists jump up there after a comrade (see enemies._hop)
				plateaus.append({"rect": Rect2(ca.position.x + 0.1, ca.position.z + 0.1, ca.size.x - 0.2, ca.size.z - 0.2), "h": ca.end.y, "ramps": [], "kind": "container"})
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
		var tl := trees()
		U.nature(self, tl[rng.randi() % tl.size()], tp, rng.randf_range(5.5, 7.0) * (1.25 if "palm" in tl[0] else 1.0), rng.randf() * TAU)
		_undergrowth(tp)
		obstacles.append(Rect2(tp.x - 0.5, tp.z - 0.5, 1.0, 1.0))      # trunk: nothing else gets placed on it

func trees() -> Array:
	match template.get("id", ""):
		"paradis": return ["palm_tree_1", "palm_tree_2", "palm_tree_3", "palm_tree_4"]
		"ski": return ["pine_tree_1", "pine_tree_2", "pine_tree_3", "pine_tree_4"]
		"fusee": return ["dead_tree_1", "dead_tree_3", "dead_tree_5", "dead_tree_7"]
		"datacenter": return ["dead_tree_2", "dead_tree_4", "birch_tree_2"]
	return ["maple_tree_1", "maple_tree_2", "maple_tree_4", "birch_tree_1", "maple_tree_1", "maple_tree_4"]

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
			var tl := trees()
			U.nature(self, tl[rng.randi() % tl.size()], tp, rng.randf_range(5.0, 6.5), rng.randf() * TAU)
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
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 1.6; cy.height = 16.0
	cs.shape = cy; body.add_child(cs); body.position = mp + Vector3(0, 8.0, 0); add_child(body)

func _lot_station(r: Rect2):
	# petrol station: canopy on pillars, pumps, a small shop
	var c := _v(r.get_center().x, r.get_center().y)
	U.box(self, Vector3(14, 0.5, 9), c + Vector3(0, 4.5, 0), U.solid(Color(0.85, 0.12, 0.12)))
	U.fit_label(U.label(self, "PÉTROLE DU PEUPLE", c + Vector3(0, 4.5, 4.52), 90, Color(1, 0.95, 0.85), Color(0, 0, 0, 0), false, U.font_main), 13.0, 0.42)
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
	var col: Color = {"quai": Color(0.55, 0.53, 0.5), "chantier": Color(0.75, 0.6, 0.25), "passerelle": Color(0.45, 0.55, 0.62), "estrade": Color(0.55, 0.12, 0.14), "piste": Color(0.62, 0.64, 0.7)}.get(pl["kind"], Color(0.6, 0.6, 0.6))
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
		var cl := U.label(self, "CHANTIER DU PEUPLE", Vector3(c.x, h + 2.6, r.position.y + 0.44), 80, Color(1, 0.85, 0.3), Color(0, 0, 0, 1), false)
		cl.rotation.y = PI; U.fit_label(cl, r.size.x - 1.0, 0.8)
	elif pl["kind"] == "passerelle":
		var glass := U.solid(Color(0.6, 0.8, 0.95, 0.35), 0.3, 0.1, 0.2)
		U.box(self, Vector3(r.size.x, 1.0, 0.08), Vector3(c.x, h + 0.5, r.position.y), glass)
		U.box(self, Vector3(r.size.x, 1.0, 0.08), Vector3(c.x, h + 0.5, r.end.y), glass)
		var pl1 := U.label(self, "PASSERELLE DES CADRES · ACCÈS INTERDIT AU PEUPLE", Vector3(c.x, h * 0.3, r.position.y - 0.16), 60, Color(1, 1, 1), Color(0, 0, 0, 1), false)
		pl1.rotation.y = PI; U.fit_label(pl1, r.size.x - 1.0, h * 0.4)
	elif pl["kind"] == "piste":
		var pl2 := U.label(self, "PISTE NOIRE · RÉSERVÉE AUX ACTIONNAIRES", Vector3(c.x, h * 0.6, r.position.y - 0.16), 64, Color(1, 1, 1), Color(0, 0, 0, 1), false)
		pl2.rotation.y = PI; U.fit_label(pl2, r.size.x - 1.0, h * 0.4)
		U.box(self, Vector3(r.size.x - 0.4, 0.35, r.size.y - 0.4), Vector3(c.x, h + 0.2, c.z), U.pbr("Snow010A", 0.2, Color(1.05, 1.05, 1.1), 0.5))
		for k in 3:
			var fl := Vector3(rng.randf_range(r.position.x + 2, r.end.x - 2), h + 0.35, rng.randf_range(r.position.y + 2, r.end.y - 2))
			U.cyl(self, 0.04, 1.6, fl + Vector3(0, 0.8, 0), U.solid(Color(0.1, 0.1, 0.1) if k % 2 == 0 else Color(0.85, 0.1, 0.1)))
	elif pl["kind"] == "estrade":
		var pl3 := U.label(self, template.get("plateau_labels", {}).get("estrade", "ESTRADE DES ACTIONNAIRES"), Vector3(c.x, h * 0.45, r.position.y - 0.16), 70, Color(1, 0.85, 0.3), Color(0, 0, 0, 1), false)
		pl3.rotation.y = PI; U.fit_label(pl3, r.size.x - 1.0, h * 0.4)
		for k in 2:
			U.place(self, U.CAR + "box.glb", Vector3(r.position.x + 2.0 + k * 1.5, h, r.position.y + 2.0), 0.9, rng.randf() * TAU)
	else:
		var pl4 := U.label(self, "QUAI DE CHARGEMENT", Vector3(c.x, h * 0.82, r.position.y - 0.16), 70, Color(1, 1, 1), Color(0, 0, 0, 1), false)
		pl4.rotation.y = PI; U.fit_label(pl4, r.size.x - 1.0, h * 0.3)
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
	var clutter: Array = template.get("clutter", ["dumpster"])
	for i in int(12 * area_k):
		var p := free_spot(6.0, 3.0)
		match clutter[i % clutter.size()]:
			"palm":
				U.nature(self, ["palm_tree_1", "palm_tree_2", "palm_tree_3", "palm_tree_5"][rng.randi() % 4], p, rng.randf_range(6.0, 9.0), rng.randf() * TAU)
				small_obstacle(p, 0.6)
			"pine":
				U.nature(self, ["pine_tree_1", "pine_tree_2", "pine_tree_3", "pine_tree_5"][rng.randi() % 4], p, rng.randf_range(5.0, 8.0), rng.randf() * TAU)
				small_obstacle(p, 0.8)
			"rack":
				var rk := U.box(self, Vector3(1.2, 2.2, 0.9), p + Vector3(0, 1.1, 0), U.pbr("Metal049A", 0.3, Color(0.35, 0.37, 0.42), 0.8), Vector3(0, rng.randf() * TAU, 0))
				U.box(self, Vector3(0.9, 0.08, 0.05), p + Vector3(0, 1.6, 0.47), U.solid(Color(0.3, 1.0, 0.5), 3.0))
				add_obstacle(rk)
			_:
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
	var n_shr := int(round(9 * area_k * 0.8))
	var n_chest := int(round(16 * area_k * 0.8))
	while shrine_spots.size() < n_shr and tries < 600:
		tries += 1
		var p := free_spot(18.0, 7.0)
		var ok := true
		for q in shrine_spots:
			if p.distance_to(q) < 24.0: ok = false
		if ok: shrine_spots.append(p)
	tries = 0
	while chest_spots.size() < n_chest and tries < 1200:
		tries += 1
		var p := free_spot(8.0, 1.5)
		var ok := true
		for q in chest_spots + shrine_spots:
			if p.distance_to(q) < 14.0: ok = false
		if ok: chest_spots.append(p)
	# a couple of chests on top of plateaus (reward for climbing)
	for pl in plateaus:
		if pl["kind"] == "container": continue
		var r: Rect2 = pl["rect"]
		chest_spots.append(Vector3(r.get_center().x + 1.5, pl["h"], r.get_center().y))
	for i in int(100 * area_k * 0.8):
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
		var l := U.label(self, text, c + Vector3(0, 3.2, 0.06 * f), 52, col, Color(0, 0, 0, 0), false)
		l.outline_size = 0
		l.rotation.y = 0.0 if f > 0.0 else PI
		U.fit_label(l, wdt - 0.25, 0.75)
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
	var walk := U.pbr(template.get("walk_tex", "PavingStones138"), 0.45, Color(0.95, 0.93, 0.9) if template.get("id", "") != "bourse" else Color(0.7, 0.68, 0.75), 0.9)
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
		var ug := U.nature(self, ["grass_large", "grass_small", "flower_2_clump", "flower_4_clump", "plant_1"][rng.randi() % 5], q, rng.randf_range(0.35, 0.7), rng.randf() * TAU)
		for gm in ug.find_children("*", "GeometryInstance3D", true, false): (gm as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# each lot gets its own floor: paving on squares and markets, concrete in yards, marble in the stock exchange
func _lot_floor(r: Rect2, kind: String):
	var bourse: bool = template.get("id", "") == "bourse"
	var ft: String = template.get("floor_tex", "PavingStones138")
	var mat: Material = null
	match kind:
		"plaza", "square", "start", "market":
			mat = U.pbr(ft, 0.5 if ft != "Snow010A" else 0.2, Color(0.88, 0.85, 0.8) if not bourse else Color(0.62, 0.6, 0.7), 0.6)
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
	match template.get("skyline", "city"):
		"sea": _sky_sea(); return
		"mountains": _sky_far("mountains"); return
		"desert": _sky_far("desert"); return
	var night: bool = ambiance == "nuit" or template.get("skyline", "") == "servers"
	var c := bounds.get_center()
	var dark := U.solid(Color(0.32, 0.3, 0.34) if not night else Color(0.08, 0.08, 0.12), 0.0, 0.9)
	var win := U.solid(Color(1.0, 0.8, 0.45) if template.get("skyline", "") != "servers" else Color(0.3, 0.75, 1.0), 3.0)
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
	var ad_ratio: float = {"hypermarche": 0.25, "quartier": 0.5, "bourse": 0.6, "grandsoir": 0.0, "paradis": 0.6, "startup": 0.6}.get(bid, 0.4)
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
		var shops: Array = template.get("shops", ["COOPÉRATIVE N°7"])
		var txt: String = shops[rng.randi() % shops.size()]
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
		var l := U.label(self, txt, sp + face * 0.09, 64, Color(1, 0.95, 0.85), Color(0, 0, 0, 0), false, U.font_main)
		l.rotation.y = rot; l.outline_size = 0; l.pixel_size = 0.009
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		U.fit_label(l, minf(half * 1.7, 8.0) - 0.4, 0.8)
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

# ---------------------------------------------------------------- tall pieces (border ring and inner blocks)
const IND_B := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n", "building-o", "building-p", "building-q", "building-r", "building-s", "building-t"]

# one tall element of about 11 x 11 m at `pos`, its front looking along `face`. `back`: may be pushed back and taller.
func _tall_piece(style: String, pos: Vector3, face: Vector3, back := false) -> Node3D:
	var rot := atan2(face.x, face.z)
	var n: Node3D
	match style:
		"glass", "hotel", "city", "palace":
			var ratio: float = {"glass": 0.75, "hotel": 0.55}.get(style, template.get("sky_ratio", 0.33))
			var sky := rng.randf() < ratio
			var path: String = U.CC + (SKY[rng.randi() % 5] if sky else BNAMES[rng.randi() % 14]) + ".glb"
			n = _bld(path, pos - face * (6.0 if sky and back else 0.0), rot)
			if style == "hotel": U.detailize(n, "Plaster001", 0.5)
			_dress(n, face)
			if style == "palace" and rng.randf() < 0.6: _red_banners(n, face)
			if style == "hotel" and rng.randf() < 0.5:
				var pp := pos + face * 7.5 + Vector3(cos(rot), 0, -sin(rot)) * rng.randf_range(-3.0, 3.0)
				if not back: U.nature(self, ["palm_tree_1", "palm_tree_2", "palm_tree_3", "palm_tree_4"][rng.randi() % 4], pp, rng.randf_range(7.0, 10.0), rng.randf() * TAU)
		"industrial", "hangar":
			if style == "hangar" and rng.randf() < 0.22:
				n = _launch_tower(pos, rng.randf_range(24.0, 34.0))
			else:
				n = U.place(self, U.IND + IND_B[rng.randi() % IND_B.size()] + ".glb", pos, rng.randf_range(11.0, 17.0) * (1.25 if back else 1.0), rot)
				var a := U.world_aabb(n)
				if a.size.x > 12.5 or a.size.z > 12.5:
					n.scale *= 11.5 / maxf(a.size.x, a.size.z)
					var a2 := U.world_aabb(n)
					n.position += Vector3(pos.x - a2.get_center().x, -a2.position.y, pos.z - a2.get_center().z)
				U.detailize(n, ["CorrugatedSteel009", "Concrete034", "Bricks105"][rng.randi() % 3], 0.4)
				_static_box(U.world_aabb(n).get_center(), U.world_aabb(n).size)
				if rng.randf() < 0.3:
					var top := U.world_aabb(n)
					var ch := U.place(self, U.IND + ["chimney-large", "chimney-medium", "chimney-basic"][rng.randi() % 3] + ".glb", Vector3(top.get_center().x, top.end.y - 0.2, top.get_center().z), rng.randf_range(6.0, 10.0), 0.0)
					far_smokes.append({"p": Vector3(top.get_center().x, U.world_aabb(ch).end.y + 0.5, top.get_center().z), "t": 0.0, "s": 5.0})
		"ruins":
			n = _ruin(U.CC + BNAMES[rng.randi() % 14] + ".glb", pos, rot, face, back)
		"servers":
			n = _server_tower(pos, rng.randf_range(15.0, 26.0) * (1.25 if back else 1.0), face)
		"rocks":
			n = _cliff(pos, rng.randf_range(12.0, 20.0) * (1.3 if back else 1.0))
		_:
			n = _bld(U.CC + BNAMES[rng.randi() % 14] + ".glb", pos, rot)
	if n: register_occluder(n)
	return n

# Berlin 1945: a gutted building, its top torn off, blackened, rubble at its foot, sometimes still smoking.
# Phase 1 leaves them standing fairly high; berlin_phase(2) brings them down further.
var _scorched := {}
func _ruin(path: String, pos: Vector3, rot: float, face: Vector3, back: bool) -> Node3D:
	var n := _bld(path, pos, rot)
	var a0 := U.world_aabb(n)
	n.scale.y *= rng.randf_range(0.62, 0.92) * (1.1 if back else 1.0)
	n.position.y -= (U.world_aabb(n).position.y - a0.position.y)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if not (src is StandardMaterial3D): continue
			var key: int = src.get_instance_id()
			if not _scorched.has(key):
				var dm: StandardMaterial3D = src.duplicate()
				dm.albedo_color = dm.albedo_color * Color(0.62, 0.58, 0.55)
				dm.roughness = 1.0
				_scorched[key] = dm
			mi.set_surface_override_material(i, _scorched[key])
	var a := U.world_aabb(n)
	var entry := {"n": n, "top": _ruin_top(a, 1.6), "face": face, "back": back}
	ruins.append(entry)
	if not back: _rubble(a, face, 4)
	if rng.randf() < 0.12:
		far_smokes.append({"p": Vector3(a.get_center().x, a.end.y + 1.0, a.get_center().z), "t": 0.0, "s": 7.0})
	return n

const RUIN_WALL := Color(0.36, 0.3, 0.27)
# jagged broken walls along the roof edges and twisted girders; `rough` = how high the broken bits go
func _ruin_top(a: AABB, rough: float) -> Array:
	var out := []
	var wall := U.solid(RUIN_WALL, 0.0, 1.0)
	var steel := U.solid(Color(0.2, 0.18, 0.17), 0.0, 0.6, 0.6)
	for e in 4:
		var along := Vector3(1, 0, 0) if e < 2 else Vector3(0, 0, 1)
		var off := (Vector3(0, 0, a.size.z * 0.5 - 0.25) if e < 2 else Vector3(a.size.x * 0.5 - 0.25, 0, 0)) * (1.0 if e % 2 == 0 else -1.0)
		var span: float = a.size.x if e < 2 else a.size.z
		var x := -span * 0.5
		while x < span * 0.5 - 0.5:
			var wdt := rng.randf_range(1.0, 2.6)
			var h := rng.randf_range(0.0, rough * 2.0)
			if h > 0.6:
				var b := U.box(self, Vector3(wdt if e < 2 else 0.5, h, 0.5 if e < 2 else wdt), Vector3(a.get_center().x, a.end.y + h * 0.5, a.get_center().z) + off + along * (x + wdt * 0.5), wall)
				b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				out.append(b)
			x += wdt
	for g in rng.randi_range(1, 2 + int(rough)):
		var gb := U.box(self, Vector3(0.25, rng.randf_range(2.0, 2.5 + rough * 1.6), 0.25), Vector3(rng.randf_range(a.position.x + 1, a.end.x - 1), a.end.y + 1.3, rng.randf_range(a.position.z + 1, a.end.z - 1)), steel)
		gb.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		out.append(gb)
	return out

func _rubble(a: AABB, face: Vector3, n: int):
	var wall := U.solid(RUIN_WALL, 0.0, 1.0)
	var base := Vector3(a.get_center().x, 0, a.get_center().z) + face * ((a.size.z if absf(face.z) > 0.5 else a.size.x) * 0.5 + 1.2)
	var side := Vector3(face.z, 0, -face.x)
	for q in n:
		var rp := base + side * rng.randf_range(-4.0, 4.0) + face * rng.randf_range(-0.5, 1.2)
		var sz := rng.randf_range(0.5, 1.3)
		var rb := U.box(self, Vector3(sz * 1.4, sz * 0.6, sz), rp + Vector3(0, sz * 0.25, 0), wall)
		rb.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		rb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# the bunker: a squat concrete blockhouse. Its roof comes off in phase 3 and the duel happens inside.
func _lot_bunker(r: Rect2):
	var side := clampf(minf(r.size.x, r.size.y) - 4.0, 18.0, 30.0)
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	var h := 5.0
	var th := 1.2
	var conc := U.pbr("Concrete034", 0.25, Color(0.55, 0.55, 0.53), 0.9)
	var conc_s := U.solid(Color(0.48, 0.48, 0.46), 0.0, 1.0)
	var inner := side - th * 2.0
	# floor and props inside (hidden under the roof until phase 3)
	U.box(self, Vector3(inner, 0.06, inner), c + Vector3(0, 0.05, 0), U.solid(Color(0.25, 0.24, 0.23), 0.0, 0.9))
	var table := U.box(self, Vector3(5.0, 0.9, 2.6), c + Vector3(0, 0.45, -inner * 0.25), U.solid(Color(0.3, 0.2, 0.12), 0.0, 0.8))
	var mp := U.box(self, Vector3(4.6, 0.03, 2.2), c + Vector3(0, 0.92, -inner * 0.25), U.solid(Color(0.85, 0.8, 0.65), 0.0, 1.0))
	var ml := U.label(self, "BERLIN", c + Vector3(0, 0.95, -inner * 0.25), 96, Color(0.4, 0.2, 0.1), Color(0, 0, 0, 0), false)
	ml.rotation = Vector3(-PI / 2, 0, 0)
	small_obstacle(c + Vector3(0, 0, -inner * 0.25), 2.0)
	_static_box(c + Vector3(0, 0.45, -inner * 0.25), Vector3(5.0, 0.9, 2.6))
	var lights := []
	for k in 4:
		var lp := c + Vector3((k % 2) * 2.0 - 1.0, 0, (k / 2) * 2.0 - 1.0) * inner * 0.3 + Vector3(0, 2.0, 0)
		U.sphere(self, 0.2, lp, U.solid(Color(1.0, 0.2, 0.1), 4.0))
		var ol := OmniLight3D.new(); ol.light_color = Color(1.0, 0.25, 0.15); ol.light_energy = 2.5; ol.omni_range = inner * 0.7
		ol.position = lp; ol.visible = false
		add_child(ol); lights.append(ol)
	# walls (they stay)
	for e in 4:
		var ax := e < 2
		var sgn := 1.0 if e % 2 == 0 else -1.0
		# low visible walls (the camera sees over them), a tall invisible collider (nobody climbs out)
		var vh := 1.0      # cut-away walls: the camera sees the whole room
		var size := Vector3(side, vh, th) if ax else Vector3(th, vh, side)
		var pos := c + (Vector3(0, vh * 0.5, sgn * (side - th) * 0.5) if ax else Vector3(sgn * (side - th) * 0.5, vh * 0.5, 0))
		U.box(self, size, pos, conc)
		_static_box(pos + Vector3(0, 4.0, 0), size + Vector3(0, 8.0, 0))
		obstacles.append(Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z))
		var txt := U.label(self, ["MILLE ANS (ENVIRON)", "ICI COMMANDE UN GÉNIE", "LA VICTOIRE EST PROCHE", "NE PAS DÉRANGER"][e], pos - (Vector3(0, 0, sgn) if ax else Vector3(sgn, 0, 0)) * (th * 0.5 + 0.02) + Vector3(0, -0.05, 0), 64, Color(0.75, 0.72, 0.68), Color(0, 0, 0, 0), false)
		txt.rotation.y = (PI if sgn > 0 else 0.0) if ax else (-PI / 2 if sgn > 0 else PI / 2)
		U.fit_label(txt, side * 0.6, 0.6)
	# roof + sign + an invisible block that keeps everyone out until phase 3
	var roof := Node3D.new(); add_child(roof)
	U.box(roof, Vector3(side + 0.6, 1.8, side + 0.6), c + Vector3(0, 1.9, 0), conc_s)
	U.box(roof, Vector3(side * 0.6, 1.0, side * 0.6), c + Vector3(0, 3.5, 0), conc_s)
	var sign := U.label(roof, "LE BUNKER", c + Vector3(0, 4.02, 0), 200, Color(0.85, 0.1, 0.1), Color(0, 0, 0, 1), false)
	sign.rotation = Vector3(-PI / 2, 0, 0)
	U.fit_label(sign, side * 0.55, 3.0)
	for k in 3:
		U.cyl(roof, 0.35, 1.4, c + Vector3(-side * 0.3 + k * side * 0.3, 3.4, side * 0.38), U.solid(Color(0.3, 0.3, 0.3), 0.0, 0.8))      # air vents
	var rect := Rect2(c.x - inner * 0.5, c.z - inner * 0.5, inner, inner)
	obstacles.append(rect)
	var block := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(inner, h, inner); cs.shape = bs
	block.add_child(cs); block.position = c + Vector3(0, h * 0.5, 0); add_child(block)
	bunker = {"rect": rect, "center": c, "roof": roof, "block": block, "lights": lights, "inner": inner}

# Berlin special level: the map follows the boss fight. 2: the bombing brings the city down. 3: the bunker opens.
func berlin_phase(n: int):
	if n == 2:
		for rr in ruins:
			for t in rr["top"]:
				if is_instance_valid(t): t.queue_free()
			var b: Node3D = rr["n"]
			var a0 := U.world_aabb(b)
			b.scale.y *= rng.randf_range(0.3, 0.5)
			b.position.y -= (U.world_aabb(b).position.y - a0.position.y)
			var a := U.world_aabb(b)
			rr["top"] = _ruin_top(a, 2.4)
			if not rr["back"]: _rubble(a, rr["face"], 3)
			if rng.randf() < 0.3:
				VFX.puff(self, Vector3(a.get_center().x, a.end.y, a.get_center().z), 4.0, false, 6)
			if rng.randf() < 0.35:
				VFX.fire(self, Vector3(a.get_center().x, a.end.y + 0.2, a.get_center().z), rng.randf_range(1.2, 2.0))
		for k in 14:
			var p := free_spot(8.0, 2.0)
			VFX.fire(self, p, rng.randf_range(0.9, 1.6))
		if env:
			var tw := create_tween().set_parallel()
			tw.tween_property(env, "ambient_light_energy", env.ambient_light_energy * 0.7, 3.0)
			tw.tween_property(env, "fog_density", env.fog_density * 1.8 + 0.002, 3.0)
			tw.tween_property(env, "fog_light_color", Color(0.55, 0.35, 0.25), 3.0)
		if sun_light:
			create_tween().tween_property(sun_light, "light_color", Color(1.0, 0.55, 0.35), 3.0)
	elif n == 3 and not bunker.is_empty():
		var roof: Node3D = bunker["roof"]
		if is_instance_valid(roof): roof.queue_free()
		if is_instance_valid(bunker["block"]): (bunker["block"] as Node).queue_free()
		obstacles.erase(bunker["rect"])
		for l in bunker["lights"]: (l as OmniLight3D).visible = true
		if env:
			env.ambient_light_energy *= 0.55
			env.fog_density = maxf(env.fog_density, 0.012)
			env.fog_light_color = Color(0.25, 0.08, 0.06)
		if sun_light: sun_light.light_energy *= 0.35

# a block of tall pieces filling `r`; pieces on the edge face the avenue around it
func _fill_block(r: Rect2, style: String):
	var cx := r.position.x + 5.5
	while cx < r.end.x - 1.0:
		var cz := r.position.y + 5.5
		while cz < r.end.y - 1.0:
			var p := Vector3(minf(cx, r.end.x - 5.0), 0, minf(cz, r.end.y - 5.0))
			var dl := p.x - r.position.x
			var dr := r.end.x - p.x
			var dt := p.z - r.position.y
			var db := r.end.y - p.z
			var m := minf(minf(dl, dr), minf(dt, db))
			var face := Vector3(-1, 0, 0) if m == dl else (Vector3(1, 0, 0) if m == dr else (Vector3(0, 0, -1) if m == dt else Vector3(0, 0, 1)))
			_tall_piece(style, p, face)
			cz += 11.0
		cx += 11.0
	# the block's corners get a street lamp and a bit of greenery so its foot doesn't look cut out
	for k in 4:
		var q := Vector3(r.position.x if k % 2 == 0 else r.end.x, 0, r.position.y if k < 2 else r.end.y)
		q += Vector3(-1.2 if k % 2 == 0 else 1.2, 0, -1.2 if k < 2 else 1.2)
		if inside(q) and not _blocked(q, 0.8):
			U.place(self, U.CR + "light-square.glb", q, 6.5, 0.0)
			small_obstacle(q, 0.5)

func _red_banners(n: Node3D, face: Vector3):
	var a := U.world_aabb(n)
	if a.size.y < 9.0: return
	var c := a.get_center()
	var depth: float = (a.size.z if absf(face.x) < 0.5 else a.size.x) * 0.5
	var lat := Vector3(face.z, 0, -face.x)
	var red := U.solid(Color(0.75, 0.05, 0.07), 0.0, 0.85)
	var rot := atan2(face.x, face.z)
	var sym: Font = load("res://fonts/Symbols.ttf")
	for k in [-1.0, 1.0]:
		var bp: Vector3 = Vector3(c.x, a.position.y + a.size.y * 0.55, c.z) + face * (_wall_plane(n, face, a.position.y + a.size.y * 0.25, a.position.y + a.size.y * 0.85) - Vector3(c.x, 0, c.z).dot(face) + 0.04) + lat * k * minf(a.size.x, a.size.z) * 0.25
		if _wall_plane(n, face, a.position.y + a.size.y * 0.25, a.position.y + a.size.y * 0.85) < -1e8: continue
		U.box(self, Vector3(2.4, a.size.y * 0.6, 0.06), bp, red, Vector3(0, rot, 0))
		var s := Label3D.new(); s.text = "☭"; s.font = sym; s.font_size = 200; s.pixel_size = 0.012
		s.modulate = Color(1, 0.8, 0.25); s.outline_size = 0; s.position = bp + face * 0.04 + Vector3(0, a.size.y * 0.12, 0); s.rotation.y = rot
		s.double_sided = false
		add_child(s)

func _server_tower(pos: Vector3, h: float, face: Vector3) -> Node3D:
	var root := Node3D.new(); add_child(root); root.position = pos
	var wd := rng.randf_range(8.5, 10.0)
	var metal := U.pbr("Metal049A", 0.3, Color(0.42, 0.45, 0.52), 0.8)
	U.box(root, Vector3(wd, h, wd), Vector3(0, h / 2.0, 0), metal)
	U.box(root, Vector3(wd + 0.4, 0.5, wd + 0.4), Vector3(0, 0.25, 0), U.solid(Color(0.12, 0.13, 0.16), 0.0, 0.6))
	var leds := [U.solid(Color(0.2, 0.7, 1.0), 3.0), U.solid(Color(0.3, 1.0, 0.5), 3.0), U.solid(Color(1.0, 0.25, 0.3), 3.0)]
	var rot := atan2(face.x, face.z)
	# rows of rack lights on the front and sides
	for sd in [0.0, PI / 2, -PI / 2]:
		var f := face.rotated(Vector3.UP, sd)
		var y := 2.0
		while y < h - 1.5:
			var strip := U.box(root, Vector3(wd * rng.randf_range(0.4, 0.85), 0.14, 0.06), Vector3(0, y, 0) + f * (wd * 0.5 + 0.03), leds[rng.randi() % 3], Vector3(0, rot + sd, 0))
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			y += rng.randf_range(1.2, 2.4)
	# cooling units and an antenna on the roof
	for k in 2:
		U.box(root, Vector3(2.4, 1.4, 2.4), Vector3(rng.randf_range(-2.5, 2.5), h + 0.7, rng.randf_range(-2.5, 2.5)), U.solid(Color(0.6, 0.62, 0.66), 0.0, 0.5, 0.6))
	U.cyl(root, 0.08, 5.0, Vector3(wd * 0.3, h + 2.5, -wd * 0.3), U.solid(Color(0.2, 0.2, 0.22)))
	U.sphere(root, 0.22, Vector3(wd * 0.3, h + 5.1, -wd * 0.3), U.solid(Color(1, 0.15, 0.15), 5.0))
	U.batch_static(root)
	_static_box(pos + Vector3(0, h / 2.0, 0), Vector3(wd, h, wd))
	return root

func _cliff(pos: Vector3, h: float) -> Node3D:
	var root := Node3D.new(); add_child(root); root.position = pos
	var rk := ["rock_1", "rock_2", "rock_3", "rock_4", "rock_5"]
	var main := U.nature(root, rk[rng.randi() % 5], Vector3.ZERO, h, rng.randf() * TAU)
	var ma := U.world_aabb(main)
	if ma.size.x > 13.0 or ma.size.z > 13.0:
		main.scale *= 12.0 / maxf(ma.size.x, ma.size.z)
		var a2 := U.world_aabb(main)
		main.position += Vector3(pos.x - a2.get_center().x, pos.y - a2.position.y, pos.z - a2.get_center().z)
	for k in 2:
		var off := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		var sm := U.nature(root, rk[rng.randi() % 5], off, h * rng.randf_range(0.3, 0.55), rng.randf() * TAU)
		var sa := U.world_aabb(sm)
		if sa.size.x > 8.0 or sa.size.z > 8.0: sm.scale *= 7.0 / maxf(sa.size.x, sa.size.z)
	# snow cap and a few pines clinging to it
	var top := U.world_aabb(main)
	var cap := U.sphere(root, minf(top.size.x, top.size.z) * 0.32, Vector3(0, top.end.y - pos.y - 0.6, 0), U.pbr("Snow010A", 0.2, Color(1.05, 1.05, 1.1), 0.6), top.size.y * 0.14)
	cap.position.x = top.get_center().x - pos.x; cap.position.z = top.get_center().z - pos.z
	for k in rng.randi_range(0, 1):
		var a := rng.randf() * TAU
		U.nature(root, ["pine_tree_1", "pine_tree_2", "pine_tree_3", "pine_tree_4"][rng.randi() % 4], Vector3(cos(a) * 5.5, 0, sin(a) * 5.5), rng.randf_range(6.0, 10.0), rng.randf() * TAU)
	var ra := U.world_aabb(root)
	_static_box(Vector3(pos.x, ra.size.y / 2.0, pos.z), Vector3(minf(ra.size.x, 11.0), ra.size.y, minf(ra.size.z, 11.0)))
	return root

func _launch_tower(pos: Vector3, h: float) -> Node3D:
	var root := Node3D.new(); add_child(root); root.position = pos
	var red := U.solid(Color(0.78, 0.15, 0.1), 0.0, 0.5, 0.6)
	var white := U.solid(Color(0.9, 0.9, 0.88), 0.0, 0.5, 0.6)
	var s := 4.0
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			U.box(root, Vector3(0.45, h, 0.45), Vector3(cx * s, h / 2.0, cz * s), red)
	var y := 3.0
	var k := 0
	while y < h:
		var m := red if k % 2 == 0 else white
		U.box(root, Vector3(s * 2.0, 0.3, 0.3), Vector3(0, y, -s), m); U.box(root, Vector3(s * 2.0, 0.3, 0.3), Vector3(0, y, s), m)
		U.box(root, Vector3(0.3, 0.3, s * 2.0), Vector3(-s, y, 0), m); U.box(root, Vector3(0.3, 0.3, s * 2.0), Vector3(s, y, 0), m)
		U.box(root, Vector3(0.18, 4.2, 0.18), Vector3(0, y + 1.5, -s), m, Vector3(0, 0, 0.9 if k % 2 == 0 else -0.9))
		y += 3.0; k += 1
	U.box(root, Vector3(s * 2.4, 0.4, s * 2.4), Vector3(0, h, 0), U.solid(Color(0.3, 0.3, 0.32)))
	U.sphere(root, 0.3, Vector3(0, h + 0.5, 0), U.solid(Color(1, 0.2, 0.15), 5.0))
	U.batch_static(root)
	_static_box(pos + Vector3(0, h / 2.0, 0), Vector3(s * 2.0, h, s * 2.0))
	return root

# ---------------------------------------------------------------- see-through when a tall piece hides the player
func register_occluder(n: Node3D):
	var a := U.world_aabb(n)
	if a.size.y < 6.0: return
	var meshes := []
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.is_queued_for_deletion(): continue
		meshes.append([m, (m as MeshInstance3D).material_override, (m as MeshInstance3D).cast_shadow])
	if meshes.is_empty(): return
	# real occlusion culling behind big pieces (what's behind a block isn't drawn)
	var occ := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(maxf(a.size.x - 1.5, 1.0), maxf(a.size.y - 1.5, 1.0), maxf(a.size.z - 1.5, 1.0))
	occ.occluder = bo
	add_child(occ)
	occ.global_position = a.get_center()
	occluders.append({"aabb": a.grow(0.3), "c": a.get_center(), "meshes": meshes, "occ": occ, "ghost": false})

func update_ghosts(cam_pos: Vector3, target: Vector3, d: float):
	_ghost_t -= d
	if _ghost_t > 0.0: return
	_ghost_t = 0.08
	if _ghost_mat == null:
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.albedo_color = Color(0.85, 0.8, 0.75, 0.16)
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_mat.cull_mode = BaseMaterial3D.CULL_BACK
	var t2 := target + Vector3(0, 1.0, 0)
	var reach := cam_pos.distance_to(t2) + 14.0
	for o in occluders:
		var c: Vector3 = o["c"]
		var hide := false
		if Vector2(c.x - target.x, c.z - target.z).length() < reach:
			var ab: AABB = o["aabb"]
			hide = ab.intersects_segment(cam_pos, t2) or ab.intersects_segment(cam_pos, target + Vector3(0, 2.2, 0)) or ab.has_point(cam_pos)
		if hide == o["ghost"]: continue
		o["ghost"] = hide
		(o["occ"] as OccluderInstance3D).visible = not hide
		for pair in o["meshes"]:
			if not is_instance_valid(pair[0]): continue
			var mi: MeshInstance3D = pair[0]
			mi.material_override = _ghost_mat if hide else pair[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hide else pair[2]

# ---------------------------------------------------------------- other horizons
func _sky_sea():
	var c := bounds.get_center()
	var water := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(1400, 1400); water.mesh = pm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.1, 0.5, 0.62); wm.roughness = 0.08; wm.metallic = 0.3
	water.material_override = wm; water.position = Vector3(c.x, -0.15, c.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# a strip of foam where the sand meets the sea, then islands and yachts on the horizon
	var foam := U.solid(Color(0.92, 0.96, 1.0), 0.0, 0.6)
	var hb := Vector2(bounds.size.x + 110.0, bounds.size.y + 110.0) * 0.5
	for e in [[Vector3(c.x, -0.05, c.y - hb.y), Vector3(hb.x * 2.0, 0.1, 1.2)], [Vector3(c.x, -0.05, c.y + hb.y), Vector3(hb.x * 2.0, 0.1, 1.2)],
			[Vector3(c.x - hb.x, -0.05, c.y), Vector3(1.2, 0.1, hb.y * 2.0)], [Vector3(c.x + hb.x, -0.05, c.y), Vector3(1.2, 0.1, hb.y * 2.0)]]:
		U.box(self, e[1], e[0], foam).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rad := maxf(bounds.size.x, bounds.size.y) * 0.5 + 120.0
	var green := U.solid(Color(0.3, 0.5, 0.3), 0.0, 0.9)
	var sand := U.solid(Color(0.9, 0.8, 0.6), 0.0, 0.9)
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var p := Vector3(c.x + cos(a) * (rad + rng.randf_range(0, 80)), 0, c.y + sin(a) * (rad + rng.randf_range(0, 80)))
		var r := rng.randf_range(12.0, 30.0)
		U.sphere(self, r, p, sand, r * 0.25).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.sphere(self, r * 0.75, p + Vector3(0, r * 0.05, 0), green, r * 0.5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i % 3 == 0:
			# offshore tower on the island: the money sleeps there
			var h := rng.randf_range(30.0, 55.0)
			U.box(self, Vector3(8, h, 8), p + Vector3(0, h / 2.0, 0), U.solid(Color(0.85, 0.88, 0.9), 0.2, 0.2, 0.6)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var a := rng.randf() * TAU
		var p := Vector3(c.x + cos(a) * (rad - 30.0), 0, c.y + sin(a) * (rad - 30.0))
		lots2.yacht(p, rng.randf() * TAU, rng.randf_range(1.6, 2.6))

func _sky_far(kind: String):
	var c := bounds.get_center()
	var rad := maxf(bounds.size.x, bounds.size.y) * 0.5 + 95.0
	var rock := U.solid(Color(0.5, 0.5, 0.56) if kind == "mountains" else Color(0.72, 0.42, 0.28), 0.0, 0.95)
	var snow := U.solid(Color(0.95, 0.97, 1.0), 0.0, 0.8)
	var n := 34
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.04, 0.04)
		var r := rad + rng.randf_range(0.0, 70.0)
		var p := Vector3(c.x + cos(a) * r, 0, c.y + sin(a) * r)
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		if kind == "mountains":
			var h := rng.randf_range(70.0, 150.0)
			cm.top_radius = 0.0; cm.bottom_radius = h * rng.randf_range(0.6, 0.9); cm.height = h; cm.radial_segments = 7
			m.mesh = cm; m.material_override = rock; m.position = p + Vector3(0, h / 2.0, 0)
			var cap := MeshInstance3D.new(); var cc := CylinderMesh.new()
			cc.top_radius = 0.0; cc.bottom_radius = cm.bottom_radius * 0.36; cc.height = h * 0.36; cc.radial_segments = 7
			cap.mesh = cc; cap.material_override = snow; cap.position = p + Vector3(0, h - h * 0.18 + 0.3, 0)
			cap.rotation.y = m.rotation.y
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cap)
		else:
			# desert mesas
			var h := rng.randf_range(20.0, 55.0)
			cm.top_radius = rng.randf_range(14.0, 30.0); cm.bottom_radius = cm.top_radius * 1.25; cm.height = h; cm.radial_segments = 8
			m.mesh = cm; m.material_override = rock; m.position = p + Vector3(0, h / 2.0, 0)
		m.rotation.y = rng.randf() * TAU
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)

# ---------------------------------------------------------------- the boundary: a real wall where the map ends
func _perimeter_wall():
	var b := bounds
	var id: String = template.get("id", "")
	var mat: Material
	var cap_col := Color(0.62, 0.1, 0.1)
	match id:
		"datacenter": mat = U.pbr("Metal049A", 0.3, Color(0.45, 0.48, 0.55), 0.8); cap_col = Color(0.2, 0.55, 0.9)
		"ski": mat = U.pbr("Bricks105", 0.3, Color(0.85, 0.82, 0.8), 0.8); cap_col = Color(0.95, 0.97, 1.0)
		"paradis": mat = U.pbr("Plaster001", 0.3, Color(1.05, 1.0, 0.92), 0.6); cap_col = Color(0.1, 0.55, 0.6)
		"fusee": mat = U.pbr("Concrete034", 0.3, Color(0.95, 0.85, 0.75), 0.8); cap_col = Color(0.95, 0.75, 0.1)
		"bourse", "quartier", "startup": mat = U.pbr("Concrete034", 0.3, Color(0.9, 0.9, 0.92), 0.8)
		_: mat = U.pbr("Bricks105", 0.3, Color(1.0, 0.92, 0.88), 0.9)
	var cap := U.solid(cap_col, 0.0, 0.6)
	var pil := U.pbr("Concrete034", 0.4, Color(0.8, 0.78, 0.75), 0.8)
	var h := 4.4
	var sides := [[Vector3(b.get_center().x, 0, b.position.y - 0.5), b.size.x + 2.0, 0.0, Vector3(0, 0, 1)],
		[Vector3(b.get_center().x, 0, b.end.y + 0.5), b.size.x + 2.0, 0.0, Vector3(0, 0, -1)],
		[Vector3(b.position.x - 0.5, 0, b.get_center().y), b.size.y + 2.0, PI / 2, Vector3(1, 0, 0)],
		[Vector3(b.end.x + 0.5, 0, b.get_center().y), b.size.y + 2.0, PI / 2, Vector3(-1, 0, 0)]]
	var slogans: Array = template["slogans"].duplicate()
	var k := 0
	for sd in sides:
		var c: Vector3 = sd[0]
		var length: float = sd[1]
		var rot := Vector3(0, sd[2], 0)
		var inward: Vector3 = sd[3]
		var along := Vector3(cos(sd[2]), 0, -sin(sd[2]))
		U.box(self, Vector3(length, h, 1.0), c + Vector3(0, h / 2.0, 0), mat, rot)
		U.box(self, Vector3(length + 0.4, 0.35, 1.3), c + Vector3(0, h + 0.17, 0), cap, rot)
		# pilasters every 9 m and a poster or a painted slogan in between
		var n := int(length / 9.0)
		for i in n + 1:
			var off := -length / 2.0 + i * length / maxf(n, 1)
			U.box(self, Vector3(0.7, h + 0.5, 1.4), c + along * off + Vector3(0, (h + 0.5) / 2.0, 0), pil, rot)
			if i < n and i % 3 == 1:
				var pp: Vector3 = c + along * (off + length / maxf(n, 1) * 0.5) + inward * 0.52 + Vector3(0, 2.4, 0)
				U.poster(self, U.propaganda_tex(rng.randi()) if rng.randf() < 0.7 else U.ad_tex(rng.randi()), pp, Vector2(2.4, 3.4), atan2(inward.x, inward.z))
			elif i < n and i % 6 == 4 and not slogans.is_empty():
				var lp: Vector3 = c + along * (off + length / maxf(n, 1) * 0.5) + inward * 0.53 + Vector3(0, 2.6, 0)
				var l := U.label(self, slogans[k % slogans.size()], lp, 46, Color(0.95, 0.9, 0.79), Color(0, 0, 0, 0), false, U.font_main)
				l.rotation.y = atan2(inward.x, inward.z); l.outline_size = 0; l.width = 7.6 / l.pixel_size; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				U.fit_label(l, 7.6, 2.6)
				k += 1
