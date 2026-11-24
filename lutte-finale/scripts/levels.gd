class_name Levels
# Level templates: the global structure each procedural map must respect.
# Nine zones in three acts; a run crosses the zones of an act in order (zone 3, 6 and 9 end an act),
# endless mode loops over all of them.
#
# Keys used by the generator (world.gd):
#   width/depth      arena size ranges (m). Maps are big on purpose: the player has to roam.
#   blocks           share of lots turned into blocks of tall buildings (they hide the rest of the map)
#   block / border   style of those blocks and of the ring around the arena (see world._tall_piece)
#   skyline          what lies beyond: city, sea, mountains, desert, servers
#   ground_tex       floor texture (+ ground tint), walk_tex for the sidewalks, floor_tex for paved lots
#   skins            per-enemy overrides for this zone: name, looks [[model, M/F]], colors, acc
#   shops            shop signs on the facades
#   roster           zone-specific enemies [kind, from_time, weight, growth/min]
#   bpat             the boss's signature attack (see enemies._boss_special)

const HYPERMARCHE := {
	"id": "hypermarche",
	"commons": ["stagiaire", "cadre", "influenceur", "crypto", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "battle",
	"name": "L'Hypermarché",
	"boss": "boss",
	"roster": [["chef_rayon", 40.0, 1.6, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "stampede",      # boss attack pattern (enemies._boss_special)
	"width": [250.0, 295.0],
	"depth": [260.0, 305.0],
	"shapes": {"rect": 3.0, "L": 2.0, "croix": 2.0, "anneau": 2.0},
	"lots": {"parking": 4.0, "containers": 2.0, "market": 2.0, "plaza": 2.0, "chantier": 1.2, "quai": 1.5, "station": 1.0, "square": 1.5, "empty": 1.0},
	"min": {"plaza": 4, "market": 2, "containers": 2, "quai": 1, "chantier": 1, "parking": 2},
	"lot_size": [26.0, 46.0],
	"avenue": 8.0,
	"blocks": 0.24,
	"block": "city",
	"border": "city",
	"skyline": "city",
	"sky_ratio": 0.33,
	"ground": Color(0.42, 0.43, 0.46),
	"ambiances": {"fin_journee": 6.0, "couvert": 2.5, "aube": 1.5},
	"facade": ["HYPERMARCHÉ", "-70 %", "ACHETEZ.  CONSOMMEZ.  RECOMMENCEZ.", Color(0.15, 0.5, 0.28)],
	"slogans": ["TRAVAILLEURS DE TOUS LES PAYS, BONKEZ-VOUS", "LE PLAN QUINQUENNAL SERA BONKÉ EN 4 ANS", "LE CAPITAL EST UN TIGRE DE PAPIER. BONKEZ LE PAPIER.", "UN SPECTRE HANTE L'HYPERMARCHÉ"],
	"shops": ["BOULANGERIE D'ÉTAT", "COOPÉRATIVE N°7", "LAVERIE DU PEUPLE", "KIOSQUE PRAVDA", "PHARMACIE CENTRALE"],
	"blimp": "ACHETEZ PLUS",
}

const QUARTIER := {
	"id": "quartier",
	"commons": ["stagiaire", "cadre", "avocat", "drh", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "folk",
	"name": "Le Quartier d'Affaires",
	"boss": "boss2",
	"roster": [["consultant", 40.0, 1.5, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "meeting",      # boss attack pattern (enemies._boss_special)
	"width": [240.0, 285.0],
	"depth": [260.0, 300.0],
	"shapes": {"rect": 2.0, "croix": 3.0, "anneau": 2.0, "L": 1.0},
	"lots": {"bureaux": 3.0, "passerelle": 3.0, "plaza": 2.0, "parking": 1.5, "square": 1.5, "chantier": 1.0, "empty": 0.8},
	"min": {"plaza": 4, "passerelle": 3, "bureaux": 3},
	"lot_size": [24.0, 40.0],
	"avenue": 9.0,
	"blocks": 0.3,
	"block": "glass",
	"border": "city",
	"skyline": "city",
	"sky_ratio": 0.8,
	"ground": Color(0.36, 0.37, 0.4),
	"ambiances": {"couvert": 4.0, "fin_journee": 3.0, "aube": 2.0},
	"facade": ["TOUR CAPITAL", "+12 %", "OPEN SPACE  ·  BURN-OUT  ·  TEAM BUILDING", Color(0.2, 0.3, 0.45)],
	"slogans": ["LE PROLÉTARIAT N'A RIEN À PERDRE, SAUF SES RÉUNIONS", "UN BUREAU PAR TRAVAILLEUR, UNE CHAISE PAR BUREAU", "LES TOURS TOMBENT, LE PEUPLE RESTE", "SYNERGIE : MOT INTERDIT PAR LE PARTI"],
	"shops": ["CABINET DE CONSEIL", "STARTUP NATION", "COWORKING PREMIUM", "BANQUE PRIVÉE", "AGENCE DE NOTATION"],
	"blimp": "CROISSANCE INFINIE",
}

const BOURSE := {
	"id": "bourse",
	"commons": ["stagiaire", "trader", "banquier", "lobbyiste", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "techno_bourse",
	"name": "La Bourse",
	"boss": "boss3",
	"roster": [["daytrader", 40.0, 1.6, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "invisible",      # boss attack pattern (enemies._boss_special)
	"width": [235.0, 275.0],
	"depth": [250.0, 290.0],
	"shapes": {"rect": 2.0, "anneau": 3.0, "croix": 2.0},
	"lots": {"corbeille": 3.0, "ecrans": 2.5, "coffre": 2.0, "plaza": 2.0, "estrade": 2.0, "bureaux": 1.0, "square": 1.0},
	"min": {"plaza": 4, "corbeille": 3, "coffre": 2, "estrade": 1},
	"lot_size": [24.0, 42.0],
	"avenue": 8.0,
	"blocks": 0.28,
	"block": "glass",
	"border": "city",
	"skyline": "city",
	"sky_ratio": 0.6,
	"ground": Color(0.3, 0.28, 0.3),
	"ground_tex": "Marble012",
	"floor_tex": "Marble012",
	"ambiances": {"nuit": 5.0, "aube": 1.0},
	"facade": ["LA BOURSE", "▲ +∞", "ACHETEZ BAS  ·  VENDEZ LE PEUPLE", Color(0.12, 0.12, 0.16)],
	"slogans": ["LA MAIN INVISIBLE A DES EMPREINTES", "LE MARCHÉ S'AUTORÉGULE : BONKEZ-LE", "SPÉCULATION = 25 ANS DE GOULAG", "LE COURS DU PEUPLE : EN HAUSSE"],
	"shops": ["COURTIER 24/7", "PARADIS FISCAL VOYAGES", "BIJOUTERIE", "CLUB PRIVÉ", "MONTRES DE LUXE"],
	"blimp": "LE MARCHÉ VOUS AIME",
}

# ---------------------------------------------------------------- act II
const PARADIS := {
	"id": "paradis",
	"commons": ["stagiaire", "cadre", "banquier", "influenceur", "avocat"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "lounge",
	"name": "Le Paradis Fiscal",
	"boss": "boss2",
	"roster": [["evade", 40.0, 1.6, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "offshore",      # boss attack pattern (enemies._boss_special)
	"width": [250.0, 290.0],
	"depth": [255.0, 300.0],
	"shapes": {"rect": 2.0, "anneau": 2.0, "L": 2.0, "croix": 1.0},
	"lots": {"plage": 3.0, "marina": 2.0, "boites": 2.0, "coffre": 1.0, "plaza": 1.5, "square": 1.5, "market": 1.0},
	"min": {"plage": 4, "marina": 2, "boites": 2, "plaza": 3},
	"lot_size": [26.0, 44.0],
	"avenue": 9.0,
	"blocks": 0.24,
	"block": "hotel",
	"border": "hotel",
	"skyline": "sea",
	"sky_ratio": 0.6,
	"ground": Color(0.5, 0.46, 0.38),
	"ground_tex": "Ground080",
	"walk_tex": "Tiles101",
	"floor_tex": "Tiles101",
	"ambiances": {"fin_journee": 4.0, "aube": 2.0, "couvert": 0.6},
	"facade": ["OFFSHORE RESORT", "0 %", "VOTRE ARGENT MÉRITE DES VACANCES", Color(0.1, 0.55, 0.6)],
	"slogans": ["L'IMPÔT EST UN DEVOIR, LE PARADIS UN DÉLIT", "NATIONALISONS LES COCOTIERS", "UNE BOÎTE AUX LETTRES N'EST PAS UNE ENTREPRISE", "LE SABLE AU PEUPLE"],
	"shops": ["SOCIÉTÉ ÉCRAN SARL", "BAR DES ÉVADÉS", "BANQUE DISCRÈTE", "YACHT CLUB", "LOCATION DE JET-SKI"],
	"blimp": "0 % D'IMPÔT · 100 % DE SOLEIL",
	"clutter": ["palm"],
	"skins": {
		"stagiaire": {"name": "Plagiste offshore", "looks": [["Beach", "M"], ["Casual", "F"]], "colors": {"LightBrown": Color(0.95, 0.85, 0.6), "Red_Dark": Color(0.1, 0.6, 0.7), "Orange": Color(0.1, 0.6, 0.7)}},
		"cadre": {"name": "Fiscaliste en chemisette", "looks": [["Beach", "M"]], "colors": {"White": Color(1.0, 0.55, 0.2), "Red_Dark": Color(0.95, 0.95, 0.9)}, "acc": ["sunglasses"]},
		"trader": {"name": "Courtier en jet-ski", "looks": [["Beach", "M"]], "colors": {"White": Color(0.2, 0.8, 0.9)}, "acc": ["sunglasses"]},
		"influenceur": {"name": "Influenceuse de Dubaï", "looks": [["Casual", "F"], ["Punk", "F"]], "colors": {"Orange": Color(1.0, 0.85, 0.3), "Pink": Color(1.0, 0.85, 0.3), "Grey": Color(1, 1, 1)}},
		"banquier": {"name": "Banquier suisse", "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.85, 0.85, 0.82), "Tie": Color(0.8, 0.1, 0.1)}},
		"crypto": {"name": "Crypto-nomade", "looks": [["Beach", "M"], ["Casual_Hoodie", "M"]], "colors": {"Purple": Color(0.2, 0.75, 0.45), "LightBrown": Color(0.2, 0.75, 0.45)}},
		"golden": {"name": "Golden Boy bronzé", "looks": [["Beach", "M"]], "colors": {"LightBrown": Color(1.0, 0.75, 0.25), "White": Color(1.0, 0.75, 0.25)}},
		"boss2": {"name": "Le Domicilié", "looks": [["Beach", "M"]], "colors": {"LightBrown": Color(1.0, 0.8, 0.3), "White": Color(0.95, 0.95, 0.95), "Red_Dark": Color(0.1, 0.5, 0.7)}, "acc": ["tophat", "sunglasses", "cigar"]},
	},
}

const STARTUP := {
	"id": "startup",
	"commons": ["stagiaire", "crypto", "coach", "drh", "trader"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "pop",
	"name": "La Start-up Nation",
	"boss": "boss",
	"roster": [["livreur", 40.0, 1.6, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "pivot",      # boss attack pattern (enemies._boss_special)
	"width": [245.0, 285.0],
	"depth": [255.0, 295.0],
	"shapes": {"rect": 2.0, "croix": 2.0, "L": 2.0, "anneau": 1.0},
	"lots": {"bureaux": 2.5, "chill": 3.0, "velos": 2.0, "passerelle": 2.0, "plaza": 1.5, "square": 1.0, "parking": 1.0},
	"min": {"chill": 3, "bureaux": 3, "velos": 2, "passerelle": 2, "plaza": 3},
	"lot_size": [24.0, 42.0],
	"avenue": 9.0,
	"blocks": 0.28,
	"block": "glass",
	"border": "city",
	"skyline": "city",
	"sky_ratio": 0.7,
	"ground": Color(0.4, 0.4, 0.43),
	"floor_tex": "Tiles101",
	"ambiances": {"couvert": 3.0, "fin_journee": 3.0, "aube": 1.0},
	"facade": ["DISRUPT", "SÉRIE B", "ON EST UNE FAMILLE  ·  PAS DE SALAIRE", Color(0.55, 0.25, 0.75)],
	"slogans": ["LA LICORNE EST UN CHEVAL DE TROIE", "UN STAGIAIRE N'EST PAS UNE RESSOURCE RENOUVELABLE", "LE BABY-FOOT NE PAIE PAS LE LOYER", "TOUT LE POUVOIR AUX SOVIETS, PAS AUX PITCHS"],
	"shops": ["INCUBATEUR", "COWORKING VEGAN", "FOOD TRUCK DE QUINOA", "DARK KITCHEN", "SALLE DE PITCH"],
	"blimp": "ON RECRUTE (BÉNÉVOLES)",
	"skins": {
		"stagiaire": {"name": "Stagiaire non payé", "looks": [["Casual_Hoodie", "M"], ["Casual", "F"], ["Casual_2", "M"]], "colors": {"Purple": Color(0.55, 0.3, 0.85), "Orange": Color(0.55, 0.3, 0.85), "LightBrown": Color(0.55, 0.3, 0.85)}},
		"cadre": {"name": "Chief Happiness Officer", "looks": [["Casual_2", "M"], ["Casual", "F"]], "colors": {"LightBrown": Color(1.0, 0.8, 0.2), "Orange": Color(1.0, 0.8, 0.2)}, "acc": ["round_glasses"]},
		"trader": {"name": "Growth Hacker", "looks": [["Casual_Hoodie", "M"]], "colors": {"Purple": Color(0.1, 0.1, 0.12)}, "acc": ["sunglasses"]},
		"crypto": {"name": "Freelance en crypto", "looks": [["Casual_Hoodie", "M"]], "colors": {"Purple": Color(0.2, 0.85, 0.75)}, "acc": ["cap"]},
		"coach": {"name": "Coach agile", "acc": ["cap"]},
		"drh": {"name": "Talent Manager"},
		"golden": {"name": "Business Angel"},
		"boss": {"name": "La Licorne", "looks": [["King", "M"]], "colors": {"Blue": Color(1.0, 0.55, 0.85), "Gold": Color(0.6, 0.9, 1.0)}, "acc": ["tophat", "sunglasses"]},
	},
}

const DATACENTER := {
	"id": "datacenter",
	"commons": ["stagiaire", "cadre", "huissier", "crypto", "lobbyiste"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "techno_data",
	"name": "Le Centre de Données",
	"boss": "boss3",
	"roster": [["moderateur", 40.0, 1.4, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "algo",      # boss attack pattern (enemies._boss_special)
	"width": [240.0, 280.0],
	"depth": [250.0, 290.0],
	"shapes": {"rect": 3.0, "croix": 2.0, "anneau": 2.0},
	"lots": {"serveurs": 4.0, "refroidissement": 2.0, "cables": 2.0, "ecrans": 1.5, "plaza": 1.0, "containers": 1.0},
	"min": {"serveurs": 4, "refroidissement": 2, "cables": 2, "plaza": 3},
	"lot_size": [24.0, 40.0],
	"avenue": 8.0,
	"blocks": 0.3,
	"block": "servers",
	"border": "servers",
	"skyline": "servers",
	"sky_ratio": 0.5,
	"ground": Color(0.22, 0.24, 0.28),
	"ground_tex": "Metal049A",
	"walk_tex": "Concrete034",
	"floor_tex": "Tiles101",
	"ambiances": {"nuit": 5.0, "couvert": 1.0},
	"facade": ["LE NUAGE", "99,9 %", "VOS DONNÉES SONT EN SÉCURITÉ (CHEZ NOUS)", Color(0.1, 0.2, 0.35)],
	"slogans": ["L'ALGORITHME N'A PAS DE CONSCIENCE DE CLASSE", "COLLECTIVISONS LES DONNÉES", "TU N'ES PAS LE CLIENT, TU ES LE PRODUIT", "DÉBRANCHEZ LE CAPITAL"],
	"shops": ["CLOUD SOUVERAIN", "MINAGE 24/7", "FERME À CLICS", "MODÉRATION LOW-COST", "IA GÉNÉRATIVE"],
	"blimp": "J'ACCEPTE LES COOKIES",
	"clutter": ["rack"],
	"skins": {
		"stagiaire": {"name": "Bot d'influence", "looks": [["SciFi", "F"]], "colors": {"Blue": Color(0.2, 0.6, 1.0), "LightBlue": Color(0.6, 0.9, 1.0)}},
		"cadre": {"name": "Modérateur sous-traité", "looks": [["Casual_Hoodie", "M"], ["SciFi", "F"]], "colors": {"Purple": Color(0.3, 0.32, 0.38), "Blue": Color(0.3, 0.32, 0.38)}},
		"influenceur": {"name": "Deepfake", "looks": [["SciFi", "F"]], "colors": {"Blue": Color(1.0, 0.3, 0.8), "Metal": Color(0.9, 0.6, 1.0)}},
		"crypto": {"name": "Mineur de crypto", "looks": [["Casual_Hoodie", "M"]], "colors": {"Purple": Color(1.0, 0.6, 0.1)}},
		"huissier": {"name": "Agent de surveillance", "looks": [["Swat", "M"]], "colors": {"Swat": Color(0.15, 0.2, 0.3)}},
		"drh": {"name": "Algorithme de recrutement", "looks": [["SciFi", "F"]]},
		"golden": {"name": "Data Broker"},
		"boss3": {"name": "L'Algorithme", "looks": [["Spacesuit", "M"]], "colors": {"SciFi_Main": Color(0.12, 0.14, 0.2), "SciFi_Light": Color(0.3, 0.8, 1.0), "SciFi_Light_Accent": Color(1.0, 0.25, 0.3)}, "acc": []},
	},
}

# ---------------------------------------------------------------- act III
const SKI := {
	"id": "ski",
	"commons": ["stagiaire", "cadre", "banquier", "avocat", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "valse",
	"name": "La Station du 1 %",
	"boss": "boss",
	"roster": [["moniteur", 40.0, 1.4, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "avalanche",      # boss attack pattern (enemies._boss_special)
	"width": [250.0, 295.0],
	"depth": [260.0, 305.0],
	"shapes": {"rect": 2.0, "L": 2.0, "anneau": 2.0, "croix": 2.0},
	"lots": {"chalets": 3.0, "sapins": 3.0, "telesiege": 2.0, "piste": 2.0, "plaza": 1.5, "square": 1.0, "parking": 0.8},
	"min": {"chalets": 3, "sapins": 3, "telesiege": 2, "piste": 2, "plaza": 3},
	"lot_size": [26.0, 46.0],
	"avenue": 9.0,
	"blocks": 0.26,
	"block": "rocks",
	"border": "rocks",
	"skyline": "mountains",
	"sky_ratio": 0.0,
	"ground": Color(0.5, 0.52, 0.56),
	"ground_tex": "Snow010A",
	"walk_tex": "PavingStones138",
	"floor_tex": "Snow010A",
	"ambiances": {"aube": 3.0, "couvert": 3.0, "fin_journee": 2.0},
	"facade": ["GRAND HÔTEL DES CIMES", "★★★★★", "L'AIR PUR EST HORS DE PRIX", Color(0.45, 0.2, 0.15)],
	"slogans": ["LA NEIGE TOMBE POUR TOUT LE MONDE", "UN TÉLÉSIÈGE PAR TRAVAILLEUR", "LES PISTES NOIRES AU PEUPLE", "LA RENTE FOND AU SOLEIL"],
	"shops": ["LOCATION DE SKIS EN OR", "FONDUE À 300 €", "SPA PRIVÉ", "BOUTIQUE DE FOURRURES", "CHALET DU CONSEIL D'ADMINISTRATION"],
	"blimp": "LA MONTAGNE EST PRIVÉE",
	"clutter": ["pine"],
	"snow": true,
	"skins": {
		"stagiaire": {"name": "Moniteur saisonnier", "looks": [["Adventurer", "M"], ["Adventurer", "F"]], "colors": {"Green": Color(0.85, 0.12, 0.12), "LightGreen": Color(0.95, 0.95, 0.95)}, "acc": ["sunglasses"]},
		"cadre": {"name": "Héritier en combi dorée", "looks": [["Suit", "M"], ["Suit", "F"]], "colors": {"Suit": Color(1.0, 0.78, 0.3), "Black": Color(1.0, 0.78, 0.3)}, "acc": ["sunglasses"]},
		"trader": {"name": "Snowboardeur fils-à-papa", "looks": [["Casual_Hoodie", "M"], ["Punk", "M"]], "colors": {"Purple": Color(0.1, 0.8, 0.95), "Black": Color(0.1, 0.8, 0.95)}, "acc": ["cap", "sunglasses"]},
		"influenceur": {"name": "Influenceuse après-ski", "looks": [["Casual", "F"]], "colors": {"Orange": Color(0.95, 0.95, 1.0)}},
		"banquier": {"name": "Rentier en fourrure", "looks": [["King", "M"]], "colors": {"Blue": Color(0.55, 0.4, 0.3)}},
		"golden": {"name": "Héritière en chapka"},
		"boss": {"name": "Le Rentier", "looks": [["King", "M"]], "colors": {"Blue": Color(0.95, 0.95, 1.0), "Gold": Color(1.0, 0.78, 0.25)}, "acc": ["tophat", "monocle", "cigar"]},
	},
}

const FUSEE := {
	"id": "fusee",
	"commons": ["stagiaire", "trader", "crypto", "huissier", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "cosmos",
	"name": "La Fusée du Milliardaire",
	"boss": "boss2",
	"roster": [["touriste", 40.0, 1.4, 0.4]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "launch",      # boss attack pattern (enemies._boss_special)
	"width": [255.0, 300.0],
	"depth": [260.0, 305.0],
	"shapes": {"rect": 3.0, "croix": 2.0, "L": 1.0},
	"lots": {"pas_de_tir": 1.0, "carburant": 2.0, "antennes": 2.0, "containers": 2.0, "quai": 1.5, "plaza": 1.5, "parking": 1.0, "empty": 1.0},
	"min": {"pas_de_tir": 2, "carburant": 2, "antennes": 2, "quai": 1, "plaza": 3},
	"lot_size": [26.0, 46.0],
	"avenue": 9.0,
	"blocks": 0.22,
	"block": "hangar",
	"border": "industrial",
	"skyline": "desert",
	"sky_ratio": 0.0,
	"ground": Color(0.6, 0.42, 0.3),
	"ground_tex": "Ground080",
	"floor_tex": "Concrete034",
	"ambiances": {"fin_journee": 3.0, "aube": 2.0, "nuit": 1.0},
	"facade": ["SPACE EXIT", "T-10", "LA PLANÈTE ? ON VOUS LA LAISSE", Color(0.12, 0.12, 0.14)],
	"slogans": ["LA LUNE N'EST À PERSONNE", "PAS DE MILLIARDAIRE SANS OUVRIER AU SOL", "RATTRAPONS-LE AVANT LE DÉCOLLAGE", "L'ORBITE AU PEUPLE"],
	"shops": ["CANTINE DES INGÉNIEURS", "BOUTIQUE DE SOUVENIRS", "SALLE DE CONTRÔLE", "BILLETS POUR MARS", "BUREAU DES NDA"],
	"blimp": "BIENTÔT SUR MARS (PAS VOUS)",
	"gravity": 0.62,
	"skins": {
		"stagiaire": {"name": "Clone de milliardaire", "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.1, 0.1, 0.12)}},
		"cadre": {"name": "Ingénieur sous NDA", "looks": [["Worker", "M"], ["Worker", "F"]], "colors": {"Worker_Yellow": Color(0.95, 0.95, 0.95), "Worker_Vest": Color(0.2, 0.3, 0.5)}},
		"trader": {"name": "Robot livreur", "looks": [["Spacesuit", "M"]], "colors": {"SciFi_Main": Color(0.85, 0.85, 0.88)}},
		"crypto": {"name": "Fan inconditionnel", "looks": [["Casual_Hoodie", "M"]], "colors": {"Purple": Color(0.1, 0.1, 0.1)}, "acc": ["cap"]},
		"avocat": {"name": "Avocat spatial"},
		"golden": {"name": "Touriste orbital", "looks": [["Spacesuit", "M"]], "colors": {"SciFi_Main": Color(1.0, 0.78, 0.3)}},
		"boss2": {"name": "L'Exilé Spatial", "looks": [["Spacesuit", "M"]], "colors": {"SciFi_Main": Color(0.95, 0.95, 0.97), "SciFi_MainDark": Color(0.12, 0.12, 0.14), "SciFi_Light": Color(1.0, 0.45, 0.1)}, "acc": []},
	},
}

const GRAND_SOIR := {
	"id": "grandsoir",
	"commons": ["stagiaire", "cadre", "trader", "avocat", "lobbyiste", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"music": "hymne",
	"name": "Le Grand Soir",
	"boss": "boss3",
	"roster": [["pretorien", 40.0, 1.0, 0.35], ["chef_rayon", 60.0, 0.5, 0.15], ["moderateur", 90.0, 0.5, 0.15], ["touriste", 120.0, 0.5, 0.15]],      # this zone's own capitalists (added to the common spawn table)
	"bpat": "marche",      # boss attack pattern (enemies._boss_special)
	"width": [260.0, 300.0],
	"depth": [265.0, 310.0],
	"shapes": {"rect": 2.0, "croix": 2.0, "anneau": 3.0},
	"lots": {"defile": 3.0, "estrade": 1.5, "plaza": 2.5, "market": 1.5, "square": 2.0, "parking": 1.0, "containers": 0.8},
	"min": {"defile": 4, "estrade": 2, "plaza": 4, "market": 1},
	"lot_size": [26.0, 46.0],
	"avenue": 10.0,
	"blocks": 0.26,
	"block": "palace",
	"border": "city",
	"skyline": "city",
	"sky_ratio": 0.25,
	"ground": Color(0.45, 0.4, 0.4),
	"ground_tex": "PavingStones138",
	"ambiances": {"nuit": 3.0, "fin_journee": 2.0},
	"facade": ["LE GRAND SOIR", "★", "CE SOIR, LE MARCHÉ FERME POUR DE BON", Color(0.7, 0.06, 0.08)],
	"slogans": ["C'EST LA LUTTE FINALE", "DEBOUT LES DAMNÉS DE LA TERRE", "LE MARCHÉ EST MORT, VIVE LE PLAN", "DU PASSÉ FAISONS TABLE RASE"],
	"shops": ["MAISON DU PEUPLE", "CANTINE COLLECTIVE", "BIBLIOTHÈQUE OUVRIÈRE", "SOVIET DE QUARTIER", "COOPÉRATIVE N°1"],
	"blimp": "TOUT LE POUVOIR AUX SOVIETS",
	"plateau_labels": {"estrade": "TRIBUNE DU PEUPLE"},
	"fireworks": true,
	"skins": {
		"boss3": {"name": "Le Marché Lui-Même", "h": 8.0, "looks": [["King", "M"]], "colors": {"Blue": Color(0.1, 0.1, 0.12), "Gold": Color(1.0, 0.8, 0.3), "Metal": Color(1.0, 0.8, 0.3)}, "acc": ["tophat", "monocle", "cigar"]},
	},
}

# special boss level (not part of the three acts): Berlin, spring 1945. Picked from the Kolkhoze on its own.
const SPECIAL := 10
const BERLIN := {
	"id": "berlin",
	"commons": ["stagiaire", "cadre", "huissier", "drh", "actionnaire"],      # the only common capitalists of this zone (+ its signature enemy)
	"special": true,
	"music": "battle",
	"name": "Berlin 1945",
	"boss": "boss3",
	"boss_time": 150.0,      # the horde is only the warm-up: he shows up at 02:30
	"roster": [["pretorien", 20.0, 1.6, 0.4], ["touriste", 70.0, 0.6, 0.2]],
	"bpat": "bunker",
	"bunker": true,          # a lot is kept for the bunker (phase 3 of the fight happens inside)
	"width": [230.0, 260.0],
	"depth": [235.0, 265.0],
	"shapes": {"rect": 2.0, "croix": 2.0, "L": 1.0},
	"lots": {"decombres": 4.0, "plaza": 1.5, "square": 1.0, "empty": 1.0},
	"min": {"decombres": 6, "plaza": 2},
	"lot_size": [26.0, 44.0],
	"avenue": 9.0,
	"blocks": 0.3,
	"block": "ruins",
	"border": "ruins",
	"skyline": "city",
	"ground": Color(0.36, 0.33, 0.3),
	"ground_tex": "Ground080",
	"walk_tex": "PavingStones138",
	"floor_tex": "PavingStones138",
	"ambiances": {"couvert": 3.0, "nuit": 2.0},
	"facade": ["BERLIN", "1945", "IL AVAIT PROMIS MILLE ANS · IL EN A TENU DOUZE", Color(0.45, 0.42, 0.4)],
	"slogans": ["LES TYRANS FINISSENT TOUJOURS DANS UN BUNKER", "L'ARMÉE ROUGE EST À 300 MÈTRES", "IL AVAIT PROMIS MILLE ANS", "PLUS JAMAIS ÇA"],
	"shops": ["BOULANGERIE (FERMÉE)", "ABRI ANTIAÉRIEN", "HÔPITAL DE CAMPAGNE", "U-BAHN", "CANTINE DE L'ARMÉE ROUGE"],
	"blimp": "",
	"clutter": ["dumpster"],
	"skins": {
		"stagiaire": {"name": "Conscrit perdu", "looks": [["Soldier", "F"], ["Swat", "M"]], "colors": {"Swat": Color(0.38, 0.4, 0.34), "Swat_Black": Color(0.2, 0.2, 0.2), "Visor": Color(0.2, 0.2, 0.2)}},
		"cadre": {"name": "Bureaucrate du régime", "looks": [["Suit", "M"], ["Suit", "F"]], "colors": {"Suit": Color(0.35, 0.36, 0.34), "Tie": Color(0.1, 0.1, 0.1)}, "acc": ["officer_cap"]},
		"trader": {"name": "Motard de liaison", "looks": [["Swat", "M"]], "colors": {"Swat": Color(0.3, 0.32, 0.28)}},
		"influenceur": {"name": "Propagandiste", "looks": [["Formal", "F"], ["Suit", "M"]], "colors": {"Red": Color(0.3, 0.3, 0.3), "Suit": Color(0.3, 0.3, 0.3)}},
		"banquier": {"name": "Banquier suisse", "acc": ["tophat", "monocle"]},
		"crypto": {"name": "Grenadier paniqué", "looks": [["Soldier", "F"], ["Swat", "M"]], "colors": {"Swat": Color(0.4, 0.38, 0.3)}},
		"avocat": {"name": "Juriste du régime"},
		"huissier": {"name": "Agent de la police secrète", "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.08, 0.08, 0.09), "Tie": Color(0.08, 0.08, 0.09)}, "acc": ["round_glasses"]},
		"coach": {"name": "Médecin du bunker", "looks": [["Formal", "F"]], "colors": {"Red": Color(0.9, 0.9, 0.88)}},
		"lobbyiste": {"name": "Industriel complice"},
		"drh": {"name": "Officier recruteur", "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.35, 0.37, 0.3)}, "acc": ["officer_cap"]},
		"actionnaire": {"name": "Général à monocle", "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.3, 0.32, 0.27)}, "acc": ["officer_cap", "monocle"]},
		"golden": {"name": "Maréchal déchu", "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.32, 0.33, 0.3), "Tie": Color(0.75, 0.6, 0.2)}, "acc": ["officer_cap", "monocle"]},
		"pretorien": {"name": "Garde du bunker"},
		"touriste": {"name": "Aviateur sans avion", "looks": [["Soldier", "F"], ["Swat", "M"]], "colors": {"Swat": Color(0.35, 0.4, 0.45)}},
		"boss3": {"name": "Le Führer de Pacotille", "h": 4.4, "looks": [["Suit", "M"]], "colors": {"Suit": Color(0.55, 0.47, 0.32), "Tie": Color(0.08, 0.08, 0.08), "White": Color(0.62, 0.5, 0.33), "Hair": Color(0.06, 0.05, 0.05), "Eyebrows": Color(0.06, 0.05, 0.05)}, "acc": [], "dictator": true},
	},
}

const ZONES := [HYPERMARCHE, QUARTIER, BOURSE, PARADIS, STARTUP, DATACENTER, SKI, FUSEE, GRAND_SOIR]
const ACTS := ["ACTE I · LA VILLE", "ACTE II · LE CAPITAL MONDIALISÉ", "ACTE III · LA LUTTE FINALE"]

static func zone(n: int) -> Dictionary:
	if n == SPECIAL: return BERLIN
	return ZONES[(n - 1) % ZONES.size()]

static func count() -> int:
	return ZONES.size()

# next zone in the menus' cycle: 1..9, then the special level, then back to 1 (locked zones skipped)
static func next_zone(z: int) -> int:
	var order: Array = range(1, ZONES.size() + 1) + [SPECIAL]
	var i: int = order.find(z)
	for k in order.size():
		var n: int = order[(i + 1 + k) % order.size()]
		if Meta.zone_unlocked(n): return n
	return 1

# "ZONE 4 : LE PARADIS FISCAL" or "CARTE BONUS : BERLIN 1945"
static func label(n: int) -> String:
	return ("CARTE BONUS : " if n == SPECIAL else "ZONE %d : " % n) + (zone(n)["name"] as String).to_upper()

static func special(n: int) -> bool:
	return n == SPECIAL

# zone 3, 6 and 9 close an act: beating their boss wins the run (the special level too)
static func act_end(n: int) -> bool:
	return n % 3 == 0 or n == SPECIAL

static func act(n: int) -> int:
	if n == SPECIAL: return 2      # tuned like the last act
	return ((n - 1) % ZONES.size()) / 3

# position inside the act (0, 1, 2)
static func slot(n: int) -> int:
	if n == SPECIAL: return 2
	return (n - 1) % 3

static func pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights: total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0: return k
	return weights.keys()[0]

# ---------------------------------------------------------------- enemy skins of the current zone
static var cur: Dictionary = HYPERMARCHE
static var _defs := {}

static func set_zone(tpl: Dictionary):
	cur = tpl
	_defs.clear()

static func skin(kind: String) -> Dictionary:
	return cur.get("skins", {}).get(kind, {})

# enemy definition with this zone's overrides (name, height, accessories)
static func edef(kind: String) -> Dictionary:
	if _defs.has(kind): return _defs[kind]
	var d: Dictionary = Data.ENEMIES[kind]
	var s := skin(kind)
	if not s.is_empty():
		d = d.duplicate()
		for k in ["name", "acc", "h"]:
			if s.has(k): d[k] = s[k]
	_defs[kind] = d
	return d
