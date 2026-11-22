extends Node
# Title screen: a comrade on the tribune, giant posters, falling leaflets, and the main menu.

const TAGLINES := [
	"Le capitalisme a gagné. Pas pour longtemps.",
	"Un spectre hante l'hypermarché.",
	"Toute ressemblance avec des personnes existantes serait purement idéologique.",
	"Approuvé par le Comité Central. Désapprouvé par le CAC 40.",
	"Le Plan est parfait. Les erreurs sont la faute des saboteurs.",
	"Aucun actionnaire n'a été épargné pendant le développement de ce jeu.",
	"Ce jeu est gratuit. Comme tout, après la Révolution.",
]

var stage
var hero: Node3D
var ap: AnimationPlayer
var t := 0.0
var cheer_t := 4.0
var tagline: Label
var tag_i := 0
var credits: Control
var menu: VBoxContainer

func _ready():
	Snd.music("march")
	stage = load("res://scripts/stage.gd").new()
	add_child(stage)
	stage.build(1)
	var c: String = Meta.run_char if Meta.data["chars"].has(Meta.run_char) and Meta.data["chars"][Meta.run_char]["unlocked"] else "stakhanov"
	hero = stage.place_hero(c, 0, Meta.skin_sel(c))
	hero.rotation.y = -0.35
	ap = U.anim_player(hero)
	# a few capitalists at the foot of the tribune, cowering before the comrade
	var kinds := ["cadre", "banquier", "trader", "cadre"]
	for i in 4:
		var e: Node3D = Chars.build_enemy(stage, kinds[i], Vector3(1.2 + i * 1.25, 0, 3.1 + (i % 2) * 0.5), 1.7)
		Chars.attach(e, Data.ENEMIES[kinds[i]]["acc"])
		e.rotation.y = PI + 0.3 - i * 0.15
		var eap := U.anim_player(e)
		Chars.set_loops(eap)
		if eap and eap.has_animation("HitRecieve_2"):
			eap.get_animation("HitRecieve_2").loop_mode = Animation.LOOP_PINGPONG
			eap.play("HitRecieve_2"); eap.seek(randf() * 0.5, true); eap.speed_scale = 0.35
	UIK.grade(self)
	_ui()
	UIK.fade_in(self, 0.8)
	if "titleshot" in OS.get_cmdline_user_args(): _shot()

func _ui():
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = UIK.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	# left band in the poster red, slanted
	var band := Panel.new()
	var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.06, 0.045, 0.04, 0.82); bs.skew = Vector2(-0.18, 0); bs.border_color = UIK.RED; bs.border_width_right = 10
	band.add_theme_stylebox_override("panel", bs)
	band.set_anchors_preset(Control.PRESET_LEFT_WIDE); band.offset_left = -120; band.offset_right = 860
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_LEFT_WIDE); v.offset_left = 70; v.offset_top = 60; v.offset_right = 700; v.offset_bottom = -40
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	var l1 := UIK.label(v, "COMMUNISTE", 84, UIK.RED, "RussoOne")
	l1.add_theme_color_override("font_shadow_color", Color(0.95, 0.9, 0.79, 0.9)); l1.add_theme_constant_override("shadow_offset_x", 5); l1.add_theme_constant_override("shadow_offset_y", 5)
	var l2 := UIK.label(v, "LAND", 132, UIK.PAPER, "RussoOne")
	l2.add_theme_color_override("font_shadow_color", UIK.RED); l2.add_theme_constant_override("shadow_offset_x", 6); l2.add_theme_constant_override("shadow_offset_y", 6)
	l2.add_theme_constant_override("line_spacing", -20)
	tagline = UIK.label(v, TAGLINES[0], 24, UIK.GOLD, "Oswald", true)
	tagline.custom_minimum_size = Vector2(600, 70)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 30); v.add_child(sp)
	menu = VBoxContainer.new(); menu.add_theme_constant_override("separation", 12); v.add_child(menu)
	var play := UIK.button(menu, "▶  JOUER", 34, 420)
	play.pressed.connect(func(): _go("res://scenes/charselect.tscn"))
	UIK.button(menu, "JOUER EN LIGNE  ·  COOP 2 À 4", 26, 420).pressed.connect(func(): _go("res://scenes/online.tscn"))
	UIK.button(menu, "LE KOLKHOZE  ·  PROGRESSION", 26, 420).pressed.connect(func(): Meta.hub_tab = "bureau"; _go("res://scenes/hub.tscn"))
	UIK.button(menu, "OPTIONS", 26, 420).pressed.connect(func(): Meta.hub_tab = "options"; _go("res://scenes/hub.tscn"))
	credits_btn = UIK.button(menu, "CRÉDITS", 26, 420)
	credits_btn.pressed.connect(func(): credits.visible = true; credits_back.call_deferred("grab_focus"))
	UIK.button(menu, "QUITTER", 26, 420).pressed.connect(func(): get_tree().quit())
	play.grab_focus()
	var foot := UIK.label(root, "Prototype · Tous droits collectivisés · %d médailles · grade %d (%s)" % [int(Meta.data["medals"]), Meta.grade(), Meta.GRADE_NAMES[Meta.grade() - 1]], 18, UIK.DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); foot.offset_left = 70; foot.offset_top = -44
	_credits(root)

