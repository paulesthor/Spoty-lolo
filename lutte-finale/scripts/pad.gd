extends Node
# Gamepad in the menus (autoload "Pad"): the left stick and the D-pad move between buttons, A presses,
# B goes back. If nothing has the focus when the pad is touched, the first visible button gets it.

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the left stick navigates like the D-pad
	var axes := {"ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0], "ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for a in axes:
		if not InputMap.has_action(a): continue
		var has := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadMotion: has = true
		if not has:
			var m := InputEventJoypadMotion.new(); m.axis = axes[a][0]; m.axis_value = axes[a][1]
			InputMap.action_add_event(a, m)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var found := false
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton and ev.button_index == pair[1]: found = true
		if not found:
			var b := InputEventJoypadButton.new(); b.button_index = pair[1]
			InputMap.action_add_event(pair[0], b)

func _input(ev: InputEvent):
	var pad: bool = (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.55)
	if not pad: return
	var scene := get_tree().current_scene
	if scene == null: return
	# in a run the pad drives the comrade, except on overlays (pause, end, choices) that have buttons
	if "state" in scene and scene.state == "play": return
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner()
	if f != null and f.is_visible_in_tree(): return
	var b := _first_focusable(scene)
	if b:
		b.grab_focus()
		vp.set_input_as_handled()

func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control:
			var ctl: Control = c
			if not ctl.is_visible_in_tree(): continue
			if (ctl is BaseButton or ctl is LineEdit) and ctl.focus_mode != Control.FOCUS_NONE and not (ctl is BaseButton and (ctl as BaseButton).disabled):
				return ctl
		var deeper := _first_focusable(c)
		if deeper: return deeper
	return null
