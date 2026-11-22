class_name VFX
# Particle effects built from the Kenney Particle Pack (CC0, res://fx): living fire with embers and smoke,
# fireball explosions with debris and scorch marks, impact sparks, muzzle flashes, smoke and sparkle trails.
# Everything is CPUParticles3D (works on every renderer) and scales with the "effects" option.

static var _mats := {}
static var _ramps := {}
static var _curves := {}
static var live := 0            # one-shot bursts alive right now (keeps big fights readable and cheap)

static func k() -> float:
	return clampf(Meta.opt("fx") / 100.0, 0.25, 1.0)

static func mat(tex: String, additive: bool) -> StandardMaterial3D:
	var key := "%s_%s" % [tex, additive]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://fx/" + tex)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

static func ramp(name: String) -> Gradient:
	if _ramps.has(name): return _ramps[name]
	var g := Gradient.new()
	var pts: Array = []
	match name:
		"fire": pts = [[0.0, Color(1.0, 0.8, 0.35, 0.0)], [0.12, Color(1.0, 0.62, 0.2, 0.85)], [0.45, Color(0.95, 0.3, 0.07, 0.6)], [0.8, Color(0.45, 0.08, 0.03, 0.25)], [1.0, Color(0.15, 0.03, 0.02, 0.0)]]
		"fire_red": pts = [[0.0, Color(1.0, 0.6, 0.25, 0.0)], [0.15, Color(0.95, 0.35, 0.1, 0.8)], [0.5, Color(0.75, 0.12, 0.04, 0.55)], [1.0, Color(0.2, 0.02, 0.01, 0.0)]]
		"fire_mix": pts = [[0.0, Color(1.0, 0.85, 0.35, 0.0)], [0.12, Color(1.0, 0.6, 0.14, 0.95)], [0.5, Color(0.92, 0.25, 0.05, 0.8)], [0.85, Color(0.3, 0.1, 0.06, 0.35)], [1.0, Color(0.18, 0.08, 0.06, 0.0)]]
		"fireball": pts = [[0.0, Color(1.0, 0.92, 0.55, 1.0)], [0.2, Color(1.0, 0.55, 0.12, 1.0)], [0.55, Color(0.55, 0.16, 0.06, 0.85)], [1.0, Color(0.22, 0.2, 0.19, 0.0)]]
		"ember": pts = [[0.0, Color(1.6, 1.2, 0.5, 1.0)], [0.6, Color(1.3, 0.5, 0.12, 0.9)], [1.0, Color(0.7, 0.12, 0.04, 0.0)]]
		"smoke": pts = [[0.0, Color(0.35, 0.32, 0.3, 0.0)], [0.2, Color(0.3, 0.28, 0.27, 0.45)], [1.0, Color(0.45, 0.43, 0.42, 0.0)]]
		"smoke_light": pts = [[0.0, Color(0.9, 0.88, 0.85, 0.0)], [0.2, Color(0.85, 0.83, 0.8, 0.4)], [1.0, Color(0.9, 0.9, 0.9, 0.0)]]
		"steam": pts = [[0.0, Color(1, 1, 1, 0.0)], [0.25, Color(0.95, 0.97, 1.0, 0.35)], [1.0, Color(1, 1, 1, 0.0)]]
		"flash": pts = [[0.0, Color(2.0, 1.8, 1.4, 1.0)], [1.0, Color(1.4, 0.6, 0.2, 0.0)]]
		"fade": pts = [[0.0, Color(1, 1, 1, 1)], [0.7, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0)]]
		"dust": pts = [[0.0, Color(0.75, 0.68, 0.58, 0.0)], [0.15, Color(0.7, 0.64, 0.55, 0.55)], [1.0, Color(0.75, 0.7, 0.62, 0.0)]]
		_: pts = [[0.0, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]]
	g.offsets = PackedFloat32Array(pts.map(func(p): return p[0]))
	g.colors = PackedColorArray(pts.map(func(p): return p[1]))
	_ramps[name] = g
	return g

# a ramp from one colour that fades out (for tinted sparks, sparkles, flashes)
static func tint_ramp(c: Color) -> Gradient:
	var key := "tint_" + c.to_html()
	if _ramps.has(key): return _ramps[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(c.r * 1.8, c.g * 1.8, c.b * 1.8, 1.0), Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.8), Color(c.r, c.g, c.b, 0.0)])
	_ramps[key] = g
	return g

