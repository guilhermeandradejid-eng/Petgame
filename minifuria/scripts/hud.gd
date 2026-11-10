class_name Hud
extends CanvasLayer
## HUD de corrida, telas (menu, pistas, garagem, pausa, resultado) e pós-processamento de tela.

var game: Node
var font: Font
var post: ColorRect
var post_mat: ShaderMaterial
var root: Control
var race_nodes: Array = []
var pos_l: Label
var lap_l: Label
var time_l: Label
var score_l: Label
var speed_l: Label
var onc_l: Label
var big_l: Label
var _big_tw: Tween
var wrong_l: Label
var steer_btns: Array = []
var pops: VBoxContainer
var feed: VBoxContainer
var status: Control
var minimap: Control
var touch: TouchPad
var menu: Control
var tracks_s: Control
var garage: Control
var pause_m: Control
var results: Control
var res_title: Label
var res_list: Label
var res_cash: Label
var mute_b: Button
var pause_extra: VBoxContainer   # opções do online (voz) entram aqui
var extra_screens := {}   # telas registradas por outros módulos (multijogador local, online)
var cur_screen := ""
var t := 0.0
var track: Track
var cars: Array = []
var player: Car
var _mm_pts := PackedVector2Array()
var _mm_sc := 1.0
var _mm_o := Vector2.ZERO


func _init() -> void:
	layer = 5


func _ready() -> void:
	font = load("res://fonts/Bungee.woff2")
	UI.load_fonts()
	var th := UI.make_theme()
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	post.material = post_mat
	pl.add_child(post)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = th
	add_child(root)
	_build_race_hud()
	_build_menu()
	_build_tracks()
	_build_garage()
	_build_pause()
	_build_results()
	show_screen("menu")


# ------------------------------------------------------------------ helpers
func _label(fs: int, col: Color, outline: Color, parent: Node = null) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = UI.display_it if fs >= 28 else font
	ls.font_size = fs
	ls.font_color = col
	ls.outline_size = maxi(4, fs / 6)
	ls.outline_color = outline
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(0, maxf(1.0, fs * 0.06))
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else root).add_child(l)
	return l


func _sb(col: Color, radius := 16, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _btn(txt: String, parent: Node, primary := true, w := 300.0, h := 66.0) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.style_button(b, primary, 24 if primary else 18)
	b.pressed.connect(func(): if game: game.sfx.play("coin", -14.0, 1.6))
	parent.add_child(b)
	return b


func _screen(dim := 0.62) -> Control:
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	UI.backdrop(bg, clampf(dim + 0.12, 0.6, 0.94))
	return bg


func _vcenter(parent: Control, sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func refresh_steer() -> void:
	var tela := String(game.save.get("steer", "tela")) == "tela"
	for b in steer_btns:
		(b as Button).text = "DIREÇÃO: TELA" if tela else "DIREÇÃO: CARRO"


func show_screen(name_: String) -> void:
	close_confirm()
	if not name_ in ["race", "results", "pause", "none"]:
		caption_hide()
	if game and steer_btns.size() > 0:
		refresh_steer()
	if name_ != "race" and wrong_l:
		wrong_l.visible = false
	menu.visible = name_ == "menu"
	tracks_s.visible = name_ == "tracks"
	garage.visible = name_ == "garage"
	pause_m.visible = name_ == "pause"
	results.visible = name_ == "results"
	var racing := name_ == "race" or name_ == "pause"
	for nd in race_nodes:
		nd.visible = racing and not (nd as Node).get_meta("split_hide", false)
	touch.show_if(name_ == "race" and not touch.get_meta("split_hide", false))
	if name_ == "tracks":
		_refresh_tracks()
	if extra_screens.has(name_) or name_ in ["menu", "tracks", "garage", "pause", "results"]:
		_focus_first.call_deferred(name_)
	for k in extra_screens:
		(extra_screens[k] as Control).visible = k == name_
	cur_screen = name_
	_sync_showroom.call_deferred()


## controle/teclado no menu: o primeiro botão da tela recebe o foco (navega com direcional e confirma com A)
func _focus_first(name_: String) -> void:
	var scr: Control = extra_screens.get(name_, {"menu": menu, "tracks": tracks_s, "garage": garage, "pause": pause_m, "results": results}.get(name_))
	if scr == null or not scr.visible:
		return
	if name_ == "garage" and garage_ui and not garage_ui.action_b.disabled:
		var fo0 := get_viewport().gui_get_focus_owner()
		if not (fo0 and scr.is_ancestor_of(fo0) and fo0.is_visible_in_tree()):
			garage_ui.action_b.grab_focus()
		return
	var fo := get_viewport().gui_get_focus_owner()
	if fo and scr.is_ancestor_of(fo) and fo.is_visible_in_tree():
		return
	# primeiro botão que não seja o VOLTAR (com controle, abrir uma tela já deixa o primeiro item escolhido)
	var back: Control = null
	var stack: Array = [scr]
	while stack.size() > 0:
		var nd: Node = stack.pop_front()
		if nd is BaseButton and (nd as Control).is_visible_in_tree() and (nd as Control).focus_mode != Control.FOCUS_NONE and not (nd as BaseButton).disabled:
			if nd is Button and (nd as Button).text == "VOLTAR":
				if back == null:
					back = nd
			else:
				(nd as Control).grab_focus()
				return
		stack.append_array(nd.get_children())
	if back:
		back.grab_focus()


# ------------------------------------------------------------------ HUD da corrida
func _build_race_hud() -> void:
	# placa de posição, volta, tempo e velocidade (desenhada: ícones no lugar de texto)
	info = Control.new()
	info.position = Vector2(16, 10)
	info.size = Vector2(330, 120)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.draw.connect(_draw_info)
	root.add_child(info)
	# rótulos antigos (o jogo ainda escreve neles; ficam escondidos)
	pos_l = _label(10, Color.WHITE, Color.BLACK)
	lap_l = _label(10, Color.WHITE, Color.BLACK)
	time_l = _label(10, Color.WHITE, Color.BLACK)
	score_l = _label(10, Color.WHITE, Color.BLACK)
	for l in [pos_l, lap_l, time_l, score_l]:
		l.visible = false
	status = Control.new()
	status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status.position = Vector2(-240, 12)
	status.size = Vector2(480, 64)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.draw.connect(_draw_status)
	root.add_child(status)
	onc_l = _label(15, Color.WHITE, Color("#ff2d55"))
	onc_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	onc_l.position = Vector2(-70, 96)
	onc_l.text = "CONTRAMÃO!"
	onc_l.modulate.a = 0.0
	speed_l = _label(10, Color.WHITE, Color.BLACK)
	speed_l.visible = false
	pops = VBoxContainer.new()
	pops.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pops.position = Vector2(-250, 140)
	pops.custom_minimum_size = Vector2(500, 0)
	pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pops)
	big_l = _label(92, Color.WHITE, Color("#ff2d55"))
	big_l.set_anchors_preset(Control.PRESET_CENTER)
	big_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# offsets explícitos a partir do centro (com "position" o Godot usava a posição absoluta e o aviso
	# grande — contagem 3, 2, 1, VAI! — ficava fora da tela, no canto superior esquerdo)
	big_l.offset_left = -500
	big_l.offset_right = 500
	big_l.offset_top = -150
	big_l.offset_bottom = 10
	big_l.pivot_offset = Vector2(500, 80)
	big_l.modulate.a = 0.0
	wrong_l = _label(40, Color.WHITE, Color("#ff2d55"))
	wrong_l.set_anchors_preset(Control.PRESET_CENTER)
	wrong_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_l.offset_left = -350
	wrong_l.offset_right = 350
	wrong_l.offset_top = 40
	wrong_l.offset_bottom = 100
	wrong_l.text = "SENTIDO ERRADO! VIRE"
	wrong_l.visible = false
	minimap = Control.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-210, 10)
	minimap.size = Vector2(140, 132)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	root.add_child(minimap)
	# barra do chefe: em cima, logo abaixo da sua blindagem (embaixo ela batia nos botões de toque)
	boss_bar = Control.new()
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.position = Vector2(-240, 76)
	boss_bar.size = Vector2(480, 54)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.visible = false
	boss_bar.draw.connect(_draw_boss)
	root.add_child(boss_bar)
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed.position = Vector2(-330, 142)
	feed.custom_minimum_size = Vector2(320, 0)
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)
	var btns := VBoxContainer.new()
	btns.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btns.position = Vector2(-62, 10)
	btns.add_theme_constant_override("separation", 8)
	root.add_child(btns)
	mute_b = _small_btn("", btns)
	mute_icon = Icon.make("sound", 26, UI.TEXT)
	mute_icon.position = Vector2(13, 9)
	mute_b.add_child(mute_icon)
	mute_b.pressed.connect(func(): game.toggle_mute())
	var pb := _small_btn("", btns)
	var pic := Icon.make("pause", 26, UI.TEXT)
	pic.position = Vector2(13, 9)
	pb.add_child(pic)
	pb.pressed.connect(func(): game.pause(true))
	touch = TouchPad.new()
	touch.font = font
	root.add_child(touch)
	race_nodes = [info, status, onc_l, minimap, feed, btns]
	_build_caption()


