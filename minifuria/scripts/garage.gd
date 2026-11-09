class_name Garage
extends Control
## Garagem estilo vitrine de miniaturas: o carro gira na plataforma (Showroom), a vitrine de baixo mostra os 10
## carros em miniatura (renderizados do modelo 3D), os cartões de peças mostram a peça do PRÓXIMO nível, com
## prévia no carro e nos medidores (base em branco, upgrades em âmbar, a melhoria em verde piscando).
## Pouco texto: ícones, miniaturas, níveis em "pips" e preços.

const UP_ORDER := ["engine", "armor", "tires", "nitro", "rear", "ammo", "dmg", "rate"]
const WPN_UPS := ["ammo", "dmg", "rate"]
const UP_NAME := {"engine": "MOTOR", "armor": "BLINDAGEM", "tires": "PNEUS", "ammo": "MUNIÇÃO", "dmg": "DANO", "rate": "CADÊNCIA"}
const UP_FOCUS := {"engine": "engine", "armor": "armor", "tires": "tires", "nitro": "", "rear": "rear", "ammo": "wpn", "dmg": "wpn", "rate": "wpn"}
const STAT_ICON := {"spd": "spd", "acc": "acc", "han": "han", "arm": "arm", "atk": "atk"}
const STAT_NAME := {"spd": "VELOCIDADE", "acc": "ACELERAÇÃO", "han": "CONTROLE", "arm": "BLINDAGEM", "atk": "ATAQUE"}
const UP_STATS := {"engine": ["spd", "acc"], "armor": ["arm"], "tires": ["han"], "ammo": ["atk"], "dmg": ["atk"], "rate": ["atk"]}

var game: Node
var hud: Hud
var room: Showroom
var view_kind := ""
var sel_up := ""
var tab := "parts"
var _t := 0.0

var title_l: Label
var cash_l: Label
var name_l: Label
var class_l: Label
var ovr: Control
var ovr_v := 0.0
var meters := {}
var load_icons: Array = []
var tab_btns := {}
var pages := {}
var part_cards := {}
var car_cards := {}
var swatches: Array = []
var action_b: Button
var detail: PanelContainer
var detail_name: Label
var detail_fx: Label
var detail_icon: Icon
var buy_b: Button
var wpn_card := {}
var spec_cards := {}
var info_chips := {}


## medidor em segmentos: base do carro (branco), upgrades comprados (âmbar), prévia da melhoria (verde piscando)
## e uma marca do carro atual quando a vitrine mostra outro carro
class StatBar extends Control:
	var base := 0.0
	var cur := 0.0
	var prev := 0.0
	var cmp := -1.0
	var t := 0.0
	const SEG := 20

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sk := h * 0.45
		var gap := 2.0
		var sw := (w - sk - gap * (SEG - 1)) / SEG
		for i in SEG:
			var v0 := float(i) / SEG * 10.0
			var x := i * (sw + gap)
			var col := Color(1, 1, 1, 0.09)
			if v0 < base:
				col = Color("#f4f2ff")
			elif v0 < cur:
				col = UI.HOT
			elif v0 < prev:
				col = UI.OK.lerp(Color.WHITE, 0.25 + 0.25 * sin(t * 8.0))
			var pts := PackedVector2Array([Vector2(x + sk, 0), Vector2(x + sk + sw, 0), Vector2(x + sw, h), Vector2(x, h)])
			draw_colored_polygon(pts, col)
		if cmp >= 0.0:
			var cx := cmp / 10.0 * (w - sk) + sk * 0.5
			draw_line(Vector2(cx, -4), Vector2(cx - sk * 0.4, h + 4), UI.INFO, 3.0, true)


func setup(g: Node, h: Hud, sh: Showroom) -> void:
	game = g
	hud = h
	room = sh
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# leve escurecimento nas bordas (painéis legíveis sem cobrir o carro)
	var vg := ColorRect.new()
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/showroom_vignette.gdshader")
	vg.material = vm
	add_child(vg)
	_build_top()
	_build_left()
	_build_right()
	_build_carousel()
	_build_action()


func _process(dt: float) -> void:
	_t += dt
	for k in meters:
		var sb: StatBar = meters[k].bar
		sb.t = _t
		if sb.prev > sb.cur:
			sb.queue_redraw()


# ------------------------------------------------------------------ construção
func _panel_style(alpha := 0.78) -> StyleBoxFlat:
	var s := UI.box(Color(0.06, 0.055, 0.11, alpha), Color(1, 1, 1, 0.08), 1, 0.0, 0, Color(0, 0, 0, 0), 10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _build_top() -> void:
	var back := UI.icon_button("VOLTAR", "back", false, 17, 168, 48)
	back.position = Vector2(28, 18)
	back.pressed.connect(_back)
	add_child(back)
	title_l = UI.title(self, "", 22, UI.TEXT)
	title_l.position = Vector2(196, 28)
	var cash := HBoxContainer.new()
	cash.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cash.offset_left = -300
	cash.offset_right = -28
	cash.offset_top = 20
	cash.offset_bottom = 64
	cash.alignment = BoxContainer.ALIGNMENT_END
	cash.add_theme_constant_override("separation", 10)
	cash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cash)
	cash.add_child(Icon.make("coin", 30, UI.OK))
	cash_l = UI.title(cash, "", 30, UI.OK)


