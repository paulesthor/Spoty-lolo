extends RefCounted
# Themed lot builders for the zones of acts II and III (world.gd keeps the act I lots).
# Every lot dresses its rectangle and registers what blocks movement with the world.

var w          # world.gd

func build(kind: String, r: Rect2):
	match kind:
		"plage": _plage(r)
		"marina": _marina(r)
		"boites": _boites(r)
		"chill": _chill(r)
		"velos": _velos(r)
		"serveurs": _serveurs(r)
		"refroidissement": _refroidissement(r)
		"cables": _cables(r)
		"chalets": _chalets(r)
		"sapins": _sapins(r)
		"telesiege": _telesiege(r)
		"pas_de_tir": _pas_de_tir(r)
		"carburant": _carburant(r)
		"antennes": _antennes(r)
		"defile": _defile(r)

func _v(x: float, z: float) -> Vector3:
	return Vector3(x, 0, z)

func _rand_in(r: Rect2, pad: float) -> Vector3:
	return _v(w.rng.randf_range(r.position.x + pad, r.end.x - pad), w.rng.randf_range(r.position.y + pad, r.end.y - pad))

func _floor(r: Rect2, mat: Material):
	var f := U.box(w, Vector3(r.size.x, 0.05, r.size.y), Vector3(r.get_center().x, 0.03, r.get_center().y), mat)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- Paradis fiscal
func _plage(r: Rect2):
	_floor(r, U.pbr("Ground080", 0.15, Color(1.25, 1.18, 1.0), 0.5))
	var towel_cols := [Color(0.9, 0.2, 0.25), Color(0.15, 0.55, 0.85), Color(1.0, 0.8, 0.2), Color(0.2, 0.7, 0.45)]
	var white := U.solid(Color(0.95, 0.95, 0.92), 0.0, 0.7)
	var cols := maxi(1, int(r.size.x / 7.0))
	var rows := maxi(1, int(r.size.y / 8.0))
	for ix in cols:
		for iz in rows:
			if w.rng.randf() < 0.3: continue
			var p := _v(r.position.x + (ix + 0.5) * r.size.x / cols, r.position.y + (iz + 0.5) * r.size.y / rows)
			if w._blocked(p, 2.0): continue
			U.place(w, U.CC + ["detail-parasol-a", "detail-parasol-b"][(ix + iz) % 2] + ".glb", p, 2.6, w.rng.randf() * TAU)
			w.small_obstacle(p, 0.5)
			# two deckchairs and towels in the parasol's shade
			for sd in [-1.0, 1.0]:
				var cp: Vector3 = p + Vector3(sd * 1.3, 0, 0.8)
				var ch := Node3D.new(); w.add_child(ch); ch.position = cp; ch.rotation.y = w.rng.randf_range(-0.3, 0.3)
				U.box(ch, Vector3(0.7, 0.08, 1.3), Vector3(0, 0.32, 0), U.solid(towel_cols[(ix + iz + int(sd + 1.0)) % 4], 0.0, 0.8))
				U.box(ch, Vector3(0.7, 0.08, 0.7), Vector3(0, 0.62, -0.75), white, Vector3(-0.8, 0, 0))
				for k in 4: U.box(ch, Vector3(0.05, 0.3, 0.05), Vector3(-0.3 + (k % 2) * 0.6, 0.15, -0.55 + (k / 2) * 1.1), white)
			var tw := U.box(w, Vector3(0.9, 0.02, 1.7), p + Vector3(0.2, 0.06, -1.6), U.solid(towel_cols[(ix * 3 + iz) % 4], 0.0, 0.9), Vector3(0, w.rng.randf() * 0.6, 0))
			tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# lifeguard tower: the only one watching is the money
	var lp := _v(r.end.x - 3.0, r.position.y + 3.0)
	if not w._blocked(lp, 2.0):
		var t := Node3D.new(); w.add_child(t); t.position = lp
		var wood := U.solid(Color(0.85, 0.75, 0.55), 0.0, 0.9)
		for k in 4: U.box(t, Vector3(0.15, 3.0, 0.15), Vector3(-0.8 + (k % 2) * 1.6, 1.5, -0.8 + (k / 2) * 1.6), wood)
		U.box(t, Vector3(2.0, 0.15, 2.0), Vector3(0, 3.0, 0), wood)
		U.box(t, Vector3(2.0, 1.2, 2.0), Vector3(0, 3.7, 0), U.solid(Color(0.95, 0.3, 0.25), 0.0, 0.7))
		U.box(t, Vector3(2.4, 0.1, 2.4), Vector3(0, 4.4, 0), wood)
		var sl := U.label(t, "SURVEILLANCE\nDU CAPITAL", Vector3(0, 3.7, 1.015), 40, Color(1, 1, 1), Color(0, 0, 0, 0), false)
		sl.outline_size = 0; U.fit_label(sl, 1.8, 1.0)
		w.small_obstacle(lp, 1.2)
		w._static_box(lp + Vector3(0, 2.2, 0), Vector3(1.8, 4.4, 1.8))
	for k in 3:
		var pp := _rand_in(r, 2.5)
		if w._blocked(pp, 1.5): continue
		U.nature(w, ["palm_tree_1", "palm_tree_2", "palm_tree_4"][k % 3], pp, w.rng.randf_range(7.0, 10.0), w.rng.randf() * TAU)
		w.small_obstacle(pp, 0.6)
	w._lot_sign(_v(r.get_center().x, r.position.y + 2.0), "PLAGE PRIVÉE · PAUVRES INTERDITS", Color(1, 0.85, 0.3))