func _small_btn(txt: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(52, 44)
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	var sb := UI.box(Color(0.06, 0.05, 0.11, 0.7), Color(1, 1, 1, 0.18), 1, 0.12, 0, Color(0, 0, 0, 0), 6)
	var sh := UI.box(Color(0.14, 0.11, 0.26, 0.85), UI.HOT, 2, 0.12, 0, Color(0, 0, 0, 0), 6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	parent.add_child(b)
	return b


var info: Control
var mute_icon: Icon
var _ri := {}


## dados da placa do canto (posição, volta, tempo, velocidade, destruídos, dinheiro): o jogo chama a cada quadro
func set_race_info(d: Dictionary) -> void:
	_ri = d
	info.queue_redraw()


func _outlined(c: CanvasItem, f: Font, pos: Vector2, txt: String, fs: int, col: Color, ow := 5) -> float:
	c.draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, Color(0.03, 0.02, 0.07, 0.85))
	c.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _draw_info() -> void:
	if _ri.is_empty():
		return
	var c := info
	var sk := 16.0
	var pw := 112.0
	var ph := 74.0
	# placa da posição: paralelogramo escuro com faixa âmbar; 1º lugar fica âmbar inteira
	var first := int(_ri.place) == 1
	c.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(pw + sk, 0), Vector2(pw, ph), Vector2(0, ph)]),
		Color(1.0, 0.7, 0.1, 0.92) if first else Color(0.06, 0.05, 0.11, 0.8))
	c.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(sk + 8, 0), Vector2(8, ph), Vector2(0, ph)]), UI.BAD if first else UI.HOT)
	var pl := "%d" % int(_ri.place)
	var w := _outlined(c, UI.display_it, Vector2(24, 62), pl, 56, UI.INK if first else Color.WHITE, 0 if first else 6)
	_outlined(c, UI.display_it, Vector2(26 + w, 40), Lang.ord_suffix(int(_ri.place)), 22, UI.INK if first else UI.HOT, 0 if first else 4)
	_outlined(c, UI.display_it, Vector2(30 + w, 64), "/%d" % int(_ri.n), 16, Color(0.03, 0.02, 0.07, 0.7) if first else UI.MUTED, 0 if first else 4)
	# volta, tempo e velocidade
	var x0 := pw + sk + 14.0
	Icon.paint(c, "flag", Rect2(x0, 2, 24, 24), UI.HOT)
	_outlined(c, UI.display_it, Vector2(x0 + 30, 24), "%d/%d" % [int(_ri.lap), int(_ri.laps)], 24, Color.WHITE)
	Icon.paint(c, "clock", Rect2(x0 + 2, 32, 20, 20), UI.MUTED)
	_outlined(c, UI.body_bold, Vector2(x0 + 30, 49), String(_ri.time), 19, Color.WHITE, 4)
	Icon.paint(c, "spd", Rect2(x0 + 2, 56, 20, 20), UI.MUTED)
	var sw := _outlined(c, UI.display_it, Vector2(x0 + 30, 74), "%d" % int(_ri.spd), 18, Color.WHITE, 4)
	_outlined(c, UI.body_bold, Vector2(x0 + 34 + sw, 74), "KM/H", 11, UI.MUTED, 3)
	# destruídos e dinheiro, pequenos, embaixo da placa
	Icon.paint(c, "skull", Rect2(2, ph + 8, 18, 18), UI.BAD)
	var kw := _outlined(c, UI.display_it, Vector2(24, ph + 24), "%d" % int(_ri.kills), 16, Color.WHITE, 4)
	Icon.paint(c, "coin", Rect2(36 + kw, ph + 8, 18, 18), UI.OK)
	_outlined(c, UI.display_it, Vector2(58 + kw, ph + 24), garage_ui._money(int(_ri.cash)) if garage_ui else str(int(_ri.cash)), 16, UI.OK, 4)


func popup(text: String, col: Color, sub := "") -> void:
	var l := _label(28, Color.WHITE, col, pops)
	l.text = text + ("\n" + sub if sub != "" else "")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(250, 20)
	l.scale = Vector2(0.3, 0.3)
	l.rotation = -0.15
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "rotation", 0.03, 0.14)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(l, "rotation", 0.0, 0.1)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	while pops.get_child_count() > 3:
		var c := pops.get_child(0)
		pops.remove_child(c)
		c.queue_free()


