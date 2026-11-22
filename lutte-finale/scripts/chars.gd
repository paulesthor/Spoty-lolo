class_name Chars
# Character builders: comrades = KayKit bodies (76 animations) with caricature accessories;
# capitalists = Quaternius outfits recoloured per enemy type (24 animations).

const KK := "res://assets/kaykit/"
const QM := "res://assets/quaternius/Male/"
const QF := "res://assets/quaternius/Female/"
const HIDE := ["Hat", "Helmet", "Hood", "Axe", "Sword", "Shield", "Mug", "Staff", "Crossbow", "Knife", "Throwable", "Wand", "Spellbook", "Cape"]

# ---------------------------------------------------------------- comrades
const HEROES := {
	"stakhanov": {"prop": "hammer_A", "body": "Barbarian", "acc": ["miner"], "weapon_hand": true},
	"ilitch": {"prop": "map_rolled", "body": "Mage", "acc": ["chapka", "goatee"], "weapon_hand": true},
	"moustache": {"prop": "Gun_Rifle", "body": "Rogue", "acc": ["kepi", "big_moustache"], "weapon_hand": true},
	"babouchka": {"prop": "pan_A", "body": "Knight", "acc": ["fichu"], "weapon_hand": true},
	"barbudo": {"prop": "Gun_Pistol", "body": "Rogue", "acc": ["beret", "beard", "cigar"], "weapon_hand": true},
	"youri": {"prop": "wrench_A", "body": "Knight", "acc": ["space_helmet"], "weapon_hand": true},
	"natacha": {"prop": "pitchfork", "body": "Knight", "acc": ["straw_hat", "scarf"], "weapon_hand": true},
	"vodkine": {"prop": "mug_A", "body": "Barbarian", "acc": ["chapka", "big_moustache"], "weapon_hand": true},
	"tamara": {"prop": "wrench_B", "body": "Rogue", "acc": ["tank_helmet"], "weapon_hand": true},
	"mikhail": {"prop": "mallet", "body": "Barbarian", "acc": ["chapka", "beard"], "weapon_hand": true},
	"timonier": {"prop": "book_single", "body": "Mage", "acc": ["mao_cap"], "weapon_hand": true},
	"lev": {"prop": "trowel", "body": "Knight", "acc": ["hard_hat"], "weapon_hand": true},
	"svetlana": {"prop": "torch", "body": "Rogue", "acc": ["bandana", "sunglasses"], "weapon_hand": true},
	"dmitri": {"prop": "spoon", "body": "Mage", "acc": ["flat_cap", "round_glasses", "big_moustache"], "weapon_hand": true},
	"valentina": {"prop": "staff_C", "body": "Rogue", "acc": ["round_glasses", "scarf"], "weapon_hand": true},
}

# hero animation names (KayKit)
const HERO_ANIMS := {
	"idle": "2H_Melee_Idle", "run": "Running_A", "jump": "Jump_Idle", "fall": "Jump_Idle", "land": "Jump_Land",
	"slide": "Dodge_Forward", "dodge_f": "Dodge_Forward", "dodge_b": "Dodge_Backward", "dodge_l": "Dodge_Left", "dodge_r": "Dodge_Right",
	"hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "attack": "2H_Melee_Attack_Chop", "throw": "Throw",
	"interact": "Interact", "cast": "Spellcast_Raise", "pickup": "PickUp",
}

# signature move when the cursor lands on a comrade in the selection screen
const SELECT_ANIM := {
	"stakhanov": "2H_Melee_Attack_Chop", "ilitch": "Spellcast_Long", "moustache": "1H_Ranged_Shoot", "babouchka": "Interact",
	"barbudo": "Throw", "youri": "Jump_Full_Long", "natacha": "PickUp", "vodkine": "Use_Item", "tamara": "2H_Ranged_Shoot",
	"mikhail": "Unarmed_Melee_Attack_Punch_B", "timonier": "Cheer", "lev": "1H_Melee_Attack_Chop", "svetlana": "Spellcast_Shoot",
	"dmitri": "2H_Melee_Attack_Spinning", "valentina": "Spellcast_Raise",
}

