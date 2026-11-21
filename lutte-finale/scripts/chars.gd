class_name Chars
# Character builders: comrades = KayKit bodies (76 animations) with caricature accessories;
# capitalists = Quaternius outfits recoloured per enemy type (24 animations).

const KK := "res://assets/kaykit/"
const QM := "res://assets/quaternius/Male/"
const QF := "res://assets/quaternius/Female/"
const HIDE := ["Hat", "Helmet", "Hood", "Axe", "Sword", "Shield", "Mug", "Staff", "Crossbow", "Knife", "Throwable", "Wand", "Spellbook", "Cape"]

# ---------------------------------------------------------------- comrades
const HEROES := {
	"stakhanov": {"body": "Barbarian", "acc": ["miner"], "weapon_hand": true},
	"ilitch": {"body": "Mage", "acc": ["chapka", "goatee"], "weapon_hand": true},
	"moustache": {"body": "Rogue", "acc": ["kepi", "big_moustache"], "weapon_hand": true},
	"babouchka": {"body": "Knight", "acc": ["fichu"], "weapon_hand": true},
	"barbudo": {"body": "Rogue", "acc": ["beret", "beard", "cigar"], "weapon_hand": true},
	"youri": {"body": "Knight", "acc": ["space_helmet"], "weapon_hand": true},
}

# hero animation names (KayKit)
const HERO_ANIMS := {
	"idle": "2H_Melee_Idle", "run": "Running_A", "jump": "Jump_Idle", "fall": "Jump_Idle", "land": "Jump_Land",
	"slide": "Dodge_Forward", "dodge_f": "Dodge_Forward", "dodge_b": "Dodge_Backward", "dodge_l": "Dodge_Left", "dodge_r": "Dodge_Right",
	"hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "attack": "2H_Melee_Attack_Chop", "throw": "Throw",
	"interact": "Interact", "cast": "Spellcast_Raise", "pickup": "PickUp",
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
	hammer(n)
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
}

const ENEMY_ANIMS := {"walk": "Walk", "run": "Run", "death": "Death", "hit": "HitRecieve", "attack": "Punch_Right", "shoot": "Gun_Shoot", "throw": "Punch_Left", "idle": "Idle"}

static var _color_mats := {}

static func build_enemy(parent: Node, kind: String, pos: Vector3, h: float) -> Node3D:
	var looks: Array = ENEMY_LOOKS.get(kind, ENEMY_LOOKS["cadre"])
	var look: Array = looks[randi() % looks.size()]
	var path: String = (QM if look[1] == "M" else QF) + look[0] + ".glb"
	var n := U.place(parent, path, pos, h, 0.0)
	recolor(n, ENEMY_COLORS.get(kind, {}))
	return n

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
	var w := hh * (0.95 if kk else 1.25)
	var ba := BoneAttachment3D.new()
	ba.bone_name = sk.get_bone_name(hb)
	sk.add_child(ba)
	var root := Node3D.new()
	ba.add_child(root)
	if kk:
		root.position.y = w * 0.12
	U._build_accessories(root, kinds, w, hh, 0.0, w * 0.5)

static func hammer(n: Node3D):
	var sk := skeleton(n)
	if sk == null: return
	var bone := "handslot.r" if sk.find_bone("handslot.r") >= 0 else "Wrist.R"
	if sk.find_bone(bone) < 0: return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var h := Node3D.new()
	h.set_meta("airborne", true)    # held in the hand: the layout checker can't see the skinned hand
	ba.add_child(h)
	U.cyl(h, 0.035, 1.0, Vector3(0, 0.45, 0), U.solid(Color(0.55, 0.33, 0.15)))
	U.box(h, Vector3(0.42, 0.2, 0.2), Vector3(0, 0.95, 0), U.solid(Color(0.5, 0.52, 0.56), 0.0, 0.35, 0.9))
	h.scale = Vector3.ONE / n.scale.x
