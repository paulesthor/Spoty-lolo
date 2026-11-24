extends CanvasLayer
# HUD, level-up cards, toasts and full-screen overlays (menu, pause, game over, victory).

signal chosen(index: int)

const C_BG := Color(0.07, 0.055, 0.05, 0.78)
const C_FG := Color(0.95, 0.9, 0.8)
const C_ACC := Color(0.85, 0.2, 0.18)
const C_XP := Color(0.85, 0.78, 0.55)
const C_HP := Color(0.75, 0.15, 0.15)
const C_BORDER := Color(1, 1, 1, 0.18)

var game
var font: Font
var root: Control
var minimap: Control
var screen_poster: TextureRect
var xp_fill: Panel
var lvl_label: Label
var timer_label: Label
var zone_label: Label
var hp_fill: Panel
var hp_label: Label
var rub_label: Label
var kill_label: Label
var weapon_slots: Array = []
var decret_slots: Array = []
var boss_box: Control
var boss_fill: Panel
var boss_name: Label
var toast_label: Label
var toast_t := 0.0
var prompt_label: Label
var hurt_rect: ColorRect
var hurt_a := 0.0
var choice_root: Control
var choice_title: Label
var cards: Array = []
var options: Array = []
var sel := 0
var screen_root: Control
var screen_title: Label
var screen_body: Label
var screen_hint: Label
var fps_label: Label
var hit_marks: Array = []
var hit_idx := 0
var ult_label: Label