const KK_YAW := 0.0   # KayKit models face +Z (glTF forward), like our facing convention

static func build_hero(parent: Node, char_id: String, skin := 0) -> Node3D:
	var def: Dictionary = HEROES.get(char_id, HEROES["stakhanov"])
	var n := U.place(parent, KK + def["body"] + ".glb", Vector3.ZERO, 1.9, 0.0)
	var sk: Array = Meta.SKINS.get(char_id, [["", Color(1, 1, 1), [], 0]])[clampi(skin, 0, 2)]
	var tint: Color = sk[1]
	for m in n.find_children("*", "MeshInstance3D", true, false):
		for w in HIDE:
			if w in str(m.name): (m as MeshInstance3D).visible = false
		if tint != Color(1, 1, 1) and not "Head" in str(m.name) and (m as MeshInstance3D).visible:
			var mi: MeshInstance3D = m
			for i in mi.mesh.get_surface_count():
				var src = mi.get_active_material(i)
				if src is StandardMaterial3D:
					var d: StandardMaterial3D = src.duplicate()
					d.albedo_color = tint
					if tint.r > 1.15 and tint.g > 0.95: d.metallic = 0.5; d.roughness = 0.35
					mi.set_surface_override_material(i, d)
	var acc: Array = def["acc"].duplicate()
	acc.append_array(sk[2])
	attach(n, acc)
	rim(n, Color(1, 0.9, 0.75), 0.6)
	hand_prop(n, def.get("prop", "hammer_A"))
	return n

# ---------------------------------------------------------------- capitalists
# model, colour overrides by material name
const ENEMY_LOOKS := {
	"stagiaire": [["Casual_2", "M"], ["Casual", "F"], ["Casual_Hoodie", "M"]],
	"cadre": [["Suit", "M"], ["Suit", "F"]],
	"trader": [["Suit", "M"]],
	"influenceur": [["Casual", "F"], ["Punk", "F"]],
	"banquier": [["Suit", "M"]],
	"crypto": [["Casual_Hoodie", "M"], ["Punk", "M"]],
	"avocat": [["Suit", "M"], ["Suit", "F"]],
	"huissier": [["Suit", "M"]],
	"coach": [["Adventurer", "M"], ["Adventurer", "F"]],
	"lobbyiste": [["Suit", "M"], ["Formal", "F"]],
	"drh": [["Formal", "F"], ["Suit", "F"]],
	"actionnaire": [["King", "M"]],
	"golden": [["Suit", "M"]],
	"boss": [["King", "M"]],
	"boss2": [["Suit", "M"]],
	"boss3": [["Suit", "M"]],
	"fisc": [["Swat", "M"]],
	"chef_rayon": [["Worker", "M"], ["Worker", "F"]],
	"consultant": [["Suit", "M"], ["Formal", "F"]],
	"daytrader": [["Suit", "M"], ["Suit", "F"]],
	"evade": [["Beach", "M"]],
	"livreur": [["Worker", "M"], ["Casual_Hoodie", "M"]],
	"moderateur": [["SciFi", "F"], ["Spacesuit", "M"]],
	"moniteur": [["Adventurer", "M"], ["Adventurer", "F"]],
	"touriste": [["Spacesuit", "M"], ["SciFi", "F"]],
	"pretorien": [["Swat", "M"], ["Soldier", "F"]],
	"pretenom": [["Suit", "M"]],
}

