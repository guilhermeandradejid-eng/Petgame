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
	touch.visible = name_ == "race" and not touch.get_meta("split_hide", false)
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
	var stack: Array = [scr]
	while stack.size() > 0:
		var nd: Node = stack.pop_front()
		if nd is BaseButton and (nd as Control).is_visible_in_tree() and (nd as Control).focus_mode != Control.FOCUS_NONE and not (nd as BaseButton).disabled:
			(nd as Control).grab_focus()
			return
		stack.append_array(nd.get_children())


# ------------------------------------------------------------------ HUD da corrida
func _build_race_hud() -> void:
	pos_l = _label(52, Color.WHITE, Color("#ff2d55"))
	pos_l.position = Vector2(18, 6)
	lap_l = _label(17, Color("#ffcf33"), Color(0, 0, 0, 0.6))
	lap_l.position = Vector2(110, 14)
	time_l = _label(22, Color.WHITE, Color(0, 0, 0, 0.6))
	time_l.position = Vector2(110, 36)
	score_l = _label(16, Color("#7dff6a"), Color(0, 0, 0, 0.6))
	score_l.position = Vector2(110, 64)
	status = Control.new()
	status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status.position = Vector2(-230, 8)
	status.size = Vector2(460, 84)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.draw.connect(_draw_status)
	root.add_child(status)
	onc_l = _label(15, Color.WHITE, Color("#ff2d55"))
	onc_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	onc_l.position = Vector2(-70, 96)
	onc_l.text = "CONTRAMÃO!"
	onc_l.modulate.a = 0.0
	speed_l = _label(30, Color.WHITE, Color(0, 0, 0, 0.6))
	speed_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	speed_l.position = Vector2(18, -54)
	pops = VBoxContainer.new()
	pops.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pops.position = Vector2(-250, 118)
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
	minimap.position = Vector2(-196, 8)
	minimap.size = Vector2(128, 128)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	root.add_child(minimap)
	boss_bar = Control.new()
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_bar.position = Vector2(-300, -84)
	boss_bar.size = Vector2(600, 60)
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
	btns.position = Vector2(-62, 8)
	root.add_child(btns)
	mute_b = _small_btn("SOM", btns)
	mute_b.pressed.connect(func(): game.toggle_mute())
	var pb := _small_btn("II", btns)
	pb.pressed.connect(func(): game.pause(true))
	touch = TouchPad.new()
	touch.font = font
	root.add_child(touch)
	race_nodes = [pos_l, lap_l, time_l, score_l, status, onc_l, speed_l, minimap, feed, btns]


