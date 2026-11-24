extends Node3D
# Set dressing and ambient life for each zone: street furniture, zone-specific props,
# and animated details (waving flags, pigeons that fly off, a blimp with a slogan,
# scrolling stock tickers, chimney smoke, neon signs, spinning signs).
# Purely visual: only the larger props become obstacles.

var w                      # world
var rng: RandomNumberGenerator
var flags: Array = []      # {n, ph}
var pigeons: Array = []    # {n, home, fly, v, t}
var spinners: Array = []   # {n, sp}
var tickers: Array = []    # {l, x0, w, sp}
var screens: Array = []    # Label3D (values change)
var smokes: Array = []     # {p, t}
var blinkers: Array = []   # {n, ph}
var blimp: Node3D
var blimp_a := 0.0
var t := 0.0
var scr_t := 0.0
var smoke_t := 0.0
var player: Node3D = null
var snow: CPUParticles3D
var fw_t := 2.0
var drones: Array = []

func build(world):
	w = world
	rng = world.rng
	var id: String = w.template.get("id", "hypermarche")
	var fs: Array = w.far_smokes.duplicate()
	fs.shuffle()
	smokes.append_array(fs.slice(0, 10))       # a dozen plumes is plenty (each one is a stream of sprites)
	_street_furniture()
	_flags(int(10 * w.area_k * (2.5 if id == "grandsoir" else 1.0)))
	_pigeon_flocks(int(5 * w.area_k))
	if w.template.get("blimp", "x") != "": _blimp(id)
	_hoardings(id)
	match id:
		"hypermarche": _hypermarche()
		"quartier": _quartier()
		"bourse": _bourse()
		"paradis": _paradis()
		"startup": _startup()
		"datacenter": _datacenter()
		"ski": _ski()
		"fusee": _fusee()
		"grandsoir": _grandsoir()
		"berlin": _berlin()

# ---------------------------------------------------------------- shared
# a free spot, or INF when the map has no room left (the prop is then skipped, never stacked)
func _spot(pad := 2.0, min_start := 10.0) -> Vector3:
	for i in 200:
		var b: Rect2 = w.bounds
		var p := Vector3(rng.randf_range(b.position.x + 4, b.end.x - 4), 0, rng.randf_range(b.position.y + 4, b.end.y - 4))
		if _free(p, pad) and p.distance_to(w.player_start) >= min_start and not _near_decor(p, pad): return p
	return Vector3.INF

var _placed: Array = []      # [pos, radius] of decor already placed (small props are not world obstacles)
func _near_decor(p: Vector3, pad: float) -> bool:
	for q in _placed:
		if p.distance_to(q[0]) < pad + q[1]: return true
	return false

func _claim(p: Vector3, r: float):
	_placed.append([p, r])

func _edge_points(r: Rect2, step: float, out := 1.6) -> Array:
	var g := r.grow(out)
	var pts := []
	var x := g.position.x + step * 0.5
	while x < g.end.x:
		pts.append([Vector3(x, 0, g.position.y), 0.0]); pts.append([Vector3(x, 0, g.end.y), PI]); x += step
	var z := g.position.y + step * 0.5
	while z < g.end.y:
		pts.append([Vector3(g.position.x, 0, z), PI / 2]); pts.append([Vector3(g.end.x, 0, z), -PI / 2]); z += step
	return pts

func _free(p: Vector3, pad: float) -> bool:
	return w.inside(p) and not w._blocked(p, pad)

func _street_furniture():
	var bench := U.solid(Color(0.45, 0.3, 0.18), 0.0, 0.8)
	var iron := U.solid(Color(0.15, 0.15, 0.17), 0.0, 0.4, 0.7)
	var red := U.solid(Color(0.75, 0.08, 0.1), 0.0, 0.5)
	for l in w.lots:
		var r: Rect2 = l[0]
		for e in _edge_points(r, 9.0):
			if rng.randf() > 0.28: continue
			var p: Vector3 = e[0]
			if not _free(p, 1.0) or _near_decor(p, 1.0): continue
			_claim(p, 1.0)
			w.small_obstacle(p, 0.5)
			var war: bool = w.template.get("id", "") == "berlin"
			match rng.randi() % 5:
				0, 1:  # bench (in Berlin: charred, knocked over, missing its back)
					var b := U.place(self, U.PROPS + ("k_graveyard_kit/bench-damaged.glb" if war else "kk_city_builder/bench.gltf"), p, 0.7 if war else 0.55, e[1] + PI)
					if war: b.rotation.z = rng.randf_range(-0.4, 0.4)
				2:  # bin (in Berlin: a dented oil drum lying on its side)
					if war:
						var bn := U.place(self, U.PROPS + "kk_resource_bits/Fuel_A_Barrel_Dirty.gltf", p, 1.0, rng.randf() * TAU)
						bn.rotation = Vector3(PI / 2, rng.randf() * TAU, 0); bn.position.y += 0.3
					else:
						U.place(self, U.PROPS + "kk_city_builder/" + ["trash_A", "trash_B"][rng.randi() % 2] + ".gltf", p, 1.0, e[1])
				3:  # hydrant
					U.place(self, U.PROPS + "kk_city_builder/firehydrant.gltf", p, 0.8, rng.randf() * TAU)
				4:  # sign (in Berlin: bent by the blast)
					var sg := U.place(self, U.CR + ["road-sign-stop", "road-sign-warning", "road-sign-street"][rng.randi() % 3] + ".glb", p, 2.4, e[1])
					if war: sg.rotation.z = rng.randf_range(0.35, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0)
	# manholes, puddles and litter on the ground
	var dark := U.solid(Color(0.18, 0.18, 0.2), 0.0, 0.5, 0.6)
	var puddle := U.solid(Color(0.3, 0.38, 0.48, 0.55), 0.0, 0.05, 0.3)
	for i in 40:
		var p := _spot(0.5, 3.0)
		if p == Vector3.INF: continue
		_claim(p, 0.5)
		match i % 3:
			0:
				U.cyl(self, 0.5, 0.03, p + Vector3(0, 0.015, 0), dark)
				if i % 9 == 0 and w.template.get("id", "") != "ski": _steam(p)      # a manhole breathing steam
			1:
				var pd := U.cyl(self, rng.randf_range(0.8, 1.8), 0.02, p + Vector3(0, 0.012, 0), puddle)
				pd.scale = Vector3(1, 1, rng.randf_range(0.5, 1.0))
				pd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			2:
				for k in 3:
					var paper := U.box(self, Vector3(0.3, 0.01, 0.22), p + Vector3(rng.randf_range(-1, 1), 0.01, rng.randf_range(-1, 1)), U.solid(Color(0.92, 0.9, 0.85)), Vector3(0, rng.randf() * TAU, 0))
					paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# electricity poles and wires along the side walls
	var b: Rect2 = w.bounds
	var z := b.position.y + 19.0       # street lights sit at +10 every 18 m: keep the poles in between
	while z < b.end.y - 6.0:
		for x in [b.position.x + 1.5, b.end.x - 1.5]:
			var p := Vector3(x, 0, z)
			if not w._in_cut(p) and not w._blocked(p, 2.0):
				U.place(self, U.CR + "electricity-pole.glb", p, 7.0, 0.0)
				w.small_obstacle(p, 0.5)
		z += 36.0

func _flags(n: int):
	var pole := U.solid(Color(0.75, 0.75, 0.78), 0.0, 0.3, 0.9)
	var red := U.solid(Color(0.78, 0.06, 0.08), 0.0, 0.9)
	var sym: Font = load("res://fonts/Symbols.ttf")
	for i in n:
		var p := _spot(1.0, 8.0)
		if p == Vector3.INF: continue
		_claim(p, 1.0)
		var root := Node3D.new(); add_child(root); root.position = p
		# kept below the camera height (7.5 m) so a flag never blocks the view
		U.cyl(root, 0.05, 4.4, Vector3(0, 2.2, 0), pole)
		U.sphere(root, 0.1, Vector3(0, 4.45, 0), U.solid(Color(1, 0.8, 0.2), 0.5, 0.3, 1.0))
		var fl := Node3D.new(); root.add_child(fl); fl.position = Vector3(0, 3.85, 0)
		U.flag_cloth(fl, Vector2(1.5, 0.95), Vector3(0, 0, 0.04), "res://assets/textures/flag_soviet.png", rng.randf() * 8.0)      # waving cloth (shader)
		fl.rotation.y = rng.randf() * TAU
		flags.append({"n": fl, "ph": rng.randf() * TAU, "base": fl.rotation.y})

