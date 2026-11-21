extends Control
# LE KOLKHOZE — minimal hub between runs: choose comrade & directives, spend medals,
# talents, weapon modules, Plan quinquennal. Also drives multi-run bot simulations.

var font: Font
var content: VBoxContainer
var header: Label
var tab := "lancer"
var bot := false
var runs_target := 0
var bot_dirs := false

func _ready():
	font = load("res://fonts/Oswald.woff2")
	for a in OS.get_cmdline_user_args():
		if a == "bot": bot = true
		elif a.begins_with("runs="): runs_target = int(a.substr(5))
		elif a == "botdirs": bot_dirs = true
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40; root.offset_top = 30; root.offset_right = -40; root.offset_bottom = -30
	root.add_theme_constant_override("separation", 30)
	add_child(root)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(340, 0)
	nav.add_theme_constant_override("separation", 10)
	root.add_child(nav)
	var title := _lbl("LE KOLKHOZE", 54, Color(0.9, 0.15, 0.15))
	nav.add_child(title)
	header = _lbl("", 26, Color(1, 0.85, 0.35))
	nav.add_child(header)
	nav.add_child(_lbl(" ", 10, Color.WHITE))
	var tabs := [["lancer", "LANCER UNE RUN"], ["bureau", "BUREAU DU PLAN"], ["caserne", "CASERNE (camarades)"], ["usine", "USINE D'ARMEMENT"], ["plan", "PLAN QUINQUENNAL"], ["directives", "DIRECTIVES DU PARTI"]]
	for t in tabs:
		var b := _btn(t[1], 26)
		b.pressed.connect(func(): tab = t[0]; _refresh())
		nav.add_child(b)
	nav.add_child(_lbl(" ", 10, Color.WHITE))
	var quit := _btn("QUITTER LE JEU", 20)
	quit.pressed.connect(func(): get_tree().quit())
	nav.add_child(quit)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_refresh()
	if bot: call_deferred("_bot_step")

