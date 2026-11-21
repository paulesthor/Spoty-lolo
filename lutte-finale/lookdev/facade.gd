extends Node3D
# Facade check: camera inside the arena looking at a border row. -- zone=1 side=left|back out=...
var out := "/tmp/f.png"
var frame := 0
func _ready():
	var zone := 1
	var side := "left"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("zone="): zone = int(a.substr(5))
		if a.begins_with("side="): side = a.substr(5)
	var w = load("res://scripts/world.gd").new()
	add_child(w)
	w.build(5 + zone * 101, Levels.zone(zone))
	var b: Rect2 = w.bounds
	var cam := Camera3D.new(); add_child(cam); cam.fov = 60
	if side == "left":
		cam.global_position = Vector3(b.position.x + 8.0, 5.0, b.get_center().y)
		cam.look_at(Vector3(b.position.x - 16.0, 7.0, b.get_center().y + 10.0))
	else:
		cam.global_position = Vector3(b.get_center().x + 10.0, 5.0, b.position.y + 10.0)
		cam.look_at(Vector3(b.get_center().x, 8.0, b.position.y - 16.0))
	cam.make_current()
func _process(_d):
	frame += 1
	if frame == 25:
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
