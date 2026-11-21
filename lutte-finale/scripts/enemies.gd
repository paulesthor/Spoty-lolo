extends Node3D
# Enemy manager: pooled capitalists with several behaviours (chase, charge, ranged, lob,
# summon, slam), armour, healers, shield auras, exploders, plus enemy hazards.

class Enemy:
	var node: Node3D
	var kind := ""
	var def: Dictionary
	var hp := 1.0
	var max_hp := 1.0
	var speed := 3.0
	var dmg := 5.0
	var armor := 0.0
	var r := 0.5
	var xp := 1
	var ai := "chase"
	var elite := false
	var boss := false
	var invincible := false
	var alive := false
	var knock := Vector3.ZERO
	var ap: AnimationPlayer
	var tag: Label3D
	var t_act := 0.0       # behaviour timer
	var phase := ""        # charger: "", "aim", "dash" ; slammer: "", "wind"
	var dash_dir := Vector3.ZERO
	var stun_t := 0.0
	var slow_t := 0.0
	var shielded := false
	var last_w := ""
	var affix := ""
	var affix_fx: Node3D
	var tp_t := 0.0
	var vuln_t := 0.0
	var level := -1
	var stun_imm := 0.0
	var idx := 0
	var anim_acc := 0.0       # diminishing returns: immune to new stuns while > 0           # -1 ground, otherwise index of the plateau it stands on
	var hit_from := {}

var game
var list: Array = []
var pools := {}
var hazards: Array = []    # enemy projectiles, lobs, ground zones, telegraphs
var gold_mat: StandardMaterial3D
var boss_mat: StandardMaterial3D
var _alive_cache: Array = []
var _tint_mats := {}
var heal_t := 0.0
var _next_idx := 0
var _frame := 0
var dying: Array = []
var aura_t := 0.0

func setup(g):
	game = g
	gold_mat = U.solid(Color(1.0, 0.72, 0.2), 0.0, 0.25, 1.0)
	boss_mat = U.solid(Color(0.16, 0.16, 0.2), 0.0, 0.5, 0.2)

func alive_list() -> Array:
	return _alive_cache

func count() -> int:
	return _alive_cache.size()

func _tint(n: Node3D, col: Color):
	var key := col.to_html()
	if not _tint_mats.has(key): _tint_mats[key] = U.solid(col, 0.0, 0.6)
	var body = null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		if c.name == "body-mesh": body = c
	if body: (body as MeshInstance3D).material_override = _tint_mats[key]

