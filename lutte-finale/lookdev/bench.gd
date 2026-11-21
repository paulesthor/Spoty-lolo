extends Node3D
# headless animation cost benchmark: godot --headless res://lookdev/bench.tscn -- mode=quat|old n=200 step=1
var aps: Array = []
var mode := "quat"
var n := 200
var step := 1
var f := 0
var t0 := 0
func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="): mode = a.substr(5)
		if a.begins_with("n="): n = int(a.substr(2))
		if a.begins_with("step="): step = int(a.substr(5))
	for i in n:
		var p := Vector3(i % 20, 0, i / 20) * 2.0
		var nd: Node3D
		if mode == "quat": nd = Chars.build_enemy(self, "cadre", p, 1.8)
		else: nd = U.place(self, U.CH + "character-a.glb", p, 1.8, 0.0)
		var ap := U.anim_player(nd)
		if ap:
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var an := "Walk" if ap.has_animation("Walk") else "walk"
			ap.play(an)
			aps.append(ap)
	t0 = Time.get_ticks_usec()
func _process(d):
	f += 1
	for i in aps.size():
		if (f + i) % step == 0: aps[i].advance(d * step)
	if f == 300:
		print("mode=%s n=%d step=%d  ms/frame=%.2f" % [mode, n, step, (Time.get_ticks_usec() - t0) / 300000.0])
		get_tree().quit()
