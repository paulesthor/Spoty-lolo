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
	"generalissime": {"prop": "map_rolled", "body": "Knight", "acc": ["marshal_cap", "big_moustache", "pipe"], "weapon_hand": true, "uniform": true},
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
	if def.get("uniform", false):
		_parade_uniform(n, tint)
		tint = Color(1, 1, 1)
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
		# a faint red silhouette that shows through walls and props: nobody hides behind the decor
		var xr := StandardMaterial3D.new()
		xr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		xr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		xr.no_depth_test = true
		xr.albedo_color = Color(1.0, 0.25, 0.2, 0.13)
		xr.render_priority = -1
		_merged_mat.next_pass = xr
	var keep: MeshInstance3D = parts[0]
	keep.mesh = mesh
	keep.material_override = null
	keep.set_surface_override_material(0, _merged_mat)
	for i in range(1, parts.size()): (parts[i] as MeshInstance3D).queue_free()
	return true

# Le Généralissime: plain-coloured parade uniform over the KayKit body (texture dropped: it was armour),
# gold shoulder boards, gold buttons, a hero's star on the chest, red stripes down the trousers
static func _parade_uniform(n: Node3D, col: Color):
	var cloth := U.solid(col, 0.0, 0.75)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var nm := str(m.name)
		if (m as MeshInstance3D).visible and ("Body" in nm or "Arm" in nm or "Leg" in nm):
			(m as MeshInstance3D).material_override = cloth
	var sk := skeleton(n)
	if sk == null or sk.find_bone("chest") < 0: return
	var gold := U.solid(Color(1.0, 0.78, 0.3), 0.4, 0.3, 1.0)
	var red := U.solid(Color(0.78, 0.06, 0.07), 0.0, 0.7)
	var fc := _on_bone(sk, "chest")
	for k in 4:
		var bt := U.cyl(fc, 0.03, 0.02, Vector3(0, 0.56 + k * 0.12, 0.37), gold)
		bt.rotation.x = PI / 2
	var st := Label3D.new(); st.text = "★"; st.font = load("res://fonts/Symbols.ttf"); st.font_size = 96; st.pixel_size = 0.0022
	st.modulate = Color(1.0, 0.8, 0.25); st.outline_size = 0; st.shaded = false; st.double_sided = false
	st.position = Vector3(0.18, 0.95, 0.375)
	fc.add_child(st)
	U.box(fc, Vector3(0.12, 0.035, 0.01), Vector3(0.18, 1.03, 0.372), red)
	for s in ["l", "r"]:
		var up := _rest(sk, "upperarm." + s)
		var shb := _on_bone(sk, "upperarm." + s)
		var sx := signf(up.x)
		U.box(shb, Vector3(0.2, 0.05, 0.24), up + Vector3(-sx * 0.02, 0.12, 0), gold)
		for f in 4:
			U.cyl(shb, 0.012, 0.07, up + Vector3(sx * 0.08, 0.07, -0.09 + f * 0.06), gold)
		var leg := _on_bone(sk, "upperleg." + s)
		var ul := _rest(sk, "upperleg." + s)
		var ft := _rest(sk, "foot." + s)
		U.box(leg, Vector3(0.025, ul.y - ft.y + 0.05, 0.05), Vector3(ul.x + sx * 0.11, (ul.y + ft.y) * 0.5, 0.0), red)

# the spy-film poster pose (exaggerated): wide stance with bent knees, chest a bit forward,
# right arm forward holding the pistol, left hand gripping the jacket lapel, head turned aside.
# Applied on top of the animation (call it after the AnimationPlayer has advanced).
# directions in model space (front = +Z, the character's right = -X)
const OSS_POSE := {
	"UpperArm.R": Vector3(-0.32, -0.94, 0.08),
	"LowerArm.R": Vector3(-0.05, 0.04, 1.0),
	"UpperArm.L": Vector3(0.86, -0.36, 0.36),
	"LowerArm.L": Vector3(-0.52, 0.16, 0.84),
	"UpperLeg.R": Vector3(-0.42, -0.86, 0.22),
	"LowerLeg.R": Vector3(-0.2, -0.92, -0.32),
	"UpperLeg.L": Vector3(0.48, -0.84, -0.1),
	"LowerLeg.L": Vector3(0.24, -0.93, -0.28),
}
const OSS_LEGS := ["UpperLeg.R", "LowerLeg.R", "UpperLeg.L", "LowerLeg.L"]
const OSS_DROP := 0.17         # hips lowered (metres) so the bent legs still reach the ground
const OSS_LEAN := 0.22         # chest forward
const OSS_HEAD := -0.55        # head turned towards his right
const OSS_CURL := 1.5         # finger curl of the fists (per joint)
const OSS_CURL_SIGN := -1.0
const OSS_WRIST_L := 1.4      # left wrist rolled: palm against the chest, knuckles forward