func _build_left() -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_style(0.0))
	pc.position = Vector2(14, 74)
	pc.custom_minimum_size = Vector2(384, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	ovr = Control.new()
	ovr.custom_minimum_size = Vector2(70, 70)
	ovr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ovr.draw.connect(_draw_ovr)
	row.add_child(ovr)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -4)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nv)
	name_l = UI.title(nv, "", 40, UI.TEXT)
	class_l = UI.text(nv, "", 15, UI.INFO, true)
	class_l.add_theme_font_override("font", UI.body_bold)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	for k in Car.STAT_KEYS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r)
		r.add_child(Icon.make(STAT_ICON[k], 28, UI.TEXT))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(col)
		var nm := UI.text(col, STAT_NAME[k], 11, UI.MUTED)
		nm.add_theme_font_override("font", UI.body_bold)
		var bar := StatBar.new()
		bar.custom_minimum_size = Vector2(276, 16)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bar)
		var dl := UI.text(r, "", 15, UI.OK)
		dl.add_theme_font_override("font", UI.body_bold)
		dl.custom_minimum_size = Vector2(36, 0)
		meters[k] = {"bar": bar, "delta": dl}
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp2)
	# equipamento do carro em ícones: ataque, item de chão, mobilidade, especial
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 8)
	lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lr)
	for i in 4:
		var chip := PanelContainer.new()
		var cs := UI.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 1, 0.12, 0, Color(0, 0, 0, 0), 6)
		cs.content_margin_left = 6
		cs.content_margin_right = 6
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", cs)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lr.add_child(chip)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 0)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(cv)
		var ic := Icon.make("atk", 30, UI.TEXT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var l := UI.text(cv, "", 11, UI.TEXT)
		l.add_theme_font_override("font", UI.display_it)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(72, 0)
		load_icons.append({"icon": ic, "label": l, "panel": chip})
	# pintura sempre à mão: 12 cores em duas fileiras
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 10)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pr)
	var pic := Icon.make("paint", 26, UI.MUTED)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(pic)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	pr.add_child(g)
	for hexc in game.PAINT_COLORS:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(46, 30)
		sw.set_meta("col", hexc)
		sw.pressed.connect(func():
			game.save.color = hexc
			game._write_save()
			game.sfx.play("coin", -10.0, 1.4)
			room.flash()
			refresh())
		g.add_child(sw)
		var ck := Icon.make("check", 18, Color.WHITE)
		ck.position = Vector2(14, 6)
		sw.add_child(ck)
		swatches.append({"btn": sw, "check": ck})


func _build_right() -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_style(0.72))
	pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pc.offset_left = -414
	pc.offset_right = -18
	pc.offset_top = 74
	pc.offset_bottom = 578
	add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for it in [["parts", "wrench", "PEÇAS"], ["arsenal", "atk", "ARSENAL"]]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 42)
		b.text = it[2]
		b.add_theme_font_override("font", UI.display_it)
		b.add_theme_font_size_override("font_size", 16)
		var ic := Icon.make(it[1], 22, UI.TEXT)
		ic.position = Vector2(14, 10)
		b.add_child(ic)
		b.pressed.connect(func(): _set_tab(it[0]))
		b.focus_entered.connect(func(): _set_tab(it[0]))
		tabs.add_child(b)
		tab_btns[it[0]] = {"btn": b, "icon": ic}
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(368, 430)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(stack)
	pages.parts = _build_parts(stack)
	pages.arsenal = _build_arsenal(stack)


