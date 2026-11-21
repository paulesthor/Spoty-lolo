extends Node
# Meta-progression (autoload "Meta"): save file, characters & talents, Bureau du Plan,
# weapon mastery & modules, Plan quinquennal (quotas), Directives du Parti.

const SAVE_VERSION := 1
var save_path := "user://lutte_finale_save.json"
var data := {}

# run configuration chosen in the Kolkhoze
var run_char := "stakhanov"
var run_directives := {}     # id -> level
var run_zone := 1            # zone the next game scene builds
var run_tier := 1            # difficulty tier (1..3)
var run_endless := false
var carry := {}              # run state carried from one zone to the next

const TIERS := [
	{"name": "Camarade", "hp": 1.0, "dmg": 1.0, "rate": 1.0, "medals": 1.0, "desc": "La difficulté normale."},
	{"name": "Commissaire", "hp": 1.6, "dmg": 1.3, "rate": 1.15, "medals": 1.6, "desc": "Ennemis +60 % PV, +30 % dégâts, plus nombreux. Médailles x1.6."},
	{"name": "Héros de l'Union", "hp": 2.5, "dmg": 1.6, "rate": 1.3, "medals": 2.4, "desc": "Ennemis x2.5 PV, +60 % dégâts, encore plus nombreux. Médailles x2.4."},
]

func tier_unlocked(t: int) -> bool:
	return t <= int(data.get("tier_max", 1))

func zone_unlocked(z: int) -> bool:
	return z <= 1 or int(data.get("bosses", {}).get(str(z - 1), 0)) > 0

func endless_unlocked() -> bool:
	return int(data.get("wins", 0)) > 0