const ENEMY_COLORS := {
	"stagiaire": {"LightBrown": Color(0.75, 0.72, 0.68), "Purple": Color(0.45, 0.5, 0.6)},
	"cadre": {"Suit": Color(0.22, 0.23, 0.27), "Tie": Color(0.75, 0.1, 0.1), "Black": Color(0.22, 0.23, 0.27)},
	"trader": {"Suit": Color(0.15, 0.2, 0.38), "Tie": Color(0.95, 0.75, 0.2)},
	"influenceur": {"Orange": Color(1.0, 0.45, 0.7), "Pink": Color(1.0, 0.4, 0.75), "Grey": Color(0.95, 0.95, 0.95)},
	"banquier": {"Suit": Color(0.12, 0.32, 0.18), "Tie": Color(0.95, 0.85, 0.3)},
	"crypto": {"Purple": Color(0.95, 0.6, 0.1), "Black": Color(0.95, 0.6, 0.1)},
	"avocat": {"Suit": Color(0.1, 0.1, 0.12), "Tie": Color(0.55, 0.55, 0.6), "Black": Color(0.1, 0.1, 0.12)},
	"huissier": {"Suit": Color(0.05, 0.05, 0.06), "Tie": Color(0.05, 0.05, 0.06)},
	"coach": {"Green": Color(1.0, 0.5, 0.1), "LightGreen": Color(1.0, 0.75, 0.3)},
	"lobbyiste": {"Suit": Color(0.42, 0.3, 0.55), "Tie": Color(0.9, 0.8, 0.95), "Red": Color(0.42, 0.3, 0.55)},
	"drh": {"Red": Color(0.75, 0.75, 0.78), "Black": Color(0.75, 0.75, 0.78)},
	"actionnaire": {"Blue": Color(0.15, 0.15, 0.2)},
	"golden": {"Suit": Color(1.0, 0.75, 0.25), "Tie": Color(0.1, 0.1, 0.1)},
	"boss": {"Blue": Color(0.6, 0.08, 0.1)},
	"boss2": {"Suit": Color(0.08, 0.1, 0.2), "Tie": Color(0.85, 0.85, 0.9)},
	"boss3": {"Suit": Color(0.92, 0.92, 0.95), "Tie": Color(1.0, 0.75, 0.25)},
	"fisc": {},
	"chef_rayon": {"Worker_Yellow": Color(0.85, 0.12, 0.12), "Worker_Vest": Color(0.85, 0.12, 0.12), "Yellow": Color(0.85, 0.12, 0.12)},
	"consultant": {"Suit": Color(0.45, 0.47, 0.5), "Tie": Color(0.2, 0.45, 0.9), "Black": Color(0.45, 0.47, 0.5), "Red": Color(0.45, 0.47, 0.5)},
	"daytrader": {"Suit": Color(0.1, 0.45, 0.2), "Tie": Color(0.9, 0.15, 0.15)},
	"evade": {"White": Color(0.95, 0.9, 0.3), "Red_Dark": Color(0.1, 0.4, 0.75), "LightBrown": Color(0.95, 0.9, 0.3)},
	"livreur": {"Worker_Yellow": Color(0.1, 0.8, 0.7), "Worker_Vest": Color(0.1, 0.8, 0.7), "Purple": Color(0.1, 0.8, 0.7)},
	"moderateur": {"SciFi_Main": Color(0.1, 0.12, 0.16), "SciFi_Light": Color(1.0, 0.2, 0.25), "SciFi_Light_Accent": Color(1.0, 0.2, 0.25), "Blue": Color(0.12, 0.13, 0.17), "LightBlue": Color(1.0, 0.2, 0.25), "Metal": Color(0.12, 0.13, 0.17)},
	"moniteur": {"Green": Color(0.85, 0.1, 0.12), "LightGreen": Color(0.95, 0.95, 0.95)},
	"touriste": {"SciFi_Main": Color(0.95, 0.95, 0.97), "SciFi_Light": Color(1.0, 0.5, 0.1), "SciFi_MainDark": Color(0.2, 0.2, 0.25), "Blue": Color(0.95, 0.95, 0.97), "LightBlue": Color(1.0, 0.5, 0.1)},
	"pretorien": {"Swat": Color(0.16, 0.13, 0.1), "Swat_Black": Color(0.05, 0.05, 0.05), "Visor": Color(1.0, 0.75, 0.25)},
	"pretenom": {"Suit": Color(0.35, 0.35, 0.38), "Tie": Color(0.35, 0.35, 0.38)},
}

