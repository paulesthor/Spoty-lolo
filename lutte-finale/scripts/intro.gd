extends Control
# Intro: a few poster panels with a slow push-in, typewriter captions and red diagonal wipes.
# Plays on first launch (any key / click skips), then hands over to the title screen.

const PANELS := [
	["ad_0.jpg", "Année 2049.\nLe capitalisme a gagné."],
	["ad_1.jpg", "Les hypermarchés ont remplacé les écoles.\nLes soldes ont remplacé les fêtes nationales."],
	["ad_2.jpg", "Le bonheur se vend désormais en actions.\nLe malheur, lui, est offert pour tout achat."],
	["propaganda_0.jpg", "Mais dans un kolkhoze oublié,\nun camarade se réveille."],
	["propaganda_2.jpg", "Il a un marteau. Il a un plan.\nSurtout, il a un quota."],
]
const PANEL_T := 4.2

var art: TextureRect
var caption: Label
var wipe: Panel
var idx := -1
var t := 0.0
var typed := 0.0
var done := false
var logo: Control

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.05, 0.035, 0.03); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.anchor_right = 0.5; art.offset_left = 60; art.offset_top = 50; art.offset_bottom = -50
	add_child(art)
	caption = UIK.label(self, "", 44, UIK.PAPER, "Oswald", true)
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.anchor_left = 0.53; caption.offset_right = -70; caption.anchor_top = 0.3; caption.anchor_bottom = 0.75
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var skip := UIK.label(self, "Une touche pour passer", 18, UIK.DIM)
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); skip.offset_left = -260; skip.offset_top = -50
	wipe = Panel.new()
	var ws := StyleBoxFlat.new(); ws.bg_color = UIK.RED; ws.skew = Vector2(0.35, 0)
	wipe.add_theme_stylebox_override("panel", ws)
	wipe.size = Vector2(3200, 1400); wipe.position = Vector2(-3400, -200)
	add_child(wipe)
	Snd.music("march", 0.5)
	_next()

func _next():
	idx += 1
	if idx >= PANELS.size():
		_logo(); return
	t = 0.0; typed = 0.0
	art.texture = load("res://assets/posters/" + PANELS[idx][0])
	art.pivot_offset = art.size * 0.5
	art.scale = Vector2.ONE
	caption.text = ""
	# red diagonal wipe across the screen
	wipe.position = Vector2(-3400, -200)
	var tw := wipe.create_tween()
	tw.tween_property(wipe, "position:x", 2400.0, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	Snd.play("whoosh", -8.0, 0.05, 0.1)

func _logo():
	art.visible = false; caption.visible = false
	logo = VBoxContainer.new()
	logo.set_anchors_preset(Control.PRESET_CENTER)
	logo.offset_left = -520; logo.offset_right = 520; logo.offset_top = -170; logo.offset_bottom = 170
	add_child(logo)
	var a := UIK.label(logo, "COMMUNISTE", 120, UIK.RED, "RussoOne")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := UIK.label(logo, "LAND", 170, UIK.PAPER, "RussoOne")
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("font_shadow_color", UIK.RED); b.add_theme_constant_override("shadow_offset_x", 8); b.add_theme_constant_override("shadow_offset_y", 8)
	logo.pivot_offset = Vector2(520, 170)
	logo.scale = Vector2.ONE * 2.5
	logo.modulate.a = 0.0
	var tw := logo.create_tween().set_parallel()
	tw.tween_property(logo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "modulate:a", 1.0, 0.2)
	get_tree().create_timer(0.3).timeout.connect(func(): Snd.play("hammer", 0.0, 0.0, 0.5, 0.8); Snd.play("stamp", 0.0, 0.0, 0.5))
	get_tree().create_timer(2.6).timeout.connect(_finish)

func _finish():
	if done: return
	done = true
	Meta.data["intro_seen"] = true
	Meta.save()
	UIK.fade_out(self, func(): get_tree().change_scene_to_file("res://scenes/title.tscn"), 0.5)

var _shot_t := 0.0
var _shot_n := 0
func _process(d: float):
	for a in OS.get_cmdline_user_args():
		if a.begins_with("introshot="):
			_shot_t += d
			if _shot_t > 2.2:
				_shot_t = 0.0
				get_viewport().get_texture().get_image().save_png("%s/intro_%d.png" % [a.substr(10), _shot_n]); _shot_n += 1
	if idx < 0 or idx >= PANELS.size(): return
	t += d
	art.pivot_offset = art.size * 0.5
	art.scale = Vector2.ONE * (1.0 + t * 0.025)
	if t > 0.5:
		var full: String = PANELS[idx][1]
		var before := int(typed)
		typed = minf(typed + d * 34.0, full.length())
		caption.text = full.substr(0, int(typed))
		if int(typed) > before and int(typed) % 3 == 0 and full[int(typed) - 1] != " ": Snd.play("ui_hover", -18.0, 0.2, 0.03, 1.6)
	if t >= PANEL_T: _next()

func _input(ev: InputEvent):
	if done: return
	if (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton) and ev.is_pressed():
		get_viewport().set_input_as_handled()
		_finish()
