class_name U
# Shared helpers: model loading, primitive builders, materials, accessories.

const CH := "res://assets/mini-characters/"
const CC := "res://assets/city-kit-commercial/"
const CR := "res://assets/city-kit-roads/"
const CAR := "res://assets/car-kit/"
const SHOP := "res://assets/mini-shop/"
const SUB := "res://assets/city-kit-suburban/"
const IND := "res://assets/city-kit-industrial/"
const FOOD := "res://assets/food-kit/"

static var _scenes := {}
static var _mats := {}
static var _sym_font: Font
static var font_main: Font
static var font_num: Font

static func fonts():
	if font_main == null:
		font_main = load("res://fonts/Oswald.woff2")
		font_num = load("res://fonts/Oswald.woff2")
		_sym_font = load("res://fonts/Symbols.ttf")

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

static func world_aabb(n: Node) -> AABB:
	var res := AABB()
	var first := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		if m is Label3D: continue
		var a: AABB = m.global_transform * m.get_aabb()
		if first:
			res = a; first = false
		else:
			res = res.merge(a)
	return res

# Instance a model, scale it to `height` (or uniform `sc`), put its base at pos.y and centre at pos.xz.
static func place(parent: Node, path: String, pos: Vector3, height := -1.0, rot := 0.0, sc := 1.0) -> Node3D:
	var n: Node3D = scene(path).instantiate()
	parent.add_child(n)
	n.rotation.y = rot
	if height > 0.0:
		var a := world_aabb(n)
		n.scale = Vector3.ONE * (height / maxf(a.size.y, 0.001))
	else:
		n.scale = Vector3.ONE * sc
	var b := world_aabb(n)
	n.position += Vector3(pos.x - b.get_center().x, pos.y - b.position.y, pos.z - b.get_center().z)
	mute(n)
	return n

static func mute(n: Node):
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src is StandardMaterial3D and mi.get_surface_override_material(i) == null:
				var key := "mute_%d" % src.get_instance_id()
				if not _mats.has(key):
					var d: StandardMaterial3D = src.duplicate()
					d.roughness = 0.75
					d.albedo_color = d.albedo_color * Color(0.92, 0.92, 0.92)
					_mats[key] = d
				mi.set_surface_override_material(i, _mats[key])