func spawn(kind: String, pos: Vector3, hp_mult := 1.0, dmg_mult := 1.0) -> Enemy:
	var def: Dictionary = Data.ENEMIES[kind]
	var e: Enemy
	if pools.has(kind) and not pools[kind].is_empty():
		e = pools[kind].pop_back()
		e.node.visible = true
		e.node.global_position = pos
		e.node.scale = e.node.get_meta("base_scale")
	else:
		e = Enemy.new()
		e.kind = kind
		e.node = Chars.build_enemy(self, kind, pos, def["h"] * 1.08)
		e.node.set_meta("base_scale", e.node.scale)
		var acc: Array = def["acc"].duplicate()
		if kind == "cadre" and randf() < 0.45: acc = []
		if kind == "cadre" and randf() < 0.3: acc.append("cigar")
		if kind == "stagiaire" and randf() < 0.15: acc = ["sunglasses"]
		if not acc.is_empty(): Chars.attach(e.node, acc)
		var show_tag: bool = def.get("elite", false) or def.get("boss", false) or def.get("invincible", false) or kind in ["coach", "lobbyiste", "drh"]
		if show_tag:
			var col := Color(1, 0.82, 0.3)
			if def.get("invincible", false): col = Color(0.6, 0.8, 1)
			elif kind == "coach": col = Color(0.5, 1, 0.5)
			elif kind == "lobbyiste": col = Color(0.8, 0.65, 1)
			e.tag = U.label(e.node, def["name"].to_upper(), Vector3.ZERO, 44 if not (def.get("elite", false) or def.get("boss", false)) else 56, col, Color(0.05, 0.03, 0, 1))
			e.tag.position = Vector3(0, (def["h"] + 0.3) / e.node.scale.y, 0)
			e.tag.fixed_size = true
			e.tag.pixel_size = 0.0006 if not (def.get("elite", false) or def.get("boss", false)) else 0.0009
		if def.get("shield_aura", false):
			var ring := U.sprite(e.node, "circle_03.png", Vector3(0, 0.05, 0), 10.0 / e.node.scale.x, Color(0.7, 0.5, 1.0, 0.18), 1.2, false, Vector3(-PI / 2, 0, 0))
		e.ap = U.anim_player(e.node)
		if e.ap:
			e.ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			e.ap.playback_default_blend_time = 0.1
		e.idx = _next_idx
		_next_idx += 1
	e.def = def
	e.hp = def["hp"] * hp_mult
	e.max_hp = e.hp
	e.speed = def["speed"] * randf_range(0.92, 1.08)
	e.dmg = def["dmg"] * dmg_mult
	e.armor = def.get("armor", 0.0) * (1.0 + 0.12 * game.time / 60.0) + 2.0 * game.dirl("lutte")
	e.last_w = ""
	e.vuln_t = 0.0
	e.level = -1
	e.r = def["r"]
	e.xp = def["xp"]
	e.ai = def.get("ai", "chase")
	e.elite = def.get("elite", false)
	e.boss = def.get("boss", false)
	e.invincible = def.get("invincible", false)
	e.alive = true
	e.affix = ""
	if e.affix_fx: e.affix_fx.queue_free(); e.affix_fx = null
	if not e.elite and not e.boss and not e.invincible and game.time > 180.0 and not game.warming:
		var ch := clampf(0.03 + (game.time - 180.0) / 360.0 * 0.12, 0.0, 0.2)
		if randf() < ch: _give_affix(e, ["blinde", "rapide", "diviseur", "vampire", "teleporteur"][randi() % 5])
	e.knock = Vector3.ZERO
	e.t_act = randf_range(1.0, 3.0)
	e.phase = ""
	e.stun_t = 0.0
	e.stun_imm = 0.0
	e.slow_t = 0.0
	e.hit_from.clear()
	if e.ap:
		var an: String = Chars.ENEMY_ANIMS["run"] if e.speed > 3.4 else Chars.ENEMY_ANIMS["walk"]
		if e.ap.has_animation(an):
			e.ap.play(an, 0.0)
			e.ap.seek(randf() * e.ap.current_animation_length, true)
			e.ap.speed_scale = e.speed / (4.5 if e.speed > 3.4 else 1.8)
			e.ap.advance(0.0)
	list.append(e)
	return e

const AFFIX_INFO := {
	"blinde": ["BLINDÉ", Color(0.6, 0.65, 0.75)],
	"rapide": ["RAPIDE", Color(0.3, 0.9, 1.0)],
	"diviseur": ["DIVISEUR", Color(0.9, 0.5, 1.0)],
	"vampire": ["VAMPIRE", Color(1.0, 0.2, 0.25)],
	"teleporteur": ["TÉLÉPORTEUR", Color(0.4, 1.0, 0.5)],
}

func _give_affix(e: Enemy, a: String):
	e.affix = a
	e.hp *= 2.2; e.max_hp = e.hp
	e.xp *= 3
	match a:
		"blinde": e.armor += 7.0
		"rapide": e.speed *= 1.6
		"teleporteur": e.tp_t = randf_range(3.0, 5.0)
	var info: Array = AFFIX_INFO[a]
	var fx := Node3D.new()
	e.node.add_child(fx)
	var sc: float = e.node.scale.y
	U.sprite(fx, "circle_03.png", Vector3(0, 0.05 / sc, 0), 2.4 / sc, Color(info[1].r, info[1].g, info[1].b, 0.8), 2.0, false, Vector3(-PI / 2, 0, 0))
	var l := U.label(fx, info[0], Vector3(0, (e.def["h"] + 0.35) / sc, 0), 40, info[1], Color(0, 0, 0, 1))
	l.fixed_size = true
	l.pixel_size = 0.0006
	e.affix_fx = fx