# ---------------------------------------------------------------- characters
const CHARACTERS := {
	"stakhanov": {
		"name": "Stakhanov", "model": "character-worker", "acc": [], "cost": 0, "weapon": "marteau",
		"passive": "Dépasser les quotas : +2 % de cadence tous les 150 ennemis bonkés (max +20 %).",
		"ult": "Surproduction", "ult_desc": "Cadence x2 pendant 6 s.",
		"base": {},
		"tree": [
			["Ouvrier modèle", [["cadence", 5], ["productivite", 6], ["cadence", 5], ["productivite", 8], ["ult_power", 30]]],
			["Mineur de fond", [["endurance", 20], ["armure", 1.5], ["endurance", 20], ["regen", 0.4], ["slam_bonus", 50]]],
			["Brigade de choc", [["vitesse", 5], ["aimant", 25], ["ult_charge", 20], ["vitesse", 6], ["rubles_pct", 20]]],
		],
	},
	"ilitch": {
		"name": "Ilitch le Chauve", "model": "character-male-b", "acc": ["chapka"], "cost": 150, "weapon": "hautparleur",
		"passive": "Le théoricien : +12 % d'XP.",
		"ult": "Discours au peuple", "ult_desc": "Étourdit tous les ennemis proches 3 s. Ils subissent +50 % de dégâts.",
		"base": {"propagande": 12},
		"tree": [
			["Orateur", [["ult_charge", 15], ["ult_power", 25], ["expansion", 8], ["ult_charge", 15], ["ult_stun", 1.5]]],
			["Idéologue", [["propagande", 8], ["chance", 5], ["reroll", 1], ["propagande", 8], ["chance", 8]]],
			["Chef de parti", [["endurance", 15], ["armure", 1], ["regen", 0.3], ["endurance", 20], ["revive", 1]]],
		],
	},
	"moustache": {
		"name": "Petit Père Moustache", "model": "character-male-g", "acc": ["chapka"], "cost": 250, "weapon": "kalach",
		"passive": "Le paranoïaque : +8 % de coup critique.",
		"ult": "Grande Purge", "ult_desc": "Élimine tous les ennemis normaux à moins de 14 m. Coûte 15 % de tes PV actuels.",
		"base": {"critique": 8},
		"tree": [
			["Purge", [["critique", 4], ["productivite", 6], ["critique", 5], ["ult_charge", 20], ["crit_dmg", 50]]],
			["Paranoïa", [["vitesse", 6], ["armure", 1], ["dodge", 8], ["vitesse", 6], ["dodge", 7]]],
			["Culte de la personnalité", [["chance", 6], ["rubles_pct", 15], ["chest_discount", 15], ["chance", 8], ["start_level", 2]]],
		],
	},
	"babouchka": {
		"name": "Babouchka Olga", "model": "character-female-f", "acc": ["chapka"], "cost": 350, "weapon": "samovar",
		"passive": "Elle a connu pire : +40 PV, régénération +0.6/s, mais -10 % de vitesse.",
		"ult": "Elle a connu pire", "ult_desc": "Invincible 4 s et soin complet.",
		"base": {"endurance": 40, "regen": 0.6, "vitesse": -10},
		"tree": [
			["Fourneau", [["expansion", 8], ["productivite", 6], ["duree", 12], ["expansion", 10], ["ult_power", 30]]],
			["Datcha", [["endurance", 25], ["regen", 0.4], ["armure", 1.5], ["endurance", 30], ["revive", 1]]],
			["Grand-mère", [["aimant", 30], ["propagande", 8], ["heal_pickup", 50], ["propagande", 8], ["chance", 8]]],
		],
	},
	"barbudo": {
		"name": "Comandante Barbudo", "model": "", "acc": [], "cost": 450, "weapon": "cigare",
		"passive": "Révolution permanente : +3 % de dégâts par élite ou boss abattu (max +30 %).",
		"ult": "¡Viva la Revolución!", "ult_desc": "Pendant 8 s, chaque ennemi tué explose et blesse ses voisins.",
		"base": {"chance": 5},
		"tree": [
			["Guérilla", [["vitesse", 5], ["dodge", 5], ["productivite", 6], ["dodge_cd", 15], ["ult_power", 30]]],
			["Sierra", [["endurance", 20], ["regen", 0.3], ["armure", 1], ["endurance", 25], ["revive", 1]]],
			["Discours de 7 heures", [["ult_charge", 15], ["propagande", 8], ["chance", 6], ["ult_charge", 15], ["rubles_pct", 20]]],
		],
	},
	"youri": {
		"name": "Youri l'Orbital", "model": "", "acc": [], "cost": 550, "weapon": "spoutnik",
		"passive": "Apesanteur : sauts plus hauts, chute ralentie, +10 % de vitesse.",
		"ult": "Retour sur Terre", "ult_desc": "Une capsule s'écrase sur le plus gros groupe d'ennemis proche : énormes dégâts et étourdissement.",
		"base": {"vitesse": 10},
		"tree": [
			["Cosmonaute", [["expansion", 8], ["duree", 10], ["expansion", 8], ["slam_bonus", 50], ["ult_power", 30]]],
			["Entraînement", [["endurance", 20], ["vitesse", 5], ["dodge_cd", 15], ["endurance", 25], ["armure", 1.5]]],
			["Héros national", [["chance", 6], ["aimant", 25], ["ult_charge", 15], ["propagande", 8], ["start_level", 2]]],
		],
	},
}

# skins: bought in the Caserne with medals; tint of the KayKit body + extra accessories
const SKINS := {
	"stakhanov": [["Bleu de travail", Color(1, 1, 1), [], 0], ["Héros du Travail (doré)", Color(1.25, 1.05, 0.55), ["medal"], 250], ["Mineur de nuit", Color(0.45, 0.45, 0.55), [], 150]],
	"ilitch": [["Costume trois-pièces", Color(1, 1, 1), [], 0], ["Momie du Mausolée", Color(1.2, 1.15, 0.95), [], 250], ["Exil en Suisse", Color(0.7, 0.85, 1.1), ["sunglasses"], 150]],
	"moustache": [["Uniforme", Color(1, 1, 1), [], 0], ["Généralissime blanc", Color(1.4, 1.4, 1.35), ["medal"], 250], ["Camouflage d'hiver", Color(0.85, 0.95, 1.05), [], 150]],
	"babouchka": [["Tablier fleuri", Color(1, 1, 1), [], 0], ["Babouchka de combat", Color(0.6, 0.75, 0.5), ["sunglasses"], 200], ["Reine de la datcha", Color(1.3, 0.8, 0.9), [], 150]],
	"barbudo": [["Treillis", Color(0.72, 0.85, 0.55), [], 0], ["Guérillero de la plage", Color(1.2, 1.1, 0.75), ["sunglasses"], 200], ["Tenue de parade", Color(0.55, 0.65, 0.45), ["medal"], 250]],
	"youri": [["Combinaison", Color(1, 1, 1), [], 0], ["Combinaison dorée", Color(1.25, 1.05, 0.55), ["medal"], 250], ["Mission martienne", Color(1.3, 0.6, 0.45), [], 200]],
}

