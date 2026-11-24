extends Node
# Meta-progression (autoload "Meta"): save file, characters & talents, Bureau du Plan,
# weapon mastery & modules, Plan quinquennal (quotas), Directives du Parti.

const SAVE_VERSION := 1
var save_path := "user://lutte_finale_save.json"
var data := {}

# run configuration chosen in the Kolkhoze
var run_char := "stakhanov"
var run_party: Array = []    # online coop: one entry per comrade ({char, skin, remote, peer, name}); empty = solo
var run_directives := {}     # id -> level
var run_zone := 1            # zone the next game scene builds
var run_tier := 1            # difficulty tier (1..3)
var run_endless := false
var carry := {}
var hub_tab := "lancer"       # tab the Kolkhoze opens on              # run state carried from one zone to the next

const TIERS := [
	{"name": "Camarade", "hp": 1.0, "dmg": 1.0, "rate": 1.0, "medals": 1.0, "desc": "La difficulté normale."},
	{"name": "Commissaire", "hp": 1.6, "dmg": 1.3, "rate": 1.15, "medals": 1.6, "desc": "Ennemis +60 % PV, +30 % dégâts, plus nombreux. Médailles x1.6."},
	{"name": "Héros de l'Union", "hp": 2.5, "dmg": 1.6, "rate": 1.3, "medals": 2.4, "desc": "Ennemis x2.5 PV, +60 % dégâts, encore plus nombreux. Médailles x2.4."},
]

func tier_unlocked(t: int) -> bool:
	return t <= int(data.get("tier_max", 1))

func zone_unlocked(z: int) -> bool:
	if z == Levels.SPECIAL: return berlin_unlocked()
	return z <= 1 or int(data.get("bosses", {}).get(str(z - 1), 0)) > 0

# the bonus map only exists once the 9 zone bosses have all been beaten
func berlin_unlocked() -> bool:
	for z in range(1, Levels.count() + 1):
		if int(data.get("bosses", {}).get(str(z), 0)) <= 0: return false
	return true

func endless_unlocked() -> bool:
	return int(data.get("wins", 0)) > 0