func _card_style(on: bool, hot := false) -> StyleBoxFlat:
	var c := Color(1, 1, 1, 0.07) if not on else Color(1, 0.7, 0.1, 0.22)
	var s := UI.box(c, (UI.HOT if hot else Color.WHITE) if on else Color(1, 1, 1, 0.1), 2 if on else 1, 0.08, 0, Color(0, 0, 0, 0), 8)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _build_parts(stack: Control) -> Control:
	var grid := GridContainer.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(grid)
	for k in UP_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 100)
		b.focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _card_style(st != "normal" and st != "disabled"))
		b.pressed.connect(_part_pressed.bind(k))
		b.focus_entered.connect(_part_sel.bind(k))
		grid.add_child(b)
		var th := TextureRect.new()
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.position = Vector2(2, 8)
		th.size = Vector2(86, 62)
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(th)
		# sem peça no carro (mobilidade): ícone grande no lugar da miniatura
		var big := Icon.make(k, 46, UI.INFO)
		big.position = Vector2(22, 16)
		big.visible = false
		b.add_child(big)
		var ic := Icon.make(k, 18, UI.HOT)
		ic.position = Vector2(8, 74)
		b.add_child(ic)
		var nm := UI.text(b, "", 12, UI.TEXT)
		nm.add_theme_font_override("font", UI.display_it)
		nm.position = Vector2(88, 10)
		nm.size = Vector2(90, 18)
		nm.clip_text = true
		var pips := Control.new()
		pips.position = Vector2(90, 38)
		pips.size = Vector2(80, 12)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pips)
		var pr := UI.text(b, "", 16, UI.OK)
		pr.add_theme_font_override("font", UI.display_it)
		pr.position = Vector2(88, 64)
		pr.size = Vector2(84, 24)
		var card := {"btn": b, "thumb": th, "big": big, "name": nm, "pips": pips, "price": pr, "icon": ic, "lvl": 0, "next": false}
		pips.draw.connect(_draw_pips.bind(card))
		part_cards[k] = card
	# detalhe do upgrade escolhido: fica no centro, embaixo do carro (nome, efeito e o botão de compra)
	detail = PanelContainer.new()
	var ds := UI.box(Color(0.06, 0.055, 0.11, 0.86), Color(1, 1, 1, 0.12), 1, 0.08, 0, Color(0, 0, 0, 0), 10)
	ds.content_margin_left = 14
	ds.content_margin_right = 10
	ds.content_margin_top = 8
	ds.content_margin_bottom = 8
	detail.add_theme_stylebox_override("panel", ds)
	detail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	detail.offset_left = -232
	detail.offset_right = 232
	detail.offset_top = -224
	detail.offset_bottom = -152
	detail.visible = false
	add_child(detail)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 12)
	detail.add_child(dh)
	detail_icon = Icon.make("engine", 36, UI.HOT)
	detail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(detail_icon)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", -2)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dh.add_child(dv)
	detail_name = UI.text(dv, "", 16, UI.TEXT)
	detail_name.add_theme_font_override("font", UI.display_it)
	detail_fx = UI.text(dv, "", 14, UI.OK)
	detail_fx.add_theme_font_override("font", UI.body_bold)
	buy_b = Button.new()
	buy_b.custom_minimum_size = Vector2(138, 50)
	_style_buy(buy_b)
	buy_b.pressed.connect(func(): _ask_up(sel_up))
	dh.add_child(buy_b)
	return grid


func _style_buy(b: Button) -> void:
	b.add_theme_font_override("font", UI.display_it)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", UI.box(Color("#1f8a3a"), Color(0, 0, 0, 0), 0, UI.SKEW, 4, Color("#0d4a1c"), 4))
	b.add_theme_stylebox_override("hover", UI.box(Color("#2fb04f"), Color.WHITE, 2, UI.SKEW, 4, Color.WHITE, 4))
	b.add_theme_stylebox_override("focus", UI.box(Color("#2fb04f"), Color.WHITE, 2, UI.SKEW, 4, Color.WHITE, 4))
	b.add_theme_stylebox_override("pressed", UI.box(Color("#2fb04f"), Color.WHITE, 2, UI.SKEW, 1, Color.WHITE, 4))
	b.add_theme_stylebox_override("disabled", UI.box(Color(1, 1, 1, 0.06), UI.LINE, 1, UI.SKEW, 2, Color.BLACK, 4))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


func _draw_pips(card: Dictionary) -> void:
	var c: Control = card.pips
	var lvl: int = card.lvl
	for i in 3:
		var x := i * 28.0
		var pts := PackedVector2Array([Vector2(x + 5, 0), Vector2(x + 25, 0), Vector2(x + 20, 10), Vector2(x, 10)])
		var col := Color(1, 1, 1, 0.12)
		if i < lvl:
			col = UI.HOT
		elif i == lvl and bool(card.next):
			col = UI.OK.lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 8.0))
		c.draw_colored_polygon(pts, col)


