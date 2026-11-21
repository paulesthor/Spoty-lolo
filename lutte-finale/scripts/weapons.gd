extends Node3D
# Auto-firing weapons: Marteau, Kalach, Faucille, Molotov.

var game
var owned := {}      # id -> level
var timers := {}
var projectiles: Array = []
var fires: Array = []
var slam_cd := 0.0

func setup(g):
	game = g

func add_weapon(id: String):
	owned[id] = owned.get(id, 0) + 1
	if not timers.has(id): timers[id] = 0.3

func stats(id: String) -> Dictionary:
	var s := Data.weapon_stats(id, owned[id])
	s["dmg"] = s["dmg"] * (1.0 + 0.15 * game.decret_lv("productivite"))
	s["cd"] = s["cd"] * pow(0.92, game.decret_lv("cadence"))
	if s.has("area"): s["area"] = s["area"] * (1.0 + 0.15 * game.decret_lv("expansion"))
	if s.has("count") and id != "molotov": s["count"] = s["count"] + game.decret_lv("collectivisation")
	if id == "molotov" and game.decret_lv("collectivisation") >= 2: s["count"] = s["count"] + 1
	return s

func _process(d: float):
	if game == null or game.state != "play": return
	d = minf(d, 0.05)
	slam_cd = maxf(0.0, slam_cd - d)
	for id in owned:
		timers[id] -= d
		if timers[id] <= 0.0:
			var s := stats(id)
			if _fire(id, s):
				timers[id] = s["cd"]
			else:
				timers[id] = 0.2
	_update_projectiles(d)
	_update_fires(d)

func _fire(id: String, s: Dictionary) -> bool:
	var pp: Vector3 = game.player.global_position
	match id:
		"marteau":
			_shockwave(pp, s["area"], s["dmg"], Color(1.0, 0.3, 0.15))
			return true
		"kalach":
			var targets := []
			for i in s["count"]:
				var t = game.enemies.nearest(pp, 26.0, targets)
				if t == null:
					if targets.is_empty(): return false
					t = targets[i % targets.size()]
				targets.append(t)
			for t in targets:
				var from := pp + Vector3(0, 1.0, 0)
				var to: Vector3 = t.node.position + Vector3(0, 0.9, 0)
				var dir := (to - from).normalized()
				dir = dir.rotated(Vector3.UP, randf_range(-0.04, 0.04))
				_bullet(from, dir, s)
			return true
		"faucille":
			var base_dir: Vector3 = game.player.facing
			var t = game.enemies.nearest(pp, 14.0)
			if t != null:
				base_dir = (t.node.position - pp); base_dir.y = 0; base_dir = base_dir.normalized()
			var n: int = s["count"]
			for i in n:
				var ang := (i - (n - 1) / 2.0) * 0.6
				_sickle(base_dir.rotated(Vector3.UP, ang), s)
			return true
		"molotov":
			for i in s["count"]:
				var tgt := pp + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				var t = game.enemies.nearest(pp + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 16.0)
				if t != null: tgt = t.node.position
				_molotov(pp + Vector3(0, 1.5, 0), Vector3(tgt.x, 0, tgt.z), s)
			return true
	return false

# ---------------------------------------------------------------- marteau
func on_landed(fall_speed: float):
	if not owned.has("marteau") or fall_speed < 7.0 or slam_cd > 0.0: return
	slam_cd = 0.6
	var s := stats("marteau")
	_shockwave(game.player.global_position, s["area"] * 1.15, s["dmg"] * 2.0, Color(1.0, 0.75, 0.2))

func _shockwave(center: Vector3, area: float, dmg: float, col: Color):
	for e in game.enemies.in_radius(center, area):
		game.enemies.damage(e, dmg, center, 14.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.9; tm.outer_radius = 1.0
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.9)
	m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(center.x, 0.08, center.z)
	ring.scale = Vector3(0.3, 0.06, 0.3)
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(area, 0.06, area), 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(ring.queue_free)
	var flash := U.sprite(self, "circle_05.png", Vector3(center.x, 0.06, center.z), area * 2.0, Color(col.r, col.g, col.b, 0.35), 2.0, false, Vector3(-PI / 2, 0, 0))
	var tw2 := create_tween()
	tw2.tween_property(flash, "scale", Vector3.ONE * 1.2, 0.25)
	tw2.tween_callback(flash.queue_free)
	game.shake(0.12 if dmg < 100.0 else 0.25)

