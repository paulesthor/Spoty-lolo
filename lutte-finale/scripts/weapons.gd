extends Node3D
# Auto-firing weapons. Each owned weapon: {lv, mods, evo}. Stats = base x weapon mods x global décrets.

var game
var owned := {}      # id -> {"lv": int, "mods": Dictionary, "evo": bool}
var timers := {}
var projectiles: Array = []
var fires: Array = []
var trails: Array = []
var sats: Array = []
var aura_fx: Node3D
var slam_cd := 0.0
var laser_t := 0.0
var orbit_a := 0.0
var bears: Array = []       # Node3D
var walls: Array = []       # {n, c, along, half, life, tick, s}
var cages: Array = []       # {n, p, r, life, tick, s}
var spiral_a := 0.0
var star_t := 0.0

func setup(g):
	game = g

func level(id: String) -> int:
	return owned[id]["lv"] if owned.has(id) else 0

func add_weapon(id: String):
	if owned.has(id): return
	owned[id] = {"lv": 1, "mods": {}, "evo": false, "fusion": ""}
	timers[id] = 0.3
	if id == "samovar": _make_aura()

func upgrade(id: String, mods: Dictionary):
	var w: Dictionary = owned[id]
	w["lv"] += 1
	for k in mods:
		w["mods"][k] = w["mods"].get(k, 0.0) + mods[k]

# weapons that occupy a slot (a fused pair counts once)
func slot_ids() -> Array:
	var out := []
	for id in owned:
		var f: String = owned[id].get("fusion", "")
		if f != "" and Data.FUSIONS[f]["b"] == id: continue
		out.append(id)
	return out

func can_fuse(f: String) -> bool:
	var a: String = Data.FUSIONS[f]["a"]
	var b: String = Data.FUSIONS[f]["b"]
	if not owned.has(a) or not owned.has(b): return false
	if owned[a].get("fusion", "") != "": return false
	return owned[a]["lv"] >= Data.EVO_MIN_LV and owned[b]["lv"] >= Data.EVO_MIN_LV

func fuse(f: String):
	owned[Data.FUSIONS[f]["a"]]["fusion"] = f
	owned[Data.FUSIONS[f]["b"]]["fusion"] = f

func display_name(id: String) -> String:
	var w: Dictionary = owned[id]
	if w.get("fusion", "") != "": return Data.FUSIONS[w["fusion"]]["name"]
	return Data.WEAPONS[id]["evo_name"] if w["evo"] else Data.WEAPONS[id]["name"]

func evolve(id: String):
	owned[id]["evo"] = true

func can_evolve(id: String) -> bool:
	if not owned.has(id) or owned[id]["evo"]: return false
	return owned[id]["lv"] >= Data.EVO_MIN_LV and game.decret_lv(Data.WEAPONS[id]["evo"]) > 0

func stats(id: String) -> Dictionary:
	var base: Dictionary = Data.WEAPONS[id]
	var w: Dictionary = owned[id]
	var m: Dictionary = w["mods"]
	var evo: bool = w["evo"]
	var s := {}
	s["dmg"] = base["dmg"] * (1.0 + m.get("dmg", 0.0)) * (1.0 + game.dv("productivite") / 100.0)
	s["cd"] = base["cd"] / ((1.0 + m.get("cd", 0.0)) * (1.0 + game.dv("cadence") / 100.0))
	s["area"] = base.get("area", 0.0) * minf(1.0 + m.get("area", 0.0), 1.8) * minf(1.0 + game.dv("expansion") / 100.0, 1.6)
	s["range"] = base.get("range", 0.0) * (1.0 + m.get("range", 0.0))
	s["duration"] = base.get("duration", 0.0) * (1.0 + m.get("duration", 0.0)) * (1.0 + game.dv("duree") / 100.0)
	var extra := int(game.dv("collectivisation")) if id in ["kalach", "faucille", "matriochka", "molotov", "tracteur", "vodka", "t34", "katioucha", "balalaika", "tracts", "cigare"] else 0
	if id == "ours": extra = int(game.dv("collectivisation")) / 2 + (1 if game.char_id == "mikhail" else 0) + (3 if game.char_id == "mikhail" and game.ult_t > 0.0 else 0)
	s["count"] = int(base.get("count", 1)) + int(m.get("count", 0.0)) + extra
	s["pierce"] = int(base.get("pierce", 0)) + int(m.get("pierce", 0.0)) + int(game.dv("perforation"))
	s["split"] = int(base.get("split", 0)) + int(m.get("split", 0.0))
	s["depth"] = int(base.get("depth", 0))
	s["chain"] = int(base.get("chain", 0)) + int(m.get("chain", 0.0))
	s["speed"] = base.get("speed", 0.0)
	s["crit"] = 0.05 + game.dv("critique") / 100.0
	s["id"] = id
	s["mastery"] = Meta.weapon_mastery(id)
	s["dmg"] *= 1.0 + 0.04 * s["mastery"]
	s["module"] = Meta.data["modules"].get(id, "")
	match s["module"]:
		"kalach_eventail": s["count"] += 2; s["dmg"] *= 0.7
		"kalach_sniper": s["count"] = 1 + int(m.get("count", 0.0)) / 2; s["dmg"] *= 3.5; s["pierce"] += 5; s["cd"] *= 2.0
		"kalach_incendiaire": s["dmg"] *= 1.15
		"marteau_seisme": s["area"] *= 1.45; s["cd"] *= 1.3
		"faucille_lourde": s["dmg"] *= 1.7; s["count"] = maxi(1, s["count"] - 1)
		"faucille_rafale": s["count"] += 2; s["range"] *= 0.7
		"molotov_napalm": s["duration"] *= 2.0; s["dmg"] *= 0.8
		"molotov_grappe": s["count"] += 2; s["area"] *= 0.65
		"matriochka_essaim": s["split"] += 2; s["dmg"] *= 0.75
		"matriochka_mere": s["depth"] += 1; s["cd"] *= 1.4
		"spoutnik_large": s["area"] *= 1.6
		"spoutnik_tueur": s["dmg"] *= 1.7; s["count"] = maxi(1, s["count"] - 1)
		"samovar_glace": s["area"] *= 1.2; s["dmg"] *= 0.8
		"samovar_bouilloire": s["dmg"] *= 1.7; s["area"] *= 0.75
		"hautparleur_megaphone": s["area"] *= 1.5
		"hautparleur_larsen": s["cd"] *= 0.65; s["dmg"] *= 0.75
	if evo:
		match id:
			"marteau": s["area"] *= 1.15; s["dmg"] *= 1.35
			"kalach": s["count"] += 2; s["pierce"] += 3; s["cd"] *= 0.6
			"faucille": s["count"] += 3; s["range"] *= 1.3
			"molotov": s["area"] *= 1.5; s["duration"] *= 1.6; s["dmg"] *= 1.3
			"matriochka": s["depth"] += 1; s["split"] += 1; s["dmg"] *= 1.2
			"spoutnik": s["count"] += 3; s["dmg"] *= 1.4
			"samovar": s["area"] *= 1.4; s["dmg"] *= 1.3
			"hautparleur": s["cd"] *= 0.55
			"tracteur": s["area"] *= 2.0; s["dmg"] *= 1.5; s["count"] += 1
			"ours": s["count"] += 1; s["area"] *= 1.3
			"vodka": s["chain"] += 4
			"rideau": s["dmg"] *= 1.3
			"t34": s["count"] += 2; s["area"] *= 1.3
			"katioucha": s["count"] *= 2
			"balalaika": s["count"] += 3; s["pierce"] += 2
			"goulag": s["dmg"] *= 1.2
			"etoile": s["dmg"] *= 1.2
			"tracts": s["count"] *= 2; s["pierce"] += 99
			"cigare": s["dmg"] *= 1.2
			"piolet": s["dmg"] *= 1.15
	var fu: String = w.get("fusion", "")
	if fu != "":
		s["dmg"] *= 1.25
		s["fusion"] = fu
		if fu == "datcha_infernale" and id == "goulag": s["dmg"] *= 3.0
	return s