func setup(g):
	game = g
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/Oswald.woff2")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	minimap = load("res://scripts/minimap.gd").new()
	minimap.setup(game)
	root.add_child(minimap)
	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.color = Color(0.7, 0.0, 0.0, 0.0)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_rect)
	# XP bar
	var xp_bg := _panel(root, Color(0, 0, 0, 0.65), 0, 0)
	_anchor_top_wide(xp_bg, 0, 22)
	xp_fill = _panel(xp_bg, C_XP, 0, 0)
	xp_fill.position = Vector2(2, 2); xp_fill.size = Vector2(10, 18)
	lvl_label = _label(root, "NIV 1", 18, Color.WHITE)
	lvl_label.position = Vector2(14, 0)
	# timer
	timer_label = _label(root, "00:00", 80, Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_at(timer_label, Control.PRESET_CENTER_TOP, Vector2(-160, 28), Vector2(320, 100))
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	timer_label.add_theme_constant_override("outline_size", 16)
	zone_label = _label(root, "ZONE 1/3  ·  HYPERMARCHÉ", 22, C_ACC)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_at(zone_label, Control.PRESET_CENTER_TOP, Vector2(-420, 122), Vector2(840, 56))
	zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	zone_label.add_theme_constant_override("outline_size", 8)
	# HP
	var hp_box := _panel(root, C_BG, 2, 1)
	hp_box.position = Vector2(24, 40); hp_box.size = Vector2(380, 54)
	var hp_bg := _panel(hp_box, Color(0, 0, 0, 0.35), 1, 0)
	hp_bg.position = Vector2(12, 12); hp_bg.size = Vector2(250, 30)
	hp_fill = _panel(hp_bg, C_HP, 1, 0)
	hp_fill.position = Vector2(3, 3); hp_fill.size = Vector2(244, 24)
	hp_label = _label(hp_box, "100 / 100", 24, C_FG)
	hp_label.position = Vector2(272, 10)
	# currencies
	var cur := _panel(root, C_BG, 2, 1)
	_at(cur, Control.PRESET_TOP_RIGHT, Vector2(-380, 40), Vector2(356, 54))
	rub_label = _label(cur, "0 RBL", 30, C_ACC)
	rub_label.position = Vector2(20, 6)
	kill_label = _label(cur, "0 KO", 30, C_FG)
	kill_label.position = Vector2(190, 6)
	# weapons + decrets
	var bottom := Control.new()
	_at(bottom, Control.PRESET_BOTTOM_LEFT, Vector2(24, -230), Vector2(640, 210))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var dl := _label(bottom, "DÉCRETS", 18, Color.WHITE)
	dl.position = Vector2(2, 0)
	for i in Data.DECRET_SLOTS:
		var p := _panel(bottom, Color(0, 0, 0, 0.3), 2, 0)
		p.position = Vector2(i * 160, 28); p.size = Vector2(150, 34)
		var dic := TextureRect.new()
		dic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; dic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dic.position = Vector2(4, 2); dic.size = Vector2(30, 30); dic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(dic)
		var l := _label(p, "", 14, Color.WHITE)
		l.size = Vector2(114, 34); l.position = Vector2(34, 0); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		decret_slots.append([p, l, dic])
	var wl := _label(bottom, "ARMES", 18, Color.WHITE)
	wl.position = Vector2(2, 74)
	for i in Data.MAX_SLOTS:
		var p := _panel(bottom, C_BG, 2, 1)
		p.position = Vector2(i * 108, 102); p.size = Vector2(98, 98)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(22, 2); ic.size = Vector2(56, 56); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		var n := _label(p, "", 12, C_FG)
		n.size = Vector2(94, 20); n.position = Vector2(2, 57); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		var lv := _label(p, "", 15, C_ACC)
		lv.size = Vector2(98, 22); lv.position = Vector2(0, 74); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_slots.append([p, n, lv, ic])
	# boss bar
	boss_box = Control.new()
	_at(boss_box, Control.PRESET_CENTER_TOP, Vector2(-420, 170), Vector2(840, 60))
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = _label(boss_box, "", 24, Color(1, 0.82, 0.3))
	boss_name.size = Vector2(840, 30); boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_outline_color", Color.BLACK); boss_name.add_theme_constant_override("outline_size", 8)
	var bb := _panel(boss_box, Color(0, 0, 0, 0.6), 1, 1)
	bb.position = Vector2(0, 34); bb.size = Vector2(840, 20)
	boss_fill = _panel(bb, Color(0.8, 0.12, 0.12), 0, 0)
	boss_fill.position = Vector2(2, 2); boss_fill.size = Vector2(836, 16)
	# toast + prompt
	toast_label = _label(root, "", 40, Color(1, 0.88, 0.6))
	_at(toast_label, Control.PRESET_CENTER, Vector2(-700, -260), Vector2(1400, 60))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK); toast_label.add_theme_constant_override("outline_size", 12)
	prompt_label = _label(root, "", 26, Color.WHITE)
	_at(prompt_label, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -180), Vector2(800, 40))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK); prompt_label.add_theme_constant_override("outline_size", 8)
	fps_label = _label(root, "", 14, Color(1, 1, 1, 0.5))
	_at(fps_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-260, -28), Vector2(240, 24))
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ult_label = _label(root, "", 24, Color(1, 0.85, 0.4))
	_at(ult_label, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -140), Vector2(800, 34))
	ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_label.add_theme_color_override("font_outline_color", Color.BLACK); ult_label.add_theme_constant_override("outline_size", 8)
	for i in 4:
		var m := _label(root, "▲", 90, Color(1, 0.15, 0.1))
		m.size = Vector2(90, 110)
		m.pivot_offset = Vector2(45, 55)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.add_theme_color_override("font_outline_color", Color.BLACK); m.add_theme_constant_override("outline_size", 10)
		m.modulate.a = 0.0
		hit_marks.append(m)
	# comrades in coop: name and health under your own bar
	for i in 3:
		var box := _panel(root, C_BG, 2, 1)
		box.position = Vector2(24, 102 + i * 40); box.size = Vector2(300, 34)
		var nm := _label(box, "", 16, C_FG)
		nm.position = Vector2(10, 5); nm.size = Vector2(130, 24); nm.clip_text = true
		var bg := _panel(box, Color(0, 0, 0, 0.35), 1, 0)
		bg.position = Vector2(146, 9); bg.size = Vector2(144, 16)
		var fill := _panel(bg, C_HP, 1, 0)
		fill.position = Vector2(2, 2); fill.size = Vector2(140, 12)
		box.visible = false
		ally_rows.append([box, nm, fill])
	wait_label = _label(root, "LES CAMARADES CHOISISSENT LEURS CARTES…", 34, Color(1, 0.85, 0.4))
	_at(wait_label, Control.PRESET_CENTER, Vector2(-500, -30), Vector2(1000, 60))
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait_label.add_theme_color_override("font_outline_color", Color.BLACK); wait_label.add_theme_constant_override("outline_size", 12)
	wait_label.visible = false
	_build_choices()
	_build_screen()

var ally_rows: Array = []
var wait_label: Label
func waiting(on: bool):
	if wait_label: wait_label.visible = on