func _process(d: float):
	if game == null: return
	d = minf(d, 0.05)
	_alive_cache.clear()
	for e in list:
		if e.alive: _alive_cache.append(e)
	if game.state != "play": return
	_frame += 1
	_update_dying(d)
	var pp: Vector3 = game.player.global_position
	var grid := {}
	const CELL := 1.6
	var slow_world: float = game.enemy_speed_mult()
	var w = game.world
	var pl_player := -1
	if pp.y > 1.2:
		pl_player = w.plateau_at(pp)
		if pl_player < 0:
			var rp0: Array = w.ramp_at(pp)
			if not rp0.is_empty(): pl_player = rp0[0]
	# support auras
	heal_t -= d
	aura_t -= d
	var do_heal := heal_t <= 0.0
	if do_heal: heal_t = 2.0
	if aura_t <= 0.0:
		aura_t = 0.3
		for e in _alive_cache: e.shielded = false
		for s in _alive_cache:
			if s.def.get("shield_aura", false):
				for o in in_radius(s.node.position, 5.0):
					if o != s: o.shielded = true
	for e in _alive_cache:
		var p: Vector3 = e.node.position
		var to := Vector3(pp.x - p.x, 0, pp.z - p.z)
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)
		e.stun_t = maxf(0.0, e.stun_t - d)
		e.stun_imm = maxf(0.0, e.stun_imm - d)
		e.slow_t = maxf(0.0, e.slow_t - d)
		e.vuln_t = maxf(0.0, e.vuln_t - d)
		var spd: float = e.speed * slow_world * (0.6 if e.slow_t > 0.0 else 1.0)
		var move := dir
		if e.affix == "vampire": e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.02 * d)
		if e.affix == "teleporteur":
			e.tp_t -= d
			if e.tp_t <= 0.0 and dist < 25.0:
				e.tp_t = randf_range(4.0, 6.0)
				var side := Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
				_heal_fx(p)
				p = game.world.resolve(pp + side * 3.5 - dir * 1.5, e.r)
				_heal_fx(p)
		if e.stun_t > 0.0:
			spd = 0.0
		else:
			match e.ai:
				"charger": move = _ai_charger(e, dir, dist, d)
				"ranged": move = _ai_ranged(e, dir, dist, d, 11.0, 2.6)
				"lobber": move = _ai_lobber(e, dir, dist, d)
				"summoner": move = _ai_summoner(e, dir, dist, d)
				"slammer": move = _ai_slammer(e, dir, dist, d)
			if e.boss: move = _ai_boss(e, dir, dist, d)
			if e.phase == "dash": spd *= 4.5
			elif e.phase in ["aim", "wind"]: spd = 0.0
		if do_heal and e.def.get("healer", false):
			for o in in_radius(p, 5.0):
				if o != e and o.hp < o.max_hp and not o.boss:
					o.hp = minf(o.max_hp, o.hp + o.max_hp * 0.06)
					_heal_fx(o.node.position)
		# climbing: ground enemies head for a ramp when the player is up on a plateau,
		# and walk back down when the player leaves it
		var on_ramp: Array = w.ramp_at(p)
		if e.phase != "dash" and not e.invincible and e.stun_t <= 0.0 and (pl_player != e.level or not on_ramp.is_empty()):
			var target_pl: int = pl_player if pl_player >= 0 else e.level
			if target_pl >= 0 and target_pl < w.plateaus.size():
				var best_v := Vector3.ZERO
				var best_d := 1e9
				for rp in w.plateaus[target_pl]["ramps"]:
					var rc: Rect2 = rp["rect"]
					var c3 := Vector3(rc.get_center().x, 0, rc.get_center().y)
					var half: float = (rc.size.y if absf(rp["dir"].z) > 0.5 else rc.size.x) / 2.0
					var goal: Vector3 = c3 - rp["dir"] * (half + 0.5) if pl_player >= 0 else c3 + rp["dir"] * (half + 0.8)
					if (rc as Rect2).has_point(Vector2(p.x, p.z)):
						goal = c3 + rp["dir"] * (half + 1.5) if pl_player >= 0 else c3 - rp["dir"] * (half + 1.5)
					var dd := goal.distance_to(Vector3(p.x, 0, p.z))
					if dd < best_d: best_d = dd; best_v = goal
				if best_d < 1e8:
					var tv := best_v - Vector3(p.x, 0, p.z)
					if tv.length() > 0.3: move = tv.normalized()
		p += move * spd * d + e.knock * d
		e.knock = e.knock.move_toward(Vector3.ZERO, 30.0 * d)
		on_ramp = w.ramp_at(p)
		var ground_y := 0.0
		if not on_ramp.is_empty():
			ground_y = w.ramp_height(p, on_ramp[0], on_ramp[1])
			if ground_y > w.plateaus[on_ramp[0]]["h"] * 0.9: e.level = on_ramp[0]
			elif ground_y < 0.3: e.level = -1
		elif e.level >= 0:
			var pr: Rect2 = w.plateaus[e.level]["rect"]
			p.x = clampf(p.x, pr.position.x + e.r, pr.end.x - e.r)
			p.z = clampf(p.z, pr.position.y + e.r, pr.end.y - e.r)
			ground_y = w.plateaus[e.level]["h"]
		elif not e.invincible:
			p = w.resolve(p, e.r)
		p.y = ground_y
		e.node.position = p
		if e.ap:
			e.anim_acc += d
			var step := 1 if dist < 18.0 else (2 if dist < 35.0 else 4)
			if (_frame + e.idx) % step == 0:
				e.ap.advance(e.anim_acc)
				e.anim_acc = 0.0
		var face: Vector3 = dir if e.phase != "dash" else e.dash_dir
		if dist > 0.1:
			e.node.rotation.y = lerp_angle(e.node.rotation.y, atan2(face.x, face.z), 10.0 * d)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not grid.has(key): grid[key] = []
		grid[key].append(e)
		var py: float = game.player.global_position.y
		if dist < e.r + 0.45 and absf(py - p.y) < 1.4 and e.stun_t <= 0.0:
			if game.player.take_damage(e.dmg, false, p, ("un " + AFFIX_INFO[e.affix][0].to_lower() + " · " if e.affix != "" else "") + e.def["name"]):
				if e.affix == "vampire": e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.3)
				var eff: String = e.def.get("on_hit", "")
				if eff != "": game.player.apply_status(eff)
		if dist > 55.0 and not e.boss and not e.invincible:
			e.node.position = game.spawn_point(22.0, 30.0)
	# separation
	for key in grid:
		for e in grid[key]:
			for ox in range(-1, 2):
				for oz in range(-1, 2):
					var k2 := Vector2i(key.x + ox, key.y + oz)
					if not grid.has(k2): continue
					for o in grid[k2]:
						if o == e or o.level != e.level: continue
						var v: Vector3 = e.node.position - o.node.position
						v.y = 0
						var dd := v.length()
						var minr: float = e.r + o.r
						if dd < minr and dd > 0.0001 and not e.boss:
							e.node.position += v / dd * (minr - dd) * 0.5 * (0.3 if o.boss else 1.0)
	_update_hazards(d)

