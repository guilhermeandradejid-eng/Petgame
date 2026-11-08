class_name Career
extends Node
## Carreira estilo Rock n' Roll Racing: mundos com 3 pistas cada. Cada corrida dá dinheiro e PONTOS pela
## colocação; com os pontos do mundo o CHEFE é liberado; vencer o chefe abre o próximo mundo.
## Dinheiro compra carros únicos (cada um com armas próprias) e upgrades por carro.

const WORLDS := [
	{"name": "PARQUE", "theme": "park", "tracks": [0, 1, 2, 3], "boss_track": 1, "need": 24, "boss": "boss_brutus", "boss_name": "BRUTUS, O ROLO",
		"boss_desc": "Van blindada gigante. TREMOR: marca um círculo onde você vai passar e explode o chão. BARRIS: rola barris gigantes para trás.",
		"boss_col": "#4a4652", "mult": 1.0, "lv": 0, "col": "#7dff6a"},
	{"name": "PÂNTANO", "theme": "swamp", "tracks": [4, 5, 6, 7], "boss_track": 6, "need": 28, "boss": "boss_croc", "boss_name": "CROCODILO DO BREJO",
		"boss_desc": "Picape-crocodilo gigante. LAMA: cospe poças que atolam o carro e sujam a tela. BOTE: marca uma faixa da pista e dá um bote lateral nela.",
		"boss_col": "#3f6b2a", "mult": 1.4, "lv": 0, "col": "#a3d977"},
	{"name": "DESERTO", "theme": "desert", "tracks": [8, 9, 10, 11], "boss_track": 9, "need": 30, "boss": "boss_xerife", "boss_name": "XERIFE DE AÇO",
		"boss_desc": "Viatura colossal. ÍMÃ: um raio te puxa para perto e segura sua velocidade. BLOQUEIO: fileira de pregos na pista com uma brecha.",
		"boss_col": "#1c1f2a", "mult": 1.8, "lv": 1, "col": "#ffb21a"},
	{"name": "NEVE", "theme": "snow", "tracks": [12, 13, 14, 15], "boss_track": 13, "need": 32, "boss": "boss_avalanche", "boss_name": "AVALANCHE",
		"boss_desc": "Trophy truck da neve. BOLAS DE NEVE: rola bolas gigantes pela pista contra você (faixas avisadas). GELO: transforma um trecho em gelo liso.",
		"boss_col": "#dfe9f7", "mult": 2.2, "lv": 1, "col": "#bfe6ff"},
	{"name": "CIDADE NEON", "theme": "city", "tracks": [16, 17, 18, 19], "boss_track": 16, "need": 34, "boss": "boss_blackout", "boss_name": "BLACKOUT",
		"boss_desc": "Sedã hacker. PULSO EMP: anel que desliga suas armas e o especial por 3 s. PORTÕES LASER: barreiras que ligam e desligam na pista.",
		"boss_col": "#14141e", "mult": 2.7, "lv": 2, "col": "#c04de0"},
	{"name": "CÉU", "theme": "sky", "tracks": [20, 21, 22, 23], "boss_track": 20, "need": 36, "boss": "boss_imperador", "boss_name": "O IMPERADOR",
		"boss_desc": "Muscle car dourado. METEOROS: círculos vermelhos caem do céu à sua frente. MURO DE FOGO: deixa a pista em chamas atrás de si.",
		"boss_col": "#d4a017", "mult": 3.2, "lv": 3, "col": "#2ee6ff"},
]
const POINTS := [10, 7, 5, 3, 2, 1, 0, 0]
const EXTRA_TRACKS := [24, 25]   # Porto e Loop Mania: corrida rápida e multijogador
const BOSS_PRIZE := [3000, 4500, 6000, 8000, 10000, 15000]
## carros à venda: preço e mundo em que aparecem na loja
const SHOP := {
	"faisca": {"price": 0, "world": 0, "name": "FAÍSCA", "desc": "Equilibrado e rápido no nitro."},
	"vespa": {"price": 3000, "world": 0, "name": "VESPA", "desc": "Buggy leve: o mais ágil, pula obstáculos."},
	"trovao": {"price": 6500, "world": 2, "name": "TROVÃO", "desc": "Muscle car blindado: foguetes e escudo."},
	"monstro": {"price": 11000, "world": 3, "name": "MONSTRO", "desc": "Picape pesada: fogo, barris e choque."},
}
const CAR_ORDER := ["faisca", "vespa", "trovao", "monstro"]
const UP_MULT := {"faisca": 1.0, "vespa": 1.15, "trovao": 1.35, "monstro": 1.6}
const WEAPON_DESC := {
	"mg": "Rajada contínua de balas.", "rocket": "Foguete teleguiado no alvo da frente.",
	"zap": "Raio instantâneo que salta para um 2º carro.", "flame": "Jato curto que incendeia (dano contínuo).",
	"oil": "Mancha que faz rodopiar.", "mine": "Explode quando alguém passa.",
	"spikes": "Furam os pneus: o carro fica lento.", "barrel": "Barril rola para trás e explode.",
	"short": "Nitro: arrancada curta.", "jump": "Salto: pula minas, óleo e carros.",
	"shield": "Escudo: 3 s invulnerável + aríete.", "shock": "Onda de choque: arremessa quem está perto.",
}

