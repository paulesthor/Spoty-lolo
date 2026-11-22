extends Node3D
# Communiste Land — prototype. Game loop for one zone ("Hypermarché").
# Test flags (after "--"): bot  speed=4  dur=600  shots=60  shotdir=res://proto_shots  seed=1  warp=300  pos=x,z yaw=deg

const ZONE_TIME := 600.0      # 10:00, then the Krach
const ZONE_OFFSET := 240.0    # each later zone starts as if this much more time had passed (difficulty)
const BOSS_TIME := 480.0      # 08:00
const CAM_OFFSET := Vector3(0, 7.5, 10.5)
const CAM_LOOK := Vector3(0, 0.3, -6.5)
const PITCH_MIN := 0.3     # ~17°: low, looking ahead
const PITCH_MAX := 1.15    # ~66°: nearly top-down
var cam_pitch := atan2(7.5, 10.5)

# camera offset/look target for the current pitch (same distance as the default framing)
func cam_offset() -> Vector3:
	var dist := Vector2(10.5, 7.5).length()
	return Vector3(0, sin(cam_pitch) * dist, cos(cam_pitch) * dist)

func cam_look() -> Vector3:
	var k := clampf((cam_pitch - PITCH_MIN) / (PITCH_MAX - PITCH_MIN), 0.0, 1.0)
	return Vector3(0, lerpf(1.2, -1.2, k), lerpf(-9.0, -2.35, k))     # default pitch gives the original framing

var state := "menu"
var zone := 1
var tier := 1
var endless := false
var tpl: Dictionary = Levels.HYPERMARCHE
var run_time := 0.0        # time spent in previous zones
var bosses_killed: Array = []
var door: Node3D = null
var carried := false
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
var char_id := "stakhanov"
var mods := {}            # permanent bonuses (talents, bureau, character)
var dirs := {}            # active directives
var rerolls := 0
var banishes := 0
var skips := 0
var banned := {}
var weather
var base_time_scale := 1.0
var slowmo_cd := 0.0
var revives := 0
var ult_kills := 0
var ult_t := 0.0          # active ultimate remaining
var kills_by_kind := {}
var kills_by_weapon := {}
var dmg_by_weapon := {}
var elites_killed := 0
var chests_opened := 0
var shrines_used := 0
var got_evo := false
var report_done := false
var multi_run := false
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
var test_killboss := false
var test_god := false
var test_give := ""
static var _zone_arg_used := false
var shot_choice_done := false

func _ready():
	var seed_v := 1917 + int(Meta.data.get("runs", 0)) * 7919 + randi() % 1000
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
		elif a.begins_with("zone=") and Meta.carry.is_empty() and not _zone_arg_used: Meta.run_zone = int(a.substr(5)); _zone_arg_used = true
		elif a.begins_with("tier="): Meta.run_tier = int(a.substr(5))
		elif a == "endless": Meta.run_endless = true
		elif a == "killboss": test_killboss = true
		elif a == "god": test_god = true
		elif a.begins_with("give="): test_give = a.substr(5)
	zone = Meta.run_zone
	tier = Meta.run_tier
	endless = Meta.run_endless
	tpl = Levels.zone(zone)
	seed_v += zone * 101
	rng.seed = seed_v
	seed(seed_v)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	world = load("res://scripts/world.gd").new()
	add_child(world)
	world.build(seed_v, tpl)
	player = load("res://scripts/player.gd").new()
	add_child(player)
	player.setup(self)
	player.bot = bot
	player.landed.connect(_on_landed)
	player.global_position = world.player_start + Vector3(0, 0.3, 0)
	enemies = load("res://scripts/enemies.gd").new()
	add_child(enemies)
	enemies.setup(self)
	weapons = load("res://scripts/weapons.gd").new()
	add_child(weapons)
	weapons.setup(self)
	weather = load("res://scripts/weather.gd").new()
	add_child(weather)
	weather.process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_meta()
	if not Meta.carry.is_empty():
		_restore(Meta.carry)
		Meta.carry = {}
	elif not "solo" in OS.get_cmdline_user_args():
		weapons.add_weapon(Meta.CHARACTERS[char_id]["weapon"])
	for n in [world, player, enemies, weapons]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_camera()
	_setup_map_objects()
	if "layoutcheck" in OS.get_cmdline_user_args():
		var iss: Array = load("res://scripts/layout_check.gd").run(self)
		for line in iss: print("[layout] " + line)
		print("[layout] zone=%d issues=%d" % [zone, iss.size()])
		get_tree().quit()
		return
	weather.setup(self)
	for i in 40:
		var l := U.label(self, "", Vector3(0, -100, 0), 64, Color.WHITE, Color(0.08, 0.04, 0.02, 1))
		l.visible = false
		dmg_labels.append(l)
	# poster grade under the HUD (HUD canvas layer is 5)
	var post := CanvasLayer.new(); post.layer = 1; add_child(post)
	var pr := ColorRect.new(); pr.set_anchors_preset(Control.PRESET_FULL_RECT); pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/poster.gdshader"); pr.material = pm
	if tpl.get("id", "") == "bourse": pm.set_shader_parameter("light_tint", Vector3(1.0, 0.96, 1.0))
	post.add_child(pr)
	hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(self)
	hud.chosen.connect(_on_chosen)
	if bot and multi_run == false and warp == 0.0 and test_pos == Vector3.INF and shot_every == 0.0:
		start()
	elif bot:
		await _warmup()
		start()
		if warp > 0.0: _do_warp()
		if test_pos != Vector3.INF:
			player.global_position = test_pos
			player.cam_yaw = test_yaw
			player.bot = false
			cam_rig.global_position = test_pos
	else:
		await _warmup()
		start()