# ---------------------------------------------------------------- behaviours
func _ai_charger(e: Enemy, dir: Vector3, dist: float, d: float) -> Vector3:
	e.t_act -= d
	match e.phase:
		"":
			if e.t_act <= 0.0 and dist < 14.0 and dist > 3.0:
				e.phase = "aim"; e.t_act = 0.7
				e.dash_dir = dir
				_telegraph_line(e.node.position, dir, 12.0, 0.7)
			return dir
		"aim":
			if e.t_act <= 0.0: e.phase = "dash"; e.t_act = 0.55
			return dir
		"dash":
			if e.t_act <= 0.0: e.phase = ""; e.t_act = randf_range(2.5, 4.0)
			return e.dash_dir
	return dir

func _ai_ranged(e: Enemy, dir: Vector3, dist: float, d: float, keep: float, cd: float) -> Vector3:
	e.t_act -= d
	if e.t_act <= 0.0 and dist < 20.0:
		e.t_act = cd + randf_range(-0.3, 0.3)
		_shoot(e.node.position + Vector3(0, 1.1, 0), dir, e.dmg, e.def.get("shot", ""))
	if dist < keep - 2.0: return -dir
	if dist > keep + 2.0: return dir
	return Vector3(-dir.z, 0, dir.x) * 0.6
func _ai_lobber(e: Enemy, dir: Vector3, dist: float, d: float) -> Vector3:
	e.t_act -= d
	if e.t_act <= 0.0 and dist < 18.0:
		e.t_act = randf_range(3.5, 4.5)
		var target: Vector3 = game.player.global_position + game.player.velocity * 0.5
		target.y = 0
		_lob(e.node.position + Vector3(0, 1.5, 0), target, e.dmg)
	if dist < 9.0: return -dir
	if dist > 14.0: return dir
	return Vector3.ZERO