func _build_arsenal(stack: Control) -> Control:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	stack.add_child(v)
	# arma de ataque (miniatura da torre)
	var wb := Button.new()
	wb.custom_minimum_size = Vector2(368, 132)
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		wb.add_theme_stylebox_override(st, _card_style(st != "normal" and st != "disabled"))
	wb.pressed.connect(_ask_weapon)
	wb.focus_entered.connect(func(): room.set_focus("wpn"))
	v.add_child(wb)
	var th := TextureRect.new()
	th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	th.position = Vector2(4, 6)
	th.size = Vector2(170, 120)
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wb.add_child(th)
	var wn := UI.title(wb, "", 20, UI.TEXT)
	wn.position = Vector2(178, 10)
	var pw := StatBar.new()
	pw.position = Vector2(180, 52)
	pw.size = Vector2(170, 12)
	pw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wb.add_child(pw)
	var ws := UI.text(wb, "", 16, UI.OK)
	ws.add_theme_font_override("font", UI.display_it)
	ws.position = Vector2(180, 84)
	wpn_card = {"btn": wb, "thumb": th, "name": wn, "power": pw, "state": ws}
	# item de chão e mobilidade: só ícone, rótulo curto e cargas por volta
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for k in ["rear", "nitro"]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _card_style(false))
		p.custom_minimum_size = Vector2(180, 64)
		row.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var ic := Icon.make("rear", 34, UI.HOT)
		h.add_child(ic)
		var vv := VBoxContainer.new()
		vv.add_theme_constant_override("separation", -2)
		h.add_child(vv)
		var l1 := UI.text(vv, "", 14, UI.TEXT)
		l1.add_theme_font_override("font", UI.display_it)
		var l2 := UI.text(vv, "", 13, UI.MUTED)
		l2.add_theme_font_override("font", UI.body_bold)
		info_chips[k] = {"icon": ic, "name": l1, "cap": l2}
	var sl := UI.text(v, "ESPECIAL", 12, UI.INFO)
	sl.add_theme_font_override("font", UI.display_it)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	v.add_child(srow)
	for spk in Car.SPECIAL_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(117, 112)
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _card_style(st != "normal" and st != "disabled"))
		b.pressed.connect(_special_pressed.bind(spk))
		srow.add_child(b)
		var ic2 := Icon.make(spk, 40, UI.INFO)
		ic2.position = Vector2(38, 10)
		b.add_child(ic2)
		var n2 := UI.text(b, String(Car.SPECIAL[spk].label), 13, UI.TEXT)
		n2.add_theme_font_override("font", UI.display_it)
		n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n2.position = Vector2(0, 56)
		n2.size = Vector2(117, 18)
		var s2 := UI.text(b, "", 14, UI.OK)
		s2.add_theme_font_override("font", UI.display_it)
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.position = Vector2(0, 80)
		s2.size = Vector2(117, 20)
		spec_cards[spk] = {"btn": b, "icon": ic2, "state": s2}
	v.visible = false
	return v


func _build_carousel() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sc.offset_left = 18
	sc.offset_right = -330
	sc.offset_top = -132
	sc.offset_bottom = -14
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(sc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	sc.add_child(h)
	for k in Career.CAR_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(87, 112)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_car_pressed.bind(k))
		b.focus_entered.connect(_car_view.bind(k))
		h.add_child(b)
		var th := TextureRect.new()
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.position = Vector2(0, 6)
		th.size = Vector2(87, 58)
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(th)
		var nm := UI.text(b, String(Career.SHOP[k].name), 11, UI.TEXT)
		nm.add_theme_font_override("font", UI.display_it)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.position = Vector2(0, 66)
		nm.size = Vector2(87, 16)
		var tg := HBoxContainer.new()
		tg.alignment = BoxContainer.ALIGNMENT_CENTER
		tg.add_theme_constant_override("separation", 3)
		tg.position = Vector2(0, 86)
		tg.size = Vector2(87, 20)
		tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tg)
		var ti := Icon.make("coin", 15, UI.OK)
		tg.add_child(ti)
		var tl := UI.text(tg, "", 13, UI.OK)
		tl.add_theme_font_override("font", UI.display_it)
		car_cards[k] = {"btn": b, "thumb": th, "name": nm, "tag_icon": ti, "tag": tl}
		room.thumb("car:" + k, th)


func _build_action() -> void:
	action_b = Button.new()
	action_b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action_b.offset_left = -310
	action_b.offset_right = -24
	action_b.offset_top = -104
	action_b.offset_bottom = -26
	action_b.text = "LARGAR!"
	UI.style_button(action_b, true, 30)
	action_b.pressed.connect(_action)
	add_child(action_b)


# ------------------------------------------------------------------ abrir / estado
func open() -> void:
	view_kind = String(game.save.car)
	sel_up = ""
	_set_tab("parts")
	room.set_focus("")
	refresh()


func _back() -> void:
	game.sfx.play("coin", -14.0, 1.6)
	if game.career.active():
		game.career.open_world(int(game.career.event.world))
	else:
		hud.show_screen("tracks")


func _set_tab(t: String) -> void:
	if tab == t and pages[t].visible:
		return
	tab = t
	for k in pages:
		(pages[k] as Control).visible = k == t
		var tb: Dictionary = tab_btns[k]
		(tb.btn as Button).add_theme_stylebox_override("normal", _card_style(k == t, true))
		(tb.icon as Icon).set_icon((tb.icon as Icon).icon, UI.HOT if k == t else UI.TEXT)
	if t != "parts":
		sel_up = ""
	room.set_focus("wpn" if t == "arsenal" else "")
	refresh()


func _car_view(k: String) -> void:
	if view_kind == k:
		return
	view_kind = k
	sel_up = ""
	room.set_focus("")
	# carro que já é seu: vira o carro equipado
	if game.career.owned(k) and String(game.save.car) != k:
		game.career.pick_car(k)
	game.sfx.play("drop", -10.0, 1.3)
	refresh()


