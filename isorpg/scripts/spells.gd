class_name Spells
extends RefCounted
## The spell book. Each spell names the mage animation that casts it; the effect starts on that
## animation's "release" event, a logical frame frozen in the sprite contract.

const LIST := [
	{"id": "bolt", "name": "Seta Arcana", "anim": "cast", "cd": 0.35, "range": 5.0,
		"color": Color(0.55, 1.0, 1.0), "rune": "arcane", "keys": [KEY_1, KEY_Q], "aim": true},
	{"id": "comet", "name": "Cometa", "anim": "summon", "cd": 6.0, "range": 7.0,
		"color": Color(1.0, 0.82, 0.45), "rune": "astral", "keys": [KEY_2, KEY_W], "aim": true},
	{"id": "fire", "name": "Anel de Fogo", "anim": "spin", "cd": 5.0, "range": 0.0,
		"color": Color(1.0, 0.55, 0.22), "rune": "fire", "keys": [KEY_3, KEY_E], "aim": false},
	{"id": "ice", "name": "Lança de Gelo", "anim": "thrust", "cd": 3.5, "range": 9.0,
		"color": Color(0.72, 0.92, 1.0), "rune": "ice", "keys": [KEY_4, KEY_R], "aim": true},
]

static var _runes := {}


static func rune_texture(name: String) -> Texture2D:
	if not _runes.has(name):
		_runes[name] = load("res://assets/gen/fx/rune_%s.png" % name)
	return _runes[name]