func _ai_summoner(e: Enemy, dir: Vector3, dist: float, d: float) -> Vector3:
	e.t_act -= d
	if e.t_act <= 0.0 and dist < 24.0:
		e.t_act = 6.0
		var m: Array = game.mults()
		for i in 3:
			var a := randf() * TAU
			spawn("stagiaire", game.world.resolve(e.node.position + Vector3(cos(a), 0, sin(a)) * 1.5, 0.5), m[0], m[1])
		_heal_fx(e.node.position)
	if dist < 10.0: return -dir
	return dir * 0.6

func _ai_slammer(e: Enemy, dir: Vector3, dist: float, d: float) -> Vector3:
	e.t_act -= d
	match e.phase:
		"":
			if e.t_act <= 0.0 and dist < 5.0:
				e.phase = "wind"; e.t_act = 0.9
				_telegraph_circle(e.node.position, 4.0, 0.9)
			return dir
		"wind":
			if e.t_act <= 0.0:
				e.phase = ""; e.t_act = 4.0
				_slam(e.node.position, 4.0, e.dmg * 1.4)
			return Vector3.ZERO
	return dir

func _ai_boss(e: Enemy, dir: Vector3, dist: float, d: float) -> Vector3:
	e.t_act -= d
	match e.phase:
		"":
			if e.t_act <= 0.0:
				if dist < 22.0 and randf() < 0.6:
					e.phase = "aim"; e.t_act = 0.9; e.dash_dir = dir
					_telegraph_line(e.node.position, dir, 18.0, 0.9)
					game.toast("Le Directeur charge !", 1.0)
				else:
					e.t_act = randf_range(3.0, 5.0)
					for i in 6:
						var a := TAU * i / 6.0
						_lob(e.node.position + Vector3(0, 4, 0), game.player.global_position + Vector3(cos(a), 0, sin(a)) * 5.0, e.dmg * 0.4)
			return dir
		"aim":
			if e.t_act <= 0.0: e.phase = "dash"; e.t_act = 0.8
			return dir
		"dash":
			if e.t_act <= 0.0: e.phase = ""; e.t_act = randf_range(3.5, 5.5)
			return e.dash_dir
	return dir

# ---------------------------------------------------------------- hazards
func _shoot(from: Vector3, dir: Vector3, dmg: float, effect: String):
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	U.sphere(n, 0.2, Vector3.ZERO, U.solid(Color(1.0, 0.95, 0.7), 4.0))
	U.sprite(n, "flare_01.png" if ResourceLoader.exists("res://fx/flare_01.png") else "light_01.png", Vector3.ZERO, 0.9, Color(1, 0.9, 0.6), 2.0)
	hazards.append({"t": "shot", "n": n, "v": dir * 11.0, "life": 2.5, "dmg": dmg, "eff": effect})

func _lob(from: Vector3, to: Vector3, dmg: float):
	to = game.world.resolve(to, 0.3)
	var tele := _telegraph_circle(to, 2.4, 1.0)
	var n := Node3D.new()
	add_child(n)
	n.global_position = from
	U.cyl(n, 0.3, 0.45, Vector3.ZERO, U.solid(Color(0.3, 0.45, 0.25), 0.0, 0.8))
	U.label(n, "$", Vector3(0, 0, 0.32), 48, Color(1, 0.85, 0.3), Color(0, 0, 0, 1), false)
	hazards.append({"t": "lob", "n": n, "from": from, "to": to, "age": 0.0, "dur": 1.0, "dmg": dmg})

func _debt_zone(p: Vector3, dmg: float):
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	U.sprite(root, "circle_05.png", Vector3(0, 0.05, 0), 5.0, Color(0.3, 0.8, 0.3, 0.5), 1.6, false, Vector3(-PI / 2, 0, 0))
	hazards.append({"t": "zone", "n": root, "life": 4.0, "r": 2.4, "dmg": dmg, "tick": 0.0})

func _telegraph_circle(p: Vector3, r: float, dur: float) -> Node3D:
	var s := U.sprite(self, "circle_03.png", Vector3(p.x, 0.06, p.z), r * 2.0, Color(1, 0.15, 0.1, 0.8), 2.0, false, Vector3(-PI / 2, 0, 0))
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.05, dur)
	tw.tween_callback(s.queue_free)
	return s