func skin_owned(c: String, i: int) -> bool:
	return i == 0 or (data.get("skins", {}).get(c, []) as Array).has(i)

func buy_skin(c: String, i: int) -> bool:
	var cost: int = SKINS[c][i][3]
	if skin_owned(c, i) or int(data["medals"]) < cost: return false
	data["medals"] = int(data["medals"]) - cost
	if not data.has("skins"): data["skins"] = {}
	if not data["skins"].has(c): data["skins"][c] = []
	data["skins"][c].append(i)
	data["skin_sel"] = data.get("skin_sel", {})
	data["skin_sel"][c] = i
	save()
	return true

func skin_sel(c: String) -> int:
	var i := int(data.get("skin_sel", {}).get(c, 0))
	return i if skin_owned(c, i) else 0

func set_skin(c: String, i: int):
	if not skin_owned(c, i): return
	if not data.has("skin_sel"): data["skin_sel"] = {}
	data["skin_sel"][c] = i
	save()

const STAT_NAMES := {
	"productivite": "+%s %% dégâts", "cadence": "+%s %% cadence", "expansion": "+%s %% zone", "duree": "+%s %% durée",
	"critique": "+%s %% critique", "endurance": "+%s PV max", "armure": "+%s armure", "vitesse": "+%s %% vitesse",
	"aimant": "+%s %% ramassage", "propagande": "+%s %% XP", "chance": "+%s %% chance", "regen": "+%s PV/s",
	"ult_charge": "ultime %s %% plus vite", "ult_power": "ultime +%s %% plus fort", "ult_stun": "+%s s d'étourdissement (ultime)",
	"slam_bonus": "+%s %% dégâts d'atterrissage", "rubles_pct": "+%s %% roubles", "reroll": "+%s relance",
	"revive": "+%s résurrection", "banish": "+%s bannissement", "skip": "+%s « passer »", "dodge_cd": "esquive %s %% plus fréquente", "crit_dmg": "+%s %% dégâts critiques", "dodge": "%s %% d'esquive",
	"chest_discount": "coffres -%s %%", "start_level": "commence avec %s niveaux", "heal_pickup": "tartines +%s %%",
	"weapon_slot": "+%s emplacement d'arme",
}

static func stat_text(k: String, v) -> String:
	var vs: String = str(v) if fmod(float(v), 1.0) != 0.0 else str(int(v))
	return (STAT_NAMES.get(k, k + " %s") as String) % vs

# ---------------------------------------------------------------- Bureau du Plan
const BUREAU := {
	"rations": {"name": "Rations doublées", "stat": "endurance", "per": 10.0, "max": 5, "base": 22},
	"discipline": {"name": "Discipline de fer", "stat": "productivite", "per": 4.0, "max": 5, "base": 30},
	"cadence": {"name": "Cadences infernales", "stat": "cadence", "per": 3.0, "max": 5, "base": 30},
	"formation": {"name": "Formation politique", "stat": "propagande", "per": 5.0, "max": 5, "base": 22},
	"portee": {"name": "Grands travaux", "stat": "expansion", "per": 4.0, "max": 5, "base": 30},
	"chance": {"name": "Trèfle soviétique", "stat": "chance", "per": 4.0, "max": 5, "base": 30},
	"logistique": {"name": "Logistique", "stat": "aimant", "per": 15.0, "max": 3, "base": 15},
	"blindage": {"name": "Chapkas renforcées", "stat": "armure", "per": 0.5, "max": 4, "base": 38},
	"regen": {"name": "Soupe au chou", "stat": "regen", "per": 0.15, "max": 3, "base": 38},
	"tresor": {"name": "Caisse noire", "stat": "rubles_pct", "per": 10.0, "max": 3, "base": 22},
	"relance": {"name": "Recours administratif", "stat": "reroll", "per": 1.0, "max": 3, "base": 60},
	"bannissement": {"name": "Liste noire", "stat": "banish", "per": 1.0, "max": 3, "base": 60},
	"passer": {"name": "Dispense", "stat": "skip", "per": 1.0, "max": 3, "base": 30},
	"seconde_chance": {"name": "Seconde chance", "stat": "revive", "per": 1.0, "max": 1, "base": 450},
	"cinquieme_arme": {"name": "Cinquième arme", "stat": "weapon_slot", "per": 1.0, "max": 1, "base": 600},
}