func _lbl(t: String, size: int, col := Color(0.92, 0.9, 0.86)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _btn(t: String, size := 22, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func _row(parts: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	for p in parts:
		h.add_child(p)
	return h

func _clear():
	for c in content.get_children(): c.queue_free()

func _refresh():
	var d: Dictionary = Meta.data
	header.text = "%d MÉDAILLES\nRuns : %d · Victoires : %d · Record : %02d:%02d" % [d["medals"], d["runs"], d["wins"], int(d["best_time"]) / 60, int(d["best_time"]) % 60]
	_clear()
	match tab:
		"lancer": _tab_lancer()
		"bureau": _tab_bureau()
		"caserne": _tab_caserne()
		"usine": _tab_usine()
		"plan": _tab_plan()
		"directives": _tab_directives()

# ---------------------------------------------------------------- tabs
func _tab_lancer():
	content.add_child(_lbl("CHOISIS TON CAMARADE", 34, Color.WHITE))
	for c in Meta.CHARACTERS:
		var def: Dictionary = Meta.CHARACTERS[c]
		var cd: Dictionary = Meta.data["chars"][c]
		if not cd["unlocked"]:
			content.add_child(_lbl("🔒 %s · à recruter à la Caserne (%d médailles)" % [def["name"], def["cost"]], 22, Color(0.6, 0.58, 0.55)))
			continue
		var sel: bool = c == Meta.run_char
		var b := _btn(("▶ " if sel else "   ") + "%s · niveau %d · arme : %s" % [def["name"], Meta.char_level(c), Data.WEAPONS[def["weapon"]]["name"]], 26)
		b.pressed.connect(func(): Meta.run_char = c; Meta.data["last_char"] = c; _refresh())
		content.add_child(b)
		if sel:
			content.add_child(_lbl("     Passif : %s\n     Ultime (E) : %s · %s" % [def["passive"], def["ult"], def["ult_desc"]], 20, Color(0.8, 0.78, 0.72)))
	var f := Meta.ferveur(Meta.run_directives)
	content.add_child(_lbl(" ", 10))
	content.add_child(_lbl("Directives actives : ferveur %d (médailles x%.2f)" % [f, 1.0 + 0.15 * f], 22, Color(1, 0.6, 0.4) if f > 0 else Color(0.7, 0.7, 0.7)))
	if Meta.data["bureau_purged"] != "":
		content.add_child(_lbl("PURGE EN COURS : « %s » est désactivé jusqu'au prochain plan." % Meta.BUREAU[Meta.data["bureau_purged"]]["name"], 22, Color(1, 0.4, 0.3)))
	var plan: Dictionary = Meta.data["plan"]
	content.add_child(_lbl("Plan quinquennal : %d run(s) restante(s)" % plan["runs_left"], 22))
	for q in plan["quotas"]:
		content.add_child(_lbl("   %s %s (%s)" % ["✔" if q["done"] else "•", q["text"], _qprog(q)], 20, Color(0.5, 1, 0.5) if q["done"] else Color(0.85, 0.83, 0.8)))
	content.add_child(_lbl(" ", 10))
	var go := _btn("LANCER LA RUN  ·  ZONE 1 : L'HYPERMARCHÉ", 34)
	go.pressed.connect(_launch)
	content.add_child(go)
	go.grab_focus()
	content.add_child(_lbl("Contrôles : ZQSD déplacement · souris caméra · Espace saut · Maj glissade · F interagir · E ultime · T relancer les cartes · Échap pause", 18, Color(0.6, 0.6, 0.6)))

func _qprog(q: Dictionary) -> String:
	if q["kind"] in ["survive", "no_chest", "char_time"]:
		return "record %02d:%02d" % [int(q["progress"]) / 60, int(q["progress"]) % 60]
	return "%d / %d" % [int(q["progress"]), int(q["target"])]

func _tab_bureau():
	content.add_child(_lbl("BUREAU DU PLAN · bonus permanents pour tous les camarades", 30, Color.WHITE))
	for id in Meta.BUREAU:
		var b: Dictionary = Meta.BUREAU[id]
		var r := Meta.bureau_rank(id)
		var maxed: bool = r >= b["max"]
		var cost := Meta.bureau_cost(id, r)
		var purged: bool = Meta.data["bureau_purged"] == id
		var txt := "%s · rang %d/%d · %s par rang" % [b["name"], r, b["max"], Meta.stat_text(b["stat"], b["per"])]
		if purged: txt += " · PURGÉ"
		var btn := _btn("ACHETER (%d)" % cost if not maxed else "MAX", 20, not maxed and Meta.data["medals"] >= cost)
		btn.pressed.connect(func(): Meta.buy_bureau(id); _refresh())
		content.add_child(_row([btn, _lbl(txt, 22, Color(1, 0.5, 0.4) if purged else Color(0.9, 0.88, 0.84))]))

func _tab_caserne():
	content.add_child(_lbl("CASERNE · camarades et arbres de talents", 30, Color.WHITE))
	content.add_child(_lbl("Chaque run rapporte de l'XP au camarade joué (autant que de médailles gagnées). 1 niveau = 1 point de talent. Les talents d'une branche s'achètent dans l'ordre.", 18, Color(0.7, 0.7, 0.7)))
	for c in Meta.CHARACTERS:
		var def: Dictionary = Meta.CHARACTERS[c]
		var cd: Dictionary = Meta.data["chars"][c]
		content.add_child(_lbl(" ", 6))
		if not cd["unlocked"]:
			var ub := _btn("RECRUTER %s (%d médailles)" % [def["name"].to_upper(), def["cost"]], 24, Meta.data["medals"] >= def["cost"])
			ub.pressed.connect(func(): Meta.unlock_char(c); _refresh())
			content.add_child(ub)
			content.add_child(_lbl("     Arme : %s · %s · Ultime : %s" % [Data.WEAPONS[def["weapon"]]["name"], def["passive"], def["ult_desc"]], 18, Color(0.7, 0.7, 0.7)))
			continue
		var lv := Meta.char_level(c)
		var nxt := Meta.char_level_xp(lv + 1) if lv < 15 else 0
		content.add_child(_lbl("%s · niveau %d%s · %d point(s) libre(s)" % [def["name"].to_upper(), lv, (" (XP %d / %d)" % [cd["xp"], nxt]) if lv < 15 else " (max)", Meta.talent_points_free(c)], 26, Color(1, 0.85, 0.35)))
		for bi in 3:
			var br: Array = def["tree"][bi]
			var have: int = int(cd["talents"][bi])
			var parts := []
			for i in 5:
				var node: Array = br[1][i]
				parts.append(("✔ " if i < have else "· ") + Meta.stat_text(node[0], node[1]))
			var can := have < 5 and Meta.talent_points_free(c) > 0
			var tb := _btn("+", 22, can)
			tb.pressed.connect(func(): Meta.buy_talent(c, bi); _refresh())
			content.add_child(_row([tb, _lbl("%s : %s" % [br[0], "  →  ".join(parts)], 18)]))

func _tab_usine():
	content.add_child(_lbl("USINE D'ARMEMENT · déblocage, maîtrise et modules", 30, Color.WHITE))
	content.add_child(_lbl("La maîtrise monte avec les dégâts infligés par l'arme, toutes runs confondues : +4 % de dégâts par niveau et des modules à équiper (un par arme).", 18, Color(0.7, 0.7, 0.7)))
	for w in Data.WEAPONS:
		content.add_child(_lbl(" ", 4))
		var name: String = Data.WEAPONS[w]["name"]
		if not Meta.weapon_unlocked(w):
			var ub := _btn("DÉBLOQUER %s (%d médailles)" % [name.to_upper(), Meta.WEAPON_UNLOCK[w]], 22, Meta.data["medals"] >= Meta.WEAPON_UNLOCK[w])
			ub.pressed.connect(func(): Meta.unlock_weapon(w); _refresh())
			content.add_child(ub)
			continue
		var dmg := float(Meta.data["mastery"].get(w, 0.0))
		var ml := Meta.weapon_mastery(w)
		var nxt: String = (" · prochain niveau à %d dégâts" % Meta.MASTERY_XP[ml + 1]) if ml < 5 else " · max"
		content.add_child(_lbl("%s · maîtrise %d/5 (%d dégâts%s)" % [name.to_upper(), ml, int(dmg), nxt], 24, Color(1, 0.85, 0.35)))
		var cur: String = Meta.data["modules"].get(w, "")
		var none := _btn(("▶ " if cur == "" else "   ") + "Aucun module", 18)
		none.pressed.connect(func(): Meta.equip_module(w, ""); _refresh())
		content.add_child(none)
		for m in Meta.MODULES:
			if Meta.MODULES[m][0] != w: continue
			var av := Meta.module_available(m)
			var mb := _btn(("▶ " if cur == m else "   ") + "%s : %s%s" % [Meta.MODULES[m][2], Meta.MODULES[m][3], "" if av else " (maîtrise %d requise)" % Meta.MODULES[m][1]], 18, av)
			mb.pressed.connect(func(): Meta.equip_module(w, m); _refresh())
			content.add_child(mb)

func _tab_plan():
	var plan: Dictionary = Meta.data["plan"]
	content.add_child(_lbl("PLAN QUINQUENNAL N°%d · %d run(s) restante(s)" % [Meta.data["plan_no"], plan["runs_left"]], 30, Color.WHITE))
	content.add_child(_lbl("Remplis les 3 quotas avant la fin du plan : chaque quota rapporte des médailles, et le plan complet offre un bonus et un nouveau camarade. Si un quota n'est pas rempli, le Parti PURGE une de tes améliorations du Bureau pendant tout le plan suivant.", 20, Color(0.75, 0.75, 0.75)))
	for q in plan["quotas"]:
		content.add_child(_lbl("%s %s · %s" % ["✔" if q["done"] else "•", q["text"], _qprog(q)], 26, Color(0.5, 1, 0.5) if q["done"] else Color(0.92, 0.9, 0.86)))
	if Meta.data["bureau_purged"] != "":
		content.add_child(_lbl("Purge en cours : « %s » est désactivé." % Meta.BUREAU[Meta.data["bureau_purged"]]["name"], 22, Color(1, 0.4, 0.3)))

func _tab_directives():
	content.add_child(_lbl("DIRECTIVES DU PARTI · rends la run plus dure, gagne plus", 30, Color.WHITE))
	content.add_child(_lbl("Chaque niveau de directive ajoute de la ferveur : +15 % de médailles par point. Meilleure victoire : ferveur %d." % Meta.data["directives_best"], 20, Color(0.75, 0.75, 0.75)))
	for id in Meta.DIRECTIVES:
		var dd: Dictionary = Meta.DIRECTIVES[id]
		var lv := int(Meta.run_directives.get(id, 0))
		var b := _btn("%s %d/%d" % ["ACTIVE" if lv > 0 else "inactive", lv, dd["max"]], 20)
		b.pressed.connect(func():
			var n := (int(Meta.run_directives.get(id, 0)) + 1) % (int(dd["max"]) + 1)
			if n == 0: Meta.run_directives.erase(id)
			else: Meta.run_directives[id] = n
			_refresh())
		content.add_child(_row([b, _lbl("%s (+%d ferveur) : %s" % [dd["name"], dd["ferveur"], dd["desc"]], 22, Color(1, 0.6, 0.4) if lv > 0 else Color(0.9, 0.88, 0.84))]))
	content.add_child(_lbl("Ferveur totale : %d" % Meta.ferveur(Meta.run_directives), 26, Color(1, 0.85, 0.35)))

func _launch():
	Meta.save()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ---------------------------------------------------------------- bot (simulation of many runs)
func _bot_step():
	if runs_target > 0 and int(Meta.data["runs"]) >= runs_target:
		_bot_summary()
		get_tree().quit()
		return
	_bot_spend()
	var unlocked := []
	for c in Meta.CHARACTERS:
		if Meta.data["chars"][c]["unlocked"]: unlocked.append(c)
	Meta.run_char = unlocked[int(Meta.data["runs"]) % unlocked.size()]
	Meta.run_directives = {}
	if bot_dirs:
		var f := int(Meta.data["wins"]) - 1
		var order := ["productivisme", "cadence", "sans_pitie", "lutte", "penurie", "productivisme", "cadence", "sans_pitie"]
		for i in clampi(f, 0, order.size()):
			Meta.run_directives[order[i]] = int(Meta.run_directives.get(order[i], 0)) + 1
	_launch()

func _bot_spend():
	var changed := true
	while changed:
		changed = false
		var best = null
		var best_cost := 1 << 30
		for id in Meta.BUREAU:
			var r := Meta.bureau_rank(id)
			if r < Meta.BUREAU[id]["max"] and Meta.bureau_cost(id, r) < best_cost:
				best_cost = Meta.bureau_cost(id, r); best = ["bureau", id]
		for c in Meta.CHARACTERS:
			if not Meta.data["chars"][c]["unlocked"] and Meta.CHARACTERS[c]["cost"] < best_cost:
				best_cost = Meta.CHARACTERS[c]["cost"]; best = ["char", c]
		for w in Meta.WEAPON_UNLOCK:
			if not Meta.weapon_unlocked(w) and Meta.WEAPON_UNLOCK[w] < best_cost:
				best_cost = Meta.WEAPON_UNLOCK[w]; best = ["weapon", w]
		if best != null and best_cost <= int(Meta.data["medals"]):
			match best[0]:
				"bureau": changed = Meta.buy_bureau(best[1])
				"char": changed = Meta.unlock_char(best[1])
				"weapon": changed = Meta.unlock_weapon(best[1])
	for c in Meta.CHARACTERS:
		var guard := 0
		while Meta.talent_points_free(c) > 0 and guard < 20:
			guard += 1
			var t: Array = Meta.data["chars"][c]["talents"]
			var bi := 0
			for i in 3:
				if int(t[i]) < int(t[bi]): bi = i
			if not Meta.buy_talent(c, bi): break
	for m in Meta.MODULES:
		if Meta.module_available(m):
			Meta.equip_module(Meta.MODULES[m][0], m)

func _bot_summary():
	var d: Dictionary = Meta.data
	var b := []
	for id in d["bureau"]: b.append("%s%d" % [id, d["bureau"][id]])
	var cl := []
	for c in d["chars"]:
		if d["chars"][c]["unlocked"]: cl.append("%s:lv%d" % [c, Meta.char_level(c)])
	var ml := []
	for w in Data.WEAPONS: ml.append("%s:%d" % [w, Meta.weapon_mastery(w)])
	print("[meta-summary] runs=%d wins=%d best=%d medals=%d bureau=%s chars=%s mastery=%s plan=%d" % [d["runs"], d["wins"], int(d["best_time"]), d["medals"], ",".join(b), ",".join(cl), ",".join(ml), d["plan_no"]])
