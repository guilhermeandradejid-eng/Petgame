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
	{
		"name": "Yham", "special": "furacao", "desc": "Atleta", "hair": "Hair_Afro",
		"skin": Color("9a6440"), "hair_color": Color("1b120c"), "accent": Color("2ec27e"),
		"racket": Color("ff6b2e"), "speed": 1.06, "power": 1.08, "control": 0.94,
	},
	{
		"name": "Nath", "special": "sakura", "desc": "Técnica", "hair": "Hair_PonyHigh", "eyes": "Eyes_Almond",
		"skin": Color("f3d3b5"), "hair_color": Color("15101a"), "accent": Color("ff4f8b"),
		"racket": Color("ff4f8b"), "speed": 1.1, "power": 0.9, "control": 1.1,
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

## Partidas: as curtas vão até N games; o SET OFICIAL segue a regra da ITF
## (6 games com 2 de vantagem, tie-break até 7 no 6-6, ponto de ouro no 40-40).
const LENGTHS := [
	{"name": "RÁPIDA", "games": 2, "official": false},
	{"name": "NORMAL", "games": 4, "official": false},
	{"name": "SET OFICIAL", "games": 6, "official": true},
]

## Roupas: peças visíveis do modelo (a cor vem da paleta do time)
const OUTFITS := [
	{"name": "CAMISETA", "parts": ["Shirt", "Shorts"]},
	{"name": "REGATA", "parts": ["Tank", "Shorts"]},
	{"name": "LISTRADA", "parts": ["Shirt", "Stripe0", "Stripe1", "Bermuda"]},
	{"name": "ATLETA", "parts": ["Tank", "Bermuda"]},
]
const CLOTH_PARTS := ["Shirt", "Tank", "Stripe0", "Stripe1", "Shorts", "Bermuda"]

## Paletas de cada time (camisa, detalhe, short): sempre no tom do time
const PALETTES := [
	[
		{"name": "AZUL", "shirt": Color("2f8cff"), "trim": Color("ffffff"), "shorts": Color("ffd23f")},
		{"name": "MARINHO", "shirt": Color("2346b8"), "trim": Color("4fe0ff"), "shorts": Color("ffffff")},
		{"name": "CÉU", "shirt": Color("5cc8ff"), "trim": Color("1f3a8a"), "shorts": Color("1f3a8a")},
	],
	[
		{"name": "VERMELHO", "shirt": Color("ff4b3e"), "trim": Color("ffe14d"), "shorts": Color("26304f")},
		{"name": "LARANJA", "shirt": Color("ff7a2e"), "trim": Color("ffffff"), "shorts": Color("c81e3a")},
		{"name": "CEREJA", "shirt": Color("d62246"), "trim": Color("ffd23f"), "shorts": Color("ffffff")},
	],
]

## Raquetes: modelo + pequeno ajuste de força/controle
const RACKETS := [
	{"name": "CLÁSSICA", "desc": "EQUILIBRADA", "power": 1.0, "control": 1.0},
	{"name": "GOTA", "desc": "+ CONTROLE", "power": 0.95, "control": 1.07},
	{"name": "POWER", "desc": "+ FORÇA", "power": 1.07, "control": 0.95},
]
const RACKET_COLORS := [Color("ff5fa2"), Color("35e0a1"), Color("ffd23f"), Color("9b5de5"),
	Color("ff9f1c"), Color("19d3ff"), Color("f4f1ea"), Color("2b2b3a")]
const RACKET_COLOR_NAMES := ["ROSA", "VERDE", "AMARELA", "ROXA", "LARANJA", "CIANO", "BRANCA", "PRETA"]

const POINT_NAMES := ["0", "15", "30", "40"]

## Arenas: a mesma praia no fim de tarde ou à noite, com refletores e luar
const ARENAS := [
	{"id": "sunset", "name": "PÔR DO SOL"},
	{"id": "night", "name": "NOITE NA ORLA"},
]

static var char_index := 0
static var char_index_p2 := 2
static var mode := "solo"      # solo, vs (tela dividida), coop
static var difficulty := 1
static var length_index := 0
static var music_on := true
static var arena := 0
# visual escolhido no vestiário por J1 e J2: roupa, paleta, raquete e cor (-1 = cor do personagem)
static var looks := [
	{"outfit": 0, "palette": 0, "racket": 0, "racket_color": -1},
	{"outfit": 1, "palette": 0, "racket": 1, "racket_color": -1},
]


static func racket_color(char_data: Dictionary, look: Dictionary) -> Color:
	var i: int = look.get("racket_color", -1)
	return RACKET_COLORS[i] if i >= 0 else char_data.get("racket", Color.WHITE)


## Dados do personagem com o ajuste da raquete aplicado
static func with_racket(char_data: Dictionary, look: Dictionary) -> Dictionary:
	var d := char_data.duplicate()
	var r: Dictionary = RACKETS[clampi(int(look.get("racket", 0)), 0, RACKETS.size() - 1)]
	d["power"] = float(d["power"]) * float(r["power"])
	d["control"] = float(d["control"]) * float(r["control"])
	return d