# ---------------------------------------------------------------- Grade au Parti (account level gating)
const GRADE_NAMES := ["Sympathisant", "Militant", "Camarade", "Délégué", "Commissaire", "Secrétaire de cellule", "Membre du Comité", "Héros du Travail", "Héros de l'Union", "Père des Peuples"]
const BUREAU_GRADE := {"blindage": 2, "regen": 3, "passer": 2, "relance": 3, "bannissement": 4, "seconde_chance": 7, "cinquieme_arme": 9}
const WEAPON_GRADE := {"matriochka": 2, "samovar": 3, "hautparleur": 3, "spoutnik": 4, "vodka": 2, "piolet": 2, "tracts": 3, "cigare": 3,
	"tracteur": 4, "balalaika": 4, "ours": 5, "t34": 5, "rideau": 6, "katioucha": 6, "goulag": 7, "etoile": 7}
const CHAR_GRADE := {"stakhanov": 1, "ilitch": 2, "moustache": 4, "babouchka": 6, "barbudo": 7, "youri": 8}
const DIRECTIVES_GRADE := 3

static func grade_req(g: int) -> int:
	return 0 if g <= 1 else int(100 * pow(g, 1.6))

func grade() -> int:
	var life := int(data.get("lifetime", 0))
	var g := 1
	while g < 10 and life >= grade_req(g + 1): g += 1
	return g

func bureau_grade_req(id: String, rank: int) -> int:
	return maxi(int(BUREAU_GRADE.get(id, 1)), 1 + 2 * rank)

static func talent_level_req(i: int) -> int:
	return 1 + 3 * i

static func bureau_cost(id: String, rank: int) -> int:
	return int(round(BUREAU[id]["base"] * pow(1.7, rank)))

# ---------------------------------------------------------------- Usine d'armement
const WEAPON_UNLOCK := {"marteau": 0, "kalach": 0, "faucille": 0, "molotov": 0, "matriochka": 80, "spoutnik": 100, "samovar": 90, "hautparleur": 90,
	"vodka": 90, "piolet": 90, "tracts": 110, "cigare": 110, "tracteur": 130, "balalaika": 130, "ours": 150, "t34": 150, "rideau": 170, "katioucha": 170, "goulag": 190, "etoile": 190}
const MASTERY_XP := [0, 400, 1500, 4000, 9000, 16000]   # cumulative kills with the weapon for levels 0..5
# modules: id -> [weapon, mastery level required, name, description]
const MODULES := {
	"kalach_eventail": ["kalach", 2, "Tir en éventail", "+2 balles en éventail, -30 % de dégâts."],
	"kalach_sniper": ["kalach", 4, "Mode sniper", "1 balle énorme : x3.5 dégâts, +5 perforations, cadence /2."],
	"kalach_incendiaire": ["kalach", 5, "Balles incendiaires", "Ignorent l'armure, +15 % de dégâts."],
	"marteau_gel": ["marteau", 2, "Onde gelée", "Les ennemis touchés sont ralentis 2 s."],
	"marteau_seisme": ["marteau", 4, "Séisme", "+45 % de zone, recharge +30 %."],
	"faucille_lourde": ["faucille", 2, "Faucille lourde", "x1.7 dégâts, -1 faucille (min 1)."],
	"faucille_rafale": ["faucille", 4, "Rafale de faucilles", "+2 faucilles, -30 % de portée."],
	"molotov_napalm": ["molotov", 2, "Napalm", "Durée x2, -20 % de dégâts."],
	"molotov_grappe": ["molotov", 4, "Bouteilles à fragmentation", "+2 bouteilles, -35 % de zone."],
	"matriochka_essaim": ["matriochka", 2, "Essaim", "+2 poupées par explosion, -25 % de dégâts."],
	"matriochka_mere": ["matriochka", 4, "Mère des poupées", "+1 niveau d'explosion, recharge +40 %."],
	"spoutnik_large": ["spoutnik", 2, "Orbite haute", "+60 % de rayon d'orbite."],
	"spoutnik_tueur": ["spoutnik", 4, "Satellite tueur", "+70 % de dégâts, -1 satellite (min 1)."],
	"samovar_glace": ["samovar", 2, "Thé glacé", "Ralentit beaucoup plus, +20 % de zone, -20 % de dégâts."],
	"samovar_bouilloire": ["samovar", 4, "Bouilloire", "x1.7 dégâts, -25 % de zone."],
	"hautparleur_megaphone": ["hautparleur", 2, "Mégaphone", "+50 % de portée."],
	"hautparleur_larsen": ["hautparleur", 4, "Larsen", "Recharge -35 %, -25 % de dégâts."],
}

