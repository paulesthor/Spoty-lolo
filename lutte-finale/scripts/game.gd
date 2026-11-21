extends Node3D
# Lutte Finale — prototype. Game loop for one zone ("Hypermarché").
# Test flags (after "--"): bot  speed=4  dur=600  shots=60  shotdir=res://proto_shots  seed=1  warp=300  pos=x,z yaw=deg

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
var decrets := {}          # id -> {"n": picks, "v": accumulated value}
var krach := false
var boss = null
var boss_spawned := false
var pending_levels := 0
var choice_source := ""
var choice_ctx = null
var bets := 0              # Bourse aux paris accepted
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
var elite_times := [120.0, 240.0, 330.0, 420.0, 540.0]
var next_event := 85.0
var event_name := ""
var event_t := 0.0
var gems: Array = []
var coins: Array = []
var chests: Array = []
var chest_cost := 12
var shrines: Array = []
var breakables: Array = []
var market_buys := 0
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
	_setup_map_objects()
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

func dv(id: String) -> float:
	return decrets[id]["v"] if decrets.has(id) else 0.0

func decret_lv(id: String) -> int:
	return decrets[id]["n"] if decrets.has(id) else 0

# debug: jump to a later moment of the zone with a plausible build (used for screenshots/tests)
func _do_warp():
	time = warp
	while next_wave <= warp: next_wave += 60.0
	while not elite_times.is_empty() and elite_times[0] < warp: elite_times.pop_front()
	next_event = warp + 10.0
	level = int(4 + warp / 30.0)
	var ups := int(warp / 60.0)
	for id in ["kalach", "molotov", "matriochka"]:
		weapons.add_weapon(id)
	for id in weapons.owned:
		for i in ups:
			weapons.upgrade(id, {"dmg": 0.2, "cd": 0.06})
	for id in ["productivite", "cadence", "endurance", "expansion"]:
		for i in maxi(1, ups / 2):
			_apply({"kind": "decret", "id": id, "rarity": 1})
	var m := mults()
	for i in 100:
		enemies.spawn(_pick_kind(), spawn_point(8.0, 26.0), m[0], m[1])

func _setup_input():
	var acts := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "slide": [KEY_SHIFT, KEY_CTRL], "interact": [KEY_F, KEY_E],
		"cam_left": [KEY_Q], "cam_right": [KEY_R],
		"pause": [KEY_ESCAPE, KEY_P], "confirm": [KEY_ENTER, KEY_KP_ENTER],
		"choose_1": [KEY_1, KEY_KP_1], "choose_2": [KEY_2, KEY_KP_2], "choose_3": [KEY_3, KEY_KP_3], "choose_4": [KEY_4, KEY_KP_4],
		"restart": [KEY_BACKSPACE],
	}
	for a in acts:
		if not InputMap.has_action(a): InputMap.add_action(a, 0.2)
		for k in acts[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var pads := {"jump": JOY_BUTTON_A, "slide": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START, "confirm": JOY_BUTTON_A, "restart": JOY_BUTTON_BACK, "choose_4": JOY_BUTTON_Y}
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
	cam.far = 400.0
	cam_rig.add_child(cam)
	cam.position = CAM_OFFSET
	cam.basis = Basis.looking_at(CAM_LOOK - CAM_OFFSET, Vector3.UP)
	cam.make_current()

# ---------------------------------------------------------------- map objects
func _beam(parent: Node3D, col: Color, h := 30.0):
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = 0.35; c.bottom_radius = 0.35; c.height = h
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, h / 2.0, 0)
	parent.add_child(m)
	return m

func _setup_map_objects():
	for p in world.chest_spots:
		_make_chest(p, false)
	var kinds := ["statue", "file", "statue", "pari", "goulag", "marche", "aimant", "defi", "file"]
	for i in world.shrine_spots.size():
		_make_shrine(kinds[i % kinds.size()], world.shrine_spots[i])
	for p in world.breakable_spots:
		_make_breakable(p)

func _make_chest(p: Vector3, free: bool, rarity_bonus := 0):
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	n.rotation.y = rng.randf() * TAU
	U.box(n, Vector3(1.2, 0.8, 0.8), Vector3(0, 0.4, 0), U.solid(Color(0.95, 0.68, 0.15) if rarity_bonus == 0 else Color(0.75, 0.4, 1.0), 0.0, 0.4, 0.6))
	U.box(n, Vector3(1.24, 0.12, 0.84), Vector3(0, 0.62, 0), U.solid(Color(0.35, 0.2, 0.1)))
	_beam(n, Color(1, 0.8, 0.3) if rarity_bonus == 0 else Color(0.8, 0.5, 1.0), 14.0)
	var lab := U.label(n, "GRATUIT" if free else "", Vector3(0, 1.6, 0), 48, Color(1, 0.88, 0.4), Color(0, 0, 0, 1))
	chests.append({"n": n, "free": free, "label": lab, "bonus": rarity_bonus})

