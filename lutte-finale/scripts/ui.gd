class_name UIK
# Constructivist UI kit shared by the menus: slanted panels, red edges, poster typography.

const INK := Color(0.07, 0.055, 0.05)
const PAPER := Color(0.95, 0.9, 0.79)
const RED := Color(0.8, 0.09, 0.12)
const GOLD := Color(1.0, 0.8, 0.3)
const DIM := Color(0.66, 0.61, 0.55)

static var _fonts := {}
static func font(name: String) -> Font:
	if not _fonts.has(name): _fonts[name] = load("res://fonts/%s.woff2" % name)
	return _fonts[name]

static func sb(bg: Color, edge := RED, edge_w := 6, skew := 0.14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.skew = Vector2(skew, 0)
	s.border_color = edge
	s.border_width_left = edge_w
	s.content_margin_left = 22; s.content_margin_right = 18
	s.content_margin_top = 8; s.content_margin_bottom = 8
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("Oswald")
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", sb(Color(0.1, 0.08, 0.07, 0.92)))
	t.set_stylebox("hover", "Button", sb(RED, GOLD))
	t.set_stylebox("pressed", "Button", sb(Color(0.55, 0.05, 0.08), GOLD))
	var fsb := sb(Color(0, 0, 0, 0), GOLD, 0)
	fsb.border_width_bottom = 3; fsb.border_color = GOLD
	t.set_stylebox("focus", "Button", fsb)
	t.set_stylebox("disabled", "Button", sb(Color(0.1, 0.08, 0.07, 0.5), Color(0.3, 0.3, 0.3)))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.43))
	t.set_color("font_color", "Label", PAPER)
	t.set_font("font", "Button", font("RussoOne"))
	return t

static func label(parent: Node, text: String, size: int, col := PAPER, fnt := "Oswald", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(fnt))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

static func button(parent: Node, text: String, size := 26, min_w := 360) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, size * 2.1)
	b.focus_mode = Control.FOCUS_ALL
	# a little jolt on hover: menus should feel alive
	b.pressed.connect(func(): Snd.play("ui_click", -4.0, 0.05, 0.05))
	b.focus_entered.connect(func(): Snd.play("ui_hover", -14.0, 0.05, 0.05))
	b.mouse_entered.connect(func():
		Snd.play("ui_hover", -12.0, 0.05, 0.04)
		b.pivot_offset = b.size * Vector2(0.0, 0.5)
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.08)
		tw.tween_property(b, "scale", Vector2.ONE, 0.1))
	parent.add_child(b)
	return b

static func panel(parent: Node, bg := Color(0.08, 0.065, 0.06, 0.9), edge := RED) -> PanelContainer:
	var p := PanelContainer.new()
	var st := sb(bg, edge, 8, 0.06)
	st.content_margin_left = 44; st.content_margin_right = 30; st.content_margin_top = 22; st.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	return p

# full-screen poster grade above a 3D stage, below the UI
static func grade(parent: Node, layer := 1):
	var cl := CanvasLayer.new(); cl.layer = layer; parent.add_child(cl)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/poster.gdshader"); r.material = m
	cl.add_child(r)

# black-to-clear fade when a menu opens; fade_out then calls `done`
static func fade_in(parent: Node, t := 0.45):
	var cl := CanvasLayer.new(); cl.layer = 50; parent.add_child(cl)
	var r := ColorRect.new(); r.color = Color(0, 0, 0, 1); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, t)
	tw.tween_callback(cl.queue_free)

static func fade_out(parent: Node, done: Callable, t := 0.35):
	var cl := CanvasLayer.new(); cl.layer = 50; parent.add_child(cl)
	var r := ColorRect.new(); r.color = Color(0, 0, 0, 0); r.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 1.0, t)
	tw.tween_callback(done)
