extends CanvasLayer
# HUD, level-up cards, toasts and full-screen overlays (menu, pause, game over, victory).

signal chosen(index: int)

const C_BG := Color(0.06, 0.06, 0.07, 0.72)
const C_FG := Color(0.92, 0.9, 0.86)
const C_ACC := Color(0.85, 0.2, 0.18)
const C_XP := Color(0.85, 0.78, 0.55)
const C_HP := Color(0.75, 0.15, 0.15)
const C_BORDER := Color(1, 1, 1, 0.18)

var game
var font: Font
var root: Control
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
	_at(zone_label, Control.PRESET_CENTER_TOP, Vector2(-250, 128), Vector2(500, 30))
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
		var l := _label(p, "", 16, Color.WHITE)
		l.size = Vector2(150, 34); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		decret_slots.append([p, l])
	var wl := _label(bottom, "ARMES", 18, Color.WHITE)
	wl.position = Vector2(2, 74)
	for i in Data.WEAPON_SLOTS:
		var p := _panel(bottom, C_BG, 2, 1)
		p.position = Vector2(i * 108, 102); p.size = Vector2(98, 98)
		var n := _label(p, "", 15, C_FG)
		n.size = Vector2(98, 30); n.position = Vector2(0, 28); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lv := _label(p, "", 18, C_ACC)
		lv.size = Vector2(98, 30); lv.position = Vector2(0, 58); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_slots.append([p, n, lv])
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
	_build_choices()
	_build_screen()

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
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = C_BORDER
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
func _process(d: float):
	if game == null: return
	var p = game.player
	var need := Data.xp_to_next(game.level)
	var xw: float = (root.size.x - 4.0) * clampf(float(game.xp) / need, 0.0, 1.0)
	xp_fill.size = Vector2(maxf(xw, 0.0), 18)
	lvl_label.text = "NIV %d" % game.level
	var t: float = game.time
	timer_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
	timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if game.krach else Color.WHITE)
	zone_label.text = "LE KRACH  ·  FUIS OU MEURS" if game.krach else "ZONE 1/3  ·  HYPERMARCHÉ"
	hp_fill.size = Vector2(244.0 * clampf(p.hp / p.max_hp, 0.0, 1.0), 24)
	hp_label.text = "%d / %d" % [ceili(p.hp), int(p.max_hp)]
	rub_label.text = "%d RBL" % game.rubles
	kill_label.text = "%d KO" % game.kills
	var wids: Array = game.weapons.owned.keys()
	for i in weapon_slots.size():
		var s: Array = weapon_slots[i]
		if i < wids.size():
			var w: Dictionary = game.weapons.owned[wids[i]]
			var nm: String = Data.WEAPONS[wids[i]]["evo_name"] if w["evo"] else Data.WEAPONS[wids[i]]["name"]
			s[1].text = nm.to_upper().replace("COCKTAIL ", "").replace("RÉVOLUTION ", "RÉVOL. ")
			s[2].text = ("NV %d ★" if w["evo"] else "NV %d") % w["lv"]
			(s[0] as Panel).modulate = Color(1, 0.35, 0.35, 1) if wids[i] == game.player.seized_weapon else Color(1, 1, 1, 1)
		else:
			s[1].text = "+"
			s[2].text = ""
			(s[0] as Panel).modulate = Color(1, 1, 1, 0.45)
	var dids: Array = game.decrets.keys()
	for i in decret_slots.size():
		var s: Array = decret_slots[i]
		var sb: StyleBoxFlat = (s[0] as Panel).get_theme_stylebox("panel")
		if i < dids.size():
			s[1].text = "%s %d" % [Data.DECRETS[dids[i]]["name"].to_upper(), game.decrets[dids[i]]["n"]]
			sb.bg_color = C_ACC
		else:
			s[1].text = ""
			sb.bg_color = Color(0, 0, 0, 0.3)
	var boss = game.boss
	boss_box.visible = boss != null and boss.alive
	if boss_box.visible:
		boss_name.text = Data.ENEMIES[boss.kind]["name"].to_upper()
		boss_fill.size = Vector2(836.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0), 16)
	toast_t -= d
	toast_label.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	hurt_a = maxf(0.0, hurt_a - d * 1.5)
	blind_a = maxf(0.0, blind_a - d * 0.6)
	hurt_rect.color = Color(0.7, 0.0, 0.0, hurt_a) if blind_a <= 0.0 else Color(0.97, 0.95, 0.88, minf(blind_a, 0.85))
	fps_label.text = "%d FPS · %d ennemis" % [Engine.get_frames_per_second(), game.enemies.count()]
	var cost: int = game.ultimate_cost()
	var uname: String = Meta.CHARACTERS[game.char_id]["ult"].to_upper()
	if game.ult_t > 0.0:
		ult_label.text = "%s · ACTIF" % uname
	elif game.ult_kills >= cost:
		ult_label.text = "E / RB : %s · PRÊT" % uname
	else:
		ult_label.text = "%s %d %%" % [uname, int(100.0 * game.ult_kills / cost)]
	ult_label.modulate.a = 1.0 if game.ult_kills >= cost or game.ult_t > 0.0 else 0.55
	if choice_root.visible:
		_choice_input()