static func mastery_level(dmg: float) -> int:
	var lv := 0
	for i in range(1, MASTERY_XP.size()):
		if dmg >= MASTERY_XP[i]: lv = i
	return lv

# ---------------------------------------------------------------- Directives du Parti
const DIRECTIVES := {
	"penurie": {"name": "Pénurie", "desc": "Coffres +50 % plus chers.", "ferveur": 1, "max": 1},
	"rationnement": {"name": "Rationnement", "desc": "Pas de tartines ni de régénération.", "ferveur": 1, "max": 1},
	"productivisme": {"name": "Productivisme", "desc": "Ennemis +25 % de PV par niveau.", "ferveur": 1, "max": 3},
	"cadence": {"name": "Cadence infernale", "desc": "+25 % d'ennemis par niveau.", "ferveur": 1, "max": 3},
	"lutte": {"name": "Lutte des classes", "desc": "Tous les ennemis ont +2 d'armure par niveau.", "ferveur": 1, "max": 2},
	"sans_pitie": {"name": "Sans pitié", "desc": "Dégâts ennemis +25 % par niveau.", "ferveur": 1, "max": 3},
	"bureaucratie": {"name": "Bureaucratie", "desc": "Seulement 2 cartes par montée de niveau.", "ferveur": 2, "max": 1},
	"inflation": {"name": "Inflation", "desc": "Roubles -40 %.", "ferveur": 1, "max": 1},
	"surveillance": {"name": "Surveillance", "desc": "Le Contrôleur Fiscal arrive dès 07:00.", "ferveur": 2, "max": 1},
	"opa": {"name": "OPA permanente", "desc": "Deux fois plus de Golden Boys, plus résistants.", "ferveur": 1, "max": 1},
}

func ferveur(dirs: Dictionary) -> int:
	var f := 0
	for k in dirs: f += DIRECTIVES[k]["ferveur"] * dirs[k]
	return f

# ---------------------------------------------------------------- Plan quinquennal (quotas)
# kinds: kill_kind (cumulative), kill_weapon (cumulative), survive (single run), boss, no_chest,
# evo, shrines (single run), level (single run), char_time (single run), ferveur_time
const QUOTA_KINDS := ["kill_kind", "kill_weapon", "kill_weapon", "survive", "boss", "no_chest", "evo", "shrines", "level", "char_time", "kill_kind"]

func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("save="): save_path = a.substr(5)
	load_save()

func default_save() -> Dictionary:
	return {
		"version": SAVE_VERSION, "medals": 0, "runs": 0, "wins": 0, "best_time": 0.0,
		"bureau": {}, "bureau_purged": "",
		"chars": {"stakhanov": {"unlocked": true, "xp": 0, "talents": [0, 0, 0]}},
		"weapons": {"marteau": true, "kalach": true, "faucille": true, "molotov": true},
		"mastery": {}, "modules": {}, "kills": {},
		"plan": {}, "plan_no": 0, "directives_best": 0, "last_char": "stakhanov", "lifetime": 0,
		"options": {"numbers": 2, "fx": 100, "shake": 100},
	}

func load_save():
	data = default_save()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in parsed: data[k] = parsed[k]
	for c in CHARACTERS:
		if not data["chars"].has(c): data["chars"][c] = {"unlocked": CHARACTERS[c]["cost"] == 0, "xp": 0, "talents": [0, 0, 0]}
	if data["plan"].is_empty(): new_plan()
	run_char = data.get("last_char", "stakhanov")

func opt(k: String) -> float:
	var o: Dictionary = data.get("options", {})
	return float(o.get(k, {"numbers": 2, "fx": 100, "shake": 100, "minimap": 1}.get(k, 0)))

