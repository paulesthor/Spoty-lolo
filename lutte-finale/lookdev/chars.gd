extends Node3D
# Character look-dev: same procedural map and lighting, three ways to build the cast.
#   style=kaykit : KayKit bodies + animations, recoloured, with our accessories
#   style=quat   : Quaternius outfits (suits, worker...) recoloured per enemy type
#   style=mix    : KayKit hero, Quaternius capitalists
# godot --path . res://lookdev/chars.tscn -- style=mix out=/tmp/x.png

const KK := "res://assets/kaykit/"
const QM := "res://assets/quaternius/Male/"
const QF := "res://assets/quaternius/Female/"
const CAM_OFFSET := Vector3(0, 7.5, 10.5)
const CAM_LOOK := Vector3(0, 0.3, -6.5)

var style := "mix"
var out := "/tmp/chars.png"
var frame := 0
var world
var rng := RandomNumberGenerator.new()
const HIDE := ["Hat", "Helmet", "Hood", "Axe", "Sword", "Shield", "Mug", "Staff", "Crossbow", "Dagger", "Wand", "Spellbook", "Quiver", "Arrow", "Cape", "Book"]

func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("style="): style = a.substr(6)
		if a.begins_with("out="): out = a.substr(4)
	rng.seed = 7
	world = load("res://scripts/world.gd").new()
	add_child(world)
	world.build(424242)
	var c: Vector3 = world.player_start
	var cam_rig := Node3D.new()
	add_child(cam_rig)
	cam_rig.global_position = c
	var cam := Camera3D.new()
	cam.fov = 55
	cam_rig.add_child(cam)
	cam.position = CAM_OFFSET
	cam.basis = Basis.looking_at(CAM_LOOK - CAM_OFFSET, Vector3.UP)
	cam.make_current()
	# hero
	var hero: Node3D
	if style == "quat":
		hero = _quat(QM + "Worker.glb", c, 1.85, PI, {"Shirt": Color(0.7, 0.1, 0.12)})
		_anim(hero, "Sword_Slash", 0.35)
		_attach(hero, ["chapka"])
		_hammer(hero, "Wrist.R")
	else:
		hero = _kaykit("Barbarian", c, 1.85, PI, Color(1, 1, 1))
		_anim(hero, "2H_Melee_Attack_Chop", 0.45)
		_attach(hero, ["chapka"])
		_hammer(hero, "handslot.r")
	# horde
	for i in 34:
		var z := rng.randf_range(-4.0, -24.0)
		var spread: float = lerp(4.0, 10.0, -z / 24.0)
		var p := c + Vector3(rng.randf_range(-spread, spread), 0, z)
		var face := atan2(c.x - p.x, c.z - p.z)
		var e: Node3D
		var kind: String = ["cadre", "cadre", "trader", "banquier", "stagiaire", "influenceuse"][i % 6]
		if style == "kaykit":
			var body: String = ["Knight", "Rogue", "Mage", "Rogue_Hooded", "Knight", "Rogue"][i % 6]
			var tint: Color = [Color(0.35, 0.35, 0.4), Color(0.3, 0.32, 0.38), Color(0.25, 0.45, 0.3), Color(0.45, 0.42, 0.4), Color(0.6, 0.6, 0.62), Color(0.9, 0.5, 0.7)][i % 6]
			e = _kaykit(body, p, 1.75, face, tint)
			_anim(e, ["Running_A", "Walking_A", "Running_B"][i % 3], rng.randf())
		else:
			e = _capitalist(kind, p, face)
			_anim(e, ["Run", "Walk", "Run"][i % 3], rng.randf())
		var acc := []
		match kind:
			"cadre": acc = ["tophat"] if i % 2 == 0 else ["tophat", "cigar"]
			"trader": acc = ["sunglasses"]
			"banquier": acc = ["tophat", "monocle"]
		if not acc.is_empty(): _attach(e, acc)
	# a few reactions: hit, dying, cheering intern
	for k in 3:
		var p2 := c + Vector3(-3.5 + k * 3.5, 0, -6.5 - k)
		var e2: Node3D = _kaykit("Knight", p2, 1.75, 0.0, Color(0.35, 0.35, 0.4)) if style == "kaykit" else _capitalist("cadre", p2, 0.4)
		if style == "kaykit": _anim(e2, ["Hit_A", "Death_A", "Death_B"][k], [0.2, 0.55, 0.5][k], true)
		else: _anim(e2, ["HitRecieve", "Death", "HitRecieve_2"][k], [0.25, 0.5, 0.3][k], true)
	# golden boy
	var gb: Node3D = _capitalist("golden", c + Vector3(3.5, 0, -11), 0.3) if style != "kaykit" else _kaykit("Knight", c + Vector3(3.5, 0, -11), 3.0, 0.3, Color(1.0, 0.75, 0.25))
	if style != "kaykit": gb.scale *= 1.7
	_anim(gb, "Walk" if style != "kaykit" else "Walking_A", 0.3)
	_attach(gb, ["tophat", "cigar", "monocle"])
	var lab := U.label(self, {"kaykit": "TEST 1 · KAYKIT (corps + animations) + accessoires", "quat": "TEST 2 · QUATERNIUS (tenues recolorées) + accessoires", "mix": "TEST 3 · MIXTE : héros KayKit, capitalistes Quaternius"}[style], c + Vector3(0, 0, 3), 1, Color.WHITE)
	lab.visible = false
	var cl := CanvasLayer.new(); add_child(cl)
	var l := Label.new()
	l.text = lab.text
	l.add_theme_font_override("font", load("res://fonts/Oswald.woff2"))
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_outline_color", Color.BLACK); l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(30, 20)
	cl.add_child(l)

