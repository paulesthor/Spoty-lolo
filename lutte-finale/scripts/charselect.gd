extends Node
# Comrade selection: the six comrades on podiums under spotlights. The chosen one steps forward
# and salutes; locked ones are black silhouettes. Run settings (zone, difficulty, mode) and launch.

var stage
var ids: Array = []
var holders: Array = []
var sel := 0
var cam_x := 0.0
var t := 0.0
var info: VBoxContainer
var sheet: VBoxContainer

# characteristics shown on the sheet: [key, label, base value, unit, min, max]
const STATS := [["hp", "PV", 120.0, "", 80.0, 180.0], ["productivite", "DÉGÂTS", 100.0, "%", 85.0, 115.0], ["cadence", "CADENCE", 100.0, "%", 85.0, 115.0],
	["vitesse", "VITESSE", 100.0, "%", 85.0, 115.0], ["jump", "SAUT", 100.0, "%", 75.0, 150.0], ["critique", "CRITIQUE", 5.0, "%", 0.0, 20.0],
	["chance", "CHANCE", 0.0, "%", -10.0, 12.0], ["expansion", "ZONE", 100.0, "%", 85.0, 120.0], ["aimant", "AIMANT", 100.0, "%", 85.0, 135.0],
	["armure", "ARMURE", 0.0, "", -1.0, 3.0]]
const EXTRAS := {"regen": "Régénération %+.1f PV/s", "dodge": "Esquive %d %%", "propagande": "XP %+d %%", "duree": "Durée des effets %+d %%",
	"crit_dmg": "Dégâts critiques %+d %%", "reroll": "Relance de cartes +%d", "air": "Portée en l'air %+d %%"}

func _sheet(c: String):
	for ch in sheet.get_children(): ch.queue_free()
	var def: Dictionary = Meta.CHARACTERS[c]
	var b: Dictionary = def["base"]
	UIK.label(sheet, "FICHE DU CAMARADE", 22, UIK.GOLD, "RussoOne")
	for st in STATS:
		var key: String = st[0]
		var base: float = st[2]
		var v: float = base + float(b.get("endurance" if key == "hp" else key, 0.0))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); sheet.add_child(row)
		var nl := UIK.label(row, st[1], 16, UIK.PAPER); nl.custom_minimum_size = Vector2(90, 0)
		var bar := ProgressBar.new(); bar.show_percentage = false; bar.custom_minimum_size = Vector2(190, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.value = clampf((v - st[4]) / (st[5] - st[4]), 0.03, 1.0) * 100.0
		var good: bool = v > base + 0.01
		var bad: bool = v < base - 0.01
		var fill := StyleBoxFlat.new(); fill.bg_color = Color(0.35, 0.8, 0.35) if good else (Color(0.85, 0.22, 0.2) if bad else Color(0.8, 0.74, 0.62))
		var bgs := StyleBoxFlat.new(); bgs.bg_color = Color(0, 0, 0, 0.45)
		bar.add_theme_stylebox_override("fill", fill); bar.add_theme_stylebox_override("background", bgs)
		row.add_child(bar)
		var txt := ("%d" % int(v)) if st[3] == "" else ("%d %%" % int(round(v)))
		UIK.label(row, txt, 16, Color(0.6, 1, 0.6) if good else (Color(1, 0.5, 0.45) if bad else UIK.DIM))
	var extra := []
	for k in EXTRAS:
		if not b.has(k): continue
		if k == "regen": extra.append("Aucune régénération" if 0.4 + float(b[k]) <= 0.0 else (EXTRAS[k] as String) % float(b[k]))
		else: extra.append((EXTRAS[k] as String) % int(b[k]))
	if not extra.is_empty():
		UIK.label(sheet, " · ".join(extra), 15, UIK.GOLD, "Oswald", true).custom_minimum_size = Vector2(380, 0)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 4); sheet.add_child(sp)
	var bio := UIK.label(sheet, String(def.get("bio", "")), 16, Color(0.86, 0.82, 0.74), "Oswald", true)
	bio.custom_minimum_size = Vector2(380, 0)
var skins_row: HBoxContainer
var go_btn: Button
var medals_lbl: Label
var settings := {}
var set_btns := {}

