extends Node3D
# Lutte Finale — prototype. Game loop for one zone ("Hypermarché").
# Test flags (after "--"): bot  speed=4  dur=600  shots=60  shotdir=res://proto_shots  seed=1

const ZONE_TIME := 600.0      # 10:00, then the Krach
const BOSS_TIME := 480.0      # 08:00
const CAM_OFFSET := Vector3(0, 7.5, 10.5)
const CAM_LOOK := Vector3(0, 0.3, -6.5)

var state := "menu"
var time := 0.0
var level := 1
var xp := 0
var rubles := 0
var kills := 0
var decrets := {}
var krach := false
var boss = null
var boss_spawned := false
var pending_levels := 0
var choice_source := ""

var world
var player
var enemies
var weapons
var hud
var cam_rig: Node3D
var cam: Camera3D
var shake_amt := 0.0
var cam_k := 1.0
var spawn_acc := 0.0
var next_wave := 60.0
var elite_times := [120.0, 240.0, 360.0, 450.0, 540.0]
var gems: Array = []
var coins: Array = []
var chests: Array = []
var chest_cost := 15
var statue_charge := 0.0
var statue_used := false
var statue_ring: MeshInstance3D
var dmg_labels: Array = []
var dmg_idx := 0
var rng := RandomNumberGenerator.new()

# test / bot
var bot := false
var warp := 0.0
var test_pos := Vector3.INF
var test_yaw := 0.0
var test_dur := 0.0
var shot_every := 0.0
var shot_t := 0.0
var shot_dir := "res://proto_shots"
var shot_n := 0
var log_t := 0.0
var choice_wait := 0.0
var shot_choice_done := false

func _ready():
	var seed_v := 1917
	for a in OS.get_cmdline_user_args():
		if a == "bot": bot = true
		elif a.begins_with("speed="): Engine.time_scale = float(a.substr(6))
		elif a.begins_with("dur="): test_dur = float(a.substr(4))
		elif a.begins_with("shots="): shot_every = float(a.substr(6))
		elif a.begins_with("shotdir="): shot_dir = a.substr(8)
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("warp="): warp = float(a.substr(5))
		elif a.begins_with("pos="):
			var xz := a.substr(4).split(",")
			test_pos = Vector3(float(xz[0]), 0, float(xz[1]))
		elif a.begins_with("yaw="): test_yaw = deg_to_rad(float(a.substr(4)))
	rng.seed = seed_v
	seed(seed_v)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	world = load("res://scripts/world.gd").new()
	add_child(world)
	world.build(seed_v)
	player = load("res://scripts/player.gd").new()
	add_child(player)
	player.setup(self)
	player.bot = bot
	player.landed.connect(_on_landed)
	enemies = load("res://scripts/enemies.gd").new()
	add_child(enemies)
	enemies.setup(self)
	weapons = load("res://scripts/weapons.gd").new()
	add_child(weapons)
	weapons.setup(self)
	weapons.add_weapon("marteau")
	for n in [world, player, enemies, weapons]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_camera()
	_setup_chests()
	_setup_statue()
	for i in 40:
		var l := U.label(self, "", Vector3(0, -100, 0), 64, Color.WHITE, Color(0.08, 0.04, 0.02, 1))
		l.visible = false
		dmg_labels.append(l)
	hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(self)
	hud.chosen.connect(_on_chosen)
	if bot:
		start()
		if warp > 0.0: _do_warp()
		if test_pos != Vector3.INF:
			player.global_position = test_pos
			player.cam_yaw = test_yaw
			player.bot = false
			cam_rig.global_position = test_pos
	else:
		_show_menu()