func _process(d: float):
	if game == null or game.state != "play": return
	d = minf(d, 0.05)
	slam_cd = maxf(0.0, slam_cd - d)
	for id in owned:
		if id == "spoutnik" or id == game.player.seized_weapon: continue
		timers[id] -= d
		if timers[id] <= 0.0:
			var s := stats(id)
			timers[id] = s["cd"] if _fire(id, s) else 0.2
	if owned.has("spoutnik"): _update_sats(d)
	if aura_fx: _update_aura_fx(d)
	if owned.has("ours"): _update_bears(d)
	_update_walls(d)
	_update_cages(d)
	_update_projectiles(d)
	_update_fires(d)
	_update_trails(d)

func _hit(e, dmg: float, s: Dictionary, from := Vector3.INF, knock := 0.0, src := "", show := true, ignore_armor := false):
	var mod: String = s.get("module", "")
	if mod == "kalach_incendiaire": ignore_armor = true
	if mod == "marteau_gel": e.slow_t = 2.0
	if mod == "samovar_glace": e.slow_t = 1.2
	game.track_damage(s.get("id", ""), dmg)
	game.enemies.damage(e, dmg, from, knock, src, show, ignore_armor, s["crit"], s.get("id", ""))

func _fire(id: String, s: Dictionary) -> bool:
	var pp: Vector3 = game.player.global_position
	match id:
		"marteau":
			_shockwave(pp, s["area"], s["dmg"], Color(1.0, 0.3, 0.15), s, owned[id]["evo"])
			if owned[id]["evo"]:
				get_tree().create_timer(0.35, false).timeout.connect(func(): _shockwave(game.player.global_position, s["area"] * 1.4, s["dmg"] * 0.8, Color(1.0, 0.6, 0.2), s, true))
			if s.get("fusion", "") == "faucille_marteau":
				var fs := stats("faucille")
				for i in 6:
					_sickle(Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 6.0), fs)
			return true
		"kalach":
			var targets := []
			for i in s["count"]:
				var t = game.enemies.nearest(pp, 28.0, targets)
				if t == null:
					if targets.is_empty(): return false
					t = targets[i % targets.size()]
				targets.append(t)
			for t in targets:
				var from := pp + Vector3(0, 1.0, 0)
				var to: Vector3 = t.node.position + Vector3(0, 0.9, 0)
				var dir := (to - from).normalized().rotated(Vector3.UP, randf_range(-0.04, 0.04))
				_bullet(from, dir, s)
			return true
		"faucille":
			var base_dir: Vector3 = game.player.facing
			var t = game.enemies.nearest(pp, 16.0)
			if t != null:
				base_dir = (t.node.position - pp); base_dir.y = 0; base_dir = base_dir.normalized()
			var n: int = s["count"]
			for i in n:
				_sickle(base_dir.rotated(Vector3.UP, (i - (n - 1) / 2.0) * (TAU / maxf(n, 3.0) if n > 3 else 0.6)), s)
			return true
		"molotov":
			for i in s["count"]:
				var tgt := pp + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				var t = game.enemies.nearest(pp + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7)), 18.0)
				if t != null: tgt = t.node.position
				_molotov(pp + Vector3(0, 1.5, 0), Vector3(tgt.x, 0, tgt.z), s)
			return true
		"matriochka":
			var targets := []
			for i in s["count"]:
				var t = game.enemies.nearest(pp, 22.0, targets)
				if t == null: break
				targets.append(t)
			if targets.is_empty(): return false
			for t in targets:
				_doll(pp + Vector3(0, 1.2, 0), t.node.position, s, s["depth"], 1.0)
			return true
		"samovar":
			var hits := 0
			for e in game.enemies.in_radius(pp, s["area"]):
				_hit(e, s["dmg"], s, Vector3.INF, 0.0, "", false)
				e.slow_t = 0.7
				hits += 1
			if owned[id]["evo"] and hits > 0:
				game.player.heal(minf(hits * 0.4, 3.0))
			return true
		"hautparleur":
			var dir: Vector3 = game.player.facing
			var full: bool = owned[id]["evo"]
			var ht = game.enemies.nearest(pp, s["area"])
			if ht == null: return false
			dir = ht.node.position - pp; dir.y = 0; dir = dir.normalized()
			for e in game.enemies.in_radius(pp, s["area"]):
				var v: Vector3 = e.node.position - pp
				v.y = 0
				if not full and v.length() > 0.5 and dir.angle_to(v.normalized()) > deg_to_rad(38): continue
				_hit(e, s["dmg"], s, pp, 16.0)
				game.enemies.stun(e, 0.6)
			_cone_fx(pp, dir, s["area"], full)
			if s.get("fusion", "") == "symphonie":
				var bs := stats("balalaika")
				for i in 6: _note(pp + Vector3(0, 1.4, 0), dir.rotated(Vector3.UP, (i - 2.5) * 0.35), bs)
			return true
		_:
			return _fire_new(id, s, pp)
	return false

# ---------------------------------------------------------------- marteau
func on_landed(fall_speed: float):
	if not owned.has("marteau") or fall_speed < 7.0 or slam_cd > 0.0: return
	slam_cd = 0.6
	var s := stats("marteau")
	_shockwave(game.player.global_position, s["area"] * 1.15, s["dmg"] * 2.0 * (1.0 + game.mods.get("slam_bonus", 0.0) / 100.0), Color(1.0, 0.75, 0.2), s, owned["marteau"]["evo"])
	game.pop_word(game.player.global_position + Vector3(0, 2.6, 0), ["BONK !", "KRACH !", "BAM !"][randi() % 3], Color(1.0, 0.85, 0.2), 1.1)