# ------------------------------------------------------------------ confirmação de compra
var _confirm_box: Control
var _confirm_prev: Control
var _ptr_ms := -100000


func _input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.is_pressed():
		_ptr_ms = Time.get_ticks_msec()
	if _confirm_box and ev.is_action_pressed("ui_cancel"):
		close_confirm()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_cancel") and not ev is InputEventKey:
		# B do controle = VOLTAR da tela aberta (no teclado o Esc continua sendo a pausa)
		var scr: Control = extra_screens.get(cur_screen, {"tracks": tracks_s, "garage": garage}.get(cur_screen))
		if scr and scr.visible:
			var b := _find_back(scr)
			if b:
				b.pressed.emit()
				get_viewport().set_input_as_handled()


func _find_back(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).is_visible_in_tree() and (c as Button).text == "VOLTAR":
			return c
		var r := _find_back(c)
		if r:
			return r
	return null


## o último clique/toque foi agora há pouco? (aí tocar num cartão só seleciona; a compra pede confirmação)
func pointer_recent() -> bool:
	return Time.get_ticks_msec() - _ptr_ms < 700


## caixa "COMPRAR?": nome, detalhe, preço e saldo depois; só compra no botão COMPRAR
func confirm_buy(what: String, sub: String, price: int, on_yes: Callable) -> void:
	close_confirm()
	var fo := get_viewport().gui_get_focus_owner()
	_confirm_prev = fo if fo is Control else null
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
			close_confirm())
	bg.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(cc)
	var pc := PanelContainer.new()
	var sb := UI.panel_box(UI.HOT)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(540, 0)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var q := UI.text(v, "COMPRAR?", 16, UI.MUTED)
	q.add_theme_font_override("font", UI.display_it)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.title(v, what.to_upper(), 34, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	if sub != "":
		var sl := UI.text(v, sub, 16, UI.INFO)
		sl.add_theme_font_override("font", UI.display_it)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 10)
	v.add_child(pr)
	var ic := Icon.make("coin", 36, UI.OK)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(ic)
	UI.title(pr, "$" + garage_ui._money(price), 42, UI.OK)
	var cash := int(game.save.cash)
	var bal := UI.text(v, "SALDO  $%s  →  $%s" % [garage_ui._money(cash), garage_ui._money(cash - price)], 15, UI.MUTED)
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var no := UI.icon_button("CANCELAR", "back", false, 18, 210, 58)
	h.add_child(no)
	var yes := UI.icon_button("COMPRAR", "coin", true, 22, 250, 58)
	h.add_child(yes)
	no.pressed.connect(func():
		game.sfx.play("click", -14.0)
		close_confirm())
	yes.pressed.connect(func():
		close_confirm()
		on_yes.call())
	# o foco do controle fica preso nos dois botões enquanto a caixa está aberta
	for b in [no, yes]:
		(b as Control).focus_neighbor_top = (b as Control).get_path()
		(b as Control).focus_neighbor_bottom = (b as Control).get_path()
	no.focus_neighbor_left = no.get_path()
	no.focus_neighbor_right = yes.get_path()
	yes.focus_neighbor_left = no.get_path()
	yes.focus_neighbor_right = yes.get_path()
	_confirm_box = bg
	game.sfx.play("warn", -16.0, 1.2)
	pc.modulate.a = 0.0
	pc.scale = Vector2(0.88, 0.88)
	(func():
		pc.pivot_offset = pc.size * 0.5
		var tw := pc.create_tween().set_parallel()
		tw.tween_property(pc, "modulate:a", 1.0, 0.12)
		tw.tween_property(pc, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		yes.grab_focus()).call_deferred()


func close_confirm() -> void:
	if _confirm_box == null:
		return
	if is_instance_valid(_confirm_box):
		_confirm_box.queue_free()
	_confirm_box = null
	if _confirm_prev and is_instance_valid(_confirm_prev) and _confirm_prev.is_visible_in_tree():
		_confirm_prev.grab_focus()
	_confirm_prev = null


func killfeed(text: String, col: Color) -> void:
	var l := _label(15, col, Color(0, 0, 0, 0.75), feed)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(320, 0)
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	while feed.get_child_count() > 4:
		var c := feed.get_child(0)
		feed.remove_child(c)
		c.queue_free()


func big(text: String, col: Color, outline: Color) -> void:
	# cancela a animação anterior (senão o fade-out dela apagava o aviso novo — a contagem sumia)
	if _big_tw and _big_tw.is_valid():
		_big_tw.kill()
	big_l.text = text
	big_l.label_settings.font_color = col
	big_l.label_settings.outline_color = outline
	big_l.scale = Vector2(3, 3)
	big_l.rotation = -0.18
	big_l.modulate.a = 0.0
	var tw := big_l.create_tween()
	_big_tw = tw
	tw.tween_property(big_l, "scale", Vector2(0.9, 0.9), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(big_l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(big_l, "rotation", -0.05, 0.18)
	tw.tween_property(big_l, "scale", Vector2(1.05, 1.05), 0.12)
	tw.tween_interval(0.7)
	tw.tween_property(big_l, "scale", Vector2(1.5, 1.5), 0.25)
	tw.parallel().tween_property(big_l, "modulate:a", 0.0, 0.25)


func _process(dt: float) -> void:
	t += dt
	_step_caption(dt)
	if status.visible:
		status.queue_redraw()
		minimap.queue_redraw()


## barra de vida do chefe (embaixo, no centro)
func _draw_boss() -> void:
	var b: Car = game.boss
	if b == null:
		return
	var W := boss_bar.size.x
	var u := clampf(b.health / b.max_health, 0.0, 1.0)
	Icon.paint(boss_bar, "skull", Rect2(2, 2, 26, 26), UI.BAD)
	_outlined(boss_bar, UI.display_it, Vector2(36, 20), Lang.t(b.display_name + ("  · DESTRUÍDO" if b.wrecked else "")), 16, UI.BAD, 5)
	boss_bar.draw_colored_polygon(PackedVector2Array([Vector2(46, 26), Vector2(W, 26), Vector2(W - 10, 46), Vector2(36, 46)]), Color(0.03, 0.02, 0.07, 0.6))
	_seg_bar(boss_bar, Rect2(38, 28, W - 44, 16), 30, u, UI.BAD.lerp(UI.HOT, 1.0 - u))


## segmentos inclinados (barras da identidade): fração cheia com a cor, o resto apagado
func _seg_bar(c: Control, r: Rect2, n: int, frac: float, col: Color, empty := Color(1, 1, 1, 0.1)) -> void:
	var sk := r.size.y * 0.5
	var gap := 2.0
	var sw := (r.size.x - sk - gap * (n - 1)) / n
	for i in n:
		var x := r.position.x + i * (sw + gap)
		var y := r.position.y
		var on := (i + 0.5) / n <= frac
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + sk, y), Vector2(x + sk + sw, y), Vector2(x + sw, y + r.size.y), Vector2(x, y + r.size.y)]),
			col if on else empty)