func _pigeon_flocks(n: int):
	var grey := U.solid(Color(0.55, 0.56, 0.6) if w.template.get("id", "") != "paradis" else Color(0.95, 0.95, 0.95), 0.0, 0.9)
	var beak := U.solid(Color(0.9, 0.6, 0.2))
	for f in n:
		var c := _spot(1.0, 12.0)
		if c == Vector3.INF: continue
		_claim(c, 1.0)
		for i in 5 + rng.randi() % 5:
			var b := Node3D.new(); add_child(b)
			var home := c + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
			b.position = home
			U.sphere(b, 0.13, Vector3(0, 0.14, 0), grey, 0.2)
			U.sphere(b, 0.07, Vector3(0, 0.26, 0.1), grey)
			U.box(b, Vector3(0.03, 0.03, 0.06), Vector3(0, 0.25, 0.18), beak)
			b.rotation.y = rng.randf() * TAU
			pigeons.append({"n": b, "home": home, "fly": false, "v": Vector3.ZERO, "t": rng.randf() * 3.0})

func _blimp(id: String):
	blimp = Node3D.new(); add_child(blimp)
	blimp.set_meta("airborne", true)
	var body := U.sphere(blimp, 3.0, Vector3.ZERO, U.solid(Color(0.85, 0.85, 0.82), 0.0, 0.5), 3.0)
	body.scale = Vector3(1, 1, 3.2)
	for k in 4:
		var fin := U.box(blimp, Vector3(0.15, 2.2, 1.8), Vector3(0, 0, -8.5), U.solid(Color(0.75, 0.08, 0.1)))
		fin.rotation.z = k * PI / 2
	U.box(blimp, Vector3(1.2, 0.8, 2.4), Vector3(0, -3.3, 0), U.solid(Color(0.3, 0.3, 0.32)))
	var txt: String = w.template.get("blimp", "ACHETEZ")
	# the slogan is painted on a banner strapped along each flank (the hull is round, the banner is flat)
	for sd in [-1.0, 1.0]:
		U.box(blimp, Vector3(0.08, 2.4, 11.0), Vector3(sd * 2.98, -0.2, 0), U.solid(Color(0.95, 0.93, 0.86), 0.0, 0.8))
		for zz in [-5.3, 5.3]: U.box(blimp, Vector3(0.1, 2.6, 0.12), Vector3(sd * 3.0, -0.2, zz), U.solid(Color(0.75, 0.08, 0.1)))
		var l := Label3D.new(); l.text = txt; l.font = U.font_main; l.font_size = 200; l.pixel_size = 0.02
		l.modulate = Color(0.75, 0.08, 0.1); l.outline_size = 0; l.position = Vector3(sd * 3.03, -0.2, 0); l.rotation.y = sd * PI / 2
		l.shaded = true; l.double_sided = false
		blimp.add_child(l)
		U.fit_label(l, 10.2, 2.0)

# ---------------------------------------------------------------- zone 1: hypermarket
func _hypermarche():
	# shopping-cart corrals: a neat row, spaced by the cart's measured width
	for i in 6:
		var p := _spot(3.5)
		if p == Vector3.INF: continue
		_claim(p, 3.5)
		var along_x := rng.randf() < 0.5
		var step := 0.0
		for k in 4:
			var cp := p + (Vector3(step, 0, 0) if along_x else Vector3(0, 0, step))
			var cart := U.place(self, U.SHOP + "shopping-cart.glb", cp, 1.1, 0.0 if along_x else PI / 2)
			var ca := U.world_aabb(cart)
			w.small_obstacle(ca.get_center(), 0.6)
			step += (ca.size.x if along_x else ca.size.z) + 0.12
	# delivery and garbage trucks
	for i in 4:
		var p := _spot(4.0)
		if p == Vector3.INF: continue
		_claim(p, 4.0)
		var tr := U.place(self, U.CAR + ["delivery", "garbage-truck", "truck", "van"][i % 4] + ".glb", p, 2.6, rng.randf() * TAU)
		w.add_obstacle(tr)
	# pallets of goods with price signs
	var prices := ["-50 %", "PROMO", "2 + 1 OFFERT", "9,99", "DERNIÈRE CHANCE", "-70 %"]
	for i in 8:
		var p := _spot(2.0)
		if p == Vector3.INF: continue
		_claim(p, 2.0)
		var pal := U.box(self, Vector3(1.6, 0.15, 1.2), p + Vector3(0, 0.08, 0), U.solid(Color(0.6, 0.45, 0.25)))
		var goods := U.place(self, U.SHOP + ["display-cans", "display-fruit", "display-bread", "shelf-boxes"][rng.randi() % 4] + ".glb", p + Vector3(0, 0.15, 0), 1.0, 0.0)
		var ga := U.world_aabb(goods)
		var fit := minf(1.5 / maxf(ga.size.x, 0.01), 1.1 / maxf(ga.size.z, 0.01))
		if fit < 1.0:
			goods.scale *= fit
			goods.position += Vector3(p.x, 0, p.z) - Vector3(U.world_aabb(goods).get_center().x, 0, U.world_aabb(goods).get_center().z)
		w.add_obstacle(goods, false, 0.4)
		var sg := U.box(self, Vector3(1.5, 0.7, 0.05), p + Vector3(0, 1.75, 0), U.solid(Color(1, 0.85, 0.1)))
		U.cyl(self, 0.03, 1.45, p + Vector3(0.0, 0.72, -0.06), U.solid(Color(0.3, 0.3, 0.3)))
		var l := U.label(self, prices[i % prices.size()], p + Vector3(0, 1.75, 0.04), 52, Color(0.8, 0.05, 0.05), Color(0, 0, 0, 0), false)
		l.pixel_size = 0.006
		l.width = 1.4 / l.pixel_size; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.outline_size = 0
		w.add_obstacle(pal, false, 0.3)
	# café terraces under parasols
	for i in 4:
		var p := _spot(3.0)
		if p == Vector3.INF: continue
		_claim(p, 3.0)
		U.place(self, U.CC + ["detail-parasol-a", "detail-parasol-b"][i % 2] + ".glb", p, 2.6, rng.randf() * TAU)
		w.small_obstacle(p, 1.4)
		for k in 2:
			var tp := p + Vector3(k * 1.4 - 0.7, 0, 0.6)
			U.cyl(self, 0.4, 0.05, tp + Vector3(0, 0.75, 0), U.solid(Color(0.9, 0.9, 0.88)))
			U.cyl(self, 0.04, 0.75, tp + Vector3(0, 0.37, 0), U.solid(Color(0.2, 0.2, 0.2)))
	_mascot()
	# chimney smoke from the industrial backdrop
	for i in 3:
		var b: Rect2 = w.bounds
		smokes.append({"p": Vector3(rng.randf_range(b.position.x, b.end.x), 14.0, b.position.y - 22.0), "t": 0.0})

