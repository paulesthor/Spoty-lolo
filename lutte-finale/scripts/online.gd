extends Node
# "Jouer en ligne": host a game (your PC runs it) or join a comrade's game by address, then the lobby.
# Test hooks (after "--"): online=host  online=join:127.0.0.1  autostart=N (host starts when N comrades are in)

var stage
var hero: Node3D
var root: Control
var name_edit: LineEdit
var ip_edit: LineEdit
var char_lbl: Label
var status_lbl: Label
var addr_lbl: Label
var list_box: VBoxContainer
var host_box: VBoxContainer
var start_btn: Button
var zone_btn: Button
var tier_btn: Button
var connect_box: VBoxContainer
var chars: Array = []
var host_btn: Button

# B on the gamepad always goes back, even while a text field is selected
func _input(ev: InputEvent):
	if ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		_back()
var ci := 0
var skin := 0
var autostart := 0
var t := 0.0

func _ready():
	stage = load("res://scripts/stage.gd").new()
	add_child(stage)
	stage.build(1)
	for c in Meta.CHARACTERS:
		if Meta.data["chars"].has(c) and Meta.data["chars"][c]["unlocked"]: chars.append(c)
	if chars.is_empty(): chars = ["stakhanov"]
	ci = maxi(0, chars.find(Meta.run_char))
	skin = Meta.skin_sel(chars[ci])
	_place_hero()
	UIK.grade(self)
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = UIK.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	_build_ui()
	Net.lobby_changed.connect(_refresh)
	Net.status_changed.connect(_refresh)
	UIK.fade_in(self)
	Snd.music("radio", 0.6)
	for a in OS.get_cmdline_user_args():
		if a == "online=host": _host()
		elif a.begins_with("online=join:"): ip_edit.text = a.substr(12); _join()
		elif a.begins_with("autostart="): autostart = int(a.substr(10))
		elif a.begins_with("lobbyshot="): _shot_later(a.substr(10))
	_refresh()

func _shot_later(path: String):
	for i in 40: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _place_hero():
	if hero: hero.queue_free()
	hero = stage.place_hero(chars[ci], 0, skin)