const ENEMY_ANIMS := {"walk": "Walk", "run": "Run", "death": "Death", "hit": "HitRecieve", "attack": "Punch_Right", "shoot": "Gun_Shoot", "throw": "Punch_Left", "idle": "Idle"}

static var _color_mats := {}
static var _merged := {}       # cache key -> ArrayMesh (shared by every enemy of that look)
static var _merged_mat: StandardMaterial3D

# Merge the skinned body parts of a model (same skeleton, same skin) into a single surface whose
# vertex colours carry each part's albedo. Returns false when the model can't be merged (textures, odd skins).
static func merge_skinned(n: Node, key: String) -> bool:
	var parts: Array = []
	var skin: Skin = null
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null or not (mi.get_parent() is Skeleton3D) or not mi.visible: continue
		if skin == null: skin = mi.skin
		elif mi.skin != skin: return false
		if mi.transform != Transform3D.IDENTITY: return false
		parts.append(mi)
	if parts.size() < 2 or skin == null: return false
	var mesh: ArrayMesh = _merged.get(key)
	if mesh == null:
		var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray()
		var bones := PackedInt32Array(); var weights := PackedFloat32Array(); var idx := PackedInt32Array()
		var per := -1
		for mi in parts:
			for i in mi.mesh.get_surface_count():
				var mat = mi.get_active_material(i)
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null: return false
				var col: Color = (mat as BaseMaterial3D).albedo_color if mat is BaseMaterial3D else Color(0.8, 0.8, 0.8)
				var a: Array = mi.mesh.surface_get_arrays(i)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				if a[Mesh.ARRAY_BONES] == null or a[Mesh.ARRAY_WEIGHTS] == null: return false
				var b: PackedInt32Array = PackedInt32Array(a[Mesh.ARRAY_BONES])
				var w: PackedFloat32Array = PackedFloat32Array(a[Mesh.ARRAY_WEIGHTS])
				var bp: int = b.size() / maxi(v.size(), 1)
				if per < 0: per = bp
				elif per != bp: return false
				var base := verts.size()
				verts.append_array(v)
				var nr = a[Mesh.ARRAY_NORMAL]
				if nr == null: nr = PackedVector3Array(); nr.resize(v.size())
				norms.append_array(nr)
				var c := PackedColorArray(); c.resize(v.size()); c.fill(col)
				cols.append_array(c)
				bones.append_array(b); weights.append_array(w)
				var ix = a[Mesh.ARRAY_INDEX]
				if ix == null:
					ix = PackedInt32Array(range(v.size()))
				for k in (ix as PackedInt32Array): idx.append(k + base)
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_BONES] = bones; arr[Mesh.ARRAY_WEIGHTS] = weights; arr[Mesh.ARRAY_INDEX] = idx
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
		_merged[key] = mesh
	if _merged_mat == null:
		_merged_mat = StandardMaterial3D.new()
		_merged_mat.vertex_color_use_as_albedo = true
		_merged_mat.roughness = 0.8
		_merged_mat.rim_enabled = true; _merged_mat.rim = 0.45; _merged_mat.rim_tint = 0.6
	var keep: MeshInstance3D = parts[0]
	keep.mesh = mesh
	keep.material_override = null
	keep.set_surface_override_material(0, _merged_mat)
	for i in range(1, parts.size()): (parts[i] as MeshInstance3D).queue_free()
	return true

static func build_enemy(parent: Node, kind: String, pos: Vector3, h: float) -> Node3D:
	var sk: Dictionary = Levels.skin(kind)
	var looks: Array = sk.get("looks", ENEMY_LOOKS.get(kind, ENEMY_LOOKS["cadre"]))
	var look: Array = looks[randi() % looks.size()]
	var path: String = (QM if look[1] == "M" else QF) + look[0] + ".glb"
	var n := U.place(parent, path, pos, h, 0.0)
	var cols: Dictionary = ENEMY_COLORS.get(kind, {}).duplicate()
	cols.merge(sk.get("colors", {}), true)
	recolor(n, cols)
	# one mesh, one material, one draw call per capitalist (was 10-14): colours go into the vertices
	if not merge_skinned(n, path + "|" + str(cols)):
		rim(n, Color(1.0, 0.85, 0.7), 0.45)
	# the horde casts no real-time shadow (big saving); a soft blob grounds each capitalist instead
	if not kind in ["golden", "boss", "boss2", "boss3"]:
		for m in n.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.blob(n, Vector3(0, 0.04 / n.scale.y, 0), 1.4 / n.scale.x)
	return n