func _shockwave(center: Vector3, area: float, dmg: float, col: Color, s: Dictionary, stun := false):
	Snd.play("hammer", -4.0, 0.1, 0.12)
	for e in game.enemies.in_radius(center, area):
		_hit(e, dmg, s, center, 8.0)
		if stun: game.enemies.stun(e, 0.6)
	game.break_in_radius(center, area)
	_ring_fx(center, area, col)
	game.shake(0.12 if dmg < 150.0 else 0.22)

func _ring_fx(center: Vector3, area: float, col: Color):
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
	# second, cream ring trailing the red one: poster two-tone shockwave
	var ring2 := MeshInstance3D.new()
	var tm2 := TorusMesh.new(); tm2.inner_radius = 0.82; tm2.outer_radius = 0.9
	ring2.mesh = tm2
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(1.0, 0.93, 0.78, 0.9)
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring2.material_override = m2
	ring2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring2)
	ring2.global_position = Vector3(center.x, 0.1, center.z)
	ring2.scale = Vector3(0.2, 0.05, 0.2)
	var tw3 := create_tween().set_parallel()
	tw3.tween_property(ring2, "scale", Vector3(area * 0.92, 0.05, area * 0.92), 0.34).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw3.tween_property(m2, "albedo_color:a", 0.0, 0.38)
	tw3.chain().tween_callback(ring2.queue_free)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(ring.queue_free)
	var flash := _fx(self, "circle_05.png", Vector3(center.x, 0.06, center.z), area * 2.0, Color(col.r, col.g, col.b, 0.35), 2.0, false, Vector3(-PI / 2, 0, 0))
	var tw2 := create_tween()
	tw2.tween_property(flash, "scale", Vector3.ONE * 1.2, 0.25)
	tw2.tween_callback(flash.queue_free)

# ---------------------------------------------------------------- haut-parleur
func _cone_fx(pos: Vector3, dir: Vector3, rng_d: float, full: bool):
	var steps := 5
	for i in steps:
		var k := float(i + 1) / steps
		var dirs := [dir] if not full else [dir, dir.rotated(Vector3.UP, PI / 2), -dir, dir.rotated(Vector3.UP, -PI / 2)]
		for dd in dirs:
			var p: Vector3 = pos + dd * rng_d * k + Vector3(0, 1.0, 0)
			var sp := _fx(self, "muzzle_02.png", p, 0.8 + 2.2 * k, Color(1.0, 0.85, 0.4, 0.6), 2.0)
			var tw := sp.create_tween()
			tw.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.25 + 0.05 * i)
			tw.tween_callback(sp.queue_free)

# ---------------------------------------------------------------- samovar aura
func _make_aura():
	aura_fx = Node3D.new()
	add_child(aura_fx)
	var ring := _fx(aura_fx, "circle_03.png", Vector3(0, 0.07, 0), 2.0, Color(1.0, 0.6, 0.25, 0.35), 1.5, false, Vector3(-PI / 2, 0, 0))
	ring.name = "ring"
	for i in 6:
		var st := _fx(aura_fx, "smoke_04.png", Vector3.ZERO, 0.9, Color(1, 0.9, 0.8, 0.25), 1.0)
		st.name = "steam%d" % i

func _update_aura_fx(d: float):
	var s := stats("samovar")
	aura_fx.global_position = game.player.global_position
	(aura_fx.get_node("ring") as Node3D).scale = Vector3.ONE * s["area"]
	var t := Time.get_ticks_msec() / 1000.0
	for i in 6:
		var a := t * 0.8 + i * TAU / 6.0
		(aura_fx.get_node("steam%d" % i) as Node3D).position = Vector3(cos(a), 0.4 + 0.3 * sin(t * 2.0 + i), sin(a)) * Vector3(s["area"] * 0.8, 1, s["area"] * 0.8)

# ---------------------------------------------------------------- spoutnik
func _update_sats(d: float):
	var s := stats("spoutnik")
	var n: int = s["count"]
	while sats.size() < n:
		var sp := Node3D.new()
		add_child(sp)
		U.sphere(sp, 0.25, Vector3.ZERO, U.solid(Color(0.85, 0.85, 0.88), 0.0, 0.2, 1.0))
		for k in 4:
			var ant := U.cyl(sp, 0.012, 0.8, Vector3(0, -0.2, 0.2), U.solid(Color(0.8, 0.8, 0.8), 0.0, 0.3, 1.0))
			ant.rotation = Vector3(0.9, k * PI / 2, 0.6)
		_fx(sp, "light_01.png", Vector3.ZERO, 1.2, Color(0.4, 0.8, 1.0, 0.5), 2.0)
		sats.append(sp)
	orbit_a += d * 2.4
	var pp: Vector3 = game.player.global_position
	for i in sats.size():
		var a := orbit_a + TAU * i / sats.size()
		var p := pp + Vector3(cos(a) * s["area"], 1.2, sin(a) * s["area"])
		sats[i].global_position = p
		for e in game.enemies.in_radius(p, 0.9):
			_hit(e, s["dmg"], s, p, 6.0, "sat")
			game.enemies.set_hit_cd(e, "sat", s["cd"])
	if owned["spoutnik"].get("fusion", "") == "conquete_spatiale":
		star_t -= d
		if star_t <= 0.0:
			star_t = 2.0
			var tg := _toughest(pp, 25.0, 1)
			if not tg.is_empty(): _star(sats[0].global_position, tg[0].node.position, stats("etoile"))
	if owned["spoutnik"]["evo"]:
		laser_t -= d
		if laser_t <= 0.0:
			laser_t = 1.0
			var t = game.enemies.nearest(pp, 18.0)
			if t != null:
				_hit(t, s["dmg"] * 3.0, s)
				_beam(sats[0].global_position, t.node.position + Vector3(0, 1.0, 0))