func _small_btn(txt: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(52, 44)
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	var sb := _sb(Color(0.1, 0.08, 0.2, 0.6), 12)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	parent.add_child(b)
	return b


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
	var sk := 14.0
	boss_bar.draw_string_outline(UI.display_it, Vector2(sk, 20), b.display_name + ("  · DESTRUÍDO" if b.wrecked else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, UI.INK)
	boss_bar.draw_string(UI.display_it, Vector2(sk, 20), b.display_name + ("  · DESTRUÍDO" if b.wrecked else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.BAD)
	boss_bar.draw_colored_polygon(PackedVector2Array([Vector2(sk, 28), Vector2(W, 28), Vector2(W - sk, 50), Vector2(0, 50)]), Color(0, 0, 0, 0.6))
	if u > 0.0:
		boss_bar.draw_colored_polygon(PackedVector2Array([Vector2(sk + 3, 31), Vector2(sk + 3 + (W - sk - 6) * u, 31), Vector2((W - sk - 6) * u, 47), Vector2(3, 47)]), UI.BAD.lerp(UI.HOT, 1.0 - u))


func _draw_status() -> void:
	if player == null:
		return
	var p := player
	var w := status.size.x
	# vida
	var hr := clampf(p.health / p.max_health, 0.0, 1.0)
	var hb := Rect2(0, 0, w, 22)
	status.draw_rect(hb.grow(3), Color(1, 1, 1, 0.85), true)
	status.draw_rect(hb, Color(0.1, 0.08, 0.2, 0.95), true)
	var hc := Color("#ff3048").lerp(Color("#5dff6a"), hr)
	if hr < 0.3 and int(t * 6.0) % 2 == 0:
		hc = Color.WHITE
	status.draw_rect(Rect2(0, 0, w * hr, 22), hc, true)
	_text(status, "BLINDAGEM", Vector2(w * 0.5, 17), 13, true)
	# nitro (cargas) + medidor de manobras
	var y := 32.0
	_text(status, String(Car.NITRO[p.nitro_type].label), Vector2(0, y + 15), 13, false)
	for i in p.nitro_cap:
		var r := Rect2(82 + i * 30, y, 24, 18)
		var full := i < p.nitro_ch
		var col := Color("#2ee6ff") if full else Color(0.1, 0.08, 0.2, 0.9)
		if p.nitroing and i == p.nitro_ch:
			col = Color.WHITE
		status.draw_rect(r.grow(2), Color(1, 1, 1, 0.7), true)
		status.draw_rect(r, col, true)
	status.draw_rect(Rect2(82, y + 22, 30 * p.nitro_cap - 6, 4), Color(0.1, 0.08, 0.2, 0.9), true)
	status.draw_rect(Rect2(82, y + 22, (30 * p.nitro_cap - 6) * p.nitro_meter, 4), Color("#b4f6ff"), true)
	# especial comprado (botão próprio): cargas verdes
	if p.special_type != "":
		var sy := y + 32.0
		_text(status, String(Car.SPECIAL[p.special_type].label), Vector2(0, sy + 13), 12, false, false, Color("#9dffb0"))
		for i in p.spec_cap:
			var r := Rect2(82 + i * 30, sy, 24, 14)
			status.draw_rect(r.grow(2), Color(1, 1, 1, 0.7), true)
			status.draw_rect(r, Color("#5dff6a") if i < p.spec_ch else Color(0.1, 0.08, 0.2, 0.9), true)
	# armas
	var fa := "%s %d" % [String(Car.LBL_F.get(p.front_type, "MG")), p.ammo_f]
	if p.front_type == "none":
		fa = "SEM ARMA"
	var ra := "%s x%d" % [String(Car.LBL_R.get(p.rear_type, "MINA")), p.ammo_r]
	_text(status, fa, Vector2(w - 4, y + 15), 15, false, true, Color("#ffb08a") if p.ammo_f > 0 else Color(1, 1, 1, 0.35))
	_text(status, ra, Vector2(w - 4, y + 38), 13, false, true, Color("#ffe27a") if p.ammo_r > 0 else Color(1, 1, 1, 0.35))


func _text(c: Control, s: String, pos: Vector2, fs: int, center: bool, right := false, col := Color.WHITE) -> void:
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
	_mm_sc = minf((s.x - 16) / (mx.x - mn.x), (s.y - 16) / (mx.y - mn.y))
	_mm_o = s * 0.5 - (mn + mx) * 0.5 * _mm_sc
	for p in raw:
		_mm_pts.append(p * _mm_sc + _mm_o)


func _draw_minimap() -> void:
	if track == null or _mm_pts.size() < 2:
		return
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0.1, 0.08, 0.2, 0.4), true)
	minimap.draw_polyline(_mm_pts, Color(0.1, 0.1, 0.2, 0.6), 8.0, true)
	minimap.draw_polyline(_mm_pts, Color(0.95, 0.94, 1.0), 4.0, true)
	for c in cars:
		if c.wrecked:
			continue
		var p := _rot(Vector2(c.global_position.x, c.global_position.z)) * _mm_sc + _mm_o
		if c.role == "traffic":
			minimap.draw_circle(p, 2.0, Color(0.4, 0.4, 0.5, 0.7))
		elif c.role == "rival":
			minimap.draw_circle(p, 4.5, c.color)
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
	var logo := UI.title(v, "MINI", 72, UI.TEXT)
	logo.label_settings.shadow_color = UI.BAD
	logo.add_theme_constant_override("line_spacing", -14)
	UI.title(v, "FÚRIA", 96, UI.HOT)
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
	menu_class = UI.text(nv, "", 14, UI.INFO, true)
	menu_class.add_theme_font_override("font", UI.body_bold)
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
var menu_car: Label
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
		var k := String(game.save.car)
		menu_cash.text = garage_ui._money(int(game.save.cash))
		menu_car.text = String(Career.SHOP[k].name)
		menu_class.text = String(Career.SHOP[k].get("class", ""))
		var kit: Array = game.career.loadout(k)
		var base := Car.ratings(k, {}, String(Car.LOADOUT[k][0]))
		var cur := Car.ratings(k, game.save.up, String(kit[0]))
		for st in menu_bars:
			var sb: Garage.StatBar = menu_bars[st]
			sb.base = minf(float(base[st]), float(cur[st])) if String(kit[0]) != "none" or st != "atk" else 0.0
			sb.cur = float(cur[st])
			sb.prev = sb.cur
			sb.queue_redraw()
		menu_badge.set_meta("v", Car.overall(cur))
		menu_badge.queue_redraw()
		show3d.show_car(k, Color(String(game.save.get("color", game.PAINT_COLORS[0]))), kit[0], kit[1], kit[2], game.save.up, kit[3])


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
	var gb := UI.icon_button("GARAGEM", "wrench", false, 18, 220, 58)
	gb.pressed.connect(func(): show_screen("garage"))
	row.add_child(gb)
	var rb := UI.icon_button("DE NOVO", "flag", false, 18, 220, 58)
	rb.pressed.connect(func(): game.start_race())
	row.add_child(rb)


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