# ---------------------------------------------------------------- zone 2: business district
func _quartier():
	# planters with small trees, coffee kiosks, taxis waiting
	for i in 14:
		var p := _spot(1.5)
		if p == Vector3.INF: continue
		_claim(p, 1.5)
		var pl := U.box(self, Vector3(1.4, 0.6, 1.4), p + Vector3(0, 0.3, 0), U.pbr("Concrete034", 0.6, Color(0.95, 0.95, 0.95)))
		U.nature(self, ["bush_large", "bush_flowers", "plant_flowers", "bush_large_flowers"][rng.randi() % 4], p + Vector3(0, 0.6, 0), 1.3, rng.randf() * TAU)
		w.add_obstacle(pl, true, 0.1)
	for i in 3:
		var p := _spot(3.0)
		if p == Vector3.INF: continue
		_claim(p, 3.0)
		var k := Node3D.new(); add_child(k); k.position = p; k.rotation.y = rng.randf() * TAU
		U.box(k, Vector3(2.4, 2.2, 1.6), Vector3(0, 1.1, 0), U.solid(Color(0.15, 0.35, 0.3)))
		U.box(k, Vector3(2.8, 0.15, 2.0), Vector3(0, 2.3, 0.2), U.solid(Color(0.9, 0.9, 0.85)))
		U.label(k, "CAFÉ À 9 €", Vector3(0, 2.6, 0.81), 80, Color(1, 1, 1), Color(0, 0, 0, 1), false)
		w.add_obstacle(k)
	for i in 3:
		var p := _spot(6.5)
		if p == Vector3.INF: continue
		_claim(p, 6.5)
		var rot := rng.randf() * TAU
		for j in 3:
			var c := U.place(self, U.CAR + "taxi.glb", p + Vector3(cos(rot), 0, sin(rot)) * (j - 1) * 4.4, 1.5, rot + PI / 2)
			w.add_obstacle(c)
	# abandoned office chairs and paper stacks
	var chair := U.solid(Color(0.12, 0.12, 0.14), 0.0, 0.5)
	for i in 14:
		var p := _spot(0.8)
		if p == Vector3.INF: continue
		_claim(p, 0.8)
		var c := Node3D.new(); add_child(c); c.position = p; c.rotation = Vector3(0, rng.randf() * TAU, 0 if rng.randf() < 0.7 else PI / 2.2)
		U.box(c, Vector3(0.5, 0.08, 0.5), Vector3(0, 0.5, 0), chair)
		U.box(c, Vector3(0.5, 0.6, 0.08), Vector3(0, 0.85, -0.22), chair)
		U.cyl(c, 0.04, 0.45, Vector3(0, 0.25, 0), U.solid(Color(0.6, 0.6, 0.62), 0.0, 0.3, 0.9))
	# rotating corporate logos on poles and a giant scrolling billboard
	for i in 4:
		var p := _spot(1.0, 14.0)
		if p == Vector3.INF: continue
		_claim(p, 1.0)
		U.cyl(self, 0.1, 3.6, p + Vector3(0, 1.8, 0), U.solid(Color(0.7, 0.7, 0.72), 0.0, 0.3, 0.9))
		var cube := U.box(self, Vector3(1.2, 1.2, 1.2), p + Vector3(0, 4.2, 0), U.solid(Color(0.2, 0.5, 0.9), 0.8, 0.3))
		spinners.append({"n": cube, "sp": 0.8})
	_billboard("SYNERGIE · DISRUPTION · AGILITÉ · BURN-OUT · TEAM BUILDING · SÉMINAIRE · KPI · ", Color(0.4, 0.8, 1.0))
	# construction lights blink on the building sites
	for pl in w.plateaus:
		if pl["kind"] == "container": continue
		var r: Rect2 = pl["rect"]
		for k in 2:
			var lp := Vector3(r.position.x + 0.4 + k * (r.size.x - 0.8), pl["h"] + 0.3, r.position.y + 0.4)
			var bl := U.sphere(self, 0.15, lp, U.solid(Color(1, 0.6, 0.1), 4.0))
			blinkers.append({"n": bl, "ph": rng.randf() * TAU})

# ---------------------------------------------------------------- zone 3: stock exchange (night)
func _bourse():
	# red carpets, velvet ropes, luxury cars and police
	for i in 4:
		var p := _spot(3.0)
		if p == Vector3.INF: continue
		_claim(p, 3.0)
		var rot := rng.randf() * PI
		var carpet := U.box(self, Vector3(2.0, 0.03, 12.0), p + Vector3(0, 0.015, 0), U.solid(Color(0.6, 0.05, 0.08), 0.0, 0.9), Vector3(0, rot, 0))
		carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 5:
			for sd in [-1.0, 1.0]:
				var off := Vector3(sd * 1.3, 0, -5.0 + k * 2.5).rotated(Vector3.UP, rot)
				U.cyl(self, 0.05, 0.9, p + off + Vector3(0, 0.45, 0), U.solid(Color(1, 0.8, 0.3), 0.3, 0.3, 1.0))
	for i in 6:
		var p := _spot(4.0)
		if p == Vector3.INF: continue
		_claim(p, 4.0)
		var c := U.place(self, U.CAR + ["suv-luxury", "sedan-sports", "police", "suv-luxury", "sedan"][i % 5] + ".glb", p, 1.5, rng.randf() * TAU)
		w.add_obstacle(c)
	_bull()
	# piles of banknotes
	var green := U.solid(Color(0.35, 0.6, 0.35), 0.0, 0.8)
	for i in 12:
		var p := _spot(1.2)
		if p == Vector3.INF: continue
		_claim(p, 1.2)
		for k in rng.randi_range(2, 6):
			U.box(self, Vector3(0.7, 0.18, 0.35), p + Vector3(rng.randf_range(-0.1, 0.1), 0.09 + k * 0.18, rng.randf_range(-0.1, 0.1)), green, Vector3(0, rng.randf() * 0.5, 0))
	# neon lamp posts (the only lit things at night) and a scrolling ticker band
	var neon_cols := [Color(0.2, 1.0, 0.5), Color(1.0, 0.2, 0.3), Color(0.3, 0.6, 1.0)]
	var lights := 0
	for i in 16:
		var p := _spot(1.0, 6.0)
		if p == Vector3.INF: continue
		_claim(p, 1.0)
		var col: Color = neon_cols[i % 3]
		U.cyl(self, 0.06, 4.0, p + Vector3(0, 2.0, 0), U.solid(Color(0.15, 0.15, 0.17), 0.0, 0.3, 0.8))
		var bl := U.sphere(self, 0.25, p + Vector3(0, 4.1, 0), U.solid(col, 5.0))
		if lights < 8:
			var ol := OmniLight3D.new(); ol.light_color = col; ol.omni_range = 9.0; ol.light_energy = 1.2
			ol.position = p + Vector3(0, 3.8, 0); add_child(ol); lights += 1
		if i % 4 == 0: blinkers.append({"n": bl, "ph": rng.randf() * TAU})
	_billboard("CAC ▲ 3,2 %   DOW ▲ 1,8 %   PAIN ▼ 99 %   SALAIRES ▼ 12 %   DIVIDENDES ▲ 47 %   YACHTS ▲ 8 %   ESPOIR ▼ 100 %   ", Color(0.3, 1.0, 0.45))
	_billboard("ACHETEZ BAS · VENDEZ TOUT · LICENCIEZ · RECOMMENCEZ · ", Color(1.0, 0.3, 0.3))
	# extra animated screens on the trading floor
	for l in w.find_children("*", "Label3D", false, false):
		var lab: Label3D = l
		if lab.text.ends_with("%") and (lab.text.begins_with("+") or lab.text.begins_with("-")): screens.append(lab)

func _billboard(text: String, col: Color):
	var b: Rect2 = w.bounds
	var x := rng.randf_range(b.position.x + 20.0, b.end.x - 20.0)
	var z := b.position.y - 7.0
	var frame := Node3D.new(); add_child(frame); frame.position = Vector3(x, 8.0, z)
	U.box(frame, Vector3(22.0, 2.4, 0.3), Vector3.ZERO, U.solid(Color(0.04, 0.04, 0.05)))
	for sx in [-10.0, 10.0]: U.box(self, Vector3(0.4, 8.0, 0.4), Vector3(x + sx, 4.0, z), U.solid(Color(0.3, 0.3, 0.32), 0.0, 0.3, 0.8))
	# marquee: a fixed window of characters shifted one step at a time (no text spills off the board)
	var l := Label3D.new(); l.font = U.font_main; l.font_size = 160; l.pixel_size = 0.011
	l.modulate = col; l.outline_size = 0; l.position = Vector3(0, 0, 0.2); l.shaded = false
	frame.add_child(l)
	tickers.append({"l": l, "text": text, "i": 0, "acc": 0.0, "n": 26})
	l.text = text.substr(0, 26)

