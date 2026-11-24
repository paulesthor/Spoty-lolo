class_name Data
# Game content definitions.

const MAX_WEAPON_LV := 10
const WEAPON_SLOTS := 4
const MAX_SLOTS := 6
const DECRET_SLOTS := 4
const DECRET_MAX_PICKS := 6
const EVO_MIN_LV := 6

const RARITIES := ["COMMUN", "RARE", "ÉPIQUE", "LÉGENDAIRE"]
const RARITY_MULT := [1.0, 1.6, 2.3, 3.2]
const RARITY_COLORS := [Color(0.75, 0.75, 0.72), Color(0.35, 0.65, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.72, 0.2)]

# tags: projectile, zone, feu, orbital, melee
const WEAPONS := {
	"marteau": {
		"name": "Marteau", "tags": ["zone", "melee"],
		"desc": "Onde de choc autour de toi. Double dégâts quand tu retombes d'un saut.",
		"dmg": 27.0, "cd": 2.2, "area": 3.4,
		"ups": ["dmg", "cd", "area"],
		"evo": "expansion", "evo_name": "Marteau-Pilon", "evo_desc": "Deux ondes de choc, plus larges, qui étourdissent.",
	},
	"kalach": {
		"name": "Kalach", "tags": ["projectile"],
		"desc": "Rafales vers l'ennemi le plus proche. Faible contre les blindés.",
		"dmg": 13.8, "cd": 0.55, "count": 1, "speed": 32.0, "pierce": 0,
		"ups": ["dmg", "cd", "count", "pierce"],
		"evo": "perforation", "evo_name": "Rafale du Peuple", "evo_desc": "+2 balles, +3 perforations, tire bien plus vite.",
	},
	"faucille": {
		"name": "Faucille", "tags": ["projectile"],
		"desc": "Part en arc et revient. Traverse tout sur son passage.",
		"dmg": 13.6, "cd": 2.4, "count": 1, "range": 9.0,
		"ups": ["dmg", "cd", "count", "range"],
		"evo": "collectivisation", "evo_name": "Moisson Rouge", "evo_desc": "+3 faucilles en éventail, portée accrue.",
	},
	"molotov": {
		"name": "Cocktail Molotov", "tags": ["zone", "feu"],
		"desc": "Lancé dans la foule, laisse une flaque de feu. Ignore l'armure.",
		"dmg": 3.6, "cd": 3.2, "count": 1, "area": 2.4, "duration": 3.0,
		"ups": ["dmg", "cd", "count", "area", "duration"],
		"evo": "duree", "evo_name": "Révolution Incendiaire", "evo_desc": "Flaques énormes qui durent bien plus longtemps.",
	},
	"matriochka": {
		"name": "Matriochka", "tags": ["projectile"],
		"desc": "Une poupée qui explose en poupées plus petites, qui explosent à leur tour.",
		"dmg": 22.0, "cd": 2.0, "count": 1, "split": 3, "depth": 1,
		"ups": ["dmg", "cd", "count", "split"],
		"evo": "critique", "evo_name": "Poupée Infinie", "evo_desc": "Un niveau d'explosion de plus, plus de poupées.",
	},
	"spoutnik": {
		"name": "Spoutnik", "tags": ["orbital"],
		"desc": "Des satellites tournent autour de toi et percutent les ennemis.",
		"dmg": 9.0, "cd": 0.5, "count": 1, "area": 3.2,
		"ups": ["dmg", "count", "area", "cd"],
		"evo": "productivite", "evo_name": "Constellation", "evo_desc": "+3 satellites et un laser sur l'ennemi le plus proche.",
	},
	"samovar": {
		"name": "Samovar", "tags": ["zone"],
		"desc": "Thé bouillant autour de toi : dégâts continus et ralentissement.",
		"dmg": 11.2, "cd": 0.5, "area": 2.8,
		"ups": ["dmg", "area", "cd"],
		"evo": "endurance", "evo_name": "Grand Samovar", "evo_desc": "Zone plus grande, et chaque brûlure te soigne un peu.",
	},
	"hautparleur": {
		"name": "Haut-parleur", "tags": ["zone"],
		"desc": "Cône de propagande devant toi : dégâts, recul et étourdissement.",
		"dmg": 16.0, "cd": 1.7, "area": 7.0,
		"ups": ["dmg", "cd", "area"],
		"evo": "cadence", "evo_name": "Radio d'État", "evo_desc": "Diffusion à 360° et recharge bien plus rapide.",
	},
	"tracteur": {
		"name": "Tracteur du Kolkhoze", "tags": ["projectile", "melee"],
		"desc": "Un tracteur fonce en ligne droite à travers la foule et écrase tout. Il ne freine jamais.",
		"dmg": 26.0, "cd": 3.6, "count": 1, "area": 1.6, "speed": 17.0, "range": 26.0,
		"ups": ["dmg", "cd", "count", "area"],
		"evo": "vitesse", "evo_name": "Moissonneuse-Batteuse", "evo_desc": "Deux fois plus large, +50 % de dégâts, +1 engin.",
	},
	"ours": {
		"name": "Ours de Sibérie", "tags": ["melee"],
		"desc": "Un ours apprivoisé (plus ou moins) court sur les capitalistes et les gifle.",
		"dmg": 14.0, "cd": 0.9, "count": 1, "area": 1.8, "speed": 9.0,
		"ups": ["dmg", "cd", "count", "area"],
		"evo": "endurance", "evo_name": "Grand Ours Soviétique", "evo_desc": "+1 ours, plus gros, ses gifles étourdissent.",
	},
	"vodka": {
		"name": "Vodka Frappée", "tags": ["projectile"],
		"desc": "Une bouteille qui rebondit d'un ennemi à l'autre. Elle ne se casse jamais, c'est de la qualité soviétique.",
		"dmg": 17.6, "cd": 1.6, "count": 1, "chain": 3, "speed": 20.0,
		"ups": ["dmg", "cd", "count", "chain"],
		"evo": "chance", "evo_name": "Tournée Générale", "evo_desc": "+4 rebonds, chaque rebond frappe 10 % plus fort.",
	},
	"piolet": {
		"name": "Piolet", "tags": ["melee"],
		"desc": "Grand coup en arc devant toi. Très gros dégâts, courte portée.",
		"dmg": 41.4, "cd": 1.1, "area": 4.6,
		"ups": ["dmg", "cd", "area"],
		"evo": "critique", "evo_name": "Pic à Glace Révolutionnaire", "evo_desc": "Frappe tout autour de toi, deux fois de suite.",
	},
	"rideau": {
		"name": "Rideau de Fer", "tags": ["zone"],
		"desc": "Un mur d'acier surgit devant toi : il repousse et broie ceux qui le touchent.",
		"dmg": 15.6, "cd": 6.0, "area": 4.0, "duration": 4.0,
		"ups": ["dmg", "cd", "area", "duration"],
		"evo": "armure", "evo_name": "Frontière Infranchissable", "evo_desc": "Quatre murs t'encerclent et protègent le camarade.",
	},
	"t34": {
		"name": "Char du Peuple", "tags": ["projectile", "zone"],
		"desc": "Un obus lent qui explose à l'impact. Les capitalistes détestent les grosses explosions.",
		"dmg": 40.0, "cd": 2.8, "count": 1, "area": 2.6, "speed": 16.0,
		"ups": ["dmg", "cd", "count", "area"],
		"evo": "productivite", "evo_name": "Division Blindée", "evo_desc": "+2 obus, explosions 30 % plus grandes.",
	},
	"katioucha": {
		"name": "Orgue du Peuple", "tags": ["zone"],
		"desc": "Une salve de roquettes tombe du ciel sur les ennemis autour de toi.",
		"dmg": 27.0, "cd": 3.5, "count": 4, "area": 1.8,
		"ups": ["dmg", "cd", "count", "area"],
		"evo": "collectivisation", "evo_name": "Salve Infinie", "evo_desc": "Deux fois plus de roquettes.",
	},
	"balalaika": {
		"name": "Balalaïka", "tags": ["projectile"],
		"desc": "Des notes têtes chercheuses. Personne n'échappe à la musique folklorique.",
		"dmg": 15.3, "cd": 0.75, "count": 3, "speed": 15.0, "pierce": 0,
		"ups": ["dmg", "cd", "count", "pierce"],
		"evo": "propagande", "evo_name": "Chœur de l'Armée Rouge", "evo_desc": "+3 notes qui traversent 2 ennemis.",
	},
	"goulag": {
		"name": "Goulag Portatif", "tags": ["zone"],
		"desc": "Une cage tombe sur un groupe d'ennemis : ils sont immobilisés et prennent des dégâts. Rééducation express.",
		"dmg": 16.0, "cd": 7.0, "area": 3.0, "duration": 3.0,
		"ups": ["dmg", "cd", "area", "duration"],
		"evo": "duree", "evo_name": "Archipel", "evo_desc": "Trois cages à chaque fois.",
	},
	"etoile": {
		"name": "Étoile Rouge", "tags": ["zone"],
		"desc": "Une étoile tombe sur l'ennemi le plus coriace. Idéale contre les élites et les boss.",
		"dmg": 72.0, "cd": 3.0, "area": 2.2,
		"ups": ["dmg", "cd", "area"],
		"evo": "chance", "evo_name": "Pluie d'Étoiles", "evo_desc": "Trois étoiles, sur les trois ennemis les plus coriaces.",
	},
	"tracts": {
		"name": "Tracts de Propagande", "tags": ["projectile"],
		"desc": "Des tracts partent en spirale autour de toi. Lire, c'est déjà se rendre.",
		"dmg": 19.2, "cd": 0.45, "count": 2, "speed": 11.0, "pierce": 1,
		"ups": ["dmg", "cd", "count", "pierce"],
		"evo": "perforation", "evo_name": "Pluie de Tracts", "evo_desc": "Deux fois plus de tracts, qui traversent tout.",
	},
	"cigare": {
		"name": "Havane Explosif", "tags": ["projectile", "zone"],
		"desc": "Un cigare se colle sur un ennemi puis explose. Fumer tue (surtout les autres).",
		"dmg": 51.0, "cd": 1.8, "count": 1, "area": 2.2, "speed": 18.0,
		"ups": ["dmg", "cd", "count", "area"],
		"evo": "aimant", "evo_name": "Boîte de Havanes", "evo_desc": "Chaque explosion en déclenche trois autres autour.",
	},
}