func _pips(c: Control, x: float, y: float, n: int, full: int, col: Color, active := -1) -> float:
	for i in n:
		var px := x + i * 27.0
		var cc := col if i < full else Color(0.06, 0.05, 0.11, 0.75)
		if i == active:
			cc = Color.WHITE
		c.draw_colored_polygon(PackedVector2Array([Vector2(px + 7, y), Vector2(px + 25, y), Vector2(px + 18, y + 16), Vector2(px, y + 16)]), Color(0, 0, 0, 0.45))
		c.draw_colored_polygon(PackedVector2Array([Vector2(px + 8, y + 2), Vector2(px + 24, y + 2), Vector2(px + 17, y + 14), Vector2(px + 1, y + 14)]), cc)
	return x + n * 27.0


func _draw_status() -> void:
	if player == null:
		return
	var p := player
	var w := status.size.x
	# blindagem: escudo + barra em segmentos (verde -> vermelho; pisca quando está no fim)
	var hr := clampf(p.health / p.max_health, 0.0, 1.0)
	var hc := Color("#ff3048").lerp(Color("#5dff6a"), hr)
	if hr < 0.3 and int(t * 6.0) % 2 == 0:
		hc = Color.WHITE
	Icon.paint(status, "arm", Rect2(0, -2, 28, 28), hc)
	status.draw_colored_polygon(PackedVector2Array([Vector2(44, 0), Vector2(w, 0), Vector2(w - 12, 24), Vector2(32, 24)]), Color(0.03, 0.02, 0.07, 0.6))
	_seg_bar(status, Rect2(36, 3, w - 42, 18), 24, hr, hc)
	# mobilidade (cargas + medidor de manobras) e especial
	var y := 32.0
	Icon.paint(status, p.nitro_type, Rect2(4, y - 2, 24, 24), UI.INFO)
	var cur := p.nitro_ch if p.nitroing else -1
	var xe := _pips(status, 36, y, p.nitro_cap, p.nitro_ch, UI.INFO, cur)
	status.draw_rect(Rect2(38, y + 19, xe - 44, 3), Color(0.03, 0.02, 0.07, 0.7), true)
	status.draw_rect(Rect2(38, y + 19, (xe - 44) * p.nitro_meter, 3), Color("#b4f6ff"), true)
	if p.special_type != "":
		var sx := xe + 16.0
		Icon.paint(status, p.special_type, Rect2(sx, y - 2, 24, 24), UI.OK)
		_pips(status, sx + 30, y, p.spec_cap, p.spec_ch, UI.OK)
	# armas (à direita): arma de ataque e item de chão com a munição
	var ra := "%d" % p.ammo_r
	var rw := UI.display_it.get_string_size(ra, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_outlined(status, UI.display_it, Vector2(w - rw, y + 17), ra, 18, UI.HOT if p.ammo_r > 0 else Color(1, 1, 1, 0.35), 4)
	Icon.paint(status, "rear", Rect2(w - rw - 28, y - 1, 22, 22), UI.HOT if p.ammo_r > 0 else Color(1, 1, 1, 0.35))
	if p.front_type != "none":
		var fa := "%d" % p.ammo_f
		var fw := UI.display_it.get_string_size(fa, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var fx := w - rw - 48 - fw
		_outlined(status, UI.display_it, Vector2(fx, y + 17), fa, 18, Color("#ffb08a") if p.ammo_f > 0 else Color(1, 1, 1, 0.35), 4)
		Icon.paint(status, "atk", Rect2(fx - 28, y - 1, 22, 22), Color("#ff6a3a") if p.ammo_f > 0 else Color(1, 1, 1, 0.35))


func _text(c: Control, s: String, pos: Vector2, fs: int, center: bool, right := false, col := Color.WHITE) -> void:
	s = Lang.t(s)
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos
	if center:
		p.x -= tw * 0.5
	elif right:
		p.x -= tw
	c.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	c.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func set_track(tr: Track) -> void:
	track = tr
	_mm_pts.clear()
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	var raw := PackedVector2Array()
	for i in range(0, tr.n, 3):
		var p := _rot(Vector2(tr.P[i].x, tr.P[i].z))
		raw.append(p)
		mn = mn.min(p)
		mx = mx.max(p)
	raw.append(raw[0])
	var s := minimap.size
	_mm_sc = minf((s.x - 40) / (mx.x - mn.x), (s.y - 22) / (mx.y - mn.y))
	_mm_o = s * 0.5 - (mn + mx) * 0.5 * _mm_sc
	for p in raw:
		_mm_pts.append(p * _mm_sc + _mm_o)


func _draw_minimap() -> void:
	if track == null or _mm_pts.size() < 2:
		return
	var ms := minimap.size
	var sk := 14.0
	minimap.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(ms.x, 0), Vector2(ms.x - sk, ms.y), Vector2(0, ms.y)]), Color(0.06, 0.05, 0.11, 0.62))
	minimap.draw_polyline(PackedVector2Array([Vector2(sk, 0), Vector2(ms.x, 0), Vector2(ms.x - sk, ms.y), Vector2(0, ms.y), Vector2(sk, 0)]), Color(1, 1, 1, 0.14), 1.5, true)
	minimap.draw_polyline(_mm_pts, Color(0.03, 0.02, 0.07, 0.8), 8.0, true)
	minimap.draw_polyline(_mm_pts, Color(0.92, 0.9, 1.0), 4.0, true)
	minimap.draw_circle(_mm_pts[0], 4.0, UI.HOT)
	for c in cars:
		if c.wrecked:
			continue
		var p := _rot(Vector2(c.global_position.x, c.global_position.z)) * _mm_sc + _mm_o
		if c.role == "traffic":
			minimap.draw_circle(p, 2.0, Color(0.4, 0.4, 0.5, 0.7))
		elif c == game.boss:
			minimap.draw_circle(p, 7.0, UI.INK)
			minimap.draw_circle(p, 5.5, UI.BAD)
		elif c.role == "rival":
			minimap.draw_circle(p, 5.0, UI.INK)
			minimap.draw_circle(p, 3.8, c.color)
	if player:
		var p := _rot(Vector2(player.global_position.x, player.global_position.z)) * _mm_sc + _mm_o
		minimap.draw_circle(p, 6.5, Color.WHITE)
		minimap.draw_circle(p, 5.0, Color("#ff2d3d"))


func _rot(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 0.7071, (p.x + p.y) * 0.7071)