# ---------------------------------------------------------------- animation
func _process(d: float):
	t += d
	if player == null:
		var g = get_parent().get_parent() if get_parent() else null
		if g and "player" in g and g.player: player = g.player
	for f in flags:
		var fl: Node3D = f["n"]
		fl.rotation.y = f["base"] + sin(t * 1.3 + f["ph"]) * 0.35
		fl.rotation.x = sin(t * 3.1 + f["ph"]) * 0.06
	for s in spinners:
		var n: Node3D = s["n"]
		if s.get("sway", false): n.rotation.z = sin(t * 1.1) * 0.08; n.rotation.x = sin(t * 0.7) * 0.05
		else: n.rotation.y += s["sp"] * d
	for dr in drones:
		var dn: Node3D = dr["n"]
		dn.position.y = dr["y"] + sin(t * 2.0 + dr["ph"]) * 0.35
		dn.rotation.y += d * 0.6
	for b in blinkers:
		(b["n"] as Node3D).visible = sin(t * 4.0 + b["ph"]) > -0.2
	for tk in tickers:
		tk["acc"] += d
		if tk["acc"] >= 0.13:
			tk["acc"] = 0.0
			var txt: String = tk["text"]
			tk["i"] = (int(tk["i"]) + 1) % txt.length()
			(tk["l"] as Label3D).text = (txt + txt).substr(tk["i"], tk["n"])
	scr_t -= d
	if scr_t <= 0.0 and not screens.is_empty():
		scr_t = 1.5
		for i in 3:
			var lab: Label3D = screens[rng.randi() % screens.size()]
			var up := rng.randf() < 0.5
			lab.text = ("+%d %%" if up else "-%d %%") % rng.randi_range(1, 99)
			lab.modulate = Color(0.3, 1, 0.4) if up else Color(1, 0.25, 0.2)
	if blimp:
		blimp_a += d * 0.035
		var c: Vector2 = w.bounds.get_center()
		var rad: float = w.bounds.size.x * 0.45
		blimp.position = Vector3(c.x + cos(blimp_a) * rad, 30.0 + sin(t * 0.3) * 1.5, c.y + sin(blimp_a) * rad)
		blimp.rotation.y = -blimp_a
	if smoke_t == 0.0:
		smoke_t = 1.0
		_smoke_columns()
	_update_pigeons(d)
	if snow and player:
		snow.global_position = player.global_position + Vector3(0, 14.0, -4.0)
	if w.template.get("id", "") == "berlin": _berlin_tick(d)
	if w.template.get("fireworks", false):
		fw_t -= d
		if fw_t <= 0.0:
			fw_t = rng.randf_range(1.2, 3.0)
			_firework()

func _update_pigeons(d: float):
	var pp: Vector3 = player.global_position if player else Vector3(1e6, 0, 0)
	for pg in pigeons:
		var n: Node3D = pg["n"]
		if pg["fly"]:
			pg["t"] -= d
			n.position += pg["v"] * d
			n.rotation.z = sin(t * 30.0) * 0.4
			if pg["t"] <= 0.0 and pp.distance_to(pg["home"]) > 12.0:
				pg["fly"] = false
				n.position = pg["home"] + Vector3(0, 12, 0)
		else:
			if n.position.y > 0.0:
				n.position.y = maxf(0.0, n.position.y - d * 4.0)
				n.position.x = move_toward(n.position.x, pg["home"].x, d * 3.0)
				n.position.z = move_toward(n.position.z, pg["home"].z, d * 3.0)
			else:
				pg["t"] -= d
				n.rotation.x = 0.4 if fmod(t + pg["t"], 1.2) < 0.2 else 0.0      # pecking
				if pg["t"] < 0.0:
					pg["t"] = rng.randf_range(1.0, 3.0)
					n.rotation.y += rng.randf_range(-1.0, 1.0)
			if pp.distance_to(n.position) < 4.5:
				pg["fly"] = true
				pg["t"] = 4.0
				var away := (n.position - pp); away.y = 0
				pg["v"] = away.normalized() * rng.randf_range(5, 8) + Vector3(0, rng.randf_range(5, 7), 0)
				n.rotation.y = atan2(away.x, away.z)

# a giant inflatable mascot that sways
func _mascot():
	var p2 := _spot(3.0, 20.0)
	if p2 == Vector3.INF: return
	_claim(p2, 3.0)
	var masc := Node3D.new(); add_child(masc); masc.position = p2
	var yel := U.solid(Color(1, 0.8, 0.15), 0.0, 0.4)
	U.cyl(masc, 0.9, 0.3, Vector3(0, 0.15, 0), U.solid(Color(0.3, 0.3, 0.32)))      # blower base
	U.sphere(masc, 1.0, Vector3(0, 2.0, 0), yel, 3.4)
	U.sphere(masc, 0.75, Vector3(0, 4.2, 0), yel)
	for ex in [-0.25, 0.25]: U.sphere(masc, 0.12, Vector3(ex, 4.35, 0.65), U.solid(Color(0.05, 0.05, 0.05)))
	U.box(masc, Vector3(0.5, 0.08, 0.1), Vector3(0, 4.0, 0.72), U.solid(Color(0.8, 0.1, 0.1)))
	U.label(masc, "SOLDES", Vector3(0, 2.0, 1.05), 110, Color(0.8, 0.05, 0.05), Color(0, 0, 0, 0), false).outline_size = 0
	w.add_obstacle(masc, true, 0.0)
	spinners.append({"n": masc, "sp": 0.0, "sway": true, "ph": 0.0})

# the golden bull of speculation
func _bull():
	var bp := _spot(4.0, 16.0)
	if bp == Vector3.INF: return
	_claim(bp, 4.0)
	var bull := Node3D.new(); add_child(bull); bull.position = bp; bull.rotation.y = rng.randf() * TAU
	var gold := U.solid(Color(1.0, 0.75, 0.25), 0.3, 0.25, 1.0)
	U.box(bull, Vector3(3.4, 2.2, 1.6), Vector3(0, 1.1, 0), U.solid(Color(0.2, 0.2, 0.22)))        # plinth on the ground
	for lx in [-1.2, 1.2]:
		for lz in [-0.4, 0.4]: U.cyl(bull, 0.15, 0.9, Vector3(lx, 2.65, lz), gold)             # legs stand on the plinth
	var bd := U.sphere(bull, 1.0, Vector3(0, 3.65, 0), gold, 1.6); bd.scale.x = 2.0           # body rests on the legs
	U.sphere(bull, 0.6, Vector3(1.9, 3.9, 0), gold)
	for hz in [-0.4, 0.4]:
		var h := U.cyl(bull, 0.08, 0.8, Vector3(2.1, 4.5, hz), gold); h.rotation.x = hz * 1.5
	U.label(bull, "TAUREAU DE LA SPÉCULATION", Vector3(0, 1.2, 0.82), 70, Color(1, 0.85, 0.3), Color(0, 0, 0, 0), false).outline_size = 0
	w.add_obstacle(bull)

# hoardings: wooden fences covered in posters (ours over theirs), along the edges of lots
func _hoardings(id: String):
	var ad_ratio: float = {"hypermarche": 0.3, "quartier": 0.5, "bourse": 0.6}.get(id, 0.3)
	var wood := U.pbr("Concrete034", 0.5, Color(0.55, 0.42, 0.3), 0.6) if false else U.solid(Color(0.42, 0.32, 0.22), 0.0, 0.9)
	var n := 0
	for l in w.lots:
		if n >= 9: break
		if l[1] in ["start", "parking"] or rng.randf() < 0.45: continue
		var r: Rect2 = l[0]
		var g := r.grow(-1.2)       # middle of each side, just inside the lot, posters facing inwards
		var e: Array = [[Vector3(g.get_center().x, 0, g.position.y), 0.0], [Vector3(g.get_center().x, 0, g.end.y), PI],
			[Vector3(g.position.x, 0, g.get_center().y), PI / 2], [Vector3(g.end.x, 0, g.get_center().y), -PI / 2]]
		e.shuffle()
		for pick in e:
			var p: Vector3 = pick[0]
			var rot: float = pick[1]
			var along := Vector3(cos(rot), 0, -sin(rot))
			var ok := true
			for k in [-3.0, 0.0, 3.0]:
				var q: Vector3 = p + along * k
				if not _free(q, 1.0) or _near_decor(q, 1.0): ok = false
			if not ok: continue
			var fence := Node3D.new(); add_child(fence); fence.position = p; fence.rotation.y = rot
			U.box(fence, Vector3(7.4, 2.6, 0.12), Vector3(0, 1.3, -0.06), wood)
			for k in 4: U.box(fence, Vector3(0.14, 2.7, 0.2), Vector3(-3.6 + k * 2.4, 1.35, -0.16), wood)
			for k in 4:
				var tex: String = U.ad_tex(rng.randi()) if rng.randf() < ad_ratio else U.propaganda_tex(rng.randi())
				var pst := U.poster(fence, tex, Vector3(-2.7 + k * 1.8, 1.35 + rng.randf_range(-0.08, 0.08), 0.01), Vector2(1.5, 2.25), 0.0)
				pst.rotation.z = rng.randf_range(-0.04, 0.04)
			for k in [-3.0, 0.0, 3.0]:
				w.small_obstacle(p + along * k, 0.6)
				_claim(p + along * k, 1.2)
			n += 1
			break