func _telegraph_line(p: Vector3, dir: Vector3, length: float, dur: float):
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(1.2, length)
	m.mesh = q
	m.material_override = U.solid(Color(1, 0.15, 0.1, 0.35), 1.5)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = Vector3(p.x, 0.07, p.z) + dir * length * 0.5
	m.rotation.y = atan2(dir.x, dir.z)
	var tw := m.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(m.queue_free)

func _slam(p: Vector3, r: float, dmg: float):
	var v: Vector3 = game.player.global_position - p
	v.y = 0
	if v.length() < r and game.player.global_position.y < 1.5:
		game.player.take_damage(dmg, false, p, "le coup de zone d'un Actionnaire")
		game.player.velocity += v.normalized() * 12.0 + Vector3(0, 6, 0)
	var s := U.sprite(self, "circle_05.png", Vector3(p.x, 0.07, p.z), r * 2.2, Color(1, 0.5, 0.2, 0.7), 2.5, false, Vector3(-PI / 2, 0, 0))
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.3, 0.25)
	tw.tween_callback(s.queue_free)
	game.shake(0.15)

func _explode(p: Vector3, dmg: float):
	_telegraph_circle(p, 2.8, 0.7)
	get_tree().create_timer(0.7, false).timeout.connect(func():
		var v: Vector3 = game.player.global_position - p
		v.y = 0
		if v.length() < 2.8: game.player.take_damage(dmg, false, p, "l'explosion d'un Crypto-bro")
		for o in in_radius(p, 2.8):
			damage(o, dmg * 2.0, p, 8.0)
		var s := U.sprite(self, "star_04.png", p + Vector3(0, 0.8, 0), 5.5, Color(0.4, 1.0, 0.5), 3.0)
		var tw := s.create_tween()
		tw.tween_property(s, "scale", Vector3.ONE * 0.1, 0.3)
		tw.tween_callback(s.queue_free)
		game.shake(0.12))

func _heal_fx(p: Vector3):
	var s := U.sprite(self, "magic_02.png" if ResourceLoader.exists("res://fx/magic_02.png") else "spark_04.png", p + Vector3(0, 1.2, 0), 1.2, Color(0.3, 1, 0.4), 2.5)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", p.y + 2.4, 0.5)
	tw.tween_callback(s.queue_free)

func _update_hazards(d: float):
	var pp: Vector3 = game.player.global_position + Vector3(0, 1.0, 0)
	for h in hazards.duplicate():
		var n: Node3D = h["n"]
		match h["t"]:
			"shot":
				n.global_position += h["v"] * d
				h["life"] -= d
				if n.global_position.distance_to(pp) < 0.75:
					if game.player.take_damage(h["dmg"], false, n.global_position, "un tir d'Influenceur") and h["eff"] != "":
						game.player.apply_status(h["eff"])
					h["life"] = 0.0
				if h["life"] <= 0.0:
					hazards.erase(h); n.queue_free()
			"lob":
				h["age"] += d
				var k: float = clampf(h["age"] / h["dur"], 0.0, 1.0)
				var pos: Vector3 = h["from"].lerp(h["to"], k)
				pos.y = lerpf(h["from"].y, 0.2, k) + sin(k * PI) * 4.0
				n.global_position = pos
				n.rotation.x += d * 8.0
				if k >= 1.0:
					hazards.erase(h); n.queue_free()
					_debt_zone(h["to"], h["dmg"])
			"zone":
				h["life"] -= d
				h["tick"] -= d
				var v: Vector3 = game.player.global_position - n.global_position
				v.y = 0
				if v.length() < h["r"] and game.player.global_position.y < 1.0:
					game.player.apply_status("debt")
					if h["tick"] <= 0.0:
						h["tick"] = 0.5
						game.player.take_damage(h["dmg"], true, n.global_position, "une zone de Dette")
				if h["life"] <= 0.0:
					hazards.erase(h); n.queue_free()