func yacht(p: Vector3, rot: float, s := 1.0) -> Node3D:
	var y := Node3D.new(); w.add_child(y); y.position = p; y.rotation.y = rot; y.scale = Vector3.ONE * s
	var hull := U.solid(Color(0.96, 0.96, 0.95), 0.1, 0.3, 0.6)
	var dark := U.solid(Color(0.1, 0.18, 0.3), 0.0, 0.4)
	U.box(y, Vector3(2.6, 0.9, 7.0), Vector3(0, 0.35, 0), hull)
	U.box(y, Vector3(2.65, 0.25, 7.05), Vector3(0, 0.0, 0), dark)
	var bow := U.box(y, Vector3(1.85, 0.9, 1.85), Vector3(0, 0.35, 3.5), hull, Vector3(0, PI / 4, 0))
	U.box(y, Vector3(2.0, 0.8, 3.0), Vector3(0, 1.2, -0.6), hull)
	U.box(y, Vector3(2.05, 0.3, 3.05), Vector3(0, 1.25, -0.6), U.solid(Color(0.1, 0.12, 0.15), 0.3, 0.1, 0.5))
	U.box(y, Vector3(1.4, 0.6, 1.6), Vector3(0, 1.9, -0.9), hull)
	U.cyl(y, 0.05, 2.2, Vector3(0, 3.2, -0.9), U.solid(Color(0.7, 0.7, 0.72), 0.0, 0.3, 0.8))
	var l := U.label(y, "LIQUIDITÉS III", Vector3(1.31, 0.45, -1.5), 50, Color(0.1, 0.18, 0.3), Color(0, 0, 0, 0), false)
	U.fit_label(l, 4.0, 0.5)
	l.rotation.y = PI / 2; l.outline_size = 0
	return y

func _marina(r: Rect2):
	var inner := r.grow(-3.0)
	if inner.size.x < 8.0 or inner.size.y < 8.0: return
	var water := U.box(w, Vector3(inner.size.x, 0.05, inner.size.y), Vector3(inner.get_center().x, 0.04, inner.get_center().y), U.solid(Color(0.1, 0.48, 0.62), 0.2, 0.08, 0.4))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stone := U.pbr("Concrete034", 0.4, Color(1.0, 0.97, 0.9), 0.6)
	for e in [[Vector3(inner.get_center().x, 0.25, inner.position.y), Vector3(inner.size.x + 0.6, 0.5, 0.6)], [Vector3(inner.get_center().x, 0.25, inner.end.y), Vector3(inner.size.x + 0.6, 0.5, 0.6)],
			[Vector3(inner.position.x, 0.25, inner.get_center().y), Vector3(0.6, 0.5, inner.size.y)], [Vector3(inner.end.x, 0.25, inner.get_center().y), Vector3(0.6, 0.5, inner.size.y)]]:
		U.box(w, e[1], e[0], stone)
	# the basin is a no-go zone: an invisible rail along the quay keeps everyone out of the water
	w.obstacles.append(inner)
	w._static_box(Vector3(inner.get_center().x, 0.75, inner.get_center().y), Vector3(inner.size.x, 1.5, inner.size.y))
	var along_x := inner.size.x > inner.size.y
	var n := maxi(1, int((inner.size.x if along_x else inner.size.y) / 9.0))
	for i in n:
		var k := (i + 0.5) / n
		var p := _v(lerpf(inner.position.x, inner.end.x, k), inner.get_center().y) if along_x else _v(inner.get_center().x, lerpf(inner.position.y, inner.end.y, k))
		var sc := minf(1.0, (minf(inner.size.x, inner.size.y) - 1.0) / 7.5)
		if sc < 0.5: continue
		yacht(p + Vector3(0, -0.1, 0), (0.0 if not along_x else PI / 2) + (PI if i % 2 == 0 else 0.0), sc)
	# bollards on the quay
	for i in 6:
		var bp := _v(inner.position.x - 1.2, lerpf(inner.position.y, inner.end.y, i / 5.0))
		U.cyl(w, 0.18, 0.5, bp + Vector3(0, 0.25, 0), U.solid(Color(0.15, 0.15, 0.17), 0.0, 0.4, 0.7))
	w._lot_sign(_v(r.get_center().x, r.position.y + 1.2), "MARINA · PAVILLON DE COMPLAISANCE", Color(0.6, 0.9, 1.0))

