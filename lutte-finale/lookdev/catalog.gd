extends Node3D
# asset catalogue: one image per category, options numbered.  godot --path . res://lookdev/catalog.tscn -- cat=bancs out=/tmp/c.png
const C := "res://assets/_catalog/"
const P := "res://assets/props/"
const CATS := {
	"bancs": [["KayKit ville", P + "kk_city_builder/bench.gltf", 0.8], ["Kenney fête foraine", C + "k_coaster_kit/bench.glb", 0.8], ["Kenney Noël", C + "k_holiday_kit/bench.glb", 0.8], ["Kenney cimetière", C + "k_graveyard_kit/bench.glb", 0.8], ["Tiny Treats", C + "tiny_treats/bench_A.gltf", 0.8]],
	"poubelles": [["KayKit ville A", P + "kk_city_builder/trash_A.gltf", 1.0], ["KayKit ville B", P + "kk_city_builder/trash_B.gltf", 1.0], ["Kenney fête foraine", C + "k_coaster_kit/trash.glb", 1.0], ["Kenney mobilier", C + "k_furniture_kit/trashcan.glb", 1.0], ["KayKit benne", P + "kk_city_builder/dumpster.gltf", 1.5]],
	"bornes": [["KayKit ville", P + "kk_city_builder/firehydrant.gltf", 0.9], ["Quaternius", C + "q_zombie_apocalypse/FireHydrant.gltf", 0.9], ["KayKit divers", C + "kk_mixed_bag_1/fire_hydrant.gltf", 0.9]],
	"coffres": [["Kenney pirate", C + "k_pirate_kit/chest.glb", 0.8], ["KayKit donjon", C + "kk_dungeon/chest.gltf", 0.8], ["KayKit donjon (or)", C + "kk_dungeon/chest_gold.gltf", 0.8], ["Quaternius bois", C + "q_fantasy_props/Chest_Wood.gltf", 0.8], ["Kenney survie", C + "k_survival_kit/chest.glb", 0.8]],
	"statues": [["KayKit paladin", C + "kk_mystery_monthly_4/paladin_statue.gltf", 3.0], ["Kenney arène", C + "k_mini_arena/statue.glb", 3.0], ["Héros KayKit en bronze (Stakhanov)", "hero", 3.0]],
	"fontaines": [["Kenney ville fantastique", P + "k_fantasy_town_kit/fountain-round-detail.glb", 1.6], ["Tiny Treats", C + "tiny_treats/fountain.gltf", 1.6]],
	"palettes": [["KayKit prototype", C + "kk_prototype_bits/Pallet_Large.gltf", 0.3], ["KayKit ressources", C + "kk_resource_bits/Pallet_Wood.gltf", 0.3], ["Kenney urbain", C + "k_retro_urban_kit/pallet.glb", 0.3], ["Quaternius", C + "q_zombie_apocalypse/Pallet.gltf", 0.3]],
	"barrieres": [["Kenney file d'attente", C + "k_coaster_kit/queue-straight.glb", 1.1], ["Kenney course", C + "k_racing_kit/barrierWhite.glb", 1.0], ["Quaternius plastique", C + "q_zombie_apocalypse/PlasticBarrier.gltf", 1.0], ["Quaternius chantier", C + "q_zombie_apocalypse/TrafficBarrier_1.gltf", 1.0], ["Kenney urbain", C + "k_retro_urban_kit/detail-barrier-type-a.glb", 1.0]],
	"clotures": [["Kenney banlieue", C + "k_city_kit_suburban/fence.glb", 1.2], ["Kenney urbain (mur)", C + "k_retro_urban_kit/wall-fence.glb", 2.0], ["Kenney course (haute)", C + "k_racing_kit_early_access/fence-closed-tall.glb", 2.0], ["Kenney grille en fer", "res://assets/weapons/graveyard/iron_fence.glb", 1.6]],
	"chantier": [["Kenney échafaudage", C + "k_retro_urban_kit/scaffolding-structure.glb", 4.0], ["KayKit échafaudage", C + "kk_dungeon/scaffold_beam_wall.gltf", 3.0]],
	"oiseaux": [["Quaternius pigeon (animé)", C + "q_ultimate_monsters/Pigeon.gltf", 0.5], ["Tiny Treats oiseau", C + "tiny_treats/bird.gltf", 0.4]],
	"panneaux": [["Kenney grand panneau", C + "k_racing_kit/billboard.glb", 3.0], ["Kenney panneau bas", C + "k_racing_kit/billboardLow.glb", 2.0], ["Kenney poteau indicateur", C + "k_survival_kit/signpost.glb", 2.0], ["Tiny Treats panneau", C + "tiny_treats/sign_ground.gltf", 1.6]],
}
func _ready():
	var cat := "bancs"
	var out := "/tmp/cat.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cat="): cat = a.substr(4)
		elif a.begins_with("out="): out = a.substr(4)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.24, 0.26, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.85, 0.85, 0.9); e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -35, 0); sun.shadow_enabled = true; add_child(sun)
	U.box(self, Vector3(40, 0.1, 12), Vector3(0, -0.05, 0), U.solid(Color(0.55, 0.55, 0.53)))
	var items: Array = CATS[cat]
	var n := items.size()
	var cell := 3.0
	for i in n:
		var x := (i - (n - 1) * 0.5) * cell
		var node: Node3D
		if items[i][1] == "hero":
			node = Chars.build_hero(self, "stakhanov", 0)
			for m in node.find_children("*", "MeshInstance3D", true, false): (m as MeshInstance3D).material_override = U.solid(Color(0.72, 0.45, 0.22), 0.0, 0.35, 0.85)
			U.box(self, Vector3(1.0, 0.5, 1.0), Vector3(x, 0.25, 0), U.solid(Color(0.6, 0.58, 0.55)))
		else:
			node = U.scene(items[i][1]).instantiate()
			add_child(node)
			var ap := U.anim_player(node)
			if ap:
				for an in ap.get_animation_list():
					if "Idle" in an and not "Jump" in an: ap.play(an); break
		# every option fits the same 2.2 m cell (largest side), standing on the ground
		node.rotation.y = 0.5
		var a0 := U.world_aabb(node)
		node.scale *= 2.2 / maxf(maxf(a0.size.x, a0.size.y), maxf(a0.size.z, 0.01))
		var a1 := U.world_aabb(node)
		var base := 0.5 if items[i][1] == "hero" else 0.0
		node.position += Vector3(x - a1.get_center().x, base - a1.position.y, -a1.get_center().z)
		var num := U.label(self, str(i + 1), Vector3(x, 3.55, 0), 220, Color(1, 0.85, 0.3), Color(0, 0, 0, 1))
		num.pixel_size = 0.004
		var lab := U.label(self, items[i][0], Vector3(x, 2.75, 0), 64, Color(1, 1, 1), Color(0, 0, 0, 1))
		lab.pixel_size = 0.0045
	var w := n * cell
	var cam := Camera3D.new(); add_child(cam); cam.fov = 38
	cam.global_position = Vector3(0, 2.6, maxf(w * 0.95, 6.0))
	cam.look_at(Vector3(0, 1.55, 0))
	for i in 30: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
