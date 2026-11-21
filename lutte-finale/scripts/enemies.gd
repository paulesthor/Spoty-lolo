extends Node3D
# Enemy manager: pooled capitalists chasing the player, with separation and obstacle avoidance.

class Enemy:
	var node: Node3D
	var kind := ""
	var hp := 1.0
	var max_hp := 1.0
	var speed := 3.0
	var dmg := 5.0
	var r := 0.5
	var xp := 1
	var elite := false
	var boss := false
	var invincible := false
	var alive := false
	var knock := Vector3.ZERO
	var ap: AnimationPlayer
	var tag: Label3D
	var dash_t := 0.0
	var dash_cd := 5.0
	var dash_dir := Vector3.ZERO
	var hit_from := {}  # weapon hit cooldowns

var game
var list: Array = []
var pools := {}
var gold_mat: StandardMaterial3D
var boss_mat: StandardMaterial3D
var _alive_cache: Array = []

func setup(g):
	game = g
	gold_mat = U.solid(Color(1.0, 0.72, 0.2), 0.0, 0.25, 1.0)
	boss_mat = U.solid(Color(0.16, 0.16, 0.2), 0.0, 0.5, 0.2)

func alive_list() -> Array:
	return _alive_cache

func count() -> int:
	return _alive_cache.size()

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
		var models: Array = def["models"]
		e.node = U.place(self, U.CH + models[randi() % models.size()] + ".glb", pos, def["h"], 0.0)
		e.node.set_meta("base_scale", e.node.scale)
		U.shrink_head(e.node)
		var acc: Array = def["acc"].duplicate()
		if kind == "cadre" and randf() < 0.45: acc = []
		if kind == "cadre" and randf() < 0.3: acc.append("cigar")
		if kind == "stagiaire" and randf() < 0.15: acc = ["sunglasses"]
		if not acc.is_empty(): U.attach_head(e.node, acc)
		if kind == "golden" or kind == "boss":
			var mat := gold_mat if kind == "golden" else boss_mat
			for m in e.node.find_children("*", "MeshInstance3D", true, false):
				if m.get_parent() is BoneAttachment3D or m.get_parent().get_parent() is BoneAttachment3D: continue
				if m.name == "head-mesh" and kind == "boss": continue
				(m as MeshInstance3D).material_override = mat
		if def.get("elite", false) or def.get("boss", false) or def.get("invincible", false):
			e.tag = U.label(e.node, def["name"].to_upper(), Vector3(0, 0, 0), 56, Color(1, 0.82, 0.3) if not def.get("invincible", false) else Color(0.6, 0.8, 1), Color(0.05, 0.03, 0, 1))
			e.tag.position = Vector3(0, def["h"] / e.node.scale.y + 0.3 / e.node.scale.y, 0)
			e.tag.pixel_size = 0.01 / e.node.scale.y
		e.ap = U.anim_player(e.node)
	e.hp = def["hp"] * hp_mult
	e.max_hp = e.hp
	e.speed = def["speed"] * randf_range(0.92, 1.08)
	e.dmg = def["dmg"] * dmg_mult
	e.r = def["r"]
	e.xp = def["xp"]
	e.elite = def.get("elite", false)
	e.boss = def.get("boss", false)
	e.invincible = def.get("invincible", false)
	e.alive = true
	e.knock = Vector3.ZERO
	e.dash_t = 0.0
	e.dash_cd = 5.0
	e.hit_from.clear()
	if e.ap:
		e.ap.play("walk" if not e.boss else "walk", 0.0)
		e.ap.seek(randf() * e.ap.current_animation_length, true)
		e.ap.speed_scale = e.speed / 3.0
	list.append(e)
	return e

func _process(d: float):
	if game == null: return
	d = minf(d, 0.05)
	_alive_cache.clear()
	for e in list:
		if e.alive: _alive_cache.append(e)
	if game.state != "play": return
	var pp: Vector3 = game.player.global_position
	var grid := {}
	const CELL := 1.6
	for e in _alive_cache:
		var p: Vector3 = e.node.position
		var to := Vector3(pp.x - p.x, 0, pp.z - p.z)
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)
		var spd: float = e.speed
		if e.boss:
			e.dash_cd -= d
			if e.dash_t > 0.0:
				e.dash_t -= d
				dir = e.dash_dir
				spd *= 4.0
			elif e.dash_cd <= 0.0 and dist < 22.0:
				e.dash_t = 0.8
				e.dash_cd = randf_range(4.5, 7.0)
				e.dash_dir = dir
				game.toast("Le Directeur charge !", 1.2)
		p += dir * spd * d + e.knock * d
		e.knock = e.knock.move_toward(Vector3.ZERO, 30.0 * d)
		if not e.invincible:
			p = game.world.resolve(p, e.r)
		p.y = 0.0
		e.node.position = p
		if dist > 0.1:
			e.node.rotation.y = lerp_angle(e.node.rotation.y, atan2(dir.x, dir.z), 10.0 * d)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not grid.has(key): grid[key] = []
		grid[key].append(e)
		# contact damage
		var py: float = game.player.global_position.y
		if dist < e.r + 0.45 and py < 1.4:
			game.player.take_damage(e.dmg)
		# keep pressure: recycle stragglers far away
		if dist > 48.0 and not e.boss and not e.invincible:
			e.node.position = game.spawn_point(22.0, 28.0)
	# separation
	for key in grid:
		var cell: Array = grid[key]
		for e in cell:
			for ox in range(-1, 2):
				for oz in range(-1, 2):
					var k2 := Vector2i(key.x + ox, key.y + oz)
					if not grid.has(k2): continue
					for o in grid[k2]:
						if o == e: continue
						var v: Vector3 = e.node.position - o.node.position
						v.y = 0
						var dd := v.length()
						var minr: float = e.r + o.r
						if dd < minr and dd > 0.0001:
							var push := v / dd * (minr - dd) * 0.5
							if not e.boss: e.node.position += push * (0.3 if o.boss else 1.0)

func damage(e: Enemy, amount: float, knock_from := Vector3.INF, knock_force := 0.0, src := "", show_num := true):
	if not e.alive: return
	if src != "":
		var now := Time.get_ticks_msec() / 1000.0
		if e.hit_from.get(src, -10.0) > now: return
	if e.invincible:
		if knock_from != Vector3.INF:
			var kv0: Vector3 = e.node.position - knock_from; kv0.y = 0
			e.knock = kv0.normalized() * knock_force * 0.3
		return
	var crit := randf() < 0.08
	var amt := amount * (2.0 if crit else 1.0)
	e.hp -= amt
	if show_num or crit:
		game.damage_number(e.node.position + Vector3(0, Data.ENEMIES[e.kind]["h"] + 0.3, 0), amt, crit)
	if knock_from != Vector3.INF and not e.boss:
		var kv: Vector3 = e.node.position - knock_from
		kv.y = 0
		e.knock = kv.normalized() * knock_force * (0.35 if e.elite else 1.0)
	if e.hp <= 0.0:
		kill(e)

func set_hit_cd(e: Enemy, src: String, cd: float):
	e.hit_from[src] = Time.get_ticks_msec() / 1000.0 + cd

func kill(e: Enemy):
	e.alive = false
	list.erase(e)
	game.on_enemy_killed(e)
	var n := e.node
	var tw := create_tween()
	tw.tween_property(n, "scale", n.scale * 0.05, 0.14)
	tw.tween_callback(func():
		n.visible = false
		if not pools.has(e.kind): pools[e.kind] = []
		pools[e.kind].append(e))

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