var game: Node
var hud: Hud
var event := {}            # corrida atual da carreira: {"world", "track", "boss"}
var scr_map: Control
var scr_world: Control
var map_box: GridContainer
var world_box: VBoxContainer
var cur_world := 0


func setup(g: Node, h: Hud) -> void:
	game = g
	hud = h
	_migrate()
	_build_map()
	_build_world()


## save antigo -> carreira: o carro e os upgrades viram o primeiro carro da garagem
func _migrate() -> void:
	var s: Dictionary = game.save
	if not s.has("career"):
		s.career = {"unlocked": 0, "points": [0, 0, 0, 0, 0, 0], "beaten": [false, false, false, false, false, false], "best": {}}
	# saves de quando havia 3 mundos: completa até 6
	while s.career.points.size() < WORLDS.size():
		s.career.points.append(0)
	while s.career.beaten.size() < WORLDS.size():
		s.career.beaten.append(false)
	if not s.has("garage"):
		var start: String = s.get("car", "faisca") if String(s.get("car", "faisca")) in SHOP else "faisca"
		s.garage = {"owned": [start], "up": {}}
		s.garage.up[start] = (s.get("up", {}) as Dictionary).duplicate()
	for k in CAR_ORDER:
		if not s.garage.up.has(k):
			s.garage.up[k] = {}
		for u in ["engine", "armor", "ammo", "rear", "nitro", "tires"]:
			s.garage.up[k][u] = int(s.garage.up[k].get(u, 0))
	if not String(s.car) in s.garage.owned:
		s.car = s.garage.owned[0]
	s.up = s.garage.up[s.car]
	var lo: Array = Car.LOADOUT[s.car]
	s.front = lo[0]
	s.rear = lo[1]
	s.nitro = lo[2]


func owned(k: String) -> bool:
	return k in game.save.garage.owned


func available(k: String) -> bool:
	return int(SHOP[k].world) <= int(game.save.career.unlocked)


## escolhe (ou compra) um carro na garagem
func pick_car(k: String) -> String:
	var s: Dictionary = game.save
	if not owned(k):
		if not available(k):
			return "Disponível no MUNDO %d" % (int(SHOP[k].world) + 1)
		var price: int = SHOP[k].price
		if int(s.cash) < price:
			return "Faltam $%d" % (price - int(s.cash))
		s.cash = int(s.cash) - price
		s.garage.owned.append(k)
		game.sfx.play("coin")
	s.car = k
	s.up = s.garage.up[k]
	var lo: Array = Car.LOADOUT[k]
	s.front = lo[0]
	s.rear = lo[1]
	s.nitro = lo[2]
	game._write_save()
	return ""


func up_price(k: String) -> int:
	var lvl := int(game.save.up.get(k, 0))
	return int(game.UP_PRICE[mini(lvl, 2)] * float(UP_MULT.get(String(game.save.car), 1.0)))


func world_open(i: int) -> bool:
	return i <= int(game.save.career.unlocked)


func boss_open(i: int) -> bool:
	return int(game.save.career.points[i]) >= int(WORLDS[i].need)


