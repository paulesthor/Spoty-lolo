extends Node3D
# weapon models gallery: lookdev/weapons.tscn -- out=<png>
func _ready():
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.25, 0.27, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.8, 0.8, 0.85); e.ambient_light_energy = 0.7
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); add_child(sun)
	var items := [["ours_yeti.gltf", 1.8], ["kalach.glb", 0.4], ["scythe.gltf", 1.2], ["guitar_A.gltf", 1.0], ["star_red.gltf", 0.8], ["pickaxe.gltf", 1.0],
		["furniture/speaker.glb", 0.8], ["graveyard/iron_fence.glb", 1.2], ["pirate/bottle.glb", 0.6], ["weaponpack/rocket.glb", 0.8], ["cage/Cage_Small.gltf", 1.2]]
	if "bear" in OS.get_cmdline_user_args(): items = [["kk_bear.gltf", 1.6]]
	if "flag" in OS.get_cmdline_user_args():
		for k in 3:
			var pole := U.cyl(self, 0.05, 4.0, Vector3(-3.0 + k * 3.0, 2.0, 0), U.solid(Color(0.7, 0.7, 0.72)))
			var fl := Node3D.new(); add_child(fl); fl.position = Vector3(-3.0 + k * 3.0, 3.4, 0); fl.rotation.y = PI / 2 + k * 0.4
			U.flag_cloth(fl, Vector2(1.5, 0.95), Vector3(0, 0, 0.04), "res://assets/textures/flag_soviet.png", k * 2.0)
		var cam3 := Camera3D.new(); add_child(cam3); cam3.fov = 40
		cam3.global_position = Vector3(0, 3.2, 7.0); cam3.look_at(Vector3(0, 2.8, 0))
		await get_tree().create_timer(0.7).timeout
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="): get_viewport().get_texture().get_image().save_png(a.substr(4))
		get_tree().quit()
		return
	if "props" in OS.get_cmdline_user_args():
		items = []
		for d in DirAccess.get_directories_at("res://assets/props"):
			for f in DirAccess.get_files_at("res://assets/props/" + d):
				if f.ends_with(".glb") or f.ends_with(".gltf"): items.append(["../props/" + d + "/" + f, 1.2])
		var cols := 8
		for i in items.size():
			var nn := U.place(self, "res://assets/weapons/" + items[i][0], Vector3(-7.0 + (i % cols) * 2.0, 0, -(i / cols) * 2.5), items[i][1], 0.6)
		var cam2 := Camera3D.new(); add_child(cam2); cam2.fov = 50
		cam2.global_position = Vector3(0, 7.0, 9.0); cam2.look_at(Vector3(0, 0, -3.5))
		await get_tree().create_timer(0.5).timeout
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="): get_viewport().get_texture().get_image().save_png(a.substr(4))
		get_tree().quit()
		return
	if "set2" in OS.get_cmdline_user_args():
		items = [["treats/kettle.gltf", 0.8], ["treats/teapot.gltf", 0.8], ["furniture/radio.glb", 0.6], ["furniture/speakerSmall.glb", 0.6], ["td/weapon-ammo-bullet.glb", 0.6], ["proto/Bullet.gltf", 0.6], ["kalach.glb", 0.4], ["pickaxe.gltf", 1.0], ["guitar_A.gltf", 1.0], ["furniture/speaker.glb", 0.8], ["../kaykit_props/hammer_A.gltf", 1.0]]
	for i in items.size():
		var n := U.place(self, "res://assets/weapons/" + items[i][0], Vector3(-7.5 + i * 1.5 if items.size() > 1 else 0.0, 0, 0), items[i][1], 0.6)
		if items[i][0].begins_with("ours"):
			for m in n.find_children("*", "MeshInstance3D", true, false):
				var mat := StandardMaterial3D.new()
				var src = (m as MeshInstance3D).get_active_material(0)
				if src is StandardMaterial3D: mat = src.duplicate()
				mat.albedo_color = Color(0.62, 0.4, 0.24)
				(m as MeshInstance3D).material_override = mat
			var ap := U.anim_player(n)
			if ap: ap.play("Walk")
	var cam := Camera3D.new(); add_child(cam); cam.fov = 35
	cam.global_position = Vector3(0, 2.0, 12.0); cam.look_at(Vector3(0, 0.6, 0))
	if items.size() == 1: cam.global_position = Vector3(1.5, 1.6, 4.0); cam.look_at(Vector3(0, 0.9, 0))
	await get_tree().create_timer(0.5).timeout
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("out="):
			get_viewport().get_texture().get_image().save_png(a.substr(4))
	get_tree().quit()
