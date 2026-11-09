class_name Career
extends Node
## Carreira estilo Rock n' Roll Racing: mundos com 3 pistas cada. Cada corrida dá dinheiro e PONTOS pela
## colocação; com os pontos do mundo o CHEFE é liberado; vencer o chefe abre o próximo mundo.
## Dinheiro compra carros únicos (cada um com armas próprias) e upgrades por carro.

const WORLDS := [
	{"name": "PARQUE", "theme": "park", "tracks": [0, 1, 2, 3], "boss_track": 1, "need": 24, "boss": "boss_brutus", "boss_name": "BRUTUS, O ROLO",
		"boss_desc": "Hipercarro elétrico blindado gigante. TREMOR: marca um círculo onde você vai passar e explode o chão. BARRIS: rola barris gigantes para trás.",
		"boss_col": "#4a4652", "mult": 1.0, "lv": 0, "col": "#7dff6a"},
	{"name": "PÂNTANO", "theme": "swamp", "tracks": [4, 5, 6, 7], "boss_track": 6, "need": 28, "boss": "boss_croc", "boss_name": "CROCODILO DO BREJO",
		"boss_desc": "Picape-crocodilo gigante. LAMA: cospe poças que atolam o carro e sujam a tela. BOTE: marca uma faixa da pista e dá um bote lateral nela.",
		"boss_col": "#3f6b2a", "mult": 1.5, "lv": 1, "col": "#a3d977"},
	{"name": "DESERTO", "theme": "desert", "tracks": [8, 9, 10, 11], "boss_track": 9, "need": 30, "boss": "boss_xerife", "boss_name": "XERIFE DE AÇO",
		"boss_desc": "Viatura colossal. ÍMÃ: um raio te puxa para perto e segura sua velocidade. BLOQUEIO: fileira de pregos na pista com uma brecha.",
		"boss_col": "#1c1f2a", "mult": 2.1, "lv": 1, "col": "#ffb21a"},
	{"name": "NEVE", "theme": "snow", "tracks": [12, 13, 14, 15], "boss_track": 13, "need": 32, "boss": "boss_avalanche", "boss_name": "AVALANCHE",
		"boss_desc": "Trophy truck da neve. BOLAS DE NEVE: rola bolas gigantes pela pista contra você (faixas avisadas). GELO: transforma um trecho em gelo liso.",
		"boss_col": "#dfe9f7", "mult": 2.8, "lv": 2, "col": "#bfe6ff"},
	{"name": "CIDADE NEON", "theme": "city", "tracks": [16, 17, 18, 19], "boss_track": 16, "need": 34, "boss": "boss_blackout", "boss_name": "BLACKOUT",
		"boss_desc": "Sedã hacker. PULSO EMP: anel que desliga suas armas e o especial por 3 s. PORTÕES LASER: barreiras que ligam e desligam na pista.",
		"boss_col": "#14141e", "mult": 3.6, "lv": 2, "col": "#c04de0"},
	{"name": "CÉU", "theme": "sky", "tracks": [20, 21, 22, 23], "boss_track": 20, "need": 36, "boss": "boss_imperador", "boss_name": "O IMPERADOR",
		"boss_desc": "Muscle car dourado. METEOROS: círculos vermelhos caem do céu à sua frente. MURO DE FOGO: deixa a pista em chamas atrás de si.",
		"boss_col": "#d4a017", "mult": 4.5, "lv": 3, "col": "#2ee6ff"},
]
const POINTS := [10, 7, 5, 3, 2, 1, 0, 0]
const EXTRA_TRACKS := [24, 25]   # Porto e Loop Mania: corrida rápida e multijogador
const BOSS_PRIZE := [3000, 5000, 7500, 10000, 14000, 20000]
## carros à venda: preço e mundo em que aparecem na loja
const SHOP := {
	"faisca": {"class": "ESPORTIVO", "price": 0, "world": 0, "name": "FAÍSCA", "desc": "Equilibrado e rápido no nitro."},
	"vespa": {"class": "HATCH DE RALLY", "price": 2500, "world": 0, "name": "VESPA", "desc": "Buggy leve: o mais ágil, salta obstáculos."},
	"trovao": {"class": "MUSCLE BLINDADO", "price": 7000, "world": 1, "name": "TROVÃO", "desc": "Muscle car blindado: foguetes e nitro longo."},
	"monstro": {"class": "PICAPE MONSTRO", "price": 15000, "world": 3, "name": "MONSTRO", "desc": "Picape pesada: fogo, barris e investida."},
	# um carro moderno por mundo
	"zefiro": {"class": "GT ELÉTRICO", "price": 4500, "world": 0, "name": "ZÉFIRO", "desc": "GT elétrico: laser, fumaça e esquiva lateral."},
	"jacare": {"class": "SUV ANFÍBIO", "price": 8500, "world": 1, "name": "JACARÉ", "desc": "SUV anfíbio: arpão, lama e nitro longo."},
	"escorpiao": {"class": "TROPHY TRUCK", "price": 12000, "world": 2, "name": "ESCORPIÃO", "desc": "Trophy truck: morteiro, fogo e salto."},
	"nevasca": {"class": "SUV DE NEVE", "price": 18000, "world": 3, "name": "NEVASCA", "desc": "SUV de neve: canhão de gelo e placas de gelo."},
	"nemesis": {"class": "HIPERCARRO", "price": 24000, "world": 4, "name": "NÊMESIS", "desc": "Hipercarro: canhão de trilho, mina EMP e esquiva."},
	"falcao": {"class": "AEROCARRO", "price": 32000, "world": 5, "name": "FALCÃO", "desc": "Aerocarro: plasma, vórtice e voo planado."},
}
const CAR_ORDER := ["faisca", "vespa", "zefiro", "trovao", "jacare", "escorpiao", "monstro", "nevasca", "nemesis", "falcao"]
## modo história: o carro sai da loja só com o ITEM DE CHÃO e a MOBILIDADE dele; a arma de ataque (uma fixa por
## carro) e o ESPECIAL são comprados entre as corridas. Na corrida rápida e no multijogador vem tudo liberado.
const WEAPON_PRICE := {"mg": 1000, "zap": 1500, "laser": 1800, "rocket": 2600, "harpoon": 3000, "mortar": 3800,
	"flame": 4400, "freeze": 5000, "railgun": 6200, "plasma": 7500}