# fusions (Survivor.io-style union): two weapons at level 6+ merge into one slot, both keep firing (+25 % damage) with a bonus effect
const FUSIONS := {
	"faucille_marteau": {"a": "marteau", "b": "faucille", "name": "Faucille et Marteau", "desc": "Chaque onde de choc projette une couronne de faucilles."},
	"armee_rouge": {"a": "kalach", "b": "t34", "name": "Armée Rouge", "desc": "Les balles du Kalach explosent à l'impact."},
	"cocktail_luxe": {"a": "molotov", "b": "vodka", "name": "Cocktail de Luxe", "desc": "Chaque rebond de la Vodka laisse une flaque de feu."},
	"conquete_spatiale": {"a": "spoutnik", "b": "etoile", "name": "Conquête Spatiale", "desc": "Les satellites font tomber une étoile toutes les 2 s."},
	"ours_tractoriste": {"a": "tracteur", "b": "ours", "name": "Ours Tractoriste", "desc": "Chaque ours lance aussi son propre tracteur."},
	"poupees_balistiques": {"a": "matriochka", "b": "katioucha", "name": "Poupées Balistiques", "desc": "Chaque roquette libère des matriochkas en explosant."},
	"datcha_infernale": {"a": "samovar", "b": "goulag", "name": "Datcha Infernale", "desc": "Les cages ébouillantent : leurs dégâts sont triplés et elles ralentissent autour."},
	"symphonie": {"a": "hautparleur", "b": "balalaika", "name": "Propagande Symphonique", "desc": "Les notes étourdissent et chaque discours lance 6 notes."},
}