# ---------------------------------------------------------------- kalach
func _bullet(from: Vector3, dir: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var b := U.sphere(n, 0.07, Vector3.ZERO, U.solid(Color(1, 0.8, 0.3), 6.0))
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tr := U.sprite(n, "trace_01.png", Vector3(0, 0, 0.6), 1.2, Color(1, 0.75, 0.3), 3.0, false, Vector3(PI / 2, 0, 0))
	tr.scale = Vector3(0.3, 1.8, 1)
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 0.05:
		n.look_at(from + flat, Vector3.UP)
	projectiles.append({"t": "bullet", "n": n, "v": dir * float(s["speed"]), "life": 1.2, "dmg": s["dmg"], "pierce": s["pierce"], "hits": []})

# ---------------------------------------------------------------- faucille
func _sickle(dir: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	var blade := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.42; tm.outer_radius = 0.55; tm.rings = 24
	blade.mesh = tm; blade.scale = Vector3(1, 0.25, 1)
	blade.material_override = U.solid(Color(0.85, 0.86, 0.9), 0.6, 0.2, 1.0)
	n.add_child(blade)
	var handle := U.box(n, Vector3(0.1, 0.1, 0.5), Vector3(0.5, 0, 0.3), U.solid(Color(0.75, 0.08, 0.1), 0.0, 0.6))
	var trail := U.sprite(n, "twirl_01.png", Vector3.ZERO, 1.8, Color(1, 0.25, 0.2, 0.7), 2.0, false, Vector3(-PI / 2, 0, 0))
	n.global_position = game.player.global_position + Vector3(0, 1.1, 0)
	projectiles.append({"t": "sickle", "n": n, "dir": dir, "age": 0.0, "dur": 1.5, "range": s["range"] * (1.0 + 0.1 * game.decret_lv("expansion")), "dmg": s["dmg"]})

# ---------------------------------------------------------------- molotov
func _molotov(from: Vector3, to: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	U.cyl(n, 0.08, 0.3, Vector3.ZERO, U.solid(Color(0.25, 0.55, 0.3, 0.9), 0.0, 0.1))
	U.sprite(n, "flame_02.png", Vector3(0, 0.25, 0), 0.4, Color(1, 0.6, 0.2), 3.0)
	projectiles.append({"t": "molotov", "n": n, "from": from, "to": to, "age": 0.0, "dur": 0.6, "s": s})

func _spawn_fire(p: Vector3, s: Dictionary):
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	var area: float = s["area"]
	U.sprite(root, "scorch_02.png", Vector3(0, 0.03, 0), area * 2.2, Color(0.15, 0.08, 0.04, 0.8), 1.0, false, Vector3(-PI / 2, 0, 0))
	var flames := []
	var count := int(6 + area * 3)
	for i in count:
		var o := Vector3(randf_range(-area, area) * 0.8, 0, randf_range(-area, area) * 0.8)
		if o.length() > area: o = o.normalized() * area * 0.9
		var h := randf_range(0.8, 1.8)
		var f := U.sprite(root, "flame_0%d.png" % (1 + i % 4), o + Vector3(0, h * 0.45, 0), h, Color(1, 0.5, 0.15) if i % 3 else Color(1, 0.2, 0.1), 3.0)
		flames.append(f)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.55, 0.2); l.light_energy = 3.0; l.omni_range = area * 2.5; l.position = Vector3(0, 1.0, 0)
	root.add_child(l)
	fires.append({"n": root, "life": s["duration"], "area": area, "dmg": s["dmg"], "tick": 0.0, "flames": flames})

func _update_fires(d: float):
	for f in fires.duplicate():
		f["life"] -= d
		f["tick"] -= d
		var t := Time.get_ticks_msec() / 1000.0
		for i in f["flames"].size():
			var fl: Node3D = f["flames"][i]
			fl.scale = Vector3.ONE * (0.85 + 0.2 * sin(t * 9.0 + i))
		if f["tick"] <= 0.0:
			f["tick"] = 0.3
			for e in game.enemies.in_radius(f["n"].global_position, f["area"]):
				game.enemies.damage(e, f["dmg"], Vector3.INF, 0.0, "", false)
		if f["life"] <= 0.0:
			fires.erase(f)
			var n: Node3D = f["n"]
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector3(1, 0.01, 1), 0.3)
			tw.tween_callback(n.queue_free)

func _update_projectiles(d: float):
	for p in projectiles.duplicate():
		var n: Node3D = p["n"]
		match p["t"]:
			"bullet":
				n.global_position += p["v"] * d
				p["life"] -= d
				var hit_end := false
				for e in game.enemies.in_radius(n.global_position, 0.35):
					if p["hits"].has(e): continue
					p["hits"].append(e)
					game.enemies.damage(e, p["dmg"], n.global_position - p["v"].normalized(), 3.0)
					game.spark(n.global_position)
					if p["hits"].size() > p["pierce"]:
						hit_end = true
						break
				if hit_end or p["life"] <= 0.0:
					projectiles.erase(p); n.queue_free()
			"sickle":
				p["age"] += d
				var k: float = p["age"] / p["dur"]
				var origin: Vector3 = game.player.global_position + Vector3(0, 1.1, 0)
				var side := Vector3(-p["dir"].z, 0, p["dir"].x)
				var pos: Vector3 = origin + p["dir"] * sin(k * PI) * p["range"] + side * sin(k * TAU) * 1.6
				n.global_position = pos
				n.rotation.y += d * 18.0
				for e in game.enemies.in_radius(pos, 0.8):
					game.enemies.damage(e, p["dmg"], pos, 5.0, "sickle%d" % n.get_instance_id())
					game.enemies.set_hit_cd(e, "sickle%d" % n.get_instance_id(), 0.35)
				if k >= 1.0:
					projectiles.erase(p); n.queue_free()
			"molotov":
				p["age"] += d
				var k: float = clampf(p["age"] / p["dur"], 0.0, 1.0)
				var pos: Vector3 = p["from"].lerp(p["to"], k)
				pos.y = lerpf(p["from"].y, 0.2, k) + sin(k * PI) * 3.0
				n.global_position = pos
				n.rotation.x += d * 12.0
				if k >= 1.0:
					projectiles.erase(p); n.queue_free()
					_spawn_fire(p["to"], p["s"])
					game.shake(0.06)