func _beam(a: Vector3, b: Vector3):
	Snd.play("laser", -12.0, 0.1, 0.2)
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new(); bc.top_radius = 0.04; bc.bottom_radius = 0.04; bc.height = a.distance_to(b)
	beam.mesh = bc
	beam.material_override = U.solid(Color(0.3, 0.9, 1.0), 8.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = (a + b) / 2.0
	var dirv := (b - a).normalized()
	if absf(dirv.dot(Vector3.UP)) < 0.99:
		beam.look_at(b, Vector3.UP)
		beam.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := beam.create_tween()
	tw.tween_property(beam, "scale", Vector3(0.1, 1, 0.1), 0.15)
	tw.tween_callback(beam.queue_free)

# ---------------------------------------------------------------- kalach
func _bullet(from: Vector3, dir: Vector3, s: Dictionary):
	Snd.play("gun", -10.0, 0.12, 0.07)
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var b := U.sphere(n, 0.07, Vector3.ZERO, U.solid(Color(1, 0.8, 0.3), 6.0))
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tr := _fx(n, "trace_01.png", Vector3(0, 0, 0.6), 1.2, Color(1, 0.75, 0.3), 3.0, false, Vector3(PI / 2, 0, 0))
	tr.scale = Vector3(0.3, 1.8, 1)
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 0.05:
		n.look_at(from + flat, Vector3.UP)
	projectiles.append({"t": "bullet", "n": n, "v": dir * float(s["speed"]), "life": 1.2, "s": s, "pierce": s["pierce"], "hits": []})

# ---------------------------------------------------------------- faucille
func _sickle(dir: Vector3, s: Dictionary):
	Snd.play("slice", -8.0, 0.15, 0.15)
	var n := Node3D.new()
	add_child(n)
	var blade := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.42; tm.outer_radius = 0.55; tm.rings = 24
	blade.mesh = tm; blade.scale = Vector3(1, 0.25, 1)
	blade.material_override = U.solid(Color(0.85, 0.86, 0.9), 0.6, 0.2, 1.0)
	n.add_child(blade)
	U.box(n, Vector3(0.1, 0.1, 0.5), Vector3(0.5, 0, 0.3), U.solid(Color(0.75, 0.08, 0.1), 0.0, 0.6))
	_fx(n, "twirl_01.png", Vector3.ZERO, 1.8, Color(1, 0.25, 0.2, 0.7), 2.0, false, Vector3(-PI / 2, 0, 0))
	n.global_position = game.player.global_position + Vector3(0, 1.1, 0)
	projectiles.append({"t": "sickle", "n": n, "dir": dir, "age": 0.0, "dur": 1.5, "range": s["range"], "s": s})

# ---------------------------------------------------------------- molotov
func _molotov(from: Vector3, to: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	U.cyl(n, 0.08, 0.3, Vector3.ZERO, U.solid(Color(0.25, 0.55, 0.3, 0.9), 0.0, 0.1))
	_fx(n, "flame_02.png", Vector3(0, 0.25, 0), 0.4, Color(1, 0.6, 0.2), 3.0)
	projectiles.append({"t": "molotov", "n": n, "from": from, "to": to, "age": 0.0, "dur": 0.6, "s": s})

func _spawn_fire(p: Vector3, s: Dictionary):
	Snd.play("glass", -6.0, 0.1, 0.12); Snd.play("fire", -10.0, 0.1, 0.2)
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	var area: float = s["area"]
	_fx(root, "scorch_02.png", Vector3(0, 0.03, 0), area * 2.2, Color(0.15, 0.08, 0.04, 0.8), 1.0, false, Vector3(-PI / 2, 0, 0))
	var flames := []
	for i in int(6 + area * 3):
		var o := Vector3(randf_range(-area, area) * 0.8, 0, randf_range(-area, area) * 0.8)
		if o.length() > area: o = o.normalized() * area * 0.9
		var h := randf_range(0.8, 1.8)
		flames.append(_fx(root, "flame_0%d.png" % (1 + i % 4), o + Vector3(0, h * 0.45, 0), h, Color(1, 0.5, 0.15) if i % 3 else Color(1, 0.2, 0.1), 3.0))
	fires.append({"n": root, "life": s["duration"], "area": area, "s": s, "tick": 0.0, "flames": flames})

func _update_fires(d: float):
	var t := Time.get_ticks_msec() / 1000.0
	for f in fires.duplicate():
		f["life"] -= d
		f["tick"] -= d
		for i in f["flames"].size():
			(f["flames"][i] as Node3D).scale = Vector3.ONE * (0.85 + 0.2 * sin(t * 9.0 + i))
		if f["tick"] <= 0.0:
			f["tick"] = 0.3
			for e in game.enemies.in_radius(f["n"].global_position, f["area"]):
				_hit(e, f["s"]["dmg"], f["s"], Vector3.INF, 0.0, "", false, true)
		if f["life"] <= 0.0:
			fires.erase(f)
			var n: Node3D = f["n"]
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector3(1, 0.01, 1), 0.3)
			tw.tween_callback(n.queue_free)

# ---------------------------------------------------------------- matriochka
func _doll(from: Vector3, to: Vector3, s: Dictionary, depth: int, size: float):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var red := U.solid(Color(0.8, 0.1, 0.12), 0.0, 0.5)
	U.sphere(n, 0.28 * size, Vector3(0, 0, 0), red, 0.7 * size)
	U.sphere(n, 0.2 * size, Vector3(0, 0.38 * size, 0), red)
	U.sphere(n, 0.13 * size, Vector3(0, 0.38 * size, 0.1 * size), U.solid(Color(0.96, 0.85, 0.72)))
	projectiles.append({"t": "doll", "n": n, "from": from, "to": Vector3(to.x, 0.3, to.z), "age": 0.0, "dur": 0.45 if size >= 1.0 else 0.3, "s": s, "depth": depth, "size": size})

func _doll_burst(p: Vector3, s: Dictionary, depth: int, size: float):
	Snd.play("hit_soft", -8.0, 0.2, 0.08, 1.0 + (1.0 - size) * 0.6)
	var rad := 1.8 * size + 0.4
	var dmg: float = s["dmg"] * size
	for e in game.enemies.in_radius(p, rad):
		_hit(e, dmg, s, p, 6.0)
	var fx := _fx(self, "star_04.png", p + Vector3(0, 0.6, 0), rad * 1.6, Color(1, 0.3, 0.2), 2.5)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 0.1, 0.25)
	tw.tween_callback(fx.queue_free)
	if depth > 0:
		var n: int = s["split"]
		var off := randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			_doll(p + Vector3(0, 0.6, 0), p + Vector3(cos(a), 0, sin(a)) * (3.0 + size), s, depth - 1, size * 0.65)

func _update_projectiles(d: float):
	for p in projectiles.duplicate():
		var n: Node3D = p["n"]
		match p["t"]:
			"bullet":
				n.global_position += p["v"] * d
				p["life"] -= d
				var done := false
				for e in game.enemies.in_radius(n.global_position, 0.35):
					if p["hits"].has(e): continue
					p["hits"].append(e)
					_hit(e, p["s"]["dmg"], p["s"], n.global_position - p["v"].normalized(), 3.0)
					game.spark(n.global_position)
					if p["s"].get("fusion", "") == "armee_rouge" and p["s"]["id"] == "kalach":
						_blast(n.global_position, 1.4, p["s"]["dmg"] * 0.6, p["s"], Color(1, 0.55, 0.2))
					if p["hits"].size() > p["pierce"]:
						done = true
						break
				if done or p["life"] <= 0.0:
					projectiles.erase(p); n.queue_free()
			"sickle":
				p["age"] += d
				var k: float = p["age"] / p["dur"]
				var origin: Vector3 = game.player.global_position + Vector3(0, 1.1, 0)
				var side := Vector3(-p["dir"].z, 0, p["dir"].x)
				var pos: Vector3 = origin + p["dir"] * sin(k * PI) * p["range"] + side * sin(k * TAU) * 1.6
				n.global_position = pos
				n.rotation.y += d * 18.0
				var src := "sickle%d" % n.get_instance_id()
				for e in game.enemies.in_radius(pos, 0.8):
					_hit(e, p["s"]["dmg"], p["s"], pos, 5.0, src)
					game.enemies.set_hit_cd(e, src, 0.35)
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
					game.shake(0.05)
			"tractor", "shell", "rocket", "note", "vodka", "cigar", "star":
				_update_new_projectile(p, n, d)
			"doll":
				p["age"] += d
				var k: float = clampf(p["age"] / p["dur"], 0.0, 1.0)
				var pos: Vector3 = p["from"].lerp(p["to"], k)
				pos.y += sin(k * PI) * 2.0 * p["size"]
				n.global_position = pos
				n.rotation.z += d * 10.0
				if k >= 1.0:
					projectiles.erase(p); n.queue_free()
					_doll_burst(p["to"], p["s"], p["depth"], p["size"])