func _build_ui():
	var title := UIK.label(root, "JOUER EN LIGNE", 64, UIK.RED, "RussoOne")
	title.position = Vector2(60, 30)
	title.add_theme_color_override("font_shadow_color", Color(0.95, 0.9, 0.79, 0.9)); title.add_theme_constant_override("shadow_offset_x", 4); title.add_theme_constant_override("shadow_offset_y", 4)
	var sub := UIK.label(root, "Coop de 2 à 4 camarades · l'hôte fait tourner la partie sur son PC, les autres le rejoignent par son adresse.", 20, UIK.GOLD)
	sub.position = Vector2(64, 112)
	# left: who you are + host / join
	var left := UIK.panel(root)
	left.position = Vector2(50, 160); left.custom_minimum_size = Vector2(560, 0)
	var lv := VBoxContainer.new(); lv.add_theme_constant_override("separation", 10); left.add_child(lv)
	UIK.label(lv, "TON NOM", 20, UIK.GOLD)
	name_edit = LineEdit.new(); name_edit.focus_mode = Control.FOCUS_CLICK; name_edit.text = String(Meta.data.get("net_name", "Camarade")); name_edit.max_length = 16
	_style_edit(name_edit)
	lv.add_child(name_edit)
	UIK.label(lv, "TON CAMARADE", 20, UIK.GOLD)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); lv.add_child(row)
	UIK.button(row, "◀", 24, 60).pressed.connect(func(): _cycle_char(-1))
	char_lbl = UIK.label(row, "", 26, UIK.PAPER, "RussoOne"); char_lbl.custom_minimum_size = Vector2(330, 0)
	char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIK.button(row, "▶", 24, 60).pressed.connect(func(): _cycle_char(1))
	UIK.button(lv, "TENUE SUIVANTE", 20, 300).pressed.connect(_cycle_skin)
	connect_box = VBoxContainer.new(); connect_box.add_theme_constant_override("separation", 10); lv.add_child(connect_box)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 10); connect_box.add_child(sp)
	host_btn = UIK.button(connect_box, "★  HÉBERGER UNE PARTIE", 28, 480)
	host_btn.pressed.connect(_host)
	host_btn.call_deferred("grab_focus")
	UIK.label(connect_box, "ou rejoindre l'adresse de l'hôte :", 20, UIK.DIM)
	var jr := HBoxContainer.new(); jr.add_theme_constant_override("separation", 8); connect_box.add_child(jr)
	ip_edit = LineEdit.new(); ip_edit.focus_mode = Control.FOCUS_CLICK; ip_edit.placeholder_text = "ex. 86.212.45.10"; ip_edit.text = String(Meta.data.get("net_ip", "")); ip_edit.custom_minimum_size = Vector2(290, 0)
	_style_edit(ip_edit)
	jr.add_child(ip_edit)
	UIK.button(jr, "REJOINDRE", 24, 180).pressed.connect(_join)
	# a keypad so the address can be typed with a gamepad too
	var kp := GridContainer.new(); kp.columns = 6
	kp.add_theme_constant_override("h_separation", 6); kp.add_theme_constant_override("v_separation", 6)
	connect_box.add_child(kp)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "⌫"]:
		var kb := UIK.button(kp, k, 22, 70)
		kb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		kb.pressed.connect(func():
			if k == "⌫": ip_edit.text = ip_edit.text.substr(0, maxi(0, ip_edit.text.length() - 1))
			else: ip_edit.text += k)
	var back := UIK.button(lv, "◀ MENU PRINCIPAL", 22, 300)
	back.pressed.connect(_back)
	# right: lobby
	var right := UIK.panel(root)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT); right.offset_left = -720; right.offset_top = 160; right.offset_right = -50
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 10); right.add_child(rv)
	UIK.label(rv, "LE SALON", 26, UIK.GOLD, "RussoOne")
	status_lbl = UIK.label(rv, "", 20, UIK.PAPER, "Oswald", true); status_lbl.custom_minimum_size = Vector2(600, 0)
	addr_lbl = UIK.label(rv, "", 22, UIK.GOLD, "Oswald", true); addr_lbl.custom_minimum_size = Vector2(600, 0)
	list_box = VBoxContainer.new(); list_box.add_theme_constant_override("separation", 6); rv.add_child(list_box)
	host_box = VBoxContainer.new(); host_box.add_theme_constant_override("separation", 8); rv.add_child(host_box)
	zone_btn = UIK.button(host_box, "", 22, 560); zone_btn.pressed.connect(_cycle_zone)
	tier_btn = UIK.button(host_box, "", 22, 560); tier_btn.pressed.connect(_cycle_tier)
	start_btn = UIK.button(host_box, "EN AVANT, CAMARADES !", 32, 560); start_btn.pressed.connect(_start)
	var help := UIK.label(rv, "Si personne n'arrive à se connecter : l'hôte ouvre le port %d (UDP) sur sa box vers son PC, ou vous installez tous un réseau virtuel gratuit (Radmin VPN, ZeroTier) et vous utilisez l'adresse qu'il affiche." % Net.PORT, 16, UIK.DIM, "Oswald", true)
	help.custom_minimum_size = Vector2(600, 0)

func _style_edit(e: LineEdit):
	e.add_theme_font_override("font", UIK.font("Oswald"))
	e.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.04, 0.035, 0.95); sb.border_color = UIK.RED; sb.border_width_bottom = 3
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	e.add_theme_stylebox_override("normal", sb)
	var fb := sb.duplicate(); fb.border_color = UIK.GOLD
	e.add_theme_stylebox_override("focus", fb)
	e.add_theme_color_override("font_color", UIK.PAPER)

func _cycle_char(dir: int):
	ci = (ci + dir + chars.size()) % chars.size()
	skin = Meta.skin_sel(chars[ci])
	_place_hero()
	Net.pick(chars[ci], skin)
	_refresh()

func _cycle_skin():
	skin = (skin + 1) % 3
	_place_hero()
	Net.pick(chars[ci], skin)