# debug: jump to a later moment of the zone with a plausible build (used for screenshots)
func _do_warp():
	time = warp
	while next_wave <= warp: next_wave += 60.0
	while not elite_times.is_empty() and elite_times[0] < warp: elite_times.pop_front()
	level = int(5 + warp / 20.0)
	var lv := clampi(int(warp / 70.0) + 1, 1, 8)
	for id in ["marteau", "kalach", "faucille", "molotov"]:
		for i in (lv if id != "marteau" else lv + 1):
			weapons.add_weapon(id)
		weapons.owned[id] = mini(weapons.owned[id], 8)
	decrets = {"productivite": 3, "cadence": 2, "endurance": 3, "vitesse": 2}
	player.max_hp = 175; player.hp = 150
	var m := _mults()
	for i in 110:
		enemies.spawn(["stagiaire", "cadre", "trader"][i % 3], spawn_point(6.0, 24.0), m[0], m[1])

func _setup_input():
	var acts := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "slide": [KEY_SHIFT, KEY_CTRL], "interact": [KEY_F, KEY_E],
		"cam_left": [KEY_Q], "cam_right": [KEY_R],
		"pause": [KEY_ESCAPE, KEY_P], "confirm": [KEY_ENTER, KEY_KP_ENTER],
		"choose_1": [KEY_1, KEY_KP_1], "choose_2": [KEY_2, KEY_KP_2], "choose_3": [KEY_3, KEY_KP_3],
		"restart": [KEY_BACKSPACE],
	}
	for a in acts:
		if not InputMap.has_action(a): InputMap.add_action(a, 0.2)
		for k in acts[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var pads := {"jump": JOY_BUTTON_A, "slide": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START, "confirm": JOY_BUTTON_A, "restart": JOY_BUTTON_BACK}
	for a in pads:
		var ev := InputEventJoypadButton.new(); ev.button_index = pads[a]
		InputMap.action_add_event(a, ev)
	var axes := [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0], ["cam_left", JOY_AXIS_RIGHT_X, -1.0], ["cam_right", JOY_AXIS_RIGHT_X, 1.0]]
	for ax in axes:
		var ev := InputEventJoypadMotion.new(); ev.axis = ax[1]; ev.axis_value = ax[2]
		InputMap.action_add_event(ax[0], ev)

func _setup_camera():
	cam_rig = Node3D.new()
	add_child(cam_rig)
	cam = Camera3D.new()
	cam.fov = 55
	cam_rig.add_child(cam)
	cam.position = CAM_OFFSET
	cam.basis = Basis.looking_at(CAM_LOOK - CAM_OFFSET, Vector3.UP)
	cam.make_current()

func _setup_chests():
	for p in world.chest_spots:
		_make_chest(p, false)

func _make_chest(p: Vector3, free: bool):
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	n.rotation.y = rng.randf() * TAU
	U.box(n, Vector3(1.2, 0.8, 0.8), Vector3(0, 0.4, 0), U.solid(Color(0.95, 0.68, 0.15), 0.0, 0.4, 0.6))
	U.box(n, Vector3(1.24, 0.12, 0.84), Vector3(0, 0.62, 0), U.solid(Color(0.35, 0.2, 0.1)))
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.8, 0.3); l.light_energy = 1.2; l.omni_range = 3.0; l.position = Vector3(0, 1.2, 0)
	n.add_child(l)
	var lab := U.label(n, "GRATUIT" if free else "", Vector3(0, 1.6, 0), 48, Color(1, 0.88, 0.4), Color(0, 0, 0, 1))
	chests.append({"n": n, "free": free, "label": lab})

func _setup_statue():
	statue_ring = MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 4.3; tm.outer_radius = 4.5
	statue_ring.mesh = tm
	statue_ring.scale = Vector3(1, 0.05, 1)
	statue_ring.material_override = U.solid(Color(1, 0.75, 0.15), 3.0)
	add_child(statue_ring)
	statue_ring.global_position = world.statue_pos + Vector3(0, 0.05, 0)
	U.label(self, "STATUE DU LEADER", world.statue_pos + Vector3(0, 8.2, 0), 64, Color(1, 0.85, 0.35), Color(0.1, 0, 0, 1))