const SHRINE_INFO := {
	"statue": ["STATUE DU LEADER", Color(1, 0.75, 0.15), "Reste dans le cercle 5 s : une faveur rare ou mieux."],
	"file": ["FILE D'ATTENTE", Color(0.4, 0.7, 1.0), "Défi : tiens 20 s dans le cercle pendant l'assaut. Récompense : coffre épique."],
	"pari": ["BOURSE AUX PARIS", Color(0.3, 1.0, 0.4), "Ennemis +20 % de PV pour toute la zone, mais +35 % d'XP et de roubles."],
	"goulag": ["GOULAG", Color(0.6, 0.6, 0.7), "Sacrifie 20 PV max. En échange : une amélioration épique ou légendaire."],
	"marche": ["MARCHÉ NOIR", Color(0.9, 0.5, 1.0), "Achète une amélioration avec tes roubles."],
	"aimant": ["DISTRIBUTEUR DE PROPAGANDE", Color(0.2, 0.95, 0.5), "Attire toute l'XP de la carte."],
	"defi": ["OPA HOSTILE", Color(1.0, 0.85, 0.3), "Défi : 3 Golden Boys arrivent. Chacun lâche un coffre."],
}

func _make_shrine(kind: String, p: Vector3):
	var info: Array = SHRINE_INFO[kind]
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var col: Color = info[1]
	match kind:
		"statue":
			U.box(n, Vector3(3, 2.2, 3), Vector3(0, 1.1, 0), U.solid(Color(0.55, 0.52, 0.5)))
			var st := U.place(n, U.CH + "character-male-b.glb", p + Vector3(0, 2.2, 0), 5.2, 0.4)
			U.play_anim(st, "emote-yes", 0.25, 0.0)
			var ap := U.anim_player(st)
			if ap: ap.pause()
			for m in st.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = U.solid(Color(0.75, 0.12, 0.12), 0.0, 0.45, 0.3)
			world.obstacles.append(Rect2(p.x - 1.5, p.z - 1.5, 3, 3))
			_static_box(p + Vector3(0, 1.1, 0), Vector3(3, 2.2, 3))
			for fx in [-3.0, 3.0]:
				U.box(n, Vector3(0.15, 7, 0.15), Vector3(fx, 3.5, 0), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
				U.box(n, Vector3(2.4, 1.5, 0.05), Vector3(fx + 1.25, 6.2, 0), U.solid(Color(0.72, 0.05, 0.1)))
				var s2 := Label3D.new(); s2.text = "☭"; s2.font = load("res://fonts/Symbols.ttf"); s2.font_size = 128; s2.pixel_size = 0.008
				s2.modulate = Color(1, 0.8, 0.25); s2.outline_size = 0; s2.position = Vector3(fx + 1.25, 6.2, 0.05); s2.shaded = true
				n.add_child(s2)
		"file":
			for i in 6:
				U.cyl(n, 0.08, 1.0, Vector3(-3.5 + i * 1.4, 0.5, 2.5), U.solid(Color(0.75, 0.75, 0.78), 0.0, 0.3, 0.9))
			U.box(n, Vector3(7.0, 0.08, 0.05), Vector3(0, 0.85, 2.5), U.solid(Color(0.8, 0.1, 0.1)))
			U.box(n, Vector3(2.2, 1.6, 0.15), Vector3(0, 2.4, 0), U.solid(Color(0.9, 0.88, 0.8)))
			U.label(n, "PRENEZ UN\nNUMÉRO", Vector3(0, 2.4, 0.1), 56, Color(0.1, 0.1, 0.1), Color(0, 0, 0, 0), false)
		"pari":
			U.box(n, Vector3(2.6, 2.6, 2.0), Vector3(0, 1.3, 0), U.solid(Color(0.12, 0.35, 0.18)))
			U.box(n, Vector3(2.2, 1.2, 0.1), Vector3(0, 3.4, 0), U.solid(Color(0.05, 0.05, 0.06)))
			U.label(n, "▲ +312 %", Vector3(0, 3.4, 0.08), 70, Color(0.3, 1, 0.4), Color(0, 0, 0, 0), false)
			world.obstacles.append(Rect2(p.x - 1.3, p.z - 1.0, 2.6, 2.0)); _static_box(p + Vector3(0, 1.3, 0), Vector3(2.6, 2.6, 2.0))
		"goulag":
			U.box(n, Vector3(4, 2.6, 3), Vector3(0, 1.3, 0), U.solid(Color(0.32, 0.3, 0.3)))
			U.box(n, Vector3(4.4, 0.3, 3.4), Vector3(0, 2.75, 0), U.solid(Color(0.2, 0.2, 0.22)))
			for i in 5:
				U.box(n, Vector3(0.06, 1.6, 0.06), Vector3(-2.4 + i * 1.2, 0.8, 2.2), U.solid(Color(0.4, 0.4, 0.4), 0.0, 0.3, 0.8))
			U.box(n, Vector3(5.0, 0.04, 0.04), Vector3(0, 1.4, 2.2), U.solid(Color(0.5, 0.5, 0.5), 0.0, 0.3, 0.8))
			world.obstacles.append(Rect2(p.x - 2.0, p.z - 1.5, 4, 3)); _static_box(p + Vector3(0, 1.3, 0), Vector3(4, 2.6, 3))
		"marche":
			U.box(n, Vector3(3.2, 1.0, 1.2), Vector3(0, 0.5, 0), U.solid(Color(0.3, 0.2, 0.25)))
			U.box(n, Vector3(3.6, 0.12, 2.0), Vector3(0, 2.6, 0.2), U.solid(Color(0.35, 0.15, 0.45)))
			var gm := U.place(n, U.SHOP + "gacha-machine.glb", p + Vector3(2.4, 0, 0), 1.8, 0.0)
			var lamp := OmniLight3D.new(); lamp.light_color = col; lamp.light_energy = 1.5; lamp.omni_range = 5.0; lamp.position = Vector3(0, 2.2, 0.6)
			n.add_child(lamp)
			world.obstacles.append(Rect2(p.x - 1.6, p.z - 0.6, 3.2, 1.2)); _static_box(p + Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 1.2))
		"aimant":
			var fr := U.place(n, U.SHOP + "freezer.glb", p, 2.2, 0.0)
			U.box(n, Vector3(1.6, 0.6, 0.1), Vector3(0, 2.6, 0.5), U.solid(Color(0.72, 0.05, 0.1)))
			world.obstacles.append(Rect2(p.x - 0.8, p.z - 0.6, 1.6, 1.2))
		"defi":
			U.box(n, Vector3(2.4, 1.2, 2.4), Vector3(0, 0.6, 0), U.solid(Color(0.3, 0.28, 0.25)))
			var g := U.place(n, U.CH + "character-male-d.glb", p + Vector3(0, 1.2, 0), 3.2, 0.0)
			U.play_anim(g, "emote-yes", 0.3, 0.0)
			var ap2 := U.anim_player(g)
			if ap2: ap2.pause()
			for m in g.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = U.solid(Color(1.0, 0.72, 0.2), 0.0, 0.25, 1.0)
			world.obstacles.append(Rect2(p.x - 1.2, p.z - 1.2, 2.4, 2.4)); _static_box(p + Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 2.4))
	_beam(n, col)
	var lab := U.label(n, info[0], Vector3(0, 6.0 if kind == "statue" else 4.2, 0), 60, col, Color(0.05, 0.03, 0, 1))
	if kind == "statue": lab.position.y = 8.2
	var ring = null
	if kind in ["statue", "file"]:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 4.3 if kind == "statue" else 5.8; tm.outer_radius = tm.inner_radius + 0.2
		ring.mesh = tm
		ring.scale = Vector3(1, 0.05, 1)
		var rm := StandardMaterial3D.new(); rm.albedo_color = col; rm.emission_enabled = true; rm.emission = col; rm.emission_energy_multiplier = 2.0
		ring.material_override = rm
		n.add_child(ring)
		ring.position = Vector3(0, 0.05, 0 if kind == "statue" else 0)
	shrines.append({"kind": kind, "n": n, "pos": p, "used": false, "charge": 0.0, "ring": ring, "label": lab, "active": false, "t": 0.0, "out": 0.0, "cd": 0.0})