# Pre-render every enemy, weapon effect, pickup and UI panel once behind a loading screen,
# so that shaders, meshes and font glyphs are ready before they are needed (avoids hitches).
var warming := false
func _warmup():
	warming = true
	state = "loading"
	var cover := CanvasLayer.new()
	cover.layer = 20
	add_child(cover)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.065, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(bg)
	var art := TextureRect.new()
	art.texture = load("res://assets/posters/" + U.propaganda_tex(randi()))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.anchor_right = 0.42; art.offset_left = 60; art.offset_top = 60; art.offset_bottom = -60
	cover.add_child(art)
	var tips := ["Astuce du Parti : la glissade laisse une traînée de feu. Les capitalistes détestent la chaleur humaine.",
		"Astuce du Parti : deux armes niveau 6 peuvent fusionner et libérer un emplacement.",
		"Astuce du Parti : M active la mini-carte, Tab affiche la grande carte.",
		"Astuce du Parti : un Golden Boy transporte toujours un coffre. Redistribue-le.",
		"Astuce du Parti : l'esquive (clic droit) rend invulnérable un court instant.",
		"Astuce du Parti : les quotas du Plan rapportent beaucoup de médailles. Le Plan a toujours raison."]
	var tip := Label.new()
	tip.text = tips[randi() % tips.size()]
	tip.add_theme_font_override("font", load("res://fonts/Oswald.woff2"))
	tip.add_theme_font_size_override("font_size", 26)
	tip.add_theme_color_override("font_color", Color(0.93, 0.87, 0.74))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.set_anchors_preset(Control.PRESET_FULL_RECT)
	tip.anchor_left = 0.48; tip.offset_right = -60; tip.anchor_top = 0.62
	cover.add_child(tip)
	var lab := Label.new()
	lab.text = "COMMUNISTE LAND\n%s\nPréparation de la zone…" % (tpl["name"] as String).to_upper()
	lab.add_theme_font_override("font", load("res://fonts/Oswald.woff2"))
	lab.add_theme_font_size_override("font_size", 48)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.anchor_left = 0.48; lab.anchor_bottom = 0.6
	lab.add_theme_color_override("font_color", Color(0.85, 0.12, 0.14))
	cover.add_child(lab)
	_update_camera(0.016)
	var front: Vector3 = player.global_position + Vector3(0, 0, -8)
	# enemies (also fills the pools)
	var spawned := []
	var kinds := ["stagiaire", "stagiaire", "stagiaire", "cadre", "cadre", "trader", "influenceur", "crypto", "avocat", "banquier", "huissier", "coach", "lobbyiste", "drh", "actionnaire", "golden"]
	for i in kinds.size():
		spawned.append(enemies.spawn(kinds[i], front + Vector3((i % 6) * 1.5 - 4.0, 0, -(i / 6) * 2.0)))
	# weapons: fire each once
	var temp := []
	for id in Data.WEAPONS:
		if not weapons.owned.has(id):
			weapons.add_weapon(id); temp.append(id)
	for id in Data.WEAPONS:
		weapons._fire(id, weapons.stats(id))
	if weapons.owned.has("spoutnik"): weapons._update_sats(0.016)
	weapons._update_bears(0.016)
	weapons._wall(front, Vector3.RIGHT, weapons.stats("rideau"))
	weapons._cage(front, weapons.stats("goulag"))
	weapons._star(front + Vector3(0, 5, 0), front, weapons.stats("etoile"))
	weapons._rocket(front, weapons.stats("katioucha"), 0.0)
	weapons._tractor(front, Vector3.FORWARD, weapons.stats("tracteur"))
	weapons._note(front, Vector3.FORWARD, weapons.stats("balalaika"))
	weapons._blast(front, 2.0, 1.0, weapons.stats("t34"), Color(1, 0.5, 0.2))
	weapons._slash_fx(front, 2.0, Color(1, 1, 1))
	weapons._ring_fx(front, 3.0, Color(1, 0.3, 0.2))
	weapons._beam(front + Vector3(0, 2, 0), front + Vector3(2, 1, 0))
	weapons._doll_burst(front, weapons.stats("matriochka"), 0, 1.0)
	weapons._spawn_fire(front, weapons.stats("molotov"))
	weapons._cone_fx(player.global_position, Vector3.FORWARD, 6.0, false)
	# enemy hazards and pickups
	enemies._shoot(front + Vector3(0, 1, 0), Vector3.BACK, 1.0, "")
	enemies._lob(front + Vector3(0, 2, 0), front + Vector3(2, 0, 0), 1.0)
	enemies._debt_zone(front + Vector3(-2, 0, 0), 0.0)
	enemies._telegraph_line(front, Vector3.FORWARD, 6.0, 0.2)
	enemies._heal_fx(front)
	_drop_gem(front, 1); _drop_gem(front, 6); _drop_coin(front, 1); _drop_heal(front)
	spark(front + Vector3(0, 1, 0), true); spark(front + Vector3(0, 1, 0))
	damage_number(front + Vector3(0, 2, 0), 123, false); damage_number(front + Vector3(1, 2, 0), 456, true)
	# UI glyphs
	var dummy := [{"kind": "decret", "id": "productivite", "rarity": 3, "tag": "ÉVOLUTION · ARME · DÉCRET · COMMUN RARE ÉPIQUE LÉGENDAIRE", "title": "Marteau-Pilon Révolution", "lv": "Niveau 10 / 6", "desc": "0123456789 %+-.,:'() abcdefghijklmnopqrstuvwxyz ÀÂÉÈÊËÎÏÔÙÛÇéèêàùç", "cost": 99},
		{"kind": "decret", "id": "cadence", "rarity": 1, "tag": "x", "title": "x", "lv": "x", "desc": "x"}, {"kind": "decret", "id": "aimant", "rarity": 2, "tag": "x", "title": "x", "lv": "x", "desc": "x"}]
	hud.show_choices("NIVEAU 0123456789 · LE PARTI TE RÉCOMPENSE", dummy, "PARTIR")
	hud.toast("ÉVÉNEMENT · ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789", 0.01)
	hud.prompt("F / X : OUVRIR LE COFFRE (12 RBL)")
	for i in 6: await get_tree().process_frame
	hud.hide_choices()
	hud.prompt("")
	# cleanup
	for e in spawned:
		if e.alive:
			e.alive = false
			enemies.list.erase(e)
			e.node.visible = false
			if not enemies.pools.has(e.kind): enemies.pools[e.kind] = []
			enemies.pools[e.kind].append(e)
	for p in weapons.projectiles: p["n"].queue_free()
	weapons.projectiles.clear()
	for f in weapons.fires: f["n"].queue_free()
	weapons.fires.clear()
	for b in weapons.bears: b.queue_free()
	weapons.bears.clear()
	for w in weapons.walls: w["n"].queue_free()
	weapons.walls.clear()
	for c in weapons.cages: c["n"].queue_free()
	weapons.cages.clear()
	for id in temp:
		weapons.owned.erase(id); weapons.timers.erase(id)
		if id == "spoutnik":
			for sp in weapons.sats: sp.queue_free()
			weapons.sats.clear()
		if id == "samovar" and weapons.aura_fx:
			weapons.aura_fx.queue_free(); weapons.aura_fx = null
	for h in enemies.hazards: h["n"].queue_free()
	enemies.hazards.clear()
	for arr in [gems, coins]:
		for g in arr: g["n"].queue_free()
		arr.clear()
	if not carried:
		kills = 0; ult_kills = 0
		kills_by_kind.clear(); kills_by_weapon.clear(); dmg_by_weapon.clear()
	cover.queue_free()
	warming = false

func _load_meta():
	char_id = Meta.run_char
	if not Meta.data["chars"].has(char_id) or not Meta.data["chars"][char_id]["unlocked"]: char_id = "stakhanov"
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("char=") and Meta.CHARACTERS.has(a2.substr(5)): char_id = a2.substr(5)    # test hook
	dirs = Meta.run_directives.duplicate()
	mods = Meta.run_modifiers(char_id)
	rerolls = int(mods.get("reroll", 0.0))
	banishes = int(mods.get("banish", 0.0))
	skips = int(mods.get("skip", 0.0))
	base_time_scale = Engine.time_scale
	revives = int(mods.get("revive", 0.0))
	player.apply_character(char_id)
	player.max_hp = 120.0 + mods.get("endurance", 0.0)
	player.hp = player.max_hp
	if dirs.has("surveillance"): pass
	if dirs.has("opa"):
		elite_times = [90.0, 150.0, 240.0, 300.0, 360.0, 420.0, 480.0, 540.0]
	for a in OS.get_cmdline_user_args():
		if a == "multirun": multi_run = true

func dirl(id: String) -> int:
	return int(dirs.get(id, 0))

var ult_uses := 0
func ultimate_cost() -> int:
	if "freeult" in OS.get_cmdline_user_args(): return 5
	return int(220.0 * (1.0 + 0.3 * ult_uses) * (1.0 - mods.get("ult_charge", 0.0) / 100.0))

# effective stat: in-run décrets + permanent bonuses (+ Stakhanov's passive)
func dv(id: String) -> float:
	var v: float = (decrets[id]["v"] if decrets.has(id) else 0.0)
	if id == "endurance": return v
	v += mods.get(id, 0.0)
	if id == "productivite": v += 1.5 * (level - 1)       # "Expérience du Parti": every level makes you hit harder
	if id == "productivite" and char_id == "barbudo": v += minf(30.0, 3.0 * (elites_killed + bosses_killed.size()))
	if id == "cadence":
		if char_id == "stakhanov": v += minf(20.0, floorf(kills / 150.0) * 2.0)
		if ult_t > 0.0 and char_id == "stakhanov": v = (1.0 + v / 100.0) * (2.0 * (1.0 + mods.get("ult_power", 0.0) / 100.0)) * 100.0 - 100.0
		if ult_t > 0.0 and char_id == "vodkine": v += 60.0 * (1.0 + mods.get("ult_power", 0.0) / 100.0)
	return v

func weapon_slots() -> int:
	return Data.WEAPON_SLOTS + int(mods.get("weapon_slot", 0.0))

func chest_price() -> int:
	return int(chest_cost * (1.5 if dirl("penurie") > 0 else 1.0) * (1.0 - mods.get("chest_discount", 0.0) / 100.0))

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
		_spawn_picked(spawn_point(8.0, 26.0), m)

func _setup_input():
	var acts := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "slide": [KEY_SHIFT, KEY_CTRL], "interact": [KEY_F], "ultimate": [KEY_E], "reroll": [KEY_T], "dodge": [KEY_C, KEY_ALT], "banish": [KEY_B], "skip": [KEY_X],
		"cam_left": [KEY_Q], "cam_right": [KEY_R], "cam_up": [KEY_PAGEUP], "cam_down": [KEY_PAGEDOWN],
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
	var pads := {"jump": JOY_BUTTON_A, "slide": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START, "confirm": JOY_BUTTON_A, "restart": JOY_BUTTON_BACK, "choose_4": JOY_BUTTON_Y, "ultimate": JOY_BUTTON_RIGHT_SHOULDER, "reroll": JOY_BUTTON_LEFT_SHOULDER, "dodge": JOY_BUTTON_LEFT_SHOULDER, "banish": JOY_BUTTON_LEFT_STICK, "skip": JOY_BUTTON_RIGHT_STICK}
	for a in pads:
		var ev := InputEventJoypadButton.new(); ev.button_index = pads[a]
		InputMap.action_add_event(a, ev)
	# map keys use the printed key (AZERTY-friendly): M toggles the minimap, Tab shows the big map
	for pair in [["minimap", KEY_M], ["bigmap", KEY_TAB]]:
		if not InputMap.has_action(pair[0]): InputMap.add_action(pair[0], 0.2)
		var kev := InputEventKey.new(); kev.keycode = pair[1]
		InputMap.action_add_event(pair[0], kev)
	var bev := InputEventJoypadButton.new(); bev.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event("bigmap", bev)
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("dodge", mb)
	var axes := [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0], ["cam_left", JOY_AXIS_RIGHT_X, -1.0], ["cam_right", JOY_AXIS_RIGHT_X, 1.0], ["cam_up", JOY_AXIS_RIGHT_Y, -1.0], ["cam_down", JOY_AXIS_RIGHT_Y, 1.0]]
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
	m.set_meta("airborne", true)     # light beam, not a physical object
	parent.add_child(m)
	return m