# ---------------------------------------------------------------- flow
func _show_menu():
	state = "menu"
	hud.set_hud_visible(false)
	hud.show_screen("LUTTE FINALE",
		"Le capitalisme a gagné. Pas pour longtemps.\n\nDéplacement : ZQSD / flèches / stick gauche     Caméra : souris / A et R / stick droit\nSaut (double saut) : Espace / A     Glissade : Maj / B     Ouvrir un coffre : F / X\n\nTes armes tirent toutes seules. Survis, monte de niveau, bats le Directeur à 08:00.",
		"ENTRÉE ou A pour commencer", Color(0.9, 0.15, 0.15))

func start():
	state = "play"
	hud.hide_screen()
	hud.set_hud_visible(true)
	if not bot: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.toast("ZONE 1 · L'HYPERMARCHÉ", 2.5)

func _unhandled_input(ev: InputEvent):
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and state == "play":
		player.cam_yaw -= clampf(ev.relative.x, -60.0, 60.0) * 0.0025

func _process(d: float):
	var rd := minf(d, 0.05)
	match state:
		"menu":
			cam_rig.rotation.y += rd * 0.1
			cam_rig.global_position = player.global_position
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("jump"): start()
			return
		"over", "win":
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("restart"):
				get_tree().paused = false
				get_tree().reload_current_scene()
			_bot_tick(d)
			return
		"paused":
			if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("confirm"): _unpause()
			elif Input.is_action_just_pressed("restart"):
				get_tree().paused = false
				get_tree().reload_current_scene()
			return
		"choice":
			if bot:
				choice_wait -= d / maxf(Engine.time_scale, 0.001)
				if choice_wait <= 0.0: _on_chosen(0)
			_bot_tick(d)
			return
	# --- play
	if Input.is_action_just_pressed("pause"):
		_pause(); return
	time += rd
	var yaw_in := Input.get_axis("cam_left", "cam_right")
	player.cam_yaw -= yaw_in * 2.2 * rd
	_update_camera(rd)
	_director(rd)
	_update_pickups(rd)
	_update_chests(rd)
	_update_statue(rd)
	_bot_tick(d)

