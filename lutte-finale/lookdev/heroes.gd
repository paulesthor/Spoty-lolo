extends Node3D
# Hero lineup: every comrade with each outfit. godot --path . res://lookdev/heroes.tscn -- out=/tmp/h.png
var out := "/tmp/heroes.png"
var frame := 0
func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	var world = load("res://scripts/world.gd").new()
	add_child(world)
	world.build(7)
	var c: Vector3 = world.player_start
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.global_position = c + Vector3(0, 3.6, 12.5)
	cam.look_at(c + Vector3(0, 1.4, 0))
	var ids: Array = Chars.HEROES.keys()
	if "enemies" in OS.get_cmdline_user_args():
		# every capitalist with its accessories, close up
		var kinds := ["stagiaire", "cadre", "trader", "influenceur", "banquier", "crypto", "avocat", "huissier", "coach", "lobbyiste", "drh", "golden"]
		cam.fov = 22
		cam.global_position = c + Vector3(-2.5, 2.2, 6.0)
		cam.look_at(c + Vector3(-2.5, 1.55, 0))
		for j in kinds.size():
			var kind: String = kinds[j]
			var e := Chars.build_enemy(self, kind, c + Vector3(-5.5 + j * 1.0, 0, 0), 1.6)
			var acc: Array = Data.ENEMIES[kind]["acc"]
			if kind == "cadre": acc = ["tophat", "cigar"]
			if not acc.is_empty(): Chars.attach(e, acc)
			var eap := U.anim_player(e)
			if eap: eap.play("Idle"); eap.seek(0.3, true); eap.pause()
		return
	if "close" in OS.get_cmdline_user_args():
		ids = ids.slice(0, 8) if not "back" in OS.get_cmdline_user_args() else ids.slice(8)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("only="): ids = Array(a.substr(5).split(","))
		cam.global_position = c + Vector3(0, 2.4, 10.5)
		cam.look_at(c + Vector3(0, 1.1, 1.5))
		if "heads" in OS.get_cmdline_user_args():
			cam.fov = 30
			cam.global_position = c + Vector3(0, 3.0, 9.0 if ids.size() < 4 else 14.0)
			cam.look_at(c + Vector3(0, 1.9, 1.5))
	for i in ids.size():
		for sk in 1:
			var h := Node3D.new()
			add_child(h)
			var m := Chars.build_hero(h, ids[i], sk)
			var back := "back" in OS.get_cmdline_user_args() and not "close" in OS.get_cmdline_user_args()
			var row := i / 8 if not back else (0 if i >= 7 else 1)
			if "close" in OS.get_cmdline_user_args(): row = 0
			var col := (i % 8) if not back else ((i - 7) if i >= 7 else i)
			h.global_position = c + Vector3((col - (3.5 if not "close" in OS.get_cmdline_user_args() else (ids.size() - 1) / 2.0)) * 1.9, 0, -row * 3.0 + 1.5)
			m.rotation.y = 0.35
			var ap := U.anim_player(m)
			if ap: ap.play("2H_Melee_Idle"); ap.seek(0.3, true); ap.pause()
	for j in (0 if "close" in OS.get_cmdline_user_args() else 4):
		var kind: String = ["banquier", "crypto", "cadre", "avocat"][j]
		var e := Chars.build_enemy(self, kind, c + Vector3(-7.5 + j * 1.6, 0, 4.5), 1.8)
		Chars.attach(e, Data.ENEMIES[kind]["acc"] + (["cigar"] if kind == "cadre" else []))
		e.rotation.y = 0.2
		var eap := U.anim_player(e)
		if eap: eap.play("Idle"); eap.seek(0.3, true); eap.pause()
func _process(_d):
	frame += 1
	if frame == 30:
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