func _static_box(center: Vector3, size: Vector3):
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs; body.add_child(cs); body.position = center; add_child(body)

func _make_breakable(p: Vector3):
	var path := U.CAR + "box.glb" if rng.randf() < 0.65 else U.SHOP + "bottle-return.glb"
	var n := U.place(self, path, p, 0.9 if path.ends_with("box.glb") else 1.4, rng.randf() * TAU)
	breakables.append({"n": n, "pos": p})

func break_in_radius(c: Vector3, r: float):
	for b in breakables.duplicate():
		var v: Vector3 = b["pos"] - c
		v.y = 0
		if v.length() < r: _break(b)

func _break(b: Dictionary):
	breakables.erase(b)
	var p: Vector3 = b["pos"]
	var n: Node3D = b["n"]
	var tw := n.create_tween()
	tw.tween_property(n, "scale", n.scale * 0.05, 0.15)
	tw.tween_callback(n.queue_free)
	spark(p + Vector3(0, 0.6, 0))
	var r := rng.randf() * (1.0 + dv("chance") / 100.0)
	if r < 0.08: _drop_heal(p)
	elif r < 0.45: _drop_gem(p, 3)
	else: _drop_coin(p, rng.randi_range(2, 5))

# ---------------------------------------------------------------- flow
func _show_menu():
	state = "menu"
	hud.set_hud_visible(false)
	hud.show_screen("LUTTE FINALE",
		"Le capitalisme a gagné. Pas pour longtemps.\n\nDéplacement : ZQSD / flèches / stick gauche     Caméra : souris / A et R / stick droit\nSaut (double saut) : Espace / A     Glissade : Maj / B     Interagir : F / X\n\nTes armes tirent toutes seules. Casse les cartons, ouvre les coffres, active les sanctuaires.\nBats le Directeur à 08:00. À 10:00, c'est le Krach.",
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
				if choice_wait <= 0.0: _on_chosen(_bot_pick())
			_bot_tick(d)
			return
	if Input.is_action_just_pressed("pause"):
		_pause(); return
	time += rd
	var yaw_in := Input.get_axis("cam_left", "cam_right")
	player.cam_yaw -= yaw_in * 2.2 * rd
	_update_camera(rd)
	_director(rd)
	_events(rd)
	_update_pickups(rd)
	_update_interactions(rd)
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
	var head: Vector3 = player.global_position + Vector3(0, 1.6, 0)
	var want: Vector3 = cam_rig.global_transform * CAM_OFFSET
	var q := PhysicsRayQueryParameters3D.create(head, want, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var k := 1.0
	if not hit.is_empty():
		k = clampf((head.distance_to(hit["position"]) - 0.8) / head.distance_to(want), 0.15, 1.0)
	cam_k = minf(k, cam_k + d * 2.0) if k > cam_k else k
	var pivot := Vector3(0, 1.6, 0)
	var local := pivot + (CAM_OFFSET - pivot) * cam_k
	cam.position = local + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amt
	cam.basis = Basis.looking_at(CAM_LOOK.lerp(Vector3(0, 1.0, -3.0), 1.0 - cam_k) - local, Vector3.UP)

func shake(a: float):
	shake_amt = minf(0.5, shake_amt + a)

func _pause():
	state = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lines := []
	for id in weapons.owned:
		var w: Dictionary = weapons.owned[id]
		lines.append("%s niv %d%s" % [Data.WEAPONS[id]["evo_name"] if w["evo"] else Data.WEAPONS[id]["name"], w["lv"], " ★" if w["evo"] else ""])
	var dl := []
	for id in decrets:
		dl.append("%s (%s)" % [Data.DECRETS[id]["name"], Data.decret_text(id, dv(id))])
	hud.show_screen("PAUSE", "Niveau %d · %d KO · %s\n\nArmes : %s\nDécrets : %s" % [level, kills, _fmt(time), ", ".join(lines), ", ".join(dl) if not dl.is_empty() else "aucun"], "ÉCHAP pour reprendre · RETOUR ARRIÈRE pour recommencer")

func _unpause():
	state = "play"
	get_tree().paused = false
	hud.hide_screen()
	if not bot: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _fmt(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]

# ---------------------------------------------------------------- spawning / difficulty
func spawn_point(min_d: float, max_d: float) -> Vector3:
	var pp: Vector3 = player.global_position
	for i in 12:
		var a := rng.randf() * TAU
		var dd := rng.randf_range(min_d, max_d)
		var p := Vector3(pp.x + cos(a) * dd, 0, pp.z + sin(a) * dd)
		if world.bounds.grow(-1.0).has_point(Vector2(p.x, p.z)):
			return world.resolve(p, 0.6)
	return world.resolve(Vector3(pp.x + min_d, 0, pp.z), 0.6)

func mults() -> Array:
	var tm := time / 60.0
	var hp := (1.0 + 0.22 * tm + 0.08 * tm * tm) * (1.0 + 0.2 * bets)
	return [hp, 1.0 + 0.07 * tm]

func enemy_speed_mult() -> float:
	return 0.55 if event_name == "greve" else 1.0

func _pick_kind() -> String:
	var tm := time / 60.0
	var total := 0.0
	var pool := []
	for row in Data.SPAWN_TABLE:
		if time < row[1]: continue
		var w: float = row[2] + row[3] * maxf(0.0, tm - row[1] / 60.0)
		pool.append([row[0], w]); total += w
	var r := rng.randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0: return p[0]
	return "stagiaire"

func _director(d: float):
	var tm := time / 60.0
	var m := mults()
	var cap := 240 if not krach else 300
	var rate := (0.7 + 0.6 * tm + 0.13 * tm * tm) * (1.0 + 0.15 * bets)
	if krach: rate *= 2.2
	spawn_acc += rate * d
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if enemies.count() >= cap: break
		enemies.spawn(_pick_kind(), spawn_point(20.0, 30.0), m[0], m[1])
	if time >= next_wave and time < ZONE_TIME:
		next_wave += 60.0
		var n := int(12 + tm * 5)
		hud.toast("VAGUE DE STAGIAIRES", 1.5)
		for i in n:
			if enemies.count() >= cap + 40: break
			var a := TAU * i / n
			var p: Vector3 = player.global_position + Vector3(cos(a), 0, sin(a)) * 17.0
			enemies.spawn("stagiaire", world.resolve(p, 0.5), m[0], m[1])
	if not elite_times.is_empty() and time >= elite_times[0]:
		elite_times.pop_front()
		enemies.spawn("golden", spawn_point(18.0, 22.0), m[0] * 0.7, m[1])
		hud.toast("UN GOLDEN BOY APPROCHE · IL TRANSPORTE UN COFFRE", 2.5)
	if not boss_spawned and time >= BOSS_TIME:
		boss_spawned = true
		boss = enemies.spawn("boss", spawn_point(20.0, 24.0), 1.0 + 0.2 * bets, 1.0)
		hud.toast("LE DIRECTEUR BLACK FRIDAY ARRIVE", 3.0)
		shake(0.4)
	if not krach and time >= ZONE_TIME:
		krach = true
		enemies.spawn("fisc", spawn_point(24.0, 28.0))
		hud.toast("LE KRACH · LE CONTRÔLEUR FISCAL TE TROUVERA", 3.5)

# ---------------------------------------------------------------- random events
func _events(d: float):
	if event_t > 0.0:
		event_t -= d
		if event_t <= 0.0:
			if event_name == "greve": hud.toast("FIN DE LA GRÈVE", 1.5)
			event_name = ""
	if time < next_event or krach: return
	next_event = time + rng.randf_range(70.0, 105.0)
	var evs := ["black_friday", "pluie", "greve", "opa", "livraison", "soldes"]
	var ev: String = evs[rng.randi() % evs.size()]
	var m := mults()
	match ev:
		"black_friday":
			hud.toast("ÉVÉNEMENT · BLACK FRIDAY ! UNE RUÉE DE CLIENTS ARRIVE", 3.0)
			var a := rng.randf() * TAU
			for i in int(30 + time / 20.0):
				var p: Vector3 = player.global_position + Vector3(cos(a), 0, sin(a)) * 24.0 + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
				var e = enemies.spawn("trader" if i % 4 == 0 else "stagiaire", world.resolve(p, 0.5), m[0] * 0.7, m[1])
		"pluie":
			hud.toast("ÉVÉNEMENT · PLUIE DE BILLETS ! RAMASSE VITE", 3.0)
			for i in 30:
				var p: Vector3 = player.global_position + Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
				_drop_coin(world.resolve(p, 0.3), rng.randi_range(2, 4))
		"greve":
			hud.toast("ÉVÉNEMENT · GRÈVE GÉNÉRALE ! LES ENNEMIS RALENTISSENT 15 S", 3.0)
			event_name = "greve"; event_t = 15.0
		"opa":
			hud.toast("ÉVÉNEMENT · OPA HOSTILE ! DEUX GOLDEN BOYS", 3.0)
			for i in 2:
				enemies.spawn("golden", spawn_point(16.0, 22.0), m[0] * 0.6, m[1])
		"livraison":
			var p: Vector3 = world.free_spot(0.0, 1.5)
			var tries := 0
			while p.distance_to(player.global_position) > 35.0 and tries < 30:
				p = world.free_spot(0.0, 1.5); tries += 1
			_make_chest(p, true, 1)
			hud.toast("ÉVÉNEMENT · LIVRAISON EXPRESS ! UN COFFRE RARE EST TOMBÉ (FAISCEAU VIOLET)", 3.5)
		"soldes":
			chest_cost = maxi(8, int(chest_cost * 0.5))
			hud.toast("ÉVÉNEMENT · SOLDES ! LES COFFRES COÛTENT MOITIÉ PRIX", 3.0)

# ---------------------------------------------------------------- kills, drops
func on_enemy_killed(e):
	kills += 1
	spark(e.node.position + Vector3(0, 1.0, 0), true)
	_drop_gem(e.node.position, e.xp)
	var luck := 1.0 + dv("chance") / 100.0
	if rng.randf() < 0.012 * luck:
		_drop_heal(e.node.position + Vector3(-0.5, 0, 0.3))
	if rng.randf() < 0.06 * luck or e.elite:
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

func damage_number(pos: Vector3, amt: float, crit: bool, resisted := false):
	var l: Label3D = dmg_labels[dmg_idx]
	dmg_idx = (dmg_idx + 1) % dmg_labels.size()
	if l.has_meta("tw"):
		var old: Tween = l.get_meta("tw")
		if old and old.is_valid(): old.kill()
	l.visible = true
	l.text = ("CRIT %d" if crit else "%d") % maxi(1, int(amt))
	l.modulate = Color(1, 0.3, 0.2, 1) if crit else (Color(0.6, 0.65, 0.75, 1) if resisted else Color(1, 1, 1, 1))
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

func _drop_gem(p: Vector3, val: int):
	if gems.size() > 350:
		var g0: Dictionary = gems[rng.randi() % gems.size()]
		g0["v"] += val
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.16 + 0.04 * minf(val, 5); sm.height = sm.radius * 2.4; sm.radial_segments = 4; sm.rings = 2
	mi.mesh = sm
	mi.material_override = U.solid(Color(0.2, 0.95, 0.45) if val < 4 else Color(0.3, 0.6, 1.0), 2.5)
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
	var magnet := 4.0 * (1.0 + dv("aimant") / 100.0)
	var t := Time.get_ticks_msec() / 1000.0
	for arr in [gems, coins]:
		for g in arr.duplicate():
			var n: Node3D = g["n"]
			var v := pp - n.global_position
			var dist := v.length()
			if dist < magnet: g["pull"] = true
			if g["pull"]:
				g["spd"] = minf(g["spd"] + 40.0 * d, 34.0)
				n.global_position += v.normalized() * minf(g["spd"] * d, dist)
				if dist < 0.7:
					arr.erase(g)
					n.queue_free()
					if arr == gems: add_xp(g["v"])
					elif g.has("heal"):
						player.heal(g["heal"])
						hud.toast("TARTINE · +25 PV", 1.0)
					else:
						rubles += int(ceil(g["v"] * (1.0 + 0.35 * bets)))
			else:
				n.rotation.y = t * 2.0
				n.position.y = 0.35 + sin(t * 3.0 + n.position.x) * 0.08
	for b in breakables.duplicate():
		var v2: Vector3 = b["pos"] - player.global_position
		v2.y = 0
		if v2.length() < 1.3: _break(b)

func add_xp(v: int):
	xp += int(ceil(v * (1.0 + dv("propagande") / 100.0) * (1.0 + 0.35 * bets)))
	while xp >= Data.xp_to_next(level):
		xp -= Data.xp_to_next(level)
		level += 1
		pending_levels += 1
	if pending_levels > 0 and state == "play":
		_open_levelup()

# ---------------------------------------------------------------- interactions (chests, shrines)
func _update_interactions(d: float):
	var pp: Vector3 = player.global_position
	var prompt := ""
	var act := Input.is_action_just_pressed("interact") or (bot and rng.randf() < 0.3)
	# chests
	for c in chests:
		if not c["free"]: c["label"].text = "%d RBL" % chest_cost
	for c in chests:
		if c["n"].global_position.distance_to(pp) < 2.4:
			var cost := 0 if c["free"] else chest_cost
			prompt = "F / X : OUVRIR LE COFFRE" + ("" if cost == 0 else " (%d RBL)" % cost) + ("" if rubles >= cost else " · PAS ASSEZ DE ROUBLES")
			if act and rubles >= cost:
				rubles -= cost
				if not c["free"]: chest_cost = int(chest_cost * 1.45) + 4
				chests.erase(c)
				c["n"].queue_free()
				_open_chest(c["bonus"])
				act = false
			break
	# shrines
	for s in shrines:
		s["cd"] = maxf(0.0, s["cd"] - d)
		var v: Vector3 = pp - s["pos"]
		v.y = 0
		var dist := v.length()
		match s["kind"]:
			"statue":
				if s["used"]: continue
				if dist < 4.5 and player.is_on_floor():
					s["charge"] += d / 5.0
					prompt = "STATUE DU LEADER · RESTE DANS LE CERCLE (%d %%)" % int(s["charge"] * 100)
					if s["charge"] >= 1.0:
						_use_shrine(s)
						var opts := _roll_options(3, 1)
						if not opts.is_empty(): _open_choice("LE LEADER T'ACCORDE UNE FAVEUR", opts, "shrine")
				else:
					s["charge"] = maxf(0.0, s["charge"] - d / 10.0)
			"file":
				if s["used"]: continue
				if s["active"]:
					s["t"] -= d
					if dist > 6.0:
						s["out"] += d
						prompt = "REVIENS DANS LA FILE ! (%.1f s)" % maxf(0.0, 2.0 - s["out"])
						if s["out"] > 2.0:
							_use_shrine(s)
							hud.toast("DÉFI ÉCHOUÉ · TU AS QUITTÉ LA FILE", 2.0)
					else:
						s["out"] = 0.0
						prompt = "FILE D'ATTENTE · TIENS ENCORE %d S" % ceili(s["t"])
					if s["active"] and s["t"] <= 0.0:
						_use_shrine(s)
						_make_chest(s["pos"] + Vector3(0, 0, 3), true, 2)
						hud.toast("DÉFI RÉUSSI · COFFRE ÉPIQUE OFFERT", 2.5)
				elif dist < 3.5:
					prompt = "F / X : PRENDRE UN NUMÉRO (défi : tenir 20 s dans le cercle)"
					if act:
						s["active"] = true; s["t"] = 20.0; s["out"] = 0.0
						hud.toast("DÉFI · FILE D'ATTENTE · NE QUITTE PAS LE CERCLE", 2.5)
						var m := mults()
						for i in int(14 + time / 25.0):
							var a := TAU * i / (14 + time / 25.0)
							enemies.spawn(_pick_kind(), world.resolve(s["pos"] + Vector3(cos(a), 0, sin(a)) * 15.0, 0.5), m[0], m[1])
			_:
				if s["used"] and s["kind"] != "marche": continue
				if dist < 3.5 and s["cd"] <= 0.0:
					prompt = "F / X : " + SHRINE_INFO[s["kind"]][0] + " · " + SHRINE_INFO[s["kind"]][2]
					if act: _activate(s)
	hud.prompt(prompt)

func _use_shrine(s: Dictionary):
	s["used"] = true
	s["active"] = false
	if s["ring"]: s["ring"].visible = false
	s["label"].modulate = Color(0.5, 0.5, 0.5)
	for c in s["n"].get_children():
		if c is MeshInstance3D and c.mesh is CylinderMesh and (c.mesh as CylinderMesh).height >= 14.0:
			c.visible = false

func _activate(s: Dictionary):
	match s["kind"]:
		"pari":
			_use_shrine(s)
			bets += 1
			hud.toast("PARI ACCEPTÉ · ENNEMIS +20 % PV · XP ET ROUBLES +35 %", 3.0)
		"goulag":
			_use_shrine(s)
			player.max_hp = maxf(40.0, player.max_hp - 20.0)
			player.hp = minf(player.hp, player.max_hp)
			var opts := _roll_options(3, 2)
			if not opts.is_empty(): _open_choice("LE GOULAG · TON SACRIFICE SERA RÉCOMPENSÉ", opts, "shrine")
		"aimant":
			_use_shrine(s)
			for g in gems: g["pull"] = true
			hud.toast("DISTRIBUTEUR · TOUTE L'XP ARRIVE", 2.0)
		"defi":
			_use_shrine(s)
			var m := mults()
			for i in 3:
				enemies.spawn("golden", world.resolve(s["pos"] + Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0)) * 8.0, 1.0), m[0] * 0.6, m[1])
			hud.toast("OPA HOSTILE · 3 GOLDEN BOYS", 2.5)
		"marche":
			s["cd"] = 2.0
			var opts := _roll_options(3, 0)
			for o in opts:
				o["cost"] = int((22 + 14 * market_buys) * (1.0 + 0.5 * o["rarity"]))
			_open_choice("MARCHÉ NOIR · TU AS %d ROUBLES" % rubles, opts, "market", "PARTIR")