# ------------------------------------------------------------------ telas
func _build_map() -> void:
	scr_map = hud._screen(0.86)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 60)
	m.add_theme_constant_override("margin_top", 36)
	m.add_theme_constant_override("margin_bottom", 30)
	scr_map.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	UI.title(v, "CARREIRA", 50)
	UI.checker(v, 300, 10)
	UI.text(v, "Cada corrida dá dinheiro e pontos (1º 10 · 2º 7 · 3º 5 · 4º 3 · 5º 2). Some os pontos do mundo para enfrentar o chefe; vença o chefe para abrir o próximo mundo.", 16, UI.MUTED, true)
	map_box = GridContainer.new()
	map_box.columns = 3
	map_box.add_theme_constant_override("h_separation", 18)
	map_box.add_theme_constant_override("v_separation", 16)
	map_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(map_box)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 16)
	v.add_child(bot)
	var back := hud._btn("VOLTAR", bot, false, 220, 54)
	back.pressed.connect(func(): hud.show_screen("menu"))
	hud.extra_screens["career"] = scr_map
	scr_map.visible = false


func open() -> void:
	game.set_solo()
	event = {}
	for ch in map_box.get_children():
		ch.queue_free()
	var s: Dictionary = game.save
	for i in WORLDS.size():
		var w: Dictionary = WORLDS[i]
		var open_ := world_open(i)
		var pc := Button.new()
		pc.custom_minimum_size = Vector2(370, 196)
		pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pc.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pc.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var c := Color(w.col)
		var base := UI.box(Color(0.1, 0.09, 0.19, 0.95) if open_ else Color(0.07, 0.06, 0.1, 0.9), c if open_ else UI.LINE, 3, 0.08, 8, Color(0, 0, 0, 0.5), 10)
		base.border_width_top = 10
		var hov := UI.box(Color(0.16, 0.14, 0.28, 0.98), Color.WHITE, 4, 0.08, 8, Color.WHITE, 10)
		hov.border_width_top = 10
		pc.add_theme_stylebox_override("normal", base)
		pc.add_theme_stylebox_override("hover", hov)
		pc.add_theme_stylebox_override("focus", hov)
		pc.add_theme_stylebox_override("pressed", hov)
		pc.add_theme_stylebox_override("disabled", base)
		pc.add_theme_font_override("font", UI.display_it)
		pc.add_theme_font_size_override("font_size", 15)
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
			pc.add_theme_color_override(k, UI.TEXT if open_ else Color(1, 1, 1, 0.35))
		var tracks: Array = []
		for t in w.tracks:
			tracks.append("· " + String(TrackData.TRACKS[t].name).to_upper())
		var pts: int = s.career.points[i]
		var state := "BLOQUEADO · vença o chefe do mundo %d" % i if not open_ else ("CHEFE DERROTADO ★" if bool(s.career.beaten[i]) else ("CHEFE LIBERADO!" if boss_open(i) else "%d / %d PONTOS" % [pts, int(w.need)]))
		pc.text = "MUNDO %d · %s\n4 pistas · prêmios x%.1f\nCHEFE: %s\n\n%s" % [i + 1, w.name, float(w.mult), w.boss_name, state]
		pc.disabled = not open_
		var wi := i
		pc.pressed.connect(func(): open_world(wi))
		map_box.add_child(pc)
	hud.show_screen("career")


func _build_world() -> void:
	scr_world = hud._screen(0.86)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 60)
	m.add_theme_constant_override("margin_top", 36)
	m.add_theme_constant_override("margin_bottom", 30)
	scr_world.add_child(m)
	world_box = VBoxContainer.new()
	world_box.add_theme_constant_override("separation", 12)
	m.add_child(world_box)
	hud.extra_screens["world"] = scr_world
	scr_world.visible = false