# ---------------------------------------------------------------- slide trail & dodge
func trail_damage() -> float:
	return (8.0 + 1.6 * game.level) * (1.0 + game.dv("productivite") / 100.0)

func add_trail(p: Vector3):
	if trails.size() > 90:
		var old: Dictionary = trails.pop_front()
		old["n"].queue_free()
	var n := _fx(self, "flame_0%d.png" % (1 + randi() % 4), Vector3(p.x, 0.45, p.z), 1.0, Color(1, 0.35, 0.12, 0.9), 2.2)
	trails.append({"n": n, "pos": Vector3(p.x, 0, p.z), "life": 2.0, "tick": 0.0})

func _update_trails(d: float):
	var s := {"crit": 0.05 + game.dv("critique") / 100.0, "id": ""}
	var dmg := trail_damage()
	for t in trails.duplicate():
		t["life"] -= d
		t["tick"] -= d
		var n: Node3D = t["n"]
		n.scale = Vector3.ONE * clampf(t["life"] / 2.0, 0.05, 1.0)
		if t["tick"] <= 0.0:
			t["tick"] = 0.3
			for e in game.enemies.in_radius(t["pos"], 0.7):
				game.enemies.damage(e, dmg, Vector3.INF, 0.0, "", false, true, s["crit"], "")
		if t["life"] <= 0.0:
			trails.erase(t)
			n.queue_free()

func dodge_fx(p: Vector3, dir: Vector3):
	for i in 4:
		var sp := _fx(self, "smoke_04.png", p + Vector3(0, 0.8, 0) - dir * i * 0.7, 1.2 - i * 0.2, Color(0.9, 0.9, 1.0, 0.35), 1.0)
		var tw := sp.create_tween()
		tw.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.35)
		tw.tween_callback(sp.queue_free)

# player effects are drawn more discreetly than enemy threats (readability), scaled by the FX option
func _fx(parent: Node, tex: String, pos: Vector3, size: float, color: Color, energy := 2.0, billboard := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var k: float = Meta.opt("fx") / 100.0
	var c := Color(color.r, color.g, color.b, color.a * 0.75 * k)
	return U.sprite(parent, tex, pos, size, c, energy * (0.6 + 0.4 * k), billboard, rot)

# ================================================================ the twelve newer weapons
func _fire_new(id: String, s: Dictionary, pp: Vector3) -> bool:
	match id:
		"tracteur":
			var t = game.enemies.nearest(pp, 24.0)
			var base: Vector3 = game.player.facing
			if t != null:
				base = t.node.position - pp; base.y = 0; base = base.normalized()
			var n: int = s["count"]
			for i in n:
				var dir := base.rotated(Vector3.UP, (i - (n - 1) / 2.0) * 0.5)
				_tractor(pp - dir * 4.0, dir, s)
			if s.get("fusion", "") == "ours_tractoriste":
				for b in bears:
					var bt = game.enemies.nearest((b as Node3D).global_position, 20.0)
					if bt == null: continue
					var bd: Vector3 = bt.node.position - (b as Node3D).global_position; bd.y = 0
					_tractor((b as Node3D).global_position - bd.normalized() * 3.0, bd.normalized(), s)
			return t != null
		"ours":
			var any := false
			for b in bears:
				var bp: Vector3 = (b as Node3D).global_position
				var hit_any := false
				for e in game.enemies.in_radius(bp, s["area"]):
					_hit(e, s["dmg"], s, bp, 7.0)
					if owned[id]["evo"]: game.enemies.stun(e, 0.4)
					hit_any = true
				if hit_any:
					any = true
					_slash_fx(bp, s["area"], Color(0.9, 0.6, 0.3))
			return any
		"vodka":
			var targets := []
			for i in s["count"]:
				var t = game.enemies.nearest(pp, 20.0, targets)
				if t == null: break
				targets.append(t)
			if targets.is_empty(): return false
			for t in targets:
				_vodka(pp + Vector3(0, 1.3, 0), t, s, s["chain"], [], 1.0)
			return true
		"piolet":
			var dir: Vector3 = game.player.facing
			var t = game.enemies.nearest(pp, s["area"] + 0.5)
			if t == null: return false      # waits for a target instead of swinging at nothing
			dir = t.node.position - pp; dir.y = 0; dir = dir.normalized()
			var full: bool = owned[id]["evo"]
			_swing(pp, dir, s, full)
			if full:
				get_tree().create_timer(0.25, false).timeout.connect(func(): _swing(game.player.global_position, dir, s, true))
			return true
		"rideau":
			var dir: Vector3 = game.player.facing
			if owned[id]["evo"]:
				for k in 4: _wall(pp + dir.rotated(Vector3.UP, k * PI / 2) * 4.5, dir.rotated(Vector3.UP, k * PI / 2 + PI / 2), s)
			else:
				var t = game.enemies.nearest(pp, 14.0)
				if t != null:
					dir = t.node.position - pp; dir.y = 0; dir = dir.normalized()
				_wall(pp + dir * 4.5, dir.rotated(Vector3.UP, PI / 2), s)
			return true
		"t34":
			var targets := []
			for i in s["count"]:
				var t = game.enemies.nearest(pp + game.player.facing * 6.0, 26.0, targets)
				if t == null: break
				targets.append(t)
			if targets.is_empty(): return false
			for t in targets:
				_shell(pp + Vector3(0, 1.4, 0), t.node.position, s)
			return true
		"katioucha":
			var list: Array = game.enemies.in_radius(pp, 18.0)
			if list.is_empty(): return false
			for i in s["count"]:
				var e = list[randi() % list.size()]
				var tp: Vector3 = e.node.position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
				_rocket(tp, s, 0.35 + i * 0.08)
			return true
		"balalaika":
			var any := false
			for i in s["count"]:
				var dir: Vector3 = game.player.facing.rotated(Vector3.UP, randf_range(-1.2, 1.2))
				_note(pp + Vector3(0, 1.4, 0), dir, s)
				any = true
			return any and game.enemies.count() > 0
		"goulag":
			var n := 3 if owned[id]["evo"] else 1
			var done := []
			for i in n:
				var t = game.enemies.nearest(pp + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 16.0, done)
				if t == null: break
				done.append(t)
				_cage(t.node.position, s)
			return not done.is_empty()
		"etoile":
			var tg := _toughest(pp, 25.0, 3 if owned[id]["evo"] else 1)
			if tg.is_empty(): return false
			for e in tg: _star(e.node.position + Vector3(0, 14, 0), e.node.position, s)
			return true
		"tracts":
			var n: int = s["count"]
			for i in n:
				spiral_a += 0.45
				var dir := Vector3(cos(spiral_a + TAU * i / n), 0, sin(spiral_a + TAU * i / n))
				_leaf(pp + Vector3(0, 1.2, 0), dir, s)
			return true
		"cigare":
			var targets := []
			for i in s["count"]:
				var t = game.enemies.nearest(pp, 18.0, targets)
				if t == null: break
				targets.append(t)
			if targets.is_empty(): return false
			for t in targets:
				_cigar(pp + Vector3(0, 1.3, 0), t, s)
			return true
	return false

# ---------------------------------------------------------------- helpers
func _toughest(p: Vector3, rad: float, n: int) -> Array:
	var l: Array = game.enemies.in_radius(p, rad).duplicate()
	l.sort_custom(func(a, b): return a.hp > b.hp)
	return l.slice(0, n)

func _blast(p: Vector3, rad: float, dmg: float, s: Dictionary, col: Color, show := true):
	Snd.play("explosion" if rad >= 2.4 else "explosion2", -6.0 if rad >= 2.4 else -9.0, 0.12, 0.08)
	if rad >= 2.5 and randf() < 0.25: game.pop_word(p + Vector3(0, 2.2, 0), ["BOUM !", "PAF !", "VLAN !"][randi() % 3], Color(1.0, 0.55, 0.15), 0.9)
	for e in game.enemies.in_radius(p, rad):
		_hit(e, dmg, s, p, 6.0, "", show)
	var fx := _fx(self, "star_04.png", p + Vector3(0, 0.5, 0), rad * 1.7, col, 2.5)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 0.1, 0.25)
	tw.tween_callback(fx.queue_free)