const SPECIAL_PRICE := {"shield": 2500, "shock": 3000, "repair": 1800}
const DEF_SPECIAL := {"faisca": "shield", "vespa": "shock", "trovao": "shield", "monstro": "shock", "zefiro": "repair",
	"jacare": "shield", "escorpiao": "shock", "nevasca": "repair", "nemesis": "shield", "falcao": "shock"}
## upgrades da arma de ataque: caros
const WPN_UP_PRICE := [1200, 2600, 4500]
const UP_KEYS := ["engine", "armor", "ammo", "rear", "nitro", "tires", "dmg", "rate"]
const UP_MULT := {"faisca": 1.0, "vespa": 1.1, "zefiro": 1.2, "trovao": 1.4, "jacare": 1.5, "escorpiao": 1.75, "monstro": 2.0,
	"nevasca": 2.15, "nemesis": 2.5, "falcao": 2.9}
const WEAPON_DESC := {
	"mg": "Rajada contínua de balas.", "rocket": "Foguete teleguiado no alvo da frente.",
	"zap": "Raio instantâneo que salta para um 2º carro.", "flame": "Jato curto que incendeia (dano contínuo).",
	"oil": "Mancha que faz rodopiar.", "mine": "Explode quando alguém passa.",
	"spikes": "Furam os pneus: o carro fica lento.", "barrel": "Barril rola para trás e explode.",
	"short": "Arrancadas curtas e fortes (4 por volta).", "long": "Arrancadas longas (3 por volta).",
	"jump": "Pula minas, óleo e carros (3 por volta).", "ram": "Arrancada que atropela e arremessa quem estiver na frente.",
	"laser": "Feixe contínuo que queima.", "harpoon": "Fisga o alvo, puxa para trás e segura.",
	"mortar": "Granada em arco onde o alvo vai estar.", "freeze": "Bola de gelo: o alvo escorrega e perde força.",
	"railgun": "Disparo que atravessa todos na linha.", "plasma": "Rajada de bolas teleguiadas.",
	"smoke": "Nuvem: ninguém mira em quem está dentro.", "mud": "Poça que atola quem passa.",
	"fire": "Chão em chamas atrás de você.", "ice": "Placa lisa: quem passa derrapa.",
	"emp": "Mina que desliga armas e especial.", "vortex": "Redemoinho que puxa e segura.",
	"dash": "Salto lateral rápido para desviar.", "glide": "Impulso e voo planado por 1,8 s.",
	"shield": "3 s invulnerável + aríete.", "shock": "Arremessa e machuca quem está perto.",
	"repair": "Devolve 40% da blindagem e apaga o fogo.",
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
		for u in UP_KEYS:
			s.garage.up[k][u] = int(s.garage.up[k].get(u, 0))
	if not s.garage.has("kit"):
		# saves de antes da loja de armas: quem já tinha progresso mantém a arma de ataque e o especial antigo
		var veteran := int(s.career.unlocked) > 0 or int(s.career.points[0]) > 0
		s.garage.kit = {}
		for k in CAR_ORDER:
			var had: bool = veteran and k in s.garage.owned
			s.garage.kit[k] = {"front": had, "spec": [], "eq": ""}
			if had and k in ["trovao", "monstro"]:
				var old := "shield" if k == "trovao" else "shock"
				s.garage.kit[k].spec = [old]
				s.garage.kit[k].eq = old
	for k in CAR_ORDER:
		if not s.garage.kit.has(k):
			s.garage.kit[k] = {"front": false, "spec": [], "eq": ""}
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
		game.sfx.play("buy", -4.0)
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
	var table: Array = WPN_UP_PRICE if k in ["dmg", "rate"] else game.UP_PRICE
	return int(table[mini(lvl, 2)] * float(UP_MULT.get(String(game.save.car), 1.0)))


func kit(k: String) -> Dictionary:
	return game.save.garage.kit.get(k, {"front": false, "spec": [], "eq": ""})


## a arma de ataque está liberada? (fora do modo história, sempre)
func has_front(k: String) -> bool:
	return not active() or bool(kit(k).front)


func owns_special(k: String, sp: String) -> bool:
	return not active() or sp in kit(k).spec


## especial que o carro leva para a corrida
func cur_special(k: String) -> String:
	if not active():
		return quick_special(k)
	var eq := String(kit(k).eq)
	return eq if eq in kit(k).spec else ""


## corrida rápida / multijogador: o especial escolhido na garagem (ou o padrão do carro)
func quick_special(k: String) -> String:
	var eq := String(kit(k).eq)
	return eq if Car.SPECIAL.has(eq) else String(DEF_SPECIAL.get(k, "shield"))


## kit completo para a corrida: [arma de ataque, item de chão, mobilidade, especial]
func loadout(k: String) -> Array:
	var lo: Array = Car.LOADOUT[k]
	return [lo[0] if has_front(k) else "none", lo[1], lo[2], cur_special(k)]


func weapon_price(k: String) -> int:
	return int(WEAPON_PRICE.get(String(Car.LOADOUT[k][0]), 1500))


func special_price(sp: String) -> int:
	return int(float(SPECIAL_PRICE.get(sp, 2500)) * float(UP_MULT.get(String(game.save.car), 1.0)))


func buy_front() -> String:
	var s: Dictionary = game.save
	var k := String(s.car)
	if has_front(k):
		return ""
	var price := weapon_price(k)
	if int(s.cash) < price:
		return "Faltam $%d" % (price - int(s.cash))
	s.cash = int(s.cash) - price
	s.garage.kit[k].front = true
	game.sfx.play("buy", -4.0)
	game._write_save()
	return ""


## escolhe o especial (compra no modo história se ainda não tiver); tocar no equipado desequipa
func pick_special(sp: String) -> String:
	var s: Dictionary = game.save
	var k := String(s.car)
	var kt: Dictionary = s.garage.kit[k]
	if active() and not sp in kt.spec:
		var price := special_price(sp)
		if int(s.cash) < price:
			return "Faltam $%d" % (price - int(s.cash))
		s.cash = int(s.cash) - price
		kt.spec.append(sp)
		game.sfx.play("buy", -4.0)
	elif String(kt.eq) == sp and active():
		kt.eq = ""
		game._write_save()
		return ""
	kt.eq = sp
	game._write_save()
	return ""


func world_open(i: int) -> bool:
	return i <= int(game.save.career.unlocked)


## as corridas de cada mundo vêm em ORDEM: 1, 2, 3, 4 e o chefe. Para liberar a próxima, chegue no pódio.
const PODIUM := 3


## quantas corridas do mundo já foram vencidas em ordem (pódio), 0..4
func stage(i: int) -> int:
	var n := 0
	for t in WORLDS[i].tracks:
		var b: Dictionary = game.save.career.best.get(str(t), {})
		if not b.has("place") or int(b.place) > PODIUM:
			break
		n += 1
	return n


func track_open(i: int, t: int) -> bool:
	return (WORLDS[i].tracks as Array).find(t) <= stage(i)


func boss_open(i: int) -> bool:
	return stage(i) >= (WORLDS[i].tracks as Array).size() or bool(game.save.career.beaten[i])


## próxima corrida da carreira na ordem (depois de uma vitória): {} quando já venceu tudo
func next_event() -> Dictionary:
	var s: Dictionary = game.save
	# segue do mundo atual para frente (nunca volta para um mundo anterior)
	var start := int(event.world) if not event.is_empty() else 0
	for i in range(start, WORLDS.size()):
		if not world_open(i):
			break
		var w: Dictionary = WORLDS[i]
		var st := stage(i)
		if st < (w.tracks as Array).size():
			return {"world": i, "track": int(w.tracks[st]), "boss": false}
		if not bool(s.career.beaten[i]):
			return {"world": i, "track": int(w.boss_track), "boss": true}
	return {}


## a corrida que acabou liberou a seguinte? (pódio na corrida da vez, ou chefe vencido)
func advanced() -> bool:
	return not event.is_empty() and next_event().hash() != event.hash()


## vai direto para a próxima corrida (garagem antes da largada); sem próxima, volta ao mapa
func go_next() -> void:
	var nx := next_event()
	if nx.is_empty():
		open()
		return
	choose(int(nx.world), int(nx.track), bool(nx.boss))


# ------------------------------------------------------------------ telas
func _build_map() -> void:
	scr_map = hud._screen(0.86)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 56)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 26)
	scr_map.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	var t := UI.title(top, "CARREIRA", 48)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(Icon.make("coin", 30, UI.OK))
	map_cash = UI.title(top, "", 30, UI.OK)
	map_box = GridContainer.new()
	map_box.columns = 3
	map_box.add_theme_constant_override("h_separation", 16)
	map_box.add_theme_constant_override("v_separation", 16)
	map_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(map_box)
	var back := UI.icon_button("VOLTAR", "back", false, 18, 220, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): hud.show_screen("menu"))
	v.add_child(back)
	hud.extra_screens["career"] = scr_map
	scr_map.visible = false