static func curve(name: String) -> Curve:
	if _curves.has(name): return _curves[name]
	var c := Curve.new()
	match name:
		"grow": c.add_point(Vector2(0, 0.3)); c.add_point(Vector2(1, 1.0))
		"puff": c.add_point(Vector2(0, 0.4)); c.add_point(Vector2(0.25, 1.0)); c.add_point(Vector2(1, 0.7))
		"flame": c.add_point(Vector2(0, 0.35)); c.add_point(Vector2(0.3, 1.0)); c.add_point(Vector2(1, 0.15))
		"shrink": c.add_point(Vector2(0, 1.0)); c.add_point(Vector2(1, 0.0))
		_: c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, 1))
	_curves[name] = c
	return c

# generic emitter. cfg keys: n, life, size, rnd_size, add, ramp, gradient, curve, dir, spread, vel, grav, damp,
# shape ("point"|"sphere"|"ring"|"box"), r, box, local, one_shot, explos, pos, angvel, preprocess
static func ps(parent: Node, tex: String, cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	var sz: float = cfg.get("size", 1.0)
	q.size = Vector2(sz, sz)
	q.material = mat(tex, cfg.get("add", true))
	p.mesh = q
	p.amount = maxi(1, int(float(cfg.get("n", 16)) * k()))
	p.lifetime = cfg.get("life", 1.0)
	p.one_shot = cfg.get("one_shot", false)
	p.explosiveness = cfg.get("explos", 0.0)
	p.randomness = 0.5
	p.local_coords = cfg.get("local", false)
	p.preprocess = cfg.get("preprocess", 0.0)
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = cfg.get("spread", 20.0)
	var v: Array = cfg.get("vel", [1.0, 2.0])
	p.initial_velocity_min = v[0]; p.initial_velocity_max = v[1]
	p.gravity = cfg.get("grav", Vector3.ZERO)
	var dm: Array = cfg.get("damp", [0.0, 0.0])
	p.damping_min = dm[0]; p.damping_max = dm[1]
	var ang: float = cfg.get("angle", 360.0)
	p.angle_min = -ang * 0.5 if ang < 360.0 else 0.0; p.angle_max = ang * 0.5 if ang < 360.0 else 360.0
	var av: float = cfg.get("angvel", 60.0)
	p.angular_velocity_min = -av; p.angular_velocity_max = av
	p.scale_amount_min = 1.0 - cfg.get("rnd_size", 0.4); p.scale_amount_max = 1.0
	p.scale_amount_curve = curve(cfg.get("curve", "flame"))
	if cfg.has("gradient"): p.color_ramp = cfg["gradient"]
	else: p.color_ramp = ramp(cfg.get("ramp", "fade"))
	match cfg.get("shape", "point"):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = cfg.get("r", 1.0)
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = cfg.get("r", 1.0)
			p.emission_ring_inner_radius = cfg.get("r_in", 0.0)
			p.emission_ring_height = cfg.get("h", 0.1)
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = cfg.get("box", Vector3.ONE)
	p.position = cfg.get("pos", Vector3.ZERO)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_meta("airborne", true)
	parent.add_child(p)
	p.emitting = true
	return p

# free a one-shot burst once its particles are gone
static func _auto_free(p: CPUParticles3D, extra := 0.2):
	live += 1
	var wr: WeakRef = weakref(p)
	p.get_tree().create_timer(p.lifetime + extra, false).timeout.connect(func():
		live -= 1
		var o = wr.get_ref()
		if o: o.queue_free())

# free a node after a delay without keeping it alive in a closure (it may be gone with its scene)
static func free_later(n: Node, t: float):
	var wr: WeakRef = weakref(n)
	n.get_tree().create_timer(t, false).timeout.connect(func():
		var o = wr.get_ref()
		if o: o.queue_free())

static func _flat_sprite(parent: Node, tex: String, pos: Vector3, size: float, col: Color, life: float, grow := 1.4, additive := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(size, size); q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://fx/" + tex)
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("airborne", true)
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi

# ================================================================ fire
# a burning patch: tongues of flame, rising embers, a column of smoke and a glowing ground.
# Returns the root; call fire_stop(root) to let it die out.
static func fire(parent: Node, pos: Vector3, radius: float, red := false) -> Node3D:
	var root := Node3D.new()
	root.set_meta("airborne", true)
	parent.add_child(root)
	root.global_position = pos
	var r := maxf(radius, 0.4)
	var area_n := clampf(r * r, 0.5, 9.0)
	ps(root, ["fire_01.png", "fire_02.png"][randi() % 2], {"n": 14 + 12 * area_n, "life": 0.8, "size": 1.6 + 0.2 * r, "add": false, "angle": 24.0,
		"ramp": "fire_red" if red else "fire_mix", "curve": "flame", "shape": "ring", "r": r * 0.85, "r_in": 0.0, "h": 0.2,
		"dir": Vector3.UP, "spread": 8.0, "vel": [0.6, 1.6], "grav": Vector3(0, 1.2, 0), "angvel": 12.0, "pos": Vector3(0, 0.6, 0)})
	ps(root, ["flame_02.png", "flame_03.png", "flame_04.png"][randi() % 3], {"n": 8 + 6 * area_n, "life": 0.6, "size": 1.1, "add": true, "angle": 30.0, "angvel": 15.0,
		"ramp": "fire", "curve": "flame", "shape": "ring", "r": r * 0.6, "h": 0.1, "spread": 8.0, "vel": [0.8, 2.0], "grav": Vector3(0, 1.6, 0), "pos": Vector3(0, 0.45, 0)})
	ps(root, ["circle_05.png", "circle_05.png"][randi() % 2], {"n": 4 + 4 * area_n, "life": 1.3, "size": 0.18, "add": true, "ramp": "ember", "curve": "shrink",
		"shape": "ring", "r": r * 0.8, "spread": 25.0, "vel": [2.0, 4.5], "grav": Vector3(0.3, 0.6, 0), "damp": [0.5, 1.0], "rnd_size": 0.6, "pos": Vector3(0, 0.4, 0)})
	ps(root, ["smoke_01.png", "smoke_05.png", "smoke_07.png"][randi() % 3], {"n": 3 + 2 * area_n, "life": 2.2, "size": 1.8 + 0.3 * r, "add": false, "ramp": "smoke", "curve": "grow",
		"shape": "sphere", "r": r * 0.5, "spread": 15.0, "vel": [1.2, 2.0], "grav": Vector3(0.4, 0.5, 0), "angvel": 30.0, "pos": Vector3(0, 1.6, 0)})
	# scorched, glowing ground
	var g := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(r * 2.4, r * 2.4); q.orientation = PlaneMesh.FACE_Y
	g.mesh = q
	var gm := StandardMaterial3D.new(); gm.albedo_texture = load("res://fx/scorch_01.png"); gm.albedo_color = Color(0.08, 0.04, 0.02, 0.85)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; gm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	g.material_override = gm; g.position = Vector3(0, 0.03, 0); g.rotation.y = randf() * TAU; g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(g)
	var glow := MeshInstance3D.new(); var q2 := QuadMesh.new(); q2.size = Vector2(r * 2.2, r * 2.2); q2.orientation = PlaneMesh.FACE_Y
	glow.mesh = q2
	var glm := StandardMaterial3D.new(); glm.albedo_texture = load("res://fx/circle_05.png"); glm.albedo_color = Color(1.4, 0.5, 0.12, 0.55)
	glm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; glm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glow.material_override = glm; glow.position = Vector3(0, 0.05, 0); glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.name = "glow"
	root.add_child(glow)
	return root

static func fire_stop(root: Node3D):
	if not is_instance_valid(root): return
	for c in root.get_children():
		if c is CPUParticles3D: (c as CPUParticles3D).emitting = false
	var tw := root.create_tween()
	for c in root.get_children():
		if c is MeshInstance3D:
			tw.parallel().tween_property((c as MeshInstance3D).material_override, "albedo_color:a", 0.0, 1.6)
	tw.tween_interval(0.8)
	tw.tween_callback(root.queue_free)

# the slide's burning trail: one emitter that follows the player and leaves flames behind in the world
static func trail_emitter(parent: Node) -> Node3D:
	var root := Node3D.new()
	root.set_meta("airborne", true)
	parent.add_child(root)
	ps(root, "fire_01.png", {"n": 80, "life": 1.1, "size": 1.3, "add": false, "ramp": "fire_mix", "curve": "flame", "shape": "sphere", "r": 0.35, "angle": 26.0,
		"spread": 10.0, "vel": [0.4, 1.2], "grav": Vector3(0, 1.4, 0), "angvel": 15.0, "pos": Vector3(0, 0.55, 0)}).name = "flames"
	ps(root, "flame_03.png", {"n": 50, "life": 1.7, "size": 0.9, "ramp": "fire_red", "curve": "flame", "shape": "sphere", "r": 0.4, "angle": 30.0, "angvel": 15.0,
		"spread": 10.0, "vel": [0.3, 0.9], "grav": Vector3(0, 0.8, 0), "pos": Vector3(0, 0.15, 0)}).name = "low"
	ps(root, "circle_05.png", {"n": 24, "life": 1.0, "size": 0.14, "ramp": "ember", "curve": "shrink", "shape": "sphere", "r": 0.3,
		"spread": 40.0, "vel": [1.5, 3.5], "grav": Vector3(0, -1.0, 0), "pos": Vector3(0, 0.4, 0)}).name = "embers"
	ps(root, "smoke_05.png", {"n": 12, "life": 2.0, "size": 1.4, "add": false, "ramp": "smoke", "curve": "grow", "shape": "sphere", "r": 0.3,
		"spread": 15.0, "vel": [0.8, 1.4], "grav": Vector3(0, 0.4, 0), "pos": Vector3(0, 1.0, 0)}).name = "smoke"
	trail_on(root, false)
	return root

static func trail_on(root: Node3D, on: bool):
	if not is_instance_valid(root): return
	for c in root.get_children():
		if c is CPUParticles3D: (c as CPUParticles3D).emitting = on

# ================================================================ explosions and impacts
static func explosion(parent: Node, pos: Vector3, radius: float, col := Color(1, 0.55, 0.15), smoke := true):
	var r := clampf(radius, 0.6, 6.0)
	var root := Node3D.new(); root.set_meta("airborne", true); parent.add_child(root); root.global_position = pos
	var heavy := live > 40      # many explosions at once: lighter bursts
	# white-hot flash
	var fl := ps(root, ["light_01.png", "light_02.png"][randi() % 2], {"n": 1, "life": 0.22, "size": r * 3.2, "one_shot": true, "explos": 1.0,
		"gradient": tint_ramp(col.lightened(0.4)), "curve": "grow", "vel": [0.0, 0.0], "angvel": 0.0, "pos": Vector3(0, 0.8, 0)})
	fl.amount = 1
	_auto_free(fl)
	# fireball
	var fb := ps(root, ["fire_01.png", "fire_02.png"][randi() % 2], {"n": (14 if not heavy else 7) + 4 * r, "life": 0.6, "size": 1.2 + 0.4 * r,
		"one_shot": true, "explos": 0.95, "add": false, "ramp": "fireball", "curve": "puff", "shape": "sphere", "r": r * 0.25, "spread": 180.0,
		"vel": [r * 2.2, r * 4.0], "damp": [r * 5.0, r * 7.0], "grav": Vector3(0, 2.5, 0), "angvel": 150.0, "pos": Vector3(0, 0.6, 0)})
	_auto_free(fb)
	# sparks and debris
	var sp := ps(root, ["circle_05.png", "spark_06.png"][randi() % 2], {"n": (12 if not heavy else 5) + 3 * r, "life": 0.7, "size": 0.25, "one_shot": true, "explos": 1.0,
		"gradient": tint_ramp(Color(1.0, 0.75, 0.35)), "curve": "shrink", "spread": 70.0, "vel": [r * 3.0, r * 6.0], "grav": Vector3(0, -14, 0), "pos": Vector3(0, 0.5, 0)})
	_auto_free(sp)
	if smoke and not heavy:
		var sm := ps(root, ["smoke_02.png", "smoke_07.png", "smoke_08.png"][randi() % 3], {"n": 5 + 2 * r, "life": 1.6, "size": 1.4 + 0.4 * r, "one_shot": true, "explos": 0.8,
			"add": false, "ramp": "smoke", "curve": "grow", "shape": "sphere", "r": r * 0.4, "spread": 90.0, "vel": [0.8, 2.0], "damp": [1.0, 2.0],
			"grav": Vector3(0, 1.2, 0), "angvel": 40.0, "pos": Vector3(0, 1.0, 0)})
		_auto_free(sm)
		var dirt := ps(root, ["dirt_01.png", "dirt_02.png", "dirt_03.png"][randi() % 3], {"n": 4 + r, "life": 0.9, "size": 0.9, "one_shot": true, "explos": 1.0,
			"add": false, "ramp": "dust", "curve": "grow", "spread": 60.0, "vel": [r * 1.5, r * 3.0], "grav": Vector3(0, -9, 0), "pos": Vector3(0, 0.2, 0)})
		_auto_free(dirt)
	# shockwave and scorch on the ground
	_flat_sprite(parent, "circle_02.png", Vector3(pos.x, 0.07, pos.z), r * 1.2, Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 0.7), 0.3, r * 1.8)
	if r >= 1.2 and not heavy:
		var sc := _flat_sprite(parent, ["scorch_01.png", "scorch_02.png", "scorch_03.png"][randi() % 3], Vector3(pos.x, 0.04, pos.z), r * 2.0, Color(0.05, 0.03, 0.02, 0.75), 4.0, 1.0, false)
		sc.scale = Vector3.ONE
	free_later(root, 2.0)

# small hit: sparks spraying away from the attack
static func impact(parent: Node, pos: Vector3, col := Color(1, 0.8, 0.35), n := 7, dir := Vector3.UP):
	if live > 60: return
	var p := ps(parent, ["spark_02.png", "spark_04.png", "spark_06.png"][randi() % 3], {"n": n, "life": 0.35, "size": 0.32, "one_shot": true, "explos": 1.0,
		"gradient": tint_ramp(col), "curve": "shrink", "dir": dir, "spread": 65.0, "vel": [4.0, 8.0], "grav": Vector3(0, -12, 0), "angvel": 0.0})
	p.global_position = pos
	_auto_free(p)
	var f := ps(parent, "star_06.png", {"n": 1, "life": 0.14, "size": 0.9, "one_shot": true, "explos": 1.0, "gradient": tint_ramp(col), "curve": "shrink", "vel": [0.0, 0.0], "angvel": 0.0})
	f.amount = 1
	f.global_position = pos
	_auto_free(f)

static func muzzle(parent: Node, pos: Vector3, col := Color(1, 0.8, 0.4)):
	var p := ps(parent, ["muzzle_01.png", "muzzle_03.png", "muzzle_05.png"][randi() % 3], {"n": 1, "life": 0.07, "size": 0.9, "one_shot": true, "explos": 1.0,
		"gradient": tint_ramp(col), "curve": "grow", "vel": [0.0, 0.0], "angvel": 0.0})
	p.amount = 1
	p.global_position = pos
	_auto_free(p, 0.05)

static func puff(parent: Node, pos: Vector3, size := 1.0, light := true, n := 5):
	var p := ps(parent, ["smoke_01.png", "smoke_03.png", "smoke_05.png"][randi() % 3], {"n": n, "life": 0.7, "size": size, "one_shot": true, "explos": 0.9, "add": false,
		"ramp": "smoke_light" if light else "smoke", "curve": "grow", "shape": "sphere", "r": size * 0.3, "spread": 180.0, "vel": [0.6, 1.4], "damp": [1.5, 2.5], "angvel": 40.0})
	p.global_position = pos
	_auto_free(p)

# ground slam: a ring of dust and debris rolling out, cracked ground
static func slam(parent: Node, pos: Vector3, radius: float, col: Color):
	var r := clampf(radius, 1.0, 8.0)
	var root := Node3D.new(); root.set_meta("airborne", true); parent.add_child(root); root.global_position = Vector3(pos.x, 0.0, pos.z)
	var d := ps(root, ["smoke_01.png", "smoke_05.png"][randi() % 2], {"n": 10 + 3 * r, "life": 0.8, "size": 1.3, "one_shot": true, "explos": 1.0, "add": false,
		"ramp": "dust", "curve": "grow", "shape": "ring", "r": 0.6, "h": 0.1, "dir": Vector3(1, 0.15, 0), "spread": 180.0,
		"vel": [r * 3.0, r * 4.0], "damp": [r * 3.0, r * 4.5], "angvel": 40.0, "pos": Vector3(0, 0.4, 0)})
	d.flatness = 0.85
	_auto_free(d)
	var rk := ps(root, ["dirt_01.png", "dirt_03.png"][randi() % 2], {"n": 6 + r, "life": 0.7, "size": 0.45, "one_shot": true, "explos": 1.0, "add": false,
		"ramp": "dust", "curve": "shrink", "spread": 50.0, "vel": [4.0, 8.0], "grav": Vector3(0, -16, 0), "pos": Vector3(0, 0.3, 0)})
	_auto_free(rk)
	_flat_sprite(parent, "circle_04.png", Vector3(pos.x, 0.07, pos.z), r * 0.6, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.9), 0.32, r * 3.4)
	var cr := _flat_sprite(parent, "scratch_01.png" if ResourceLoader.exists("res://fx/scratch_01.png") else "scorch_03.png", Vector3(pos.x, 0.04, pos.z), r * 1.4, Color(0.08, 0.06, 0.05, 0.7), 2.5, 1.0, false)
	cr.scale = Vector3.ONE
	free_later(root, 1.2)