func _boites(r: Rect2):
	# a field of letterboxes: each one a company "headquartered" here
	_floor(r, U.pbr("Tiles101", 0.4, Color(0.95, 0.95, 0.92), 0.5))
	var post := U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.4, 0.8)
	var boxes := [U.solid(Color(0.85, 0.75, 0.2), 0.2, 0.4, 0.6), U.solid(Color(0.2, 0.3, 0.55), 0.0, 0.5), U.solid(Color(0.6, 0.6, 0.62), 0.3, 0.3, 0.8)]
	var tag := U.solid(Color(0.95, 0.95, 0.9))
	var x := r.position.x + 2.5
	var row := 0
	while x < r.end.x - 2.0:
		var z := r.position.y + 2.5 + (row % 2) * 1.2
		while z < r.end.y - 2.0:
			var p := _v(x, z)
			if not w._blocked(p, 0.5) and w.rng.randf() < 0.85:
				U.box(w, Vector3(0.1, 1.1, 0.1), p + Vector3(0, 0.55, 0), post)
				U.box(w, Vector3(0.42, 0.34, 0.55), p + Vector3(0, 1.25, 0), boxes[w.rng.randi() % 3])
				U.box(w, Vector3(0.3, 0.08, 0.01), p + Vector3(0, 1.3, 0.28), tag)
				w.small_obstacle(p, 0.3)
			z += 2.4
		x += 2.6; row += 1
	w._lot_sign(_v(r.get_center().x, r.get_center().y), "SIÈGE SOCIAL DE 4 000 ENTREPRISES", Color(1, 0.85, 0.3))

# ---------------------------------------------------------------- Start-up nation
func _chill(r: Rect2):
	_floor(r, U.pbr("Grass004", 0.25, Color(0.75, 1.1, 0.6), 0.5))      # synthetic lawn
	var cols := [Color(1.0, 0.4, 0.6), Color(0.3, 0.8, 0.9), Color(1.0, 0.85, 0.2), Color(0.6, 0.4, 0.95)]
	for i in int(r.size.x * r.size.y / 70.0):
		var p := _rand_in(r, 2.0)
		if w._blocked(p, 1.2): continue
		match i % 4:
			0, 1:  # beanbags
				U.sphere(w, 0.6, p + Vector3(0, 0.3, 0), U.solid(cols[i % 4], 0.0, 0.9), 0.65)
				w.small_obstacle(p, 0.5)
			2:  # table football
				var t := Node3D.new(); w.add_child(t); t.position = p; t.rotation.y = w.rng.randf() * TAU
				U.box(t, Vector3(1.4, 0.3, 0.8), Vector3(0, 0.85, 0), U.solid(Color(0.15, 0.45, 0.2)))
				U.box(t, Vector3(1.5, 0.12, 0.9), Vector3(0, 1.0, 0), U.solid(Color(0.35, 0.22, 0.12)))
				for k in 4: U.box(t, Vector3(0.1, 0.7, 0.1), Vector3(-0.6 + (k % 2) * 1.2, 0.35, -0.3 + (k / 2) * 0.6), U.solid(Color(0.2, 0.2, 0.2)))
				for k in 4: U.cyl(t, 0.02, 1.4, Vector3(-0.45 + k * 0.3, 1.05, 0), U.solid(Color(0.8, 0.8, 0.82), 0.0, 0.3, 0.9)).rotation.x = PI / 2
				w.small_obstacle(p, 0.8)
			3:  # ping-pong
				var pt := U.box(w, Vector3(2.6, 0.08, 1.5), p + Vector3(0, 0.76, 0), U.solid(Color(0.1, 0.35, 0.6)))
				U.box(w, Vector3(0.04, 0.16, 1.5), p + Vector3(0, 0.88, 0), U.solid(Color(0.95, 0.95, 0.95)))
				for k in 4: U.box(w, Vector3(0.08, 0.76, 0.08), p + Vector3(-1.1 + (k % 2) * 2.2, 0.38, -0.6 + (k / 2) * 1.2), U.solid(Color(0.2, 0.2, 0.2)))
				w.small_obstacle(p, 1.3)
	# a giant slide: management's idea of a career path
	var sp := _v(r.position.x + 4.0, r.get_center().y)
	if not w._blocked(sp, 3.0):
		var s := Node3D.new(); w.add_child(s); s.position = sp
		var yel := U.solid(Color(1.0, 0.75, 0.1), 0.0, 0.5)
		for k in 2: U.box(s, Vector3(0.12, 4.2, 0.12), Vector3(-0.5 + k, 2.1, -1.5), U.solid(Color(0.3, 0.3, 0.32)))
		U.box(s, Vector3(1.3, 0.15, 1.3), Vector3(0, 4.2, -1.5), yel)
		U.box(s, Vector3(1.0, 0.12, 6.2), Vector3(0, 2.1, 1.0), yel, Vector3(0.74, 0, 0))
		# the name is painted on a board on the slide's top railing
		U.box(s, Vector3(2.2, 0.6, 0.06), Vector3(0, 4.7, -0.86), U.solid(Color(0.15, 0.15, 0.17)))
		for sx in [-1.0, 1.0]: U.box(s, Vector3(0.06, 0.6, 0.06), Vector3(sx * 1.0, 4.4, -0.86), U.solid(Color(0.3, 0.3, 0.32)))
		var asl := U.label(s, "ASCENSEUR SOCIAL", Vector3(0, 4.7, -0.82), 48, Color(1, 0.85, 0.3), Color(0, 0, 0, 0), false)
		asl.outline_size = 0; U.fit_label(asl, 2.0, 0.45)
		w.add_obstacle(s, true, 0.2)
	w._lot_sign(_v(r.get_center().x, r.end.y - 2.0), "ESPACE BIEN-ÊTRE (OBLIGATOIRE)", Color(1, 0.6, 0.85))