# ---------------------------------------------------------------- act II and III zones
func _scatter(n: int, pad: float, f: Callable):
	for i in int(n * w.area_k):
		var p := _spot(pad)
		if p == Vector3.INF: continue
		_claim(p, pad)
		f.call(p, i)

func _paradis():
	# beach balls, jet-skis parked on the sand, coconuts, sun loungers
	var cols := [Color(1, 0.3, 0.3), Color(0.2, 0.6, 1.0), Color(1.0, 0.85, 0.2)]
	_scatter(8, 1.0, func(p: Vector3, i: int): U.sphere(self, 0.35, p + Vector3(0, 0.35, 0), U.solid(cols[i % 3], 0.0, 0.5)))
	_scatter(6, 3.0, func(p: Vector3, i: int):
		var j := Node3D.new(); add_child(j); j.position = p; j.rotation.y = rng.randf() * TAU
		U.box(j, Vector3(0.9, 0.5, 2.4), Vector3(0, 0.35, 0), U.solid([Color(1, 0.85, 0.2), Color(0.9, 0.2, 0.3), Color(0.2, 0.8, 0.9)][i % 3], 0.0, 0.4))
		U.box(j, Vector3(0.6, 0.35, 0.9), Vector3(0, 0.75, -0.2), U.solid(Color(0.1, 0.1, 0.12)))
		U.box(j, Vector3(0.8, 0.08, 0.08), Vector3(0, 1.05, 0.45), U.solid(Color(0.2, 0.2, 0.22)))
		w.small_obstacle(p, 1.0))
	_scatter(10, 0.6, func(p: Vector3, i: int):
		for k in 3: U.sphere(self, 0.16, p + Vector3(k * 0.3, 0.15, (k % 2) * 0.2), U.solid(Color(0.45, 0.3, 0.15), 0.0, 0.9)))
	# a moored golden yacht with a slogan on the hull, as a landmark
	_cocktail_bars()

func _cocktail_bars():
	for i in int(3 * w.area_k):
		var p := _spot(3.5)
		if p == Vector3.INF: continue
		_claim(p, 3.5)
		var b := Node3D.new(); add_child(b); b.position = p; b.rotation.y = rng.randf() * TAU
		var wood := U.solid(Color(0.55, 0.38, 0.2), 0.0, 0.9)
		U.box(b, Vector3(3.0, 1.1, 1.0), Vector3(0, 0.55, 0), wood)
		for k in 4: U.box(b, Vector3(0.12, 2.6, 0.12), Vector3(-1.4 + (k % 2) * 2.8, 1.3, -0.4 + (k / 2) * 1.6), wood)
		U.box(b, Vector3(3.6, 0.25, 2.4), Vector3(0, 2.7, 0.4), U.solid(Color(0.85, 0.75, 0.45), 0.0, 1.0))
		U.label(b, "BAR DES ÉVADÉS", Vector3(0, 1.4, 0.52), 50, Color(1, 0.9, 0.5), Color(0, 0, 0, 1), false)
		w.small_obstacle(p, 1.8)

func _startup():
	# e-scooters dumped everywhere, food trucks, neon "pivot" signs
	_scatter(18, 0.8, func(p: Vector3, i: int):
		var s := Node3D.new(); add_child(s); s.position = p; s.rotation = Vector3(0, rng.randf() * TAU, PI / 2 * 0.9 if i % 3 == 0 else 0.0)
		if i % 3 == 0: s.position.y = 0.1
		U.box(s, Vector3(0.18, 0.06, 1.0), Vector3(0, 0.12, 0), U.solid(Color(0.15, 0.15, 0.17)))
		U.box(s, Vector3(0.05, 1.0, 0.05), Vector3(0, 0.6, 0.45), U.solid(Color(0.3, 0.85, 0.5), 0.0, 0.5))
		U.box(s, Vector3(0.45, 0.04, 0.04), Vector3(0, 1.1, 0.45), U.solid(Color(0.15, 0.15, 0.17))))
	_scatter(4, 4.0, func(p: Vector3, i: int):
		var tr := U.place(self, U.CAR + ["delivery", "van", "delivery-flat"][i % 3] + ".glb", p, 2.6, rng.randf() * TAU)
		w.add_obstacle(tr)
		var a := U.world_aabb(tr)
		# a menu board fixed on the roof, the dish written on both faces
		var rot: float = tr.rotation.y
		var bb := U.box(self, Vector3(2.6, 0.7, 0.08), Vector3(p.x, a.end.y + 0.55, p.z), U.solid(Color(0.95, 0.4, 0.7)), Vector3(0, rot, 0))
		for k in 2: U.box(self, Vector3(0.06, 0.25, 0.06), Vector3(p.x, a.end.y + 0.12, p.z) + Vector3(cos(rot), 0, -sin(rot)) * (k * 2.0 - 1.0), U.solid(Color(0.3, 0.3, 0.32)))
		for f in [1.0, -1.0]:
			var fl := U.label(self, ["QUINOA BOWL", "KOMBUCHA", "AVOCADO TOAST", "POKÉ"][i % 4], Vector3(p.x, a.end.y + 0.55, p.z) + Vector3(sin(rot), 0, cos(rot)) * 0.045 * f, 70, Color(1, 1, 1), Color(0, 0, 0, 0), false, U.font_main)
			fl.rotation.y = rot + (0.0 if f > 0.0 else PI); fl.outline_size = 0
			U.fit_label(fl, 2.4, 0.6))
	var neon := [Color(1, 0.3, 0.8), Color(0.3, 0.9, 1.0), Color(0.7, 0.4, 1.0)]
	_scatter(10, 1.0, func(p: Vector3, i: int):
		U.cyl(self, 0.06, 3.6, p + Vector3(0, 1.8, 0), U.solid(Color(0.2, 0.2, 0.22)))
		var bl := U.box(self, Vector3(1.6, 0.5, 0.08), p + Vector3(0, 3.7, 0), U.solid(neon[i % 3], 4.0), Vector3(0, rng.randf() * TAU, 0))
		if i % 3 == 0: blinkers.append({"n": bl, "ph": rng.randf() * TAU})
		w.small_obstacle(p, 0.4))
	_billboard("PIVOT · DISRUPT · SCALE · BURN · LEVER · PIVOT · LICENCIER · RECOMMENCER · ", Color(1.0, 0.45, 0.85))

func _datacenter():
	# hovering surveillance drones, blinking beacons, cable trays
	_scatter(10, 1.0, func(p: Vector3, i: int):
		var d := Node3D.new(); add_child(d); d.position = p + Vector3(0, rng.randf_range(4.0, 6.0), 0)
		d.set_meta("airborne", true)
		U.box(d, Vector3(0.6, 0.15, 0.6), Vector3.ZERO, U.solid(Color(0.15, 0.15, 0.18), 0.2, 0.4, 0.6))
		for k in 4:
			U.cyl(d, 0.22, 0.02, Vector3(cos(k * PI / 2 + PI / 4) * 0.45, 0.08, sin(k * PI / 2 + PI / 4) * 0.45), U.solid(Color(0.6, 0.6, 0.62)))
		var eye := U.sphere(d, 0.09, Vector3(0, -0.1, 0.25), U.solid(Color(1, 0.15, 0.15), 5.0))
		blinkers.append({"n": eye, "ph": rng.randf() * TAU})
		drones.append({"n": d, "y": d.position.y, "ph": rng.randf() * TAU}))
	_scatter(14, 0.8, func(p: Vector3, i: int):
		U.cyl(self, 0.08, 2.6, p + Vector3(0, 1.3, 0), U.solid(Color(0.2, 0.2, 0.22)))
		var bl := U.sphere(self, 0.18, p + Vector3(0, 2.7, 0), U.solid([Color(0.2, 0.7, 1.0), Color(0.3, 1.0, 0.5)][i % 2], 5.0))
		if i % 2 == 0: blinkers.append({"n": bl, "ph": rng.randf() * TAU})
		w.small_obstacle(p, 0.3))
	var lights := 0
	for i in 6:
		var p := _spot(1.0, 8.0)
		if p == Vector3.INF: continue
		var ol := OmniLight3D.new(); ol.light_color = Color(0.3, 0.7, 1.0); ol.omni_range = 12.0; ol.light_energy = 1.4
		ol.position = p + Vector3(0, 4.0, 0); add_child(ol)
	_billboard("TÉLÉCHARGEMENT DE VOTRE ÂME : 87 % · NE QUITTEZ PAS · VOS DONNÉES NOUS APPARTIENNENT · ", Color(0.4, 0.85, 1.0))

