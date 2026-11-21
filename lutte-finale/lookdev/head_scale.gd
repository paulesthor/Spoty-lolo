extends SkeletonModifier3D
# Shrinks the head bone after animation is applied, for less "chibi" proportions.
@export var head_scale := 0.8
@export var body_scale := 1.0
func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk: return
	var h := sk.find_bone("head")
	if h >= 0: sk.set_bone_pose_scale(h, Vector3.ONE * head_scale)
	var t := sk.find_bone("torso")
	if t >= 0 and body_scale != 1.0: sk.set_bone_pose_scale(t, Vector3(1.0, body_scale, 1.0))