func set_opt(k: String, v: float):
	if not data.has("options"): data["options"] = {}
	data["options"][k] = v
	save()

func save():
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))

func reset_save():
	data = default_save()
	new_plan()
	save()

# ---------------------------------------------------------------- characters & talents
static func char_level_xp(lv: int) -> int:
	return int(50 * pow(lv, 1.5))

func char_level(c: String) -> int:
	var xp: float = data["chars"][c]["xp"]
	var lv := 0
	while lv < 15 and xp >= char_level_xp(lv + 1): lv += 1
	return lv

func talent_points_free(c: String) -> int:
	var spent := 0
	for t in data["chars"][c]["talents"]: spent += int(t)
	return char_level(c) - spent

func buy_talent(c: String, branch: int) -> bool:
	var t: Array = data["chars"][c]["talents"]
	if talent_points_free(c) <= 0 or int(t[branch]) >= 5: return false
	if char_level(c) < talent_level_req(int(t[branch])): return false
	t[branch] = int(t[branch]) + 1
	save()
	return true

func unlock_char(c: String) -> bool:
	var cost: int = CHARACTERS[c]["cost"]
	if data["chars"][c]["unlocked"] or data["medals"] < cost: return false
	if grade() < int(CHAR_GRADE.get(c, 1)): return false
	data["medals"] -= cost
	data["chars"][c]["unlocked"] = true
	save()
	return true

# ---------------------------------------------------------------- bureau / weapons
func bureau_rank(id: String) -> int:
	return int(data["bureau"].get(id, 0))

func buy_bureau(id: String) -> bool:
	var r := bureau_rank(id)
	if r >= BUREAU[id]["max"]: return false
	if grade() < bureau_grade_req(id, r): return false
	var cost := bureau_cost(id, r)
	if data["medals"] < cost: return false
	data["medals"] -= cost
	data["bureau"][id] = r + 1
	save()
	return true

func weapon_unlocked(w: String) -> bool:
	return data["weapons"].get(w, false)

func unlock_weapon(w: String) -> bool:
	if weapon_unlocked(w) or data["medals"] < WEAPON_UNLOCK[w]: return false
	if grade() < int(WEAPON_GRADE.get(w, 1)): return false
	data["medals"] -= WEAPON_UNLOCK[w]
	data["weapons"][w] = true
	save()
	return true

func weapon_mastery(w: String) -> int:
	return mastery_level(float(data["mastery"].get(w, 0.0)))

func module_available(m: String) -> bool:
	return weapon_mastery(MODULES[m][0]) >= MODULES[m][1]

func equip_module(w: String, m: String):
	if m == "" or module_available(m):
		data["modules"][w] = m
		save()

# ---------------------------------------------------------------- run modifiers
func run_modifiers(c: String) -> Dictionary:
	var mods := {}
	var add := func(k: String, v: float): mods[k] = mods.get(k, 0.0) + v
	for k in CHARACTERS[c]["base"]: add.call(k, float(CHARACTERS[c]["base"][k]))
	var t: Array = data["chars"][c]["talents"]
	for b in 3:
		var nodes: Array = CHARACTERS[c]["tree"][b][1]
		for i in int(t[b]):
			add.call(nodes[i][0], float(nodes[i][1]))
	for id in data["bureau"]:
		if id == data.get("bureau_purged", ""): continue
		add.call(BUREAU[id]["stat"], BUREAU[id]["per"] * int(data["bureau"][id]))
	return mods

# ---------------------------------------------------------------- quotas
func _quota_scale() -> float:
	return 1.0 + 0.15 * float(data["plan_no"])

