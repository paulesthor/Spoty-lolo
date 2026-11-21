extends RefCounted
# Debug: scans a generated zone for props that float without support or overlap each other.
# godot --headless --path . res://scenes/main.tscn -- layoutcheck zone=2 seed=5

static func run(game) -> Array:
	var issues := []
	var world: Node3D = game.world
	# 1) floating meshes: bottom above ground with nothing underneath
	var boxes := []        # [aabb, node]
	var roots: Array = [world, game]
	for root in roots:
		for m in (root as Node).find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = m
			if not mi.is_visible_in_tree() or mi.mesh == null: continue
			if mi.mesh is QuadMesh or mi.mesh is PlaneMesh or mi.mesh is TorusMesh: continue     # sprites, decals, rings
			var sk := _skip(mi, game)
			if sk and _in_actor(mi, game): continue
			boxes.append([mi.global_transform * mi.get_aabb(), mi, sk])
	for b in boxes:
		if b[2]: continue          # imported-model parts only serve as supports
		var a: AABB = b[0]
		if a.position.y < 0.12: continue
		var supported := false
		for o in boxes:
			if o == b: continue
			var c: AABB = o[0]
			if c.position.y >= a.position.y - 0.01: continue
			if c.end.y < a.position.y - 0.25: continue
			if _xz_overlap(a, c) > 0.0:
				supported = true; break
		if not supported:
			# wall-mounted: touching something that itself reaches lower
			for o in boxes:
				if o == b: continue
				var c2: AABB = o[0]
				if c2.position.y < a.position.y - 0.05 and a.grow(0.12).intersects(c2):
					supported = true; break
		if not supported:
			for pl in world.plateaus:
				if (pl["rect"] as Rect2).grow(0.3).intersects(Rect2(a.position.x, a.position.z, a.size.x, a.size.z)) and absf(a.position.y - pl["h"]) < 0.3:
					supported = true; break
		if not supported:
			var par: Node = (b[1] as Node).get_parent()
			issues.append("FLOTTE  %s  y=%.2f size=%s  parent=%s(%d enfants)  at (%.1f, %.1f)" % [_name(b[1]), a.position.y, str(a.size), par.name, par.get_child_count(), a.get_center().x, a.get_center().z])
	# 2) overlapping props: model instances, chests, shrines, breakables, obstacles
	var props := []
	for root in [world, world.decor]:
		if root == null: continue
		for n in (root as Node).get_children():
			if n is Node3D and (n as Node3D).scene_file_path != "":
				var a2 := U.world_aabb(n)
				if a2.size.y > 7.0: continue          # buildings around the arena
				if (n as Node3D).scene_file_path.contains("food-kit"): continue      # goods displayed on counters
				var sp: String = (n as Node3D).scene_file_path
				if sp.contains("electricity-pole") or sp.contains("light-square"):
					var c4 := a2.get_center()
					a2 = AABB(Vector3(c4.x - 0.3, a2.position.y, c4.z - 0.3), Vector3(0.6, a2.size.y, 0.6))    # the mast, not the overhead arm
				if sp.contains("nature/"):
					var nm := sp.get_file()
					if nm.begins_with("grass") or nm.begins_with("flower") or nm.begins_with("plant") or nm.begins_with("petals"): continue   # undergrowth
					if nm.contains("tree"):
						var c3 := a2.get_center()
						a2 = AABB(Vector3(c3.x - 0.4, a2.position.y, c3.z - 0.4), Vector3(0.8, a2.size.y, 0.8))     # trunk only: canopies overhang
					else:
						a2 = a2.grow(-a2.size.x * 0.2)
				props.append([a2, n, _name(n)])
	for c in game.chests: props.append([U.world_aabb(c["n"]), c["n"], "coffre"])
	for bk in game.breakables: props.append([U.world_aabb(bk["n"]).grow(-0.05), bk["n"], "carton"])
	for s in game.shrines:
		var core := AABB(s["pos"] - Vector3(1.4, 0, 1.4), Vector3(2.8, 3.0, 2.8))     # the building itself, not its floor ring or light beam
		props.append([core, s["n"], "sanctuaire " + s["kind"]])
	for i in props.size():
		for j in range(i + 1, props.size()):
			var a3: AABB = props[i][0]
			var b3: AABB = props[j][0]
			var ov := _xz_overlap(a3, b3)
			if ov <= 0.0: continue
			var small := minf(a3.size.x * a3.size.z, b3.size.x * b3.size.z)
			var stacked := a3.position.y >= b3.end.y - 0.25 or b3.position.y >= a3.end.y - 0.25
			if ov > 0.12 * small and a3.intersects(b3) and not stacked:
				issues.append("CHEVAUCHE  %s  /  %s  at (%.1f, %.1f)" % [props[i][2], props[j][2], a3.get_center().x, a3.get_center().z])
	return issues

static func _skip(mi: Node, game) -> bool:
	var n: Node = mi
	while n != null and n != game:
		if n.name.begins_with("@") and false: return true
		if n == game.player or n == game.enemies or n == game.weapons or n == game.hud: return true
		if n.has_meta("airborne"): return true
		if n != mi and n is Node3D and (n as Node3D).scene_file_path != "": return true    # parts inside an imported model (the model itself is grounded by U.place)
		n = n.get_parent()
	return false

static func _in_actor(mi: Node, game) -> bool:
	var n: Node = mi
	while n != null and n != game:
		if n == game.player or n == game.enemies or n == game.weapons or n == game.hud or n.has_meta("airborne"): return true
		n = n.get_parent()
	return false

static func _name(n: Node) -> String:
	if n is Node3D and (n as Node3D).scene_file_path != "": return (n as Node3D).scene_file_path.get_file().get_basename()
	var p := n.get_parent()
	if p and p is Node3D and (p as Node3D).scene_file_path != "": return p.scene_file_path.get_file().get_basename() + "/" + n.name
	if n is MeshInstance3D and (n as MeshInstance3D).mesh: return "%s(%s) sous %s" % [n.name, (n as MeshInstance3D).mesh.get_class(), p.name if p else "?"]
	return str(n.name)

static func _xz_overlap(a: AABB, b: AABB) -> float:
	var x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var z := minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	if x <= 0.0 or z <= 0.0: return 0.0
	return x * z