func _update_allies():
	var others: Array = []
	for q in game.players:
		if q != game.player: others.append(q)
	for i in ally_rows.size():
		var row: Array = ally_rows[i]
		(row[0] as Control).visible = i < others.size()
		if i >= others.size(): continue
		var q = others[i]
		(row[1] as Label).text = "J%d · %s" % [q.idx + 1, (Meta.CHARACTERS[q.char_id]["name"] as String).to_upper()]
		(row[1] as Label).add_theme_color_override("font_color", Color(1, 0.35, 0.3) if q.downed else C_FG)
		(row[2] as Panel).size = Vector2(140.0 * clampf(q.hp / maxf(q.max_hp, 1.0), 0.0, 1.0), 12)

func _at(c: Control, preset: int, pos: Vector2, sz := Vector2.ZERO):
	c.set_anchors_preset(preset)
	if sz == Vector2.ZERO: sz = c.size
	c.offset_left = pos.x; c.offset_top = pos.y
	c.offset_right = pos.x + sz.x; c.offset_bottom = pos.y + sz.y

func _anchor_top_wide(c: Control, top: float, h: float):
	c.anchor_left = 0; c.anchor_right = 1; c.anchor_top = 0; c.anchor_bottom = 0
	c.offset_left = 0; c.offset_right = 0; c.offset_top = top; c.offset_bottom = top + h

func _panel(parent: Control, col: Color, radius: int, border: int) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	# constructivist look: slanted panels with a thick red edge (no rounded corners)
	sb.set_corner_radius_all(0)
	sb.skew = Vector2(0.12, 0.0)
	if border > 0:
		sb.border_color = C_ACC
		sb.border_width_left = 5
		sb.border_width_bottom = 2
		sb.border_width_top = 0
		sb.border_width_right = 0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _label(parent: Control, t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# ---------------------------------------------------------------- per-frame
# ---------------------------------------------------------------- off-screen threats
# red arrows on the screen edge for what can hurt you from outside the view: projectiles and lobs on
# their way, rolling balls, elites and the boss
var _marks: Array = []
func _threats():
	if game == null or game.cam == null or game.player == null: return
	var cam: Camera3D = game.cam
	var vs := root.get_viewport_rect().size
	var pp: Vector3 = game.player.global_position
	var pts := []
	for h in game.enemies.hazards:
		if not is_instance_valid(h["n"]): continue
		var hp: Vector3 = h["to"] if h["t"] == "lob" else (h["n"] as Node3D).global_position
		if h["t"] in ["shot", "lob", "ball"] and hp.distance_to(pp) < 30.0: pts.append([hp, Color(1, 0.25, 0.2)])
	for e in game.enemies.alive_list():
		if (e.elite or e.boss) and e.node.position.distance_to(pp) < 45.0: pts.append([e.node.position + Vector3(0, 1.5, 0), Color(1, 0.8, 0.25)])
	if game.portal != null: pts.append([game.portal_pos + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.5)])
	var used := 0
	var cx := vs * 0.5
	for it in pts:
		if used >= 10: break
		var wp: Vector3 = it[0]
		var behind := not cam.is_position_in_frustum(wp)
		var sp := cam.unproject_position(wp)
		if not behind and sp.x > 30 and sp.x < vs.x - 30 and sp.y > 30 and sp.y < vs.y - 30: continue
		var dir := sp - cx
		if behind: dir = -dir
		if dir.length() < 1.0: continue
		dir = dir.normalized()
		var k := minf((vs.x * 0.5 - 40) / maxf(absf(dir.x), 0.001), (vs.y * 0.5 - 40) / maxf(absf(dir.y), 0.001))
		if used >= _marks.size():
			var l := Label.new(); l.text = "▲"
			l.add_theme_font_override("font", load("res://fonts/Symbols.ttf")); l.add_theme_font_size_override("font_size", 34)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0)); l.add_theme_constant_override("outline_size", 6)
			l.size = Vector2(40, 40); l.pivot_offset = Vector2(20, 20)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(l); _marks.append(l)
		var m: Label = _marks[used]
		m.visible = true
		m.position = cx + dir * k - Vector2(20, 20)
		m.rotation = dir.angle() + PI / 2
		m.add_theme_color_override("font_color", it[1])
		m.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 120.0))
		used += 1
	for i in range(used, _marks.size()): (_marks[i] as Label).visible = false

