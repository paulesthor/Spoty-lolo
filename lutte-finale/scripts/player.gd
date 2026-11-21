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
var max_hp := 120.0
var hp := 120.0
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
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.FORWARD
var trail_t := 0.0
const DODGE_CD := 1.6
var status := {}      # name -> remaining seconds (slow, debt, blind, seize)
var seized_weapon := ""
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
	_build_model("stakhanov")

func apply_character(c: String):
	_build_model(c)

var oneshot_t := 0.0
var char_id := "stakhanov"

func _build_model(c: String):
	char_id = c
	if model:
		model.queue_free()
		cur_anim = ""
	var keep := global_position
	global_position = Vector3.ZERO
	model = Chars.build_hero(self, c, Meta.skin_sel(c))
	ap = U.anim_player(model)
	if ap: ap.playback_default_blend_time = 0.12
	_anim("idle")
	global_position = keep

func _anim(state: String, speed := 1.0):
	if ap == null: return
	var a: String = Chars.HERO_ANIMS.get(state, state)
	if not ap.has_animation(a): return
	if cur_anim != a:
		cur_anim = a
		ap.play(a, 0.12)
	ap.speed_scale = speed

func oneshot(state: String, dur: float, speed := 1.0):
	if ap == null: return
	var a: String = Chars.HERO_ANIMS.get(state, state)
	if not ap.has_animation(a): return
	cur_anim = a
	ap.play(a, 0.08)
	ap.seek(0.0, true)
	ap.speed_scale = speed
	oneshot_t = dur

func stat_speed() -> float:
	var sp: float = base_speed * (1.0 + game.dv("vitesse") / 100.0)
	if status.get("slow", 0.0) > 0.0: sp *= 0.62
	if status.get("debt", 0.0) > 0.0: sp *= 0.55
	return sp

func apply_status(name: String):
	match name:
		"slow":
			if status.get("slow", 0.0) <= 0.0: game.toast("PAPERASSE · TU ES RALENTI", 1.2)
			status["slow"] = 2.5
		"debt":
			status["debt"] = 0.25
		"blind":
			if status.get("blind", 0.0) <= 0.0: game.hud.blind()
			status["blind"] = 1.6
		"seize":
			if status.get("seize", 0.0) > 0.0 or game.weapons.owned.is_empty(): return
			var ids: Array = game.weapons.owned.keys()
			seized_weapon = ids[randi() % ids.size()]
			status["seize"] = 5.0
			game.toast("SAISIE ! %s CONFISQUÉ 5 S" % Data.WEAPONS[seized_weapon]["name"].to_upper(), 1.8)

func _tick_status(d: float):
	for k in status.keys():
		status[k] = maxf(0.0, status[k] - d)
	if status.get("seize", 0.0) <= 0.0: seized_weapon = ""