func _velos(r: Rect2):
	_floor(r, U.pbr("Concrete034", 0.3, Color(0.85, 0.85, 0.88), 0.6))
	var teal := U.solid(Color(0.15, 0.8, 0.7), 0.0, 0.6)
	var dark := U.solid(Color(0.1, 0.1, 0.12), 0.0, 0.5)
	var rows := maxi(1, int(r.size.y / 6.0))
	for iz in rows:
		var z := r.position.y + (iz + 0.5) * r.size.y / rows
		var x := r.position.x + 2.0
		var rack := U.box(w, Vector3(r.size.x - 4.0, 0.08, 0.08), _v(r.get_center().x, z) + Vector3(0, 0.6, 0), U.solid(Color(0.6, 0.6, 0.62), 0.0, 0.3, 0.8))
		w.obstacles.append(Rect2(r.position.x + 2.0, z - 0.9, r.size.x - 4.0, 1.8))
		w._static_box(_v(r.get_center().x, z) + Vector3(0, 0.5, 0), Vector3(r.size.x - 4.0, 1.0, 1.4))
		while x < r.end.x - 2.0:
			if w.rng.randf() < 0.75:
				var b := Node3D.new(); w.add_child(b); b.position = _v(x, z)
				for k in [-0.5, 0.5]:
					var wh := U.cyl(b, 0.34, 0.05, Vector3(0, 0.36, k), dark)
					wh.rotation.z = PI / 2
				U.box(b, Vector3(0.05, 0.05, 0.9), Vector3(0, 0.62, 0), teal)
				U.box(b, Vector3(0.05, 0.4, 0.05), Vector3(0, 0.55, -0.25), teal)
				U.box(b, Vector3(0.45, 0.4, 0.4), Vector3(0, 1.0, 0.25), teal)      # the delivery box
				U.label(b, "MIAM", Vector3(0.23, 1.0, 0.25), 28, Color(1, 1, 1), Color(0, 0, 0, 0), false).rotation.y = PI / 2
			x += 1.3
	w._lot_sign(_v(r.get_center().x, r.position.y + 1.5), "AUTO-ENTREPRENEURS · PAS DE CONTRAT", Color(0.4, 1, 0.9))

# ---------------------------------------------------------------- Data center
func _serveurs(r: Rect2):
	_floor(r, U.pbr("Tiles101", 0.5, Color(0.55, 0.58, 0.65), 0.5))
	var metal := U.pbr("Metal049A", 0.3, Color(0.3, 0.32, 0.38), 0.8)
	var leds := [U.solid(Color(0.2, 0.7, 1.0), 3.5), U.solid(Color(0.3, 1.0, 0.5), 3.5), U.solid(Color(1.0, 0.3, 0.3), 3.5)]
	var tray := U.solid(Color(0.75, 0.6, 0.15), 0.0, 0.6)
	var along_x := r.size.x >= r.size.y
	var length := (r.size.x if along_x else r.size.y) - 6.0
	var across := r.size.y if along_x else r.size.x
	var n := maxi(1, int(across / 4.6))
	for i in n:
		var off := (i + 0.5) * across / n
		var c := _v(r.get_center().x, r.position.y + off) if along_x else _v(r.position.x + off, r.get_center().y)
		var size := Vector3(length, 2.9, 1.2) if along_x else Vector3(1.2, 2.9, length)
		var row := U.box(w, size, c + Vector3(0, 1.45, 0), metal)
		w.add_obstacle(row)
		# blinking fronts on both sides and a cable tray on top
		for sd in [-1.0, 1.0]:
			var y := 0.6
			while y < 2.6:
				var lp := c + (Vector3(0, y, sd * 0.61) if along_x else Vector3(sd * 0.61, y, 0))
				var ls := U.box(w, Vector3(length * 0.92, 0.05, 0.03) if along_x else Vector3(0.03, 0.05, length * 0.92), lp, leds[w.rng.randi() % 3])
				ls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				y += 0.42
		U.box(w, (Vector3(length, 0.12, 0.5) if along_x else Vector3(0.5, 0.12, length)), c + Vector3(0, 3.05, 0), tray)
	w._lot_sign(_v(r.get_center().x, r.position.y + 1.0) if along_x else _v(r.position.x + 1.0, r.get_center().y), "SALLE DES SERVEURS · VOS SECRETS ICI", Color(0.5, 0.85, 1.0))