func _ready():
	Snd.music("march")
	ids = Meta.CHARACTERS.keys()
	stage = load("res://scripts/stage.gd").new()
	add_child(stage)
	stage.build(ids.size(), 2.25, 0.12)
	for i in ids.size(): holders.append(null)
	for i in ids.size(): _place(i)
	for i in ids.size():
		var nm: String = Meta.CHARACTERS[ids[i]]["name"]
		stage.plates[i].text = nm.to_upper() if _unlocked(ids[i]) else "???"
	sel = maxi(0, ids.find(Meta.run_char))
	settings = Meta.data.get("launch", {"zone": 1, "tier": 1, "endless": false}).duplicate()
	if not Meta.zone_unlocked(int(settings["zone"])): settings["zone"] = 1
	if not Meta.tier_unlocked(int(settings["tier"])): settings["tier"] = 1
	if not Meta.endless_unlocked(): settings["endless"] = false
	UIK.grade(self)
	_ui()
	_select(sel, false)
	cam_x = stage.podiums[sel].x
	UIK.fade_in(self, 0.5)
	if "selectshot" in OS.get_cmdline_user_args(): _shot()

func _unlocked(c: String) -> bool:
	return Meta.data["chars"][c]["unlocked"]

func _place(i: int):
	if holders[i]: holders[i].queue_free()
	var c: String = ids[i]
	holders[i] = stage.place_hero(c, i, Meta.skin_sel(c), not _unlocked(c))

# ---------------------------------------------------------------- UI
func _ui():
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = UIK.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	# header
	var head := UIK.label(root, "CHOISIS TON CAMARADE", 56, UIK.PAPER, "RussoOne")
	head.position = Vector2(60, 30)
	head.add_theme_color_override("font_shadow_color", UIK.RED); head.add_theme_constant_override("shadow_offset_x", 4); head.add_theme_constant_override("shadow_offset_y", 4)
	medals_lbl = UIK.label(root, "", 24, UIK.GOLD)
	medals_lbl.position = Vector2(64, 100)
	# info panel (right)
	var p := UIK.panel(root)
	p.set_anchors_preset(Control.PRESET_RIGHT_WIDE); p.offset_left = -500; p.offset_right = -40; p.offset_top = 40; p.offset_bottom = -170
	info = VBoxContainer.new(); info.add_theme_constant_override("separation", 8); p.add_child(info)
	# character sheet (left): characteristics as bars + a short (dark) biography
	var sp := UIK.panel(root, Color(0.08, 0.065, 0.06, 0.86))
	sp.position = Vector2(40, 140); sp.custom_minimum_size = Vector2(400, 0)
	sheet = VBoxContainer.new(); sheet.add_theme_constant_override("separation", 4); sp.add_child(sheet)
	# bottom bar: navigation, run settings, launch
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); bar.offset_left = 60; bar.offset_right = -40; bar.offset_top = -140; bar.offset_bottom = -40
	bar.add_theme_constant_override("separation", 14)
	root.add_child(bar)
	var back := UIK.button(bar, "◀ MENU", 22, 150); back.pressed.connect(func(): _go("res://scenes/title.tscn"))
	var hub := UIK.button(bar, "KOLKHOZE", 22, 170); hub.pressed.connect(func(): Meta.hub_tab = "caserne"; _go("res://scenes/hub.tscn"))
	var prev := UIK.button(bar, "◀", 30, 70); prev.pressed.connect(func(): _select(posmod(sel - 1, ids.size())))
	var nxt := UIK.button(bar, "▶", 30, 70); nxt.pressed.connect(func(): _select(posmod(sel + 1, ids.size())))
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 4); bar.add_child(sv)
	set_btns["zone"] = UIK.button(sv, "", 18, 300)
	set_btns["zone"].pressed.connect(func(): _cycle("zone"))
	set_btns["tier"] = UIK.button(sv, "", 18, 300)
	set_btns["tier"].pressed.connect(func(): _cycle("tier"))
	set_btns["endless"] = UIK.button(bar, "", 18, 210)
	set_btns["endless"].pressed.connect(func(): _cycle("endless"))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; bar.add_child(spacer)
	go_btn = UIK.button(bar, "EN AVANT, CAMARADE !", 32, 460)
	go_btn.add_theme_stylebox_override("normal", UIK.sb(UIK.RED, UIK.GOLD))
	go_btn.add_theme_stylebox_override("hover", UIK.sb(Color(0.95, 0.15, 0.15), UIK.PAPER))
	go_btn.pressed.connect(_launch)
	go_btn.call_deferred("grab_focus")
	_refresh_settings()