func _ski():
	# snowmen, ski racks, falling snow
	_scatter(8, 1.2, func(p: Vector3, i: int):
		var white := U.pbr("Snow010A", 0.2, Color(1.05, 1.05, 1.1), 0.5)
		U.sphere(self, 0.6, p + Vector3(0, 0.55, 0), white)
		U.sphere(self, 0.42, p + Vector3(0, 1.4, 0), white)
		U.sphere(self, 0.3, p + Vector3(0, 2.0, 0), white)
		U.cyl(self, 0.22, 0.4, p + Vector3(0, 2.45, 0), U.solid(Color(0.1, 0.1, 0.1)))          # top hat: even the snowmen are rich here
		var nose := U.cyl(self, 0.04, 0.3, p + Vector3(0, 2.0, 0.38), U.solid(Color(1, 0.5, 0.1)))
		nose.rotation.x = PI / 2
		w.small_obstacle(p, 0.6))
	_scatter(8, 1.5, func(p: Vector3, i: int):
		var r := Node3D.new(); add_child(r); r.position = p; r.rotation.y = rng.randf() * TAU
		var wood := U.solid(Color(0.5, 0.34, 0.2), 0.0, 0.9)
		U.box(r, Vector3(2.4, 0.1, 0.1), Vector3(0, 1.2, 0), wood)
		for k in 2: U.box(r, Vector3(0.1, 1.2, 0.1), Vector3(-1.1 + k * 2.2, 0.6, 0), wood)
		for k in 5:
			var sk := U.box(r, Vector3(0.1, 1.7, 0.03), Vector3(-0.9 + k * 0.45, 0.85, 0.1), U.solid([Color(1, 0.8, 0.2), Color(0.1, 0.1, 0.1), Color(0.9, 0.15, 0.15)][k % 3]))
			sk.rotation.x = -0.12
		w.small_obstacle(p, 1.2))
	snow = CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new(); m.albedo_color = Color(1, 1, 1, 0.9); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	snow.mesh = q; snow.amount = 500; snow.lifetime = 7.0; snow.preprocess = 7.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; snow.emission_box_extents = Vector3(30, 0.5, 30)
	snow.direction = Vector3(0.2, -1, 0); snow.spread = 15.0; snow.gravity = Vector3(0.3, -1.2, 0)
	snow.initial_velocity_min = 0.8; snow.initial_velocity_max = 1.6
	snow.local_coords = false
	snow.set_meta("airborne", true)
	add_child(snow)

func _fusee():
	# crates, small test rockets, rovers, warning beacons
	_scatter(10, 1.5, func(p: Vector3, i: int):
		var c := U.place(self, U.CAR + "box.glb", p, 1.2, rng.randf() * TAU)
		w.add_obstacle(c, false, 0.2))
	_scatter(5, 2.0, func(p: Vector3, i: int):
		var white := U.solid(Color(0.95, 0.95, 0.95), 0.1, 0.3, 0.6)
		U.cyl(self, 0.35, 3.0, p + Vector3(0, 1.9, 0), white)
		var nose := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.35; cm.height = 0.9
		nose.mesh = cm; nose.material_override = U.solid(Color(0.85, 0.15, 0.1)); nose.position = p + Vector3(0, 3.85, 0); add_child(nose)
		for k in 3: U.box(self, Vector3(0.05, 0.9, 0.5), p + Vector3(cos(k * TAU / 3) * 0.4, 0.6, sin(k * TAU / 3) * 0.4), U.solid(Color(0.85, 0.15, 0.1)), Vector3(0, -k * TAU / 3, 0))
		w.small_obstacle(p, 0.6))
	_scatter(4, 3.0, func(p: Vector3, i: int):
		var rv := Node3D.new(); add_child(rv); rv.position = p; rv.rotation.y = rng.randf() * TAU
		U.box(rv, Vector3(1.6, 0.5, 2.2), Vector3(0, 0.8, 0), U.solid(Color(0.85, 0.85, 0.82), 0.2, 0.4, 0.6))
		for k in 6:
			var wh := U.cyl(rv, 0.3, 0.2, Vector3(-0.85 + (k % 2) * 1.7, 0.3, -0.8 + (k / 2) * 0.8), U.solid(Color(0.15, 0.15, 0.15)))
			wh.rotation.z = PI / 2
		U.box(rv, Vector3(1.2, 0.05, 0.8), Vector3(0, 1.3, -0.3), U.solid(Color(0.15, 0.25, 0.55), 0.4, 0.2, 0.6), Vector3(-0.3, 0, 0))
		w.small_obstacle(p, 1.3))
	_scatter(12, 0.6, func(p: Vector3, i: int):
		U.cyl(self, 0.05, 1.4, p + Vector3(0, 0.7, 0), U.solid(Color(0.2, 0.2, 0.22)))
		var bl := U.sphere(self, 0.14, p + Vector3(0, 1.5, 0), U.solid(Color(1, 0.55, 0.1), 5.0))
		blinkers.append({"n": bl, "ph": rng.randf() * TAU}))
	_billboard("T-MOINS 10 · 9 · 8 · LE PEUPLE RESTE AU SOL · 7 · 6 · LA PLANÈTE AUSSI · ", Color(1.0, 0.6, 0.2))

func _grandsoir():
	# lanterns over the squares, barricades of crates, red carpet of leaflets
	var red := U.solid(Color(0.85, 0.08, 0.1), 2.0)
	_scatter(10, 3.0, func(p: Vector3, i: int):
		for k in 6:
			var lp := p + Vector3(-3.0 + k * 1.2, 4.2 + sin(k * 0.9) * 0.2, 0)
			var lan := U.sphere(self, 0.22, lp, red, 0.36)
			lan.set_meta("airborne", true)
		U.box(self, Vector3(7.0, 0.03, 0.03), p + Vector3(0, 4.45, 0), U.solid(Color(0.1, 0.1, 0.1))).set_meta("airborne", true)
		for sd in [-3.6, 3.6]: U.cyl(self, 0.06, 4.5, p + Vector3(sd, 2.25, 0), U.solid(Color(0.25, 0.25, 0.27))))
	_scatter(6, 2.5, func(p: Vector3, i: int):
		for k in 5:
			var c := U.place(self, U.CAR + "box.glb", p + Vector3((k % 3) * 1.1 - 1.1, (k / 3) * 1.0, 0), 1.0, rng.randf_range(-0.2, 0.2))
		var fl := U.box(self, Vector3(0.05, 0.9, 1.4), p + Vector3(0, 3.0, 0.7), U.solid(Color(0.78, 0.06, 0.08), 0.0, 0.9))
		U.cyl(self, 0.04, 3.4, p + Vector3(0, 1.7, 0), U.solid(Color(0.3, 0.3, 0.3)))
		w.small_obstacle(p, 1.8))
	_billboard("C'EST LA LUTTE FINALE · GROUPONS-NOUS ET DEMAIN · LE MARCHÉ FERME CE SOIR · ", Color(1.0, 0.3, 0.25))

