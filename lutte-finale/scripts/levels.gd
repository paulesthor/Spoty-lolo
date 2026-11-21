class_name Levels
# Level templates: the global structure each procedural map must respect.
# A run crosses the three zones in order; endless mode loops over them.

const HYPERMARCHE := {
	"id": "hypermarche",
	"name": "L'Hypermarché",
	"boss": "boss",
	"width": [150.0, 185.0],
	"depth": [160.0, 195.0],
	# arena shapes and their weights
	"shapes": {"rect": 3.0, "L": 2.0, "croix": 2.0, "anneau": 2.0},
	# lot catalogue (weights) and guaranteed minimum counts
	"lots": {"parking": 4.0, "containers": 2.0, "market": 2.0, "plaza": 2.0, "chantier": 1.2, "quai": 1.5, "station": 1.0, "square": 1.5, "empty": 1.0},
	"min": {"plaza": 3, "market": 1, "containers": 1, "quai": 1, "chantier": 1},
	"lot_size": [26.0, 46.0],
	"avenue": 8.0,
	"sky_ratio": 0.33,
	"ground": Color(0.42, 0.43, 0.46),
	# lighting moods and their weights
	"ambiances": {"fin_journee": 6.0, "couvert": 2.5, "aube": 1.5},
	"facade": ["HYPERMARCHÉ", "-70 %", "ACHETEZ.  CONSOMMEZ.  RECOMMENCEZ.", Color(0.15, 0.5, 0.28)],
	"slogans": ["TRAVAILLEURS DE TOUS LES PAYS, BONKEZ-VOUS", "LE PLAN QUINQUENNAL SERA BONKÉ EN 4 ANS", "LE CAPITAL EST UN TIGRE DE PAPIER. BONKEZ LE PAPIER.", "UN SPECTRE HANTE L'HYPERMARCHÉ"],
}

const QUARTIER := {
	"id": "quartier",
	"name": "Le Quartier d'Affaires",
	"boss": "boss2",
	"width": [140.0, 170.0],
	"depth": [160.0, 190.0],
	"shapes": {"rect": 2.0, "croix": 3.0, "anneau": 2.0, "L": 1.0},
	"lots": {"bureaux": 3.0, "passerelle": 3.0, "plaza": 2.0, "parking": 1.5, "square": 1.5, "chantier": 1.0, "empty": 0.8},
	"min": {"plaza": 3, "passerelle": 3, "bureaux": 2},
	"lot_size": [24.0, 40.0],
	"avenue": 9.0,
	"sky_ratio": 0.8,
	"ground": Color(0.36, 0.37, 0.4),
	"ambiances": {"couvert": 4.0, "fin_journee": 3.0, "aube": 2.0},
	"facade": ["TOUR CAPITAL", "+12 %", "OPEN SPACE  ·  BURN-OUT  ·  TEAM BUILDING", Color(0.2, 0.3, 0.45)],
	"slogans": ["LE PROLÉTARIAT N'A RIEN À PERDRE, SAUF SES RÉUNIONS", "UN BUREAU PAR TRAVAILLEUR, UNE CHAISE PAR BUREAU", "LES TOURS TOMBENT, LE PEUPLE RESTE", "SYNERGIE : MOT INTERDIT PAR LE PARTI"],
}

const BOURSE := {
	"id": "bourse",
	"name": "La Bourse",
	"boss": "boss3",
	"width": [140.0, 165.0],
	"depth": [150.0, 180.0],
	"shapes": {"rect": 2.0, "anneau": 3.0, "croix": 2.0},
	"lots": {"corbeille": 3.0, "ecrans": 2.5, "coffre": 2.0, "plaza": 2.0, "estrade": 2.0, "bureaux": 1.0, "square": 1.0},
	"min": {"plaza": 3, "corbeille": 2, "coffre": 1, "estrade": 1},
	"lot_size": [24.0, 42.0],
	"avenue": 8.0,
	"sky_ratio": 0.6,
	"ground": Color(0.3, 0.28, 0.3),
	"ambiances": {"nuit": 5.0, "aube": 1.0},
	"facade": ["LA BOURSE", "▲ +∞", "ACHETEZ BAS  ·  VENDEZ LE PEUPLE", Color(0.12, 0.12, 0.16)],
	"slogans": ["LA MAIN INVISIBLE A DES EMPREINTES", "LE MARCHÉ S'AUTORÉGULE : BONKEZ-LE", "SPÉCULATION = 25 ANS DE GOULAG", "LE COURS DU PEUPLE : EN HAUSSE"],
}

const ZONES := [HYPERMARCHE, QUARTIER, BOURSE]

static func zone(n: int) -> Dictionary:
	return ZONES[(n - 1) % ZONES.size()]

static func pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights: total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0: return k
	return weights.keys()[0]