func toast(t: String, dur := 2.0):
	toast_label.text = t
	toast_t = dur

func prompt(t: String):
	prompt_label.text = t

func hurt():
	hurt_a = 0.28

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
	choice_title = _label(choice_root, "", 54, Color.WHITE)
	_at(choice_title, Control.PRESET_CENTER, Vector2(-600, -330), Vector2(1200, 80))
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label(choice_root, "1 · 2 · 3, clic, ou manette (gauche/droite + A)", 20, Color(1, 1, 1, 0.6))
	var hint := hint_label
	_at(hint, Control.PRESET_CENTER, Vector2(-600, 250), Vector2(1200, 30))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var card := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.09, 0.95)
		sb.set_border_width_all(3)
		sb.border_color = C_BORDER
		sb.set_corner_radius_all(3)
		card.add_theme_stylebox_override("panel", sb)
		_at(card, Control.PRESET_CENTER, Vector2(-560 + i * 380, -220), Vector2(360, 440))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(func(): sel = i; _highlight())
		choice_root.add_child(card)
		var tag := _label(card, "", 18, C_ACC)
		tag.position = Vector2(24, 24)
		var title := _label(card, "", 40, Color.WHITE)
		title.position = Vector2(24, 54); title.size = Vector2(312, 60)
		var lv := _label(card, "", 22, C_XP)
		lv.position = Vector2(24, 112)
		var desc := _label(card, "", 22, Color(0.85, 0.83, 0.8))
		desc.position = Vector2(24, 160); desc.size = Vector2(312, 240)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var key := _label(card, str(i + 1), 26, Color(1, 1, 1, 0.35))
		key.position = Vector2(318, 392)
		var price := _label(card, "", 26, Color(1, 0.85, 0.35))
		price.position = Vector2(24, 392)
		cards.append({"card": card, "sb": sb, "tag": tag, "title": title, "lv": lv, "desc": desc, "price": price})

var hint_label: Label
var leave_label := ""
func show_choices(title: String, opts: Array, leave := ""):
	options = opts
	leave_label = leave
	hint_label.text = "1 · 2 · 3, clic, ou manette (gauche/droite + A)" + ("   ·   4 / Y : " + leave if leave != "" else "") + (("   ·   T / LB : relancer (%d)" % game.rerolls) if game.rerolls > 0 and game.choice_source in ["level", "shrine"] else "")
	choice_title.text = title
	sel = 0
	for i in 3:
		var c: Dictionary = cards[i]
		c["card"].visible = i < opts.size()
		if i < opts.size():
			var o: Dictionary = opts[i]
			c["tag"].text = o["tag"]
			c["title"].text = o["title"]
			c["lv"].text = o["lv"]
			c["desc"].text = o["desc"]
			c["price"].text = ("%d RBL" % o["cost"]) if o.has("cost") else ""
			c["rcol"] = Data.RARITY_COLORS[o["rarity"]]
			c["tag"].add_theme_color_override("font_color", c["rcol"])
	_highlight()
	choice_root.visible = true

func hide_choices():
	choice_root.visible = false

func _highlight():
	for i in cards.size():
		var sb: StyleBoxFlat = cards[i]["sb"]
		var rc: Color = cards[i].get("rcol", C_BORDER)
		sb.border_color = Color(1, 1, 1) if i == sel else Color(rc.r, rc.g, rc.b, 0.8)
		sb.set_border_width_all(5 if i == sel else 3)
		sb.bg_color = Color(0.14, 0.1, 0.09, 0.97) if i == sel else Color(0.08, 0.08, 0.09, 0.95)

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
	if leave_label != "" and (Input.is_action_just_pressed("choose_4") or Input.is_action_just_pressed("pause")):
		chosen.emit(-1)

# ---------------------------------------------------------------- overlays
func _build_screen():
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.visible = false
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(dim)
	screen_title = _label(screen_root, "", 140, Color.WHITE)
	_at(screen_title, Control.PRESET_CENTER, Vector2(-800, -300), Vector2(1600, 180))
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_body = _label(screen_root, "", 26, Color(0.9, 0.86, 0.8))
	_at(screen_body, Control.PRESET_CENTER, Vector2(-600, -100), Vector2(1200, 300))
	screen_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_hint = _label(screen_root, "", 30, Color(1, 0.8, 0.35))
	_at(screen_hint, Control.PRESET_CENTER, Vector2(-600, 230), Vector2(1200, 50))
	screen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_screen(title: String, body: String, hint: String, title_col := Color.WHITE):
	screen_title.text = title
	screen_title.add_theme_color_override("font_color", title_col)
	screen_body.text = body
	screen_hint.text = hint
	screen_root.visible = true

func hide_screen():
	screen_root.visible = false

func set_hud_visible(v: bool):
	for c in root.get_children():
		if c == screen_root or c == choice_root: continue
		(c as CanvasItem).visible = v