func _open_chest(bonus: int):
	var opts := _roll_options(1, 0, bonus)
	if opts.is_empty():
		player.heal(40); hud.toast("COFFRE : +40 PV", 2.0)
		return
	var o: Dictionary = opts[0]
	_apply(o)
	hud.toast("COFFRE %s : %s · %s" % [Data.RARITIES[o["rarity"]], o["title"], o["short"]], 3.0)
	shake(0.1)

# ---------------------------------------------------------------- options & upgrades
func roll_rarity(min_r := 0, bonus := 0) -> int:
	var luck := dv("chance") / 100.0
	var w := [60.0, 27.0 * (1.0 + luck), 10.0 * (1.0 + 2.0 * luck), 3.0 * (1.0 + 3.0 * luck)]
	var total := 0.0
	for i in range(min_r, 4): total += w[i]
	var r := rng.randf() * total
	var res := 3
	for i in range(min_r, 4):
		r -= w[i]
		if r <= 0.0: res = i; break
	return mini(3, res + bonus)

func _roll_options(n: int, min_r := 0, bonus := 0) -> Array:
	var pool := []
	for id in weapons.owned:
		if weapons.can_evolve(id):
			pool.append({"kind": "evo", "id": id, "w": 4.0})
		elif weapons.level(id) < Data.MAX_WEAPON_LV:
			pool.append({"kind": "weapon_up", "id": id, "w": 1.3})
	if weapons.owned.size() < Data.WEAPON_SLOTS:
		for id in Data.WEAPONS:
			if not weapons.owned.has(id):
				pool.append({"kind": "weapon_new", "id": id, "w": 0.7})
	for id in decrets:
		if decrets[id]["n"] < Data.DECRET_MAX_PICKS:
			pool.append({"kind": "decret", "id": id, "w": 1.0})
	if decrets.size() < Data.DECRET_SLOTS:
		for id in Data.DECRETS:
			if not decrets.has(id):
				pool.append({"kind": "decret", "id": id, "w": 0.45})
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
		o["rarity"] = roll_rarity(min_r, bonus) if o["kind"] != "evo" else 3
		_describe(o)
	return out