# ---------------------------------------------------------------- damage
func damage(e: Enemy, amount: float, knock_from := Vector3.INF, knock_force := 0.0, src := "", show_num := true, ignore_armor := false, crit_chance := 0.05, wid := ""):
	if not e.alive: return
	if src != "":
		var now := Time.get_ticks_msec() / 1000.0
		if e.hit_from.get(src, -10.0) > now: return
	if e.invincible:
		if knock_from != Vector3.INF:
			var kv0: Vector3 = e.node.position - knock_from; kv0.y = 0
			e.knock = kv0.normalized() * knock_force * 0.3
		return
	var crit := randf() < crit_chance
	var amt: float = amount * ((2.0 + game.mods.get("crit_dmg", 0.0) / 100.0) if crit else 1.0)
	if e.vuln_t > 0.0: amt *= 1.5
	if wid != "": e.last_w = wid
	if not ignore_armor:
		amt = maxf(amt - e.armor, amt * 0.15)
	if e.shielded: amt *= 0.6
	e.hp -= amt
	if show_num or crit:
		game.damage_number(e.node.position + Vector3(0, e.def["h"] + 0.3, 0), amt, crit, e.armor > 0.0 and not ignore_armor and amt < amount * 0.6)
	if knock_from != Vector3.INF and not e.boss and e.ai != "slammer":
		var kv: Vector3 = e.node.position - knock_from
		kv.y = 0
		e.knock = kv.normalized() * knock_force * (0.35 if e.elite else (0.5 if e.affix != "" or e.ai == "slammer" else 1.0))
	if e.hp <= 0.0:
		kill(e)

# stun with diminishing returns; big enemies are stunned less and recover immunity longer
func stun(e: Enemy, dur: float, force := false):
	if not e.alive or e.invincible: return
	if e.boss and not force: return
	if e.stun_imm > 0.0 and not force: return
	var big: bool = e.elite or e.boss or e.ai == "slammer" or e.affix != ""
	var dd := dur * (0.4 if big else 1.0)
	e.stun_t = maxf(e.stun_t, dd)
	e.stun_imm = dd + (4.0 if big else 1.5)

func set_hit_cd(e: Enemy, src: String, cd: float):
	e.hit_from[src] = Time.get_ticks_msec() / 1000.0 + cd

func kill(e: Enemy):
	if not e.alive: return
	e.alive = false
	list.erase(e)
	if e.affix == "diviseur" and not game.warming:
		var m: Array = game.mults()
		for i in 2:
			var c := spawn(e.kind, game.world.resolve(e.node.position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), e.r), m[0] * 0.4, m[1])
			c.node.scale = c.node.get_meta("base_scale") * 0.75
			c.affix = ""
	if e.affix_fx:
		e.affix_fx.queue_free(); e.affix_fx = null
	if e.def.has("explode"):
		_explode(e.node.position, e.def["explode"] * game.mults()[1])
	game.on_enemy_killed(e)
	if e.ap and e.ap.has_animation(Chars.ENEMY_ANIMS["death"]) and dying.size() < 50 and not game.warming:
		e.ap.play(Chars.ENEMY_ANIMS["death"], 0.05)
		e.ap.speed_scale = 1.8
		dying.append({"e": e, "t": 0.0})
	else:
		_pool(e)

func _pool(e: Enemy):
	var n := e.node
	var tw := create_tween()
	tw.tween_property(n, "scale", n.scale * 0.05, 0.14)
	tw.tween_callback(func():
		n.visible = false
		if not pools.has(e.kind): pools[e.kind] = []
		pools[e.kind].append(e))

# dead enemies play their death animation, stay a moment, then sink into the ground
func _update_dying(d: float):
	for dd in dying.duplicate():
		var e: Enemy = dd["e"]
		dd["t"] += d
		if e.ap: e.ap.advance(d)
		if dd["t"] > 0.9:
			e.node.position.y -= d * 2.5
		if dd["t"] > 1.5:
			dying.erase(dd)
			e.node.visible = false
			e.node.scale = e.node.get_meta("base_scale")
			if not pools.has(e.kind): pools[e.kind] = []
			pools[e.kind].append(e)

func nearest(pos: Vector3, max_d: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in _alive_cache:
		if e.invincible or exclude.has(e): continue
		var v: Vector3 = e.node.position - pos
		v.y = 0
		var dd := v.length_squared()
		if dd < bd:
			bd = dd; best = e
	return best

func in_radius(pos: Vector3, rad: float) -> Array:
	var out := []
	for e in _alive_cache:
		var v: Vector3 = e.node.position - pos
		v.y = 0
		if v.length() < rad + e.r: out.append(e)
	return out

func clear_all(except_boss := true):
	for e in _alive_cache.duplicate():
		if e.invincible: continue
		if except_boss and e.boss: continue
		kill(e)
	for h in hazards:
		h["n"].queue_free()
	hazards.clear()