func _make_quota(kind: String, used: Array) -> Dictionary:
	var s := _quota_scale()
	var q := {"kind": kind, "progress": 0, "done": false}
	match kind:
		"kill_kind":
			var kinds := ["stagiaire", "cadre", "trader", "influenceur", "crypto", "avocat", "banquier", "huissier"]
			var k: String = kinds[randi() % kinds.size()]
			var base := {"stagiaire": 800, "cadre": 400, "trader": 150, "influenceur": 120, "crypto": 100, "avocat": 80, "banquier": 60, "huissier": 60}
			q["target_id"] = k
			q["target"] = int(base[k] * s)
			q["text"] = "Bonker %d %s(s)" % [q["target"], Data.ENEMIES[k]["name"]]
		"kill_weapon":
			var ws := []
			for w in data["weapons"]: if data["weapons"][w]: ws.append(w)
			var w: String = ws[randi() % ws.size()]
			q["target_id"] = w
			q["target"] = int(700 * s)
			q["text"] = "Bonker %d ennemis avec : %s" % [q["target"], Data.WEAPONS[w]["name"]]
		"survive":
			q["target"] = int(clampf(300 + 60 * data["plan_no"], 300, 600))
			q["text"] = "Survivre jusqu'à %02d:%02d" % [q["target"] / 60, q["target"] % 60]
		"boss":
			q["target"] = 1
			q["text"] = "Bonker le Directeur Black Friday"
		"no_chest":
			q["target"] = 240
			q["text"] = "Atteindre 04:00 sans ouvrir aucun coffre"
		"evo":
			q["target"] = 1
			q["text"] = "Obtenir une évolution d'arme"
		"shrines":
			q["target"] = 3
			q["text"] = "Utiliser 3 sanctuaires dans une même run"
		"level":
			q["target"] = int(14 + 2 * data["plan_no"])
			q["text"] = "Atteindre le niveau %d" % q["target"]
		"char_time":
			var cs := []
			for c in data["chars"]: if data["chars"][c]["unlocked"]: cs.append(c)
			var c: String = cs[randi() % cs.size()]
			q["target_id"] = c
			q["target"] = 300
			q["text"] = "Survivre jusqu'à 05:00 avec %s" % CHARACTERS[c]["name"]
	return q

func new_plan():
	var kinds := QUOTA_KINDS.duplicate()
	kinds.shuffle()
	var picked := []
	var qs := []
	for k in kinds:
		if picked.has(k): continue
		picked.append(k)
		qs.append(_make_quota(k, picked))
		if qs.size() == 3: break
	data["plan"] = {"quotas": qs, "runs_left": 5}
	data["plan_no"] = int(data.get("plan_no", 0)) + 1