static func _aim_bone(sk: Skeleton3D, b: String, dir: Vector3):
	var i := sk.find_bone(b)
	if i < 0: return
	var p := sk.get_bone_parent(i)
	var pg: Transform3D = sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
	var cur: Basis = (pg * sk.get_bone_rest(i)).basis      # from the rest pose: the result never accumulates
	var y := cur.y.normalized()
	var want := dir.normalized()
	var axis := y.cross(want)
	if axis.length() < 0.0001: return
	var rot := Basis(axis.normalized(), y.angle_to(want))
	var g := (rot * cur).orthonormalized()
	sk.set_bone_pose_rotation(i, (pg.basis.orthonormalized().inverse() * g).get_rotation_quaternion())

# close a hand: each finger joint turns about the knuckle line (index -> pinky), towards the palm
static func _fist(sk: Skeleton3D, side: String, amount: float):
	var i1 := sk.find_bone("Index1." + side); var p1 := sk.find_bone("Pinky1." + side)
	if i1 < 0 or p1 < 0: return
	var hinge := (sk.get_bone_global_rest(p1).origin - sk.get_bone_global_rest(i1).origin).normalized()
	var sg := OSS_CURL_SIGN * (1.0 if side == "L" else -1.0)
	for fg in ["Index", "Middle", "Ring", "Pinky"]:
		for k in [2, 3, 4]:      # bone 1 is the metacarpal (it starts at the wrist): bending it folds the whole palm
			var fi := sk.find_bone("%s%d.%s" % [fg, k, side])
			if fi < 0: continue
			var axis: Vector3 = (sk.get_bone_global_rest(fi).basis.orthonormalized().inverse() * hinge).normalized()
			sk.set_bone_pose_rotation(fi, sk.get_bone_rest(fi).basis.get_rotation_quaternion() * Quaternion(axis, amount * sg))

static func oss_pose(n: Node3D, legs := true):
	var sk := skeleton(n)
	if sk == null or sk.find_bone("UpperArm.R") < 0: return
	if legs:
		var hi := sk.find_bone("Hips")
		if hi >= 0:
			var hp := sk.get_bone_parent(hi)
			var pb: Basis = sk.get_bone_global_pose(hp).basis if hp >= 0 else Basis.IDENTITY
			sk.set_bone_pose_position(hi, sk.get_bone_rest(hi).origin + pb.orthonormalized().inverse() * Vector3(0, -OSS_DROP, 0))
	var ti := sk.find_bone("Torso")
	if ti >= 0: sk.set_bone_pose_rotation(ti, sk.get_bone_rest(ti).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, OSS_LEAN))
	for b in OSS_POSE:
		if not legs and b in OSS_LEGS: continue
		_aim_bone(sk, b, OSS_POSE[b])
	# left fist closed on the lapel
	_fist(sk, "L", OSS_CURL)
	_fist(sk, "R", OSS_CURL * 0.8)      # fingers round the pistol grip
	var ll := sk.find_bone("LowerArm.L")
	if ll >= 0: sk.set_bone_pose_rotation(ll, sk.get_bone_pose_rotation(ll) * Quaternion(Vector3.UP, OSS_WRIST_L))
	var wl := sk.find_bone("Wrist.L")
	if wl >= 0: _aim_bone(sk, "Wrist.L", OSS_POSE["LowerArm.L"])      # hand in line with the forearm
	if legs:
		# feet flat on the ground again, pointing where they pointed at rest
		for f in ["Foot.L", "Foot.R"]:
			var fi := sk.find_bone(f)
			if fi < 0: continue
			# the feet hang from the rig root, not from the shins: put each one back at the end of its shin
			var li := sk.find_bone("LowerLeg." + f.substr(5))
			var shin_len := sk.get_bone_global_rest(li).origin.distance_to(sk.get_bone_global_rest(fi).origin)
			var lg := sk.get_bone_global_pose(li)
			var ankle: Vector3 = lg.origin + lg.basis.y.normalized() * shin_len
			var fp := sk.get_bone_parent(fi)
			var fpg: Transform3D = sk.get_bone_global_pose(fp) if fp >= 0 else Transform3D.IDENTITY
			var want := Transform3D(sk.get_bone_global_rest(fi).basis.orthonormalized(), ankle)
			var loc := fpg.affine_inverse() * want
			sk.set_bone_pose_position(fi, loc.origin)
			sk.set_bone_pose_rotation(fi, loc.basis.orthonormalized().get_rotation_quaternion())
	var hd := sk.find_bone("Head")
	if hd >= 0: sk.set_bone_pose_rotation(hd, sk.get_bone_rest(hd).basis.get_rotation_quaternion() * Quaternion(Vector3.UP, OSS_HEAD))