## tocar/clicar num cartão só escolhe; comprar sempre passa pela caixa de confirmação.
## No controle, apertar A no cartão já escolhido abre a confirmação.
func _car_pressed(k: String) -> void:
	if view_kind != k or hud.pointer_recent():
		_car_view(k)
	elif not game.career.owned(k):
		_action()


func _part_sel(k: String) -> void:
	if sel_up == k:
		return
	sel_up = k
	room.set_focus(String(UP_FOCUS[k]))
	refresh()


func _part_pressed(k: String) -> void:
	if sel_up != k or hud.pointer_recent():
		_part_sel(k)
	else:
		_ask_up(k)


## sem dinheiro: avisa quanto falta (e não abre a caixa)
func _short(price: int) -> bool:
	if int(game.save.cash) >= price:
		return false
	hud.popup("Faltam $%d" % (price - int(game.save.cash)), Color("#ff7a7a"))
	game.sfx.play("error", -8.0)
	return true


func _ask_up(k: String) -> void:
	if k == "" or not _can_up(k):
		return
	var lvl := int(game.save.up.get(k, 0))
	if lvl >= 3:
		return
	var price: int = game.upgrade_price(k)
	if _short(price):
		return
	var lo: Array = Car.LOADOUT[String(game.save.car)]
	hud.confirm_buy(_up_name(k, lo), "NÍVEL %d DE 3" % (lvl + 1), price, _buy.bind(k))


func _buy(k: String) -> void:
	if k == "" or not _can_up(k):
		return
	var lvl := int(game.save.up.get(k, 0))
	if lvl >= 3 or _short(game.upgrade_price(k)):
		return
	game.buy_upgrade(k)
	room.flash()


func _ask_weapon() -> void:
	var ck := String(game.save.car)
	if game.career.has_front(ck) or not game.career.owned(ck):
		return
	var price: int = game.career.weapon_price(ck)
	if _short(price):
		return
	hud.confirm_buy(String(Car.FRONT[String(Car.LOADOUT[ck][0])].name), "ARMA DE ATAQUE", price, func():
		game.equip("front", "atk")
		room.flash())


## especial: o que já é seu equipa/desequipa direto; comprar pede confirmação
func _special_pressed(spk: String) -> void:
	var ck := String(game.save.car)
	if not game.career.active() or game.career.owns_special(ck, spk):
		game.equip("special", spk)
		return
	var price: int = game.career.special_price(spk)
	if _short(price):
		return
	hud.confirm_buy(String(Car.SPECIAL[spk].label), "ESPECIAL", price, func():
		game.equip("special", spk)
		room.flash())


func _action() -> void:
	var k := view_kind
	if game.career.owned(k):
		game.start_race()
		return
	if game.career.available(k):
		var price := int(Career.SHOP[k].price)
		if _short(price):
			return
		hud.confirm_buy(String(Career.SHOP[k].name), "NOVO CARRO", price, _buy_car.bind(k))
		return
	hud.popup("Disponível no MUNDO %d" % (int(Career.SHOP[k].world) + 1), Color("#ff7a7a"))
	game.sfx.play("error", -8.0)


func _buy_car(k: String) -> void:
	var msg: String = game.career.pick_car(k)
	if msg != "":
		hud.popup(msg, Color("#ff7a7a"))
		game.sfx.play("error", -8.0)
	else:
		room.flash()
		hud.popup(String(Career.SHOP[k].name) + "!", UI.HOT, "NOVO CARRO NA GARAGEM")
	refresh()


func _can_up(k: String) -> bool:
	var ck := String(game.save.car)
	if view_kind != ck or not game.career.owned(ck):
		return false
	if k in WPN_UPS and not game.career.has_front(ck):
		return false
	if k == "rear" and String(Car.LOADOUT[ck][1]) == "none":
		return false
	return true