# ------------------------------------------------------------------ menu
func _build_menu() -> void:
	# menu: logo e botões com ícone à esquerda; à direita o SEU carro girando na vitrine (Showroom, atrás das telas)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)
	var vg := ColorRect.new()
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/ui_backdrop.gdshader")
	vm.set_shader_parameter("dim", 0.55)
	vm.set_shader_parameter("ink", UI.INK)
	vm.set_shader_parameter("hot", UI.HOT)
	vg.material = vm
	menu.add_child(vg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	m.offset_right = 520
	m.add_theme_constant_override("margin_left", 64)
	m.add_theme_constant_override("margin_top", 44)
	m.add_theme_constant_override("margin_bottom", 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var logo := UI.title(v, "WRECK 'N'", 64, UI.TEXT)
	logo.label_settings.shadow_color = UI.BAD
	logo.add_theme_constant_override("line_spacing", -14)
	var logo2 := UI.title(v, "ROLL", 116, UI.HOT)
	logo2.add_theme_constant_override("line_spacing", -22)
	UI.checker(v, 340, 12)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	v.add_child(sp)
	var big := UI.icon_button("CARREIRA", "trophy", true, 30, 400, 76)
	big.pressed.connect(func(): game.sfx.play("coin", -14.0, 1.6); game.career.open())
	v.add_child(big)
	for it in [["CORRIDA RÁPIDA", "flag", func(): game.set_solo(); game.career.event = {}; show_screen("tracks")],
			["LOCAL", "people", func(): game.multi.open_join()],
			["ONLINE", "globe", func(): game.online.open()]]:
		var b := UI.icon_button(it[0], it[1], false, 20, 340, 56)
		b.pressed.connect(func(): game.sfx.play("coin", -14.0, 1.6); it[2].call())
		v.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var cfg := UI.icon_button("", "gear", false, 18, 76, 56)
	cfg.tooltip_text = "Configurações"
	cfg.pressed.connect(func(): game.settings.open("menu"))
	row.add_child(cfg)
	if OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD"]:
		var ex := UI.icon_button("", "exit", false, 18, 76, 56)
		ex.tooltip_text = "Sair"
		ex.pressed.connect(func(): get_tree().quit())
		row.add_child(ex)
	# idioma: troca na hora entre inglês e português
	lang_b = UI.icon_button("EN" if Lang.en() else "PT", "globe", false, 18, 124, 56)
	lang_b.tooltip_text = "IDIOMA · LANGUAGE"
	lang_b.pressed.connect(func(): game.settings.toggle_lang())
	row.add_child(lang_b)
	menu_anim = v.get_children()
	# dinheiro e nome do carro (canto direito)
	var tr := HBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -320
	tr.offset_right = -32
	tr.offset_top = 26
	tr.offset_bottom = 70
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 10)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(tr)
	tr.add_child(Icon.make("coin", 30, UI.OK))
	menu_cash = UI.title(tr, "", 30, UI.OK)
	# embaixo do carro: nota, nome, classe e os medidores em miniatura
	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info.offset_left = -680
	info.offset_right = -60
	info.offset_top = -210
	info.offset_bottom = -48
	info.alignment = BoxContainer.ALIGNMENT_END
	info.add_theme_constant_override("separation", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(info)
	var hr := HBoxContainer.new()
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	hr.add_theme_constant_override("separation", 14)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hr)
	menu_badge = Control.new()
	menu_badge.custom_minimum_size = Vector2(62, 62)
	menu_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_badge.draw.connect(func(): Garage.draw_badge(menu_badge, float(menu_badge.get_meta("v", 0.0)), 0.0))
	hr.add_child(menu_badge)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -4)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(nv)
	menu_car = UI.title(nv, "", 34, UI.TEXT)
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 10)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.add_child(cr)
	menu_class = UI.text(cr, "", 14, UI.INFO, true)
	menu_class.add_theme_font_override("font", UI.body_bold)
	menu_tag_icon = Icon.make("star", 16, UI.HOT)
	menu_tag_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cr.add_child(menu_tag_icon)
	menu_tag = UI.text(cr, "", 14, UI.HOT)
	menu_tag.add_theme_font_override("font", UI.display_it)
	menu_info = info
	var mr := HBoxContainer.new()
	mr.alignment = BoxContainer.ALIGNMENT_CENTER
	mr.add_theme_constant_override("separation", 16)
	mr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(mr)
	for k in Car.STAT_KEYS:
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mr.add_child(cv)
		var ic := Icon.make(Garage.STAT_ICON[k], 22, UI.TEXT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var bar := Garage.StatBar.new()
		bar.custom_minimum_size = Vector2(84, 10)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(bar)
		menu_bars[k] = bar


var menu_cash: Label
var lang_b: Button
var menu_car: Label
var menu_info: Control
var menu_tag: Label
var menu_tag_icon: Icon
var menu_anim: Array = []
var menu_class: Label
var menu_badge: Control
var menu_bars := {}


# ------------------------------------------------------------------ seleção de pista
func _build_tracks() -> void:
	tracks_s = _screen(0.72)
	var v := _vcenter(tracks_s, 14)
	var tl := UI.title(v, "CORRIDA RÁPIDA", 40, UI.HOT, HORIZONTAL_ALIGNMENT_CENTER)
	tl.label_settings.outline_color = UI.INK
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.name = "Grid"
	v.add_child(grid)
	for i in TrackData.TRACKS.size():
		var d: Dictionary = TrackData.TRACKS[i]
		var th: Dictionary = TrackData.THEMES[d.theme]
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 112)
		b.tooltip_text = String(d.name)
		var c1 := Color(th.sky_hor).darkened(0.55).lerp(UI.INK2, 0.4)
		var sb := UI.box(c1, Color(th.curb[0]), 2, 0.08, 5, Color(0, 0, 0, 0.5), 8)
		sb.border_width_left = 7
		var sh := UI.box(c1.lightened(0.15), Color.WHITE, 3, 0.08, 5, Color.WHITE, 8)
		sh.border_width_left = 9
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("focus", sh)
		b.pressed.connect(func(): game.choose_track(i))
		b.set_meta("idx", i)
		grid.add_child(b)
		# traçado da pista, ícones dos elementos, nome e medalha
		var ti := i
		var art := Control.new()
		art.position = Vector2(14, 6)
		art.size = Vector2(110, 74)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(func(): UI.draw_track(art, ti, Rect2(Vector2.ZERO, art.size), Color(th.curb[1]).lerp(Color.WHITE, 0.5), 3.0))
		b.add_child(art)
		var fy := 8.0
		for f in UI.track_feats(i):
			var ic := Icon.make(f, 18, UI.INFO)
			ic.position = Vector2(132, fy)
			b.add_child(ic)
			fy += 21.0
		var nm := UI.text(b, String(d.name).to_upper(), 11, UI.TEXT)
		nm.add_theme_font_override("font", UI.display_it)
		nm.position = Vector2(12, 84)
		nm.size = Vector2(140, 18)
		nm.clip_text = true
		var md := Label.new()
		md.name = "Medal"
		md.add_theme_font_override("font", UI.display_it)
		md.add_theme_font_size_override("font_size", 14)
		md.add_theme_color_override("font_color", UI.INK)
		md.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		md.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		md.position = Vector2(4, 4)
		md.size = Vector2(32, 22)
		md.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(md)
	var back := UI.icon_button("VOLTAR", "back", false, 18, 220, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen("menu"))
	v.add_child(back)