static func fusion_of(w: String) -> String:
	for f in FUSIONS:
		if FUSIONS[f]["a"] == w or FUSIONS[f]["b"] == w: return f
	return ""

# value per card (multiplied by rarity). "int": value floored per rarity table
const DECRETS := {
	"productivite": {"name": "Productivité", "fmt": "+%d %% de dégâts", "base": 10.0, "pct": true},
	"cadence": {"name": "Cadence", "fmt": "+%d %% de vitesse d'attaque", "base": 8.0, "pct": true},
	"collectivisation": {"name": "Collectivisation", "fmt": "+%d projectile(s) (armes à projectiles, roquettes, ours)", "base": 1.0, "int": true},
	"perforation": {"name": "Perforation", "fmt": "Les projectiles traversent +%d ennemi(s)", "base": 1.0, "int": true},
	"expansion": {"name": "Expansion", "fmt": "+%d %% de taille des zones (max +60 %%)", "base": 9.0, "pct": true},
	"duree": {"name": "Plan Quinquennal", "fmt": "+%d %% de durée des effets", "base": 15.0, "pct": true},
	"critique": {"name": "Zèle", "fmt": "+%d %% de chances de coup critique", "base": 6.0, "pct": true},
	"endurance": {"name": "Endurance", "fmt": "+%d PV max", "base": 20.0},
	"armure": {"name": "Chapka Blindée", "fmt": "-%d dégâts reçus par coup", "base": 1.5},
	"vitesse": {"name": "Stakhanovisme", "fmt": "+%d %% de vitesse de course", "base": 7.0, "pct": true},
	"aimant": {"name": "Aimant", "fmt": "+%d %% de rayon de ramassage", "base": 35.0, "pct": true},
	"propagande": {"name": "Propagande", "fmt": "+%d %% d'XP gagnée", "base": 12.0, "pct": true},
	"chance": {"name": "Chance", "fmt": "+%d %% de chance (raretés, butin)", "base": 10.0, "pct": true},
}

