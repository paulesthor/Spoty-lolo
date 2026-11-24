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

const PROPS := "res://assets/props/"
const CAT := "res://assets/_catalog/"     # more CC0 props (same licences, see assets/_catalog/LICENSE.txt)

# instance a model in `parent`'s local space: largest side (or height) = size, centred on x/z, base on y = 0
static func model_local(parent: Node3D, path: String, size: float, by_height := false) -> Node3D:
	var n: Node3D = scene(path).instantiate()
	parent.add_child(n)
	var inv := parent.global_transform.affine_inverse()
	var a: AABB = inv * world_aabb(n)
	var ref: float = a.size.y if by_height else maxf(maxf(a.size.x, a.size.y), a.size.z)
	n.scale *= size / maxf(ref, 0.001)
	a = inv * world_aabb(n)
	n.position += Vector3(-a.get_center().x, -a.position.y, -a.get_center().z)
	return n      # CC0 map props (see assets/props/LICENSE.txt)
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

const TEX := "res://assets/textures/"
const NATURE := "res://assets/nature/prefabs/"

# textured PBR material (ambientCG): colour + normal + roughness, world-space triplanar so any box tiles correctly
static func pbr(name: String, scale := 0.25, tint := Color(1, 1, 1), normal := 1.0) -> StandardMaterial3D:
	var key := "pbr_%s_%f_%s" % [name, scale, tint.to_html()]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + name + "_Color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + name + "_NormalGL.jpg")
	m.normal_scale = normal
	m.roughness_texture = load(TEX + name + "_Roughness.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

# adds a tiling surface detail (plaster, bricks, corrugated steel...) over a flat-coloured model:
# the model keeps its palette, but gains texture and relief (triplanar, world space)
static func detailize(n: Node, name: String, scale := 0.5, brighten := 1.12):
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if not (src is StandardMaterial3D): continue
			var key := "det_%d_%s_%f" % [src.get_instance_id(), name, scale]
			if not _mats.has(key):
				var d: StandardMaterial3D = src.duplicate()
				d.detail_enabled = true
				d.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
				d.detail_albedo = load(TEX + name + "_Detail.jpg")
				d.detail_normal = load(TEX + name + "_NormalGL.jpg")
				d.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
				d.normal_enabled = true
				d.uv2_triplanar = true
				d.uv2_world_triplanar = true
				d.uv2_scale = Vector3.ONE * scale
				d.albedo_color = d.albedo_color * brighten
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				_mats[key] = d
			mi.set_surface_override_material(i, _mats[key])

const POSTERS := "res://assets/posters/"

# poster-style pictograms: weapons by id, décrets/surplus as "d_<id>"
static func icon(kind: String, id: String) -> Texture2D:
	var name := id
	if kind in ["decret", "surplus"]:
		name = "d_" + {"regen": "endurance", "crit_dmg": "critique"}.get(id, id)
	elif kind == "fusion":
		name = Data.FUSIONS[id]["a"]
	var p := "res://assets/icons/%s.png" % name
	return load(p) if ResourceLoader.exists(p) else null

# a printed poster (texture on a quad), facing +Z of its rotation
static func poster(parent: Node, tex: String, pos: Vector3, size: Vector2, rot_y: float) -> MeshInstance3D:
	var key := "poster_" + tex
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(POSTERS + tex)
		m.roughness = 0.85
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = size
	mi.mesh = q
	mi.material_override = _mats[key]
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	return mi

static func propaganda_tex(i: int) -> String:
	return "propaganda_%d.jpg" % (posmod(i, 8))

static func ad_tex(i: int) -> String:
	return "ad_%d.jpg" % (posmod(i, 4))

# stylised vegetation (Quaternius): instance a prefab scaled to a height, base on the ground
static func nature(parent: Node, prefab: String, pos: Vector3, height: float, rot := 0.0) -> Node3D:
	var n: Node3D = scene(NATURE + prefab + ".tscn").instantiate()
	parent.add_child(n)
	n.rotation.y = rot
	var a := world_aabb(n)
	n.scale = Vector3.ONE * (height / maxf(a.size.y, 0.001))
	var b := world_aabb(n)
	n.position += Vector3(pos.x - b.get_center().x, pos.y - b.position.y, pos.z - b.get_center().z)
	return n

# Static batching: merge the primitive meshes that are direct children of `root` into one mesh per
# (material, shadow) pair. Hundreds of boxes/cylinders become a handful of draw calls.
static func batch_static(root: Node3D, keep: Array = []) -> int:
	var groups := {}
	var inv := root.global_transform.affine_inverse()
	for c in root.get_children():
		if not (c is MeshInstance3D) or keep.has(c): continue
		var mi: MeshInstance3D = c
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or not mi.visible: continue
		if mi.get_child_count() > 0 or mi.has_meta("airborne"): continue
		var bmat := mi.material_override as BaseMaterial3D
		if bmat and bmat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED: continue   # billboards must stay separate
		var key := "%d_%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
		if not groups.has(key): groups[key] = []
		groups[key].append(mi)
	var merged := 0
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2: continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			var m: MeshInstance3D = mi
			for si in m.mesh.get_surface_count():
				st.append_from(m.mesh, si, inv * m.global_transform)
		var out := MeshInstance3D.new()
		out.mesh = st.commit()
		out.material_override = (list[0] as MeshInstance3D).material_override
		out.cast_shadow = (list[0] as MeshInstance3D).cast_shadow
		root.add_child(out)
		for mi in list:
			(mi as Node).queue_free()
		merged += list.size()
	return merged

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

# ---------------------------------------------------------------- painted signs
# enamel plate texture drawn pixel by pixel: coloured face, double rim, rivets, a top-to-bottom wear gradient
static var _plate_tex := {}
static func plate_tex(bg: Color, fg: Color, aspect: float) -> Texture2D:
	var w := int(clampf(64.0 * aspect, 64.0, 512.0))
	var h := 64
	var key := "%s|%s|%d" % [bg.to_html(), fg.to_html(), w]
	if _plate_tex.has(key): return _plate_tex[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var k := 1.06 - 0.16 * float(y) / h       # lighter at the top, a little grime at the bottom
		img.fill_rect(Rect2i(0, y, w, 1), Color(bg.r * k, bg.g * k, bg.b * k))
	var rim := fg.lerp(bg, 0.2)
	for t in 3:
		img.fill_rect(Rect2i(t, t, w - 2 * t, 1), rim); img.fill_rect(Rect2i(t, h - 1 - t, w - 2 * t, 1), rim)
		img.fill_rect(Rect2i(t, t, 1, h - 2 * t), rim); img.fill_rect(Rect2i(w - 1 - t, t, 1, h - 2 * t), rim)
	var rim2 := fg.lerp(bg, 0.55)
	img.fill_rect(Rect2i(6, 6, w - 12, 1), rim2); img.fill_rect(Rect2i(6, h - 7, w - 12, 1), rim2)
	img.fill_rect(Rect2i(6, 6, 1, h - 12), rim2); img.fill_rect(Rect2i(w - 7, 6, 1, h - 12), rim2)
	for cx in [9, w - 11]:
		for cy in [9, h - 11]:
			img.fill_rect(Rect2i(cx, cy, 3, 3), Color(0.75, 0.75, 0.72))      # rivets
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_plate_tex[key] = tex
	return tex

# a painted sign: the enamel plate, the text painted on it (lit like paint), a star at each end.
# Centre at pos, facing +Z rotated by rot_y; `back` paints both faces.
static func sign_panel(parent: Node, text: String, size: Vector2, pos: Vector3, rot_y: float, bg: Color, fg: Color, back := false, glow := 0.0) -> Node3D:
	fonts()
	var root := Node3D.new(); parent.add_child(root)
	root.position = pos; root.rotation.y = rot_y
	var m := StandardMaterial3D.new()
	m.albedo_texture = plate_tex(bg, fg, size.x / maxf(size.y, 0.01))
	m.roughness = 0.45
	if glow > 0.0:
		m.emission_enabled = true; m.emission = bg; m.emission_energy_multiplier = glow * 0.4
	var stars := size.x / maxf(size.y, 0.01) > 2.2
	for f in ([1.0, -1.0] if back else [1.0]):
		var face := Node3D.new(); root.add_child(face)
		face.position = Vector3(0, 0, 0.012 * f)
		if f < 0.0: face.rotation.y = PI
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new(); qm.size = size
		q.mesh = qm; q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.add_child(q)
		var l := Label3D.new()
		l.text = text.to_upper(); l.font = font_main; l.font_size = 96
		l.modulate = fg; l.outline_size = 0
		l.shaded = true; l.double_sided = false
		l.position = Vector3(0, 0, 0.006)
		face.add_child(l)
		var tw := size.x - (size.y * 1.9 if stars else size.y * 0.4)
		fit_label(l, tw, size.y * 0.62)
		if stars:
			for sx in [-1.0, 1.0]:
				var st := Label3D.new(); st.text = "★"; st.font = _sym_font; st.font_size = 96
				st.modulate = fg; st.outline_size = 0; st.shaded = true; st.double_sided = false
				st.pixel_size = size.y * 0.3 / 96.0
				st.position = Vector3(sx * (size.x * 0.5 - size.y * 0.42), 0, 0.006)
				face.add_child(st)
	return root

# a cloth flag that really waves (shaders/flag.gdshader): its pole edge is at `pos`, it flies towards +Z
static var _flag_mats := {}
static func flag_cloth(parent: Node, size: Vector2, pos: Vector3, tex_path := "res://assets/textures/flag_soviet.png", phase := 0.0) -> MeshInstance3D:
	var key := "%s_%d" % [tex_path, int(phase * 10.0) % 8]
	if not _flag_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/flag.gdshader")
		m.set_shader_parameter("tex", load(tex_path))
		m.set_shader_parameter("phase", float(int(phase * 10.0) % 8))
		_flag_mats[key] = m
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.y)
	pm.orientation = PlaneMesh.FACE_X
	pm.subdivide_width = 14; pm.subdivide_depth = 3
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = _flag_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos + Vector3(0, 0, size.x * 0.5)
	return mi

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
	l.double_sided = billboard      # painted text only shows on its own side (no mirror image through walls)
	parent.add_child(l)
	return l

# shrink a 3D label so it stays inside its sign (max_w x max_h metres)
static func fit_label(l: Label3D, max_w: float, max_h := 0.0):
	var f: Font = l.font if l.font else font_num
	var sz: Vector2 = f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size) if l.autowrap_mode == TextServer.AUTOWRAP_OFF else f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, l.width, l.font_size)
	var w := sz.x * l.pixel_size
	var h := sz.y * l.pixel_size
	var k := 1.0
	if w > max_w and w > 0.0: k = max_w / w
	if max_h > 0.0 and h * k > max_h: k = max_h / maxf(h, 0.001)
	if k < 1.0:
		l.pixel_size *= k
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF: l.width /= k

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