# ------------------------------------------------------------------ atualização
func refresh() -> void:
	if game == null or game.career == null:
		return
	var s: Dictionary = game.save
	var k := view_kind if view_kind != "" else String(s.car)
	var owned: bool = game.career.owned(k)
	var mine := owned and k == String(s.car)
	var lo: Array = Car.LOADOUT[k]
	var kit: Array = game.career.loadout(k) if mine else [lo[0], lo[1], lo[2], ""]
	var up: Dictionary = (s.garage.up.get(k, {}) as Dictionary).duplicate() if owned else {}
	var col := Color(String(s.get("color", game.PAINT_COLORS[0]))) if mine else Color(String(Showroom.THUMB_COLORS.get(k, "#e8352b")))
	# prévia do próximo nível do upgrade selecionado
	var pup := up.duplicate()
	if mine and sel_up != "" and int(up.get(sel_up, 0)) < 3 and _can_up(sel_up):
		pup[sel_up] = int(up.get(sel_up, 0)) + 1
	room.show_car(k, col, kit[0], kit[1], kit[2], pup, kit[3])
	# título e dinheiro
	var d: Dictionary = TrackData.TRACKS[game.track_idx]
	var ev: Dictionary = game.career.event if game.career.active() else {}
	if ev.is_empty():
		title_l.text = String(d.name).to_upper()
	else:
		title_l.text = ("CHEFE · " if ev.boss else "MUNDO %d · " % (int(ev.world) + 1)) + String(d.name).to_upper()
	cash_l.text = _money(int(s.cash))
	# carro: nome, classe, nota geral e medidores
	name_l.text = String(Career.SHOP[k].name)
	class_l.text = String(Career.SHOP[k].get("class", ""))
	var front_now: String = kit[0]
	var base := Car.ratings(k, {}, lo[0])
	var cur := Car.ratings(k, up, front_now if front_now != "none" else "none")
	var prv := Car.ratings(k, pup, front_now if front_now != "none" else "none")
	var cmp := {}
	if k != String(s.car):
		cmp = Car.ratings(String(s.car), s.up, String(game.career.loadout(String(s.car))[0]))
	ovr_v = Car.overall(cur)
	ovr.set_meta("prev", Car.overall(prv))
	ovr.queue_redraw()
	for st in Car.STAT_KEYS:
		var m: Dictionary = meters[st]
		var sb: StatBar = m.bar
		sb.base = minf(float(base[st]), float(cur[st])) if st != "atk" or front_now != "none" else 0.0
		sb.cur = float(cur[st])
		sb.prev = float(prv[st])
		sb.cmp = float(cmp[st]) if not cmp.is_empty() else -1.0
		sb.queue_redraw()
		var dv := float(prv[st]) - float(cur[st])
		(m.delta as Label).text = "+%.1f" % dv if dv > 0.05 else ""
	# equipamento em ícones
	var labels := [Car.LBL_F.get(lo[0], "—"), Car.LBL_R.get(lo[1], "—"), String(Car.NITRO[lo[2]].label), Car.SPECIAL[kit[3]].label if kit[3] != "" else "—"]
	var icons := ["atk", "rear", String(lo[2]), String(kit[3]) if kit[3] != "" else "shield"]
	for i in 4:
		var li: Dictionary = load_icons[i]
		var have: bool = not (i == 0 and front_now == "none") and not (i == 3 and kit[3] == "")
		(li.icon as Icon).set_icon(icons[i], UI.HOT if have else Color(1, 1, 1, 0.25))
		(li.label as Label).text = labels[i]
		(li.label as Label).modulate = Color(1, 1, 1, 1.0 if have else 0.35)
	_refresh_parts(k, mine, up, lo)
	_refresh_arsenal(k, mine, kit, lo)
	_refresh_paint(mine)
	_refresh_carousel(k)
	_refresh_action(k)


func _money(v: int) -> String:
	var t := str(absi(v))
	var out := ""
	while t.length() > 3:
		out = ("," if Lang.en() else ".") + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if v < 0 else "") + t + out


func _part_thumb(k: String, lvl: int, ck: String) -> String:
	var fk := String(Car.LOADOUT[ck][0])
	var mk := String(Car.MODEL.get(ck, ck))
	match k:
		"engine":
			return ["part:kit_scoop", "part:kit_blower", "part:kit_blower3", "part:kit_blower3"][lvl]
		"armor":
			var items: Array = []
			if not mk in Car.STOCK_BULLBAR:
				items.append("part:kit_bullbar")
			if mk != "trovao":
				items.append("part:kit_armor")
			items.append("part:kit_bullbar")
			return items[mini(lvl, items.size() - 1)]
		"tires":
			return "tire:knobby" if mk in Car.OFFROAD else ["tire:sport", "tire:slick", "tire:slick", "tire:slick"][lvl]
		"nitro":
			return ""   # mobilidade não aparece no carro: o cartão mostra o ícone
		"rear":
			return "part:kit_dispenser"
		"ammo":
			return "part:kit_drum"
		"dmg":
			return "wpn:%s:kit_heatsink" % fk
		"rate":
			return "wpn:%s:kit_vent" % fk
	return ""


func _up_effect(k: String, lo: Array) -> String:
	match k:
		"engine":
			return "+4% VELOCIDADE E ACELERAÇÃO"
		"armor":
			return "+20% BLINDAGEM"
		"tires":
			return "+6% ADERÊNCIA"
		"nitro":
			return "+1 %s POR VOLTA" % String(Car.NITRO[lo[2]].label)
		"rear":
			return "+1 %s POR VOLTA" % String(Car.LBL_R.get(lo[1], "ITEM"))
		"ammo":
			return "+%d TIROS POR VOLTA" % int(Car.FRONT[lo[0]].up)
		"dmg":
			return "+25% DE DANO"
		"rate":
			return "+22% CADÊNCIA"
	return ""


func _up_name(k: String, lo: Array) -> String:
	if k == "nitro":
		return String(Car.NITRO[lo[2]].label)
	if k == "rear":
		return String(Car.LBL_R.get(lo[1], "ITEM"))
	return String(UP_NAME[k])