# Enemy roster. ai: chase | charger | ranged | lobber | summoner | slammer
# on_hit: status applied to the player on contact (slow, seize, blind)
const ENEMIES := {
	"stagiaire": {"name": "Stagiaire", "models": ["character-male-a", "character-female-a", "character-male-f"], "h": 1.5, "hp": 10.0, "speed": 3.7, "dmg": 6.0, "xp": 1, "r": 0.45, "armor": 0.0, "acc": []},
	"cadre": {"name": "Cadre", "models": ["character-male-d", "character-female-d"], "h": 1.75, "hp": 26.0, "speed": 3.1, "dmg": 10.0, "xp": 2, "r": 0.5, "armor": 2.0, "acc": ["tophat"]},
	"trader": {"name": "Trader", "models": ["character-male-e", "character-female-e"], "h": 1.7, "hp": 22.0, "speed": 3.6, "dmg": 14.0, "xp": 3, "r": 0.48, "armor": 0.0, "acc": ["sunglasses"], "ai": "charger"},
	"influenceur": {"name": "Influenceur", "models": ["character-female-b", "character-female-c"], "h": 1.6, "hp": 18.0, "speed": 3.4, "dmg": 5.0, "xp": 3, "r": 0.45, "armor": 0.0, "acc": ["sunglasses"], "ai": "ranged", "shot": "blind"},
	"banquier": {"name": "Banquier", "models": ["character-male-d"], "h": 1.8, "hp": 40.0, "speed": 2.6, "dmg": 4.0, "xp": 4, "r": 0.5, "armor": 2.0, "acc": ["tophat", "monocle"], "ai": "lobber", "tint": Color(0.2, 0.3, 0.22)},
	"crypto": {"name": "Crypto-bro", "models": ["character-male-f", "character-male-a"], "h": 1.65, "hp": 28.0, "speed": 4.2, "dmg": 8.0, "xp": 3, "r": 0.48, "armor": 0.0, "acc": ["cap", "sunglasses"], "explode": 14.0},
	"avocat": {"name": "Avocat d'affaires", "models": ["character-male-c", "character-female-d"], "h": 1.8, "hp": 55.0, "speed": 2.7, "dmg": 12.0, "xp": 4, "r": 0.55, "armor": 9.0, "acc": ["sunglasses"], "tint": Color(0.25, 0.25, 0.32), "on_hit": "slow"},
	"huissier": {"name": "Huissier", "models": ["character-male-g"], "h": 1.75, "hp": 35.0, "speed": 4.6, "dmg": 8.0, "xp": 4, "r": 0.5, "armor": 2.0, "acc": ["sunglasses", "cap"], "on_hit": "seize", "tint": Color(0.15, 0.15, 0.17)},
	"coach": {"name": "Coach en motivation", "models": ["character-female-e", "character-male-e"], "h": 1.75, "hp": 45.0, "speed": 3.0, "dmg": 9.0, "xp": 5, "r": 0.5, "armor": 1.0, "acc": ["cap"], "healer": true, "tint": Color(0.95, 0.55, 0.2)},
	"lobbyiste": {"name": "Lobbyiste", "models": ["character-female-d", "character-male-d"], "h": 1.8, "hp": 50.0, "speed": 2.9, "dmg": 10.0, "xp": 5, "r": 0.5, "armor": 3.0, "acc": ["tophat"], "shield_aura": true, "tint": Color(0.55, 0.45, 0.7)},
	"drh": {"name": "DRH", "models": ["character-female-f"], "h": 1.75, "hp": 60.0, "speed": 2.4, "dmg": 8.0, "xp": 6, "r": 0.5, "armor": 2.0, "acc": ["sunglasses"], "ai": "summoner"},
	"actionnaire": {"name": "Actionnaire", "models": ["character-male-d"], "h": 2.6, "hp": 240.0, "speed": 2.2, "dmg": 22.0, "xp": 12, "r": 0.85, "armor": 5.0, "acc": ["tophat", "cigar"], "ai": "slammer"},
	"golden": {"name": "Golden Boy", "models": ["character-male-d"], "h": 3.2, "hp": 420.0, "speed": 2.8, "dmg": 18.0, "xp": 30, "r": 1.0, "armor": 3.0, "acc": ["tophat", "cigar", "monocle"], "elite": true},
	"boss": {"name": "Le Directeur Black Friday", "models": ["character-male-d"], "h": 5.6, "hp": 32000.0, "speed": 3.1, "dmg": 30.0, "xp": 150, "r": 1.7, "armor": 6.0, "acc": ["tophat", "cigar"], "boss": true},
	"boss2": {"name": "Le PDG Vertical", "models": [], "h": 6.0, "hp": 52000.0, "speed": 3.3, "dmg": 34.0, "xp": 200, "r": 1.8, "armor": 8.0, "acc": ["tophat", "sunglasses"], "boss": true},
	"boss3": {"name": "La Main Invisible", "models": [], "h": 6.6, "hp": 80000.0, "speed": 3.5, "dmg": 40.0, "xp": 300, "r": 1.9, "armor": 10.0, "acc": ["tophat", "monocle", "cigar"], "boss": true},
	# zone signatures (see Levels "roster"): each zone has its own capitalist with its own trick
	"chef_rayon": {"name": "Chef de rayon", "models": [], "h": 1.7, "hp": 24.0, "speed": 3.1, "dmg": 6.0, "xp": 3, "r": 0.48, "armor": 1.0, "acc": ["cap"], "ai": "fan",
		"hint": "lance ses étiquettes de prix en éventail"},
	"consultant": {"name": "Consultant", "models": [], "h": 1.75, "hp": 30.0, "speed": 3.0, "dmg": 3.0, "xp": 3, "r": 0.48, "armor": 1.0, "acc": ["round_glasses"], "ai": "lobber", "lob": "slow",
		"hint": "jette des PowerPoint qui t'engluent (ralentissement)"},
	"daytrader": {"name": "Day-trader", "models": [], "h": 1.7, "hp": 34.0, "speed": 3.3, "dmg": 11.0, "xp": 4, "r": 0.48, "armor": 0.0, "acc": ["sunglasses"], "ai": "bullbear",
		"hint": "haussier il fonce, baissier il se blinde : frappe-le quand il fonce"},
	"evade": {"name": "Évadé fiscal", "models": [], "h": 1.7, "hp": 30.0, "speed": 3.8, "dmg": 9.0, "xp": 4, "r": 0.48, "armor": 0.0, "acc": ["sunglasses"], "blink": true,
		"hint": "se téléporte quand on le frappe : achève-le vite"},
	"livreur": {"name": "Livreur auto-entrepreneur", "models": [], "h": 1.7, "hp": 22.0, "speed": 4.2, "dmg": 12.0, "xp": 3, "r": 0.48, "armor": 0.0, "acc": ["cap"], "ai": "courier",
		"hint": "traverse la carte en ligne droite, sans s'arrêter (il est payé à la course)"},
	"moderateur": {"name": "Modérateur IA", "models": [], "h": 1.75, "hp": 28.0, "speed": 2.8, "dmg": 14.0, "xp": 4, "r": 0.48, "armor": 2.0, "acc": [], "ai": "beamer",
		"hint": "te scanne puis tire un rayon : sors de la ligne rouge"},
	"moniteur": {"name": "Moniteur de ski", "models": [], "h": 1.75, "hp": 32.0, "speed": 3.2, "dmg": 12.0, "xp": 4, "r": 0.48, "armor": 1.0, "acc": ["sunglasses"], "ai": "roller",
		"hint": "fait rouler des boules de neige géantes"},
	"touriste": {"name": "Touriste spatial", "models": [], "h": 1.75, "hp": 36.0, "speed": 2.9, "dmg": 14.0, "xp": 4, "r": 0.5, "armor": 2.0, "acc": [], "ai": "leaper",
		"hint": "bondit en apesanteur et retombe sur toi : sors du cercle"},
	"pretorien": {"name": "Garde prétorien", "models": [], "h": 1.95, "hp": 70.0, "speed": 3.0, "dmg": 16.0, "xp": 6, "r": 0.55, "armor": 6.0, "acc": ["sunglasses"], "ai": "bulldozer",
		"hint": "charge puis frappe le sol au bout de sa course"},
	"pretenom": {"name": "Prête-nom", "models": [], "h": 1.8, "hp": 260.0, "speed": 0.0, "dmg": 0.0, "xp": 6, "r": 0.55, "armor": 2.0, "acc": ["tophat"], "ai": "static"},
	"fisc": {"name": "Contrôleur Fiscal", "models": ["character-male-c"], "h": 2.2, "hp": 1.0, "speed": 6.4, "dmg": 45.0, "xp": 0, "r": 0.6, "armor": 0.0, "acc": ["cap", "sunglasses"], "invincible": true},
}