func _slash_fx(p: Vector3, rad: float, col: Color):
	var fx := _fx(self, "slash_02.png", Vector3(p.x, 0.6, p.z), rad * 2.0, Color(col.r, col.g, col.b, 0.8), 2.0, false, Vector3(-PI / 2, randf() * TAU, 0))
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 1.3, 0.18)
	tw.tween_callback(fx.queue_free)

# ---------------------------------------------------------------- tracteur
func _tractor(from: Vector3, dir: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(from.x, 0.0, from.z)
	var w: float = s["area"]
	var red := U.solid(Color(0.75, 0.1, 0.1), 0.0, 0.5)
	U.box(n, Vector3(w * 1.1, 1.0, 2.2), Vector3(0, 0.9, 0), red)
	U.box(n, Vector3(w * 0.8, 0.9, 0.9), Vector3(0, 1.8, -0.4), U.solid(Color(0.2, 0.2, 0.22)))
	for sx in [-1.0, 1.0]:
		var wh := U.cyl(n, 0.65, 0.4, Vector3(sx * w * 0.6, 0.65, -0.6), U.solid(Color(0.1, 0.1, 0.1)))
		wh.rotation = Vector3(0, 0, PI / 2)
		var fw := U.cyl(n, 0.4, 0.3, Vector3(sx * w * 0.55, 0.4, 0.8), U.solid(Color(0.1, 0.1, 0.1)))
		fw.rotation = Vector3(0, 0, PI / 2)
	n.look_at(n.global_position + dir, Vector3.UP)
	n.rotate_object_local(Vector3.UP, PI)
	projectiles.append({"t": "tractor", "n": n, "v": dir * float(s["speed"]), "life": s["range"] / s["speed"], "s": s, "hits": []})

# ---------------------------------------------------------------- ours
func _update_bears(d: float):
	var s := stats("ours")
	var n: int = s["count"]
	while bears.size() < n:
		var b := Node3D.new()
		add_child(b)
		var br := U.solid(Color(0.38, 0.24, 0.14), 0.0, 0.9)
		U.sphere(b, 0.75, Vector3(0, 0.85, 0), br, 1.0)
		U.sphere(b, 0.45, Vector3(0, 1.35, 0.65), br)
		U.sphere(b, 0.18, Vector3(0, 1.28, 1.05), U.solid(Color(0.55, 0.4, 0.3)))
		for ex in [-0.28, 0.28]:
			U.sphere(b, 0.14, Vector3(ex, 1.75, 0.55), br)
		var hat := Node3D.new(); b.add_child(hat); hat.position = Vector3(0, 1.72, 0.6)
		U.cyl(hat, 0.3, 0.25, Vector3.ZERO, U.solid(Color(0.35, 0.25, 0.18), 0.0, 1.0))
		U.cyl(hat, 0.08, 0.05, Vector3(0, 0.05, 0.3), U.solid(Color(0.8, 0.1, 0.1), 1.0)).rotation = Vector3(PI / 2, 0, 0)
		b.scale = Vector3.ONE * (1.3 if owned["ours"]["evo"] else 1.0)
		b.global_position = game.player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		bears.append(b)
	var pp: Vector3 = game.player.global_position
	for i in bears.size():
		var b: Node3D = bears[i]
		var home := pp + Vector3(cos(TAU * i / bears.size()), 0, sin(TAU * i / bears.size())) * 2.5
		var target := home
		var t = game.enemies.nearest(b.global_position, 9.0)
		if t != null and t.node.position.distance_to(pp) < 14.0: target = t.node.position
		var v := target - b.global_position
		v.y = 0
		if v.length() > 0.8:
			var step: Vector3 = v.normalized() * minf(v.length(), float(s["speed"]) * d * (1.6 if v.length() > 10.0 else 1.0))
			b.global_position += step
			b.rotation.y = atan2(v.x, v.z)
		b.global_position.y = absf(sin(Time.get_ticks_msec() / 120.0 + i)) * 0.15
		if b.global_position.distance_to(pp) > 25.0: b.global_position = pp

# ---------------------------------------------------------------- vodka
func _vodka(from: Vector3, target, s: Dictionary, chain: int, hit: Array, mult: float):
	Snd.play("whoosh", -16.0, 0.2, 0.1, 1.6)
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	U.cyl(n, 0.09, 0.4, Vector3.ZERO, U.solid(Color(0.85, 0.92, 1.0, 0.7), 0.4, 0.1))
	U.cyl(n, 0.04, 0.12, Vector3(0, 0.25, 0), U.solid(Color(0.8, 0.1, 0.1)))
	projectiles.append({"t": "vodka", "n": n, "target": target, "s": s, "chain": chain, "hits": hit, "mult": mult, "life": 1.5})

# ---------------------------------------------------------------- piolet
func _swing(pp: Vector3, dir: Vector3, s: Dictionary, full: bool):
	Snd.play("slice", -4.0, 0.1, 0.1, 0.8)
	for e in game.enemies.in_radius(pp, s["area"]):
		var v: Vector3 = e.node.position - pp
		v.y = 0
		if not full and v.length() > 0.6 and dir.angle_to(v.normalized()) > deg_to_rad(85): continue
		_hit(e, s["dmg"], s, pp, 9.0)
	var fx := _fx(self, "twirl_01.png", Vector3(pp.x, 0.9, pp.z) + dir * (0.0 if full else s["area"] * 0.4), s["area"] * (2.2 if full else 1.6), Color(0.85, 0.9, 1.0, 0.8), 2.5, false, Vector3(-PI / 2, atan2(dir.x, dir.z), 0))
	var tw := fx.create_tween()
	tw.tween_property(fx, "rotation:y", fx.rotation.y + 2.5, 0.18)
	tw.tween_callback(fx.queue_free)

# ---------------------------------------------------------------- rideau de fer
func _wall(c: Vector3, along: Vector3, s: Dictionary):
	Snd.play("slam", -4.0, 0.05, 0.2)
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(c.x, 0, c.z)
	var half: float = s["area"]
	U.box(n, Vector3(half * 2.0, 1.2, 0.3), Vector3(0, 0.6, 0), U.solid(Color(0.4, 0.42, 0.45, 0.85), 0.0, 0.4, 0.8))
	U.box(n, Vector3(half * 2.0, 0.12, 0.36), Vector3(0, 1.24, 0), U.solid(Color(0.75, 0.08, 0.1)))
	n.rotation.y = atan2(along.x, along.z) - PI / 2
	n.scale = Vector3(1, 0.05, 1)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	walls.append({"n": n, "c": n.global_position, "along": along.normalized(), "half": half, "life": s["duration"], "tick": 0.0, "s": s})
	game.shake(0.05)

func _update_walls(d: float):
	for w in walls.duplicate():
		w["life"] -= d
		w["tick"] -= d
		if w["tick"] <= 0.0:
			w["tick"] = 0.4
			var c: Vector3 = w["c"]
			var along: Vector3 = w["along"]
			var normal := Vector3(-along.z, 0, along.x)
			for e in game.enemies.in_radius(c, w["half"] + 1.0):
				var v: Vector3 = e.node.position - c
				v.y = 0
				if absf(v.dot(along)) > w["half"] or absf(v.dot(normal)) > 1.1: continue
				var side := signf(v.dot(normal))
				if side == 0.0: side = 1.0
				_hit(e, w["s"]["dmg"], w["s"], c - normal * side * 3.0, 9.0)
		if w["life"] <= 0.0:
			walls.erase(w)
			var n: Node3D = w["n"]
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(1, 0.05, 1), 0.2)
			tw.tween_callback(n.queue_free)