func _describe(o: Dictionary):
	var r: int = o["rarity"]
	match o["kind"]:
		"evo":
			var w: Dictionary = Data.WEAPONS[o["id"]]
			o["title"] = w["evo_name"]
			o["tag"] = "ÉVOLUTION · %s + %s" % [w["name"].to_upper(), Data.DECRETS[w["evo"]]["name"].to_upper()]
			o["lv"] = "Arme ultime"
			o["desc"] = w["evo_desc"]
			o["short"] = "évolution"
		"weapon_new":
			var w: Dictionary = Data.WEAPONS[o["id"]]
			o["title"] = w["name"]
			o["tag"] = "NOUVELLE ARME"
			o["lv"] = "Niveau 1"
			o["desc"] = w["desc"] + "\n\nÉvolue avec : " + Data.DECRETS[w["evo"]]["name"]
			o["short"] = "nouvelle arme"
		"weapon_up":
			var w: Dictionary = Data.WEAPONS[o["id"]]
			var ups: Array = w["ups"].duplicate()
			ups.shuffle()
			var k := 3 if r == 3 else 2
			var mods := {}
			var parts := []
			for i in mini(k, ups.size()):
				var st: String = ups[i]
				var v := Data.weapon_up_value(st, r)
				mods[st] = v
				parts.append(Data.weapon_up_text(st, v))
			o["mods"] = mods
			o["title"] = w["name"]
			o["tag"] = "ARME · " + Data.RARITIES[r]
			o["lv"] = "Niveau %d" % (weapons.level(o["id"]) + 1)
			o["desc"] = "\n".join(parts)
			o["short"] = ", ".join(parts)
		"decret":
			var dd: Dictionary = Data.DECRETS[o["id"]]
			var v := Data.decret_value(o["id"], r)
			o["value"] = v
			o["title"] = dd["name"]
			o["tag"] = ("NOUVEAU DÉCRET · " if not decrets.has(o["id"]) else "DÉCRET · ") + Data.RARITIES[r]
			o["lv"] = "Niveau %d / %d" % [decret_lv(o["id"]) + 1, Data.DECRET_MAX_PICKS]
			o["desc"] = Data.decret_text(o["id"], v)
			for wid in Data.WEAPONS:
				if Data.WEAPONS[wid]["evo"] == o["id"]:
					o["desc"] += "\n\nFait évoluer : " + Data.WEAPONS[wid]["name"]
			o["short"] = Data.decret_text(o["id"], v)