func _firework():
	var pp: Vector3 = player.global_position if player else Vector3(w.bounds.get_center().x, 0, w.bounds.get_center().y)
	var p := pp + Vector3(rng.randf_range(-40, 40), rng.randf_range(26, 42), rng.randf_range(-45, -10))
	var col: Color = [Color(1, 0.3, 0.25), Color(1, 0.85, 0.3), Color(1, 1, 1), Color(0.95, 0.2, 0.2)][rng.randi() % 4]
	var fx := CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://fx/circle_05.png"); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	fx.mesh = q; fx.amount = 70; fx.lifetime = 1.8; fx.one_shot = true; fx.explosiveness = 1.0
	fx.direction = Vector3.UP; fx.spread = 180.0; fx.initial_velocity_min = 9.0; fx.initial_velocity_max = 13.0
	fx.gravity = Vector3(0, -4, 0); fx.damping_min = 3.0; fx.damping_max = 4.0
	fx.scale_amount_min = 0.6; fx.scale_amount_max = 1.0
	fx.position = p
	fx.set_meta("airborne", true)
	add_child(fx)
	fx.emitting = true
	VFX.free_later(fx, 2.5)
	if rng.randf() < 0.5: Snd.play("explosion", -22.0, 0.2, 0.3, 1.6)

# ---------------------------------------------------------------- Berlin 1945 (special level)
func _berlin():
	var stone := U.solid(Color(0.34, 0.31, 0.28), 0.0, 1.0)
	var dark := U.solid(Color(0.16, 0.15, 0.14), 0.0, 0.7, 0.5)
	# the parliament in ruins, a red flag raised on the skeleton of its dome
	var c := _spot(16.0, 30.0)
	if c != Vector3.INF:
		_claim(c, 16.0)
		var hall := Node3D.new(); add_child(hall); hall.position = c
		U.box(hall, Vector3(26.0, 9.0, 16.0), Vector3(0, 4.5, 0), stone)
		for k in 6: U.box(hall, Vector3(1.0, 8.0, 1.0), Vector3(-10.0 + k * 4.0, 4.0, 8.4), stone)      # columns
		U.box(hall, Vector3(26.0, 1.2, 1.4), Vector3(0, 8.6, 8.6), stone)
		var lab := U.label(hall, "DEM DEUTSCHEN VOLKE", Vector3(0, 8.6, 9.32), 72, Color(0.8, 0.78, 0.72), Color(0, 0, 0, 0), false)
		U.fit_label(lab, 20.0, 1.0)
		# dome: bare ribs
		for k in 10:
			var a := TAU * k / 10.0
			var rib := U.box(hall, Vector3(0.35, 7.0, 0.35), Vector3(cos(a) * 3.6, 12.0, sin(a) * 3.6), dark)
			rib.rotation = Vector3(sin(a) * 0.55, 0, -cos(a) * 0.55)
		U.cyl(hall, 6.4, 0.5, Vector3(0, 9.3, 0), dark)
		U.cyl(hall, 0.09, 6.0, Vector3(0, 18.0, 0), U.solid(Color(0.3, 0.3, 0.3)))
		var flag := Node3D.new(); hall.add_child(flag); flag.position = Vector3(0, 20.0, 0)
		U.flag_cloth(flag, Vector2(3.2, 2.0), Vector3(0, -0.2, 0.05))
		flags.append({"n": flag, "base": 0.0, "ph": 0.3})
		hall.rotation.y = rng.randf() * TAU
		w.add_obstacle(hall)
		w.register_occluder(hall)
	# searchlights sweeping the smoky sky
	for i in 6:
		var p := _spot(2.0)
		if p == Vector3.INF: continue
		_claim(p, 2.0)
		U.cyl(self, 0.7, 1.0, p + Vector3(0, 0.5, 0), dark)
		var piv := Node3D.new(); add_child(piv); piv.position = p + Vector3(0, 1.1, 0)
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 3.0; cm.bottom_radius = 0.35; cm.height = 60.0
		beam.mesh = cm
		var bm := StandardMaterial3D.new(); bm.albedo_color = Color(1.0, 0.95, 0.8, 0.07); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = Vector3(0, 30.0, 0)
		var tilt := Node3D.new(); piv.add_child(tilt); tilt.rotation.x = rng.randf_range(0.35, 0.6)
		tilt.add_child(beam)
		piv.set_meta("airborne", true)
		spinners.append({"n": piv, "sp": rng.randf_range(0.15, 0.3) * (1.0 if i % 2 else -1.0)})
		w.small_obstacle(p, 0.8)
	# ash drifting down from the burning city
	snow = CPUParticles3D.new()
	var aq := QuadMesh.new(); aq.size = Vector2(0.07, 0.07)
	var am := StandardMaterial3D.new(); am.albedo_color = Color(0.35, 0.33, 0.31, 0.85); am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aq.material = am
	snow.mesh = aq; snow.amount = 260; snow.lifetime = 8.0; snow.preprocess = 8.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; snow.emission_box_extents = Vector3(30, 0.5, 30)
	snow.direction = Vector3(0.4, -1, 0.1); snow.spread = 25.0; snow.gravity = Vector3(0.4, -0.6, 0)
	snow.initial_velocity_min = 0.4; snow.initial_velocity_max = 1.0
	snow.local_coords = false
	snow.set_meta("airborne", true)
	add_child(snow)
	_bunker_dressing()
	# fires still burning in the rubble
	_scatter(8, 2.0, func(p: Vector3, i: int):
		VFX.fire(self, p, rng.randf_range(0.8, 1.4))
		w.small_obstacle(p, 0.8))
	# Red Army posters and a field kitchen
	_billboard("BERLIN · AVRIL 1945 · LE BUNKER EST ENCERCLÉ · IL AVAIT PROMIS MILLE ANS · PLUS JAMAIS ÇA · ", Color(1.0, 0.35, 0.25))