func _process(_d):
	frame += 1
	if frame == 40:
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()

# ---------------------------------------------------------------- builders
func _kaykit(name: String, p: Vector3, h: float, rot: float, tint: Color) -> Node3D:
	var n := U.place(self, KK + name + ".glb", p, h, rot)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		for word in HIDE:
			if word in str(m.name): (m as MeshInstance3D).visible = false
		if tint != Color(1, 1, 1) and not "Head" in str(m.name):
			var mi: MeshInstance3D = m
			for i in mi.mesh.get_surface_count():
				var src = mi.get_active_material(i)
				if src is StandardMaterial3D:
					var d: StandardMaterial3D = src.duplicate()
					d.albedo_color = tint
					mi.set_surface_override_material(i, d)
	return n

const SUITS := {
	"cadre": {"Suit": Color(0.22, 0.23, 0.27), "Tie": Color(0.75, 0.1, 0.1)},
	"trader": {"Suit": Color(0.15, 0.2, 0.35), "Tie": Color(0.95, 0.75, 0.2)},
	"banquier": {"Suit": Color(0.12, 0.3, 0.18), "Tie": Color(0.95, 0.85, 0.3)},
	"stagiaire": {"Suit": Color(0.55, 0.55, 0.58), "Tie": Color(0.3, 0.5, 0.8)},
	"influenceuse": {"Suit": Color(0.9, 0.45, 0.65), "Tie": Color(1, 1, 1)},
	"golden": {"Suit": Color(1.0, 0.75, 0.25), "Tie": Color(0.1, 0.1, 0.1)},
}

func _capitalist(kind: String, p: Vector3, rot: float) -> Node3D:
	var female := kind in ["influenceuse"] or rng.randf() < 0.3
	return _quat((QF if female else QM) + "Suit.glb", p, rng.randf_range(1.7, 1.85), rot, SUITS[kind])

func _quat(path: String, p: Vector3, h: float, rot: float, colors: Dictionary) -> Node3D:
	var n := U.place(self, path, p, h, rot)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src == null: continue
			var nm: String = src.resource_name
			if colors.has(nm):
				var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				d.albedo_color = colors[nm]
				d.roughness = 0.6
				mi.set_surface_override_material(i, d)
	return n

func _anim(n: Node, a: String, t: float, freeze := true):
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		var p: AnimationPlayer = ap
		if not p.has_animation(a): continue
		p.play(a)
		p.seek(t * p.current_animation_length, true)
		if freeze: p.pause()

func _skeleton(n: Node) -> Skeleton3D:
	var l := n.find_children("*", "Skeleton3D", true, false)
	return l[0] if not l.is_empty() else null

# accessories on the head bone, sized from the model's head (works for both rigs)
func _attach(n: Node3D, kinds: Array):
	var sk := _skeleton(n)
	if sk == null: return
	var hb := sk.find_bone("head")
	if hb < 0: hb = sk.find_bone("Head")
	if hb < 0: return
	var top := 0.0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if not (m as MeshInstance3D).visible: continue
		var a: AABB = (sk.global_transform.affine_inverse() * (m as Node3D).global_transform) * (m as MeshInstance3D).get_aabb()
		top = maxf(top, a.end.y)
	var hy := sk.get_bone_global_rest(hb).origin.y
	var hh := top - hy
	var big := sk.find_bone("head") >= 0    # KayKit: big stylised head
	var w := hh * (0.95 if big else 1.25)
	var ba := BoneAttachment3D.new()
	ba.bone_name = sk.get_bone_name(hb)
	sk.add_child(ba)
	var root := Node3D.new()
	ba.add_child(root)
	U._build_accessories(root, kinds, w, hh, 0.0, w * 0.5)

func _hammer(n: Node3D, bone: String):
	var sk := _skeleton(n)
	if sk == null or sk.find_bone(bone) < 0: return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var inv := 1.0 / n.scale.x
	var h := Node3D.new()
	ba.add_child(h)
	U.cyl(h, 0.035, 1.0, Vector3(0, 0.45, 0), U.solid(Color(0.55, 0.33, 0.15)))
	U.box(h, Vector3(0.42, 0.2, 0.2), Vector3(0, 0.95, 0), U.solid(Color(0.5, 0.52, 0.56), 0.0, 0.35, 0.9))
	h.scale = Vector3.ONE * inv