func _setup_map_objects():
	for p in world.chest_spots:
		_make_chest(p, false)
	var kinds := ["statue", "file", "statue", "pari", "goulag", "marche", "aimant", "defi", "file"]
	for i in world.shrine_spots.size():
		_make_shrine(kinds[i % kinds.size()], world.shrine_spots[i])
	var taken: Array = []
	for c in chests: taken.append((c["n"] as Node3D).global_position)
	for p in world.breakable_spots:
		var ok := true
		for q in taken:
			if p.distance_to(q) < 1.6: ok = false; break
		if not ok: continue
		taken.append(p)
		_make_breakable(p)

# lid swings open and coins burst out; runs while the game is paused on the reward choice
func _chest_open_fx(n: Node3D):
	var lid: Node3D = n.get_node_or_null("lid")
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if lid: tw.tween_property(lid, "rotation:x", -1.9, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 8:
		var c := U.cyl(n, 0.12, 0.04, Vector3(0, 0.6, 0), U.solid(Color(1, 0.8, 0.25), 1.5, 0.3, 1.0))
		var a := TAU * i / 8.0
		var to := Vector3(cos(a) * 1.2, 1.6 + randf() * 0.8, sin(a) * 1.2)
		var ct := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ct.tween_property(c, "position", to, 0.35).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(c, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.35)
		ct.tween_property(c, "scale", Vector3.ONE * 0.01, 0.3)
	var glow := U.sprite(n, "light_01.png", Vector3(0, 1.0, 0), 3.0, Color(1, 0.8, 0.3, 0.8), 3.0)
	var gt := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	gt.tween_property(glow, "scale", Vector3.ONE * 2.0, 0.4)
	tw.tween_interval(0.9)
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(n.queue_free)

func _make_chest(p: Vector3, free: bool, rarity_bonus := 0):
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	n.rotation.y = rng.randf() * TAU
	var body_col := Color(0.95, 0.68, 0.15) if rarity_bonus == 0 else Color(0.75, 0.4, 1.0)
	var wood := U.solid(Color(0.42, 0.25, 0.12), 0.0, 0.8)
	U.box(n, Vector3(1.2, 0.62, 0.8), Vector3(0, 0.31, 0), wood)
	for bx in [-0.5, 0.5]:
		U.box(n, Vector3(0.1, 0.64, 0.84), Vector3(bx, 0.32, 0), U.solid(body_col, 0.0, 0.4, 0.6))
	var lid := Node3D.new(); lid.name = "lid"; n.add_child(lid); lid.position = Vector3(0, 0.62, -0.4)
	U.box(lid, Vector3(1.22, 0.26, 0.82), Vector3(0, 0.13, 0.4), wood)
	for bx in [-0.5, 0.5]:
		U.box(lid, Vector3(0.1, 0.28, 0.86), Vector3(bx, 0.13, 0.4), U.solid(body_col, 0.0, 0.4, 0.6))
	U.box(lid, Vector3(0.18, 0.22, 0.06), Vector3(0, 0.05, 0.83), U.solid(Color(1, 0.85, 0.3), 0.5, 0.3, 1.0))
	var st := Label3D.new(); st.text = "★"; st.font = load("res://fonts/Symbols.ttf"); st.font_size = 96; st.pixel_size = 0.004
	st.modulate = Color(0.85, 0.1, 0.1); st.outline_size = 0; st.position = Vector3(0, 0.3, 0.41)
	n.add_child(st)
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
			var holder := Node3D.new(); n.add_child(holder); holder.position = Vector3(0, 2.2, 0)
			var st := Chars.build_hero(holder, char_id, 0)
			st.position = Vector3.ZERO      # build_hero places at the world origin; re-centre on the plinth
			st.scale *= 1.9
			st.rotation.y = rng.randf() * TAU
			var ap := U.anim_player(st)
			if ap and ap.has_animation("Cheer"):
				ap.play("Cheer"); ap.seek(0.55, true); ap.pause()
			for m in st.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = U.solid(Color(0.75, 0.12, 0.12), 0.0, 0.45, 0.3)
			world.obstacles.append(Rect2(p.x - 1.5, p.z - 1.5, 3, 3))
			_static_box(p + Vector3(0, 1.1, 0), Vector3(3, 2.2, 3))
			for fx in [-3.0, 3.0]:
				U.box(n, Vector3(0.15, 5.0, 0.15), Vector3(fx, 2.5, 0), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
				U.box(n, Vector3(2.4, 1.5, 0.05), Vector3(fx + 1.25, 4.2, 0), U.solid(Color(0.72, 0.05, 0.1)))
				var s2 := Label3D.new(); s2.text = "☭"; s2.font = load("res://fonts/Symbols.ttf"); s2.font_size = 128; s2.pixel_size = 0.008
				s2.modulate = Color(1, 0.8, 0.25); s2.outline_size = 0; s2.position = Vector3(fx + 1.25, 4.2, 0.05); s2.shaded = true
				n.add_child(s2)
		"file":
			for i in 6:
				U.cyl(n, 0.08, 1.0, Vector3(-3.5 + i * 1.4, 0.5, 2.5), U.solid(Color(0.75, 0.75, 0.78), 0.0, 0.3, 0.9))
			U.box(n, Vector3(7.0, 0.08, 0.05), Vector3(0, 0.85, 2.5), U.solid(Color(0.8, 0.1, 0.1)))
			U.box(n, Vector3(0.14, 1.7, 0.14), Vector3(0, 0.85, -0.12), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8))
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
			for px in [-1.65, 1.65]:
				for pz in [-0.6, 1.0]:
					U.box(n, Vector3(0.1, 2.55, 0.1), Vector3(px, 1.27, pz), U.solid(Color(0.25, 0.25, 0.27), 0.0, 0.4, 0.8))
			var gm := U.place(n, U.SHOP + "gacha-machine.glb", p + Vector3(2.4, 0, 0), 1.8, 0.0)
			var lamp := OmniLight3D.new(); lamp.light_color = col; lamp.light_energy = 1.5; lamp.omni_range = 5.0; lamp.position = Vector3(0, 2.2, 0.6)
			n.add_child(lamp)
			world.obstacles.append(Rect2(p.x - 1.6, p.z - 0.6, 3.2, 1.2)); _static_box(p + Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 1.2))
		"aimant":
			var fr := U.place(n, U.SHOP + "freezer.glb", p, 2.2, 0.0)
			var fa := U.world_aabb(fr)
			U.box(n, Vector3(1.6, 0.6, 0.1), Vector3(0, fa.end.y - p.y + 0.28, fa.end.z - p.z + 0.02), U.solid(Color(0.72, 0.05, 0.1)))
			world.obstacles.append(Rect2(p.x - 0.8, p.z - 0.6, 1.6, 1.2))
		"defi":
			U.box(n, Vector3(2.4, 1.2, 2.4), Vector3(0, 0.6, 0), U.solid(Color(0.3, 0.28, 0.25)))
			var g := Chars.build_enemy(n, "golden", p + Vector3(0, 1.2, 0), 3.2)
			Chars.attach(g, ["tophat", "cigar", "monocle"])
			var ap2 := U.anim_player(g)
			if ap2 and ap2.has_animation("Wave"):
				ap2.play("Wave"); ap2.seek(0.4, true); ap2.pause()
			for m in g.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = U.solid(Color(1.0, 0.72, 0.2), 0.0, 0.25, 1.0)
			world.obstacles.append(Rect2(p.x - 1.2, p.z - 1.2, 2.4, 2.4)); _static_box(p + Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 2.4))
	_beam(n, col)
	var lab := U.label(n, info[0], Vector3(0, 6.0 if kind == "statue" else 4.2, 0), 60, col, Color(0.05, 0.03, 0, 1))
	if kind == "statue": lab.position.y = 7.0
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
	Snd.play("break", -10.0, 0.15, 0.06)
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
	hud.show_screen("COMMUNISTE LAND",
		"Le capitalisme a gagné. Pas pour longtemps.\n\nDéplacement : ZQSD / flèches / stick gauche     Caméra : souris / A et R / stick droit\nSaut (double saut) : Espace / A     Glissade : Maj / B     Interagir : F / X\n\nTes armes tirent toutes seules. Casse les cartons, ouvre les coffres, active les sanctuaires.\nBats le Directeur à 08:00. À 10:00, c'est le Krach.",
		"ENTRÉE ou A pour commencer", Color(0.9, 0.15, 0.15))

