extends Control
# LE KOLKHOZE — hub between runs: choose comrade & directives, spend medals,
# talents, weapon modules, Plan quinquennal. Also drives multi-run bot simulations.

const C_BG := Color(0.08, 0.065, 0.06)
const C_PANEL := Color(0.14, 0.115, 0.1)
const C_PANEL2 := Color(0.19, 0.155, 0.13)
const C_RED := Color(0.78, 0.09, 0.12)
const C_GOLD := Color(1.0, 0.8, 0.3)
const C_TEXT := Color(0.93, 0.9, 0.85)
const C_DIM := Color(0.62, 0.58, 0.53)
const C_OK := Color(0.45, 0.9, 0.45)
const C_BAD := Color(1.0, 0.45, 0.35)

var font: Font
var content: VBoxContainer
var header_medals: Label
var header_grade: Label
var header_stats: Label
var grade_bar: ProgressBar
var tab := "lancer"
var nav_buttons := {}
var bot := false
var runs_target := 0
var bot_dirs := false
var bot_char := ""
var bot_nospend := false
var shots_dir := ""

func _ready():
	font = load("res://fonts/Oswald.woff2")
	for a in OS.get_cmdline_user_args():
		if a == "bot": bot = true
		elif a.begins_with("runs="): runs_target = int(a.substr(5))
		elif a == "botdirs": bot_dirs = true
		elif a.begins_with("char="): bot_char = a.substr(5)
		elif a == "nospend": bot_nospend = true
		elif a.begins_with("hubshots="): shots_dir = a.substr(9)
	theme = _make_theme()
	Snd.music("march")
	tab = Meta.hub_tab
	Meta.hub_tab = "lancer"
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# a Party poster in watermark behind the content
	var wm := TextureRect.new()
	wm.texture = load("res://assets/posters/" + U.propaganda_tex(randi()))
	wm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wm.set_anchors_preset(Control.PRESET_FULL_RECT)
	wm.modulate = Color(1, 1, 1, 0.07)
	add_child(wm)
	var band := ColorRect.new()
	band.color = C_RED
	band.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 8
	add_child(band)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 44; root.offset_top = 28; root.offset_right = -36; root.offset_bottom = -28
	root.add_theme_constant_override("separation", 28)
	add_child(root)
	# ---- left column
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(360, 0)
	nav.add_theme_constant_override("separation", 8)
	root.add_child(nav)
	nav.add_child(_lbl("COMMUNISTE LAND", 24, C_DIM))
	var kt := _lbl("LE KOLKHOZE", 44, C_RED, false)
	kt.add_theme_font_override("font", load("res://fonts/RussoOne.woff2"))
	nav.add_child(kt)
	var hb := _card(nav, C_PANEL, C_RED, 2)
	header_medals = _lbl("", 34, C_GOLD); hb.add_child(header_medals)
	header_grade = _lbl("", 22, C_TEXT); hb.add_child(header_grade)
	grade_bar = _bar(hb, 0.0, C_GOLD)
	header_stats = _lbl("", 18, C_DIM); hb.add_child(header_stats)
	nav.add_child(_space(6))
	var tabs := [["lancer", "▶  LANCER UNE RUN"], ["bureau", "BUREAU DU PLAN"], ["caserne", "CASERNE"], ["usine", "USINE D'ARMEMENT"], ["plan", "PLAN QUINQUENNAL"], ["directives", "DIRECTIVES DU PARTI"], ["options", "OPTIONS"]]
	for t in tabs:
		var b := _btn(t[1], 24)
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func(): tab = t[0]; _refresh())
		nav.add_child(b)
		nav_buttons[t[0]] = b
	# a Party poster fills the space under the menu (changes each visit)
	var art := TextureRect.new()
	art.texture = load("res://assets/posters/" + U.propaganda_tex(randi()))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size = Vector2(0, 120)
	nav.add_child(art)
	var quit := _btn("◀ MENU PRINCIPAL", 18)
	quit.pressed.connect(func(): Meta.save(); get_tree().change_scene_to_file("res://scenes/title.tscn"))
	nav.add_child(quit)
	# ---- content
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	_refresh()
	if shots_dir != "": call_deferred("_take_shots")
	elif bot: call_deferred("_bot_step")