# Berlin boss: a caricature built from plain pieces fixed to the bones (they follow the animations):
# a plain red armband (no symbol), riding boots, belt, cross strap, shoulder boards, a few plain medals
# a frame that follows `b`, in which children are placed in the model's own rest coordinates (metres, front = +Z)
static func _on_bone(sk: Skeleton3D, b: String) -> Node3D:
	var i := sk.find_bone(b)
	var ba := BoneAttachment3D.new()
	ba.bone_name = b
	sk.add_child(ba)
	var fr := Node3D.new()
	ba.add_child(fr)
	if i >= 0: fr.transform = sk.get_bone_global_rest(i).affine_inverse()
	return fr

static func _rest(sk: Skeleton3D, b: String) -> Vector3:
	var i := sk.find_bone(b)
	return sk.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO

# a cylinder from a to b (model coordinates)
static func _cyl_between(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var m := U.cyl(parent, r, a.distance_to(b), (a + b) * 0.5, mat)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	m.basis = Basis(side, up, side.cross(up)).orthonormalized()
	return m

const CAP_Y := 0.228
const CAP_Z := 0.045
const CAP_R := 0.113
const MOUSTACHE_Y := 0.07
const MOUSTACHE_Z := 0.14
static func dress_dictator(n: Node3D):
	var sk := skeleton(n)
	if sk == null or sk.find_bone("UpperArm.L") < 0: return
	var red := U.solid(Color(0.82, 0.05, 0.06), 0.0, 0.8)
	var leather := U.solid(Color(0.2, 0.12, 0.06), 0.0, 0.45)
	var boot := U.solid(Color(0.035, 0.035, 0.04), 0.0, 0.22, 0.1)
	var brass := U.solid(Color(0.85, 0.7, 0.3), 0.3, 0.3, 0.9)
	var silver := U.solid(Color(0.75, 0.75, 0.78), 0.3, 0.3, 0.9)
	var khaki := U.solid(Color(0.47, 0.4, 0.27), 0.0, 0.85)
	# plain red armband on the left upper arm (no symbol at all)
	var ua := _rest(sk, "UpperArm.L"); var la := _rest(sk, "LowerArm.L")
	_cyl_between(_on_bone(sk, "UpperArm.L"), ua.lerp(la, 0.42), ua.lerp(la, 0.72), 0.056, red)
	# the little square moustache and the plastered fringe, fixed on the head bone
	var fh := _on_bone(sk, "Head")
	var hd := _rest(sk, "Head")
	U.box(fh, Vector3(0.046, 0.024, 0.014), Vector3(hd.x, hd.y + MOUSTACHE_Y, hd.z + MOUSTACHE_Z), U.solid(Color(0.05, 0.04, 0.04), 0.0, 1.0))
	var fringe := U.box(fh, Vector3(0.085, 0.024, 0.014), Vector3(hd.x + 0.03, hd.y + 0.19, hd.z + 0.145), U.solid(Color(0.06, 0.05, 0.05), 0.0, 0.6))
	fringe.rotation.z = -0.45
	# the peaked cap, built on the skull itself: band hugging the head just above the brows,
	# a flat crown resting on it, the visor coming down on the forehead (no insignia)
	var cap := Node3D.new(); fh.add_child(cap)
	cap.position = Vector3(hd.x, hd.y + CAP_Y, hd.z + CAP_Z)
	cap.rotation.x = -0.12      # worn slightly up at the front
	var grey := U.solid(Color(0.36, 0.38, 0.34), 0.0, 0.8)
	var band := U.cyl(cap, CAP_R, 0.075, Vector3.ZERO, grey)
	band.scale = Vector3(1.0, 1.0, 1.12)
	U.cyl(cap, CAP_R + 0.003, 0.018, Vector3(0, -0.02, 0), U.solid(Color(0.15, 0.15, 0.15), 0.0, 0.5)).scale = Vector3(1.0, 1.0, 1.12)
	U.cyl(cap, CAP_R + 0.004, 0.01, Vector3(0, 0.012, 0), U.solid(Color(0.8, 0.8, 0.82), 0.0, 0.3, 1.0)).scale = Vector3(1.0, 1.0, 1.12)
	var crown := U.cyl(cap, CAP_R * 1.28, 0.03, Vector3(0, 0.05, 0.01), grey)
	crown.scale = Vector3(1.0, 1.0, 1.1)
	crown.rotation.x = -0.1
	var visor := U.box(cap, Vector3(CAP_R * 1.5, 0.01, 0.075), Vector3(0, -0.032, CAP_R * 1.12 + 0.025), U.solid(Color(0.04, 0.04, 0.04), 0.0, 0.2))
	visor.rotation.x = 0.35
	# black riding boots up to the knee
	for s in ["L", "R"]:
		var kn := _rest(sk, "LowerLeg." + s); var ft := _rest(sk, "Foot." + s)
		var fr := _on_bone(sk, "LowerLeg." + s)
		_cyl_between(fr, kn.lerp(ft, 0.08), ft + Vector3(0, 0.03, 0), 0.058, boot)
		_cyl_between(fr, kn.lerp(ft, 0.06), kn.lerp(ft, 0.14), 0.064, boot)      # boot cuff
	# belt and buckle at the waist
	var ab := _rest(sk, "Abdomen")
	var fb := _on_bone(sk, "Abdomen")
	var belt := U.cyl(fb, 0.165, 0.055, Vector3(ab.x, ab.y + 0.03, ab.z + 0.02), leather)
	belt.scale = Vector3(1.0, 1.0, 0.82)
	U.box(fb, Vector3(0.06, 0.05, 0.02), Vector3(ab.x, ab.y + 0.03, ab.z + 0.16), brass)
	# cross strap over the right shoulder, front and back
	var fc := _on_bone(sk, "Chest")
	var ch := _rest(sk, "Chest")
	_cyl_between(fc, Vector3(-0.13, ab.y + 0.04, 0.175), Vector3(0.11, ch.y + 0.1, 0.15), 0.017, leather)
	_cyl_between(fc, Vector3(-0.13, ab.y + 0.04, -0.07), Vector3(0.11, ch.y + 0.1, -0.06), 0.017, leather)
	# three plain medals on the left breast and a ribbon bar
	for k in 3:
		var md := U.cyl(fc, 0.017, 0.008, Vector3(0.05 + k * 0.035, ch.y - 0.06, 0.19), brass if k != 1 else silver)
		md.rotation.x = PI / 2
	U.box(fc, Vector3(0.1, 0.018, 0.01), Vector3(0.085, ch.y - 0.025, 0.19), red)
	# collar tabs, shoulder boards and tunic pockets
	for sx in [-1.0, 1.0]:
		U.box(fc, Vector3(0.035, 0.022, 0.012), Vector3(sx * 0.045, ch.y + 0.1, 0.15), khaki)
		U.box(fc, Vector3(0.075, 0.06, 0.012), Vector3(sx * 0.085, ch.y - 0.13, 0.18), khaki)
	for s in ["L", "R"]:
		var up := _rest(sk, "UpperArm." + s)
		U.box(_on_bone(sk, "UpperArm." + s), Vector3(0.09, 0.018, 0.07), up + Vector3(0, 0.035, 0), khaki)

static func build_enemy(parent: Node, kind: String, pos: Vector3, h: float) -> Node3D:
	var sk: Dictionary = Levels.skin(kind)
	var looks: Array = sk.get("looks", ENEMY_LOOKS.get(kind, ENEMY_LOOKS["cadre"]))
	var look: Array = looks[randi() % looks.size()]
	var path: String = (QM if look[1] == "M" else QF) + look[0] + ".glb"
	var n := U.place(parent, path, pos, h, 0.0)
	var cols: Dictionary = ENEMY_COLORS.get(kind, {}).duplicate()
	cols.merge(sk.get("colors", {}), true)
	recolor(n, cols)
	if sk.get("dictator", false): dress_dictator(n)
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
const HATS := ["marshal_cap", "officer_cap", "chapka", "kepi", "beret", "flat_cap", "straw_hat", "hard_hat", "mao_cap", "cap", "tank_helmet", "tophat"]
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
