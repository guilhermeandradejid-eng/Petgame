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
var cash_l: Label
var g_title: Label
var g_boxes := {}
var g_up := {}
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
	if name_ == "garage":
		refresh_garage()
	if extra_screens.has(name_) or name_ in ["menu", "tracks", "garage", "pause", "results"]:
		_focus_first.call_deferred(name_)
	for k in extra_screens:
		(extra_screens[k] as Control).visible = k == name_
	cur_screen = name_


## controle/teclado no menu: o primeiro botão da tela recebe o foco (navega com direcional e confirma com A)
func _focus_first(name_: String) -> void:
	var scr: Control = extra_screens.get(name_, {"menu": menu, "tracks": tracks_s, "garage": garage, "pause": pause_m, "results": results}.get(name_))
	if scr == null or not scr.visible:
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
	_text(status, {"jump": "SALTO", "shield": "ESCUDO", "shock": "CHOQUE"}.get(p.special_type, "NITRO"), Vector2(0, y + 15), 13, false)
	for i in p.nitro_cap:
		var r := Rect2(62 + i * 30, y, 24, 18)
		var full := i < p.nitro_ch
		var col := Color("#2ee6ff") if full else Color(0.1, 0.08, 0.2, 0.9)
		if p.nitroing and i == p.nitro_ch:
			col = Color.WHITE
		status.draw_rect(r.grow(2), Color(1, 1, 1, 0.7), true)
		status.draw_rect(r, col, true)
	status.draw_rect(Rect2(62, y + 22, 30 * p.nitro_cap - 6, 4), Color(0.1, 0.08, 0.2, 0.9), true)
	status.draw_rect(Rect2(62, y + 22, (30 * p.nitro_cap - 6) * p.nitro_meter, 4), Color("#b4f6ff"), true)
	# armas
	var fa := "%s %d" % [{"mg": "MG", "rocket": "FOGUETE x", "zap": "RAIO x", "flame": "FOGO"}.get(p.front_type, "MG"), p.ammo_f]
	var ra := "%s x%d" % [{"mine": "MINA", "oil": "ÓLEO", "spikes": "PREGOS", "barrel": "BARRIL"}.get(p.rear_type, "MINA"), p.ammo_r]
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
	menu = _screen(0.55)
	# navegação vertical à esquerda (mesma posição em todas as telas); a pista passa ao fundo, à direita
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 64)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 34)
	menu.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var logo := UI.title(v, "MINI", 72, UI.TEXT)
	logo.label_settings.shadow_color = UI.BAD
	var logo2 := UI.title(v, "FÚRIA", 92, UI.HOT)
	logo.add_theme_constant_override("line_spacing", -14)
	UI.checker(v, 330, 12)
	var tag := UI.text(v, "6 MUNDOS  ·  26 PISTAS  ·  6 CHEFES  ·  ATÉ 8 ONLINE", 16, UI.INFO, true)
	tag.add_theme_font_override("font", UI.body_bold)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var items := [["CARREIRA", true, func(): game.career.open()],
		["CORRIDA RÁPIDA", false, func(): game.set_solo(); game.career.event = {}; show_screen("tracks")],
		["MULTIJOGADOR LOCAL", false, func(): game.multi.open_join()],
		["ONLINE", false, func(): game.online.open()],
		["CONFIGURAÇÕES", false, func(): game.settings.open("menu")]]
	if OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD"]:
		items.append(["SAIR", false, func(): get_tree().quit()])
	var k := 0
	for it in items:
		var b := _btn(it[0], v, it[1], 380 - k * 6, 60 if it[1] else 50)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(it[2])
		k += 1
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp2)
	var info := UI.text(v, "Teclado: setas/WASD dirigem · B freio · Z tiro · X mina · SHIFT nitro · R volta à pista\nControle: analógico dirige · A acelera · B freio · X tiro · Y mina · RB nitro · START pausa", 14, UI.MUTED)
	info.modulate = Color(1, 1, 1, 0.85)