# trails attached to a moving projectile (world-space particles, so they stay behind it)
static func smoke_trail(node: Node3D, size := 0.6, dark := false) -> CPUParticles3D:
	return ps(node, ["smoke_01.png", "smoke_05.png", "smoke_07.png"][randi() % 3], {"n": 18, "life": 0.9, "size": size, "add": false,
		"ramp": "smoke" if dark else "smoke_light", "curve": "grow", "spread": 180.0, "vel": [0.1, 0.4], "angvel": 40.0})

static func fire_trail(node: Node3D, size := 0.5) -> CPUParticles3D:
	return ps(node, ["fire_01.png", "fire_02.png"][randi() % 2], {"n": 22, "life": 0.35, "size": size, "add": false, "ramp": "fire_mix", "curve": "flame",
		"spread": 180.0, "vel": [0.1, 0.5], "angvel": 120.0})

static func sparkle_trail(node: Node3D, col: Color, size := 0.4, tex := "star_07.png") -> CPUParticles3D:
	return ps(node, tex, {"n": 16, "life": 0.5, "size": size, "gradient": tint_ramp(col), "curve": "shrink", "spread": 180.0, "vel": [0.2, 0.8], "angvel": 90.0})

# continuous steam around the player (samovar)
static func steam_ring(parent: Node) -> CPUParticles3D:
	return ps(parent, ["smoke_01.png", "smoke_05.png"][randi() % 2], {"n": 26, "life": 1.4, "size": 1.0, "add": false, "ramp": "steam", "curve": "grow",
		"shape": "ring", "r": 1.0, "r_in": 0.8, "h": 0.1, "spread": 15.0, "vel": [0.4, 1.0], "grav": Vector3(0, 0.6, 0), "angvel": 30.0, "local": true, "pos": Vector3(0, 0.3, 0)})

# sound waves (haut-parleur, balalaïka): flat rings travelling and widening
static func wave(parent: Node, pos: Vector3, dir: Vector3, dist: float, col: Color):
	for i in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2(1.6, 1.6)
		mi.mesh = q
		var m := StandardMaterial3D.new(); m.albedo_texture = load("res://fx/circle_02.png"); m.albedo_color = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.set_meta("airborne", true)
		parent.add_child(mi)
		var from := pos + Vector3(0, 1.0, 0)
		mi.global_position = from
		if dir.length() > 0.1: mi.look_at(from + dir, Vector3.UP)
		mi.scale = Vector3.ONE * 0.4
		var tw := mi.create_tween().set_parallel()
		tw.tween_interval(i * 0.07)
		tw.chain().tween_property(mi, "global_position", from + dir * dist, 0.35)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * (1.0 + dist * 0.45), 0.35)
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