func _process(d: float):
	_threats()
	if game == null: return
	var p = game.player
	_update_allies()
	var need: int = game.xp_need(game.level)
	var xw: float = (root.size.x - 4.0) * clampf(float(game.xp) / need, 0.0, 1.0)
	xp_fill.size = Vector2(maxf(xw, 0.0), 18)
	lvl_label.text = "NIV %d" % game.level
	var t: float = game.time
	timer_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
	timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if game.krach else Color.WHITE)
	var zt: String = "NIVEAU SPÉCIAL" if Levels.special(game.zone) else ("ZONE %d · SANS FIN" % game.zone) if game.endless else ("ACTE %s · ZONE %d/3" % [["I", "II", "III"][Levels.act(game.zone)], (game.zone - 1) % 3 + 1])
	# the objective of the moment, always on screen
	var obj := ""
	if game.door != null: obj = "OBJECTIF · LA PORTE EST OUVERTE · SUIS LE FAISCEAU ROUGE"
	elif game.boss != null and is_instance_valid(game.boss.node) and game.boss.alive: obj = "OBJECTIF · BONKE " + (game.boss.def["name"] as String).to_upper() + ("  ·  LE KRACH EST LÀ" if game.krach else "")
	elif game.krach: obj = "LE KRACH · LA HORDE FINALE · SURVIS"
	elif game.portal != null: obj = "OBJECTIF · LE PORTAIL DU BOSS EST OUVERT (FAISCEAU DORÉ) · IL VIENDRA SEUL À 10:00"
	elif game.tpl.has("boss_time"): obj = "OBJECTIF · TIENS BON · IL ARRIVE À %02d:%02d" % [int(game.tpl["boss_time"]) / 60, int(game.tpl["boss_time"]) % 60]
	else:
		var left: int = maxi(0, int(game.PORTAL_TIME - t))
		obj = "OBJECTIF · EXPLORE · COFFRES ET AUTELS · PORTAIL DU BOSS DANS %d:%02d" % [left / 60, left % 60]
	zone_label.text = zt + "  ·  " + (game.tpl["name"] as String).to_upper() + "\n" + obj
	hp_fill.size = Vector2(244.0 * clampf(p.hp / p.max_hp, 0.0, 1.0), 24)
	hp_label.text = "%d / %d" % [mini(ceili(p.hp), ceili(p.max_hp)), ceili(p.max_hp)]
	rub_label.text = "%d RBL" % game.rubles
	kill_label.text = "%d KO" % game.kills
	var wids: Array = game.player.weapons.slot_ids()
	var nslots: int = game.weapon_slots()
	for i in weapon_slots.size():
		var s: Array = weapon_slots[i]
		(s[0] as Panel).visible = i < nslots
		if i < wids.size():
			var w: Dictionary = game.player.weapons.owned[wids[i]]
			var nm: String = game.player.weapons.display_name(wids[i])
			s[1].text = nm.to_upper().replace("COCKTAIL MOLOTOV", "MOLOTOV").replace("RÉVOLUTION ", "RÉVOL. ")
			s[2].text = ("NV %d ★" if w["evo"] else "NV %d") % w["lv"]
			s[3].texture = U.icon("weapon", wids[i])
			(s[0] as Panel).modulate = Color(1, 0.35, 0.35, 1) if wids[i] == game.player.seized_weapon else Color(1, 1, 1, 1)
		else:
			s[1].text = "+"
			s[2].text = ""
			s[3].texture = null
			(s[0] as Panel).modulate = Color(1, 1, 1, 0.45)
	var dids: Array = game.decrets.keys()
	for i in decret_slots.size():
		var s: Array = decret_slots[i]
		var sb: StyleBoxFlat = (s[0] as Panel).get_theme_stylebox("panel")
		if i < dids.size():
			s[1].text = "%s %d" % [Data.DECRETS[dids[i]]["name"].to_upper(), game.decrets[dids[i]]["n"]]
			s[2].texture = U.icon("decret", dids[i])
			sb.bg_color = C_ACC
		else:
			s[1].text = ""
			s[2].texture = null
			sb.bg_color = Color(0, 0, 0, 0.3)
	var boss = game.boss
	boss_box.visible = boss != null and boss.alive
	if boss_box.visible:
		boss_name.text = Levels.edef(boss.kind)["name"].to_upper()
		boss_fill.size = Vector2(836.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0), 16)
	toast_t -= d
	_toast_shown += d
	if not _toast_q.is_empty() and (toast_t <= 0.0 or _toast_shown >= 1.2):
		var nx: Array = _toast_q.pop_front()
		_show_toast(nx[0], nx[1])
	toast_label.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	hurt_a = maxf(0.0, hurt_a - d * 1.5)
	blind_a = maxf(0.0, blind_a - d * 0.6)
	for m in hit_marks:
		(m as Label).modulate.a = maxf(0.0, (m as Label).modulate.a - d * 1.4)
	var low: bool = p.hp < p.max_hp * 0.3 and p.hp > 0.0
	if low and hurt_a < 0.12: hurt_a = 0.12 + 0.08 * sin(Time.get_ticks_msec() / 150.0)
	hurt_rect.color = Color(0.7, 0.0, 0.0, hurt_a) if blind_a <= 0.0 else Color(0.97, 0.95, 0.88, minf(blind_a, 0.85))
	fps_label.text = "%d FPS · %d ennemis" % [Engine.get_frames_per_second(), game.enemies.count()]
	var cost: int = game.ultimate_cost(game.player)
	var uname: String = Meta.CHARACTERS[game.player.char_id]["ult"].to_upper()
	if game.player.ult_t > 0.0:
		ult_label.text = "%s · ACTIF" % uname
	elif game.player.ult_kills >= cost:
		ult_label.text = "E / RB : %s · PRÊT" % uname
	else:
		ult_label.text = "%s %d %%" % [uname, int(100.0 * game.player.ult_kills / cost)]
	ult_label.modulate.a = 1.0 if game.player.ult_kills >= cost or game.player.ult_t > 0.0 else 0.55
	if choice_root.visible:
		_choice_input()