func _apply(o: Dictionary):
	match o["kind"]:
		"evo":
			weapons.evolve(o["id"])
			hud.toast("ÉVOLUTION : " + Data.WEAPONS[o["id"]]["evo_name"].to_upper(), 3.0)
		"weapon_new":
			weapons.add_weapon(o["id"])
		"weapon_up":
			if not o.has("mods"): _describe(o)
			weapons.upgrade(o["id"], o["mods"])
		"decret":
			var v: float = o.get("value", Data.decret_value(o["id"], o["rarity"]))
			if not decrets.has(o["id"]): decrets[o["id"]] = {"n": 0, "v": 0.0}
			decrets[o["id"]]["n"] += 1
			decrets[o["id"]]["v"] += v
			if o["id"] == "endurance":
				player.max_hp += v
				player.heal(v)

func _open_levelup():
	var opts := _roll_options(3)
	if opts.is_empty():
		pending_levels = 0
		player.heal(30)
		return
	_open_choice("NIVEAU %d · LE PARTI TE RÉCOMPENSE" % (level - pending_levels + 1), opts, "level")

func _open_choice(title: String, opts: Array, source: String, leave := ""):
	state = "choice"
	choice_source = source
	choice_wait = 0.4
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_choices(title, opts, leave)
	if bot and shot_every > 0.0 and not shot_choice_done:
		shot_choice_done = true
		await get_tree().process_frame
		await get_tree().process_frame
		_screenshot()