func _physics_process(d: float):
	if game == null or game.state != "play": return
	invuln = maxf(0.0, invuln - d)
	_tick_status(d)
	if game.dirl("rationnement") == 0:
		hp = minf(max_hp, hp + (0.4 + game.mods.get("regen", 0.0)) * d)
	slide_cd = maxf(0.0, slide_cd - d)
	dodge_cd = maxf(0.0, dodge_cd - d)
	var input := Vector2.ZERO
	var want_jump := false
	var want_slide := false
	var want_dodge := false
	if bot:
		var r := _bot_input(d)
		input = r[0]; want_jump = r[1]; want_slide = r[2]
		want_dodge = r.size() > 3 and r[3]
	else:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_jump = Input.is_action_just_pressed("jump")
		want_slide = Input.is_action_just_pressed("slide")
		want_dodge = Input.is_action_just_pressed("dodge")
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0, input.y)
	if dir.length() > 1.0: dir = dir.normalized()
	var spd := stat_speed()
	if want_slide and slide_cd <= 0.0 and is_on_floor():
		slide_t = 0.55
		slide_cd = 0.9
		invuln = maxf(invuln, 0.2)
		slide_dir = dir.normalized() if dir.length() > 0.1 else facing
	if slide_t > 0.0:
		slide_t -= d
		var k := clampf(slide_t / 0.55, 0.0, 1.0)
		dir = slide_dir.lerp(dir if dir.length() > 0.1 else slide_dir, 0.25).normalized()
		spd *= 1.0 + 1.1 * k
		# the slide leaves a burning trail that hurts enemies
		trail_t -= d
		if trail_t <= 0.0:
			trail_t = 0.05
			game.weapons.add_trail(global_position)
	# dodge: short invulnerable dash, usable in the air
	if want_dodge and dodge_cd <= 0.0:
		dodge_t = 0.22
		dodge_cd = DODGE_CD * (1.0 - game.mods.get("dodge_cd", 0.0) / 100.0)
		dodge_dir = dir.normalized() if dir.length() > 0.1 else facing
		invuln = maxf(invuln, 0.38)
		game.weapons.dodge_fx(global_position, dodge_dir)
		var side := facing.cross(Vector3.UP).dot(dodge_dir)
		var fwd := facing.dot(dodge_dir)
		var st := "dodge_f"
		if fwd < -0.5: st = "dodge_b"
		elif side > 0.5: st = "dodge_r"
		elif side < -0.5: st = "dodge_l"
		oneshot(st, 0.4, 1.6)
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 70.0 if is_on_floor() else 30.0
	hv = hv.move_toward(dir * spd, accel * d)
	if dodge_t > 0.0:
		dodge_t -= d
		hv = dodge_dir * 22.0
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		jumps_left = 1
	var low_g := char_id == "youri"
	velocity.y -= GRAVITY * d * (0.72 if low_g and velocity.y < 0.0 else 1.0)
	if want_jump:
		if is_on_floor():
			velocity.y = JUMP_V * (1.15 if char_id == "youri" else 1.0)
		elif jumps_left > 0:
			velocity.y = DOUBLE_JUMP_V * (1.15 if char_id == "youri" else 1.0)
			jumps_left -= 1
	last_vy = velocity.y
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		landed.emit(-last_vy)
		if -last_vy > 7.0 and oneshot_t <= 0.0: oneshot("land", 0.25, 1.5)
	was_on_floor = on_floor
	if hv.length() > 0.3:
		facing = hv.normalized()
		model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z) + Chars.KK_YAW, 14.0 * d)
	oneshot_t = maxf(0.0, oneshot_t - d)
	if oneshot_t > 0.0:
		pass
	elif not on_floor:
		_anim("jump" if velocity.y > 0.0 else "fall")
	elif slide_t > 0.0:
		_anim("slide", 1.3)
	elif hv.length() > 0.5:
		_anim("run", clampf(hv.length() / 7.0, 0.7, 1.6))
	else:
		_anim("idle")
	if global_position.y < -5.0:
		global_position = Vector3(0, 1, 0)

var last_cause := ""
func take_damage(amount: float, dot := false, from := Vector3.INF, cause := "") -> bool:
	if hp <= 0.0 or (invuln > 0.0 and not dot) or game.test_god: return false
	if cause != "": last_cause = cause
	if not dot and oneshot_t <= 0.0 and slide_t <= 0.0: oneshot("hit", 0.25, 1.6)
	if from != Vector3.INF and not dot: game.hud.hit_from(from)
	if not dot and randf() * 100.0 < game.mods.get("dodge", 0.0):
		invuln = 0.3
		return false
	hp -= maxf(amount - game.dv("armure"), amount * 0.25)
	if not dot: invuln = 0.6
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
	var center: Vector3 = game.world.player_start
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
	var best_c = null
	var bd := 40.0
	for c in game.chests:
		var cost: int = 0 if c["free"] else game.chest_cost
		var dd: float = c["n"].global_position.distance_to(global_position)
		if cost <= game.rubles and dd < bd: bd = dd; best_c = c["n"].global_position
	if best_c != null:
		want = (best_c - global_position)
	var g = game.nearest_gem(global_position, 14.0)
	if g != null:
		want = want * 0.3 + (g - global_position) * 1.5
	if game.door != null:
		want = game.door.global_position - global_position
		want.y = 0
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
	var dg := flee.length() > 3.0 and randf() < 0.05
	return [v2, j, s, dg]