func _refresh_tracks() -> void:
	var grid := tracks_s.find_child("Grid", true, false)
	for b in grid.get_children():
		var i: int = b.get_meta("idx")
		var best: Dictionary = game.save.best.get(str(i), {})
		var md: Label = b.get_node("Medal")
		md.text = "%dº" % int(best.place) if best.has("place") else ""
		var mc: Color = [Color("#ffcf33"), Color("#d8dbe2"), Color("#d08a4a")][clampi(int(best.get("place", 3)) - 1, 0, 2)]
		var st := StyleBoxFlat.new()
		st.bg_color = mc if best.has("place") and int(best.place) <= 3 else Color(1, 1, 1, 0.25)
		st.set_corner_radius_all(12)
		md.add_theme_stylebox_override("normal", st if best.has("place") else StyleBoxEmpty.new())


# ------------------------------------------------------------------ garagem (vitrine 3D)
var boss_bar: Control
var show3d: Showroom
var garage_ui: Garage


func _build_garage() -> void:
	# a vitrine 3D fica atrás de todas as telas (menu e garagem usam o mesmo estúdio)
	show3d = Showroom.new()
	root.add_child(show3d)
	root.move_child(show3d, 0)
	show3d.setup(game)
	show3d.visible = false
	show3d.car_changed.connect(_menu_car_info)
	garage = Control.new()
	garage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	garage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(garage)
	garage_ui = Garage.new()
	garage.add_child(garage_ui)
	garage_ui.setup(game, self, show3d)


func refresh_garage() -> void:
	if garage_ui and garage.visible:
		garage_ui.refresh()


## liga a vitrine nas telas que mostram o carro (menu e garagem); nas outras a pista volta a aparecer ao fundo
## carros do desfile do menu: o seu primeiro, depois os outros da garagem e os da loja já liberados
func _parade_list() -> Array:
	var s: Dictionary = game.save
	var mine := String(s.car)
	var out: Array = []
	var keys: Array = [mine]
	for k in Career.CAR_ORDER:
		if k != mine and game.career.owned(k):
			keys.append(k)
	for k in Career.CAR_ORDER:
		if not game.career.owned(k) and game.career.available(k):
			keys.append(k)
	for k in keys.slice(0, 7):
		var owned: bool = game.career.owned(k)
		var lo: Array = game.career.loadout(k) if owned else Car.LOADOUT[k] + [""]
		out.append({"kind": k, "col": Color(String(s.get("color", game.PAINT_COLORS[0]))) if owned else Color(String(Showroom.THUMB_COLORS.get(k, "#e8352b"))),
			"front": lo[0], "rear": lo[1], "nitro": lo[2], "special": lo[3], "up": (s.garage.up.get(k, {}) as Dictionary).duplicate() if owned else {},
			"tag": "mine" if k == mine else ("owned" if owned else "shop")})
	return out


## placa embaixo do carro do menu: nota, nome, classe, situação (seu / na garagem / preço) e medidores
func _menu_car_info(e: Dictionary) -> void:
	if menu_car == null:
		return
	var k := String(e.kind)
	menu_car.text = String(Career.SHOP[k].name)
	menu_class.text = String(Career.SHOP[k].get("class", ""))
	match String(e.tag):
		"mine":
			menu_tag_icon.set_icon("star", UI.HOT)
			menu_tag.text = "SEU CARRO"
			menu_tag.add_theme_color_override("font_color", UI.HOT)
		"owned":
			menu_tag_icon.set_icon("check", UI.TEXT)
			menu_tag.text = "NA GARAGEM"
			menu_tag.add_theme_color_override("font_color", UI.TEXT)
		_:
			menu_tag_icon.set_icon("coin", UI.OK)
			menu_tag.text = garage_ui._money(int(Career.SHOP[k].price))
			menu_tag.add_theme_color_override("font_color", UI.OK)
	var base := Car.ratings(k, {}, String(Car.LOADOUT[k][0]))
	var cur := Car.ratings(k, e.up, String(e.front))
	for st in menu_bars:
		var sb: Garage.StatBar = menu_bars[st]
		sb.base = minf(float(base[st]), float(cur[st])) if String(e.front) != "none" or st != "atk" else 0.0
		sb.cur = float(cur[st])
		sb.prev = sb.cur
		sb.queue_redraw()
	menu_badge.set_meta("v", Car.overall(cur))
	menu_badge.queue_redraw()
	# a placa entra deslizando junto com o carro
	menu_info.modulate.a = 0.0
	var tw := menu_info.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(menu_info, "modulate:a", 1.0, 0.35)