# ------------------------------------------------------------------ seleção de pista
func _build_tracks() -> void:
	tracks_s = _screen(0.72)
	var v := _vcenter(tracks_s, 12)
	var tl := _label(44, Color("#ffcf33"), Color("#c74200"), v)
	tl.text = "ESCOLHA A PISTA"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.label_settings.font_color = UI.HOT
	tl.label_settings.outline_color = UI.INK
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.name = "Grid"
	v.add_child(grid)
	for i in TrackData.TRACKS.size():
		var d: Dictionary = TrackData.TRACKS[i]
		var th: Dictionary = TrackData.THEMES[d.theme]
		var b := Button.new()
		b.custom_minimum_size = Vector2(168, 96)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_font_override("font", UI.display_it)
		var c1 := Color(th.sky_hor).darkened(0.45).lerp(UI.INK2, 0.35)
		var sb := UI.box(c1, Color(th.curb[0]), 3, 0.12, 6, Color(0, 0, 0, 0.5), 8)
		sb.border_width_left = 8
		var sh := UI.box(c1.lightened(0.15), Color.WHITE, 4, 0.12, 6, Color.WHITE, 8)
		sh.border_width_left = 10
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("focus", sh)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color.WHITE)
		b.add_theme_constant_override("outline_size", 6)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		b.pressed.connect(func(): game.choose_track(i))
		b.set_meta("idx", i)
		grid.add_child(b)
	_btn("VOLTAR", v, false, 220, 52).pressed.connect(func(): show_screen("menu"))


func _refresh_tracks() -> void:
	var grid := tracks_s.find_child("Grid", true, false)
	for b in grid.get_children():
		var i: int = b.get_meta("idx")
		var d: Dictionary = TrackData.TRACKS[i]
		var th: Dictionary = TrackData.THEMES[d.theme]
		var feats: Array = []
		for f in d.feat.values():
			var nm := {"loop": "LOOP", "jump": "SALTO", "cork": "TORÇÃO", "helix": "ESPIRAL"}[f[0]] as String
			if not feats.has(nm):
				feats.append(nm)
		if d.traffic > 0:
			feats.append("TRÁFEGO")
		var best: Dictionary = game.save.best.get(str(i), {})
		var medal := ""
		if best.has("place"):
			medal = "  [%dº]" % int(best.place)
		b.text = "%s\n%s%s\n%s" % [String(d.name).to_upper(), th.label.to_upper() + (" · EXTRA" if i >= 24 else ""), medal, " · ".join(feats) if feats.size() > 0 else "CIRCUITO"]


# ------------------------------------------------------------------ garagem
const UP_NAMES := {"engine": "MOTOR", "armor": "BLINDAGEM", "ammo": "ARMA DA FRENTE", "rear": "ARMA DE TRÁS", "nitro": "ESPECIAL +1", "tires": "PNEUS"}
var g_weap: Label
var boss_bar: Control


