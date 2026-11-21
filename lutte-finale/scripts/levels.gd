class_name Levels
# Level templates: the global structure each procedural map must respect.

const HYPERMARCHE := {
	"name": "L'Hypermarché",
	"width": [150.0, 185.0],
	"depth": [160.0, 195.0],
	# arena shapes and their weights
	"shapes": {"rect": 3.0, "L": 2.0, "croix": 2.0, "anneau": 2.0},
	# lot catalogue (weights) and guaranteed minimum counts
	"lots": {"parking": 4.0, "containers": 2.0, "market": 2.0, "plaza": 2.0, "chantier": 1.2, "quai": 1.5, "station": 1.0, "square": 1.5, "empty": 1.0},
	"min": {"plaza": 3, "market": 1, "containers": 1, "quai": 1, "chantier": 1},
	"lot_size": [26.0, 46.0],
	"avenue": 8.0,
	# lighting moods and their weights
	"ambiances": {"fin_journee": 6.0, "couvert": 2.5, "aube": 1.5},
}

static func pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights: total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0: return k
	return weights.keys()[0]