func _refresh_settings():
	var z: int = settings["zone"]
	set_btns["zone"].text = Levels.label(z)
	var tr: int = settings["tier"]
	set_btns["tier"].text = "DIFFICULTÉ : %s" % (Meta.TIERS[tr - 1]["name"] as String).to_upper()
	set_btns["endless"].text = "MODE : SANS FIN" if settings["endless"] else "MODE : UN ACTE"
	set_btns["endless"].disabled = not Meta.endless_unlocked()
	medals_lbl.text = "%d médailles  ·  grade %d : %s" % [int(Meta.data["medals"]), Meta.grade(), Meta.GRADE_NAMES[Meta.grade() - 1]]

func _cycle(k: String):
	match k:
		"zone":
			settings["zone"] = Levels.next_zone(int(settings["zone"]))
		"tier":
			var tr: int = settings["tier"] % 3 + 1
			while not Meta.tier_unlocked(tr): tr = tr % 3 + 1
			settings["tier"] = tr
		"endless":
			settings["endless"] = not settings["endless"] and Meta.endless_unlocked()
	_refresh_settings()

func _select(i: int, cheer := true):
	if cheer: Snd.play("ui_hover", -6.0, 0.05, 0.05, 0.8)
	sel = i
	var c: String = ids[i]
	for k in ids.size():
		var on: bool = k == i
		if k < stage.plates.size(): stage.plates[k].visible = on      # one name at a time: the plates used to overlap
		var sp: SpotLight3D = stage.spots[k]
		sp.light_energy = 9.0 if on else 1.2
		sp.shadow_enabled = on
		var h: Node3D = holders[k]
		var tw := h.create_tween()
		tw.tween_property(h, "position", stage.podiums[k] + (Vector3(0, 0, 0.35) if on else Vector3.ZERO), 0.25)
		tw.parallel().tween_property(h, "scale", Vector3.ONE * (1.22 if on else 0.92), 0.25).set_trans(Tween.TRANS_BACK)
	var ap := U.anim_player(holders[i])
	var move: String = Chars.SELECT_ANIM.get(c, "Cheer")
	if cheer and ap and _unlocked(c) and ap.has_animation(move):
		# each comrade's signature move, then back to idle
		ap.play(move, 0.12)
		var dur: float = minf(ap.get_animation(move).length, 2.4)
		var tok := Time.get_ticks_msec()
		holders[i].set_meta("move_tok", tok)
		get_tree().create_timer(dur).timeout.connect(func():
			if is_instance_valid(ap) and holders[i].get_meta("move_tok", 0) == tok: ap.play("2H_Melee_Idle", 0.25))
	if _unlocked(c):
		Meta.run_char = c
		Meta.data["last_char"] = c
	_info()