# report: {char, time, kills, kills_by_kind{}, kills_by_weapon{}, dmg_by_weapon{}, boss, elites,
#          level, chests, shrines, evo, ferveur, win}
func end_run(r: Dictionary) -> Dictionary:
	var out := {"lines": [], "medals": 0}
	var f: int = r["ferveur"]
	var bosses: Array = r.get("bosses", [])
	var base := int(r["kills"] / 45.0 + r["time"] / 60.0 * 5.0 + r["elites"] * 3 + 50 * bosses.size() + (60 if r["win"] else 0))
	var tier: int = r.get("tier", 1)
	var mult := (1.0 + 0.15 * f) * float(TIERS[tier - 1]["medals"])
	var medals := int(base * mult)
	out["lines"].append("Médailles de la run : %d%s" % [medals, (" (x%.2f)" % mult) if mult != 1.0 else ""])
	if not data.has("bosses"): data["bosses"] = {}
	for z in bosses:
		var first := int(data["bosses"].get(str(z), 0)) == 0
		data["bosses"][str(z)] = int(data["bosses"].get(str(z), 0)) + 1
		if first and z < 3: out["lines"].append("NOUVELLE ZONE DÉBLOQUÉE : %s (départ possible depuis le Kolkhoze)" % Levels.zone(z + 1)["name"])
	if r["win"] and tier < 3 and tier >= int(data.get("tier_max", 1)):
		data["tier_max"] = tier + 1
		out["lines"].append("NOUVELLE DIFFICULTÉ : %s" % TIERS[tier]["name"])
	if r["win"] and int(data.get("wins", 0)) == 0:
		out["lines"].append("MODE SANS FIN DÉBLOQUÉ")
	if r.get("endless", false):
		data["endless_best"] = maxi(int(data.get("endless_best", 0)), int(r.get("zone", 1)))
	# weapon mastery
	for w in r["kills_by_weapon"]:
		var before := weapon_mastery(w)
		data["mastery"][w] = float(data["mastery"].get(w, 0.0)) + r["kills_by_weapon"][w]
		var after := weapon_mastery(w)
		if after > before:
			out["lines"].append("Maîtrise %s : niveau %d !" % [Data.WEAPONS[w]["name"], after])
			for m in MODULES:
				if MODULES[m][0] == w and MODULES[m][1] > before and MODULES[m][1] <= after:
					out["lines"].append("  Nouveau module : %s" % MODULES[m][2])
	for k in r["kills_by_kind"]:
		data["kills"][k] = int(data["kills"].get(k, 0)) + r["kills_by_kind"][k]
	# quotas
	var plan: Dictionary = data["plan"]
	for q in plan["quotas"]:
		if q["done"]: continue
		match q["kind"]:
			"kill_kind": q["progress"] = int(q["progress"]) + int(r["kills_by_kind"].get(q["target_id"], 0))
			"kill_weapon": q["progress"] = int(q["progress"]) + int(r["kills_by_weapon"].get(q["target_id"], 0))
			"survive": q["progress"] = maxi(int(q["progress"]), int(r["time"]))
			"boss": q["progress"] = maxi(int(q["progress"]), 1 if r["boss"] else 0)
			"no_chest": if r["chests"] == 0: q["progress"] = maxi(int(q["progress"]), int(r["time"]))
			"evo": q["progress"] = maxi(int(q["progress"]), 1 if r["evo"] else 0)
			"shrines": q["progress"] = maxi(int(q["progress"]), int(r["shrines"]))
			"level": q["progress"] = maxi(int(q["progress"]), int(r["level"]))
			"char_time": if r["char"] == q["target_id"]: q["progress"] = maxi(int(q["progress"]), int(r["time"]))
		if int(q["progress"]) >= int(q["target"]):
			q["done"] = true
			var reward := int(30 * _quota_scale())
			medals += reward
			out["lines"].append("QUOTA RÉALISÉ : %s (+%d médailles)" % [q["text"], reward])
	plan["runs_left"] = int(plan["runs_left"]) - 1
	var all_done := true
	for q in plan["quotas"]:
		if not q["done"]: all_done = false
	if all_done or int(plan["runs_left"]) <= 0:
		data["bureau_purged"] = ""
		if all_done:
			var bonus := int(80 * _quota_scale())
			medals += bonus
			out["lines"].append("PLAN QUINQUENNAL ACCOMPLI ! +%d médailles" % bonus)
			var locked := []
			for c in CHARACTERS:
				if not data["chars"][c]["unlocked"]: locked.append(c)
			if not locked.is_empty():
				var c: String = locked[0]
				data["chars"][c]["unlocked"] = true
				out["lines"].append("Le Parti t'offre un nouveau camarade : %s" % CHARACTERS[c]["name"])
		else:
			var owned: Array = data["bureau"].keys()
			if owned.is_empty():
				var tax := int(data["medals"] * 0.2)
				data["medals"] -= tax
				out["lines"].append("PLAN ÉCHOUÉ. Le Parti confisque %d médailles." % tax)
			else:
				var p: String = owned[randi() % owned.size()]
				data["bureau_purged"] = p
				out["lines"].append("PLAN ÉCHOUÉ. PURGE : « %s » est désactivé pendant tout le prochain plan." % BUREAU[p]["name"])
		new_plan()
		out["lines"].append("Nouveau Plan quinquennal n°%d." % data["plan_no"])
	# character xp
	var c: String = r["char"]
	var lv_before := char_level(c)
	data["chars"][c]["xp"] = int(data["chars"][c]["xp"]) + medals
	var lv_after := char_level(c)
	if lv_after > lv_before:
		out["lines"].append("%s passe niveau %d (+%d point(s) de talent)" % [CHARACTERS[c]["name"], lv_after, lv_after - lv_before])
	var g_before := grade()
	data["medals"] = int(data["medals"]) + medals
	data["lifetime"] = int(data.get("lifetime", 0)) + medals
	if grade() > g_before:
		out["lines"].append("PROMOTION : tu es maintenant %s (grade %d) ! De nouvelles améliorations sont accessibles." % [GRADE_NAMES[grade() - 1], grade()])
	data["runs"] = int(data["runs"]) + 1
	if r["win"]: data["wins"] = int(data["wins"]) + 1
	data["best_time"] = maxf(float(data["best_time"]), float(r["time"]))
	if r["win"]: data["directives_best"] = maxi(int(data["directives_best"]), f)
	out["medals"] = medals
	save()
	return out