func start():
	state = "play"
	Snd.music("boss" if zone >= 3 else "battle")
	hud.hide_screen()
	hud.set_hud_visible(true)
	if not bot: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.toast("ZONE %d · %s · %s" % [zone, tpl["name"].to_upper(), Meta.CHARACTERS[char_id]["name"].to_upper()], 2.5)
	if test_give != "":
		var ids: Array = Data.WEAPONS.keys() if test_give.begins_with("all") else Array(test_give.split(","))
		for id in ids:
			weapons.add_weapon(id)
			for i in Data.EVO_MIN_LV - weapons.level(id): weapons.upgrade(id, {"dmg": 0.1})
			if test_give.ends_with("evo"): weapons.evolve(id)
		if test_give.ends_with("evo"):
			for f in Data.FUSIONS:
				if weapons.can_fuse(f): weapons.fuse(f)
	var sl := int(mods.get("start_level", 0.0))
	if carried: sl = 0
	elif zone > 1: sl += 12 * (zone - 1)     # starting directly in a later zone: catch-up levels
	if sl > 0:
		level += sl
		pending_levels += sl
		_open_levelup()

func _unhandled_input(ev: InputEvent):
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and state == "play":
		player.cam_yaw -= clampf(ev.relative.x, -60.0, 60.0) * 0.0025
		cam_pitch = clampf(cam_pitch + clampf(ev.relative.y, -60.0, 60.0) * 0.0022, PITCH_MIN, PITCH_MAX)

func _process(d: float):
	if cam_rig == null or player == null or hud == null: return
	var rd := minf(d, 0.05)
	match state:
		"loading", "dying":
			_update_camera(rd)
			return
		"menu":
			cam_rig.rotation.y += rd * 0.1
			cam_rig.global_position = player.global_position
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("jump"): start()
			return
		"over", "win":
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("restart"):
				_back_to_hub()
			_bot_tick(d)
			return
		"paused":
			if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("confirm"): _unpause()
			elif Input.is_action_just_pressed("restart"):
				game_over(true)
			return
		"choice":
			if Input.is_action_just_pressed("reroll") and rerolls > 0 and choice_source in ["level", "shrine"]:
				rerolls -= 1
				var n: int = hud.options.size()
				var mr := 1 if hud.options.size() > 0 and choice_source == "shrine" else 0
				var opts := _roll_options(n, mr)
				if not opts.is_empty(): hud.show_choices(hud.choice_title.text, opts, "")
			if Input.is_action_just_pressed("banish") and banishes > 0 and choice_source in ["level", "shrine", "market"] and hud.sel < hud.options.size():
				var o: Dictionary = hud.options[hud.sel]
				if o["kind"] != "pack":
					banishes -= 1
					banned[_ban_key(o)] = true
					hud.toast("BANNI : %s (pour toute la run)" % o["title"], 1.5)
					var keep := []
					for i in hud.options.size():
						if i != hud.sel: keep.append(hud.options[i])
					var ex := []
					for k in keep: ex.append(_ban_key(k))
					var rep := _roll_options(1, 1 if choice_source == "shrine" else 0, 0, ex)
					if choice_source == "market":
						for r in rep: r["cost"] = int((22 + 14 * market_buys) * (1.0 + 0.5 * r["rarity"]))
					var newopts := []
					for i in hud.options.size():
						if i == hud.sel:
							if not rep.is_empty(): newopts.append(rep[0])
						else:
							newopts.append(hud.options[i])
					hud.show_choices(hud.choice_title.text, newopts, hud.leave_label)
			if Input.is_action_just_pressed("skip") and skips > 0 and choice_source in ["level", "shrine"]:
				skips -= 1
				rubles += 8
				hud.toast("CARTES PASSÉES · +8 ROUBLES", 1.2)
				_on_chosen(-2)
				return
			if bot:
				choice_wait -= d / maxf(Engine.time_scale, 0.001)
				if choice_wait <= 0.0: _on_chosen(_bot_pick())
			_bot_tick(d)
			return
	if Input.is_action_just_pressed("pause"):
		_pause(); return
	if Input.is_action_just_pressed("minimap"):
		Meta.set_opt("minimap", 0.0 if Meta.opt("minimap") > 0.0 else 1.0)
		hud.toast("MINI-CARTE " + ("ACTIVÉE" if Meta.opt("minimap") > 0.0 else "DÉSACTIVÉE · TAB POUR LA GRANDE CARTE"), 1.2)
	if Input.is_action_just_pressed("ultimate") or (bot and ult_kills >= ultimate_cost() and enemies.count() > 25):
		_try_ultimate()
	ult_t = maxf(0.0, ult_t - rd)
	time += rd
	var yaw_in := Input.get_axis("cam_left", "cam_right")
	cam_pitch = clampf(cam_pitch + Input.get_axis("cam_up", "cam_down") * 1.2 * rd, PITCH_MIN, PITCH_MAX)
	player.cam_yaw -= yaw_in * 2.2 * rd
	_update_camera(rd)
	_director(rd)
	_events(rd)
	_update_pickups(rd)
	_update_interactions(rd)
	_update_door()
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
	var off := cam_offset()
	var want: Vector3 = cam_rig.global_transform * off
	var q := PhysicsRayQueryParameters3D.create(head, want, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var k := 1.0
	if not hit.is_empty():
		k = clampf((head.distance_to(hit["position"]) - 0.8) / head.distance_to(want), 0.15, 1.0)
	cam_k = minf(k, cam_k + d * 2.0) if k > cam_k else k
	var pivot := Vector3(0, 1.6, 0)
	var local := pivot + (off - pivot) * cam_k
	cam.position = local + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amt
	cam.basis = Basis.looking_at(cam_look().lerp(Vector3(0, 1.0, -3.0), 1.0 - cam_k) - local, Vector3.UP)

func shake(a: float):
	shake_amt = minf(0.5, shake_amt + a * Meta.opt("shake") / 100.0)

func _pause():
	state = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lines := []
	for id in weapons.owned:
		var w: Dictionary = weapons.owned[id]
		lines.append("%s niv %d%s" % [weapons.display_name(id), w["lv"], " ★" if w["evo"] else ""])
	var dl := []
	for id in decrets:
		dl.append("%s (%s)" % [Data.DECRETS[id]["name"], Data.decret_text(id, dv(id))])
	hud.show_screen("PAUSE", "Niveau %d · %d KO · %s\n\nArmes : %s\nDécrets : %s" % [level, kills, _fmt(time), ", ".join(lines), ", ".join(dl) if not dl.is_empty() else "aucun"], "Échap : reprendre · Retour arrière : abandonner")
	hud.screen_buttons([["REPRENDRE", _unpause], ["ABANDONNER LA RUN", func(): game_over(true)]])

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
		if world.inside(p) and world.plateau_at(p) < 0:
			return world.resolve(p, 0.6)
	return world.resolve(Vector3(pp.x + min_d, 0, pp.z), 0.6)

# difficulty clock: zone time plus an offset per zone already crossed
func dtime() -> float:
	return time + (zone - 1) * ZONE_OFFSET

func mults() -> Array:
	var tm := dtime() / 60.0
	var t: Dictionary = Meta.TIERS[tier - 1]
	var hp := (1.0 + 0.36 * tm + 0.12 * tm * tm + 0.014 * tm * tm * tm) * (1.0 + 0.2 * bets) * (1.0 + 0.25 * dirl("productivisme")) * float(t["hp"])
	return [hp, (1.0 + 0.1 * tm) * (1.0 + 0.25 * dirl("sans_pitie")) * float(t["dmg"])]

func enemy_speed_mult() -> float:
	return 0.55 if event_name == "greve" else 1.0

# the horde stays mowable (fodder scales slower) and shooters are capped, so the player keeps hunting
const FODDER := ["stagiaire", "cadre"]
const SHOOTERS := ["influenceur", "banquier"]
func _spawn_picked(p: Vector3, m: Array):
	var kind := _pick_kind()
	if kind in SHOOTERS:
		var n := 0
		for e in enemies.alive_list():
			if e.kind in SHOOTERS: n += 1
		if n >= int(5 + minf(dtime() / 150.0, 6.0)): kind = "cadre" if rng.randf() < 0.5 else "stagiaire"
	var hp: float = m[0]
	if kind in FODDER: hp = pow(hp, 0.82)
	enemies.spawn(kind, p, hp, m[1])

func _pick_kind() -> String:
	var tm := dtime() / 60.0
	var total := 0.0
	var pool := []
	for row in Data.SPAWN_TABLE:
		if dtime() < row[1]: continue
		var w: float = row[2] + row[3] * maxf(0.0, tm - row[1] / 60.0)
		pool.append([row[0], w]); total += w
	var r := rng.randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0: return p[0]
	return "stagiaire"

func _director(d: float):
	var tm := dtime() / 60.0
	var m := mults()
	var cap := 260 if not krach else 320
	var rate := (1.1 + 0.9 * tm + 0.19 * tm * tm) * (1.0 + 0.15 * bets) * (1.0 + 0.25 * dirl("cadence")) * float(Meta.TIERS[tier - 1]["rate"])
	if krach: rate *= 2.2
	spawn_acc += rate * d
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if enemies.count() >= cap: break
		_spawn_picked(spawn_point(20.0, 30.0), m)
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
		enemies.spawn("golden", spawn_point(18.0, 22.0), m[0] * (1.05 if dirl("opa") > 0 else 0.7), m[1])
		hud.toast("UN GOLDEN BOY APPROCHE · IL TRANSPORTE UN COFFRE", 2.5)
	if not boss_spawned and time >= BOSS_TIME:
		boss_spawned = true
		var bk: String = tpl["boss"]
		Snd.music("boss", 2.0); Snd.play("explosion", 0.0, 0.0, 1.0, 0.6)
		var zl := 1.0 + 1.2 * floorf((zone - 1) / 3.0)     # endless: bosses get tougher every loop
		boss = enemies.spawn(bk, spawn_point(20.0, 24.0), (1.0 + 0.2 * bets) * zl * float(Meta.TIERS[tier - 1]["hp"]), float(Meta.TIERS[tier - 1]["dmg"]))
		hud.toast("%s ARRIVE" % Data.ENEMIES[bk]["name"].to_upper(), 3.0)
		if test_killboss: get_tree().create_timer(3.0, false).timeout.connect(func(): if boss.alive: enemies.kill(boss))
		shake(0.4)
	if not krach and time >= (420.0 if dirl("surveillance") > 0 else ZONE_TIME):
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
			for i in int(30 + dtime() / 20.0):
				var p: Vector3 = player.global_position + Vector3(cos(a), 0, sin(a)) * 24.0 + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
				enemies.spawn("trader" if i % 4 == 0 else "stagiaire", world.resolve(p, 0.5), m[0] * 0.7, m[1])
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
	if warming: return
	kills += 1
	ult_kills += 1
	kills_by_kind[e.kind] = int(kills_by_kind.get(e.kind, 0)) + 1
	if e.last_w != "": kills_by_weapon[e.last_w] = int(kills_by_weapon.get(e.last_w, 0)) + 1
	if e.elite:
		elites_killed += 1
		stamp(e.node.position + Vector3(0, 3.0, 0), ["LIQUIDÉ !", "NATIONALISÉ !", "REDISTRIBUÉ !"][randi() % 3])
	if char_id == "barbudo" and ult_t > 0.0 and not e.boss:
		var bp: Vector3 = e.node.position
		weapons._blast(bp, 2.6, 30.0 + 6.0 * level, {"crit": 0.1, "id": ""}, Color(1, 0.4, 0.15), false)
	spark(e.node.position + Vector3(0, 1.0, 0), true)
	_drop_gem(e.node.position, e.xp)
	var luck := 1.0 + dv("chance") / 100.0
	if rng.randf() < 0.012 * luck and dirl("rationnement") == 0:
		_drop_heal(e.node.position + Vector3(-0.5, 0, 0.3))
	if rng.randf() < 0.06 * luck or e.elite:
		_drop_coin(e.node.position + Vector3(0.6, 0, 0), 30 if e.elite else rng.randi_range(2, 5))
	if e.elite:
		_make_chest(e.node.position + Vector3(-0.8, 0, 0), true)
		hud.toast("LE GOLDEN BOY A LÂCHÉ UN COFFRE", 2.0)
	if e.boss:
		_boss_down(e)

func on_player_hit(amount: float):
	hud.hurt()
	shake(0.15)
	if player.hp > 0.0 and player.hp < player.max_hp * 0.3 and time > slowmo_cd and not bot:
		slowmo_cd = time + 12.0
		hud.toast("PV CRITIQUES !", 1.0)
		Engine.time_scale = base_time_scale * 0.3
		get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Engine.time_scale = base_time_scale)