# ---------------------------------------------------------------- characters
const CHARACTERS := {
	"stakhanov": {
		"name": "Stakhanov", "model": "character-worker", "acc": [], "cost": 0, "weapon": "marteau",
		"passive": "Dépasser les quotas : +2 % de cadence tous les 150 ennemis bonkés (max +20 %).",
		"ult": "Surproduction", "ult_desc": "Cadence x2 pendant 6 s.",
		"bio": "Héros du travail, il a dépassé ses quotas de 1 400 %, puis ses poumons, puis son espérance de vie. On l'a décoré trois fois, dont une à titre posthume par erreur. Il ne s'en est pas remis : il est retourné à la mine.",
		"base": {"endurance": 20, "productivite": 10, "armure": 1, "vitesse": -5, "aimant": -10},
		"tree": [
			["Ouvrier modèle", [["cadence", 5], ["productivite", 6], ["cadence", 5], ["productivite", 8], ["ult_power", 30]]],
			["Mineur de fond", [["endurance", 20], ["armure", 1.5], ["endurance", 20], ["regen", 0.4], ["slam_bonus", 50]]],
			["Brigade de choc", [["vitesse", 5], ["aimant", 25], ["ult_charge", 20], ["vitesse", 6], ["rubles_pct", 20]]],
		],
	},
	"ilitch": {
		"name": "Ilitch le Chauve", "model": "character-male-b", "acc": ["chapka"], "cost": 150, "weapon": "hautparleur",
		"passive": "Le théoricien : +15 % d'XP, +15 % de taille des zones. Ses discours portent loin, ses bras beaucoup moins.",
		"ult": "Discours au peuple", "ult_desc": "Étourdit tous les ennemis proches 3 s. Ils subissent +50 % de dégâts.",
		"bio": "Il a lu tous les livres, surtout les siens. Son corps est conservé dans du formol depuis un siècle, ce qui explique sa santé fragile et son teint de cire. Il parle encore très bien, et très longtemps.",
		"base": {"propagande": 15, "expansion": 15, "endurance": -20, "productivite": -5},
		"tree": [
			["Orateur", [["ult_charge", 15], ["ult_power", 25], ["expansion", 8], ["ult_charge", 15], ["ult_stun", 1.5]]],
			["Idéologue", [["propagande", 8], ["chance", 5], ["reroll", 1], ["propagande", 8], ["chance", 8]]],
			["Chef de parti", [["endurance", 15], ["armure", 1], ["regen", 0.3], ["endurance", 20], ["revive", 1]]],
		],
	},
	"moustache": {
		"name": "Petit Père Moustache", "model": "character-male-g", "acc": ["chapka"], "cost": 250, "weapon": "kalach",
		"passive": "Le paranoïaque : +12 % de critique, +5 % de dégâts. Il ne se soigne jamais : il ne fait confiance à aucun médecin.",
		"ult": "Grande Purge", "ult_desc": "Élimine tous les ennemis normaux à moins de 14 m. Coûte 15 % de tes PV actuels.",
		"bio": "Il soupçonne tout le monde, y compris son reflet. Ses amis disparaissent des photos, ses ennemis aussi, et il compte bien ajouter les capitalistes à la liste. Sa moustache a son propre service de sécurité.",
		"base": {"critique": 12, "productivite": 5, "regen": -0.4, "chance": -10},
		"tree": [
			["Purge", [["critique", 4], ["productivite", 6], ["critique", 5], ["ult_charge", 20], ["crit_dmg", 50]]],
			["Paranoïa", [["vitesse", 6], ["armure", 1], ["dodge", 8], ["vitesse", 6], ["dodge", 7]]],
			["Culte de la personnalité", [["chance", 6], ["rubles_pct", 15], ["chest_discount", 15], ["chance", 8], ["start_level", 2]]],
		],
	},
	"babouchka": {
		"name": "Babouchka Olga", "model": "character-female-f", "acc": ["chapka"], "cost": 350, "weapon": "samovar",
		"passive": "Elle a connu pire : +50 PV, régénération +0,6/s, +1 d'armure. Mais elle ne court plus depuis 1953.",
		"ult": "Elle a connu pire", "ult_desc": "Invincible 4 s et soin complet.",
		"bio": "Elle a survécu à deux guerres, trois famines et quatorze réformes agraires. Les balles rebondissent sur son fichu. Elle avance lentement, mais rien de ce qui se met en travers de son chemin n'a jamais survécu à son thé.",
		"base": {"endurance": 50, "regen": 0.6, "armure": 1, "vitesse": -12, "jump": -15, "cadence": -5},
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
		"bio": "Guérillero de profession, mannequin de t-shirt malgré lui. Il a appris que son visage se vend très bien dans les centres commerciaux : il vient récupérer les droits d'auteur, au cigare explosif.",
		"base": {"chance": 10, "vitesse": 5, "endurance": -10, "armure": -1},
		"tree": [
			["Guérilla", [["vitesse", 5], ["dodge", 5], ["productivite", 6], ["dodge_cd", 15], ["ult_power", 30]]],
			["Sierra", [["endurance", 20], ["regen", 0.3], ["armure", 1], ["endurance", 25], ["revive", 1]]],
			["Discours de 7 heures", [["ult_charge", 15], ["propagande", 8], ["chance", 6], ["ult_charge", 15], ["rubles_pct", 20]]],
		],
	},
	"youri": {
		"name": "Youri l'Orbital", "model": "", "acc": [], "cost": 550, "weapon": "spoutnik",
		"passive": "Apesanteur : saute 45 % plus haut et 30 % plus loin, chute ralentie, aimant +20 %. Au sol, il marche comme dans un scaphandre, parce que c'en est un.",
		"ult": "Retour sur Terre", "ult_desc": "Une capsule s'écrase sur le plus gros groupe d'ennemis proche : énormes dégâts et étourdissement.",
		"bio": "Premier camarade dans l'espace, dernier à avoir retiré son casque. Il dit que la Terre est belle vue d'en haut, et que de là-haut on ne voit pas les actionnaires. Il redescend uniquement pour leur tomber dessus.",
		"base": {"jump": 45, "air": 30, "aimant": 20, "vitesse": -12, "cadence": -5, "endurance": -10},
		"tree": [
			["Cosmonaute", [["expansion", 8], ["duree", 10], ["expansion", 8], ["slam_bonus", 50], ["ult_power", 30]]],
			["Entraînement", [["endurance", 20], ["vitesse", 5], ["dodge_cd", 15], ["endurance", 25], ["armure", 1.5]]],
			["Héros national", [["chance", 6], ["aimant", 25], ["ult_charge", 15], ["propagande", 8], ["start_level", 2]]],
		],
	},
	"natacha": {
		"name": "Natacha la Kolkhozienne", "model": "", "acc": [], "cost": -1, "weapon": "tracteur",
		"passive": "Récolte collective : aimant +30 %, chance +5 %. Rien ne se perd, tout se collectivise.",
		"ult": "Moisson collective", "ult_desc": "Aspire toute l'XP de la carte et lance 8 tracteurs en étoile.",
		"bio": "Kolkhozienne de l'année, élue par un jury qu'elle a elle-même nommé. Elle moissonne le blé, le seigle et désormais les cadres supérieurs. Son tracteur n'a jamais eu de permis, ses victimes non plus.",
		"base": {"aimant": 30, "endurance": 10, "chance": 5, "cadence": -5, "critique": -3},
		"unlock": {"kind": "weapon_kills_total", "weapon": "tracteur", "n": 8000, "text": "Faire 8000 éliminations avec le Tracteur du Kolkhoze (toutes runs confondues)"},
		"tree": [
			["Moissonneuse", [["productivite", 6], ["expansion", 8], ["productivite", 8], ["expansion", 10], ["ult_power", 30]]],
			["Champs", [["endurance", 20], ["regen", 0.3], ["endurance", 25], ["armure", 1], ["revive", 1]]],
			["Coopérative", [["aimant", 20], ["propagande", 8], ["chance", 6], ["ult_charge", 15], ["rubles_pct", 20]]],
		],
	},
	"vodkine": {
		"name": "Sergent Vodkine", "model": "", "acc": [], "cost": -1, "weapon": "vodka",
		"passive": "Ivresse tactique : 15 % d'esquive, régénération +0,3/s. Il titube, donc personne ne sait où il va, lui non plus.",
		"ult": "Tournée du sergent", "ult_desc": "Soigne 40 % des PV et +60 % de cadence pendant 6 s.",
		"bio": "Sergent depuis 1979, toujours pas démobilisé : personne n'a osé lui annoncer la fin de la guerre froide. Sa gourde contient un antiseptique, un carburant et son petit-déjeuner. C'est la même bouteille.",
		"base": {"dodge": 15, "regen": 0.3, "critique": 5, "vitesse": -5, "expansion": -10},
		"unlock": {"kind": "weapon_evo", "weapon": "vodka", "text": "Faire évoluer la Vodka Frappée en Tournée Générale pendant une run"},
		"tree": [
			["Bouteille", [["cadence", 5], ["productivite", 6], ["cadence", 6], ["crit_dmg", 40], ["ult_power", 30]]],
			["Caserne", [["endurance", 20], ["armure", 1], ["dodge", 5], ["endurance", 25], ["regen", 0.4]]],
			["Cantine", [["ult_charge", 15], ["chance", 6], ["aimant", 20], ["ult_charge", 15], ["heal_pickup", 50]]],
		],
	},
	"tamara": {
		"name": "Tankiste Tamara", "model": "", "acc": [], "cost": -1, "weapon": "t34",
		"passive": "Blindée : +3 d'armure, +30 PV, +10 % de dégâts. Elle ne saute pas : elle écrase ce qui dépasse.",
		"ult": "Percée blindée", "ult_desc": "Fonce droit devant, invulnérable, en écrasant tout sur 14 m.",
		"bio": "Tankiste décorée, elle a gardé le char après la démobilisation « pour les courses ». Elle se gare toujours sur les places réservées aux SUV de luxe, généralement par-dessus.",
		"base": {"armure": 3, "endurance": 30, "productivite": 10, "vitesse": -10, "jump": -20, "cadence": -10},
		"unlock": {"kind": "weapon_kills_run", "weapon": "t34", "n": 2500, "text": "Faire 2500 éliminations avec le Char du Peuple pendant une run"},
		"tree": [
			["Canon", [["productivite", 6], ["expansion", 8], ["productivite", 8], ["critique", 5], ["ult_power", 30]]],
			["Chenilles", [["armure", 1], ["endurance", 25], ["armure", 1], ["endurance", 30], ["revive", 1]]],
			["Équipage", [["vitesse", 6], ["ult_charge", 15], ["cadence", 5], ["vitesse", 6], ["start_level", 2]]],
		],
	},
	"mikhail": {
		"name": "Mikhaïl le Dresseur", "model": "", "acc": [], "cost": -1, "weapon": "ours",
		"passive": "Ami des bêtes : un ours de plus à ses côtés.",
		"ult": "Réveil de la taïga", "ult_desc": "Trois ours géants rejoignent la lutte pendant 10 s.",
		"bio": "Dresseur au cirque d'État jusqu'à ce que les ours votent sa promotion. Ils sont syndiqués, nourris, logés, et ont droit à un capitaliste par jour. Le planning ne précise pas lequel.",
		"base": {"endurance": 20, "regen": 0.3, "productivite": -5, "aimant": -10},
		"unlock": {"kind": "survive_with", "weapon": "ours", "time": 1500, "text": "Tenir 25 minutes au total (3 zones) avec l'Ours de Sibérie dans son arsenal"},
		"tree": [
			["Meute", [["productivite", 6], ["cadence", 5], ["productivite", 8], ["expansion", 10], ["ult_power", 30]]],
			["Fourrure", [["endurance", 25], ["regen", 0.3], ["armure", 1], ["endurance", 30], ["regen", 0.4]]],
			["Taïga", [["vitesse", 5], ["aimant", 20], ["ult_charge", 15], ["chance", 6], ["ult_charge", 15]]],
		],
	},
	"timonier": {
		"name": "Le Grand Timonier", "model": "", "acc": [], "cost": -1, "weapon": "tracts",
		"passive": "Petit livre : +15 % d'XP, une relance de cartes, zones +10 %. Il commande, d'autres tapent.",
		"ult": "Grand bond en avant", "ult_desc": "Tous les ennemis proches perdent 20 % de leurs PV max.",
		"bio": "Grand nageur, grand bondisseur, grand tout. Il a écrit un petit livre rouge pour chaque occasion, dont un sur la modestie. Ses tracts tranchent mieux que ses réformes, ce qui n'est pas difficile.",
		"base": {"propagande": 15, "reroll": 1, "expansion": 10, "endurance": -20, "armure": -1, "productivite": -5},
		"unlock": {"kind": "level_run", "n": 70, "text": "Atteindre le niveau 70 pendant une run"},
		"tree": [
			["Pensée", [["propagande", 8], ["reroll", 1], ["propagande", 8], ["banish", 1], ["ult_power", 30]]],
			["Longue marche", [["vitesse", 5], ["endurance", 20], ["vitesse", 5], ["endurance", 25], ["dodge_cd", 15]]],
			["Masses", [["productivite", 6], ["cadence", 5], ["ult_charge", 15], ["productivite", 8], ["start_level", 2]]],
		],
	},
	"lev": {
		"name": "Lev le Bâtisseur", "model": "", "acc": [], "cost": -1, "weapon": "rideau",
		"passive": "Planificateur : zones +20 %, +2 d'armure. Il construit des murs, des murs, et quelques murs.",
		"ult": "Mur de la Honte", "ult_desc": "Huit murs d'acier surgissent en cercle autour de lui.",
		"bio": "Architecte du peuple, il a bâti 3 000 immeubles identiques et un mur dont il refuse de parler. Il pose une brique toutes les quatre secondes, même sur les gens. Surtout sur les gens.",
		"base": {"expansion": 20, "armure": 2, "endurance": 10, "vitesse": -8, "critique": -5},
		"unlock": {"kind": "weapon_level", "weapon": "rideau", "level": 10, "text": "Monter le Rideau de Fer au niveau maximum (10) pendant une run"},
		"tree": [
			["Béton", [["expansion", 6], ["duree", 12], ["expansion", 8], ["duree", 15], ["ult_power", 30]]],
			["Échafaudage", [["armure", 1], ["endurance", 25], ["armure", 1], ["regen", 0.3], ["revive", 1]]],
			["Plan", [["productivite", 6], ["ult_charge", 15], ["chance", 6], ["productivite", 8], ["rubles_pct", 20]]],
		],
	},
	"svetlana": {
		"name": "Svetlana la Pyromane", "model": "", "acc": [], "cost": -1, "weapon": "molotov",
		"passive": "Feu sacré : effets +25 % plus longs, +10 % de dégâts, +8 % de vitesse. Elle brûle tout, surtout ses PV.",
		"ult": "Grand incendie", "ult_desc": "Douze flaques de feu s'embrasent tout autour d'elle.",
		"bio": "Ancienne chimiste d'une usine de cocktails, fermée après un léger incident (la ville). Elle croit au progrès, à l'égalité et à l'essence. Les pompiers du quartier d'affaires connaissent son prénom.",
		"base": {"duree": 25, "productivite": 10, "vitesse": 8, "endurance": -25, "armure": -1},
		"unlock": {"kind": "weapon_kills_total", "weapon": "molotov", "n": 15000, "text": "Faire 15000 éliminations avec le Cocktail Molotov (toutes runs confondues)"},
		"tree": [
			["Essence", [["duree", 10], ["productivite", 6], ["expansion", 8], ["productivite", 8], ["ult_power", 30]]],
			["Cendres", [["endurance", 20], ["regen", 0.3], ["dodge", 5], ["endurance", 25], ["dodge", 6]]],
			["Allumettes", [["cadence", 5], ["ult_charge", 15], ["cadence", 6], ["chance", 6], ["ult_charge", 15]]],
		],
	},
	"dmitri": {
		"name": "Dmitri le Musicien", "model": "", "acc": [], "cost": -1, "weapon": "balalaika",
		"passive": "Rythme folklorique : +15 % de cadence, +5 % de vitesse. Ses notes font peu de dégâts, mais beaucoup de notes.",
		"ult": "Kalinka !", "ult_desc": "Tous les ennemis proches dansent (étourdis) 4 s et subissent +50 % de dégâts.",
		"bio": "Virtuose de la balalaïka, il joue si vite que le Bureau politique l'a classé arme stratégique. Ses concerts durent jusqu'à ce que le public s'effondre. Il appelle ça « le rappel ».",
		"base": {"cadence": 15, "vitesse": 5, "endurance": -20, "productivite": -10},
		"unlock": {"kind": "weapon_kills_run", "weapon": "balalaika", "n": 3000, "text": "Faire 3000 éliminations avec la Balalaïka pendant une run"},
		"tree": [
			["Cordes", [["cadence", 5], ["productivite", 6], ["cadence", 6], ["critique", 5], ["ult_power", 30]]],
			["Bal populaire", [["vitesse", 6], ["dodge", 6], ["endurance", 20], ["vitesse", 6], ["dodge_cd", 15]]],
			["Chœur", [["propagande", 8], ["ult_charge", 15], ["aimant", 20], ["ult_charge", 15], ["chance", 8]]],
		],
	},
	"valentina": {
		"name": "Valentina de l'Observatoire", "model": "", "acc": [], "cost": -1, "weapon": "etoile",
		"passive": "Regard des étoiles : +12 % de critique, +25 % de dégâts critiques. Elle vise lentement, elle ne rate jamais.",
		"ult": "Pluie de météores", "ult_desc": "Douze étoiles rouges s'abattent sur les ennemis les plus coriaces.",
		"bio": "Astronome de l'Observatoire, elle a découvert que les étoiles sont rouges, comme prévu par le Plan. Elle a ensuite appris à les faire tomber. Les actionnaires feraient bien de regarder en l'air.",
		"base": {"critique": 12, "crit_dmg": 25, "chance": 5, "endurance": -25, "cadence": -5},
		"unlock": {"kind": "boss_with", "weapon": "etoile", "zone": 3, "text": "Vaincre La Main Invisible (boss final) avec l'Étoile Rouge dans son arsenal"},
		"tree": [
			["Télescope", [["critique", 4], ["crit_dmg", 30], ["critique", 5], ["crit_dmg", 40], ["ult_power", 30]]],
			["Orbite", [["endurance", 20], ["regen", 0.3], ["armure", 1], ["endurance", 25], ["revive", 1]]],
			["Constellation", [["chance", 6], ["ult_charge", 15], ["propagande", 8], ["ult_charge", 15], ["start_level", 2]]],
		],
	},
	"generalissime": {
		"name": "Le Généralissime", "model": "", "acc": [], "cost": -1, "weapon": "katioucha",
		"passive": "Culte de la personnalité : chaque coffre ouvert le soigne de 15 % de ses PV, et ses roquettes de l'Orgue tombent par salves plus fournies (+2).",
		"ult": "Orgue de Staline", "ult_desc": "Trois salves de roquettes s'abattent sur tout ce qui bouge autour de lui, puis +25 % de dégâts pendant 8 s.",
		"bio": "Le vainqueur de Berlin, en uniforme blanc de parade, médaille épinglée par lui-même. Il a gagné la guerre, réécrit les manuels d'histoire et fait repeindre les photos. Il fume la pipe pour réfléchir ; le Politburo retient son souffle pour la même raison.",
		"base": {"productivite": 10, "propagande": 10, "aimant": 15, "vitesse": -8, "dodge": -5},
		"unlock": {"kind": "zone_boss", "zone": 10, "text": "Bonker le Führer de Pacotille dans son bunker (carte bonus)"},
		"tree": [
			["Défilé", [["productivite", 6], ["cadence", 5], ["productivite", 8], ["ult_power", 25], ["crit_dmg", 40]]],
			["Grand uniforme", [["endurance", 25], ["armure", 1], ["regen", 0.3], ["endurance", 30], ["revive", 1]]],
			["Culte de la personnalité", [["chance", 6], ["rubles_pct", 15], ["ult_charge", 15], ["chest_discount", 15], ["start_level", 2]]],
		],
	},
}