static func solid(color: Color, emissive := 0.0, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%f_%f_%f" % [color.to_html(), emissive, rough, metal]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m

static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos; mi.rotation = rot
	parent.add_child(mi)
	return mi

static func cyl(parent: Node, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 16
	m.mesh = c; m.material_override = mat; m.position = pos
	parent.add_child(m)
	return m

static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, h := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = r; s.height = (h if h > 0.0 else r * 2.0)
	m.mesh = s; m.material_override = mat; m.position = pos
	parent.add_child(m)
	return m

static func label(parent: Node, text: String, pos: Vector3, size: int, color: Color, outline_col := Color.BLACK, billboard := true, fnt: Font = null) -> Label3D:
	fonts()
	var l := Label3D.new()
	l.text = text
	l.font = fnt if fnt else font_num
	l.font_size = size
	l.outline_size = int(size * 0.16)
	l.modulate = color
	l.outline_modulate = outline_col
	l.pixel_size = 0.01
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = billboard
	l.shaded = false
	l.double_sided = true
	parent.add_child(l)
	return l

static func fx_material(tex: String, color: Color, energy := 2.0, billboard := true) -> StandardMaterial3D:
	var key := "fx_%s_%s_%f_%s" % [tex, color.to_html(), energy, billboard]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://fx/" + tex)
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mats[key] = m
	return m

static func sprite(parent: Node, tex: String, pos: Vector3, size: float, color: Color, energy := 2.0, billboard := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = fx_material(tex, color, energy, billboard)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func play_anim(n: Node, anim: String, t := -1.0, speed := 1.0):
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		var p: AnimationPlayer = ap
		if p.has_animation(anim):
			if p.current_animation == anim and t < 0.0:
				p.speed_scale = speed
				return
			p.play(anim, 0.15)
			p.speed_scale = speed
			if t >= 0.0:
				p.seek(t, true)
			else:
				p.seek(randf() * p.current_animation_length, true)

static func anim_player(n: Node) -> AnimationPlayer:
	var l := n.find_children("*", "AnimationPlayer", true, false)
	return l[0] if not l.is_empty() else null

# ---------------------------------------------------------------- accessories
static func head_frame(n: Node) -> Array:
	var sks := n.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return []
	var sk: Skeleton3D = sks[0]
	var hb := sk.find_bone("head")
	var hm: Node = null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		if c.name == "head-mesh": hm = c; break
	if hb < 0 or hm == null: return []
	var a: AABB = (sk.global_transform.affine_inverse() * hm.global_transform) * (hm as MeshInstance3D).get_aabb()
	var origin := sk.get_bone_global_rest(hb).origin
	return [sk, a, origin]

static func shrink_head(n: Node, head := 0.78, body := 1.12):
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var hm = load("res://scripts/head_scale.gd").new()
		hm.head_scale = head
		hm.body_scale = body
		sk.add_child(hm)

static func bone_attach(n: Node, bone: String) -> Node3D:
	var f := head_frame(n)
	if f.is_empty(): return null
	var sk: Skeleton3D = f[0]
	if sk.find_bone(bone) < 0: return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var holder := Node3D.new()
	holder.set_meta("w", (f[1] as AABB).size.x)
	ba.add_child(holder)
	return holder

static func attach_head(n: Node, kinds: Array):
	fonts()
	var f := head_frame(n)
	if f.is_empty(): return
	var sk: Skeleton3D = f[0]
	var a: AABB = f[1]
	var o: Vector3 = f[2]
	var w := a.size.x
	var top := a.end.y - o.y
	var cz := a.get_center().z - o.z
	var front := a.end.z - o.z
	var ba := BoneAttachment3D.new()
	ba.bone_name = "head"
	sk.add_child(ba)
	var root := Node3D.new()
	ba.add_child(root)
	for k in kinds:
		match k:
			"chapka":
				var fur := solid(Color(0.5, 0.42, 0.33), 0.0, 1.0)
				var dark := solid(Color(0.33, 0.26, 0.2), 0.0, 1.0)
				cyl(root, w * 0.5, w * 0.3, Vector3(0, top + w * 0.05, cz), dark)
				sphere(root, w * 0.5, Vector3(0, top + w * 0.18, cz), dark, w * 0.45)
				var band := MeshInstance3D.new(); var tb := TorusMesh.new(); tb.inner_radius = w * 0.46; tb.outer_radius = w * 0.66
				band.mesh = tb; band.material_override = fur; band.position = Vector3(0, top - w * 0.06, cz); band.scale = Vector3(1, 1.5, 1); root.add_child(band)
				for sx in [-1.0, 1.0]:
					var flap := box(root, Vector3(w * 0.16, w * 0.62, w * 0.5), Vector3(sx * w * 0.6, top - w * 0.42, cz), fur)
					flap.rotation = Vector3(0, 0, sx * 0.12)
				for zz in [1.0, -1.0]:
					box(root, Vector3(w * 0.2, w * 0.2, w * 0.04), Vector3(0, top - w * 0.02, cz + zz * w * 0.66), solid(Color(0.85, 0.08, 0.1), 0.5), Vector3(0, 0, PI / 4))
					var st := Label3D.new(); st.text = "★"; st.font = _sym_font; st.font_size = 64; st.pixel_size = w * 0.0036
					st.modulate = Color(1, 0.8, 0.2); st.outline_size = 0; st.position = Vector3(0, top - w * 0.02, cz + zz * w * 0.69); st.shaded = false
					st.rotation = Vector3(0, 0 if zz > 0 else PI, 0)
					root.add_child(st)
			"tophat":
				var blk := solid(Color(0.06, 0.06, 0.07), 0.0, 0.5)
				cyl(root, w * 0.52, w * 0.04, Vector3(0, top, cz), blk)
				cyl(root, w * 0.34, w * 0.62, Vector3(0, top + w * 0.31, cz), blk)
				cyl(root, w * 0.35, w * 0.09, Vector3(0, top + w * 0.08, cz), solid(Color(0.95, 0.72, 0.2), 0.0, 0.3, 1.0))
			"cigar":
				var c := cyl(root, w * 0.045, w * 0.38, Vector3(w * 0.12, top - w * 0.78, front + w * 0.16), solid(Color(0.4, 0.22, 0.1)))
				c.rotation = Vector3(PI / 2 - 0.25, 0.35, 0)
				var tip := cyl(root, w * 0.047, w * 0.04, Vector3(w * 0.19, top - w * 0.73, front + w * 0.33), solid(Color(1, 0.4, 0.1), 4.0))
				tip.rotation = c.rotation
			"monocle":
				var m := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = w * 0.09; tm.outer_radius = w * 0.115
				m.mesh = tm; m.material_override = solid(Color(1, 0.8, 0.3), 0.0, 0.2, 1.0)
				m.position = Vector3(w * 0.2, top - w * 0.48, front + w * 0.02); m.rotation = Vector3(PI / 2, 0, 0)
				root.add_child(m)
			"sunglasses":
				for sx in [-1.0, 1.0]:
					box(root, Vector3(w * 0.26, w * 0.13, w * 0.03), Vector3(sx * w * 0.2, top - w * 0.48, front + w * 0.02), solid(Color(0.05, 0.05, 0.06), 0.0, 0.1))
			"cap":
				var cc := solid(Color(0.15, 0.2, 0.35), 0.0, 0.8)
				cyl(root, w * 0.5, w * 0.18, Vector3(0, top + w * 0.02, cz), cc)
				box(root, Vector3(w * 0.7, w * 0.04, w * 0.35), Vector3(0, top - w * 0.06, front + w * 0.1), cc)
				box(root, Vector3(w * 0.22, w * 0.12, w * 0.03), Vector3(0, top + w * 0.02, front + w * 0.01), solid(Color(0.9, 0.75, 0.2), 0.0, 0.3, 1.0))
