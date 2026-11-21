extends CharacterBody3D
# Ilitch-like comrade in a chapka. Third-person movement relative to the camera yaw.

signal landed(fall_speed: float)

const GRAVITY := 26.0
const JUMP_V := 10.5
const DOUBLE_JUMP_V := 9.0

var game
var model: Node3D
var ap: AnimationPlayer
var cam_yaw := 0.0
var max_hp := 100.0
var hp := 100.0
var base_speed := 7.5
var jumps_left := 1
var slide_t := 0.0
var slide_cd := 0.0
var slide_dir := Vector3.FORWARD
var invuln := 0.0
var was_on_floor := true
var last_vy := 0.0
var facing := Vector3.FORWARD
var cur_anim := ""
# bot (automated test) state
var bot := false
var bot_angle := 0.0
var bot_jump_t := 2.0
var bot_slide_t := 3.5

func setup(g):
	game = g
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.45; cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	floor_snap_length = 0.3
	model = U.place(self, U.CH + "character-male-b.glb", Vector3.ZERO, 1.75, 0.0)
	U.shrink_head(model)
	U.attach_head(model, ["chapka"])
	var arm := U.bone_attach(model, "arm-right")
	if arm:
		var ww: float = arm.get_meta("w")
		var hammer := Node3D.new()
		var handle := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.035; cy.bottom_radius = 0.035; cy.height = 1.0
		handle.mesh = cy; handle.material_override = U.solid(Color(0.55, 0.33, 0.15)); handle.position = Vector3(0, 0.45, 0)
		hammer.add_child(handle)
		var head := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.42, 0.2, 0.2)
		head.mesh = hb; head.material_override = U.solid(Color(0.5, 0.52, 0.56), 0.0, 0.35, 0.9); head.position = Vector3(0.0, 0.95, 0)
		hammer.add_child(head)
		arm.add_child(hammer)
		hammer.scale = Vector3.ONE * ww * 1.1
		hammer.position = Vector3(-ww * 0.1, -ww * 0.75, ww * 0.15)
		hammer.rotation_degrees = Vector3(-60, 0, 0)
	ap = U.anim_player(model)
	_anim("idle")

func _anim(a: String, speed := 1.0):
	if ap == null: return
	if cur_anim != a:
		cur_anim = a
		ap.play(a, 0.12)
	ap.speed_scale = speed

func stat_speed() -> float:
	return base_speed * (1.0 + 0.08 * game.decret_lv("vitesse"))

func _physics_process(d: float):
	if game == null or game.state != "play": return
	invuln = maxf(0.0, invuln - d)
	slide_cd = maxf(0.0, slide_cd - d)
	var input := Vector2.ZERO
	var want_jump := false
	var want_slide := false
	if bot:
		var r := _bot_input(d)
		input = r[0]; want_jump = r[1]; want_slide = r[2]
	else:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_jump = Input.is_action_just_pressed("jump")
		want_slide = Input.is_action_just_pressed("slide")
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0, input.y)
	if dir.length() > 1.0: dir = dir.normalized()
	var spd := stat_speed()
	if want_slide and slide_cd <= 0.0 and is_on_floor():
		slide_t = 0.55
		slide_cd = 0.9
		slide_dir = dir.normalized() if dir.length() > 0.1 else facing
	if slide_t > 0.0:
		slide_t -= d
		var k := clampf(slide_t / 0.55, 0.0, 1.0)
		dir = slide_dir.lerp(dir if dir.length() > 0.1 else slide_dir, 0.25).normalized()
		spd *= 1.0 + 1.1 * k
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 70.0 if is_on_floor() else 30.0
	hv = hv.move_toward(dir * spd, accel * d)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		jumps_left = 1
	velocity.y -= GRAVITY * d
	if want_jump:
		if is_on_floor():
			velocity.y = JUMP_V
		elif jumps_left > 0:
			velocity.y = DOUBLE_JUMP_V
			jumps_left -= 1
	last_vy = velocity.y
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		landed.emit(-last_vy)
	was_on_floor = on_floor
	if hv.length() > 0.3:
		facing = hv.normalized()
		model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z), 14.0 * d)
	if not on_floor:
		_anim("jump" if velocity.y > 0.0 else "fall")
	elif slide_t > 0.0:
		_anim("crouch")
	elif hv.length() > 0.5:
		_anim("sprint", clampf(hv.length() / 7.5, 0.6, 1.6))
	else:
		_anim("idle")
	if global_position.y < -5.0:
		global_position = Vector3(0, 1, 0)

func take_damage(amount: float) -> bool:
	if invuln > 0.0 or hp <= 0.0: return false
	hp -= amount
	invuln = 0.45
	game.on_player_hit(amount)
	if hp <= 0.0:
		hp = 0.0
		game.game_over()
	return true

func heal(amount: float):
	hp = minf(max_hp, hp + amount)

# simple automated player used for headless tests
func _bot_input(d: float) -> Array:
	bot_angle += d * 0.22
	var center := Vector3(0, 0, -12)
	var target := center + Vector3(cos(bot_angle), 0, sin(bot_angle)) * 20.0
	var want := target - global_position
	want.y = 0
	var flee := Vector3.ZERO
	for e in game.enemies.alive_list():
		var v: Vector3 = global_position - e.node.global_position
		v.y = 0
		var dist := v.length()
		if dist < 4.5 and dist > 0.01:
			flee += v / dist * (4.5 - dist) * (3.0 if e.boss else 1.0)
	var g = game.nearest_gem(global_position, 14.0)
	if g != null:
		want = want * 0.3 + (g - global_position) * 1.5
	var mv := want.normalized() * 0.7 + flee * 0.6
	mv = Basis(Vector3.UP, -cam_yaw) * mv
	bot_jump_t -= d
	bot_slide_t -= d
	var j := false
	var s := false
	if bot_jump_t <= 0.0: j = true; bot_jump_t = randf_range(2.0, 5.0)
	if bot_slide_t <= 0.0: s = true; bot_slide_t = randf_range(3.0, 6.0)
	var v2 := Vector2(mv.x, mv.z)
	if v2.length() > 1.0: v2 = v2.normalized()
	return [v2, j, s]