func open_world(i: int) -> void:
	cur_world = i
	game.set_solo()
	for ch in world_box.get_children():
		ch.queue_free()
	var w: Dictionary = WORLDS[i]
	var s: Dictionary = game.save
	UI.title(world_box, "MUNDO %d · %s" % [i + 1, w.name], 46)
	UI.checker(world_box, 300, 10)
	var pts: int = s.career.points[i]
	var need: int = w.need
	# barra de pontos até o chefe
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(620, 34)
	bar.draw.connect(func():
		var u := clampf(float(pts) / need, 0.0, 1.0)
		var sk := 12.0
		var W := bar.size.x
		bar.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(W, 0), Vector2(W - sk, 18), Vector2(0, 18)]), Color(1, 1, 1, 0.1))
		if u > 0.0:
			bar.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(sk + (W - sk) * u, 0), Vector2((W - sk) * u, 18), Vector2(0, 18)]), Color(w.col))
		bar.draw_string(UI.display_it, Vector2(0, 34), "%d / %d PONTOS PARA ENFRENTAR O CHEFE" % [pts, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.TEXT))
	world_box.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	world_box.add_child(row)
	for t in w.tracks:
		var d: Dictionary = TrackData.TRACKS[t]
		var best: Dictionary = s.career.best.get(str(t), {})
		var b := hud._btn("%s\n%s" % [String(d.name).to_upper(), ("melhor: %dº" % int(best.place)) if best.has("place") else "ainda não correu"], row, false, 262, 92)
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = String(d.desc)
		var ti: int = t
		b.pressed.connect(func(): choose(i, ti, false))
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", UI.panel_box(Color(w.boss_col).lightened(0.3)))
	world_box.add_child(bp)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bp.add_child(bv)
	UI.title(bv, "CHEFE: " + String(w.boss_name), 26, UI.BAD)
	var dl := UI.text(bv, String(w.boss_desc), 16, UI.TEXT, true)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(900, 0)
	UI.text(bv, "Pista: %s · vença chegando na frente dele · prêmio $%d" % [String(TrackData.TRACKS[w.boss_track].name).to_upper(), int(BOSS_PRIZE[i])], 15, UI.MUTED)
	var bb := hud._btn("ENFRENTAR O CHEFE" if boss_open(i) else "PRECISA DE %d PONTOS" % need, bv, boss_open(i), 380, 58)
	bb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bb.disabled = not boss_open(i)
	bb.pressed.connect(func(): choose(i, int(w.boss_track), true))
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 16)
	world_box.add_child(bot)
	hud._btn("VOLTAR", bot, false, 220, 54).pressed.connect(open)
	UI.text(bot, "   $ %d" % int(s.cash), 22, UI.OK).add_theme_font_override("font", UI.display_it)
	hud.show_screen("world")


func choose(world: int, track: int, boss: bool) -> void:
	event = {"world": world, "track": track, "boss": boss}
	game.load_track(track)
	hud.show_screen("garage")


func active() -> bool:
	return not event.is_empty() and game.session.kind == "solo"


## multiplicador de prêmio da corrida atual
func mult() -> float:
	return float(WORLDS[int(event.world)].mult) if active() else 1.0


## resultado da corrida: pontos, chefe, desbloqueio. Devolve linhas para a tela de resultado.
func apply_result(place: int, beat_boss: bool) -> Array:
	var lines: Array = []
	if not active():
		return lines
	var s: Dictionary = game.save
	var wi: int = event.world
	var w: Dictionary = WORLDS[wi]
	var key := str(event.track)
	var best: Dictionary = s.career.best.get(key, {})
	if not best.has("place") or place < int(best.place):
		s.career.best[key] = {"place": place}
	if event.boss:
		if beat_boss:
			var first := not bool(s.career.beaten[wi])
			s.career.beaten[wi] = true
			var prize: int = BOSS_PRIZE[wi]
			s.cash = int(s.cash) + prize
			lines.append("CHEFE %s DERROTADO!  +$%d" % [w.boss_name, prize])
			if first and wi + 1 < WORLDS.size():
				s.career.unlocked = maxi(int(s.career.unlocked), wi + 1)
				lines.append("MUNDO %d LIBERADO: %s" % [wi + 2, WORLDS[wi + 1].name])
				for k in SHOP:
					if int(SHOP[k].world) == wi + 1:
						lines.append("NOVO CARRO NA LOJA: %s" % SHOP[k].name)
			elif first:
				lines.append("VOCÊ VENCEU TODOS OS MUNDOS! CAMPEÃO DA FÚRIA!")
		else:
			lines.append("O chefe chegou antes. Melhore o carro e tente de novo!")
	else:
		var pts: int = POINTS[mini(place - 1, POINTS.size() - 1)]
		var before: int = s.career.points[wi]
		s.career.points[wi] = before + pts
		lines.append("+%d PONTOS  ·  MUNDO %d: %d / %d" % [pts, wi + 1, int(s.career.points[wi]), int(w.need)])
		if before < int(w.need) and int(s.career.points[wi]) >= int(w.need):
			lines.append("CHEFE LIBERADO: %s!" % w.boss_name)
	game._write_save()
	return lines