func _on_landed(fall_speed: float):
	weapons.on_landed(fall_speed)

func damage_number(pos: Vector3, amt: float, crit: bool, resisted := false):
	var mode := int(Meta.opt("numbers"))
	if mode == 0 or (mode == 1 and not crit): return
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

# comic onomatopoeia (poster/comic identity); rate-limited so it never floods the screen
var _word_t := 0.0
var _word_font: Font
func pop_word(pos: Vector3, text: String, col: Color, size := 1.0, force := false):
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now < _word_t: return
	_word_t = now + 0.35
	if _word_font == null: _word_font = load("res://fonts/Bangers.woff2")
	var l := Label3D.new()
	l.text = text; l.font = _word_font; l.font_size = 96
	l.pixel_size = 0.012 * size
	l.modulate = col
	l.outline_modulate = Color(0.06, 0.04, 0.03, 1); l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.rotation.z = randf_range(-0.25, 0.25)
	add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.2
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.06)
	tw.tween_interval(0.35)
	tw.parallel().tween_property(l, "position:y", l.position.y + 0.8, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.18)
	tw.tween_callback(l.queue_free)

func stamp(pos: Vector3, text: String):
	Snd.play("stamp", -2.0, 0.05, 0.1); Snd.play("bell", -12.0, 0.05, 0.3)
	pop_word(pos, text, Color(0.85, 0.08, 0.1), 1.4, true)

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
	mi.global_position = Vector3(p.x, p.y + 0.35, p.z)
	gems.append({"n": mi, "v": val, "pull": false, "spd": 0.0, "y0": p.y + 0.35})

func _drop_coin(p: Vector3, val: int):
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 0.22; cy.bottom_radius = 0.22; cy.height = 0.06
	mi.mesh = cy
	mi.material_override = U.solid(Color(1, 0.78, 0.25), 1.2, 0.3, 1.0)
	mi.rotation.x = PI / 2
	add_child(mi)
	mi.global_position = Vector3(p.x, p.y + 0.4, p.z)
	coins.append({"n": mi, "v": val, "pull": false, "spd": 0.0, "y0": p.y + 0.4})

func _drop_heal(p: Vector3):
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(p.x, p.y + 0.4, p.z)
	U.box(n, Vector3(0.5, 0.14, 0.4), Vector3.ZERO, U.solid(Color(0.85, 0.6, 0.3)))
	U.box(n, Vector3(0.44, 0.04, 0.34), Vector3(0, 0.09, 0), U.solid(Color(0.95, 0.2, 0.25), 0.6))
	coins.append({"n": n, "v": 0, "heal": 25.0, "pull": false, "spd": 0.0, "y0": p.y + 0.4})

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
					if arr == gems:
						add_xp(g["v"])
						Snd.play("gem", -16.0, 0.0, 0.035, 0.9 + minf(float(g["v"]), 10.0) * 0.04 + randf() * 0.15)
					elif g.has("heal"):
						var hh: float = g["heal"] * (1.0 + mods.get("heal_pickup", 0.0) / 100.0)
						player.heal(hh)
						hud.toast("TARTINE · +%d PV" % int(hh), 1.0)
					else:
						Snd.play("coin", -10.0, 0.1, 0.06)
						rubles += int(ceil(g["v"] * (1.0 + 0.35 * bets) * (1.0 + mods.get("rubles_pct", 0.0) / 100.0) * (0.6 if dirl("inflation") > 0 else 1.0)))
			else:
				n.rotation.y = t * 2.0
				n.position.y = g.get("y0", 0.35) + sin(t * 3.0 + n.position.x) * 0.08
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
		if not c["free"]: c["label"].text = "%d RBL" % chest_price()
	for c in chests:
		if c["n"].global_position.distance_to(pp) < 2.4:
			var cost := 0 if c["free"] else chest_price()
			prompt = "F / X : OUVRIR LE COFFRE" + ("" if cost == 0 else " (%d RBL)" % cost) + ("" if rubles >= cost else " · PAS ASSEZ DE ROUBLES")
			if act and rubles >= cost:
				rubles -= cost
				if not c["free"]: chest_cost = int(chest_cost * 1.45) + 4
				chests.erase(c)
				_chest_open_fx(c["n"])
				Snd.play("chest", -2.0, 0.05, 0.2); Snd.play("coin", -6.0, 0.1, 0.0, 0.8)
				player.oneshot("interact", 0.5, 1.6)
				chests_opened += 1
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
							_spawn_picked(world.resolve(s["pos"] + Vector3(cos(a), 0, sin(a)) * 15.0, 0.5), m)
			_:
				if s["used"] and s["kind"] != "marche": continue
				if dist < 3.5 and s["cd"] <= 0.0:
					prompt = "F / X : " + SHRINE_INFO[s["kind"]][0] + " · " + SHRINE_INFO[s["kind"]][2]
					if act: _activate(s)
	hud.prompt(prompt)

