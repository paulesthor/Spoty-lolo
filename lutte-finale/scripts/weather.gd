extends Node3D
# Weather events for the zone: tornadoes, smog, thunderstorm (inspired by Megabonk's desert).

var game
var kind := ""
var t := 0.0
var next_at := 150.0
var force := ""
var tornadoes: Array = []
var strike_t := 0.0
var base_fog := 0.004

func setup(g):
	game = g
	for a in OS.get_cmdline_user_args():
		if a.begins_with("weather="): force = a.substr(8); next_at = 0.0
	base_fog = game.world.env.fog_density

func _process(d: float):
	if game == null or game.state != "play": return
	d = minf(d, 0.05)
	if kind == "":
		if game.time >= next_at and not game.krach:
			_start(force if force != "" else ["tornades", "smog", "orage"][randi() % 3])
		return
	t -= d
	match kind:
		"tornades": _update_tornadoes(d)
		"orage": _update_storm(d)
	if t <= 0.0: _stop()

func _start(k: String):
	kind = k
	t = 30.0 if k != "smog" else 25.0
	match k:
		"tornades":
			game.toast("MÉTÉO · TORNADES DE CADDIES ! ÉLOIGNE-TOI DES TOURBILLONS", 3.0)
			for i in 2 + int(game.time / 240.0):
				var p: Vector3 = game.spawn_point(14.0, 22.0)
				tornadoes.append(_make_tornado(p))
		"smog":
			game.toast("MÉTÉO · PIC DE POLLUTION ! LA VISIBILITÉ CHUTE", 3.0)
			var tw := create_tween()
			tw.tween_property(game.world.env, "fog_density", 0.045, 3.0)
			game.world.env.fog_light_color = Color(0.55, 0.5, 0.4)
		"orage":
			game.toast("MÉTÉO · ORAGE ! LA FOUDRE FRAPPE (CERCLES ROUGES)", 3.0)
			strike_t = 1.0

func _stop():
	match kind:
		"tornades":
			for tn in tornadoes: tn["n"].queue_free()
			tornadoes.clear()
		"smog":
			var tw := create_tween()
			tw.tween_property(game.world.env, "fog_density", base_fog, 3.0)
			game.world.env.fog_light_color = Color(0.8, 0.68, 0.58)
	kind = ""
	next_at = game.time + randf_range(110.0, 150.0)
	game.toast("LA MÉTÉO SE CALME", 1.5)

func _make_tornado(p: Vector3) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	for i in 7:
		var r := 0.6 + i * 0.45
		var sp := U.sprite(n, "twirl_01.png", Vector3(0, 0.5 + i * 1.1, 0), r * 2.6, Color(0.75, 0.7, 0.6, 0.55), 1.3)
		sp.name = "ring%d" % i
	for i in 3:
		var cart := U.place(n, U.SHOP + "shopping-cart.glb", p + Vector3(2, 2 + i * 2, 0), 1.0, 0.0)
		cart.name = "cart%d" % i
	return {"n": n, "vel": Vector3.ZERO, "tick": 0.0}

func _update_tornadoes(d: float):
	var pp: Vector3 = game.player.global_position
	var tm: float = Time.get_ticks_msec() / 1000.0
	for tn in tornadoes:
		var n: Node3D = tn["n"]
		var to := pp - n.global_position
		to.y = 0
		var wander := Vector3(sin(tm * 0.7 + n.get_instance_id()), 0, cos(tm * 0.5 + n.get_instance_id())) * 2.5
		tn["vel"] = tn["vel"].lerp(to.normalized() * 3.2 + wander, d * 0.8)
		n.global_position = game.world.resolve(n.global_position + tn["vel"] * d, 1.0)
		for i in 7:
			(n.get_node("ring%d" % i) as Node3D).rotation.y = tm * (3.0 + i)
		for i in 3:
			var a := tm * 2.5 + i * TAU / 3.0
			(n.get_node("cart%d" % i) as Node3D).position = Vector3(cos(a) * (1.5 + i), 1.5 + i * 2.0, sin(a) * (1.5 + i))
			(n.get_node("cart%d" % i) as Node3D).rotation = Vector3(tm * 2.0, tm * 3.0, 0)
		tn["tick"] -= d
		var dist := to.length()
		if dist < 3.2 and pp.y < 4.0:
			var tang := Vector3(-to.z, 0, to.x).normalized()
			game.player.velocity += (tang * 18.0 - to.normalized() * 6.0 + Vector3(0, 10.0, 0)) * d
			if tn["tick"] <= 0.0:
				tn["tick"] = 0.5
				game.player.take_damage(12.0 * game.mults()[1], false, n.global_position, "une tornade de caddies")
		for e in game.enemies.in_radius(n.global_position, 3.2):
			if e.boss or e.invincible: continue
			game.enemies.damage(e, 40.0 * d * game.mults()[0], n.global_position, 10.0, "", false, true)

func _update_storm(d: float):
	strike_t -= d
	if strike_t > 0.0: return
	strike_t = randf_range(0.5, 1.0)
	var p: Vector3 = game.player.global_position + Vector3(randf_range(-11, 11), 0, randf_range(-11, 11))
	if randf() < 0.3: p = game.player.global_position + game.player.velocity * 0.8
	p = game.world.resolve(Vector3(p.x, 0, p.z), 0.5)
	game.enemies._telegraph_circle(p, 2.4, 1.0)
	get_tree().create_timer(1.0, false).timeout.connect(func():
		var v: Vector3 = game.player.global_position - p
		v.y = 0
		if v.length() < 2.4: game.player.take_damage(25.0 * game.mults()[1], false, p, "la foudre")
		for e in game.enemies.in_radius(p, 2.4):
			if not e.boss and not e.invincible: game.enemies.damage(e, 250.0 * game.mults()[0], p, 8.0, "", true, true)
		var bolt := MeshInstance3D.new()
		var c := CylinderMesh.new(); c.top_radius = 0.15; c.bottom_radius = 0.3; c.height = 30.0
		bolt.mesh = c
		bolt.material_override = U.solid(Color(0.8, 0.9, 1.0), 10.0)
		add_child(bolt)
		bolt.global_position = p + Vector3(0, 15, 0)
		var fl := OmniLight3D.new(); fl.light_color = Color(0.7, 0.8, 1.0); fl.light_energy = 8.0; fl.omni_range = 18.0
		bolt.add_child(fl)
		var tw := bolt.create_tween()
		tw.tween_property(bolt, "scale", Vector3(0.1, 1, 0.1), 0.2)
		tw.tween_callback(bolt.queue_free)
		game.shake(0.12))