var map_cash: Label


## barra de pontos inclinada (mundo) com o ícone do chefe na ponta
func _points_bar(parent: Control, pos: Vector2, w: float, pts: int, need: int, col: Color, beaten: bool) -> Control:
	var bar := Control.new()
	bar.position = pos
	bar.size = Vector2(w, 22)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var u := clampf(float(pts) / maxf(1.0, need), 0.0, 1.0)
		var sk := 8.0
		var W := bar.size.x - 30.0
		bar.draw_colored_polygon(PackedVector2Array([Vector2(sk, 4), Vector2(W, 4), Vector2(W - sk, 18), Vector2(0, 18)]), Color(1, 1, 1, 0.12))
		if u > 0.0:
			bar.draw_colored_polygon(PackedVector2Array([Vector2(sk, 4), Vector2(sk + (W - sk) * u, 4), Vector2((W - sk) * u, 18), Vector2(0, 18)]), col)
		Icon.paint(bar, "trophy" if beaten else "skull", Rect2(Vector2(W + 4, -2), Vector2(26, 26)), UI.HOT if beaten else (UI.BAD if u >= 1.0 else Color(1, 1, 1, 0.35))))
	parent.add_child(bar)
	return bar


func open() -> void:
	game.set_solo()
	event = {}
	for ch in map_box.get_children():
		ch.queue_free()
	var s: Dictionary = game.save
	map_cash.text = hud.garage_ui._money(int(s.cash))
	for i in WORLDS.size():
		var w: Dictionary = WORLDS[i]
		var open_ := world_open(i)
		var beaten := bool(s.career.beaten[i])
		var c := Color(w.col)
		var pc := Button.new()
		pc.custom_minimum_size = Vector2(370, 214)
		var base := UI.box(Color(0.1, 0.09, 0.19, 0.95) if open_ else Color(0.06, 0.055, 0.09, 0.92), c if open_ else UI.LINE, 2, 0.06, 6, Color(0, 0, 0, 0.5), 10)
		base.border_width_top = 8
		var hov := UI.box(Color(0.16, 0.14, 0.28, 0.98), Color.WHITE, 3, 0.06, 6, Color.WHITE, 10)
		hov.border_width_top = 8
		for st in ["normal", "disabled"]:
			pc.add_theme_stylebox_override(st, base)
		for st in ["hover", "focus", "pressed"]:
			pc.add_theme_stylebox_override(st, hov)
		pc.disabled = not open_
		var wi := i
		pc.pressed.connect(func(): open_world(wi))
		map_box.add_child(pc)
		var num := UI.title(pc, str(i + 1), 64, c if open_ else Color(1, 1, 1, 0.2))
		num.position = Vector2(18, 10)
		var nm := UI.title(pc, String(w.name), 20, UI.TEXT if open_ else Color(1, 1, 1, 0.3))
		nm.position = Vector2(20, 96)
		var mul := HBoxContainer.new()
		mul.position = Vector2(22, 130)
		mul.add_theme_constant_override("separation", 4)
		mul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(mul)
		mul.add_child(Icon.make("coin", 18, UI.OK if open_ else Color(1, 1, 1, 0.25)))
		var ml := UI.text(mul, "x%.1f" % float(w.mult), 16, UI.OK if open_ else Color(1, 1, 1, 0.25))
		ml.add_theme_font_override("font", UI.display_it)
		# miniatura do chefe (silhueta enquanto o mundo está fechado)
		var th := TextureRect.new()
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.position = Vector2(150, 14)
		th.size = Vector2(206, 128)
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		th.modulate = Color(1, 1, 1) if open_ else Color(0.02, 0.02, 0.04, 0.85)
		pc.add_child(th)
		hud.show3d.thumb("boss:%d" % i, th)
		if open_:
			_points_bar(pc, Vector2(20, 166), 330, stage(i), (w.tracks as Array).size(), c, beaten)
		else:
			var lk := Icon.make("lock", 34, Color(1, 1, 1, 0.45))
			lk.position = Vector2(236, 160)
			pc.add_child(lk)
	hud.show_screen("career")


