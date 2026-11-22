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
	for i in ids.size():
		for sk in 1:
			var h := Node3D.new()
			add_child(h)
			var m := Chars.build_hero(h, ids[i], sk)
			var back := "back" in OS.get_cmdline_user_args()
			var row := i / 8 if not back else (0 if i >= 7 else 1)
			var col := (i % 8) if not back else ((i - 7) if i >= 7 else i)
			h.global_position = c + Vector3((col - 3.5) * 1.9, 0, -row * 3.0 + 1.5)
			m.rotation.y = 0.35
			var ap := U.anim_player(m)
			if ap: ap.play("2H_Melee_Idle"); ap.seek(0.3, true); ap.pause()
	for j in 4:
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