# one message at a time: a new one waits for the current one (min. 1.2 s on screen); duplicates are dropped
var _toast_q: Array = []
var _toast_shown := 0.0
func toast(t: String, dur := 2.0):
	if t == toast_label.text and toast_t > 0.0: return
	for q in _toast_q:
		if q[0] == t: return
	if toast_t > 0.0 and _toast_shown < 1.2:
		if _toast_q.size() < 3: _toast_q.append([t, dur])
		return
	_show_toast(t, dur)

func _show_toast(t: String, dur: float):
	toast_label.text = t
	toast_t = dur
	_toast_shown = 0.0

func prompt(t: String):
	prompt_label.text = t

func hurt():
	hurt_a = 0.28

# red arrow on the screen edge pointing to where the hit came from
func hit_from(src: Vector3):
	var v: Vector3 = src - game.player.global_position
	v.y = 0
	if v.length() < 0.01: return
	var local := Basis(Vector3.UP, -game.player.cam_yaw) * v
	var ang := atan2(local.x, -local.z)
	var m: Label = hit_marks[hit_idx]
	hit_idx = (hit_idx + 1) % hit_marks.size()
	var c := root.size / 2.0
	var rad := minf(c.x, c.y) * 0.62
	m.position = c + Vector2(sin(ang), -cos(ang)) * rad - m.size / 2.0
	m.rotation = ang
	m.modulate.a = 1.0

var blind_a := 0.0
func blind():
	blind_a = 1.2