func _refroidissement(r: Rect2):
	_floor(r, U.pbr("Concrete034", 0.25, Color(0.8, 0.82, 0.86), 0.7))
	var n := maxi(2, int(r.size.x * r.size.y / 260.0))
	for i in n:
		var p := _rand_in(r, 4.0)
		if w._blocked(p, 3.0): continue
		if i % 3 == 0:
			var t := U.place(w, U.IND + "detail-tank-large.glb", p, w.rng.randf_range(5.0, 8.0), w.rng.randf() * TAU)
			w.add_obstacle(t)
			var a := U.world_aabb(t)
			w.far_smokes.append({"p": Vector3(p.x, a.end.y + 0.5, p.z), "t": 0.0, "s": 3.0})
		else:
			# big fan unit: housing, grille, blades
			var f := Node3D.new(); w.add_child(f); f.position = p
			U.box(f, Vector3(3.2, 1.6, 3.2), Vector3(0, 0.8, 0), U.solid(Color(0.75, 0.77, 0.8), 0.0, 0.5, 0.6))
			U.cyl(f, 1.35, 0.1, Vector3(0, 1.62, 0), U.solid(Color(0.15, 0.15, 0.17)))
			for k in 4:
				U.box(f, Vector3(2.4, 0.04, 0.4), Vector3(0, 1.7, 0), U.solid(Color(0.6, 0.62, 0.66), 0.0, 0.3, 0.8), Vector3(0, k * PI / 4, 0.12))
			w.add_obstacle(f)
	w._lot_sign(_v(r.get_center().x, r.end.y - 1.5), "REFROIDISSEMENT · 3 PISCINES OLYMPIQUES PAR JOUR", Color(0.6, 0.9, 1.0))

func _cables(r: Rect2):
	_floor(r, U.pbr("Tiles101", 0.5, Color(0.5, 0.52, 0.58), 0.5))
	var cols := [Color(0.1, 0.1, 0.12), Color(0.9, 0.6, 0.1), Color(0.2, 0.4, 0.9), Color(0.8, 0.15, 0.15)]
	for i in 10:
		var a := _rand_in(r, 1.0)
		var b := _rand_in(r, 1.0)
		var mid := (a + b) * 0.5
		var cab := U.box(w, Vector3(0.18, 0.12, a.distance_to(b)), mid + Vector3(0, 0.06, 0), U.solid(cols[i % 4], 0.0, 0.5))
		cab.look_at_from_position(mid + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), Vector3.UP)
		cab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in int(r.size.x * r.size.y / 200.0):
		var p := _rand_in(r, 2.0)
		if w._blocked(p, 1.6): continue
		# cable drums lying on their side
		var d := U.cyl(w, 0.9, 0.9, p + Vector3(0, 0.9, 0), U.solid(Color(0.55, 0.38, 0.2), 0.0, 0.8))
		d.rotation.x = PI / 2; d.rotation.y = w.rng.randf() * TAU
		U.cyl(w, 0.65, 0.95, p + Vector3(0, 0.9, 0), U.solid(cols[i % 4], 0.0, 0.5)).rotation = d.rotation
		w.small_obstacle(p, 1.0)
		w._static_box(p + Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 1.6))
	w._lot_sign(_v(r.get_center().x, r.get_center().y), "NE PAS DÉBRANCHER (OU SI)", Color(1, 0.7, 0.3))

