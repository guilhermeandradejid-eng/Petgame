class_name Hud
extends CanvasLayer
## HUD, menus, popups e pós-processamento de tela.

signal play_pressed
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal mute_pressed

var font: Font
var post: ColorRect
var post_mat: ShaderMaterial
var root: Control
var pos_l: Label
var lap_l: Label
var time_l: Label
var score_l: Label
var td_l: Label
var speed_l: Label
var onc_l: Label
var big_l: Label
var pops: VBoxContainer
var bar: Control
var minimap: Control
var touch: TouchPad
var menu: Control
var pause_m: Control
var results: Control
var res_title: Label
var res_list: Label
var mute_b: Button
var nitro := 0.0
var nitro_on := false
var t := 0.0
var track: Track
var cars: Array = []
var player: Car


func _init() -> void:
	layer = 5


func _ready() -> void:
	font = load("res://fonts/Bungee.woff2")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 22

	# camada do pós-processamento, abaixo do HUD
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	post.material = post_mat
	pl.add_child(post)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = th
	add_child(root)

	pos_l = _label(54, Color.WHITE, Color("#ff2d55"))
	pos_l.position = Vector2(18, 8)
	lap_l = _label(18, Color("#ffcf33"), Color(0, 0, 0, 0.6))
	lap_l.position = Vector2(110, 18)
	time_l = _label(24, Color.WHITE, Color(0, 0, 0, 0.6))
	time_l.position = Vector2(110, 40)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 4)
	top.position = Vector2(-170, 10)
	top.custom_minimum_size = Vector2(340, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(srow)
	score_l = _label(24, Color.WHITE, Color(0, 0, 0, 0.6), srow)
	td_l = _label(18, Color("#ff7a9a"), Color(0, 0, 0, 0.6), srow)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(340, 26)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	top.add_child(bar)
	onc_l = _label(16, Color.WHITE, Color("#ff2d55"), top)
	onc_l.text = "CONTRAMÃO!"
	onc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onc_l.modulate.a = 0.0

	speed_l = _label(40, Color.WHITE, Color(0, 0, 0, 0.6))
	speed_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_l.position = Vector2(-100, -70)
	speed_l.size = Vector2(200, 60)

	pops = VBoxContainer.new()
	pops.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pops.position = Vector2(-250, 96)
	pops.custom_minimum_size = Vector2(500, 0)
	pops.alignment = BoxContainer.ALIGNMENT_BEGIN
	pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pops)

	big_l = _label(96, Color.WHITE, Color("#ff2d55"))
	big_l.set_anchors_preset(Control.PRESET_CENTER)
	big_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_l.size = Vector2(1000, 160)
	big_l.position = Vector2(-500, -150)
	big_l.pivot_offset = Vector2(500, 80)
	big_l.modulate.a = 0.0

	minimap = Control.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-200, 10)
	minimap.size = Vector2(130, 130)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	root.add_child(minimap)

	var btns := VBoxContainer.new()
	btns.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btns.position = Vector2(-62, 10)
	root.add_child(btns)
	mute_b = _small_btn("SOM", btns)
	mute_b.pressed.connect(func(): mute_pressed.emit())
	var pb := _small_btn("II", btns)
	pb.pressed.connect(func(): pause_pressed.emit())

	touch = TouchPad.new()
	root.add_child(touch)

	menu = _screen()
	var logo := _label(110, Color.WHITE, Color("#ff2d55"), menu.get_child(0))
	logo.text = "MINI"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var logo2 := _label(110, Color("#ffcf33"), Color("#ff6a1a"), menu.get_child(0))
	logo2.text = "FÚRIA"
	logo2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tag := _label(16, Color("#2ee6ff"), Color(0, 0, 0, 0.5), menu.get_child(0))
	tag.text = "FASE DE TESTE · CIRCUITO DO PARQUE"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play := _big_btn("CORRER", menu.get_child(0))
	play.pressed.connect(func(): play_pressed.emit())
	var info := Label.new()
	info.text = "Bata nos rivais para TAKEDOWN · Nitro enche com drift, quase-batidas, contramão e pulos\nBater de frente destrói o carro!\nTeclado: setas/WASD · ESPAÇO drift · SHIFT nitro · R volta à pista · P pausa"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_override("font", SystemFont.new())
	info.add_theme_font_size_override("font_size", 16)
	info.modulate = Color(1, 1, 1, 0.8)
	menu.get_child(0).add_child(info)

	pause_m = _screen()
	var pt := _label(64, Color("#ffcf33"), Color("#c74200"), pause_m.get_child(0))
	pt.text = "PAUSA"
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_btn("CONTINUAR", pause_m.get_child(0)).pressed.connect(func(): resume_pressed.emit())
	_big_btn("REINICIAR", pause_m.get_child(0)).pressed.connect(func(): restart_pressed.emit())
	pause_m.visible = false

	results = _screen()
	res_title = _label(64, Color("#ffcf33"), Color("#c74200"), results.get_child(0))
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_list = Label.new()
	res_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_list.add_theme_font_size_override("font_size", 20)
	results.get_child(0).add_child(res_list)
	_big_btn("CORRER DE NOVO", results.get_child(0)).pressed.connect(func(): restart_pressed.emit())
	_big_btn("MENU", results.get_child(0)).pressed.connect(func(): menu_pressed.emit())
	results.visible = false
	set_race_hud(false)


func _label(fs: int, col: Color, outline: Color, parent: Node = null) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = fs
	ls.font_color = col
	ls.outline_size = maxi(4, fs / 6)
	ls.outline_color = outline
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(0, fs * 0.06)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else root).add_child(l)
	return l


