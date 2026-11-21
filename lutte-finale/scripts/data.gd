class_name Data
# Game content definitions (prototype).

const MAX_WEAPON_LV := 8
const WEAPON_SLOTS := 4
const DECRET_SLOTS := 4

const WEAPONS := {
	"marteau": {
		"name": "Marteau",
		"desc": "Onde de choc autour de toi. Double dégâts quand tu retombes d'un saut.",
		"dmg": 26.0, "cd": 2.0, "area": 3.4,
	},
	"kalach": {
		"name": "Kalach",
		"desc": "Rafales vers l'ennemi le plus proche. Simple, fiable, populaire.",
		"dmg": 11.0, "cd": 0.5, "count": 1, "speed": 30.0, "pierce": 0,
	},
	"faucille": {
		"name": "Faucille",
		"desc": "Part en arc et revient. Traverse tout sur son passage.",
		"dmg": 18.0, "cd": 2.4, "count": 1, "range": 9.0,
	},
	"molotov": {
		"name": "Cocktail Molotov",
		"desc": "Lancé dans la foule, laisse une flaque de feu.",
		"dmg": 7.0, "cd": 3.2, "count": 1, "area": 2.4, "duration": 3.0,
	},
}

const DECRETS := {
	"productivite": {"name": "Productivité", "desc": "+15 % de dégâts.", "max": 5},
	"cadence": {"name": "Cadence", "desc": "Les armes se rechargent 8 % plus vite.", "max": 5},
	"collectivisation": {"name": "Collectivisation", "desc": "+1 projectile pour les armes qui tirent.", "max": 3},
	"expansion": {"name": "Expansion", "desc": "+15 % de taille des zones d'effet.", "max": 5},
	"endurance": {"name": "Endurance", "desc": "+25 PV max, et soigne 25 PV.", "max": 5},
	"vitesse": {"name": "Vitesse", "desc": "+8 % de vitesse de course.", "max": 5},
	"aimant": {"name": "Aimant", "desc": "+40 % de rayon de ramassage.", "max": 5},
	"propagande": {"name": "Propagande", "desc": "+15 % d'XP gagnée.", "max": 5},
}

# model, height, hp, speed, dmg, xp, radius, accessories
const ENEMIES := {
	"stagiaire": {"name": "Stagiaire", "models": ["character-male-a", "character-female-a", "character-male-f"], "h": 1.5, "hp": 9.0, "speed": 3.6, "dmg": 6.0, "xp": 1, "r": 0.45, "acc": []},
	"cadre": {"name": "Cadre", "models": ["character-male-d", "character-female-d"], "h": 1.75, "hp": 20.0, "speed": 3.1, "dmg": 9.0, "xp": 2, "r": 0.5, "acc": ["tophat"]},
	"trader": {"name": "Trader", "models": ["character-male-e", "character-female-e"], "h": 1.7, "hp": 15.0, "speed": 4.7, "dmg": 8.0, "xp": 2, "r": 0.48, "acc": ["sunglasses"]},
	"golden": {"name": "Golden Boy", "models": ["character-male-d"], "h": 3.2, "hp": 380.0, "speed": 2.7, "dmg": 18.0, "xp": 30, "r": 1.0, "acc": ["tophat", "cigar", "monocle"], "elite": true},
	"boss": {"name": "Le Directeur Black Friday", "models": ["character-male-d"], "h": 5.6, "hp": 14000.0, "speed": 3.0, "dmg": 30.0, "xp": 120, "r": 1.7, "acc": ["tophat", "cigar"], "boss": true},
	"fisc": {"name": "Contrôleur Fiscal", "models": ["character-male-c"], "h": 2.2, "hp": 1.0, "speed": 6.2, "dmg": 45.0, "xp": 0, "r": 0.6, "acc": ["cap", "sunglasses"], "invincible": true},
}

static func xp_to_next(level: int) -> int:
	return 5 + (level - 1) * 6 + int(pow(level, 1.5))

static func weapon_stats(id: String, lv: int) -> Dictionary:
	var b: Dictionary = WEAPONS[id].duplicate()
	var l := float(lv - 1)
	b["dmg"] = b["dmg"] * (1.0 + 0.22 * l)
	b["cd"] = b["cd"] * pow(0.94, l)
	if b.has("count"): b["count"] = b["count"] + int(lv / 3)
	if b.has("area"): b["area"] = b["area"] * (1.0 + 0.07 * l)
	if b.has("pierce"): b["pierce"] = b["pierce"] + int(lv / 4)
	if b.has("duration"): b["duration"] = b["duration"] + 0.25 * l
	return b

static func weapon_level_text(id: String, lv: int) -> String:
	match id:
		"marteau": return "+dégâts, zone plus grande, recharge plus rapide."
		"kalach": return "+dégâts, tire plus vite%s." % (", +1 balle" if lv % 3 == 0 else "")
		"faucille": return "+dégâts%s." % (", +1 faucille" if lv % 3 == 0 else ", recharge plus rapide")
		"molotov": return "+dégâts, flaque plus grande et plus longue%s." % (", +1 bouteille" if lv % 3 == 0 else "")
	return "+dégâts."