func _build_garage() -> void:
	garage = _screen(0.82)
	var v := _vcenter(garage, 10)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 40)
	v.add_child(top)
	g_title = _label(34, Color("#ffcf33"), Color("#c74200"), top)
	cash_l = _label(30, Color("#7dff6a"), Color(0, 0, 0, 0.6), top)
	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 16)
	v.add_child(cols)
	var c1 := _panel(cols, "CARROS")
	for k in ["faisca", "vespa", "trovao", "monstro"]:
		_choice(c1, "car", k, 62)
	var c2 := _panel(cols, "ARMAS DO CARRO")
	g_weap = UI.text(c2, "", 15, UI.TEXT)
	g_weap.add_theme_font_override("font", UI.body_bold)
	g_weap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_weap.custom_minimum_size = Vector2(300, 0)
	var c3 := _panel(cols, "UPGRADES DO CARRO")
	for k in ["engine", "armor", "tires", "ammo", "rear", "nitro"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c3.add_child(row)
		var l := Label.new()
		l.custom_minimum_size = Vector2(190, 0)
		l.add_theme_font_size_override("font_size", 15)
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 48)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_font_override("font", UI.display_it)
		b.add_theme_stylebox_override("normal", UI.box(Color("#1f8a3a"), Color(0, 0, 0, 0), 0, UI.SKEW, 4, Color("#0d4a1c"), 4))
		b.add_theme_stylebox_override("hover", UI.box(Color("#2fb04f"), Color.WHITE, 2, UI.SKEW, 4, Color.WHITE, 4))
		b.add_theme_stylebox_override("focus", UI.box(Color("#2fb04f"), Color.WHITE, 2, UI.SKEW, 4, Color.WHITE, 4))
		b.add_theme_stylebox_override("pressed", UI.box(Color("#2fb04f"), Color.WHITE, 2, UI.SKEW, 1, Color.WHITE, 4))
		b.add_theme_stylebox_override("disabled", UI.box(Color(1, 1, 1, 0.06), UI.LINE, 1, UI.SKEW, 2, Color.BLACK, 4))
		l.add_theme_font_override("font", UI.body_bold)
		l.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): game.buy_upgrade(k))
		row.add_child(b)
		g_up[k] = {"label": l, "btn": b}
	var hint := Label.new()
	hint.custom_minimum_size = Vector2(320, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_override("font", SystemFont.new())
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.text = "Pneus: rua > esportivo > slick (+6% de aderência por nível). Munição e nitro recarregam a cada volta."
	c3.add_child(hint)
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_theme_constant_override("separation", 20)
	v.add_child(bot)
	_btn("VOLTAR", bot, false, 200, 56).pressed.connect(func(): show_screen("tracks"))
	var gsb := _btn("DIREÇÃO", bot, false, 330, 56)
	gsb.pressed.connect(func(): game.toggle_steer())
	steer_btns.append(gsb)
	_btn("LARGAR!", bot, true, 280, 64).pressed.connect(func(): game.start_race())


func _panel(parent: Node, title: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_box(UI.HOT))
	pc.custom_minimum_size = Vector2(340, 0)
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var l := UI.title(v, title, 20, UI.INFO)
	l.label_settings.outline_size = 3
	return v


func _choice(parent: Node, slot: String, key: String, h: int) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(310, h)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", UI.body_bold)
	b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.06), UI.LINE, 1, 0.1, 0, Color.BLACK, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.14), Color.WHITE, 2, 0.1, 0, Color.BLACK, 6))
	b.add_theme_stylebox_override("focus", UI.box(Color(1, 1, 1, 0.14), Color.WHITE, 2, 0.1, 0, Color.BLACK, 6))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.18), UI.HOT, 2, 0.1, 0, Color.BLACK, 6))
	b.pressed.connect(func(): game.equip(slot, key))
	parent.add_child(b)
	g_boxes[slot + ":" + key] = b


func _bar(v: float) -> String:
	return "%d/5" % clampi(int(round(v * 5.0)), 1, 5)