func _info():
	for ch in info.get_children(): ch.queue_free()
	var c: String = ids[sel]
	_sheet(c)
	var def: Dictionary = Meta.CHARACTERS[c]
	var unlocked := _unlocked(c)
	UIK.label(info, (def["name"] as String).to_upper(), 40, UIK.RED if unlocked else UIK.DIM, "RussoOne", true)
	if not unlocked and def.has("unlock"):
		UIK.label(info, "Camarade à réhabiliter par un exploit.", 24, UIK.PAPER, "Oswald", true)
		UIK.label(info, "Arme de départ : %s" % Data.WEAPONS[def["weapon"]]["name"], 22, UIK.GOLD)
		UIK.label(info, def["passive"], 20, UIK.PAPER, "Oswald", true)
		UIK.label(info, "DÉFI", 20, UIK.RED, "RussoOne")
		UIK.label(info, Meta.challenge_text(c), 20, UIK.GOLD, "Oswald", true)
		var pb := ProgressBar.new(); pb.show_percentage = false; pb.custom_minimum_size = Vector2(0, 14)
		pb.value = clampf(Meta.challenge_value(c) / Meta.challenge_target(c), 0.0, 1.0) * 100.0
		info.add_child(pb)
		go_btn.disabled = true
		return
	if not unlocked:
		var cg: int = Meta.CHAR_GRADE.get(c, 1)
		UIK.label(info, "Camarade non encore réhabilité.", 24, UIK.PAPER, "Oswald", true)
		UIK.label(info, "Arme de départ : %s" % Data.WEAPONS[def["weapon"]]["name"], 22, UIK.GOLD)
		UIK.label(info, def["passive"], 20, UIK.PAPER, "Oswald", true)
		UIK.label(info, "Coût : %d médailles · grade %d requis (%s)" % [def["cost"], cg, Meta.GRADE_NAMES[cg - 1]], 20, UIK.DIM, "Oswald", true)
		var can: bool = int(Meta.data["medals"]) >= int(def["cost"]) and Meta.grade() >= cg
		var rb := UIK.button(info, "RÉHABILITER · %d MÉDAILLES" % def["cost"], 22, 420)
		rb.disabled = not can
		rb.pressed.connect(func():
			if Meta.unlock_char(c):
				_place(sel); _select(sel); _refresh_settings())
		go_btn.disabled = true
		return
	go_btn.disabled = false
	var wrow := HBoxContainer.new(); wrow.add_theme_constant_override("separation", 10); info.add_child(wrow)
	var wic := TextureRect.new(); wic.texture = U.icon("weapon", def["weapon"]); wic.custom_minimum_size = Vector2(56, 56)
	wic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; wic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wrow.add_child(wic)
	UIK.label(wrow, "Niveau %d  ·  arme : %s" % [Meta.char_level(c), Data.WEAPONS[def["weapon"]]["name"]], 22, UIK.GOLD)
	UIK.label(info, Data.WEAPONS[def["weapon"]]["desc"], 18, UIK.DIM, "Oswald", true)
	UIK.label(info, "PASSIF", 20, UIK.RED, "RussoOne")
	UIK.label(info, def["passive"], 20, UIK.PAPER, "Oswald", true)
	UIK.label(info, "ULTIME (E) · %s" % (def["ult"] as String).to_upper(), 20, UIK.RED, "RussoOne", true)
	UIK.label(info, def["ult_desc"], 20, UIK.PAPER, "Oswald", true)
	UIK.label(info, "TENUE", 20, UIK.RED, "RussoOne")
	skins_row = HBoxContainer.new(); skins_row.add_theme_constant_override("separation", 6); info.add_child(skins_row)
	UIK.label(info, "Tenue choisie : " + Meta.SKINS[c][Meta.skin_sel(c)][0], 16, UIK.DIM)
	for si in Meta.SKINS[c].size():
		var sk: Array = Meta.SKINS[c][si]
		var owned: bool = Meta.skin_owned(c, si)
		var b := UIK.button(skins_row, ("● %d" % (si + 1) if Meta.skin_sel(c) == si else "%d" % (si + 1)) + ("" if owned else " · %d ★" % sk[3]), 14, 112)
		b.tooltip_text = sk[0]
		b.disabled = not owned and int(Meta.data["medals"]) < int(sk[3])
		b.pressed.connect(func():
			if Meta.skin_owned(c, si): Meta.set_skin(c, si)
			else: Meta.buy_skin(c, si)
			_place(sel); _select(sel, false); _refresh_settings())

func _launch():
	if not _unlocked(ids[sel]): Snd.play("ui_error"); return
	Snd.play("ui_confirm"); Snd.stop_music(0.7)
	Meta.data["launch"] = settings
	Meta.run_zone = int(settings["zone"]); Meta.run_tier = int(settings["tier"]); Meta.run_endless = bool(settings["endless"])
	Meta.carry = {}
	Meta.save()
	var ap := U.anim_player(holders[sel])
	if ap and ap.has_animation("Cheer"): ap.play("Cheer", 0.1)
	UIK.fade_out(self, func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), 0.7)

func _go(scene: String):
	Meta.save()
	UIK.fade_out(self, func(): get_tree().change_scene_to_file(scene))

func _input(ev: InputEvent):
	if ev is InputEventJoypadButton and ev.pressed:
		if ev.button_index == JOY_BUTTON_LEFT_SHOULDER: _select(posmod(sel - 1, ids.size()))
		elif ev.button_index == JOY_BUTTON_RIGHT_SHOULDER: _select(posmod(sel + 1, ids.size()))

func _process(d: float):
	t += d
	# the whole line-up stays in view on the left; the camera leans gently toward the chosen one
	# the camera travels along the line-up, keeping the chosen one left of the info panel
	cam_x = lerpf(cam_x, stage.podiums[sel].x, 1.0 - exp(-4.0 * d))
	stage.cam.position = Vector3(cam_x + 3.4, 4.0 + sin(t * 0.3) * 0.08, 12.5)
	stage.cam.look_at(Vector3(cam_x + 2.8, 1.9, 0.0))
	# left/right pick a comrade while the launch button has the focus (up/down reach the other buttons);
	# the shoulder buttons always do
	var f := get_viewport().gui_get_focus_owner()
	if f == null or f == go_btn:
		if Input.is_action_just_pressed("ui_left"): _select(posmod(sel - 1, ids.size()))
		if Input.is_action_just_pressed("ui_right"): _select(posmod(sel + 1, ids.size()))
	if Input.is_action_just_pressed("ui_cancel"): _go("res://scenes/title.tscn")

func _shot():
	for i in 40: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1])
	get_tree().quit()
