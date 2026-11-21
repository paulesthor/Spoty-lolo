extends Control
# Minimap: rotates with the camera (forward is up). Shows the arena, buildings, raised platforms,
# chests, shrines, elites, bosses, the tax inspector, tornadoes and the zone door.
# Normal enemies are deliberately left out (readability). M: small <-> off · Tab: large map.

var game
var big := false
const SMALL := 230.0
const BIG := 620.0

func setup(g):
	game = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(_d):
	if game == null or game.player == null: return
	var on: bool = Meta.opt("minimap") > 0.0
	var want_big: bool = Input.is_action_pressed("bigmap") and game.state == "play"
	visible = (on or want_big) and game.state in ["play", "paused"]
	if want_big != big:
		big = want_big
	var vs := get_viewport_rect().size
	if big:
		size = Vector2(BIG, BIG)
		position = (vs - size) / 2.0
	else:
		size = Vector2(SMALL, SMALL)
		position = Vector2(vs.x - SMALL - 24.0, 104.0)
	if visible: queue_redraw()

func _w2m(p: Vector3, c: Vector3, yaw: float, k: float) -> Vector2:
	var r := Vector3(p.x - c.x, 0, p.z - c.z).rotated(Vector3.UP, -yaw)
	return size / 2.0 + Vector2(r.x, r.z) * k

func _rect(r: Rect2, c: Vector3, yaw: float, k: float, col: Color):
	var pts := PackedVector2Array([
		_w2m(Vector3(r.position.x, 0, r.position.y), c, yaw, k), _w2m(Vector3(r.end.x, 0, r.position.y), c, yaw, k),
		_w2m(Vector3(r.end.x, 0, r.end.y), c, yaw, k), _w2m(Vector3(r.position.x, 0, r.end.y), c, yaw, k)])
	draw_colored_polygon(pts, col)

func _draw():
	if game == null: return
	var c: Vector3 = game.player.global_position
	var yaw: float = game.player.cam_yaw
	var radius := 110.0 if big else 48.0
	var k := (size.x / 2.0) / radius
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.05, 0.82))
	var w = game.world
	_rect(w.bounds, c, yaw, k, Color(0.32, 0.31, 0.3, 0.9))
	for r in w.cuts: _rect(r, c, yaw, k, Color(0.1, 0.09, 0.09, 1))
	for pl in w.plateaus:
		_rect(pl["rect"], c, yaw, k, Color(0.55, 0.5, 0.4, 0.95))
		for rp in pl["ramps"]: _rect(rp["rect"], c, yaw, k, Color(0.45, 0.42, 0.36, 0.95))
	# shrines (unused), chests
	for s in game.shrines:
		if s["used"] and s["kind"] != "marche": continue
		var sp := _w2m(s["pos"], c, yaw, k)
		draw_circle(sp, 6.0 if big else 4.5, Color(0.35, 0.8, 1.0))
		draw_arc(sp, 8.0 if big else 6.0, 0, TAU, 16, Color(1, 1, 1, 0.8), 1.5)
	for ch in game.chests:
		var cp := _w2m((ch["n"] as Node3D).global_position, c, yaw, k)
		var col := Color(0.75, 0.4, 1.0) if ch["free"] else Color(1.0, 0.78, 0.25)
		var h := 5.0 if big else 3.5
		draw_rect(Rect2(cp - Vector2(h, h), Vector2(h, h) * 2.0), col)
	# weather
	if game.weather and "tornadoes" in game.weather:
		for t in game.weather.tornadoes:
			if t is Dictionary and t.has("n") and is_instance_valid(t["n"]):
				var tp := _w2m((t["n"] as Node3D).global_position, c, yaw, k)
				draw_arc(tp, 7.0, 0, TAU, 16, Color(0.8, 0.8, 0.85), 2.5)
				draw_arc(tp, 3.5, 0, TAU, 12, Color(0.8, 0.8, 0.85), 2.0)
	# threats worth knowing about
	for e in game.enemies.alive_list():
		if not (e.elite or e.boss or e.invincible or e.affix != ""): continue
		if e.affix != "" and not big: continue
		var ep := _w2m(e.node.position, c, yaw, k)
		if e.boss:
			draw_circle(ep, 9.0, Color(0.9, 0.1, 0.1))
			draw_arc(ep, 11.0, 0, TAU, 20, Color(1, 0.85, 0.3), 2.0)
		elif e.invincible:
			draw_circle(ep, 6.0, Color(0.5, 0.7, 1.0))
		elif e.elite:
			draw_circle(ep, 6.0, Color(1.0, 0.75, 0.2))
		else:
			draw_circle(ep, 3.5, Color(0.95, 0.35, 0.3))
	if game.door != null:
		var dp := _w2m(game.door.global_position, c, yaw, k)
		dp = dp.clamp(Vector2(8, 8), size - Vector2(8, 8))
		draw_circle(dp, 9.0, Color(1, 0.2, 0.15))
		draw_arc(dp, 12.0, 0, TAU, 20, Color(1, 1, 1), 2.0)
	# player arrow (camera forward is always up)
	var f: Vector3 = game.player.facing.rotated(Vector3.UP, -yaw)
	var dir := Vector2(f.x, f.z).normalized()
	if dir == Vector2.ZERO: dir = Vector2(0, -1)
	var ctr := size / 2.0
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([ctr + dir * 10.0, ctr - dir * 6.0 + side * 6.0, ctr - dir * 3.0, ctr - dir * 6.0 - side * 6.0]), Color(1, 1, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 2.0)
	if big:
		var font: Font = U.font_main
		draw_string(font, Vector2(14, 30), "CARTE · coffres (or/violet) · sanctuaires (bleu) · élites (orange) · boss (rouge) · porte (rouge cerclé)", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 15, Color(1, 1, 1, 0.85))