# ---------------------------------------------------------------- level-up cards
func _build_choices():
	choice_root = Control.new()
	choice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_root.visible = false
	root.add_child(choice_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	choice_root.add_child(dim)
	choice_title = _label(choice_root, "", 50, Color.WHITE)
	choice_title.add_theme_font_override("font", load("res://fonts/RussoOne.woff2"))
	choice_title.add_theme_color_override("font_shadow_color", C_ACC); choice_title.add_theme_constant_override("shadow_offset_x", 4); choice_title.add_theme_constant_override("shadow_offset_y", 4)
	_at(choice_title, Control.PRESET_CENTER, Vector2(-600, -330), Vector2(1200, 80))
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label(choice_root, "1 · 2 · 3, clic, ou manette (gauche/droite + A)", 20, Color(1, 1, 1, 0.6))
	var hint := hint_label
	_at(hint, Control.PRESET_CENTER, Vector2(-600, 250), Vector2(1200, 30))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# reward cards as little Party posters: paper, a slanted rarity band, an emblem, ink type
	var paper := Color(0.94, 0.89, 0.78)
	var ink := Color(0.1, 0.07, 0.06)
	var russo: Font = load("res://fonts/RussoOne.woff2")
	var sym: Font = load("res://fonts/Symbols.ttf")
	for i in 3:
		var card := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = paper
		sb.set_border_width_all(4)
		sb.border_color = C_BORDER
		sb.shadow_color = Color(0, 0, 0, 0.5); sb.shadow_size = 10; sb.shadow_offset = Vector2(6, 8)
		card.add_theme_stylebox_override("panel", sb)
		_at(card, Control.PRESET_CENTER, Vector2(-560 + i * 380, -220), Vector2(360, 440))
		card.pivot_offset = Vector2(180, 220)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(func(): sel = i; _highlight())
		choice_root.add_child(card)
		var band := Panel.new()
		var bsb := StyleBoxFlat.new(); bsb.bg_color = C_ACC; bsb.skew = Vector2(0.25, 0)
		band.add_theme_stylebox_override("panel", bsb)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.position = Vector2(-6, 14); band.size = Vector2(300, 38)
		card.add_child(band)
		var tag := _label(card, "", 17, Color.WHITE)
		tag.position = Vector2(18, 20); tag.size = Vector2(320, 30)
		var ico := TextureRect.new()
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.position = Vector2(126, 46); ico.size = Vector2(108, 108); ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ico)
		var emb := _label(card, "★", 64, Color(0.8, 0.1, 0.12))
		emb.add_theme_font_override("font", sym)
		emb.position = Vector2(0, 52); emb.size = Vector2(360, 80); emb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var title := _label(card, "", 32, ink)
		title.add_theme_font_override("font", russo)
		title.position = Vector2(20, 156); title.size = Vector2(320, 44)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lv := _label(card, "", 20, Color(0.75, 0.1, 0.12))
		lv.position = Vector2(20, 204); lv.size = Vector2(320, 30); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var desc := _label(card, "", 20, ink)
		desc.position = Vector2(28, 236); desc.size = Vector2(304, 160)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var key := _label(card, str(i + 1), 26, Color(0.1, 0.07, 0.06, 0.35))
		key.position = Vector2(318, 396)
		var price := _label(card, "", 26, Color(0.75, 0.1, 0.12))
		price.position = Vector2(24, 396)
		cards.append({"card": card, "sb": sb, "tag": tag, "title": title, "lv": lv, "desc": desc, "price": price, "band": bsb, "emb": emb, "ico": ico})

var hint_label: Label
var leave_label := ""

# largest font size (max..min) at which `text` fits in w x h with the label's font and wrapping
func _fit(l: Label, text: String, max_size: int, min_size: int, w: float, h: float):
	l.text = text
	l.size = Vector2(w, h)
	var f: Font = l.get_theme_font("font")
	var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF
	var fs := max_size
	while fs > min_size:
		var sz: Vector2 = f.get_multiline_string_size(text, l.horizontal_alignment, w, fs) if wrap else f.get_string_size(text, l.horizontal_alignment, -1, fs)
		if sz.x <= w + 0.5 and sz.y <= h: break
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	l.clip_text = true
func show_choices(title: String, opts: Array, leave := ""):
	options = opts
	leave_label = leave
	var parts := ["1 · 2 · 3, clic ou A"]
	if leave != "": parts.append("4 / B : " + leave)
	if game.rerolls > 0 and game.choice_source in ["level", "shrine"]: parts.append("T / LB : relancer (%d)" % game.rerolls)
	if game.banishes > 0 and game.choice_source in ["level", "shrine", "market"]: parts.append("B clavier / L3 : bannir (%d)" % game.banishes)
	if game.skips > 0 and game.choice_source in ["level", "shrine"]: parts.append("X / R3 : passer (%d)" % game.skips)
	hint_label.text = "   ·   ".join(parts)
	choice_title.text = title
	sel = 0
	for i in 3:
		var c: Dictionary = cards[i]
		c["card"].visible = i < opts.size()
		if i < opts.size():
			var o: Dictionary = opts[i]
			# every text is shrunk until it fits its box: long names and descriptions never spill over
			_fit(c["tag"], o["tag"], 17, 11, 270.0, 26.0)
			_fit(c["title"], o["title"], 32, 16, 320.0, 44.0)
			_fit(c["lv"], o["lv"], 20, 13, 320.0, 28.0)
			_fit(c["desc"], o["desc"], 20, 12, 304.0, 150.0)
			c["price"].text = ("%d RBL" % o["cost"]) if o.has("cost") else ""
			c["rcol"] = Data.RARITY_COLORS[o["rarity"]]
			var rc: Color = c["rcol"]
			(c["band"] as StyleBoxFlat).bg_color = Color(0.8, 0.1, 0.12) if o["rarity"] == 0 else rc.darkened(0.25)
			var glyph := {"weapon_new": "☭", "weapon_up": "☭", "decret": "★", "evo": "☭★", "fusion": "☭☭", "surplus": "★★", "surcharge": "☭", "pack": "★"}
			c["emb"].text = glyph.get(o["kind"], "★")
			var tex: Texture2D = U.icon(o["kind"], str(o.get("id", "")))
			c["ico"].texture = tex
			c["emb"].visible = tex == null
	_highlight()
	choice_root.visible = true
	toast_label.visible = false