# ---------------------------------------------------------------- Ski resort
func _snow_mound(p: Vector3, s: float):
	var m := U.sphere(w, s, p, U.pbr("Snow010A", 0.2, Color(1.05, 1.05, 1.1), 0.5), s * 0.5)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _chalets(r: Rect2):
	var houses := ["building-type-a", "building-type-b", "building-type-c", "building-type-d", "building-type-e", "building-type-f", "building-type-g", "building-type-h"]
	var cols := maxi(1, int(r.size.x / 13.0))
	var rows := maxi(1, int(r.size.y / 13.0))
	for ix in cols:
		for iz in rows:
			var p := _v(r.position.x + (ix + 0.5) * r.size.x / cols, r.position.y + (iz + 0.5) * r.size.y / rows)
			if w._blocked(p, 4.0) or w.rng.randf() < 0.2: continue
			var h := U.place(w, U.SUB + houses[w.rng.randi() % houses.size()] + ".glb", p, w.rng.randf_range(6.5, 8.0), [0.0, PI / 2, PI, -PI / 2][w.rng.randi() % 4])
			U.detailize(h, "Plaster001", 0.4)
			var a: AABB = w.add_obstacle(h)
			# snow on the roof
			var roof := U.box(w, Vector3(a.size.x * 0.9, 0.35, a.size.z * 0.9), Vector3(a.get_center().x, a.end.y - 0.1, a.get_center().z), U.pbr("Snow010A", 0.2, Color(1.05, 1.05, 1.1), 0.5))
			roof.set_meta("airborne", true)
			_snow_mound(p + Vector3(a.size.x * 0.6, 0, 0), 1.4)
	for k in 4:
		var tp := _rand_in(r, 2.0)
		if w._blocked(tp, 1.5): continue
		U.nature(w, ["pine_tree_1", "pine_tree_2", "pine_tree_3"][k % 3], tp, w.rng.randf_range(5.0, 7.5), w.rng.randf() * TAU)
		w.small_obstacle(tp, 0.7)
	w._lot_sign(_v(r.get_center().x, r.position.y + 1.5), "CHALETS · RÉSIDENCES SECONDAIRES (TERTIAIRES)", Color(1, 0.9, 0.7))

func _sapins(r: Rect2):
	for i in int(r.size.x * r.size.y / 55.0):
		var p := _rand_in(r, 1.5)
		if w._blocked(p, 1.3): continue
		U.nature(w, ["pine_tree_1", "pine_tree_2", "pine_tree_3", "pine_tree_4", "pine_tree_5"][w.rng.randi() % 5], p, w.rng.randf_range(4.5, 9.0), w.rng.randf() * TAU)
		w.small_obstacle(p, 0.7)
		if w.rng.randf() < 0.4: _snow_mound(p + Vector3(w.rng.randf_range(-1.5, 1.5), 0, w.rng.randf_range(-1.5, 1.5)), w.rng.randf_range(0.6, 1.2))
	for i in 3:
		var p := _rand_in(r, 2.0)
		if w._blocked(p, 1.0): continue
		U.nature(w, ["rock_1", "rock_3", "rock_5"][i], p, w.rng.randf_range(1.0, 2.0), w.rng.randf() * TAU)
		w.small_obstacle(p, 0.9)

func _telesiege(r: Rect2):
	var along_x := r.size.x >= r.size.y
	var length := (r.size.x if along_x else r.size.y) - 4.0
	var c := _v(r.get_center().x, r.get_center().y)
	var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var lat := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var steel := U.solid(Color(0.5, 0.52, 0.56), 0.0, 0.4, 0.8)
	var n := maxi(2, int(length / 12.0) + 1)
	var top := 10.5
	for i in n:
		var p := c + dir * (-length * 0.5 + length * i / (n - 1))
		U.cyl(w, 0.3, top, p + Vector3(0, top / 2.0, 0), steel)
		U.box(w, Vector3(0.3, 0.3, 4.0) if along_x else Vector3(4.0, 0.3, 0.3), p + Vector3(0, top, 0), steel)
		w.small_obstacle(p, 0.6)
		w._static_box(p + Vector3(0, top / 2.0, 0), Vector3(0.6, top, 0.6))
	for sd in [-1.0, 1.0]:
		var cab := U.box(w, Vector3(length, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, length), c + Vector3(0, top - 0.1, 0) + lat * sd * 1.8, U.solid(Color(0.15, 0.15, 0.15)))
		cab.set_meta("airborne", true)
		# chairs hanging from the cable, empty: the rich went home
		var k := -length * 0.5 + 3.0
		while k < length * 0.5 - 2.0:
			var cp: Vector3 = c + dir * k + lat * sd * 1.8
			var hang := U.box(w, Vector3(0.05, 1.6, 0.05), cp + Vector3(0, top - 0.9, 0), U.solid(Color(0.2, 0.2, 0.22)))
			hang.set_meta("airborne", true)
			var seat := U.box(w, Vector3(1.4, 0.12, 0.6) if along_x else Vector3(0.6, 0.12, 1.4), cp + Vector3(0, top - 1.75, 0), U.solid(Color(0.85, 0.12, 0.12)))
			seat.set_meta("airborne", true)
			k += 6.0
	# stations at both ends
	for sd in [-1.0, 1.0]:
		var sp: Vector3 = c + dir * sd * (length * 0.5 + 0.5)
		var st := U.box(w, Vector3(3.0, 3.2, 5.0) if along_x else Vector3(5.0, 3.2, 3.0), sp + Vector3(0, 1.6, 0), U.solid(Color(0.55, 0.35, 0.22), 0.0, 0.8))
		w.add_obstacle(st)
		U.box(w, Vector3(3.4, 0.4, 5.4) if along_x else Vector3(5.4, 0.4, 3.4), sp + Vector3(0, 3.4, 0), U.pbr("Snow010A", 0.2, Color(1.05, 1.05, 1.1), 0.5))
	w._lot_sign(c + lat * 5.0, "TÉLÉSIÈGE · FORFAIT 900 € LA JOURNÉE", Color(1, 1, 1))