func _use_shrine(s: Dictionary):
	player.oneshot("interact", 0.5, 1.6)
	if not s["used"]: shrines_used += 1
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
			if opts.size() >= 3: opts.pop_back()
			for o in opts:
				o["cost"] = int((22 + 14 * market_buys) * (1.0 + 0.5 * o["rarity"]))
			opts.append({"kind": "pack", "id": "pack", "rarity": 1, "tag": "PAPERASSE", "title": "Dossier administratif", "lv": "Charges de choix", "desc": "+2 relances\n+1 bannissement\n+1 passer", "short": "charges", "cost": 25 + 10 * market_buys})
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

func _ban_key(o: Dictionary) -> String:
	return ("d:" if o["kind"] == "decret" else "w:") + str(o.get("id", ""))

func _roll_options(n: int, min_r := 0, bonus := 0, exclude: Array = []) -> Array:
	var pool := []
	for id in weapons.owned:
		if weapons.can_evolve(id):
			pool.append({"kind": "evo", "id": id, "w": 4.0})
		elif weapons.level(id) < Data.MAX_WEAPON_LV:
			pool.append({"kind": "weapon_up", "id": id, "w": 1.3})
		else:
			pool.append({"kind": "surcharge", "id": id, "w": 0.8})
	for f in Data.FUSIONS:
		if weapons.can_fuse(f):
			pool.append({"kind": "fusion", "id": f, "w": 4.0})
	if weapons.slot_ids().size() < weapon_slots() and not "solo" in OS.get_cmdline_user_args():
		for id in Data.WEAPONS:
			if not weapons.owned.has(id) and Meta.weapon_unlocked(id):
				pool.append({"kind": "weapon_new", "id": id, "w": 0.7})
	for id in decrets:
		if decrets[id]["n"] < Data.DECRET_MAX_PICKS:
			pool.append({"kind": "decret", "id": id, "w": 1.0})
	if decrets.size() < Data.DECRET_SLOTS:
		for id in Data.DECRETS:
			if not decrets.has(id):
				pool.append({"kind": "decret", "id": id, "w": 0.45})
	for sid in SURPLUS:
		pool.append({"kind": "surplus", "id": sid, "w": 0.12})
	var filtered := []
	for o in pool:
		var k := _ban_key(o)
		if banned.has(k) or exclude.has(k): continue
		filtered.append(o)
	pool = filtered
	var out := []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for o in pool: total += o["w"]
		var r := rng.randf() * total
		var chosen = pool[pool.size() - 1]     # fallback: float rounding must never leave the loop without a pick
		for o in pool:
			r -= o["w"]
			if r <= 0.0:
				chosen = o; break
		out.append(chosen); pool.erase(chosen)
	for o in out:
		o["rarity"] = roll_rarity(min_r, bonus) if not o["kind"] in ["evo", "fusion"] else 3
		_describe(o)
	return out

# endless "Surplus du Plan" cards: once everything is maxed, chests and levels still pay off
const SURPLUS := {
	"productivite": ["SURPLUS DE PRODUCTION", "+%d %% de dégâts", 6.0],
	"cadence": ["HEURES SUPPLÉMENTAIRES", "+%d %% de cadence", 5.0],
	"endurance": ["RATIONS DOUBLES", "+%d PV max (et soin)", 15.0],
	"regen": ["SOUPE AU CHOU", "+%.1f PV/s", 0.35],
	"critique": ["ZÈLE RÉVOLUTIONNAIRE", "+%d %% de critique", 3.0],
	"crit_dmg": ["COUP DE GRÂCE", "+%d %% de dégâts critiques", 15.0],
	"aimant": ["AIMANT DU PARTI", "+%d %% de ramassage", 15.0],
	"vitesse": ["STAKHANOVISME", "+%d %% de vitesse", 3.0],
}

func _describe(o: Dictionary):
	var r: int = o["rarity"]
	match o["kind"]:
		"surplus":
			var sp: Array = SURPLUS[o["id"]]
			var v: float = sp[2] * Data.RARITY_MULT[r]
			o["value"] = v
			o["title"] = sp[0]
			o["tag"] = "SURPLUS DU PLAN · " + Data.RARITIES[r]
			o["lv"] = "Sans limite"
			o["desc"] = (sp[1] as String) % (v if o["id"] == "regen" else roundi(v))
			o["short"] = o["desc"]
		"surcharge":
			var v2: float = 0.12 * Data.RARITY_MULT[r]
			o["value"] = v2
			o["title"] = "SURCHARGE · " + weapons.display_name(o["id"]).to_upper()
			o["tag"] = "ARME AU MAXIMUM · " + Data.RARITIES[r]
			o["lv"] = "Surcharge"
			o["desc"] = "+%d %% de dégâts et +%d %% de cadence pour cette arme." % [roundi(v2 * 100), roundi(v2 * 40)]
			o["short"] = o["desc"]
		"evo":
			var w: Dictionary = Data.WEAPONS[o["id"]]
			o["title"] = w["evo_name"]
			o["tag"] = "ÉVOLUTION · %s + %s" % [w["name"].to_upper(), Data.DECRETS[w["evo"]]["name"].to_upper()]
			o["lv"] = "Arme ultime"
			o["desc"] = w["evo_desc"]
			o["short"] = "évolution"
		"fusion":
			var fu: Dictionary = Data.FUSIONS[o["id"]]
			o["title"] = fu["name"]
			o["tag"] = "FUSION · %s + %s" % [(Data.WEAPONS[fu["a"]]["name"] as String).to_upper(), (Data.WEAPONS[fu["b"]]["name"] as String).to_upper()]
			o["lv"] = "Libère un emplacement"
			o["desc"] = fu["desc"] + "\n\nLes deux armes continuent de tirer (+25 % de dégâts) mais n'occupent plus qu'un emplacement."
			o["short"] = "fusion"
		"weapon_new":
			var w: Dictionary = Data.WEAPONS[o["id"]]
			o["title"] = w["name"]
			o["tag"] = "NOUVELLE ARME"
			o["lv"] = "Niveau 1"
			o["desc"] = w["desc"] + "\n\nÉvolue avec : " + Data.DECRETS[w["evo"]]["name"]
			var fid := Data.fusion_of(o["id"])
			if fid != "":
				var fd: Dictionary = Data.FUSIONS[fid]
				o["desc"] += "\nFusionne avec : " + Data.WEAPONS[fd["b"] if fd["a"] == o["id"] else fd["a"]]["name"]
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
		"pack":
			rerolls += 2; banishes += 1; skips += 1
		"fusion":
			Snd.play("evolve", 0.0, 0.0, 0.3)
			got_evo = true
			weapons.fuse(o["id"])
			hud.toast("FUSION : " + (Data.FUSIONS[o["id"]]["name"] as String).to_upper(), 3.0)
		"evo":
			Snd.play("evolve", 0.0, 0.0, 0.3)
			got_evo = true
			weapons.evolve(o["id"])
			hud.toast("ÉVOLUTION : " + Data.WEAPONS[o["id"]]["evo_name"].to_upper(), 3.0)
		"weapon_new":
			weapons.add_weapon(o["id"])
		"weapon_up":
			if not o.has("mods"): _describe(o)
			weapons.upgrade(o["id"], o["mods"])
		"surcharge":
			if not o.has("value"): _describe(o)
			if bot: print("[surcharge] %s" % o["id"])
			var wm: Dictionary = weapons.owned[o["id"]]["mods"]
			wm["dmg"] = wm.get("dmg", 0.0) + o["value"]
			wm["cd"] = wm.get("cd", 0.0) + o["value"] * 0.4
		"surplus":
			if not o.has("value"): _describe(o)
			if bot: print("[surplus] %s +%.1f" % [o["id"], o["value"]])
			var sv: float = o["value"]
			if o["id"] == "endurance":
				player.max_hp += sv; player.heal(sv)
			else:
				mods[o["id"]] = mods.get(o["id"], 0.0) + sv
		"decret":
			var v: float = o.get("value", Data.decret_value(o["id"], o["rarity"]))
			if not decrets.has(o["id"]): decrets[o["id"]] = {"n": 0, "v": 0.0}
			decrets[o["id"]]["n"] += 1
			decrets[o["id"]]["v"] += v
			if o["id"] == "endurance":
				player.max_hp += v
				player.heal(v)

func _open_levelup():
	Snd.play("levelup", -6.0, 0.0, 0.3)
	var opts := _roll_options(2 if dirl("bureaucratie") > 0 else 3)
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
	Snd.play("ui_confirm", -6.0, 0.03, 0.1)
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