# skins: bought in the Caserne with medals; tint of the KayKit body + extra accessories
const SKINS := {
	"stakhanov": [["Bleu de travail", Color(1, 1, 1), [], 0], ["Héros du Travail (doré)", Color(1.25, 1.05, 0.55), ["medal"], 250], ["Mineur de nuit", Color(0.45, 0.45, 0.55), [], 150]],
	"ilitch": [["Costume trois-pièces", Color(1, 1, 1), [], 0], ["Momie du Mausolée", Color(1.2, 1.15, 0.95), [], 250], ["Exil en Suisse", Color(0.7, 0.85, 1.1), ["sunglasses"], 150]],
	"moustache": [["Uniforme", Color(1, 1, 1), [], 0], ["Grand uniforme blanc", Color(1.4, 1.4, 1.35), ["medal"], 250], ["Camouflage d'hiver", Color(0.85, 0.95, 1.05), [], 150]],
	"babouchka": [["Tablier fleuri", Color(1, 1, 1), [], 0], ["Babouchka de combat", Color(0.6, 0.75, 0.5), ["sunglasses"], 200], ["Reine de la datcha", Color(1.3, 0.8, 0.9), [], 150]],
	"barbudo": [["Treillis", Color(0.72, 0.85, 0.55), [], 0], ["Guérillero de la plage", Color(1.2, 1.1, 0.75), ["sunglasses"], 200], ["Tenue de parade", Color(0.55, 0.65, 0.45), ["medal"], 250]],
	"youri": [["Combinaison", Color(1, 1, 1), [], 0], ["Combinaison dorée", Color(1.25, 1.05, 0.55), ["medal"], 250], ["Mission martienne", Color(1.3, 0.6, 0.45), [], 200]],
	"natacha": [["Robe des champs", Color(1, 1, 1), [], 0], ["Kolkhozienne d'honneur", Color(1.25, 1.05, 0.55), ["medal"], 250], ["Moisson d'automne", Color(1.2, 0.8, 0.5), [], 150]],
	"vodkine": [["Uniforme", Color(0.75, 0.85, 0.6), [], 0], ["Permission", Color(0.6, 0.7, 1.1), ["sunglasses"], 200], ["Parade", Color(1.2, 1.05, 0.6), ["medal"], 250]],
	"tamara": [["Combinaison", Color(0.7, 0.8, 0.6), [], 0], ["Camouflage d'hiver", Color(1.3, 1.3, 1.3), [], 200], ["As du blindé", Color(1.2, 1.0, 0.55), ["medal"], 250]],
	"mikhail": [["Fourrures", Color(1, 1, 1), [], 0], ["Cirque d'État", Color(1.3, 0.6, 0.6), [], 200], ["Taïga blanche", Color(1.35, 1.35, 1.35), [], 150]],
	"timonier": [["Costume gris", Color(0.75, 0.75, 0.75), [], 0], ["Costume vert", Color(0.6, 0.85, 0.6), [], 150], ["Grand bond doré", Color(1.25, 1.05, 0.55), ["medal"], 250]],
	"lev": [["Bleu de chantier", Color(0.7, 0.8, 1.1), [], 0], ["Brique rouge", Color(1.2, 0.6, 0.5), [], 150], ["Héros du béton", Color(1.2, 1.05, 0.6), ["medal"], 250]],
	"svetlana": [["Tenue noire", Color(0.55, 0.5, 0.55), [], 0], ["Braise", Color(1.3, 0.55, 0.35), [], 200], ["Cendres", Color(1.1, 1.1, 1.1), ["sunglasses"], 150]],
	"dmitri": [["Chemise brodée", Color(1, 1, 1), [], 0], ["Tournée d'été", Color(1.2, 1.1, 0.75), ["sunglasses"], 150], ["Bal de gala", Color(0.6, 0.55, 0.9), ["medal"], 250]],
	"generalissime": [["Uniforme blanc de la Victoire", Color(0.95, 0.93, 0.86), [], 0], ["Capote de l'hiver 41", Color(0.42, 0.44, 0.37), [], 200], ["Maréchal de bronze (statue)", Color(0.62, 0.46, 0.28), [], 250]],
	"valentina": [["Blouse de l'observatoire", Color(1.2, 1.2, 1.25), [], 0], ["Nuit étoilée", Color(0.5, 0.55, 1.0), [], 200], ["Médaille d'or", Color(1.25, 1.05, 0.55), ["medal"], 250]],
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
		"options": {"numbers": 1, "fx": 60, "shake": 100},
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
	if not data.has("chal"): data["chal"] = {}
	if data["plan"].is_empty(): new_plan()
	run_char = data.get("last_char", "stakhanov")
	apply_quality.call_deferred()

func opt(k: String) -> float:
	var o: Dictionary = data.get("options", {})
	return float(o.get(k, {"numbers": 1, "fx": 60, "shake": 100, "minimap": 1, "music": 70, "sfx": 80, "quality": 2}.get(k, 0)))

func set_opt(k: String, v: float):
	if not data.has("options"): data["options"] = {}
	data["options"][k] = v
	save()
	if k == "quality": apply_quality()

# graphics quality: 2 = high (default), 1 = medium, 0 = performance (no sun shadows, 80 % 3D resolution)
func apply_quality():
	var q := int(opt("quality"))
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
	var vp := get_tree().root
	vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else Viewport.MSAA_2X
	vp.scaling_3d_scale = 0.8 if q == 0 else 1.0
	vp.mesh_lod_threshold = [16.0, 10.0, 8.0][q]      # project default: 8 px
	for l in get_tree().get_nodes_in_group("sun"):
		(l as DirectionalLight3D).shadow_enabled = q > 0

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
	if cost < 0 or data["chars"][c]["unlocked"] or data["medals"] < cost: return false
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
func run_modifiers(c: String, with_base := true) -> Dictionary:
	var mods := {}
	var add := func(k: String, v: float): mods[k] = mods.get(k, 0.0) + v
	if with_base:
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
# comrades unlocked by challenges ("unlock" spec in CHARACTERS); progress is the best value reached
func challenge_value(c: String, r := {}) -> float:
	var u: Dictionary = CHARACTERS[c]["unlock"]
	var best := float(data.get("chal", {}).get(c, 0.0))
	if r.is_empty(): 
		if u["kind"] == "weapon_kills_total": return float(data["mastery"].get(u["weapon"], 0.0))
		return best
	var v := 0.0
	var wl: Dictionary = r.get("weapon_levels", {})
	match u["kind"]:
		"weapon_kills_total": return float(data["mastery"].get(u["weapon"], 0.0))
		"weapon_level": v = float(wl.get(u["weapon"], 0))
		"weapon_kills_run": v = float(r["kills_by_weapon"].get(u["weapon"], 0))
		"level_run": v = float(r["level"])
		"survive_with": v = float(r["time"]) if wl.has(u["weapon"]) else 0.0
		"boss_with": v = 1.0 if (wl.has(u["weapon"]) and (r.get("bosses", []) as Array).has(int(u.get("zone", 1)))) else 0.0
		"zone_boss": v = 1.0 if (r.get("bosses", []) as Array).has(int(u.get("zone", 1))) else 0.0
		"weapon_evo": v = 1.0 if (r.get("evolved", []) as Array).has(u["weapon"]) else 0.0
	return maxf(best, v)

func challenge_target(c: String) -> float:
	var u: Dictionary = CHARACTERS[c]["unlock"]
	match u["kind"]:
		"weapon_level": return float(u["level"])
		"survive_with": return float(u["time"])
		"boss_with", "weapon_evo", "zone_boss": return 1.0
	return float(u["n"])

func challenge_text(c: String) -> String:
	var u: Dictionary = CHARACTERS[c]["unlock"]
	var v := challenge_value(c)
	var tgt := challenge_target(c)
	var prog := ""
	match u["kind"]:
		"survive_with": prog = "record %02d:%02d / %02d:%02d" % [int(v) / 60, int(v) % 60, int(tgt) / 60, int(tgt) % 60]
		"boss_with", "weapon_evo", "zone_boss": prog = "pas encore" if v < 1.0 else "fait"
		_: prog = "%d / %d" % [int(v), int(tgt)]
	return "%s  (%s)" % [u["text"], prog]

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
	var berlin_before := berlin_unlocked()
	for z in bosses:
		var first := int(data["bosses"].get(str(z), 0)) == 0
		data["bosses"][str(z)] = int(data["bosses"].get(str(z), 0)) + 1
		if first and z < Levels.count(): out["lines"].append("NOUVELLE ZONE DÉBLOQUÉE : %s (départ possible depuis le Kolkhoze)" % Levels.zone(z + 1)["name"])
	if not berlin_before and berlin_unlocked():
		out["lines"].append("CARTE BONUS DÉBLOQUÉE : BERLIN 1945 · LE BUNKER DU PETIT MOUSTACHU (au Kolkhoze)")
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
	for cc in CHARACTERS:
		if not CHARACTERS[cc].has("unlock") or data["chars"][cc]["unlocked"]: continue
		var cv := challenge_value(cc, r)
		data["chal"][cc] = cv
		if cv >= challenge_target(cc):
			data["chars"][cc]["unlocked"] = true
			out["lines"].append("NOUVEAU CAMARADE RÉHABILITÉ : %s !" % CHARACTERS[cc]["name"])
	data["runs"] = int(data["runs"]) + 1
	if r["win"]: data["wins"] = int(data["wins"]) + 1
	data["best_time"] = maxf(float(data["best_time"]), float(r["time"]))
	if r["win"]: data["directives_best"] = maxi(int(data["directives_best"]), f)
	out["medals"] = medals
	save()
	return out