func _credits(root: Control):
	credits = Control.new(); credits.set_anchors_preset(Control.PRESET_FULL_RECT); credits.visible = false
	root.add_child(credits)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT); credits.add_child(dim)
	var p := UIK.panel(credits)
	p.set_anchors_preset(Control.PRESET_CENTER); p.offset_left = -470; p.offset_right = 470; p.offset_top = -340; p.offset_bottom = 340
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); p.add_child(v)
	UIK.label(v, "CRÉDITS DU COMITÉ CENTRAL", 40, UIK.RED, "RussoOne")
	UIK.label(v, "Conception, code et propagande : le Parti (et Claude, camarade numérique)\n\nModèles 3D : Kenney (CC0), KayKit · Kay Lousberg (CC0), Quaternius (CC0)\nTextures : ambientCG (CC0) · Végétation : Quaternius Ultimate Stylized Nature (CC0)\nIcônes : game-icons.net (CC BY 3.0) · Delapouite, Lorc, Sbed, Skoll, Zeromancer\nSons : Kenney (CC0) · Musique originale, banque de sons FluidR3 (MIT)\nPolices : Russo One, Oswald, Bangers (SIL Open Font License)\nMoteur : Godot Engine (MIT)\n\nAucun capitaliste réel n'a été blessé. Les caricatures sont des caricatures.\nLe Plan remercie les camarades testeurs, qui seront décorés à titre posthume.", 21, UIK.PAPER, "Oswald", true)
	var crow := HBoxContainer.new(); crow.add_theme_constant_override("separation", 12); v.add_child(crow)
	credits_back = UIK.button(crow, "RETOUR", 24, 240)
	credits_back.pressed.connect(_close_credits)
	UIK.button(crow, "REVOIR L'INTRO", 24, 300).pressed.connect(func(): _go("res://scenes/intro.tscn"))

func _go(scene: String):
	UIK.fade_out(self, func(): get_tree().change_scene_to_file(scene))

func _process(d: float):
	t += d
	stage.cam.position = Vector3(2.6 + sin(t * 0.15) * 0.8, 3.3 + sin(t * 0.21) * 0.2, 9.0)
	stage.cam.look_at(Vector3(-1.6, 2.6, 0.0))
	cheer_t -= d
	if ap and cheer_t <= 0.0:
		cheer_t = 7.0
		ap.play("Cheer", 0.2)
		get_tree().create_timer(2.2).timeout.connect(func(): if ap: ap.play("2H_Melee_Idle", 0.3))
	if int(t / 5.0) != tag_i:
		tag_i = int(t / 5.0)
		tagline.text = TAGLINES[tag_i % TAGLINES.size()]
	if Input.is_action_just_pressed("ui_cancel") and credits.visible: _close_credits()

var credits_btn: Button
var credits_back: Button
func _close_credits():
	credits.visible = false
	if credits_btn: credits_btn.grab_focus()

func _shot():
	for i in 40: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[-1])
	get_tree().quit()