func _on_chosen(i: int):
	if state != "choice": return
	if i >= 0 and i < hud.options.size():
		var o: Dictionary = hud.options[i]
		if choice_source == "market":
			if rubles < o["cost"]:
				hud.toast("PAS ASSEZ DE ROUBLES", 1.2)
				if not bot: return
			else:
				rubles -= o["cost"]
				market_buys += 1
				_apply(o)
				hud.toast("ACHAT : %s" % o["title"], 1.5)
		else:
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
func _bot_pick() -> int:
	var best := 0
	var bs := -1.0
	for i in hud.options.size():
		var o: Dictionary = hud.options[i]
		var sc: float = 1.0 + o["rarity"] * 0.6
		match o["kind"]:
			"evo": sc += 10.0
			"weapon_new": sc += 3.0 if weapons.owned.size() < 3 else 1.0
			"weapon_up": sc += 2.0
			"decret":
				sc += 2.5 if o["id"] in ["productivite", "cadence", "endurance", "armure", "collectivisation", "expansion"] else 0.5
		if choice_source == "market" and rubles < o.get("cost", 0): sc = -1.0
		if sc > bs: bs = sc; best = i
	if choice_source == "market" and bs < 0.0: return -1
	return best

func _bot_tick(d: float):
	if not bot: return
	log_t += d
	if log_t >= 10.0:
		log_t = 0.0
		var wl := []
		for id in weapons.owned: wl.append("%s%d%s" % [id.substr(0, 4), weapons.owned[id]["lv"], "*" if weapons.owned[id]["evo"] else ""])
		var dl := []
		for id in decrets: dl.append("%s%d" % [id.substr(0, 4), decrets[id]["n"]])
		print("[bot] t=%s lvl=%d hp=%d/%d kills=%d enemies=%d rub=%d fps=%d w=%s d=%s bets=%d state=%s" % [_fmt(time), level, player.hp, player.max_hp, kills, enemies.count(), rubles, Engine.get_frames_per_second(), ",".join(wl), ",".join(dl), bets, state])
	if shot_every > 0.0:
		shot_t += d
		if shot_t >= shot_every:
			shot_t = 0.0
			_screenshot()
	if test_dur > 0.0 and (time >= test_dur or state in ["over", "win"]):
		if state in ["over", "win"]: _screenshot()
		print("[bot] END state=%s t=%s lvl=%d kills=%d" % [state, _fmt(time), level, kills])
		get_tree().quit()

func _screenshot():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	img.save_png("%s/shot_%03d_%s.png" % [shot_dir, shot_n, state])
	shot_n += 1