# spawn table: [kind, from_time, weight_at_start, weight_growth_per_min]
const SPAWN_TABLE := [
	["stagiaire", 0.0, 6.0, 0.0],
	["cadre", 20.0, 2.0, 0.6],
	["trader", 90.0, 1.0, 0.35],
	["influenceur", 120.0, 1.0, 0.3],
	["crypto", 150.0, 1.0, 0.3],
	["avocat", 180.0, 1.0, 0.4],
	["banquier", 210.0, 0.7, 0.25],
	["huissier", 240.0, 0.7, 0.25],
	["coach", 270.0, 0.5, 0.15],
	["lobbyiste", 300.0, 0.5, 0.15],
	["drh", 330.0, 0.35, 0.1],
	["actionnaire", 360.0, 0.4, 0.2],
]

static func xp_to_next(level: int) -> int:
	return 5 + 4 * level + int(0.45 * level * level)

static func int_bonus(rarity: int) -> int:
	return [1, 1, 2, 3][rarity]

# per-stat increment of a weapon upgrade at a given rarity
static func weapon_up_value(stat: String, rarity: int) -> float:
	var m: float = RARITY_MULT[rarity]
	match stat:
		"dmg": return 0.15 * m
		"cd": return 0.07 * m
		"area": return 0.07 * m
		"range": return 0.12 * m
		"duration": return 0.15 * m
		"count", "pierce", "split", "chain": return float(int_bonus(rarity))
	return 0.0

static func weapon_up_text(stat: String, v: float) -> String:
	match stat:
		"dmg": return "+%d %% dégâts" % roundi(v * 100)
		"cd": return "+%d %% cadence" % roundi(v * 100)
		"area": return "+%d %% zone" % roundi(v * 100)
		"range": return "+%d %% portée" % roundi(v * 100)
		"duration": return "+%d %% durée" % roundi(v * 100)
		"count": return "+%d projectile(s)" % int(v)
		"pierce": return "+%d perforation" % int(v)
		"split": return "+%d poupée(s) par explosion" % int(v)
		"chain": return "+%d rebond(s)" % int(v)
	return ""

static func decret_value(id: String, rarity: int) -> float:
	var d: Dictionary = DECRETS[id]
	if d.get("int", false): return float(int_bonus(rarity))
	return roundf(d["base"] * RARITY_MULT[rarity] * 10.0) / 10.0

static func decret_text(id: String, v: float) -> String:
	var d: Dictionary = DECRETS[id]
	if d.get("int", false) or d.get("pct", false) or fmod(v, 1.0) == 0.0:
		return d["fmt"] % roundi(v)
	return (d["fmt"] as String).replace("%d", "%.1f") % v
