class_name GameData
## Dados fixos do jogo: personagens, times, dificuldades e configurações da partida.

const COURT_HALF_W := 4.0      # quadra de duplas: 8 m x 16 m
const COURT_HALF_L := 8.0
const NET_H := 1.7             # altura oficial da rede no beach tennis
const NET_HALF_W := 4.6
const CHAR_SCALE := 0.86

const CHARACTERS := [
	{
		"name": "Tuca", "special": "tsunami", "desc": "Equilibrado", "hair": "Hair_Spiky",
		"skin": Color("f2b98a"), "hair_color": Color("3b2416"), "accent": Color("ff3b3b"),
		"racket": Color("ff5fa2"), "speed": 1.0, "power": 1.0, "control": 1.0,
	},
	{
		"name": "Bia", "special": "raio", "desc": "Velocista", "hair": "Hair_Pony",
		"skin": Color("d39a6a"), "hair_color": Color("ff7a2e"), "accent": Color("7c4dff"),
		"racket": Color("35e0a1"), "speed": 1.12, "power": 0.9, "control": 1.0,
	},
	{
		"name": "Zeca", "special": "meteoro", "desc": "Pancadão", "hair": "Cap",
		"skin": Color("8d5a3b"), "hair_color": Color("1d1d1d"), "accent": Color("ff9f1c"),
		"racket": Color("ffd23f"), "speed": 0.93, "power": 1.2, "control": 0.92,
	},
	{
		"name": "Lola", "special": "bumerangue", "desc": "Precisa", "hair": "Hair_Puffs",
		"skin": Color("5e3a26"), "hair_color": Color("2a1a14"), "accent": Color("19d3ff"),
		"racket": Color("9b5de5"), "speed": 0.98, "power": 0.95, "control": 1.18,
	},
]

const TEAMS := [
	{"name": "TUBARÕES", "shirt": Color("2f8cff"), "trim": Color("ffffff"), "shorts": Color("ffd23f")},
	{"name": "SIRIS", "shirt": Color("ff4b3e"), "trim": Color("ffe14d"), "shorts": Color("26304f")},
]

const DIFFICULTIES := [
	{"name": "FÁCIL", "reaction": 0.36, "speed": 0.84, "error": 1.25, "smash": 0.45, "judge": 0.45, "dive": 0.5},
	{"name": "MÉDIO", "reaction": 0.24, "speed": 0.9, "error": 0.8, "smash": 0.75, "judge": 0.75, "dive": 0.8},
	{"name": "DIFÍCIL", "reaction": 0.14, "speed": 0.98, "error": 0.45, "smash": 0.95, "judge": 0.95, "dive": 1.0},
]

const LENGTHS := [
	{"name": "RÁPIDA", "games": 2},
	{"name": "NORMAL", "games": 4},
]

const POINT_NAMES := ["0", "15", "30", "40"]

static var char_index := 0
static var char_index_p2 := 2
static var mode := "solo"      # solo, vs (tela dividida), coop
static var difficulty := 1
static var length_index := 0
static var music_on := true