# ---------------------------------------------------------------- char du peuple
func _shell(from: Vector3, to: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	U.sphere(n, 0.22, Vector3.ZERO, U.solid(Color(0.25, 0.27, 0.2), 0.0, 0.4, 0.7))
	_fx(n, "smoke_04.png", Vector3(0, 0, 0), 0.6, Color(0.8, 0.8, 0.8, 0.5), 1.0)
	var dist := from.distance_to(to)
	projectiles.append({"t": "shell", "n": n, "from": from, "to": Vector3(to.x, 0.3, to.z), "age": 0.0, "dur": maxf(0.25, dist / float(s["speed"])), "s": s})

# ---------------------------------------------------------------- orgue du peuple
func _rocket(to: Vector3, s: Dictionary, delay: float):
	var n := Node3D.new()
	add_child(n)
	n.global_position = to + Vector3(-3, 16, -3)
	U.cyl(n, 0.1, 0.8, Vector3.ZERO, U.solid(Color(0.3, 0.35, 0.25)))
	_fx(n, "flame_02.png", Vector3(0, 0.6, 0), 0.6, Color(1, 0.6, 0.2), 3.0)
	n.look_at(to, Vector3.UP)
	n.rotate_object_local(Vector3.RIGHT, -PI / 2)
	projectiles.append({"t": "rocket", "n": n, "from": n.global_position, "to": to, "age": -delay, "dur": 0.45, "s": s})

# ---------------------------------------------------------------- balalaïka
func _note(from: Vector3, dir: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var l := Label3D.new(); l.text = "♪"; l.font = load("res://fonts/Symbols.ttf"); l.font_size = 128; l.pixel_size = 0.006
	l.modulate = Color(1, 0.85, 0.3); l.outline_size = 0; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = false
	n.add_child(l)
	projectiles.append({"t": "note", "n": n, "v": dir.normalized() * float(s["speed"]), "life": 2.4, "s": s, "pierce": s["pierce"], "hits": [], "target": null})

# ---------------------------------------------------------------- goulag
func _cage(p: Vector3, s: Dictionary):
	Snd.play("hammer", -6.0, 0.05, 0.2, 0.7)
	var n := Node3D.new()
	add_child(n)
	p = Vector3(p.x, 0, p.z)
	n.global_position = p + Vector3(0, 8, 0)
	var r: float = s["area"]
	var bar := U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.9)
	for i in 12:
		var a := TAU * i / 12.0
		U.cyl(n, 0.06, 2.4, Vector3(cos(a) * r, 1.2, sin(a) * r), bar)
	U.cyl(n, r, 0.12, Vector3(0, 2.4, 0), bar)
	U.label(n, "GOULAG", Vector3(0, 2.8, 0), 64, Color(1, 0.85, 0.3), Color(0, 0, 0, 1))
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", p, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cages.append({"n": n, "p": p, "r": r, "life": s["duration"] + 0.25, "tick": 0.25, "s": s})

func _update_cages(d: float):
	for c in cages.duplicate():
		c["life"] -= d
		c["tick"] -= d
		if c["tick"] <= 0.0:
			c["tick"] = 0.5
			for e in game.enemies.in_radius(c["p"], c["r"]):
				_hit(e, c["s"]["dmg"], c["s"], Vector3.INF, 0.0, "", false)
				e.slow_t = 0.6
				if not e.boss and not e.elite: game.enemies.stun(e, 0.55)
			if c["s"].get("fusion", "") == "datcha_infernale":
				for e in game.enemies.in_radius(c["p"], c["r"] * 1.8): e.slow_t = 0.6
		if c["life"] <= 0.0:
			cages.erase(c)
			(c["n"] as Node3D).queue_free()

# ---------------------------------------------------------------- étoile rouge
func _star(from: Vector3, to: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var l := Label3D.new(); l.text = "★"; l.font = load("res://fonts/Symbols.ttf"); l.font_size = 192; l.pixel_size = 0.012
	l.modulate = Color(1, 0.2, 0.15); l.outline_size = 0; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.add_child(l)
	_fx(n, "light_01.png", Vector3.ZERO, 2.5, Color(1, 0.3, 0.2, 0.6), 3.0)
	projectiles.append({"t": "star", "n": n, "from": from, "to": Vector3(to.x, 0.4, to.z), "age": 0.0, "dur": 0.45, "s": s})

# ---------------------------------------------------------------- tracts
func _leaf(from: Vector3, dir: Vector3, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var b := U.box(n, Vector3(0.45, 0.02, 0.32), Vector3.ZERO, U.solid(Color(0.95, 0.92, 0.85), 0.3))
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.box(n, Vector3(0.2, 0.03, 0.12), Vector3(0, 0.005, 0), U.solid(Color(0.8, 0.1, 0.1)))
	n.rotation.y = atan2(dir.x, dir.z)
	projectiles.append({"t": "bullet", "n": n, "v": dir * float(s["speed"]), "life": 1.6, "s": s, "pierce": s["pierce"], "hits": []})

# ---------------------------------------------------------------- havane
func _cigar(from: Vector3, target, s: Dictionary):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	var c := U.cyl(n, 0.07, 0.45, Vector3.ZERO, U.solid(Color(0.45, 0.28, 0.12)))
	c.rotation = Vector3(PI / 2, 0, 0)
	_fx(n, "flame_02.png", Vector3(0, 0, 0.25), 0.25, Color(1, 0.5, 0.2), 3.0)
	projectiles.append({"t": "cigar", "n": n, "target": target, "s": s, "stuck": -1.0, "life": 1.5, "pos": from})

# ---------------------------------------------------------------- shared projectile update
func _update_new_projectile(p: Dictionary, n: Node3D, d: float):
	match p["t"]:
		"tractor":
			n.global_position += p["v"] * d
			p["life"] -= d
			for e in game.enemies.in_radius(n.global_position, p["s"]["area"]):
				if p["hits"].has(e): continue
				p["hits"].append(e)
				_hit(e, p["s"]["dmg"], p["s"], n.global_position - p["v"].normalized() * 2.0, 12.0)
			if p["life"] <= 0.0:
				projectiles.erase(p); n.queue_free()
		"shell", "star":
			p["age"] += d
			var k: float = clampf(p["age"] / p["dur"], 0.0, 1.0)
			var pos: Vector3 = p["from"].lerp(p["to"], k)
			if p["t"] == "shell": pos.y += sin(k * PI) * 1.2
			n.global_position = pos
			if k >= 1.0:
				projectiles.erase(p); n.queue_free()
				var s: Dictionary = p["s"]
				_blast(p["to"], s["area"], s["dmg"], s, Color(1, 0.5, 0.15) if p["t"] == "shell" else Color(1, 0.2, 0.15))
				game.shake(0.06 if p["t"] == "shell" else 0.1)
		"rocket":
			p["age"] += d
			if p["age"] < 0.0: n.visible = false; return
			n.visible = true
			var k: float = clampf(p["age"] / p["dur"], 0.0, 1.0)
			n.global_position = p["from"].lerp(p["to"], k)
			if k >= 1.0:
				projectiles.erase(p); n.queue_free()
				var s: Dictionary = p["s"]
				_blast(p["to"], s["area"], s["dmg"], s, Color(1, 0.6, 0.2), false)
				if s.get("fusion", "") == "poupees_balistiques":
					var ms := stats("matriochka")
					for i in 2:
						var a := randf() * TAU
						_doll(p["to"] + Vector3(0, 0.6, 0), p["to"] + Vector3(cos(a), 0, sin(a)) * 3.0, ms, 0, 0.65)
		"note":
			p["life"] -= d
			var t = p["target"]
			if t == null or not t.alive:
				t = game.enemies.nearest(n.global_position, 12.0, p["hits"])
				p["target"] = t
			if t != null:
				var want: Vector3 = (t.node.position + Vector3(0, 1.0, 0) - n.global_position).normalized() * float(p["s"]["speed"])
				p["v"] = (p["v"] as Vector3).lerp(want, minf(1.0, d * 6.0))
			n.global_position += p["v"] * d
			var done := false
			for e in game.enemies.in_radius(n.global_position, 0.6):
				if p["hits"].has(e): continue
				p["hits"].append(e)
				_hit(e, p["s"]["dmg"], p["s"], n.global_position, 3.0)
				if p["s"].get("fusion", "") == "symphonie": game.enemies.stun(e, 0.4)
				p["target"] = null
				if p["hits"].size() > p["pierce"]:
					done = true
					break
			if done or p["life"] <= 0.0:
				projectiles.erase(p); n.queue_free()
		"vodka":
			p["life"] -= d
			var t = p["target"]
			if t == null or not t.alive or p["life"] <= 0.0:
				projectiles.erase(p); n.queue_free(); return
			var to: Vector3 = t.node.position + Vector3(0, 1.0, 0)
			var v: Vector3 = to - n.global_position
			n.rotation.x += d * 14.0
			if v.length() < 0.6:
				var s: Dictionary = p["s"]
				_hit(t, s["dmg"] * p["mult"], s, n.global_position, 4.0)
				p["hits"].append(t)
				if s.get("fusion", "") == "cocktail_luxe":
					var ms := stats("molotov")
					ms["area"] *= 0.6; ms["duration"] *= 0.6
					_spawn_fire(Vector3(t.node.position.x, 0, t.node.position.z), ms)
				projectiles.erase(p); n.queue_free()
				if p["chain"] > 0:
					var nxt = game.enemies.nearest(t.node.position, 9.0, p["hits"])
					if nxt != null:
						_vodka(to, nxt, s, p["chain"] - 1, p["hits"], p["mult"] * (1.1 if owned.has("vodka") and owned["vodka"]["evo"] else 1.0))
				return
			n.global_position += v.normalized() * minf(v.length(), float(p["s"]["speed"]) * d)
		"cigar":
			var t = p["target"]
			var s: Dictionary = p["s"]
			if p["stuck"] < 0.0:
				p["life"] -= d
				if t == null or not t.alive or p["life"] <= 0.0:
					projectiles.erase(p); n.queue_free(); return
				var to: Vector3 = t.node.position + Vector3(0, 1.2, 0)
				var v: Vector3 = to - n.global_position
				if v.length() < 0.6:
					p["stuck"] = 1.0
				else:
					n.global_position += v.normalized() * minf(v.length(), float(s["speed"]) * d)
					n.look_at(to, Vector3.UP)
			else:
				p["stuck"] -= d
				if t != null and t.alive:
					p["pos"] = t.node.position + Vector3(0, 1.2, 0)
				n.global_position = p["pos"]
				if p["stuck"] <= 0.0:
					projectiles.erase(p); n.queue_free()
					var c: Vector3 = Vector3(p["pos"].x, 0.3, p["pos"].z)
					_blast(c, s["area"], s["dmg"], s, Color(1, 0.55, 0.15))
					if owned.has("cigare") and owned["cigare"]["evo"]:
						for i in 3:
							var a := TAU * i / 3.0 + randf()
							var c2: Vector3 = c + Vector3(cos(a), 0, sin(a)) * s["area"] * 1.2
							get_tree().create_timer(0.2 + 0.1 * i, false).timeout.connect(func(): _blast(c2, s["area"] * 0.7, s["dmg"] * 0.5, s, Color(1, 0.7, 0.2), false))
