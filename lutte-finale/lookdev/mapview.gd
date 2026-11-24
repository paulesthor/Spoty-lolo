extends Node3D
# map look-dev: build a zone and frame a lot of a given kind.
# godot --path . res://lookdev/mapview.tscn -- zone=4 lot=plage out=/tmp/m.png [seed=3] [far]
func _ready():
	var zone := 1
	var kind := "market"
	var out := "/tmp/map.png"
	var sd := 1917
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zone="): zone = int(a.substr(5))
		elif a.begins_with("lot="): kind = a.substr(4)
		elif a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("seed="): sd = int(a.substr(5))
	Levels.set_zone(Levels.zone(zone))
	var world = load("res://scripts/world.gd").new()
	add_child(world)
	world.build(sd, Levels.zone(zone))
	var target: Vector3 = world.player_start
	for l in world.lots:
		if l[1] == kind:
			var r: Rect2 = l[0]
			target = Vector3(r.get_center().x, 0, r.get_center().y)
			break
	var cam := Camera3D.new(); add_child(cam); cam.fov = 50
	var far := "far" in OS.get_cmdline_user_args()
	cam.global_position = target + (Vector3(0, 22.0, 26.0) if far else Vector3(0, 9.0, 13.0))
	cam.look_at(target + Vector3(0, 1.0, 0))
	for i in 40: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