func _update_camera(d: float):
	if not player.global_position.is_finite() or not is_finite(player.cam_yaw):
		player.global_position = Vector3(0, 1, 0)
		player.velocity = Vector3.ZERO
		player.cam_yaw = 0.0
	player.cam_yaw = fmod(player.cam_yaw, TAU)
	var target: Vector3 = player.global_position
	target.y = lerpf(0.0, target.y, 0.6)
	cam_rig.global_position = cam_rig.global_position.lerp(target, 1.0 - exp(-10.0 * d))
	cam_rig.rotation.y = player.cam_yaw
	shake_amt = maxf(0.0, shake_amt - d * 1.5)
	# pull the camera in when a building is between it and the player
	var local := CAM_OFFSET
	var head: Vector3 = player.global_position + Vector3(0, 1.6, 0)
	var want: Vector3 = cam_rig.global_transform * CAM_OFFSET
	var q := PhysicsRayQueryParameters3D.create(head, want, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var k := 1.0
	if not hit.is_empty():
		k = clampf((head.distance_to(hit["position"]) - 0.8) / head.distance_to(want), 0.15, 1.0)
	cam_k = minf(k, cam_k + d * 2.0) if k > cam_k else k
	var pivot := Vector3(0, 1.6, 0)
	local = pivot + (CAM_OFFSET - pivot) * cam_k
	cam.position = local + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amt
	cam.basis = Basis.looking_at(CAM_LOOK.lerp(Vector3(0, 1.0, -3.0), 1.0 - cam_k) - local, Vector3.UP)

func shake(a: float):
	shake_amt = minf(0.5, shake_amt + a)

func _pause():
	state = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen("PAUSE", "Niveau %d · %d KO · %s" % [level, kills, _fmt(time)], "ÉCHAP pour reprendre · RETOUR ARRIÈRE pour recommencer")

func _unpause():
	state = "play"
	get_tree().paused = false
	hud.hide_screen()
	if not bot: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _fmt(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]

# ---------------------------------------------------------------- spawning
func spawn_point(min_d: float, max_d: float) -> Vector3:
	var pp: Vector3 = player.global_position
	for i in 12:
		var a := rng.randf() * TAU
		var dd := rng.randf_range(min_d, max_d)
		var p := Vector3(pp.x + cos(a) * dd, 0, pp.z + sin(a) * dd)
		if world.bounds.grow(-1.0).has_point(Vector2(p.x, p.z)):
			return world.resolve(p, 0.6)
	return world.resolve(Vector3(pp.x + min_d, 0, pp.z), 0.6)

func _mults() -> Array:
	var tm := time / 60.0
	return [1.0 + 0.3 * tm + 0.03 * tm * tm, 1.0 + 0.12 * tm]

func _director(d: float):
	var tm := time / 60.0
	var m := _mults()
	var cap := 220 if not krach else 280
	var rate := 1.6 + 0.9 * tm + 0.08 * tm * tm
	if krach: rate *= 2.2
	spawn_acc += rate * d
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if enemies.count() >= cap: break
		var r := rng.randf() * (6.0 + 2.0 * tm + (1.2 * tm if tm > 1.5 else 0.0))
		var kind := "stagiaire"
		if r > 6.0: kind = "cadre"
		if r > 6.0 + 2.0 * tm: kind = "trader"
		enemies.spawn(kind, spawn_point(20.0, 28.0), m[0], m[1])
	if time >= next_wave and time < ZONE_TIME:
		next_wave += 60.0
		var n := int(18 + tm * 4)
		hud.toast("VAGUE DE STAGIAIRES", 1.5)
		for i in n:
			if enemies.count() >= cap + 40: break
			var a := TAU * i / n
			var p: Vector3 = player.global_position + Vector3(cos(a), 0, sin(a)) * 17.0
			enemies.spawn("stagiaire", world.resolve(p, 0.5), m[0], m[1])
	if not elite_times.is_empty() and time >= elite_times[0]:
		elite_times.pop_front()
		enemies.spawn("golden", spawn_point(18.0, 22.0), m[0] * 0.8, m[1])
		hud.toast("UN GOLDEN BOY APPROCHE · IL TRANSPORTE UN COFFRE", 2.5)
	if not boss_spawned and time >= BOSS_TIME:
		boss_spawned = true
		boss = enemies.spawn("boss", spawn_point(20.0, 24.0), 1.0, 1.0)
		hud.toast("LE DIRECTEUR BLACK FRIDAY ARRIVE", 3.0)
		shake(0.4)
	if not krach and time >= ZONE_TIME:
		krach = true
		enemies.spawn("fisc", spawn_point(24.0, 28.0))
		hud.toast("LE KRACH · LE CONTRÔLEUR FISCAL TE TROUVERA", 3.5)

# ---------------------------------------------------------------- events
func on_enemy_killed(e):
	kills += 1
	spark(e.node.position + Vector3(0, 1.0, 0), true)
	var val: int = e.xp
	_drop_gem(e.node.position, val)
	if rng.randf() < 0.012:
		_drop_heal(e.node.position + Vector3(-0.5, 0, 0.3))
	if rng.randf() < 0.07 or e.elite:
		_drop_coin(e.node.position + Vector3(0.6, 0, 0), 30 if e.elite else rng.randi_range(2, 5))
	if e.elite:
		_make_chest(e.node.position + Vector3(-0.8, 0, 0), true)
		hud.toast("LE GOLDEN BOY A LÂCHÉ UN COFFRE", 2.0)
	if e.boss:
		_win()

func on_player_hit(amount: float):
	hud.hurt()
	shake(0.15)

func _on_landed(fall_speed: float):
	weapons.on_landed(fall_speed)

func decret_lv(id: String) -> int:
	return decrets.get(id, 0)

func damage_number(pos: Vector3, amt: float, crit: bool):
	var l: Label3D = dmg_labels[dmg_idx]
	dmg_idx = (dmg_idx + 1) % dmg_labels.size()
	if l.has_meta("tw"):
		var old: Tween = l.get_meta("tw")
		if old and old.is_valid(): old.kill()
	l.visible = true
	l.text = ("CRIT %d" if crit else "%d") % int(amt)
	l.modulate = Color(1, 0.3, 0.2, 1) if crit else Color(1, 1, 1, 1)
	l.outline_modulate = Color(0.08, 0.04, 0.02, 1)
	l.font_size = 64 if crit else 44
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", pos.y + 1.2, 0.55)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.chain().tween_callback(func(): l.visible = false)
	l.set_meta("tw", tw)

func spark(pos: Vector3, big := false):
	var s := U.sprite(self, "star_06.png" if big else "spark_04.png", pos, 1.6 if big else 0.8, Color(1, 0.2, 0.15) if big else Color(1, 0.8, 0.3), 3.0)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 0.1, 0.25)
	tw.tween_callback(s.queue_free)

