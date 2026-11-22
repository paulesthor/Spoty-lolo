extends Node3D
# VFX look-dev: fire pools, slide trail, explosion, slam, impacts. godot --path . res://lookdev/vfx.tscn -- out=/tmp/v.png
var out := "/tmp/vfx.png"
var frame := 0
var trail: Node3D
var c := Vector3.ZERO
func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	var world = load("res://scripts/world.gd").new()
	add_child(world)
	world.build(7)
	c = world.player_start
	var cam := Camera3D.new(); add_child(cam); cam.fov = 50
	cam.global_position = c + Vector3(0, 6.5, 10.0); cam.look_at(c + Vector3(0, 0.8, 0))
	VFX.fire(self, c + Vector3(-4.5, 0, 0), 2.2)
	VFX.fire(self, c + Vector3(-1.0, 0, -3), 1.2)
	trail = VFX.trail_emitter(self)
	VFX.trail_on(trail, true)
func _process(d):
	frame += 1
	if frame == 6: Engine.time_scale = 0.05
	if trail: trail.global_position = c + Vector3(-1.0 + sin(Time.get_ticks_msec() * 0.0004) * 3.0, 0, 3.5)
	if frame == 10: VFX.explosion(self, c + Vector3(3.5, 0.3, -1), 2.8)
	if frame == 11: VFX.slam(self, c + Vector3(1.0, 0, 2), 3.0, Color(1, 0.75, 0.2))
	if frame == 12:
		for i in 3: VFX.impact(self, c + Vector3(5.5 + i, 1.0, 2.5), Color(1, 0.8, 0.3), 10)
	if frame == 15:
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