# ---------------------------------------------------------------- Rocket base
func _pas_de_tir(r: Rect2):
	var c := _v(r.get_center().x, r.get_center().y)
	U.cyl(w, minf(r.size.x, r.size.y) * 0.42, 0.3, c + Vector3(0, 0.15, 0), U.pbr("Concrete034", 0.2, Color(0.75, 0.75, 0.78), 0.8))
	var root := Node3D.new(); w.add_child(root); root.position = c
	var white := U.solid(Color(0.95, 0.95, 0.95), 0.1, 0.3, 0.6)
	var black := U.solid(Color(0.08, 0.08, 0.1), 0.0, 0.4)
	var h := 26.0
	U.cyl(root, 2.2, h, Vector3(0, h / 2.0 + 2.0, 0), white)
	var nose := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 2.2; cm.height = 6.0
	nose.mesh = cm; nose.material_override = white; nose.position = Vector3(0, h + 2.0 + 3.0, 0); root.add_child(nose)
	U.cyl(root, 2.25, 1.2, Vector3(0, h * 0.7, 0), black)
	U.cyl(root, 1.6, 2.0, Vector3(0, 1.0, 0), black)
	for k in 4:
		var f := U.box(root, Vector3(0.25, 4.0, 2.4), Vector3(0, 3.5, 0), black, Vector3(0, k * PI / 2, 0))
		f.position = Vector3(cos(k * PI / 2) * 2.6, 3.5, sin(k * PI / 2) * 2.6)
		f.rotation.y = -k * PI / 2
	for sd in [1.0, -1.0]:
		# painted vertically along the hull, narrow enough to stay on the curve
		var l := U.label(root, "E\nX\nI\nT", Vector3(0, h * 0.55, sd * 2.22), 300, Color(0.1, 0.1, 0.12), Color(0, 0, 0, 0), false, U.font_main)
		l.rotation.y = 0.0 if sd > 0 else PI; l.outline_size = 0; l.pixel_size = 0.012; l.line_spacing = -40
		U.fit_label(l, 1.6, h * 0.55)
	w.obstacles.append(Rect2(c.x - 3.4, c.z - 3.4, 6.8, 6.8))
	w._static_box(c + Vector3(0, h / 2.0, 0), Vector3(5.0, h, 5.0))
	w.register_occluder(root)
	# service tower next to it, with arms reaching the rocket
	var tp := c + Vector3(8.0, 0, 0)
	var tw: Node3D = w._launch_tower(tp, h + 6.0)
	w.obstacles.append(Rect2(tp.x - 4.4, tp.z - 4.4, 8.8, 8.8))
	w.register_occluder(tw)
	for y in [h * 0.45, h * 0.8]:
		U.box(w, Vector3(3.6, 0.5, 0.8), c + Vector3(3.9, y, 0), U.solid(Color(0.78, 0.15, 0.1), 0.0, 0.5, 0.6)).set_meta("airborne", true)
	w._lot_sign(c + Vector3(0, 0, minf(r.size.y * 0.45, 14.0)), "PAS DE TIR · ALLER SIMPLE POUR MILLIARDAIRES", Color(1, 0.6, 0.3))

func _carburant(r: Rect2):
	_floor(r, U.pbr("Concrete034", 0.2, Color(0.9, 0.88, 0.85), 0.8))
	var n := maxi(2, int(r.size.x * r.size.y / 220.0))
	var pipe := U.solid(Color(0.85, 0.85, 0.82), 0.0, 0.3, 0.8)
	var last := Vector3.INF
	for i in n:
		var p := _rand_in(r, 4.5)
		if w._blocked(p, 3.5): continue
		var t := U.place(w, U.IND + ["detail-tank-large", "detail-tank"][i % 2] + ".glb", p, w.rng.randf_range(5.0, 9.0), w.rng.randf() * TAU)
		w.add_obstacle(t)
		if last != Vector3.INF:
			var mid := (p + last) * 0.5 + Vector3(0, 0.4, 0)
			var pp := U.box(w, Vector3(0.3, 0.3, p.distance_to(last)), mid, pipe)
			pp.look_at_from_position(mid, last + Vector3(0, 0.4, 0), Vector3.UP)
		last = p
	w._lot_sign(_v(r.get_center().x, r.position.y + 1.5), "KÉROSÈNE · 300 TONNES PAR SELFIE", Color(1, 0.75, 0.2))