# ---------------------------------------------------------------- ui helpers
func _sb(col: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 6) -> StyleBoxFlat:
	# constructivist: square corners, a thick coloured edge on the left
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(0)
	if bw > 0:
		s.border_color = border if border.a > 0.2 else Color(C_RED.r, C_RED.g, C_RED.b, 0.55)
		s.border_width_left = maxi(4, bw * 3)
		s.border_width_bottom = bw
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 8; s.content_margin_bottom = 8
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.set_stylebox("normal", "Button", _sb(C_PANEL2, Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("hover", "Button", _sb(Color(0.3, 0.12, 0.1), C_RED, 2))
	t.set_stylebox("pressed", "Button", _sb(C_RED, C_GOLD, 2))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), C_GOLD, 2))
	t.set_stylebox("disabled", "Button", _sb(Color(0.12, 0.1, 0.09), Color(1, 1, 1, 0.04), 1))
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.4))
	var bgs := StyleBoxFlat.new(); bgs.bg_color = Color(0, 0, 0, 0.45); bgs.set_corner_radius_all(4)
	var fgs := StyleBoxFlat.new(); fgs.bg_color = C_GOLD; fgs.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bgs)
	t.set_stylebox("fill", "ProgressBar", fgs)
	return t

func _lbl(t: String, size: int, col := C_TEXT, wrap := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(80, 0)
	return l

func _btn(t: String, size := 20, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Snd.play("ui_click", -4.0, 0.05, 0.05))
	b.mouse_entered.connect(func(): Snd.play("ui_hover", -14.0, 0.05, 0.04))
	return b

func _space(h: int) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, h)
	return c