# rim light: a soft bright edge that detaches characters from the ground (cached per source material)
static var _rim_mats := {}
static func rim(n: Node, tint: Color, amount: float):
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null or not (mi.get_parent() is Skeleton3D): continue
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if not (src is StandardMaterial3D): continue
			var key := "%d_%f" % [src.get_instance_id(), amount]
			if not _rim_mats.has(key):
				var d: StandardMaterial3D = src.duplicate()
				d.rim_enabled = true
				d.rim = amount
				d.rim_tint = 0.6
				_rim_mats[key] = d
			mi.set_surface_override_material(i, _rim_mats[key])

static func recolor(n: Node, colors: Dictionary):
	if colors.is_empty(): return
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src == null: continue
			var nm: String = src.resource_name
			if not colors.has(nm): continue
			var key := "%s_%s" % [nm, (colors[nm] as Color).to_html()]
			if not _color_mats.has(key):
				var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				d.albedo_color = colors[nm]
				d.roughness = 0.6
				if nm == "Suit" and (colors[nm] as Color).r > 0.9: d.metallic = 0.6
				_color_mats[key] = d
			mi.set_surface_override_material(i, _color_mats[key])

# ---------------------------------------------------------------- shared helpers
static func skeleton(n: Node) -> Skeleton3D:
	var l := n.find_children("*", "Skeleton3D", true, false)
	return l[0] if not l.is_empty() else null

static func is_kaykit(n: Node) -> bool:
	var sk := skeleton(n)
	return sk != null and sk.find_bone("handslot.r") >= 0

# accessories on the head bone, sized from the visible meshes (works for both rigs)
const HATS := ["chapka", "kepi", "beret", "flat_cap", "straw_hat", "hard_hat", "mao_cap", "cap", "tank_helmet", "tophat"]
const HAT_SINK := 0.16

static func _is_knight(n: Node) -> bool:
	for m in n.find_children("Knight_*", "MeshInstance3D", true, false): return true
	return false

static func attach(n: Node3D, kinds: Array):
	if kinds.is_empty(): return
	var sk := skeleton(n)
	if sk == null: return
	var hb := sk.find_bone("head")
	var kk := hb >= 0
	if hb < 0: hb = sk.find_bone("Head")
	if hb < 0: return
	var top := 0.0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if not (m as MeshInstance3D).visible: continue
		var a: AABB = (sk.global_transform.affine_inverse() * (m as Node3D).global_transform) * (m as MeshInstance3D).get_aabb()
		top = maxf(top, a.end.y)
	var hy := sk.get_bone_global_rest(hb).origin.y
	var hh := top - hy
	if kk and _is_knight(n): hh -= 0.12     # the knight's hair tuft pokes above the skull
	var w := hh * (0.95 if kk else 1.25)
	var ba := BoneAttachment3D.new()
	ba.bone_name = sk.get_bone_name(hb)
	sk.add_child(ba)
	var root := Node3D.new()
	ba.add_child(root)
	if kk:
		root.position.y = w * 0.12
	# headwear is sunk into the hair: the mesh top is a hair tuft, the skull sits lower
	var hats: Array = kinds.filter(func(x): return x in HATS)
	var rest: Array = kinds.filter(func(x): return not x in HATS)
	U.eye_k = 0.6 if kk else 0.4
	U._build_accessories(root, rest, w, hh, 0.0, w * 0.5)
	if not hats.is_empty():
		var hr := Node3D.new()
		hr.position.y = -w * (HAT_SINK if kk else 0.2)
		root.add_child(hr)
		U._build_accessories(hr, hats, w, hh, 0.0, w * 0.5)
	U.batch_static(root)      # a hat made of 3 pieces -> one draw call per material