func _antennes(r: Rect2):
	_floor(r, U.pbr("Concrete034", 0.2, Color(0.85, 0.85, 0.88), 0.8))
	var white := U.solid(Color(0.92, 0.92, 0.94), 0.0, 0.4, 0.4)
	for i in maxi(2, int(r.size.x * r.size.y / 240.0)):
		var p := _rand_in(r, 4.0)
		if w._blocked(p, 3.5): continue
		var d := Node3D.new(); w.add_child(d); d.position = p; d.rotation.y = w.rng.randf() * TAU
		U.cyl(d, 0.35, 4.0, Vector3(0, 2.0, 0), U.solid(Color(0.4, 0.4, 0.42), 0.0, 0.4, 0.8))
		var dish := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 3.0; cm.bottom_radius = 0.4; cm.height = 1.0
		dish.mesh = cm; dish.material_override = white; dish.position = Vector3(0, 4.6, 0); dish.rotation.x = -0.7; d.add_child(dish)
		U.cyl(d, 0.05, 2.4, Vector3(0, 5.4, 0.6), U.solid(Color(0.2, 0.2, 0.22))).rotation.x = -0.7
		w.small_obstacle(p, 1.0)
		w._static_box(p + Vector3(0, 2.0, 0), Vector3(0.8, 4.0, 0.8))
	var hut := U.box(w, Vector3(5.0, 3.0, 4.0), _v(r.end.x - 4.0, r.end.y - 3.5) + Vector3(0, 1.5, 0), U.solid(Color(0.85, 0.85, 0.8), 0.0, 0.7))
	w.add_obstacle(hut)
	w._lot_sign(_v(r.get_center().x, r.position.y + 1.5), "CONTRÔLE DE MISSION · ON VOUS ÉCOUTE", Color(0.7, 0.9, 1.0))

# ---------------------------------------------------------------- Grand Soir
func _defile(r: Rect2):
	_floor(r, U.pbr("PavingStones138", 0.5, Color(0.9, 0.8, 0.78), 0.6))
	var along_x := r.size.x >= r.size.y
	var length := (r.size.x if along_x else r.size.y) - 8.0
	var c := _v(r.get_center().x, r.get_center().y)
	var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var lat := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var rot := atan2(dir.x, dir.z)
	var red := U.solid(Color(0.78, 0.06, 0.08), 0.0, 0.7)
	var gold := U.solid(Color(1.0, 0.8, 0.3), 0.4, 0.3, 1.0)
	var k := -length * 0.5 + 3.0
	var i := 0
	while k < length * 0.5 - 2.0:
		var p := c + dir * k
		var v := U.place(w, U.CAR + ["tractor", "truck-flat", "truck", "tractor-shovel"][i % 4] + ".glb", p, 2.8, rot)
		var a: AABB = w.add_obstacle(v)
		# parade float on the vehicle: a giant star or a worker's fist of papier-mâché
		var top := Vector3(p.x, a.end.y, p.z)
		if i % 2 == 0:
			var st := Label3D.new(); st.text = "★"; st.font = load("res://fonts/Symbols.ttf"); st.font_size = 256; st.pixel_size = 0.014
			st.modulate = Color(1, 0.8, 0.25); st.outline_size = 0; st.position = top + Vector3(0, 1.8, 0); st.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			w.add_child(st)
			U.box(w, Vector3(0.15, 1.2, 0.15), top + Vector3(0, 0.6, 0), gold)
		else:
			U.box(w, Vector3(2.0, 1.4, 0.1), top + Vector3(0, 0.9, 0), red, Vector3(0, rot + PI / 2, 0))
			U.poster(w, U.propaganda_tex(i), top + Vector3(0, 0.95, 0) + lat * 0.07, Vector2(1.0, 1.4), rot + PI / 2)
		k += 7.0; i += 1
	# crowd barriers along the route
	for sd in [-1.0, 1.0]:
		var bp: Vector3 = c + lat * sd * 3.2
		U.box(w, Vector3(length, 0.9, 0.08) if along_x else Vector3(0.08, 0.9, length), bp + Vector3(0, 0.45, 0), U.solid(Color(0.75, 0.75, 0.78), 0.0, 0.3, 0.8))
	w._lot_sign(c + lat * 6.0, "DÉFILÉ DU GRAND SOIR · ENTRÉE LIBRE", Color(1, 0.85, 0.3))
