extends Node
# Gamepad everywhere (autoload "Pad"):
#  - the left stick and the D-pad move between buttons, A presses, B goes back (ui_cancel);
#  - a gold frame shows which button is selected while the pad is in use;
#  - if nothing is selected, the first visible button gets the focus as soon as the pad is touched;
#  - when a menu rebuilds itself (Kolkhoze tabs, options...), the selection comes back to the same place.

var frame: Panel
var layer: CanvasLayer
var pad_mode := false
var _last_path: Array = []
var _last_scene: Node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var axes := {"ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0], "ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for a in axes:
		if not InputMap.has_action(a): continue
		var has := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadMotion: has = true
		if not has:
			var m := InputEventJoypadMotion.new(); m.axis = axes[a][0]; m.axis_value = axes[a][1]
			InputMap.action_add_event(a, m)
		InputMap.action_set_deadzone(a, 0.5)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var found := false
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton and ev.button_index == pair[1]: found = true
		if not found:
			var b := InputEventJoypadButton.new(); b.button_index = pair[1]
			InputMap.action_add_event(pair[0], b)
	layer = CanvasLayer.new(); layer.layer = 120; add_child(layer)
	frame = Panel.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 0.8, 0.3, 0.08); sb.border_color = Color(1, 0.8, 0.3)
	sb.set_border_width_all(4); sb.set_corner_radius_all(3)
	sb.shadow_color = Color(1, 0.75, 0.2, 0.5); sb.shadow_size = 8
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	layer.add_child(frame)

func _in_game_play(scene: Node) -> bool:
	return "state" in scene and scene.state == "play"

func _input(ev: InputEvent):
	if ev is InputEventMouseMotion or ev is InputEventMouseButton:
		pad_mode = false
		return
	var pad: bool = (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.55)
	if not pad: return
	pad_mode = true
	var scene := get_tree().current_scene
	if scene == null or _in_game_play(scene): return
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner()
	if f != null and f.is_visible_in_tree(): return
	var b := _restore(scene)
	if b == null: b = _first_focusable(scene)
	if b:
		b.grab_focus()
		vp.set_input_as_handled()

func _process(_d: float):
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_last_path = []
	var f := get_viewport().gui_get_focus_owner()
	var show := pad_mode and f != null and f.is_visible_in_tree() and scene != null and not _in_game_play(scene)
	if f != null and is_instance_valid(f) and scene != null and scene.is_ancestor_of(f):
		_last_path = _index_path(scene, f)
	elif f == null and not _last_path.is_empty() and scene != null and pad_mode and not _in_game_play(scene):
		# the focused button was rebuilt: pick the one now at the same place
		var r := _restore(scene)
		if r: r.grab_focus()
	frame.visible = show
	if show:
		var rect := f.get_global_rect()
		frame.position = rect.position - Vector2(5, 5)
		frame.size = rect.size + Vector2(10, 10)

func _index_path(root: Node, n: Node) -> Array:
	var out := []
	while n != null and n != root:
		out.push_front(n.get_index())
		n = n.get_parent()
	return out

func _restore(scene: Node) -> Control:
	if _last_path.is_empty(): return null
	var n: Node = scene
	for i in _last_path:
		if i >= n.get_child_count(): return null
		n = n.get_child(i)
	if n is Control and (n as Control).is_visible_in_tree() and (n as Control).focus_mode != Control.FOCUS_NONE:
		return n
	return null

func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible: continue
		if c is Control:
			var ctl: Control = c
			if ctl.is_visible_in_tree() and (ctl is BaseButton or ctl is LineEdit) and ctl.focus_mode != Control.FOCUS_NONE and not (ctl is BaseButton and (ctl as BaseButton).disabled):
				return ctl
		var deeper := _first_focusable(c)
		if deeper: return deeper
	return null

# test hook: padtest=down,down,a,b,... presses those pad inputs one by one and logs the selection
func _enter_tree():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("padtest="): _run_test.call_deferred(a.substr(8).split(","))

func _run_test(steps: PackedStringArray):
	await get_tree().create_timer(2.5).timeout
	for s in steps:
		var ev
		match s:
			"up", "down", "left", "right":
				ev = InputEventJoypadButton.new()
				ev.button_index = {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT}[s]
			"sdown", "sup":
				ev = InputEventJoypadMotion.new(); ev.axis = JOY_AXIS_LEFT_Y; ev.axis_value = 1.0 if s == "sdown" else -1.0
			"a": ev = InputEventJoypadButton.new(); ev.button_index = JOY_BUTTON_A
			"b": ev = InputEventJoypadButton.new(); ev.button_index = JOY_BUTTON_B
			"start": ev = InputEventJoypadButton.new(); ev.button_index = JOY_BUTTON_START
			"rb": ev = InputEventJoypadButton.new(); ev.button_index = JOY_BUTTON_RIGHT_SHOULDER
			"wait":
				await get_tree().create_timer(2.0).timeout
				continue
		if ev is InputEventJoypadButton: ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.15).timeout
		var rel = ev.duplicate()
		if rel is InputEventJoypadButton: rel.pressed = false
		else: rel.axis_value = 0.0
		Input.parse_input_event(rel)
		await get_tree().create_timer(0.6).timeout
		var f := get_viewport().gui_get_focus_owner()
		var sc := get_tree().current_scene
		print("[pad] %s -> scene=%s focus=%s" % [s, sc.name if sc else "?", (f.get("text") if f and f.get("text") != null else str(f))])
	get_tree().quit()