func _build_world() -> void:
	scr_world = hud._screen(0.86)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 56)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 26)
	scr_world.add_child(m)
	world_box = VBoxContainer.new()
	world_box.add_theme_constant_override("separation", 14)
	m.add_child(world_box)
	hud.extra_screens["world"] = scr_world
	scr_world.visible = false


## nomes curtos dos ataques do chefe (as palavras em maiúsculas antes de ":" na descrição)
func _boss_attacks(w: Dictionary) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("([A-ZÁÉÍÓÚÃÕÇÊ][A-ZÁÉÍÓÚÃÕÇÊ ]{2,}):")
	for mt in re.search_all(String(w.boss_desc)):
		out.append(mt.get_string(1).strip_edges())
	return out


func open_world(i: int) -> void:
	cur_world = i
	game.set_solo()
	for ch in world_box.get_children():
		ch.queue_free()
	var w: Dictionary = WORLDS[i]
	var s: Dictionary = game.save
	var c := Color(w.col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	world_box.add_child(top)
	var tt := UI.title(top, "%d · %s" % [i + 1, w.name], 44)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(Icon.make("coin", 30, UI.OK))
	UI.title(top, hud.garage_ui._money(int(s.cash)), 30, UI.OK)
	var st := stage(i)
	var nt: int = (w.tracks as Array).size()
	var prow := Control.new()
	prow.custom_minimum_size = Vector2(0, 26)
	world_box.add_child(prow)
	_points_bar(prow, Vector2(0, 0), 560, st, nt, c, bool(s.career.beaten[i]))
	var pl := UI.title(prow, ("CORRIDA %d DE %d" % [st + 1, nt]) if st < nt else ("CAMPEÃO" if bool(s.career.beaten[i]) else "CHEFE"), 18, UI.TEXT)
	pl.position = Vector2(580, -2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	world_box.add_child(row)
	for t in w.tracks:
		row.add_child(_track_card(int(t), i, false))
	# chefe: miniatura, nome, ataques (só os nomes), prêmio e o botão
	var bp := PanelContainer.new()
	var bs := UI.box(Color(0.08, 0.06, 0.12, 0.92), UI.BAD, 2, 0.0, 0, Color(0, 0, 0, 0), 10)
	bs.border_width_left = 8
	bs.content_margin_left = 18
	bs.content_margin_top = 10
	bs.content_margin_bottom = 10
	bp.add_theme_stylebox_override("panel", bs)
	world_box.add_child(bp)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 18)
	bp.add_child(bh)
	var th := TextureRect.new()
	th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	th.custom_minimum_size = Vector2(250, 150)
	bh.add_child(th)
	hud.show3d.thumb("boss:%d" % i, th)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bv)
	var bt := HBoxContainer.new()
	bt.add_theme_constant_override("separation", 10)
	bv.add_child(bt)
	bt.add_child(Icon.make("skull", 30, UI.BAD))
	UI.title(bt, String(w.boss_name), 26, UI.BAD)
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 8)
	bv.add_child(ar)
	for a in _boss_attacks(w):
		var chip := PanelContainer.new()
		var cs := UI.box(Color(1, 0.18, 0.33, 0.18), UI.BAD, 1, 0.15, 0, Color(0, 0, 0, 0), 6)
		cs.content_margin_left = 12
		cs.content_margin_right = 12
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", cs)
		ar.add_child(chip)
		var al := UI.text(chip, a, 14, UI.TEXT)
		al.add_theme_font_override("font", UI.display_it)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 6)
	bv.add_child(pr)
	pr.add_child(Icon.make("coin", 22, UI.OK))
	var prl := UI.title(pr, hud.garage_ui._money(int(BOSS_PRIZE[i])), 20, UI.OK)
	prl.label_settings.outline_size = 4
	var bb := UI.icon_button("ENFRENTAR" if boss_open(i) else "VENÇA AS 4", "skull" if boss_open(i) else "lock", boss_open(i), 22, 300, 60)
	bb.disabled = not boss_open(i)
	bb.pressed.connect(func(): choose(i, int(w.boss_track), true))
	bh.add_child(bb)
	bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := UI.icon_button("VOLTAR", "back", false, 18, 220, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(open)
	world_box.add_child(back)
	hud.show_screen("world")


## cartão de pista: traçado, elementos (ícones), nome e melhor colocação
func _track_card(t: int, wi: int, boss: bool) -> Button:
	var d: Dictionary = TrackData.TRACKS[t]
	var th: Dictionary = TrackData.THEMES[d.theme]
	var best: Dictionary = game.save.career.best.get(str(t), {})
	var b := Button.new()
	b.custom_minimum_size = Vector2(278, 158)
	var c1 := Color(th.sky_hor).darkened(0.55).lerp(UI.INK2, 0.4)
	var sb := UI.box(c1, Color(th.curb[0]), 2, 0.06, 5, Color(0, 0, 0, 0.5), 10)
	sb.border_width_left = 8
	var sh := UI.box(c1.lightened(0.15), Color.WHITE, 3, 0.06, 5, Color.WHITE, 10)
	sh.border_width_left = 10
	b.add_theme_stylebox_override("normal", sb)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, sh)
	b.tooltip_text = String(d.desc)
	var open_ := boss or track_open(wi, t)
	b.disabled = not open_
	b.add_theme_stylebox_override("disabled", UI.box(c1.darkened(0.5), Color(1, 1, 1, 0.12), 2, 0.06, 5, Color(0, 0, 0, 0.5), 10))
	b.pressed.connect(func(): choose(wi, t, boss))
	var num := UI.title(b, str((WORLDS[wi].tracks as Array).find(t) + 1), 22, Color(th.curb[0]) if open_ else Color(1, 1, 1, 0.25))
	num.position = Vector2(196, 120)
	if not open_:
		var lk := Icon.make("lock", 46, Color(1, 1, 1, 0.5))
		lk.position = Vector2(64, 38)
		b.add_child(lk)
		b.modulate = Color(0.6, 0.6, 0.7)
	elif not boss and (WORLDS[wi].tracks as Array).find(t) == stage(wi):
		var nx := UI.text(b, "PRÓXIMA", 13, UI.INK)
		nx.add_theme_font_override("font", UI.display_it)
		var nb := StyleBoxFlat.new()
		nb.bg_color = UI.HOT
		nb.set_corner_radius_all(6)
		nb.content_margin_left = 8
		nb.content_margin_right = 8
		nx.add_theme_stylebox_override("normal", nb)
		nx.position = Vector2(150, 8)
	var art := Control.new()
	art.position = Vector2(20, 10)
	art.size = Vector2(170, 108)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): UI.draw_track(art, t, Rect2(Vector2.ZERO, art.size), Color(th.curb[1]).lerp(Color.WHITE, 0.5), 4.0))
	b.add_child(art)
	var fy := 12.0
	for f in UI.track_feats(t):
		var ic := Icon.make(f, 24, UI.INFO)
		ic.position = Vector2(236, fy)
		b.add_child(ic)
		fy += 28.0
	var nm := UI.text(b, String(d.name).to_upper(), 14, UI.TEXT)
	nm.add_theme_font_override("font", UI.display_it)
	nm.position = Vector2(18, 126)
	nm.size = Vector2(190, 22)
	nm.clip_text = true
	if best.has("place"):
		var pl := int(best.place)
		var md := Label.new()
		md.text = "%dº" % pl
		md.add_theme_font_override("font", UI.display_it)
		md.add_theme_font_size_override("font_size", 18)
		md.add_theme_color_override("font_color", UI.INK)
		md.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		md.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var st2 := StyleBoxFlat.new()
		st2.bg_color = [Color("#ffcf33"), Color("#d8dbe2"), Color("#d08a4a")][mini(pl, 3) - 1] if pl <= 3 else Color(1, 1, 1, 0.3)
		st2.set_corner_radius_all(16)
		md.add_theme_stylebox_override("normal", st2)
		md.position = Vector2(222, 118)
		md.size = Vector2(42, 32)
		md.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(md)
	return b


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
			lines.append("CHEFE DERROTADO  +$%d" % prize)
			if first and wi + 1 < WORLDS.size():
				s.career.unlocked = maxi(int(s.career.unlocked), wi + 1)
				lines.append("MUNDO %d LIBERADO" % (wi + 2))
				for k in SHOP:
					if int(SHOP[k].world) == wi + 1:
						lines.append("NOVO CARRO: %s" % SHOP[k].name)
			elif first:
				lines.append("CAMPEÃO DA FÚRIA!")
		else:
			lines.append("O CHEFE CHEGOU ANTES")
	else:
		var pts: int = POINTS[mini(place - 1, POINTS.size() - 1)]
		s.career.points[wi] = int(s.career.points[wi]) + pts
		var nt: int = (w.tracks as Array).size()
		var j: int = (w.tracks as Array).find(int(event.track))
		var st := stage(wi)
		if place > PODIUM:
			if j >= st:
				lines.append("CHEGUE NO PÓDIO PARA AVANÇAR")
		elif j == st - 1 and st < nt:
			lines.append("CORRIDA %d LIBERADA" % (st + 1))
		elif j == st - 1 and st == nt and not bool(s.career.beaten[wi]):
			lines.append("CHEFE LIBERADO!")
		lines.append("MUNDO %d · %d / %d" % [wi + 1, st, nt])
	game._write_save()
	return lines