# ---------------------------------------------------------------- ultimate
func _try_ultimate():
	if ult_kills < ultimate_cost(): return
	player.oneshot("cast", 0.7, 1.4)
	ult_kills = 0
	ult_uses += 1
	var pw: float = 1.0 + mods.get("ult_power", 0.0) / 100.0
	var pp: Vector3 = player.global_position
	match char_id:
		"stakhanov":
			ult_t = 6.0
			hud.toast("SURPRODUCTION !", 1.5)
		"ilitch":
			var dur: float = (3.0 + mods.get("ult_stun", 0.0)) * pw
			for e in enemies.in_radius(pp, 22.0):
				enemies.stun(e, dur, true)
				e.vuln_t = dur
			hud.toast("DISCOURS AU PEUPLE !", 1.5)
			weapons._ring_fx(pp, 22.0, Color(1, 0.8, 0.3))
		"moustache":
			player.hp = maxf(1.0, player.hp * 0.85)
			var n := 0
			for e in enemies.in_radius(pp, 14.0 * pw):
				if not e.elite and not e.boss and not e.invincible:
					enemies.kill(e); n += 1
			hud.toast("GRANDE PURGE · %d CAPITALISTES DISPARUS" % n, 2.0)
			weapons._ring_fx(pp, 14.0 * pw, Color(0.8, 0.1, 0.1))
		"babouchka":
			player.hp = player.max_hp
			player.invuln = 4.0 * pw
			hud.toast("ELLE A CONNU PIRE !", 1.5)
		"barbudo":
			ult_t = 8.0 * pw
			hud.toast("¡VIVA LA REVOLUCIÓN !", 1.5)
		"natacha":
			for g in gems: g["pull"] = true
			var ts: Dictionary = weapons.stats("tracteur") if weapons.owned.has("tracteur") else {"dmg": 30.0 + 4.0 * level, "area": 1.8, "speed": 18.0, "range": 26.0, "crit": 0.1, "id": "tracteur", "count": 1}
			ts["dmg"] = ts["dmg"] * 2.0 * pw
			for k in 8:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
				weapons._tractor(pp, dir, ts)
			hud.toast("MOISSON COLLECTIVE !", 1.5)
		"vodkine":
			player.heal(player.max_hp * 0.4 * pw)
			ult_t = 6.0
			hud.toast("TOURNÉE DU SERGENT !", 1.5)
		"tamara":
			var dir: Vector3 = player.facing
			player.invuln = 1.6
			player.velocity = dir * 22.0
			var hit_dmg: float = (80.0 + 14.0 * level) * pw
			for e in enemies.alive_list().duplicate():
				var v: Vector3 = e.node.position - pp; v.y = 0
				var along := v.dot(dir)
				if along > -1.0 and along < 14.0 and (v - dir * along).length() < 2.4:
					enemies.damage(e, hit_dmg, pp, 16.0, "", true, true, 0.2, "")
			weapons._ring_fx(pp + dir * 7.0, 4.0, Color(0.6, 0.7, 0.4))
			hud.toast("PERCÉE BLINDÉE !", 1.5)
		"mikhail":
			ult_t = 10.0 * pw
			hud.toast("LA TAÏGA SE RÉVEILLE !", 1.5)
		"timonier":
			for e in enemies.in_radius(pp, 20.0):
				if e.invincible: continue
				enemies.damage(e, e.max_hp * (0.2 if not e.boss else 0.04) * pw, pp, 6.0, "", true, true, 0.0, "")
			weapons._ring_fx(pp, 20.0, Color(1, 0.2, 0.15))
			hud.toast("GRAND BOND EN AVANT !", 1.5)
		"lev":
			var rs: Dictionary = weapons.stats("rideau") if weapons.owned.has("rideau") else {"dmg": 20.0 + 3.0 * level, "area": 4.0, "duration": 6.0, "crit": 0.1, "id": "rideau"}
			rs["duration"] = 6.0 * pw
			for k in 8:
				var a := TAU * k / 8.0
				var c := pp + Vector3(cos(a), 0, sin(a)) * 7.0
				weapons._wall(c, Vector3(-sin(a), 0, cos(a)), rs)
			hud.toast("LE MUR DE LA HONTE SE DRESSE !", 1.5)
		"svetlana":
			var ms: Dictionary = weapons.stats("molotov") if weapons.owned.has("molotov") else {"dmg": 10.0 + 2.0 * level, "area": 2.6, "duration": 4.0, "crit": 0.1, "id": "molotov"}
			ms["dmg"] = ms["dmg"] * 1.5 * pw
			for k in 12:
				var a := TAU * k / 12.0
				weapons._spawn_fire(pp + Vector3(cos(a), 0, sin(a)) * (4.0 + (k % 2) * 4.0), ms)
			hud.toast("GRAND INCENDIE !", 1.5)
		"dmitri":
			var dur2: float = 4.0 * pw
			for e in enemies.in_radius(pp, 18.0):
				enemies.stun(e, dur2, true)
				e.vuln_t = dur2
			hud.toast("KALINKA ! TOUT LE MONDE DANSE !", 1.5)
		"valentina":
			var es: Dictionary = weapons.stats("etoile") if weapons.owned.has("etoile") else {"dmg": 90.0 + 10.0 * level, "area": 2.2, "crit": 0.2, "id": "etoile"}
			es["dmg"] = es["dmg"] * 1.5 * pw
			var tg: Array = weapons._toughest(pp, 26.0, 12)
			for k in tg.size():
				var e = tg[k]
				get_tree().create_timer(0.08 * k, false).timeout.connect(func(): if e.alive: weapons._star(e.node.position + Vector3(2, 16, 2), e.node.position, es))
			hud.toast("PLUIE DE MÉTÉORES !", 1.5)
		"youri":
			var best: Vector3 = pp + player.facing * 6.0
			var bn := -1
			var cand: Array = enemies.in_radius(pp, 18.0)
			for i in mini(24, cand.size()):
				var e = cand[randi() % cand.size()]
				var nb: int = enemies.in_radius(e.node.position, 5.0).size()
				if nb > bn: bn = nb; best = e.node.position
			var tgt: Vector3 = Vector3(best.x, 0, best.z)
			enemies._telegraph_circle(tgt, 7.0, 0.8)
			hud.toast("RETOUR SUR TERRE !", 1.5)
			var dmg: float = (500.0 + 90.0 * level) * pw
			var cap := Node3D.new()
			add_child(cap)
			cap.global_position = tgt + Vector3(4, 30, 4)
			U.sphere(cap, 1.3, Vector3.ZERO, U.solid(Color(0.75, 0.75, 0.72), 0.0, 0.4, 0.8))
			U.label(cap, "CCCP", Vector3(0, 0, 1.35), 120, Color(0.85, 0.1, 0.1), Color(0, 0, 0, 0), false)
			U.sprite(cap, "flame_02.png", Vector3(0, 1.4, 0), 3.0, Color(1, 0.5, 0.2), 3.0)
			var tw := cap.create_tween()
			tw.tween_property(cap, "global_position", tgt + Vector3(0, 1.0, 0), 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func():
				for e in enemies.in_radius(tgt, 7.0):
					enemies.damage(e, dmg, tgt, 14.0, "", true, true, 0.2, "")
					if e.alive: enemies.stun(e, 2.0 * pw, true)
				weapons._ring_fx(tgt, 7.0, Color(1, 0.6, 0.3))
				shake(0.45))
			tw.tween_interval(1.5)
			tw.tween_callback(cap.queue_free)
	shake(0.3)

# ---------------------------------------------------------------- zones
func _boss_down(e):
	bosses_killed.append(zone)
	if zone >= 3 and not endless:
		_win()
		return
	# the way to the next zone opens near where the boss fell
	var p: Vector3 = world.resolve(e.node.position, 2.0)
	if not world.inside(p): p = world.player_start
	_open_door(p)
	player.oneshot("cheer", 1.6, 1.0)
	var nxt: Dictionary = Levels.zone(zone + 1)
	hud.toast("%s EST BONKÉ ! LA PORTE VERS %s EST OUVERTE" % [Data.ENEMIES[e.kind]["name"].to_upper(), nxt["name"].to_upper()], 4.0)
	player.heal(player.max_hp * 0.3)

func _open_door(p: Vector3):
	Snd.play("door", 0.0, 0.0, 1.0); Snd.play("evolve", -4.0, 0.0, 1.0)
	door = Node3D.new()
	add_child(door)
	door.global_position = Vector3(p.x, 0, p.z)
	var red := U.solid(Color(0.75, 0.06, 0.08), 0.0, 0.6)
	U.box(door, Vector3(0.6, 5.0, 0.6), Vector3(-2.0, 2.5, 0), red)
	U.box(door, Vector3(0.6, 5.0, 0.6), Vector3(2.0, 2.5, 0), red)
	U.box(door, Vector3(4.6, 0.7, 0.7), Vector3(0, 5.2, 0), red)
	var star := Label3D.new(); star.text = "★"; star.font = load("res://fonts/Symbols.ttf"); star.font_size = 256; star.pixel_size = 0.006
	star.modulate = Color(1, 0.8, 0.2); star.outline_size = 0; star.position = Vector3(0, 6.3, 0); star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	door.add_child(star)
	U.sprite(door, "circle_03.png", Vector3(0, 0.08, 0), 5.0, Color(1, 0.3, 0.2, 0.7), 2.5, false, Vector3(-PI / 2, 0, 0))
	U.sprite(door, "light_01.png", Vector3(0, 2.4, 0), 4.0, Color(1, 0.45, 0.3, 0.7), 3.0)
	_beam(door, Color(1, 0.3, 0.2), 40.0)
	U.label(door, "VERS LA ZONE %d" % (zone + 1), Vector3(0, 7.6, 0), 96, Color(1, 0.9, 0.6), Color(0, 0, 0, 1))