func _refresh_parts(k: String, mine: bool, up: Dictionary, lo: Array) -> void:
	var cash := int(game.save.cash)
	for uk in UP_ORDER:
		var card: Dictionary = part_cards[uk]
		var lvl := int(up.get(uk, 0))
		var ok := mine and _can_up(uk)
		card.lvl = lvl
		card.next = sel_up == uk and lvl < 3 and ok
		(card.name as Label).text = _up_name(uk, lo)
		var pr: Label = card.price
		var b: Button = card.btn
		if not mine:
			pr.text = "—"
			pr.add_theme_color_override("font_color", UI.MUTED)
		elif not ok:
			pr.text = "SEM ARMA" if uk in WPN_UPS else "—"
			pr.add_theme_color_override("font_color", UI.MUTED)
		elif lvl >= 3:
			pr.text = "MÁX"
			pr.add_theme_color_override("font_color", UI.HOT)
		else:
			var price: int = game.upgrade_price(uk)
			pr.text = "$" + _money(price)
			pr.add_theme_color_override("font_color", UI.OK if cash >= price else UI.BAD)
		b.modulate = Color(1, 1, 1, 1.0 if ok else 0.5)
		b.add_theme_stylebox_override("normal", _card_style(sel_up == uk, true))
		var tk := _part_thumb(uk, mini(lvl, 3), k)
		(card.big as Icon).visible = tk == ""
		(card.thumb as TextureRect).visible = tk != ""
		(card.icon as Icon).visible = tk != ""
		if tk == "":
			(card.big as Icon).set_icon(String(lo[2]), UI.INFO)
		else:
			room.thumb(tk, card.thumb)
		(card.pips as Control).queue_redraw()
	# detalhe (só com uma peça escolhida, na aba de peças)
	detail.visible = sel_up != "" and tab == "parts" and mine
	if not detail.visible:
		return
	var lvl2 := int(up.get(sel_up, 0))
	detail_icon.set_icon(sel_up, UI.HOT)
	detail_name.text = "%s  NV %d/3" % [_up_name(sel_up, lo), lvl2]
	detail_fx.text = _up_effect(sel_up, lo) if lvl2 < 3 else "NO MÁXIMO"
	if not _can_up(sel_up) or lvl2 >= 3:
		buy_b.text = "MÁX" if lvl2 >= 3 else "—"
		buy_b.disabled = true
	else:
		var price2: int = game.upgrade_price(sel_up)
		buy_b.text = "$" + _money(price2)
		buy_b.disabled = cash < price2


func _refresh_arsenal(k: String, mine: bool, kit: Array, lo: Array) -> void:
	var fk: String = lo[0]
	var hist: bool = game.career.active()
	room.thumb("wpn:" + fk, wpn_card.thumb)
	(wpn_card.name as Label).text = String(Car.FRONT[fk].name).to_upper()
	var pw: StatBar = wpn_card.power
	pw.base = float(Car.WPN_POWER.get(fk, 4.0))
	pw.cur = pw.base
	pw.prev = pw.base
	pw.queue_redraw()
	var st: Label = wpn_card.state
	var has: bool = kit[0] != "none"
	if not mine:
		st.text = ""
	elif has:
		st.text = "EQUIPADA" if hist else "LIBERADA"
		st.add_theme_color_override("font_color", UI.HOT)
	else:
		var p: int = game.career.weapon_price(k)
		st.text = "COMPRAR $" + _money(p)
		st.add_theme_color_override("font_color", UI.OK if int(game.save.cash) >= p else UI.BAD)
	(wpn_card.btn as Button).disabled = not mine
	for ik in ["rear", "nitro"]:
		var ch: Dictionary = info_chips[ik]
		var ups := int((game.save.garage.up.get(k, {}) as Dictionary).get(ik, 0)) if mine else 0
		if ik == "rear":
			(ch.icon as Icon).set_icon("rear", UI.HOT)
			(ch.name as Label).text = String(Car.LBL_R.get(lo[1], "—"))
			(ch.cap as Label).text = "×%d POR VOLTA" % (int(Car.REAR[lo[1]].cap) + int(Car.REAR[lo[1]].up) * ups)
		else:
			(ch.icon as Icon).set_icon(String(lo[2]), UI.INFO)
			(ch.name as Label).text = String(Car.NITRO[lo[2]].label)
			(ch.cap as Label).text = "×%d POR VOLTA" % (int(Car.NITRO[lo[2]].cap) + ups)
	for spk in spec_cards:
		var sc: Dictionary = spec_cards[spk]
		var owned_sp: bool = game.career.owns_special(k, spk) if mine else false
		var eq: bool = mine and String(kit[3]) == spk
		var l: Label = sc.state
		if not mine:
			l.text = ""
		elif eq:
			l.text = "EQUIPADO"
			l.add_theme_color_override("font_color", UI.HOT)
		elif owned_sp:
			l.text = "USAR"
			l.add_theme_color_override("font_color", UI.TEXT)
		else:
			var p2: int = game.career.special_price(spk)
			l.text = "$" + _money(p2)
			l.add_theme_color_override("font_color", UI.OK if int(game.save.cash) >= p2 else UI.BAD)
		(sc.btn as Button).add_theme_stylebox_override("normal", _card_style(eq, true))
		(sc.btn as Button).disabled = not mine
		(sc.icon as Icon).set_icon(spk, UI.HOT if eq else UI.INFO)