# the bunker: entrance, sandbags and barbed wire outside; the room inside (seen once the roof is gone)
func _bunker_dressing():
	if w.bunker.is_empty(): return
	var c: Vector3 = w.bunker["center"]
	var inner: float = w.bunker["inner"]
	var half: float = inner * 0.5 + 1.2
	var sand := U.solid(Color(0.6, 0.53, 0.4), 0.0, 1.0)
	var conc := U.solid(Color(0.42, 0.42, 0.4), 0.0, 1.0)
	var wood := U.solid(Color(0.35, 0.24, 0.14), 0.0, 0.9)
	var iron := U.solid(Color(0.2, 0.2, 0.21), 0.0, 0.5, 0.6)
	var paper := U.solid(Color(0.9, 0.87, 0.78), 0.0, 1.0)
	# entrance: a concrete stairwell block on the south side, a sign, sandbags each side
	var ent := c + Vector3(0, 0, half + 1.6)
	U.box(self, Vector3(4.0, 2.6, 3.0), ent + Vector3(0, 1.3, 0), conc)
	U.box(self, Vector3(2.0, 1.9, 0.1), ent + Vector3(0, 0.95, 1.52), U.solid(Color(0.05, 0.05, 0.05)))
	var sg := U.label(self, "BUNKER · ENTRÉE INTERDITE · MÊME AUX GÉNÉRAUX", ent + Vector3(0, 2.25, 1.53), 64, Color(0.9, 0.85, 0.75), Color(0, 0, 0, 0), false)
	U.fit_label(sg, 3.8, 0.4)
	w.add_obstacle(U.box(self, Vector3(4.0, 2.6, 3.0), ent + Vector3(0, 1.3, 0), conc))
	for sx in [-1.0, 1.0]:
		for row in 3:
			for k in 4:
				U.box(self, Vector3(0.8, 0.32, 0.45), ent + Vector3(sx * (2.6 + k * 0.0), 0.17 + row * 0.32, 1.2 - k * 0.85), sand).rotation.y = PI / 2
	# barbed wire on X-shaped posts all around
	for e in 4:
		var along := Vector3(1, 0, 0) if e < 2 else Vector3(0, 0, 1)
		var side := Vector3(0, 0, 1) if e < 2 else Vector3(1, 0, 0)
		var sg2 := 1.0 if e % 2 == 0 else -1.0
		var k := -half + 1.0
		while k < half - 1.0:
			var p: Vector3 = c + side * sg2 * (half + 3.2) + along * k
			if p.distance_to(ent) > 4.0:
				for d in [-0.5, 0.5]:
					var post := U.box(self, Vector3(0.08, 1.2, 0.08), p + Vector3(0, 0.55, 0), wood)
					post.rotation = Vector3(0, 0, d) if e >= 2 else Vector3(d, 0, 0)
				U.box(self, Vector3(0.02, 0.02, 2.6) if e >= 2 else Vector3(2.6, 0.02, 0.02), p + Vector3(0, 0.9, 0) + along * 1.3, iron)
				U.box(self, Vector3(0.02, 0.02, 2.6) if e >= 2 else Vector3(2.6, 0.02, 0.02), p + Vector3(0, 0.5, 0) + along * 1.3, iron)
			k += 2.6
	# inside: chairs around the map table, a field radio, filing cabinets, a camp bed, papers everywhere
	var tc: Vector3 = c + Vector3(0, 0, -inner * 0.25)
	for k in 6:
		var a := TAU * k / 6.0
		var ch := U.place(self, U.PROPS + "kk_furniture/chair_A_wood.gltf", tc + Vector3(cos(a) * 3.3, 0, sin(a) * 1.9), 1.0, -a + PI / 2)
		if k == 2: ch.rotation.z = 1.3; ch.position.y += 0.25      # one knocked over in the tantrum
	var radio := U.place(self, "res://assets/weapons/furniture/radio.glb", tc + Vector3(2.0, 0.9, 0.6), 0.4, 0.4)
	for k in 3:
		U.box(self, Vector3(0.9, 1.6, 0.6), c + Vector3(-inner * 0.42, 0.8, -inner * 0.3 + k * 1.0), U.solid(Color(0.3, 0.33, 0.28), 0.0, 0.5, 0.4))
	U.place(self, U.PROPS + "kk_furniture/bed_single_A.gltf", c + Vector3(inner * 0.33, 0, inner * 0.28), 0.9, 0.0)
	U.place(self, U.PROPS + "kk_furniture/armchair.gltf", c + Vector3(-inner * 0.3, 0, inner * 0.1), 1.0, PI * 0.6)
	for k in 26:
		var pp := c + Vector3(rng.randf_range(-inner * 0.45, inner * 0.45), 0.08, rng.randf_range(-inner * 0.45, inner * 0.45))
		U.box(self, Vector3(0.3, 0.01, 0.22), pp, paper, Vector3(0, rng.randf() * TAU, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		U.place(self, U.PROPS + "kk_resource_bits/Containers_Crate_Medium_Wood.gltf", c + Vector3(inner * 0.4, 0.0, -inner * 0.4 + k * 1.0), 0.8, rng.randf() * 0.3)
	# a portrait torn off the wall, face down on the floor (we will never know who it was)
	U.box(self, Vector3(1.0, 0.04, 1.3), c + Vector3(-inner * 0.2, 0.08, inner * 0.35), U.solid(Color(0.4, 0.28, 0.12), 0.2, 0.4, 0.6), Vector3(0, 0.4, 0))

# Berlin: distant artillery all along, shells landing nearer during the bombing, dust and flickers in the bunker
var art_t := 2.0
var bunk_t := 1.0
func _berlin_tick(d: float):
	var ph: int = w.berlin_ph
	art_t -= d
	if art_t <= 0.0 and ph < 3:
		art_t = rng.randf_range(0.6, 1.6) if ph == 2 else rng.randf_range(2.5, 5.5)
		var c: Vector2 = w.bounds.get_center()
		var a := rng.randf() * TAU
		var rad: float = maxf(w.bounds.size.x, w.bounds.size.y) * 0.5 + rng.randf_range(40.0, 90.0)
		var fp := Vector3(c.x + cos(a) * rad, rng.randf_range(2.0, 10.0), c.y + sin(a) * rad)
		var fl := U.sprite(self, "light_01.png", fp, rng.randf_range(30.0, 55.0), Color(1.0, 0.6, 0.25, 0.9), 4.0)
		fl.set_meta("airborne", true)
		var tw := fl.create_tween()
		tw.tween_property(fl, "scale", Vector3.ONE * 0.05, 0.35)
		tw.tween_callback(fl.queue_free)
		Snd.play("explosion", -24.0 if ph == 1 else -16.0, 0.2, 0.3, 0.5)
		if ph == 2 and player and rng.randf() < 0.55:
			# a shell lands in the streets (show only, it does not hurt)
			var b := rng.randf() * TAU
			var sp: Vector3 = player.global_position + Vector3(cos(b), 0, sin(b)) * rng.randf_range(22.0, 40.0)
			if w.inside(sp):
				VFX.explosion(self, sp + Vector3(0, 0.4, 0), 3.0, Color(1.0, 0.55, 0.2))
				var cr := U.cyl(self, rng.randf_range(1.2, 2.0), 0.02, Vector3(sp.x, 0.06, sp.z), U.solid(Color(0.1, 0.09, 0.08), 0.0, 1.0))
				cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ph == 3 and not w.bunker.is_empty():
		bunk_t -= d
		if bunk_t <= 0.0:
			bunk_t = rng.randf_range(2.0, 4.0)
			var c3: Vector3 = w.bunker["center"]
			var inner: float = w.bunker["inner"]
			# a shell hits above: the lights flicker and dust pours from the ceiling
			for l in w.bunker["lights"]:
				var ol := l as OmniLight3D
				var tw2 := ol.create_tween()
				tw2.tween_property(ol, "light_energy", 0.3, 0.06); tw2.tween_property(ol, "light_energy", 2.5, 0.1)
				tw2.tween_property(ol, "light_energy", 0.6, 0.05); tw2.tween_property(ol, "light_energy", 2.5, 0.2)
			for k in 3:
				var dp := c3 + Vector3(rng.randf_range(-inner * 0.4, inner * 0.4), 4.0, rng.randf_range(-inner * 0.4, inner * 0.4))
				var dust := VFX.ps(self, "smoke_05.png", {"n": 16, "life": 1.4, "size": 0.9, "add": false, "ramp": "dust", "curve": "grow", "spread": 12.0, "vel": [1.0, 2.5], "pos": dp, "dir": Vector3.DOWN, "one_shot": true, "explos": 0.6})
				VFX.free_later(dust, 2.0)
			Snd.play("explosion", -20.0, 0.1, 0.2, 0.4)

# ---------------------------------------------------------------- ambient smoke and steam (continuous particles)
# chimney plumes (factories, ruins, the skyline) and a few rooftop chimneys on ordinary buildings
func _smoke_columns():
	for s in smokes:
		var k: float = s.get("s", 3.0) / 3.0
		VFX.ps(self, ["smoke_01.png", "smoke_05.png", "smoke_07.png"][rng.randi() % 3], {"n": 12, "life": 7.0, "preprocess": 7.0, "size": 2.6 * k,
			"add": false, "ramp": "smoke", "curve": "grow", "spread": 8.0, "vel": [1.6 * k, 2.4 * k], "grav": Vector3(0.45, 0.2, 0.1),
			"angvel": 12.0, "pos": s["p"]})
	var id: String = w.template.get("id", "")
	if id in ["berlin", "datacenter", "fusee"]: return
	var cands: Array = w.occluders.duplicate()
	cands.shuffle()
	var brick := U.solid(Color(0.5, 0.3, 0.24), 0.0, 1.0)
	var n := 0
	for o in cands:
		if n >= 6: break
		var a: AABB = o["aabb"]
		if a.size.y < 9.0 or a.size.y > 40.0: continue
		var cp := Vector3(a.position.x + a.size.x * rng.randf_range(0.25, 0.75), a.end.y - 0.3, a.position.z + a.size.z * rng.randf_range(0.25, 0.75))
		U.box(self, Vector3(0.7, 1.8, 0.7), cp + Vector3(0, 0.9, 0), brick).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.box(self, Vector3(0.85, 0.15, 0.85), cp + Vector3(0, 1.85, 0), brick).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		VFX.ps(self, "smoke_05.png", {"n": 8, "life": 5.0, "preprocess": 5.0, "size": 1.4, "add": false, "ramp": "smoke_light", "curve": "grow",
			"spread": 10.0, "vel": [1.0, 1.6], "grav": Vector3(0.4, 0.15, 0.1), "angvel": 15.0, "pos": cp + Vector3(0, 2.1, 0)})
		n += 1

func _steam(p: Vector3):
	VFX.ps(self, "smoke_05.png", {"n": 6, "life": 2.6, "preprocess": 2.6, "size": 0.8, "add": false, "ramp": "steam", "curve": "grow",
		"spread": 12.0, "vel": [0.6, 1.1], "grav": Vector3(0.15, 0.1, 0), "angvel": 20.0, "pos": p + Vector3(0, 0.1, 0), "shape": "sphere", "r": 0.25})