func _update_door():
	if door == null: return
	var v: Vector3 = player.global_position - door.global_position
	v.y = 0
	if v.length() < 2.6: _next_zone()

func _next_zone():
	if state != "play": return
	state = "loading"
	get_tree().paused = true
	Meta.carry = _snapshot()
	Meta.run_zone = zone + 1
	print("[game] ZONE %d -> %d t=%s level=%d kills=%d" % [zone, zone + 1, _fmt(run_time + time), level, kills])
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _snapshot() -> Dictionary:
	return {"owned": weapons.owned.duplicate(true), "decrets": decrets.duplicate(true), "level": level, "xp": xp, "rubles": rubles,
		"kills": kills, "kills_by_kind": kills_by_kind.duplicate(), "kills_by_weapon": kills_by_weapon.duplicate(), "dmg_by_weapon": dmg_by_weapon.duplicate(),
		"elites": elites_killed, "chests": chests_opened, "shrines": shrines_used, "evo": got_evo, "rerolls": rerolls, "banishes": banishes, "skips": skips,
		"banned": banned.duplicate(), "revives": revives, "ult_kills": ult_kills, "ult_uses": ult_uses, "hp": player.hp, "max_hp": player.max_hp, "run_time": run_time + time,
		"bosses": bosses_killed.duplicate(), "market_buys": market_buys, "mods": mods.duplicate()}

func _restore(c: Dictionary):
	carried = true
	for id in c["owned"]:
		weapons.add_weapon(id)
		weapons.owned[id] = (c["owned"][id] as Dictionary).duplicate(true)
	decrets = c["decrets"]; level = c["level"]; xp = c["xp"]; rubles = c["rubles"]; kills = c["kills"]
	kills_by_kind = c["kills_by_kind"]; kills_by_weapon = c["kills_by_weapon"]; dmg_by_weapon = c["dmg_by_weapon"]
	elites_killed = c["elites"]; chests_opened = c["chests"]; shrines_used = c["shrines"]; got_evo = c["evo"]
	rerolls = c["rerolls"]; banishes = c["banishes"]; skips = c["skips"]; banned = c["banned"]; revives = c["revives"]
	ult_kills = c["ult_kills"]; ult_uses = c["ult_uses"]; run_time = c["run_time"]; bosses_killed = c["bosses"]
	market_buys = c.get("market_buys", 0)
	if c.has("mods"): mods = c["mods"]      # includes "Surplus du Plan" bonuses
	player.max_hp = c["max_hp"]
	player.hp = player.max_hp     # a new zone: the Party grants a full meal

# ---------------------------------------------------------------- end
func game_over(abandon := false):
	if state == "over": return
	if revives > 0 and not abandon:
		revives -= 1
		player.hp = player.max_hp * 0.5
		player.invuln = 3.0
		for e in enemies.in_radius(player.global_position, 10.0):
			if not e.boss and not e.invincible: enemies.kill(e)
		hud.toast("SECONDE CHANCE · LE PARTI TE RESSUSCITE", 2.5)
		return
	if not abandon and state == "play":
		# the comrade falls first, in slow motion, then the report appears
		state = "dying"
		player.oneshot("death", 9.0, 1.0)
		hud.set_hud_visible(false)
		Engine.time_scale = base_time_scale * 0.45
		get_tree().create_timer(1.6, true, false, true).timeout.connect(func():
			Engine.time_scale = base_time_scale
			_finish_over())
		return
	_finish_over()

func _finish_over():
	Snd.stop_music(0.3); Snd.music("defeat", 0.2)
	state = "over"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rep := _report(false)
	hud.show_screen("TU ES MORT",
		("Tué par : " + player.last_cause + "\n" if player.last_cause != "" else "") + "Officiellement, tu n'as jamais existé.\nTemps : %s   ·   Niveau %d   ·   %d capitalistes bonkés\n\n%s" % [_fmt(time), level, kills, "\n".join(rep["lines"])],
		"ENTRÉE ou A : retour au Kolkhoze", Color(0.85, 0.15, 0.15))
	hud.screen_buttons([["RETOUR AU KOLKHOZE", _back_to_hub], ["REJOUER", _replay]])
	print("[game] GAME OVER t=%s level=%d kills=%d" % [_fmt(time), level, kills])

func _win():
	Snd.music("victory", 0.3)
	state = "win"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rep := _report(true)
	hud.show_screen("LE CAPITALISME EST TOMBÉ",
		"La Main Invisible a été bonkée. La Bourse, les tours et l'hypermarché appartiennent au peuple.\nLe Parti te remercie et t'oubliera dès demain.\nTemps total : %s   ·   Niveau %d   ·   %d capitalistes bonkés\n\n%s" % [_fmt(run_time + time), level, kills, "\n".join(rep["lines"])],
		"ENTRÉE ou A : retour au Kolkhoze", Color(0.95, 0.75, 0.25))
	hud.screen_buttons([["RETOUR AU KOLKHOZE", _back_to_hub], ["REJOUER", _replay]])
	print("[game] WIN t=%s level=%d kills=%d" % [_fmt(time), level, kills])

func _report(win: bool) -> Dictionary:
	if report_done: return {"lines": []}
	report_done = true
	var r := {"char": char_id, "time": time, "kills": kills, "kills_by_kind": kills_by_kind, "kills_by_weapon": kills_by_weapon,
		"dmg_by_weapon": dmg_by_weapon, "boss": win, "elites": elites_killed, "level": level, "chests": chests_opened,
		"shrines": shrines_used, "evo": got_evo, "ferveur": Meta.ferveur(dirs), "win": win,
		"bosses": bosses_killed, "tier": tier, "endless": endless, "zone": zone}
	r["time"] = run_time + time
	var wlv := {}
	for wid in weapons.owned: wlv[wid] = weapons.owned[wid]["lv"]
	r["weapon_levels"] = wlv
	var evo_list := []
	for wid in weapons.owned:
		if weapons.owned[wid]["evo"]: evo_list.append(wid)
	r["evolved"] = evo_list
	r["boss"] = not bosses_killed.is_empty()
	var out: Dictionary = Meta.end_run(r)
	print("[meta] run=%d char=%s zone=%d time=%s win=%s lvl=%d kills=%d medals=%d total=%d" % [Meta.data["runs"], char_id, zone, _fmt(run_time + time), win, level, kills, out["medals"], Meta.data["medals"]])
	return out

func _replay():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/charselect.tscn")

func _back_to_hub():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func track_damage(wid: String, amt: float):
	if warming: return
	if wid != "": dmg_by_weapon[wid] = dmg_by_weapon.get(wid, 0.0) + amt

# ---------------------------------------------------------------- automated test hooks
func _bot_pick() -> int:
	var best := 0
	var bs := -1.0
	for i in hud.options.size():
		var o: Dictionary = hud.options[i]
		var sc: float = 1.0 + o["rarity"] * 0.6
		match o["kind"]:
			"evo", "fusion": sc += 10.0
			"surcharge", "surplus": sc += 1.2
			"weapon_new": sc += 3.0 if weapons.slot_ids().size() < 3 else 1.0
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
		print("[perf] dc=%d obj=%d prims=%d proc_ms=%.1f phys_ms=%.1f nodes=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if shot_every > 0.0:
		shot_t += d
		if shot_t >= shot_every:
			shot_t = 0.0
			_screenshot()
	if multi_run and state in ["over", "win"]:
		_back_to_hub()
		return
	if multi_run and time >= 720.0:
		game_over(true)
		return
	if test_dur > 0.0 and (time >= test_dur or state in ["over", "win"]):
		if state in ["over", "win"]: _screenshot()
		print("[bot] END state=%s t=%s lvl=%d kills=%d" % [state, _fmt(time), level, kills])
		print("[perf] END dc=%d obj=%d prims=%d proc_ms=%.1f enemies=%d nodes=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, enemies.count(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		var dl := []
		for k in dmg_by_weapon: dl.append("%s=%d" % [k, int(dmg_by_weapon[k])])
		print("[bot] DMG " + " ".join(dl))
		get_tree().quit()

func _screenshot():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	img.save_png("%s/shot_%03d_%s.png" % [shot_dir, shot_n, state])
	shot_n += 1