func refresh_garage() -> void:
	var s: Dictionary = game.save
	var d: Dictionary = TrackData.TRACKS[game.track_idx]
	g_title.text = "GARAGEM · " + String(d.name).to_upper()
	cash_l.text = "$ %d" % int(s.cash)
	var names := {"faisca": "FAÍSCA", "trovao": "TROVÃO", "vespa": "VESPA"}
	for key in g_boxes:
		var b: Button = g_boxes[key]
		var parts: PackedStringArray = key.split(":")
		var slot := parts[0]
		var k := parts[1]
		var on: bool = s[slot] == k
		var txt := ""
		match slot:
			"car":
				var sp: Dictionary = Car.SPECS[k]
				var shop: Dictionary = Career.SHOP[k]
				var tag := ""
				if not game.career.owned(k):
					tag = "   [$%d]" % int(shop.price) if game.career.available(k) else "   [MUNDO %d]" % (int(shop.world) + 1)
				txt = "%s%s\nVEL %s  BLIND %s  CONTROLE %s" % [shop.name, tag, _bar((sp.vmax - 34.0) / 10.0), _bar(sp.hp / 175.0), _bar((sp.turn - 2.0) / 1.1)]
				b.disabled = not game.career.owned(k) and not game.career.available(k)
			"front":
				txt = "FRENTE: %s (%d por volta)" % [String(Car.FRONT[k].name).to_upper(), int(Car.FRONT[k].cap)]
			"rear":
				txt = "TRÁS: %s (%d por volta)" % [String(Car.REAR[k].name).to_upper(), int(Car.REAR[k].cap)]
			"nitro":
				txt = "%s (%d x %.1fs)" % [String(Car.NITRO[k].name).to_upper(), int(Car.NITRO[k].cap), float(Car.NITRO[k].dur)]
		b.text = ("> " if on else "   ") + txt
		var col := UI.HOT if on else Color(1, 1, 1, 0.06)
		b.add_theme_stylebox_override("normal", UI.box(col, Color.WHITE if on else UI.LINE, 2 if on else 1, 0.1, 3 if on else 0, UI.HOT_DARK, 6))
		b.add_theme_color_override("font_color", UI.INK if on else UI.TEXT)
		b.add_theme_color_override("font_hover_color", UI.TEXT)
	var lo: Array = Car.LOADOUT[String(s.car)]
	var sn: String = Car.SPECIAL[lo[2]].name if Car.SPECIAL.has(lo[2]) else "Nitro"
	g_weap.text = "%s\n%s\n\nFRENTE · %s\n%s\n\nTRÁS · %s\n%s\n\nESPECIAL · %s\n%s" % [Career.SHOP[s.car].name, Career.SHOP[s.car].desc,
		String(Car.FRONT[lo[0]].name).to_upper(), Career.WEAPON_DESC[lo[0]], String(Car.REAR[lo[1]].name).to_upper(), Career.WEAPON_DESC[lo[1]],
		sn.to_upper(), Career.WEAPON_DESC[lo[2]]]
	if game.career.active():
		var ev: Dictionary = game.career.event
		g_title.text = ("CHEFE · " if ev.boss else "MUNDO %d · " % (int(ev.world) + 1)) + String(d.name).to_upper()
	for k in g_up:
		var lvl: int = s.up.get(k, 0)
		var row: Dictionary = g_up[k]
		(row.label as Label).text = "%s  NV %d/3" % [UP_NAMES[k], lvl]
		var b: Button = row.btn
		if lvl >= 3:
			b.text = "MÁX"
			b.disabled = true
		else:
			var price: int = game.upgrade_price(k)
			b.text = "$ %d" % price
			b.disabled = int(s.cash) < price


# ------------------------------------------------------------------ pausa e resultado
func _build_pause() -> void:
	pause_m = _screen(0.62)
	var v := _vcenter(pause_m)
	var pt := _label(64, Color("#ffcf33"), Color("#c74200"), v)
	pt.text = "PAUSA"
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn("CONTINUAR", v).pressed.connect(func(): game.pause(false))
	var sb := _btn("DIREÇÃO", v, false)
	sb.pressed.connect(func(): game.toggle_steer())
	steer_btns.append(sb)
	_btn("REINICIAR", v, false).pressed.connect(func(): game.start_race())
	_btn("CONFIGURAÇÕES", v, false).pressed.connect(func(): game.settings.open("pause"))
	_btn("SAIR DA CORRIDA", v, false).pressed.connect(func(): game.to_menu())
	pause_extra = VBoxContainer.new()
	pause_extra.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(pause_extra)


func _build_results() -> void:
	results = _screen(0.7)
	var v := _vcenter(results)
	res_title = _label(64, Color("#ffcf33"), Color("#c74200"), v)
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_list = Label.new()
	res_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_list.add_theme_font_size_override("font_size", 20)
	res_list.add_theme_font_override("font", UI.body_bold)
	v.add_child(res_list)
	res_cash = _label(30, Color("#7dff6a"), Color(0, 0, 0, 0.6), v)
	res_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_btn("PRÓXIMA PISTA", row, true, 300, 64).pressed.connect(func(): game.next_track())
	_btn("GARAGEM", row, false, 200, 56).pressed.connect(func(): show_screen("garage"))
	_btn("CORRER DE NOVO", row, false, 240, 56).pressed.connect(func(): game.start_race())