func _screen() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.2, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	bg.add_child(v)
	return bg


func _big_btn(txt: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(320, 74)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ffcf33")
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.shadow_color = Color("#c77a00")
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 1
	var sh := sb.duplicate() as StyleBoxFlat
	sh.bg_color = Color("#fff27a")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", sh)
	b.add_theme_color_override("font_color", Color("#1b1530"))
	b.add_theme_color_override("font_hover_color", Color("#1b1530"))
	b.add_theme_color_override("font_pressed_color", Color("#1b1530"))
	b.add_theme_color_override("font_focus_color", Color("#1b1530"))
	parent.add_child(b)
	return b


func _small_btn(txt: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(52, 44)
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.2, 0.6)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	parent.add_child(b)
	return b


func set_race_hud(on: bool) -> void:
	for n in [pos_l, lap_l, time_l, score_l, td_l, bar, speed_l, minimap, onc_l]:
		n.visible = on
	touch.visible = on


# ------------------------------------------------------------------ popups
func popup(text: String, col: Color, sub := "") -> void:
	var l := _label(30, Color.WHITE, col, pops)
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
		pops.get_child(0).queue_free()
		pops.remove_child(pops.get_child(0))


func big(text: String, col: Color, outline: Color) -> void:
	big_l.text = text
	big_l.label_settings.font_color = col
	big_l.label_settings.outline_color = outline
	big_l.scale = Vector2(3, 3)
	big_l.rotation = -0.18
	big_l.modulate.a = 0.0
	var tw := big_l.create_tween()
	tw.tween_property(big_l, "scale", Vector2(0.9, 0.9), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(big_l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(big_l, "rotation", -0.05, 0.18)
	tw.tween_property(big_l, "scale", Vector2(1.05, 1.05), 0.12)
	tw.tween_interval(0.7)
	tw.tween_property(big_l, "scale", Vector2(1.5, 1.5), 0.25)
	tw.parallel().tween_property(big_l, "modulate:a", 0.0, 0.25)


func bump_bar() -> void:
	bar.pivot_offset = bar.size * 0.5
	var tw := bar.create_tween()
	tw.tween_property(bar, "scale", Vector2(1.08, 1.25), 0.06)
	tw.tween_property(bar, "scale", Vector2.ONE, 0.15)


# ------------------------------------------------------------------ desenho
func _process(dt: float) -> void:
	t += dt
	bar.queue_redraw()
	minimap.queue_redraw()


func _draw_bar() -> void:
	var s := bar.size
	var r := Rect2(Vector2.ZERO, s)
	var full := nitro >= 0.999
	bar.draw_rect(r.grow(3), Color(1, 1, 1, 0.9 if (full or nitro_on) else 0.5), true)
	bar.draw_rect(r, Color(0.1, 0.08, 0.2, 0.9), true)
	var w := s.x * clampf(nitro, 0, 1)
	var c1 := Color("#2ee6ff") if nitro_on else (Color("#ffe14d") if full else Color("#ff7a1a"))
	var c2 := Color("#b4f6ff") if nitro_on else (Color("#fff7b0") if full else Color("#ffb01a"))
	bar.draw_rect(Rect2(0, 0, w, s.y), c1, true)
	var spd := 140.0 if nitro_on else 40.0
	var off := fmod(t * spd, 28.0)
	var x := -28.0 + off
	while x < w:
		var pts := PackedVector2Array([Vector2(x, s.y), Vector2(x + 10, 0), Vector2(x + 20, 0), Vector2(x + 10, s.y)])
		for i in pts.size():
			pts[i].x = clampf(pts[i].x, 0, w)
		bar.draw_colored_polygon(pts, c2)
		x += 28.0
	var fs := 14
	var txt := "NITRO"
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	bar.draw_string_outline(font, Vector2((s.x - tw) / 2, s.y * 0.72), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	bar.draw_string(font, Vector2((s.x - tw) / 2, s.y * 0.72), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_minimap() -> void:
	if track == null:
		return
	var s := minimap.size
	minimap.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.08, 0.2, 0.4), true)
	# gira 45° para bater com a vista isométrica
	var pts := PackedVector2Array()
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in range(0, track.n, 3):
		var p := _rot(track.pts[i])
		pts.append(p)
		mn = mn.min(p)
		mx = mx.max(p)
	pts.append(pts[0])
	var sc := minf((s.x - 16) / (mx.x - mn.x), (s.y - 16) / (mx.y - mn.y))
	var o := s * 0.5 - (mn + mx) * 0.5 * sc
	for i in pts.size():
		pts[i] = pts[i] * sc + o
	minimap.draw_polyline(pts, Color(0.1, 0.1, 0.2, 0.6), 8.0, true)
	minimap.draw_polyline(pts, Color(0.95, 0.94, 1.0), 4.0, true)
	for c in cars:
		if c.wrecked:
			continue
		var p := _rot(Vector2(c.global_position.x, c.global_position.z)) * sc + o
		if c.role == "traffic":
			minimap.draw_circle(p, 2.0, Color(0.4, 0.4, 0.5, 0.7))
		elif c.role == "rival":
			minimap.draw_circle(p, 4.5, c.color)
	if player:
		var p := _rot(Vector2(player.global_position.x, player.global_position.z)) * sc + o
		minimap.draw_circle(p, 6.5, Color.WHITE)
		minimap.draw_circle(p, 5.0, Color("#ff2d3d"))


func _rot(p: Vector2) -> Vector2:
	# câmera olha de +x+z para -x-z: direita da tela = (1,0,-1), para baixo = (1,0,1)
	return Vector2((p.x - p.y) * 0.7071, (p.x + p.y) * 0.7071)