func _refresh_paint(mine: bool) -> void:
	var cur := String(game.save.get("color", game.PAINT_COLORS[0]))
	for sw in swatches:
		var b: Button = sw.btn
		var hexc := String(b.get_meta("col"))
		var c := Color(hexc)
		var on := hexc == cur
		b.add_theme_stylebox_override("normal", UI.box(c, Color.WHITE if on else Color(0, 0, 0, 0.6), 4 if on else 2, 0.12, 0, Color.BLACK, 6))
		b.add_theme_stylebox_override("hover", UI.box(c.lightened(0.15), Color.WHITE, 3, 0.12, 0, Color.BLACK, 6))
		b.add_theme_stylebox_override("focus", UI.box(c.lightened(0.15), Color.WHITE, 3, 0.12, 0, Color.BLACK, 6))
		b.add_theme_stylebox_override("pressed", UI.box(c, Color.WHITE, 4, 0.12, 0, Color.BLACK, 6))
		b.add_theme_stylebox_override("disabled", UI.box(Color(c, 0.25), Color(0, 0, 0, 0.4), 2, 0.12, 0, Color.BLACK, 6))
		var ck: Icon = sw.check
		ck.visible = on
		ck.set_icon("check", Color.BLACK if c.get_luminance() > 0.55 else Color.WHITE)
		b.disabled = not mine


func _refresh_carousel(k: String) -> void:
	var s: Dictionary = game.save
	for ck in car_cards:
		var cc: Dictionary = car_cards[ck]
		var b: Button = cc.btn
		var owned: bool = game.career.owned(ck)
		var avail: bool = game.career.available(ck)
		var ti: Icon = cc.tag_icon
		var tl: Label = cc.tag
		if ck == String(s.car):
			ti.set_icon("star", UI.HOT)
			tl.text = "SEU"
			tl.add_theme_color_override("font_color", UI.HOT)
		elif owned:
			ti.set_icon("check", UI.TEXT)
			tl.text = ""
		elif avail:
			ti.set_icon("coin", UI.OK)
			tl.text = _money(int(Career.SHOP[ck].price))
			tl.add_theme_color_override("font_color", UI.OK if int(s.cash) >= int(Career.SHOP[ck].price) else UI.BAD)
		else:
			ti.set_icon("lock", UI.MUTED)
			tl.text = "MUNDO %d" % (int(Career.SHOP[ck].world) + 1)
			tl.add_theme_color_override("font_color", UI.MUTED)
		(cc.thumb as TextureRect).modulate = Color(1, 1, 1) if avail or owned else Color(0.05, 0.05, 0.08, 0.9)
		var on: bool = ck == k
		b.add_theme_stylebox_override("normal", _card_style(on, true))
		b.add_theme_stylebox_override("hover", _card_style(true))
		b.add_theme_stylebox_override("focus", _card_style(true, on))
		b.add_theme_stylebox_override("pressed", _card_style(true, true))


func _refresh_action(k: String) -> void:
	var owned: bool = game.career.owned(k)
	var t := "LARGAR!"
	action_b.disabled = false
	if not owned:
		if game.career.available(k):
			t = "COMPRAR $" + _money(int(Career.SHOP[k].price))
			action_b.disabled = int(game.save.cash) < int(Career.SHOP[k].price)
		else:
			t = "MUNDO %d" % (int(Career.SHOP[k].world) + 1)
			action_b.disabled = true
	var pre := "▸ " if String(action_b.text).begins_with("▸ ") else ""
	action_b.text = pre + t


func _draw_ovr() -> void:
	draw_badge(ovr, ovr_v, float(ovr.get_meta("prev", ovr_v)))


## selo hexagonal da NOTA geral (0-100), com o ganho da prévia em verde
static func draw_badge(ci: Control, v: float, pv: float) -> void:
	var c := ci.size * 0.5
	var r := ci.size.x * 0.47
	var k := ci.size.x / 70.0
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + TAU * i / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, UI.HOT)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.84)
	ci.draw_colored_polygon(inner, UI.INK)
	var txt := "%d" % int(round(v * 10.0))
	var fs := int(28 * k)
	var w := UI.display.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(UI.display, c + Vector2(-w * 0.5, 8 * k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
	if pv > v + 0.01:
		var t2 := "+%d" % int(round((pv - v) * 10.0))
		ci.draw_string(UI.display, c + Vector2(-12 * k, 30 * k), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), UI.OK)
	var l := Lang.t("NOTA")
	var fs2 := int(10 * k)
	var w2 := UI.body_bold.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	ci.draw_string(UI.body_bold, c + Vector2(-w2 * 0.5, -14 * k), l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, UI.MUTED)