## entrada do menu: logo e botões aparecem em sequência
func _menu_intro() -> void:
	var i := 0
	for nd in menu_anim:
		var c := nd as Control
		c.modulate.a = 0.0
		c.pivot_offset = Vector2(0, c.size.y * 0.5)
		c.scale = Vector2(0.9, 0.9)
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(0.05 * i)
		tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_delay(0.05 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1


func _sync_showroom() -> void:
	if show3d == null or game == null or game.career == null:
		return
	var on := cur_screen in ["menu", "garage"]
	show3d.activate(on)
	if on and not show3d.has_meta("warm"):
		show3d.set_meta("warm", true)
		show3d.prewarm()
	if not on:
		return
	if cur_screen == "garage":
		show3d.stop_parade()
		show3d.frame_off = Vector2(0.0, -0.07)
		show3d.size_k = 1.45
		show3d.auto_spin = true
		garage_ui.open()
	else:
		# menu: o seu carro girando à direita, sem painéis
		show3d.frame_off = Vector2(0.19, -0.05)
		show3d.size_k = 1.6
		show3d.auto_spin = true
		show3d.set_focus("")
		menu_cash.text = garage_ui._money(int(game.save.cash))
		show3d.start_parade(_parade_list())
		_menu_intro()


# ------------------------------------------------------------------ pausa e resultado
func _build_pause() -> void:
	pause_m = _screen(0.62)
	var v := _vcenter(pause_m, 12)
	UI.title(v, "PAUSA", 64, UI.HOT, HORIZONTAL_ALIGNMENT_CENTER)
	var cb := UI.icon_button("CONTINUAR", "play", true, 24, 340, 66)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cb.pressed.connect(func(): game.pause(false))
	v.add_child(cb)
	var sb := UI.icon_button("DIREÇÃO", "han", false, 18, 340, 54)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sb.pressed.connect(func(): game.toggle_steer())
	v.add_child(sb)
	steer_btns.append(sb)
	for it in [["REINICIAR", "flag", func(): game.start_race()], ["CONFIGURAÇÕES", "gear", func(): game.settings.open("pause")],
			["SAIR DA CORRIDA", "exit", func(): game.to_menu()]]:
		var b := UI.icon_button(it[0], it[1], false, 18, 340, 54)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(it[2])
		v.add_child(b)
	pause_extra = VBoxContainer.new()
	pause_extra.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(pause_extra)


func _build_results() -> void:
	results = _screen(0.7)
	var v := _vcenter(results, 16)
	res_title = UI.title(v, "", 72, UI.HOT, HORIZONTAL_ALIGNMENT_CENTER)
	# números da corrida em blocos (ícone + valor + rótulo curto)
	res_tiles = HBoxContainer.new()
	res_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	res_tiles.add_theme_constant_override("separation", 12)
	v.add_child(res_tiles)
	res_list = Label.new()
	res_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_list.add_theme_font_size_override("font_size", 20)
	res_list.add_theme_font_override("font", UI.body_bold)
	v.add_child(res_list)
	res_chips = HBoxContainer.new()
	res_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	res_chips.add_theme_constant_override("separation", 10)
	v.add_child(res_chips)
	var cr := HBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.add_theme_constant_override("separation", 10)
	v.add_child(cr)
	cr.add_child(Icon.make("coin", 40, UI.OK))
	res_cash = UI.title(cr, "", 40, UI.OK)
	res_total = UI.text(cr, "", 18, UI.MUTED)
	res_total.add_theme_font_override("font", UI.display_it)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var nb := UI.icon_button("PRÓXIMA", "play", true, 24, 280, 66)
	nb.pressed.connect(func(): game.next_track())
	row.add_child(nb)
	res_next = nb
	var gb := UI.icon_button("GARAGEM", "wrench", false, 18, 220, 58)
	gb.pressed.connect(func(): show_screen("garage"))
	row.add_child(gb)
	var rb := UI.icon_button("DE NOVO", "flag", false, 18, 220, 58)
	rb.pressed.connect(func(): game.start_race())
	row.add_child(rb)
	res_retry = rb


var res_next: Button
var res_retry: Button
var res_tiles: HBoxContainer
var res_chips: HBoxContainer
var res_total: Label


## resultado: blocos [ícone, valor, rótulo], frases da carreira viram selos, e o prêmio
func set_results(title: String, tiles: Array, chips: Array, prize: int, total: int) -> void:
	res_title.text = title
	for ch in res_tiles.get_children():
		ch.queue_free()
	for ch in res_chips.get_children():
		ch.queue_free()
	for t in tiles:
		var p := PanelContainer.new()
		var st := UI.box(Color(0.08, 0.07, 0.15, 0.9), Color(1, 1, 1, 0.1), 1, 0.1, 0, Color(0, 0, 0, 0), 8)
		st.content_margin_left = 16
		st.content_margin_right = 16
		st.content_margin_top = 10
		st.content_margin_bottom = 10
		p.add_theme_stylebox_override("panel", st)
		p.custom_minimum_size = Vector2(150, 0)
		res_tiles.add_child(p)
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 2)
		p.add_child(tv)
		var ic := Icon.make(String(t[0]), 30, UI.HOT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tv.add_child(ic)
		UI.title(tv, String(t[1]), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var l := UI.text(tv, String(t[2]), 12, UI.MUTED)
		l.add_theme_font_override("font", UI.body_bold)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in chips:
		var cp := PanelContainer.new()
		var cs := UI.box(Color(1, 0.7, 0.1, 0.16), UI.HOT, 2, 0.15, 0, Color(0, 0, 0, 0), 6)
		cs.content_margin_left = 14
		cs.content_margin_right = 14
		cs.content_margin_top = 6
		cs.content_margin_bottom = 6
		cp.add_theme_stylebox_override("panel", cs)
		res_chips.add_child(cp)
		var cl := UI.text(cp, String(c), 16, UI.TEXT)
		cl.add_theme_font_override("font", UI.display_it)
	res_cash.text = "+" + garage_ui._money(prize)
	res_total.text = "TOTAL " + garage_ui._money(total)


# ------------------------------------------------------------------ narrador: legenda animada
## Caixa no alto da tela (abaixo das barras): o rosto do DECIBEL (desenhado: cabeleira de roqueiro, bandana
## vermelha, óculos escuros, cavanhaque, jaqueta de couro com tachas e microfone na mão), o nome e a fala em
## português aparecendo letra a letra. A boca abre conforme o volume da voz (pico do barramento "Narrador")
## e a cabeça balança no ritmo.
const CAP_W := 560.0
const CAP_H := 74.0
var cap: Control
var cap_face: Control
var cap_name: Label
var cap_text: Label
var cap_who := "z"
var cap_life := 0.0
var cap_dur := 0.0
var cap_mouth := 0.0
var cap_blink := 0.0


func _build_caption() -> void:
	cap = Control.new()
	cap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# deslocamentos a partir da âncora (centro do topo), não posição absoluta
	cap.offset_left = -CAP_W * 0.5 + 20.0
	cap.offset_right = CAP_W * 0.5 + 20.0
	cap.offset_top = 80.0
	cap.offset_bottom = 80.0 + CAP_H
	cap.pivot_offset = Vector2(CAP_W * 0.5, CAP_H * 0.5)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.visible = false
	cap.draw.connect(_draw_cap_box)
	root.add_child(cap)
	cap_face = Control.new()
	cap_face.size = Vector2(86, 86)
	cap_face.position = Vector2(-30, -8)
	cap_face.pivot_offset = Vector2(43, 70)
	cap_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_face.draw.connect(_draw_cap_face)
	cap.add_child(cap_face)
	cap_name = UI.text(cap, "", 14, UI.HOT)
	cap_name.add_theme_font_override("font", UI.display_it)
	cap_name.position = Vector2(66, 5)
	cap_text = UI.text(cap, "", 17, UI.TEXT)
	cap_text.add_theme_font_override("font", UI.body_bold)
	cap_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap_text.position = Vector2(66, 24)
	cap_text.size = Vector2(CAP_W - 84, 48)
	cap_text.add_theme_constant_override("line_spacing", -4)


func caption(who: String, text: String, dur: float) -> void:
	if cap == null:
		return
	cap_who = who
	cap_dur = maxf(0.6, dur)
	cap_life = 0.0
	cap_name.text = "DECIBEL  ·  AO VIVO"
	cap_name.add_theme_color_override("font_color", UI.HOT)
	cap_text.text = text
	cap_text.visible_ratio = 0.0
	cap.visible = cur_screen in ["race", "results", "pause"] or cur_screen == "none"
	cap.modulate.a = 1.0
	cap.scale = Vector2(0.6, 0.6)
	cap.rotation = -0.05
	var tw := cap.create_tween().set_parallel()
	tw.tween_property(cap, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cap, "rotation", 0.0, 0.22)
	cap.queue_redraw()


func caption_hide() -> void:
	if cap:
		cap.visible = false
		cap_life = 99.0


func _step_caption(dt: float) -> void:
	if cap == null or not cap.visible:
		return
	cap_life += dt
	# letra a letra durante ~85% da fala
	cap_text.visible_ratio = clampf(cap_life / (cap_dur * 0.85), 0.0, 1.0)
	# boca no ritmo da voz
	var bi := AudioServer.get_bus_index("Narrador")
	var lv := 0.0
	if bi >= 0:
		lv = clampf((AudioServer.get_bus_peak_volume_left_db(bi, 0) + 38.0) / 30.0, 0.0, 1.0)
	cap_mouth = lerpf(cap_mouth, lv, minf(1.0, dt * 22.0))
	cap_blink = maxf(0.0, cap_blink - dt)
	if cap_blink <= 0.0 and randf() < dt * 0.6:
		cap_blink = 0.12
	# cabeça balança falando; some 0,6 s depois da fala
	cap_face.rotation = sin(t * 9.0) * 0.06 * cap_mouth + sin(t * 2.1) * 0.03
	cap_face.position.y = -8.0 - cap_mouth * 3.0
	if cap_life > cap_dur + 0.6:
		cap.modulate.a = maxf(0.0, cap.modulate.a - dt * 4.0)
		if cap.modulate.a <= 0.0:
			cap.visible = false
	cap_face.queue_redraw()


func _draw_cap_box() -> void:
	var col := UI.HOT
	var sk := 10.0
	var pts := PackedVector2Array([Vector2(sk, 0), Vector2(CAP_W, 0), Vector2(CAP_W - sk, CAP_H), Vector2(0, CAP_H)])
	cap.draw_colored_polygon(PackedVector2Array([Vector2(sk + 4, 5), Vector2(CAP_W + 4, 5), Vector2(CAP_W - sk + 4, CAP_H + 5), Vector2(4, CAP_H + 5)]), Color(0, 0, 0, 0.35))
	cap.draw_colored_polygon(pts, Color(0.06, 0.05, 0.11, 0.9))
	cap.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 2.5)
	cap.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(sk + 8, 0), Vector2(8, CAP_H), Vector2(0, CAP_H)]), col)