# enemy danger visuals: drawn over everything (players' own effects included) so a threat is never hidden
static var _danger := {}
static func danger(mi: GeometryInstance3D) -> GeometryInstance3D:
	var src = mi.material_override
	if src is BaseMaterial3D:
		var key: int = src.get_instance_id()
		if not _danger.has(key):
			var d: BaseMaterial3D = src.duplicate()
			d.no_depth_test = true
			d.render_priority = 20
			if d.blend_mode == BaseMaterial3D.BLEND_MODE_ADD: d.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			_danger[key] = d
		mi.material_override = _danger[key]
	return mi

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

# soft dark ground blob (cheap stand-in for a real-time shadow)
static func blob(parent: Node, pos: Vector3, size: float, alpha := 0.42) -> MeshInstance3D:
	var key := "blob_%f" % alpha
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://fx/circle_05.png")
		m.albedo_color = Color(0, 0, 0, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mats[key] = m
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = Vector3(-PI / 2, 0, 0)
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
	_build_accessories(root, kinds, w, top, cz, front)

# eye height below the top of the head, as a fraction of the head width (KayKit heroes vs Quaternius capitalists)
static var eye_k := 0.6
static func _build_accessories(root: Node3D, kinds: Array, w: float, top: float, cz: float, front: float):
	fonts()
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
				m.position = Vector3(w * 0.2, top - w * eye_k, front + w * 0.02); m.rotation = Vector3(PI / 2, 0, 0)
				root.add_child(m)
			"sunglasses":
				for sx in [-1.0, 1.0]:
					box(root, Vector3(w * 0.26, w * 0.13, w * 0.03), Vector3(sx * w * 0.2, top - w * eye_k, front + w * 0.02), solid(Color(0.05, 0.05, 0.06), 0.0, 0.1))
				box(root, Vector3(w * 0.16, w * 0.03, w * 0.03), Vector3(0, top - w * (eye_k - 0.03), front + w * 0.02), solid(Color(0.05, 0.05, 0.06), 0.0, 0.1))
			"miner":
				var y := solid(Color(0.95, 0.75, 0.1), 0.0, 0.4)
				sphere(root, w * 0.55, Vector3(0, top - w * 0.05, cz), y, w * 0.6)
				cyl(root, w * 0.62, w * 0.05, Vector3(0, top - w * 0.12, cz), y)
				var lamp := cyl(root, w * 0.11, w * 0.12, Vector3(0, top + w * 0.05, cz + w * 0.5), solid(Color(1, 1, 0.8), 3.0))
				lamp.rotation = Vector3(PI / 2, 0, 0)
			"goatee":
				var g := solid(Color(0.45, 0.25, 0.12), 0.0, 1.0)
				var gb := box(root, Vector3(w * 0.22, w * 0.3, w * 0.12), Vector3(0, top - w * 1.05, front + w * 0.02), g)
				gb.rotation = Vector3(-0.25, 0, PI / 4)
				box(root, Vector3(w * 0.42, w * 0.06, w * 0.08), Vector3(0, top - w * 0.78, front + w * 0.03), g)
			"kepi":
				var kp := solid(Color(0.3, 0.35, 0.25), 0.0, 0.8)
				cyl(root, w * 0.5, w * 0.28, Vector3(0, top + w * 0.06, cz), kp)
				cyl(root, w * 0.56, w * 0.08, Vector3(0, top + w * 0.22, cz), kp)
				box(root, Vector3(w * 0.7, w * 0.04, w * 0.32), Vector3(0, top - w * 0.06, front + w * 0.12), solid(Color(0.1, 0.1, 0.1), 0.0, 0.3))
				cyl(root, w * 0.51, w * 0.07, Vector3(0, top - w * 0.02, cz), solid(Color(0.75, 0.08, 0.1)))
				var st := Label3D.new(); st.text = "★"; st.font = _sym_font; st.font_size = 64; st.pixel_size = w * 0.003
				st.modulate = Color(1, 0.8, 0.2); st.outline_size = 0; st.position = Vector3(0, top + w * 0.1, cz + w * 0.51); st.shaded = false
				root.add_child(st)
			"marshal_cap":
				# the Generalissimo's cap: pale crown, red band, gold badge and chin cord, black visor
				var mc := solid(Color(0.92, 0.9, 0.82), 0.0, 0.8)
				cyl(root, w * 0.47, w * 0.2, Vector3(0, top + w * 0.02, cz), mc)
				var mcr := cyl(root, w * 0.55, w * 0.08, Vector3(0, top + w * 0.15, cz + w * 0.02), mc)
				mcr.rotation.x = -0.12
				cyl(root, w * 0.48, w * 0.09, Vector3(0, top - w * 0.02, cz), solid(Color(0.75, 0.06, 0.07), 0.0, 0.7))
				box(root, Vector3(w * 0.62, w * 0.035, w * 0.26), Vector3(0, top - w * 0.08, front + w * 0.06), solid(Color(0.05, 0.05, 0.05), 0.0, 0.2))
				box(root, Vector3(w * 0.6, w * 0.025, w * 0.02), Vector3(0, top - w * 0.05, front + w * 0.02), solid(Color(1.0, 0.78, 0.3), 0.4, 0.3, 1.0))
				var bst := Label3D.new(); bst.text = "★"; bst.font = _sym_font; bst.font_size = 64; bst.pixel_size = w * 0.0035
				bst.modulate = Color(1, 0.8, 0.25); bst.outline_size = 0; bst.position = Vector3(0, top + w * 0.07, front + w * 0.02); bst.shaded = false
				root.add_child(bst)
			"pipe":
				# the pipe, held in the corner of the mouth under the moustache
				var wood := solid(Color(0.35, 0.18, 0.08), 0.0, 0.5)
				var stem := box(root, Vector3(w * 0.05, w * 0.05, w * 0.32), Vector3(w * 0.2, top - w * (eye_k + 0.42), front + w * 0.12), solid(Color(0.08, 0.06, 0.05), 0.0, 0.4))
				stem.rotation.y = 0.35
				var bowl := cyl(root, w * 0.07, w * 0.14, Vector3(w * 0.3, top - w * (eye_k + 0.36), front + w * 0.24), wood)
				bowl.rotation.z = 0.1
			"officer_cap":
				# grey peaked cap, kept small: band, flat crown, black visor, silver cord (no insignia)
				var oc := solid(Color(0.36, 0.38, 0.34), 0.0, 0.8)
				cyl(root, w * 0.34, w * 0.14, Vector3(0, top + w * 0.02, cz), oc)
				var crown := cyl(root, w * 0.37, w * 0.05, Vector3(0, top + w * 0.1, cz + w * 0.02), oc)
				crown.rotation.x = -0.12
				box(root, Vector3(w * 0.42, w * 0.03, w * 0.17), Vector3(0, top - w * 0.05, front - w * 0.02), solid(Color(0.05, 0.05, 0.05), 0.0, 0.2))
				cyl(root, w * 0.35, w * 0.03, Vector3(0, top - w * 0.03, cz), solid(Color(0.8, 0.8, 0.82), 0.0, 0.3, 1.0))
			"toothbrush":
				# the ridiculous little square moustache, and the hair plastered sideways on the forehead
				box(root, Vector3(w * 0.12, w * 0.065, w * 0.05), Vector3(0, top - w * (eye_k + 0.11), front + w * 0.035), solid(Color(0.05, 0.04, 0.04), 0.0, 1.0))
				var fringe := box(root, Vector3(w * 0.36, w * 0.08, w * 0.05), Vector3(w * 0.08, top - w * (eye_k - 0.12), front + w * 0.01), solid(Color(0.06, 0.05, 0.05), 0.0, 0.6))
				fringe.rotation.z = -0.4
			"big_moustache":
				var mo := solid(Color(0.12, 0.08, 0.06), 0.0, 1.0)
				for sx in [-1.0, 1.0]:
					var half := box(root, Vector3(w * 0.42, w * 0.13, w * 0.12), Vector3(sx * w * 0.22, top - w * 0.9, front + w * 0.05), mo)
					half.rotation = Vector3(0, 0, sx * -0.3)
			"fichu":
				var f := solid(Color(0.8, 0.1, 0.12), 0.0, 0.9)
				sphere(root, w * 0.56, Vector3(0, top - w * 0.12, cz - w * 0.02), f, w * 0.75)
				var knot := box(root, Vector3(w * 0.3, w * 0.22, w * 0.12), Vector3(0, top - w * 0.95, front - w * 0.05), f)
				knot.rotation = Vector3(0, 0, PI / 4)
				for dk in 5:
					sphere(root, w * 0.05, Vector3((dk - 2) * w * 0.2, top + w * 0.05, cz + w * 0.45), solid(Color(1, 1, 1)))
			"straw_hat":
				var straw := solid(Color(0.9, 0.78, 0.45), 0.0, 0.9)
				cyl(root, w * 0.95, w * 0.05, Vector3(0, top - w * 0.02, cz), straw)
				sphere(root, w * 0.5, Vector3(0, top + w * 0.08, cz), straw, w * 0.4)
				cyl(root, w * 0.51, w * 0.08, Vector3(0, top + w * 0.02, cz), solid(Color(0.75, 0.1, 0.12)))
			"tank_helmet":
				var lea := solid(Color(0.25, 0.2, 0.15), 0.0, 0.7)
				sphere(root, w * 0.62, Vector3(0, top - w * 0.12, cz), lea, w * 0.75)
				for kk in 3: box(root, Vector3(w * 0.09, w * 0.1, w * 0.95), Vector3((kk - 1) * w * 0.26, top + w * 0.2, cz), lea)
				cyl(root, w * 0.66, w * 0.08, Vector3(0, top - w * 0.14, cz), lea)
				for sx in [-1.0, 1.0]:
					var gl := cyl(root, w * 0.13, w * 0.07, Vector3(sx * w * 0.2, top - w * 0.02, front + w * 0.06), solid(Color(0.4, 0.7, 0.9, 0.85), 0.5, 0.1, 0.5))
					gl.rotation = Vector3(PI / 2 - 0.3, 0, 0)
				box(root, Vector3(w * 1.2, w * 0.05, w * 0.05), Vector3(0, top - w * 0.02, front + w * 0.0), solid(Color(0.1, 0.1, 0.1)))
			"mao_cap":
				var gc := solid(Color(0.4, 0.45, 0.38), 0.0, 0.8)
				cyl(root, w * 0.52, w * 0.26, Vector3(0, top + w * 0.06, cz), gc)
				box(root, Vector3(w * 0.6, w * 0.04, w * 0.3), Vector3(0, top - w * 0.06, front + w * 0.1), solid(Color(0.2, 0.22, 0.18)))
				var ms := Label3D.new(); ms.text = "★"; ms.font = _sym_font; ms.font_size = 64; ms.pixel_size = w * 0.0035
				ms.modulate = Color(0.9, 0.12, 0.12); ms.outline_size = 0; ms.position = Vector3(0, top + w * 0.08, cz + w * 0.53); ms.shaded = false
				root.add_child(ms)
			"round_glasses":
				var rim := solid(Color(0.1, 0.1, 0.1), 0.0, 0.3, 0.8)
				for sx in [-1.0, 1.0]:
					var lens := MeshInstance3D.new(); var tor := TorusMesh.new(); tor.inner_radius = w * 0.09; tor.outer_radius = w * 0.12
					lens.mesh = tor; lens.material_override = rim; lens.rotation = Vector3(PI / 2, 0, 0)
					lens.position = Vector3(sx * w * 0.2, top - w * 0.56, front + w * 0.03); root.add_child(lens)
				box(root, Vector3(w * 0.16, w * 0.025, w * 0.025), Vector3(0, top - w * 0.56, front + w * 0.03), rim)
			"hard_hat":
				var hy := solid(Color(1.0, 0.55, 0.1), 0.0, 0.4)
				sphere(root, w * 0.56, Vector3(0, top - w * 0.04, cz), hy, w * 0.62)
				cyl(root, w * 0.66, w * 0.05, Vector3(0, top - w * 0.12, cz + w * 0.08), hy)
				box(root, Vector3(w * 0.08, w * 0.12, w * 1.0), Vector3(0, top + w * 0.24, cz), hy)
			"bandana":
				var bd := solid(Color(0.8, 0.12, 0.12), 0.0, 0.9)
				sphere(root, w * 0.55, Vector3(0, top - w * 0.1, cz - w * 0.02), bd, w * 0.6)
				for kk in 2:
					var tail := box(root, Vector3(w * 0.12, w * 0.4, w * 0.05), Vector3((kk - 0.5) * w * 0.15, top - w * 0.4, cz - w * 0.6), bd)
					tail.rotation = Vector3(0.4, 0, (kk - 0.5) * 0.6)
			"scarf":
				var sf := solid(Color(0.85, 0.15, 0.15), 0.0, 0.9)
				var ring2 := MeshInstance3D.new(); var tr2 := TorusMesh.new(); tr2.inner_radius = w * 0.3; tr2.outer_radius = w * 0.42
				ring2.mesh = tr2; ring2.material_override = sf; ring2.position = Vector3(0, top - w * 1.42, cz); ring2.scale = Vector3(1, 1.4, 1); root.add_child(ring2)
				box(root, Vector3(w * 0.16, w * 0.4, w * 0.06), Vector3(w * 0.16, top - w * 1.62, front - w * 0.08), sf)
			"flat_cap":
				var fc := solid(Color(0.35, 0.3, 0.25), 0.0, 0.9)
				sphere(root, w * 0.56, Vector3(0, top + w * 0.02, cz - w * 0.03), fc, w * 0.34)
				box(root, Vector3(w * 0.7, w * 0.05, w * 0.32), Vector3(0, top - w * 0.06, front + w * 0.08), fc, Vector3(0.18, 0, 0))
			"beret":
				var bc := solid(Color(0.12, 0.12, 0.1), 0.0, 0.9)
				var bm := sphere(root, w * 0.55, Vector3(-w * 0.08, top + w * 0.02, cz - w * 0.02), bc, w * 0.32)
				bm.rotation = Vector3(0, 0, 0.18)
				var bst := Label3D.new(); bst.text = "★"; bst.font = _sym_font; bst.font_size = 64; bst.pixel_size = w * 0.003
				bst.modulate = Color(0.9, 0.15, 0.1); bst.outline_size = 0; bst.position = Vector3(w * 0.18, top + w * 0.05, cz + w * 0.5); bst.shaded = false
				root.add_child(bst)
			"beard":
				var bd := solid(Color(0.1, 0.08, 0.06), 0.0, 1.0)
				sphere(root, w * 0.42, Vector3(0, top - w * 0.98, front - w * 0.12), bd, w * 0.55)
				for sx in [-1.0, 1.0]:
					box(root, Vector3(w * 0.12, w * 0.5, w * 0.3), Vector3(sx * w * 0.42, top - w * 0.6, front - w * 0.22), bd)
			"space_helmet":
				var gl := solid(Color(0.75, 0.88, 1.0, 0.28), 0.4, 0.05, 0.3)
				sphere(root, w * 0.82, Vector3(0, top - w * 0.42, cz), gl)
				var ring := MeshInstance3D.new(); var tr := TorusMesh.new(); tr.inner_radius = w * 0.62; tr.outer_radius = w * 0.78
				ring.mesh = tr; ring.material_override = solid(Color(0.92, 0.92, 0.95), 0.0, 0.4, 0.5); ring.position = Vector3(0, top - w * 1.12, cz); root.add_child(ring)
				var cccp := Label3D.new(); cccp.text = "CCCP"; cccp.font = font_main; cccp.font_size = 64; cccp.pixel_size = w * 0.0035
				cccp.modulate = Color(0.85, 0.1, 0.1); cccp.outline_size = 0; cccp.position = Vector3(0, top - w * 1.12, cz + w * 0.79); cccp.shaded = false
				root.add_child(cccp)
			"medal":
				var md := cyl(root, w * 0.14, w * 0.04, Vector3(-w * 0.25, top - w * 1.55, front + w * 0.02), solid(Color(1.0, 0.78, 0.25), 0.5, 0.3, 1.0))
				md.rotation = Vector3(PI / 2, 0, 0)
				box(root, Vector3(w * 0.12, w * 0.16, w * 0.03), Vector3(-w * 0.25, top - w * 1.4, front + w * 0.02), solid(Color(0.8, 0.1, 0.1)))
			"cap":
				var cc := solid(Color(0.15, 0.2, 0.35), 0.0, 0.8)
				cyl(root, w * 0.5, w * 0.18, Vector3(0, top + w * 0.02, cz), cc)
				box(root, Vector3(w * 0.7, w * 0.04, w * 0.35), Vector3(0, top - w * 0.06, front + w * 0.1), cc)
				box(root, Vector3(w * 0.22, w * 0.12, w * 0.03), Vector3(0, top + w * 0.02, front + w * 0.01), solid(Color(0.9, 0.75, 0.2), 0.0, 0.3, 1.0))