func hide_choices():
	toast_label.visible = true
	choice_root.visible = false

func _highlight():
	if choice_root.visible: Snd.play("ui_hover", -14.0, 0.05, 0.04)
	for i in cards.size():
		var sb: StyleBoxFlat = cards[i]["sb"]
		var rc: Color = cards[i].get("rcol", C_BORDER)
		sb.border_color = C_ACC if i == sel else Color(rc.r, rc.g, rc.b, 0.9).darkened(0.2)
		sb.set_border_width_all(8 if i == sel else 4)
		sb.bg_color = Color(1.0, 0.95, 0.84) if i == sel else Color(0.9, 0.85, 0.74)
		var cd: Panel = cards[i]["card"]
		var tw := cd.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(cd, "scale", Vector2.ONE * (1.06 if i == sel else 1.0), 0.1)
		tw.parallel().tween_property(cd, "rotation", (-0.02 if i == sel else 0.0), 0.1)

func _on_card_input(ev: InputEvent, i: int):
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(i)

func _choice_input():
	if options.is_empty(): return
	for i in 3:
		if Input.is_action_just_pressed("choose_%d" % (i + 1)) and i < options.size():
			chosen.emit(i); return
	if Input.is_action_just_pressed("ui_left"):
		sel = (sel - 1 + options.size()) % options.size(); _highlight()
	if Input.is_action_just_pressed("ui_right"):
		sel = (sel + 1) % options.size(); _highlight()
	if Input.is_action_just_pressed("confirm"):
		chosen.emit(sel)
	if leave_label != "" and (Input.is_action_just_pressed("choose_4") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel")):
		chosen.emit(-1)

# ---------------------------------------------------------------- overlays
func _build_screen():
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.visible = false
	screen_root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(screen_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(dim)
	# slanted red band + a Party poster on the left: the overlays share the menus' poster identity
	var band := Panel.new()
	var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.07, 0.05, 0.045, 0.9); bs.skew = Vector2(-0.16, 0)
	bs.border_color = C_ACC; bs.border_width_left = 10; bs.border_width_right = 10
	band.add_theme_stylebox_override("panel", bs)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(band, Control.PRESET_CENTER, Vector2(-760, -340), Vector2(1520, 680))
	screen_root.add_child(band)
	screen_poster = TextureRect.new()
	screen_poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at(screen_poster, Control.PRESET_CENTER, Vector2(-700, -300), Vector2(400, 600))
	screen_root.add_child(screen_poster)
	screen_title = _label(screen_root, "", 96, Color.WHITE)
	screen_title.add_theme_font_override("font", load("res://fonts/RussoOne.woff2"))
	screen_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); screen_title.add_theme_constant_override("shadow_offset_x", 5); screen_title.add_theme_constant_override("shadow_offset_y", 5)
	_at(screen_title, Control.PRESET_CENTER, Vector2(-300, -300), Vector2(1000, 130))
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_body = _label(screen_root, "", 26, Color(0.9, 0.86, 0.8))
	_at(screen_body, Control.PRESET_CENTER, Vector2(-280, -150), Vector2(960, 380))
	screen_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_hint = _label(screen_root, "", 30, Color(1, 0.8, 0.35))
	_at(screen_hint, Control.PRESET_CENTER, Vector2(-300, 300), Vector2(1000, 40))
	screen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# clickable buttons under an overlay: [[label, Callable], ...]