func _draw_cap_face() -> void:
	var c := Vector2(43, 44)
	var ci := cap_face
	ci.draw_circle(c, 38.0, UI.HOT)
	ci.draw_circle(c, 34.0, Color(0.12, 0.08, 0.14))
	var hair := Color("#1c1414")
	var skin := Color("#e7a982")
	# cabeleira de roqueiro (atrás do rosto, caindo nos ombros)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-25, -6), c + Vector2(-22, -24), c + Vector2(0, -30), c + Vector2(22, -24),
		c + Vector2(26, -4), c + Vector2(28, 24), c + Vector2(19, 32), c + Vector2(-19, 32), c + Vector2(-28, 24)]), hair)
	# jaqueta de couro com gola e tachas
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-30, 46), c + Vector2(-24, 30), c + Vector2(-8, 26), c + Vector2(0, 36), c + Vector2(8, 26), c + Vector2(24, 30), c + Vector2(30, 46)]), Color("#141018"))
	for sx: float in [-17.0, -11.0, 11.0, 17.0]:
		ci.draw_circle(c + Vector2(sx, 34), 1.6, Color(0.85, 0.86, 0.9))
	# rosto
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, 2), 18.0, 21.0), skin)
	# bandana vermelha com o nó do lado
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-19, -9), c + Vector2(-17, -17), c + Vector2(0, -21), c + Vector2(17, -17), c + Vector2(19, -9), c + Vector2(0, -13)]), Color("#d7263d"))
	ci.draw_circle(c + Vector2(-8, -15), 1.4, Color(1, 1, 1, 0.8))
	ci.draw_circle(c + Vector2(7, -16), 1.4, Color(1, 1, 1, 0.8))
	var sw := sin(t * 7.0) * 2.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(17, -14), c + Vector2(27, -10 + sw), c + Vector2(25, -6 + sw), c + Vector2(17, -10)]), Color("#b81d31"))
	# óculos escuros de aviador com brilho
	for sx: float in [-8.0, 8.0]:
		ci.draw_colored_polygon(_ellipse(c + Vector2(sx, -3), 7.0, 5.0), Color(0.05, 0.04, 0.07))
	ci.draw_line(c + Vector2(-1, -5), c + Vector2(1, -5), Color(0.6, 0.6, 0.65), 1.5)
	ci.draw_line(c + Vector2(-12, -5), c + Vector2(-8, -6), Color(1, 1, 1, 0.75), 1.5)
	ci.draw_line(c + Vector2(4, -5), c + Vector2(8, -6), Color(1, 1, 1, 0.5), 1.2)
	# bocão de roqueiro gritando: lábios, dentes, língua; cavanhaque embaixo
	var mouth_h := 2.0 + cap_mouth * 13.0
	var m0 := c + Vector2(0, 11)
	ci.draw_colored_polygon(_ellipse(m0, 7.5 + cap_mouth * 2.0, mouth_h * 0.5 + 1.0), Color("#4a0f12"))
	if mouth_h > 4.0:
		ci.draw_rect(Rect2(m0 + Vector2(-6, -mouth_h * 0.5), Vector2(12, minf(3.0, mouth_h * 0.28))), Color.WHITE)
		ci.draw_colored_polygon(_ellipse(m0 + Vector2(0, mouth_h * 0.28), 4.5, mouth_h * 0.2), Color("#d9586a"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 13 + mouth_h * 0.5), c + Vector2(5, 13 + mouth_h * 0.5), c + Vector2(2, 23 + mouth_h * 0.3), c + Vector2(-2, 23 + mouth_h * 0.3)]), hair)
	# brinco de raio
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-19, 6), c + Vector2(-17, 6), c + Vector2(-19, 10), c + Vector2(-17, 10), c + Vector2(-21, 15), c + Vector2(-20, 10), c + Vector2(-22, 10)]), Color("#ffcf33"))
	# microfone na mão, na frente da boca
	var mc := c + Vector2(15, 22)
	ci.draw_line(mc, mc + Vector2(8, 16), Color(0.12, 0.12, 0.14), 5.0)
	ci.draw_circle(mc, 5.5, Color(0.55, 0.56, 0.6))
	ci.draw_circle(mc, 4.0, Color(0.32, 0.33, 0.37))
	ci.draw_circle(mc + Vector2(-1.5, -1.5), 1.3, Color(1, 1, 1, 0.6))


static func _ellipse(c: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p