func toast(t: String, dur := 2.0):
	hud.toast(t, dur)

# ---------------------------------------------------------------- pickups
func _drop_gem(p: Vector3, val: int):
	if gems.size() > 350:
		var g0: Dictionary = gems[rng.randi() % gems.size()]
		g0["v"] += val
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.16 + 0.04 * minf(val, 5); sm.height = sm.radius * 2.4; sm.radial_segments = 4; sm.rings = 2
	mi.mesh = sm
	mi.material_override = U.solid(Color(0.2, 0.95, 0.45) if val < 5 else Color(0.3, 0.6, 1.0), 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(p.x, 0.35, p.z)
	gems.append({"n": mi, "v": val, "pull": false, "spd": 0.0})

func _drop_coin(p: Vector3, val: int):
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 0.22; cy.bottom_radius = 0.22; cy.height = 0.06
	mi.mesh = cy
	mi.material_override = U.solid(Color(1, 0.78, 0.25), 1.2, 0.3, 1.0)
	mi.rotation.x = PI / 2
	add_child(mi)
	mi.global_position = Vector3(p.x, 0.4, p.z)
	coins.append({"n": mi, "v": val, "pull": false, "spd": 0.0})

func _drop_heal(p: Vector3):
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(p.x, 0.4, p.z)
	U.box(n, Vector3(0.5, 0.14, 0.4), Vector3.ZERO, U.solid(Color(0.85, 0.6, 0.3)))
	U.box(n, Vector3(0.44, 0.04, 0.34), Vector3(0, 0.09, 0), U.solid(Color(0.95, 0.2, 0.25), 0.6))
	coins.append({"n": n, "v": 0, "heal": 25.0, "pull": false, "spd": 0.0})

func nearest_gem(p: Vector3, maxd: float):
	var best = null
	var bd := maxd
	for g in gems:
		var dd: float = g["n"].global_position.distance_to(p)
		if dd < bd: bd = dd; best = g["n"].global_position
	return best

func _update_pickups(d: float):
	var pp: Vector3 = player.global_position + Vector3(0, 0.6, 0)
	var magnet := 4.0 * (1.0 + 0.4 * decret_lv("aimant"))
	var t := Time.get_ticks_msec() / 1000.0
	for arr in [gems, coins]:
		for g in arr.duplicate():
			var n: Node3D = g["n"]
			var v := pp - n.global_position
			var dist := v.length()
			if dist < magnet: g["pull"] = true
			if g["pull"]:
				g["spd"] = minf(g["spd"] + 40.0 * d, 30.0)
				n.global_position += v.normalized() * minf(g["spd"] * d, dist)
				if dist < 0.7:
					arr.erase(g)
					n.queue_free()
					if arr == gems: add_xp(g["v"])
					elif g.has("heal"):
						player.heal(g["heal"])
						hud.toast("TARTINE · +25 PV", 1.0)
					else:
						rubles += g["v"]
			else:
				n.rotation.y = t * 2.0
				n.position.y = 0.35 + sin(t * 3.0 + n.position.x) * 0.08

func add_xp(v: int):
	xp += int(ceil(v * (1.0 + 0.15 * decret_lv("propagande"))))
	while xp >= Data.xp_to_next(level):
		xp -= Data.xp_to_next(level)
		level += 1
		pending_levels += 1
	if pending_levels > 0 and state == "play":
		_open_levelup()

# ---------------------------------------------------------------- chests & statue
func _update_chests(d: float):
	var pp: Vector3 = player.global_position
	var near = null
	for c in chests:
		if c["n"].global_position.distance_to(pp) < 2.4: near = c
		if not c["free"]: c["label"].text = "%d RBL" % chest_cost
	if near == null:
		hud.prompt("")
	else:
		var cost := 0 if near["free"] else chest_cost
		hud.prompt("F / X : OUVRIR LE COFFRE" + ("" if cost == 0 else " (%d RBL)" % cost) + ("" if rubles >= cost else " · PAS ASSEZ DE ROUBLES"))
		if (Input.is_action_just_pressed("interact") or bot) and rubles >= cost:
			rubles -= cost
			if not near["free"]: chest_cost = int(chest_cost * 1.6) + 5
			chests.erase(near)
			near["n"].queue_free()
			hud.prompt("")
			var opts := _roll_options(1)
			if opts.is_empty():
				player.heal(40); hud.toast("COFFRE : +40 PV", 2.0)
			else:
				_apply(opts[0])
				hud.toast("COFFRE : " + opts[0]["title"] + " " + opts[0]["lv"], 2.5)
			shake(0.1)

func _update_statue(d: float):
	if statue_used: return
	var v: Vector3 = player.global_position - world.statue_pos
	v.y = 0
	if v.length() < 4.5 and player.is_on_floor():
		statue_charge += d / 5.0
		hud.prompt("STATUE DU LEADER · RESTE DANS LE CERCLE (%d %%)" % int(statue_charge * 100))
		if statue_charge >= 1.0:
			statue_used = true
			statue_ring.visible = false
			hud.prompt("")
			var opts := _roll_options(3)
			if not opts.is_empty():
				_open_choice("LE LEADER T'ACCORDE UNE FAVEUR", opts, "statue")
	else:
		statue_charge = maxf(0.0, statue_charge - d / 10.0)
	var m: StandardMaterial3D = statue_ring.material_override
	m.emission_energy_multiplier = 2.0 + statue_charge * 6.0

# ---------------------------------------------------------------- level-up / options
func _roll_options(n: int) -> Array:
	var pool := []
	for id in weapons.owned:
		var lv: int = weapons.owned[id]
		if lv < Data.MAX_WEAPON_LV:
			pool.append({"type": "weapon", "id": id, "lv_n": lv + 1, "w": 1.3})
	if weapons.owned.size() < Data.WEAPON_SLOTS:
		for id in Data.WEAPONS:
			if not weapons.owned.has(id):
				pool.append({"type": "weapon", "id": id, "lv_n": 1, "w": 1.6})
	for id in decrets:
		if decrets[id] < Data.DECRETS[id]["max"]:
			pool.append({"type": "decret", "id": id, "lv_n": decrets[id] + 1, "w": 1.0})
	if decrets.size() < Data.DECRET_SLOTS:
		for id in Data.DECRETS:
			if not decrets.has(id):
				pool.append({"type": "decret", "id": id, "lv_n": 1, "w": 0.8})
	var out := []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for o in pool: total += o["w"]
		var r := rng.randf() * total
		for o in pool:
			r -= o["w"]
			if r <= 0.0:
				out.append(o); pool.erase(o); break
	for o in out:
		if o["type"] == "weapon":
			var w: Dictionary = Data.WEAPONS[o["id"]]
			o["title"] = w["name"]
			o["tag"] = "NOUVELLE ARME" if o["lv_n"] == 1 else "ARME"
			o["lv"] = "Niveau %d" % o["lv_n"]
			o["desc"] = w["desc"] if o["lv_n"] == 1 else Data.weapon_level_text(o["id"], o["lv_n"])
		else:
			var dd: Dictionary = Data.DECRETS[o["id"]]
			o["title"] = dd["name"]
			o["tag"] = "NOUVEAU DÉCRET" if o["lv_n"] == 1 else "DÉCRET"
			o["lv"] = "Niveau %d / %d" % [o["lv_n"], dd["max"]]
			o["desc"] = dd["desc"]
	return out

func _open_levelup():
	var opts := _roll_options(3)
	if opts.is_empty():
		pending_levels = 0
		player.heal(30)
		return
	_open_choice("NIVEAU %d · LE PARTI TE RÉCOMPENSE" % (level - pending_levels + 1), opts, "level")

func _open_choice(title: String, opts: Array, source: String):
	state = "choice"
	choice_source = source
	choice_wait = 0.4
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_choices(title, opts)
	if bot and shot_every > 0.0 and not shot_choice_done:
		shot_choice_done = true
		await get_tree().process_frame
		await get_tree().process_frame
		_screenshot()

func _on_chosen(i: int):
	if state != "choice": return
	var o: Dictionary = hud.options[i]
	_apply(o)
	hud.hide_choices()
	if choice_source == "level":
		pending_levels -= 1
	if pending_levels > 0:
		_open_levelup()
		return
	state = "play"
	get_tree().paused = false
	if not bot: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply(o: Dictionary):
	if o["type"] == "weapon":
		weapons.add_weapon(o["id"])
	else:
		decrets[o["id"]] = decrets.get(o["id"], 0) + 1
		if o["id"] == "endurance":
			player.max_hp += 25
			player.heal(25)

# ---------------------------------------------------------------- end
func game_over():
	if state == "over": return
	state = "over"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen("TU ES MORT",
		"Officiellement, tu n'as jamais existé.\n\nTemps : %s   ·   Niveau %d   ·   %d capitalistes bonkés   ·   %d roubles" % [_fmt(time), level, kills, rubles],
		"ENTRÉE ou A pour recommencer", Color(0.85, 0.15, 0.15))
	print("[game] GAME OVER t=%s level=%d kills=%d" % [_fmt(time), level, kills])

func _win():
	state = "win"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen("ZONE NETTOYÉE",
		"Le Directeur Black Friday a été bonké. L'Hypermarché appartient au peuple.\n\nTemps : %s   ·   Niveau %d   ·   %d capitalistes bonkés\n\n(Prototype : les zones 2 et 3 arrivent ensuite.)" % [_fmt(time), level, kills],
		"ENTRÉE ou A pour rejouer", Color(0.95, 0.75, 0.25))
	print("[game] WIN t=%s level=%d kills=%d" % [_fmt(time), level, kills])

# ---------------------------------------------------------------- automated test hooks
func _bot_tick(d: float):
	if not bot: return
	var real := d / maxf(Engine.time_scale, 0.001)
	log_t += d
	if log_t >= 10.0:
		log_t = 0.0
		print("[bot] t=%s lvl=%d hp=%d/%d kills=%d enemies=%d fps=%d weapons=%s decrets=%s state=%s" % [_fmt(time), level, player.hp, player.max_hp, kills, enemies.count(), Engine.get_frames_per_second(), str(weapons.owned), str(decrets), state])
	if shot_every > 0.0:
		shot_t += d
		if shot_t >= shot_every:
			shot_t = 0.0
			_screenshot()
	if test_dur > 0.0 and (time >= test_dur or state in ["over", "win"]):
		if state in ["over", "win"]:
			_screenshot()
		print("[bot] END state=%s t=%s lvl=%d kills=%d" % [state, _fmt(time), level, kills])
		get_tree().quit()

func _screenshot():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	var path := "%s/shot_%03d_%s.png" % [shot_dir, shot_n, state]
	img.save_png(path)
	shot_n += 1