var screen_btns: HBoxContainer
func screen_buttons(list: Array):
	if screen_btns == null:
		screen_btns = HBoxContainer.new()
		screen_btns.add_theme_constant_override("separation", 16)
		screen_btns.alignment = BoxContainer.ALIGNMENT_CENTER
		screen_btns.theme = UIK.theme()
		_at(screen_btns, Control.PRESET_CENTER, Vector2(-300, 230), Vector2(1000, 64))
		screen_root.add_child(screen_btns)
	for c in screen_btns.get_children(): c.queue_free()
	for it in list:
		var b := UIK.button(screen_btns, it[0], 24, 300)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		b.pressed.connect(it[1])
	if not list.is_empty(): screen_btns.get_child(0).call_deferred("grab_focus")

func show_screen(title: String, body: String, hint: String, title_col := Color.WHITE, stats: Array = []):
	screen_buttons([])
	screen_poster.texture = load("res://assets/posters/" + U.propaganda_tex(randi()))
	_fit(screen_title, title, 96 if stats.is_empty() else 80, 40, 1000.0, 130.0 if stats.is_empty() else 105.0)
	_vplace(screen_title, -300.0 if stats.is_empty() else -318.0, 130.0 if stats.is_empty() else 105.0)
	screen_title.add_theme_color_override("font_color", title_col)
	screen_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_stats(stats)
	if stats.is_empty():
		_vplace(screen_body, -150.0, 380.0)
		_fit(screen_body, body, 26, 13, 960.0, 370.0)
	else:
		_vplace(screen_body, -10.0, 236.0)
		_fit(screen_body, body, 22, 12, 960.0, 232.0)
	_fit(screen_hint, hint, 30, 16, 1000.0, 40.0)
	screen_root.visible = true

func _vplace(c: Control, y: float, h: float):
	c.offset_top = y; c.offset_bottom = y + h

# end-of-run report: a grid of big numbers (whole run, not only the last zone)
var stats_grid: GridContainer
func _screen_stats(stats: Array):
	if stats_grid == null:
		stats_grid = GridContainer.new()
		stats_grid.columns = 4
		stats_grid.add_theme_constant_override("h_separation", 10)
		stats_grid.add_theme_constant_override("v_separation", 8)
		stats_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_at(stats_grid, Control.PRESET_CENTER, Vector2(-280, -200), Vector2(960, 176))
		screen_root.add_child(stats_grid)
	for c in stats_grid.get_children(): c.queue_free()
	stats_grid.visible = not stats.is_empty()
	for st in stats:
		var tile := PanelContainer.new()
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.13, 0.08, 0.07, 0.95); sb.skew = Vector2(-0.12, 0)
		sb.border_color = Color(0.75, 0.12, 0.1); sb.border_width_left = 4
		sb.content_margin_left = 12; sb.content_margin_right = 8; sb.content_margin_top = 4; sb.content_margin_bottom = 4
		tile.add_theme_stylebox_override("panel", sb)
		tile.custom_minimum_size = Vector2(232, 84)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_grid.add_child(tile)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(v)
		var big := _label(v, "", 34, Color(1, 0.82, 0.35) if st.size() < 3 or not st[2] else Color(1, 0.35, 0.25))
		big.add_theme_font_override("font", load("res://fonts/RussoOne.woff2"))
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fit(big, str(st[1]), 34, 16, 205.0, 44.0)
		big.custom_minimum_size = Vector2(205, 44)
		var lab := _label(v, "", 15, Color(0.85, 0.8, 0.74))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fit(lab, str(st[0]), 15, 10, 205.0, 22.0)
		lab.custom_minimum_size = Vector2(205, 22)

func hide_screen():
	screen_root.visible = false

func set_hud_visible(v: bool):
	for c in root.get_children():
		if c == screen_root or c == choice_root or c == wait_label: continue
		var ally := false
		for row in ally_rows:
			if row[0] == c: ally = true
		if ally: continue      # the comrades' bars only show in coop (see _update_allies)
		(c as CanvasItem).visible = v
	if not v:
		for row in ally_rows: (row[0] as Control).visible = false
		if wait_label: wait_label.visible = false