# KayKit CC0 props (assets/kaykit_props): [scale, offset, rotation in degrees] in hand-slot space
const PROP_FIT := {
	"hammer_A": [1.0, Vector3.ZERO, Vector3.ZERO],
	"mallet": [1.0, Vector3.ZERO, Vector3.ZERO],
	"pitchfork": [0.85, Vector3(0, -0.1, 0), Vector3.ZERO],
	"staff_C": [0.85, Vector3.ZERO, Vector3.ZERO],
	"trowel": [0.9, Vector3.ZERO, Vector3.ZERO],
	"torch": [1.0, Vector3.ZERO, Vector3.ZERO],
	"spoon": [1.1, Vector3.ZERO, Vector3.ZERO],
	"wrench_A": [1.2, Vector3.ZERO, Vector3.ZERO],
	"wrench_B": [1.2, Vector3.ZERO, Vector3.ZERO],
	"Gun_Rifle": [0.9, Vector3.ZERO, Vector3.ZERO],
	"Gun_Pistol": [1.0, Vector3.ZERO, Vector3.ZERO],
	"pan_A": [0.7, Vector3(0, 0.5, 0), Vector3(90, 0, 0)],
	"mug_A": [1.1, Vector3(-0.05, 0, 0), Vector3.ZERO],
	"book_single": [1.0, Vector3.ZERO, Vector3.ZERO],
	"map_rolled": [1.0, Vector3(0, 0.3, 0), Vector3(90, 0, 0)],
}

static func hand_prop(n: Node3D, prop: String):
	var sk := skeleton(n)
	if sk == null: return
	var bone := "handslot.r" if sk.find_bone("handslot.r") >= 0 else "Wrist.R"
	if sk.find_bone(bone) < 0: return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var ps: PackedScene = load("res://assets/kaykit_props/%s.gltf" % prop)
	if ps == null: return
	var h: Node3D = ps.instantiate()
	h.set_meta("airborne", true)
	var fit: Array = PROP_FIT.get(prop, [1.0, Vector3.ZERO, Vector3.ZERO])
	h.scale = Vector3.ONE * float(fit[0])
	h.position = fit[1]
	h.rotation_degrees = fit[2]
	ba.add_child(h)
	if prop == "torch":    # the flame of the revolution, obviously
		var fl := U.sphere(h, 0.13, Vector3(0, 1.02, 0), U.solid(Color(1.0, 0.55, 0.1), 3.0), 0.3)
		fl.set_meta("airborne", true)
		U.sphere(h, 0.08, Vector3(0, 1.1, 0), U.solid(Color(1.0, 0.9, 0.4), 4.0), 0.22)

# ink outline on a character (inverted hull as a next pass on its own material copies)
static var _ink: ShaderMaterial
static func outline(n: Node, width := 0.025):
	if _ink == null:
		_ink = ShaderMaterial.new()
		_ink.shader = load("res://shaders/ink_outline.gdshader")
	var mat: ShaderMaterial = _ink
	if width != 0.025:
		mat = _ink.duplicate()
		mat.set_shader_parameter("width", width)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if not mi.visible or mi.mesh == null or not (mi.get_parent() is Skeleton3D): continue
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if not (src is BaseMaterial3D): continue
			var d: BaseMaterial3D = src.duplicate()
			d.next_pass = mat
			mi.set_surface_override_material(i, d)

# imported glTF clips don't loop by default: locomotion/idle clips must, or the model freezes mid-run
const LOOPING := ["Idle", "2H_Melee_Idle", "Running_A", "Running_B", "Walking_A", "Walking_B", "Jump_Idle", "Unarmed_Idle",
	"Walk", "Run", "Run_Back", "Run_Left", "Run_Right", "Idle_Neutral", "Idle_Gun", "Idle_Gun_Pointing", "Idle_Sword", "Idle_Gun_Shoot"]
static func set_loops(ap: AnimationPlayer):
	if ap == null: return
	for nm in LOOPING:
		if ap.has_animation(nm):
			ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