func _save_prefs():
	Meta.data["net_name"] = name_edit.text.strip_edges()
	Meta.data["net_ip"] = ip_edit.text.strip_edges()
	Meta.save()

func _host():
	_save_prefs()
	Net.host(_name(), chars[ci], skin)
	Net.set_setting("zone", 1)
	_refresh()

func _join():
	if ip_edit.text.strip_edges() == "": return
	_save_prefs()
	Net.join(ip_edit.text, _name(), chars[ci], skin)
	_refresh()

func _name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Camarade"

func _cycle_zone():
	Net.set_setting("zone", Levels.next_zone(int(Net.settings.get("zone", 1))))

func _cycle_tier():
	var tr: int = int(Net.settings.get("tier", 1)) % 3 + 1
	while not Meta.tier_unlocked(tr): tr = tr % 3 + 1
	Net.set_setting("tier", tr)

func _start():
	if not Net.is_host or Net.lobby.size() < 1: return
	Net.start_game()

func _back():
	Net.leave()
	UIK.fade_out(self, func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))

func _refresh():
	if char_lbl == null: return
	char_lbl.text = (Meta.CHARACTERS[chars[ci]]["name"] as String).to_upper()
	status_lbl.text = Net.status if Net.status != "" else "Héberge une partie ou rejoins celle d'un camarade."
	connect_box.visible = not Net.active
	var addr := ""
	if Net.is_host and Net.vpn_ip != "":
		addr = "Adresse à donner (%s) : %s" % [Net.vpn_name, Net.vpn_ip]
	elif Net.is_host:
		var pub: String = Net.public_ip if Net.public_ip != "" else ("(recherche…)" if Net.status.begins_with("Partie ouverte") else "inconnue · tape « quelle est mon IP » sur internet")
		addr = "Adresse à donner à tes camarades : %s" % pub
		if Net.local_ip != "": addr += "\nSur le même réseau local : %s" % Net.local_ip
	addr_lbl.text = addr
	for c in list_box.get_children(): c.queue_free()
	for i in Net.lobby.size():
		var l: Dictionary = Net.lobby[i]
		var txt := "J%d · %s  —  %s%s" % [i + 1, l["name"], (Meta.CHARACTERS.get(l["char"], {"name": "?"})["name"] as String).to_upper(), "  (hôte)" if i == 0 else ""]
		UIK.label(list_box, txt, 22, [UIK.GOLD, Color(0.4, 0.85, 1.0), Color(0.5, 1.0, 0.5), Color(1.0, 0.55, 0.9)][i % 4])
	host_box.visible = Net.is_host
	if Net.is_host:
		var z: int = int(Net.settings.get("zone", 1))
		zone_btn.text = "DÉPART · " + Levels.label(z)
		tier_btn.text = "DIFFICULTÉ : %s" % (Meta.TIERS[int(Net.settings.get("tier", 1)) - 1]["name"] as String).to_upper()
		start_btn.disabled = Net.lobby.size() < 1
		start_btn.text = "EN AVANT, CAMARADES ! (%d / 4)" % Net.lobby.size()
	elif Net.active and not Net.lobby.is_empty():
		var z2: int = int(Net.settings.get("zone", 1))
		addr_lbl.text = "L'hôte prépare la partie · " + Levels.label(z2).to_lower()

func _process(d: float):
	t += d
	var fo := get_viewport().gui_get_focus_owner()
	if Input.is_action_just_pressed("ui_cancel") and not (fo is LineEdit) and not Input.is_joy_button_pressed(0, JOY_BUTTON_B): _back()
	if stage and stage.cam:
		stage.cam.position = Vector3(0.25 + sin(t * 0.2) * 0.3, 2.5, 6.8)
		stage.cam.look_at(Vector3(0.25, 1.8, 0))
	if hero: hero.rotation.y = sin(t * 0.5) * 0.4
	if autostart > 0 and Net.is_host and Net.lobby.size() >= autostart:
		autostart = 0
		get_tree().create_timer(1.0).timeout.connect(_start)