# a styled panel; returns the inner VBox to fill
func _card(parent: Node, col := C_PANEL, border := Color(1, 1, 1, 0.06), bw := 1, min_w := 0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(col, border, bw, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_w > 0: p.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v

func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	content.add_child(g)
	return g

func _bar(parent: Node, v: float, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0; b.max_value = 1.0; b.value = clampf(v, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	var fg := StyleBoxFlat.new(); fg.bg_color = col; fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b

func _pips(n: int, mx: int) -> String:
	return "●".repeat(n) + "○".repeat(maxi(0, mx - n))

func _title(t: String, sub := ""):
	var h := _lbl(t, 48, C_TEXT, false)
	h.add_theme_font_override("font", load("res://fonts/RussoOne.woff2"))
	h.add_theme_color_override("font_shadow_color", C_RED); h.add_theme_constant_override("shadow_offset_x", 4); h.add_theme_constant_override("shadow_offset_y", 4)
	content.add_child(h)
	if sub != "": content.add_child(_lbl(sub, 18, C_DIM))

func _clear():
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()

func _refresh():
	var d: Dictionary = Meta.data
	var g := Meta.grade()
	header_medals.text = "%d MÉDAILLES" % d["medals"]
	header_grade.text = "Grade %d · %s" % [g, Meta.GRADE_NAMES[g - 1]]
	if g < 10:
		var lo := Meta.grade_req(g)
		var hi := Meta.grade_req(g + 1)
		grade_bar.value = clampf(float(int(d.get("lifetime", 0)) - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	else:
		grade_bar.value = 1.0
	header_stats.text = "Prochain grade : %d médailles gagnées au total (%d)\nRuns %d · Victoires %d · Record %02d:%02d" % [Meta.grade_req(mini(g + 1, 10)), int(d.get("lifetime", 0)), d["runs"], d["wins"], int(d["best_time"]) / 60, int(d["best_time"]) % 60]
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		if k == tab:
			b.add_theme_stylebox_override("normal", _sb(C_RED, C_GOLD, 2))
		else:
			b.remove_theme_stylebox_override("normal")
	_clear()
	match tab:
		"lancer": _tab_lancer()
		"bureau": _tab_bureau()
		"caserne": _tab_caserne()
		"usine": _tab_usine()
		"plan": _tab_plan()
		"directives": _tab_directives()
		"options": _tab_options()

# ---------------------------------------------------------------- LANCER
func _tab_lancer():
	_title("LANCER UNE RUN", "Le Plan t'attend. Choisis ton camarade sur l'estrade, puis en avant !")
	var cc := _card(content, C_PANEL2, C_RED, 2)
	var cdef: Dictionary = Meta.CHARACTERS[Meta.run_char]
	cc.add_child(_lbl("CAMARADE ACTUEL : %s · NIVEAU %d" % [(cdef["name"] as String).to_upper(), Meta.char_level(Meta.run_char)], 28, C_GOLD))
	cc.add_child(_lbl("Arme : %s · %s" % [Data.WEAPONS[cdef["weapon"]]["name"], cdef["passive"]], 18, C_DIM))
	var csel := _btn("CHOISIR SON CAMARADE  ▶", 22)
	csel.pressed.connect(func(): Meta.save(); get_tree().change_scene_to_file("res://scenes/charselect.tscn"))
	cc.add_child(csel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var qv := _card(row, C_PANEL)
	var plan: Dictionary = Meta.data["plan"]
	qv.add_child(_lbl("PLAN QUINQUENNAL N°%d · %d RUN(S) RESTANTE(S)" % [Meta.data["plan_no"], plan["runs_left"]], 22, C_GOLD))
	for q in plan["quotas"]:
		qv.add_child(_lbl(("✔ " if q["done"] else "• ") + q["text"] + "  (" + _qprog(q) + ")", 18, C_OK if q["done"] else C_TEXT))
		_bar(qv, _qfrac(q), C_OK if q["done"] else C_GOLD)
	if Meta.data["bureau_purged"] != "":
		qv.add_child(_lbl("PURGE EN COURS : « %s » désactivé." % Meta.BUREAU[Meta.data["bureau_purged"]]["name"], 18, C_BAD))
	var dv := _card(row, C_PANEL)
	var f := Meta.ferveur(Meta.run_directives)
	dv.add_child(_lbl("DIRECTIVES ACTIVES", 22, C_GOLD))
	if f == 0:
		dv.add_child(_lbl("Aucune. Ferveur 0." + ("" if Meta.grade() >= Meta.DIRECTIVES_GRADE else "\nDébloquées au grade %d." % Meta.DIRECTIVES_GRADE), 18, C_DIM))
	else:
		for id in Meta.run_directives:
			dv.add_child(_lbl("• %s %d" % [Meta.DIRECTIVES[id]["name"], Meta.run_directives[id]], 18, C_BAD))
		dv.add_child(_lbl("Ferveur %d · médailles x%.2f" % [f, 1.0 + 0.15 * f], 20, C_GOLD))
	# run settings: start zone, difficulty, mode
	var ls: Dictionary = Meta.data.get("launch", {"zone": 1, "tier": 1, "endless": false})
	if not Meta.zone_unlocked(int(ls["zone"])): ls["zone"] = 1
	if not Meta.tier_unlocked(int(ls["tier"])): ls["tier"] = 1
	if not Meta.endless_unlocked(): ls["endless"] = false
	Meta.data["launch"] = ls
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 14)
	content.add_child(srow)
	var zc := _card(srow, C_PANEL)
	zc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zc.add_child(_lbl("ZONE DE DÉPART", 20, C_GOLD))
	var zr := GridContainer.new(); zr.columns = 3; zc.add_child(zr)
	for z in range(1, Levels.count() + 1):
		var ok := Meta.zone_unlocked(z)
		var b := _btn(("%d · %s" % [z, Levels.zone(z)["name"]]) if ok else "%d · verrouillée" % z, 16, ok)
		if int(ls["zone"]) == z: b.add_theme_stylebox_override("normal", _sb(C_RED, C_GOLD, 2))
		b.pressed.connect(func(): ls["zone"] = z; _refresh())
		zr.add_child(b)
	zc.add_child(_lbl("Partir d'une zone plus loin donne des niveaux de rattrapage." if Meta.zone_unlocked(2) else "Bats le boss d'une zone pour pouvoir partir de la suivante.", 15, C_DIM))
	var tc := _card(srow, C_PANEL)
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(_lbl("DIFFICULTÉ", 20, C_GOLD))
	var tr := HBoxContainer.new(); tc.add_child(tr)
	for t in [1, 2, 3]:
		var ok := Meta.tier_unlocked(t)
		var b := _btn(Meta.TIERS[t - 1]["name"] if ok else "verrouillée", 16, ok)
		if int(ls["tier"]) == t: b.add_theme_stylebox_override("normal", _sb(C_RED, C_GOLD, 2))
		b.pressed.connect(func(): ls["tier"] = t; _refresh())
		tr.add_child(b)
	tc.add_child(_lbl(Meta.TIERS[int(ls["tier"]) - 1]["desc"] + ("" if Meta.tier_unlocked(3) else "\nGagne une run complète pour débloquer la suivante."), 15, C_DIM))
	var mc := _card(srow, C_PANEL)
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(_lbl("MODE", 20, C_GOLD))
	var mr := HBoxContainer.new(); mc.add_child(mr)
	for e in [false, true]:
		var ok: bool = (not e) or Meta.endless_unlocked()
		var b := _btn(("Sans fin" if e else "Normal (3 zones)") if ok else "Sans fin · verrouillé", 16, ok)
		if bool(ls["endless"]) == e: b.add_theme_stylebox_override("normal", _sb(C_RED, C_GOLD, 2))
		b.pressed.connect(func(): ls["endless"] = e; _refresh())
		mr.add_child(b)
	mc.add_child(_lbl(("Les zones bouclent sans fin, de plus en plus dures. Record : zone %d." % int(Meta.data.get("endless_best", 0))) if Meta.endless_unlocked() else "Débloqué après ta première victoire.", 15, C_DIM))
	var go := _btn("LANCER LA RUN  ·  ZONE %d : %s" % [int(ls["zone"]), (Levels.zone(int(ls["zone"]))["name"] as String).to_upper()], 34)
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.custom_minimum_size = Vector2(0, 80)
	go.add_theme_stylebox_override("normal", _sb(C_RED, C_GOLD, 2))
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/charselect.tscn"))
	content.add_child(go)
	go.grab_focus()
	content.add_child(_lbl("ZQSD déplacement · souris caméra · Espace saut · Maj glissade · F interagir · E ultime · T relancer les cartes · Échap pause", 17, C_DIM))

func _qprog(q: Dictionary) -> String:
	if q["kind"] in ["survive", "no_chest", "char_time"]:
		return "record %02d:%02d / %02d:%02d" % [int(q["progress"]) / 60, int(q["progress"]) % 60, int(q["target"]) / 60, int(q["target"]) % 60]
	return "%d / %d" % [int(q["progress"]), int(q["target"])]

func _qfrac(q: Dictionary) -> float:
	return 1.0 if q["done"] else clampf(float(q["progress"]) / maxf(1.0, float(q["target"])), 0.0, 1.0)

# ---------------------------------------------------------------- BUREAU
func _tab_bureau():
	_title("BUREAU DU PLAN", "Bonus permanents pour tous les camarades. Chaque rang suivant demande un grade plus élevé.")
	var g := _grid(3)
	for id in Meta.BUREAU:
		var b: Dictionary = Meta.BUREAU[id]
		var r := Meta.bureau_rank(id)
		var maxed: bool = r >= b["max"]
		var cost := Meta.bureau_cost(id, r)
		var purged: bool = Meta.data["bureau_purged"] == id
		var greq := Meta.bureau_grade_req(id, r)
		var locked := Meta.grade() < greq
		var v := _card(g, C_PANEL, C_BAD if purged else Color(1, 1, 1, 0.06), 2 if purged else 1, 300)
		var brow := HBoxContainer.new(); brow.add_theme_constant_override("separation", 10); v.add_child(brow)
		var stat_icon := {"regen": "endurance", "rubles_pct": "chance", "reroll": "chance", "banish": "critique", "skip": "vitesse", "revive": "endurance", "weapon_slot": "productivite"}
		var bic := TextureRect.new(); bic.texture = U.icon("decret", stat_icon.get(b["stat"], b["stat"])); bic.custom_minimum_size = Vector2(52, 52)
		bic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		brow.add_child(bic)
		var bcol := VBoxContainer.new(); bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; brow.add_child(bcol)
		bcol.add_child(_lbl(b["name"].to_upper(), 22, C_BAD if purged else C_GOLD))
		bcol.add_child(_lbl(Meta.stat_text(b["stat"], b["per"]) + " par rang", 17, C_TEXT))
		v.add_child(_lbl(_pips(r, b["max"]) + ("   PURGÉ" if purged else ""), 20, C_BAD if purged else C_GOLD))
		var txt := "MAX"
		if not maxed: txt = ("GRADE %d REQUIS" % greq) if locked else "ACHETER · %d" % cost
		var btn := _btn(txt, 18, not maxed and not locked and Meta.data["medals"] >= cost)
		btn.pressed.connect(func(): Meta.buy_bureau(id); _refresh())
		v.add_child(btn)

# ---------------------------------------------------------------- CASERNE
func _tab_caserne():
	_title("CASERNE", "Chaque run rapporte de l'XP au camarade joué. 1 niveau = 1 point de talent. Les talents d'une branche s'achètent dans l'ordre, et chacun demande un niveau minimum.")
	for c in Meta.CHARACTERS:
		var def: Dictionary = Meta.CHARACTERS[c]
		var cd: Dictionary = Meta.data["chars"][c]
		var v := _card(content, C_PANEL)
		if not cd["unlocked"]:
			var cg: int = Meta.CHAR_GRADE.get(c, 1)
			v.add_child(_lbl(def["name"].to_upper() + "  · VERROUILLÉ", 26, C_DIM))
			v.add_child(_lbl("Arme : %s · %s" % [Data.WEAPONS[def["weapon"]]["name"], def["passive"]], 17, C_DIM))
			if def.has("unlock"):
				v.add_child(_lbl("DÉFI : " + Meta.challenge_text(c), 18, C_GOLD))
				_bar(v, clampf(Meta.challenge_value(c) / Meta.challenge_target(c), 0.0, 1.0), C_GOLD)
				continue
			var ub := _btn("RECRUTER · %d médailles%s" % [def["cost"], (" · grade %d requis" % cg) if Meta.grade() < cg else ""], 20, Meta.data["medals"] >= def["cost"] and Meta.grade() >= cg)
			ub.pressed.connect(func(): Meta.unlock_char(c); _refresh())
			v.add_child(ub)
			continue
		var lv := Meta.char_level(c)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 20)
		v.add_child(head)
		var hl := _lbl("%s · NIVEAU %d" % [def["name"].to_upper(), lv], 26, C_GOLD)
		head.add_child(hl)
		var fp := Meta.talent_points_free(c)
		head.add_child(_lbl("%d point(s) libre(s)" % fp, 22, C_OK if fp > 0 else C_DIM))
		if lv < 15:
			var lo := Meta.char_level_xp(lv)
			var hi := Meta.char_level_xp(lv + 1)
			_bar(v, float(int(cd["xp"]) - lo) / maxf(1.0, hi - lo), Color(0.5, 0.75, 1.0))
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 12)
		v.add_child(cols)
		for bi in 3:
			var br: Array = def["tree"][bi]
			var have: int = int(cd["talents"][bi])
			var bv := _card(cols, C_PANEL2)
			bv.add_child(_lbl(br[0].to_upper(), 20, Color.WHITE))
			for i in 5:
				var node: Array = br[1][i]
				var col := C_OK if i < have else (C_TEXT if i == have else C_DIM)
				var pre := "✔ " if i < have else ("▸ " if i == have else "· ")
				var req := "" if i < have else "  (niv %d)" % Meta.talent_level_req(i)
				bv.add_child(_lbl(pre + Meta.stat_text(node[0], node[1]) + req, 16, col))
			var can := have < 5 and fp > 0 and lv >= Meta.talent_level_req(have)
			var tb := _btn("APPRENDRE" if have < 5 else "COMPLET", 18, can)
			tb.pressed.connect(func(): Meta.buy_talent(c, bi); _refresh())
			bv.add_child(tb)
		v.add_child(_lbl("Arme de départ : %s · %s · Ultime (E) : %s — %s" % [Data.WEAPONS[def["weapon"]]["name"], def["passive"], def["ult"], def["ult_desc"]], 15, C_DIM))
		var sr := HBoxContainer.new()
		sr.add_theme_constant_override("separation", 10)
		v.add_child(sr)
		sr.add_child(_lbl("TENUES :", 18, Color.WHITE, false))
		for si in Meta.SKINS[c].size():
			var sk: Array = Meta.SKINS[c][si]
			var owned: bool = Meta.skin_owned(c, si)
			var sel: bool = Meta.skin_sel(c) == si
			var label: String = ("● " if sel else "○ ") + sk[0] + ("" if owned else "  · %d médailles" % sk[3])
			var sb := _btn(label, 16, owned or int(Meta.data["medals"]) >= int(sk[3]))
			if sel: sb.add_theme_stylebox_override("normal", _sb(C_RED, C_GOLD, 2))
			sb.pressed.connect(func():
				if Meta.skin_owned(c, si): Meta.set_skin(c, si)
				else: Meta.buy_skin(c, si)
				_refresh())
			sr.add_child(sb)

# ---------------------------------------------------------------- USINE
func _tab_usine():
	_title("USINE D'ARMEMENT", "La maîtrise monte avec les ennemis éliminés par l'arme, toutes runs confondues : +4 % de dégâts par niveau, et des modules à équiper (un par arme).")
	var g := _grid(2)
	for w in Data.WEAPONS:
		var name: String = Data.WEAPONS[w]["name"]
		var v := _card(g, C_PANEL, Color(1, 1, 1, 0.06), 1, 420)
		if not Meta.weapon_unlocked(w):
			var wg: int = Meta.WEAPON_GRADE.get(w, 1)
			var lrow := HBoxContainer.new(); lrow.add_theme_constant_override("separation", 12); v.add_child(lrow)
			var lic := TextureRect.new(); lic.texture = U.icon("weapon", w); lic.custom_minimum_size = Vector2(64, 64); lic.modulate = Color(0.35, 0.35, 0.35)
			lic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; lic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lrow.add_child(lic)
			lrow.add_child(_lbl(name.to_upper() + "  · VERROUILLÉ", 24, C_DIM))
			v.add_child(_lbl(Data.WEAPONS[w]["desc"], 16, C_DIM))
			var ub := _btn("DÉBLOQUER · %d médailles%s" % [Meta.WEAPON_UNLOCK[w], (" · grade %d requis" % wg) if Meta.grade() < wg else ""], 18, Meta.data["medals"] >= Meta.WEAPON_UNLOCK[w] and Meta.grade() >= wg)
			ub.pressed.connect(func(): Meta.unlock_weapon(w); _refresh())
			v.add_child(ub)
			continue
		var dmg := float(Meta.data["mastery"].get(w, 0.0))
		var ml := Meta.weapon_mastery(w)
		var hrow := HBoxContainer.new(); hrow.add_theme_constant_override("separation", 12); v.add_child(hrow)
		var wic := TextureRect.new(); wic.texture = U.icon("weapon", w); wic.custom_minimum_size = Vector2(64, 64)
		wic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; wic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hrow.add_child(wic)
		hrow.add_child(_lbl("%s · MAÎTRISE %s" % [name.to_upper(), _pips(ml, 5)], 24, C_GOLD))
		v.add_child(_lbl(Data.WEAPONS[w]["desc"], 15, C_DIM))
		var evl := "Évolution : %s (niv %d + décret %s)" % [Data.WEAPONS[w]["evo_name"], Data.EVO_MIN_LV, Data.DECRETS[Data.WEAPONS[w]["evo"]]["name"]]
		var fid := Data.fusion_of(w)
		if fid != "":
			var fd: Dictionary = Data.FUSIONS[fid]
			evl += "\nFusion : %s (avec %s)" % [fd["name"], Data.WEAPONS[fd["b"] if fd["a"] == w else fd["a"]]["name"]]
		v.add_child(_lbl(evl, 15, Color(0.85, 0.75, 0.5)))
		if ml < 5:
			var lo: float = Meta.MASTERY_XP[ml]
			var hi: float = Meta.MASTERY_XP[ml + 1]
			_bar(v, (dmg - lo) / maxf(1.0, hi - lo), Color(1, 0.55, 0.25))
			v.add_child(_lbl("%d / %d éliminations" % [int(dmg), int(hi)], 15, C_DIM))
		var cur: String = Meta.data["modules"].get(w, "")
		var none := _btn(("● " if cur == "" else "○ ") + "Aucun module", 17)
		none.pressed.connect(func(): Meta.equip_module(w, ""); _refresh())
		v.add_child(none)
		for m in Meta.MODULES:
			if Meta.MODULES[m][0] != w: continue
			var av := Meta.module_available(m)
			var mb := _btn(("● " if cur == m else "○ ") + "%s%s" % [Meta.MODULES[m][2], "" if av else "  (maîtrise %d)" % Meta.MODULES[m][1]], 17, av)
			mb.tooltip_text = Meta.MODULES[m][3]
			mb.pressed.connect(func(): Meta.equip_module(w, m); _refresh())
			v.add_child(mb)
			v.add_child(_lbl("     " + Meta.MODULES[m][3], 15, C_DIM if not av else Color(0.8, 0.77, 0.72)))

# ---------------------------------------------------------------- PLAN
func _tab_plan():
	var plan: Dictionary = Meta.data["plan"]
	_title("PLAN QUINQUENNAL N°%d" % Meta.data["plan_no"], "Remplis les 3 quotas en %d run(s). Chaque quota rapporte des médailles, le plan complet un bonus et un camarade. Un plan raté : le Parti PURGE une amélioration du Bureau pendant tout le plan suivant." % plan["runs_left"])
	for q in plan["quotas"]:
		var v := _card(content, C_PANEL, C_OK if q["done"] else Color(1, 1, 1, 0.06), 2 if q["done"] else 1)
		v.add_child(_lbl(("✔  " if q["done"] else "") + q["text"], 26, C_OK if q["done"] else C_TEXT))
		_bar(v, _qfrac(q), C_OK if q["done"] else C_GOLD)
		v.add_child(_lbl(_qprog(q), 18, C_DIM))
	if Meta.data["bureau_purged"] != "":
		var pv := _card(content, Color(0.25, 0.07, 0.06), C_BAD, 2)
		pv.add_child(_lbl("PURGE EN COURS : « %s » est désactivé jusqu'au prochain plan." % Meta.BUREAU[Meta.data["bureau_purged"]]["name"], 22, C_BAD))

# ---------------------------------------------------------------- DIRECTIVES
func _tab_directives():
	_title("DIRECTIVES DU PARTI", "Rends la run plus dure pour gagner plus : chaque point de ferveur donne +15 %% de médailles. Meilleure victoire : ferveur %d." % Meta.data["directives_best"])
	if Meta.grade() < Meta.DIRECTIVES_GRADE:
		var lv0 := _card(content, C_PANEL, C_BAD, 2)
		lv0.add_child(_lbl("Accessible au grade %d." % Meta.DIRECTIVES_GRADE, 26, C_BAD))
		return
	var g := _grid(2)
	for id in Meta.DIRECTIVES:
		var dd: Dictionary = Meta.DIRECTIVES[id]
		var lv := int(Meta.run_directives.get(id, 0))
		var v := _card(g, C_PANEL2 if lv > 0 else C_PANEL, C_BAD if lv > 0 else Color(1, 1, 1, 0.06), 2 if lv > 0 else 1, 420)
		v.add_child(_lbl("%s  %s" % [dd["name"].to_upper(), _pips(lv, dd["max"])], 22, C_BAD if lv > 0 else C_TEXT))
		v.add_child(_lbl("%s (+%d ferveur par niveau)" % [dd["desc"], dd["ferveur"]], 17, C_DIM))
		var b := _btn("NIVEAU SUIVANT" if lv < dd["max"] else "DÉSACTIVER", 18)
		b.pressed.connect(func():
			var n := (int(Meta.run_directives.get(id, 0)) + 1) % (int(dd["max"]) + 1)
			if n == 0: Meta.run_directives.erase(id)
			else: Meta.run_directives[id] = n
			_refresh())
		v.add_child(b)
	var f := Meta.ferveur(Meta.run_directives)
	content.add_child(_lbl("FERVEUR TOTALE : %d  ·  médailles x%.2f" % [f, 1.0 + 0.15 * f], 30, C_GOLD))

func _tab_options():
	_title("OPTIONS", "Réglages de lisibilité. Ils sont enregistrés avec ta sauvegarde.")
	var v := _card(content, C_PANEL)
	v.add_child(_lbl("CHIFFRES DE DÉGÂTS", 24, C_GOLD))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); v.add_child(row)
	for o in [[2, "TOUS"], [1, "CRITIQUES SEULEMENT"], [0, "AUCUN"]]:
		var b := _btn(("● " if int(Meta.opt("numbers")) == o[0] else "○ ") + o[1], 20)
		b.pressed.connect(func(): Meta.set_opt("numbers", o[0]); _refresh())
		row.add_child(b)
	v.add_child(_lbl("INTENSITÉ DES EFFETS DE TES ARMES", 24, C_GOLD))
	v.add_child(_lbl("Les dangers ennemis (zones rouges, tirs) restent toujours bien visibles.", 16, C_DIM))
	var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 10); v.add_child(row2)
	for o in [100, 75, 50, 25]:
		var b := _btn(("● " if int(Meta.opt("fx")) == o else "○ ") + "%d %%" % o, 20)
		b.pressed.connect(func(): Meta.set_opt("fx", o); _refresh())
		row2.add_child(b)
	v.add_child(_lbl("TREMBLEMENT DE L'ÉCRAN", 24, C_GOLD))
	var row3 := HBoxContainer.new(); row3.add_theme_constant_override("separation", 10); v.add_child(row3)
	for o in [100, 50, 0]:
		var b := _btn(("● " if int(Meta.opt("shake")) == o else "○ ") + "%d %%" % o, 20)
		b.pressed.connect(func(): Meta.set_opt("shake", o); _refresh())
		row3.add_child(b)
	for vk in [["music", "VOLUME DE LA MUSIQUE"], ["sfx", "VOLUME DES EFFETS SONORES"]]:
		v.add_child(_lbl(vk[1], 24, C_GOLD))
		var rowv := HBoxContainer.new(); rowv.add_theme_constant_override("separation", 10); v.add_child(rowv)
		for o in [100, 70, 40, 0]:
			var b := _btn(("● " if int(Meta.opt(vk[0])) == o else "○ ") + ("%d %%" % o if o > 0 else "Coupé"), 20)
			var key: String = vk[0]
			b.pressed.connect(func(): Meta.set_opt(key, o); Snd.apply_volumes(); _refresh())
			rowv.add_child(b)
	v.add_child(_lbl("MINI-CARTE", 24, C_GOLD))
	var row4 := HBoxContainer.new(); row4.add_theme_constant_override("separation", 10); v.add_child(row4)
	for o in [1, 0]:
		var b := _btn(("● " if int(Meta.opt("minimap")) == o else "○ ") + ("Activée" if o == 1 else "Désactivée"), 20)
		b.pressed.connect(func(): Meta.set_opt("minimap", o); _refresh())
		row4.add_child(b)
	var dv := _card(content, Color(0.22, 0.07, 0.06), C_BAD, 1)
	dv.add_child(_lbl("Contrôles : ZQSD · souris · Espace saut · Maj glissade (traînée de feu) · clic droit / C esquive · F interagir · E ultime · Échap pause · M mini-carte · Tab grande carte\nCartes : 1/2/3 choisir · T relancer · B bannir · X passer", 18, C_TEXT))

func _launch():
	var ls: Dictionary = Meta.data.get("launch", {"zone": 1, "tier": 1, "endless": false})
	Meta.run_zone = int(ls["zone"])
	Meta.run_tier = int(ls["tier"])
	Meta.run_endless = bool(ls["endless"])
	Meta.carry = {}
	Meta.save()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ---------------------------------------------------------------- screenshots (tests)
func _take_shots():
	for t in ["lancer", "bureau", "caserne", "usine", "plan", "directives", "options"]:
		tab = t
		_refresh()
		for i in 4: await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(shots_dir)
		get_viewport().get_texture().get_image().save_png("%s/hub_%s.png" % [shots_dir, t])
	get_tree().quit()

# ---------------------------------------------------------------- bot (simulation of many runs)
func _bot_step():
	if runs_target > 0 and int(Meta.data["runs"]) >= runs_target:
		_bot_summary()
		get_tree().quit()
		return
	if not bot_nospend: _bot_spend()
	if bot_char != "":
		Meta.data["chars"][bot_char]["unlocked"] = true
		for w in Meta.WEAPON_UNLOCK: Meta.data["weapons"][w] = true
	var unlocked := []
	for c in Meta.CHARACTERS:
		if Meta.data["chars"][c]["unlocked"]: unlocked.append(c)
	Meta.run_char = bot_char if bot_char != "" else unlocked[int(Meta.data["runs"]) % unlocked.size()]
	Meta.run_directives = {}
	if bot_dirs:
		var f := int(Meta.data["wins"]) - 1
		var order := ["productivisme", "cadence", "sans_pitie", "lutte", "penurie", "productivisme", "cadence", "sans_pitie"]
		for i in clampi(f, 0, order.size()):
			Meta.run_directives[order[i]] = int(Meta.run_directives.get(order[i], 0)) + 1
	_launch()

func _bot_spend():
	var changed := true
	while changed:
		changed = false
		var best = null
		var best_cost := 1 << 30
		for id in Meta.BUREAU:
			var r := Meta.bureau_rank(id)
			if r < Meta.BUREAU[id]["max"] and Meta.grade() >= Meta.bureau_grade_req(id, r) and Meta.bureau_cost(id, r) < best_cost:
				best_cost = Meta.bureau_cost(id, r); best = ["bureau", id]
		for c in Meta.CHARACTERS:
			if not Meta.data["chars"][c]["unlocked"] and Meta.grade() >= int(Meta.CHAR_GRADE.get(c, 1)) and Meta.CHARACTERS[c]["cost"] < best_cost:
				best_cost = Meta.CHARACTERS[c]["cost"]; best = ["char", c]
		for w in Meta.WEAPON_UNLOCK:
			if not Meta.weapon_unlocked(w) and Meta.grade() >= int(Meta.WEAPON_GRADE.get(w, 1)) and Meta.WEAPON_UNLOCK[w] < best_cost:
				best_cost = Meta.WEAPON_UNLOCK[w]; best = ["weapon", w]
		if best != null and best_cost <= int(Meta.data["medals"]):
			match best[0]:
				"bureau": changed = Meta.buy_bureau(best[1])
				"char": changed = Meta.unlock_char(best[1])
				"weapon": changed = Meta.unlock_weapon(best[1])
	for c in Meta.CHARACTERS:
		var guard := 0
		while Meta.talent_points_free(c) > 0 and guard < 20:
			guard += 1
			var t: Array = Meta.data["chars"][c]["talents"]
			var bi := -1
			for i in 3:
				if int(t[i]) < 5 and Meta.char_level(c) >= Meta.talent_level_req(int(t[i])) and (bi < 0 or int(t[i]) < int(t[bi])): bi = i
			if bi < 0 or not Meta.buy_talent(c, bi): break
	for m in Meta.MODULES:
		if Meta.module_available(m):
			Meta.equip_module(Meta.MODULES[m][0], m)

func _bot_summary():
	var d: Dictionary = Meta.data
	var b := []
	for id in d["bureau"]: b.append("%s%d" % [id, d["bureau"][id]])
	var cl := []
	for c in d["chars"]:
		if d["chars"][c]["unlocked"]: cl.append("%s:lv%d" % [c, Meta.char_level(c)])
	var ml := []
	for w in Data.WEAPONS: ml.append("%s:%d" % [w, Meta.weapon_mastery(w)])
	print("[meta-summary] runs=%d wins=%d best=%d medals=%d bureau=%s chars=%s mastery=%s plan=%d" % [d["runs"], d["wins"], int(d["best_time"]), d["medals"], ",".join(b), ",".join(cl), ",".join(ml), d["plan_no"]])
