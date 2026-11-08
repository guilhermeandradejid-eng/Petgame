class_name UI
extends RefCounted
## Identidade visual "FÚRIA" (menus e botões).
## Princípios (pesquisa de interfaces de corrida — Gran Turismo, arcades de brinquedo, guias de UI de jogos):
##  • base escura e UMA cor "quente" de destaque (laranja-âmbar) para ação principal e foco; ciano só para informação
##  • formas inclinadas (paralelogramos) e itálico pesado = velocidade; degrau inferior dá "peso" de botão físico
##  • navegação vertical à esquerda, igual em todas as telas; fundo com a pista em movimento + linhas de velocidade
##  • contraste alto (texto claro sobre tinta escura, escuro sobre âmbar) e estado de foco que não depende só da cor
##    (borda branca + seta ▸ + leve aumento)

const INK := Color("#0f0d1c")
const INK2 := Color("#1b1730")
const PANEL := Color(0.105, 0.09, 0.19, 0.9)
const LINE := Color(1, 1, 1, 0.16)
const TEXT := Color("#f4f2ff")
const MUTED := Color("#a49ec4")
const HOT := Color("#ffb21a")
const HOT2 := Color("#ff5a1f")
const HOT_DARK := Color("#a33a00")
const INFO := Color("#2ee6ff")
const OK := Color("#7dff6a")
const BAD := Color("#ff2d55")
const SKEW := 0.22

static var display: Font      # Bungee
static var display_it: Font   # Bungee inclinada
static var body: Font         # Barlow Medium
static var body_it: Font      # Barlow SemiBold Italic
static var body_bold: Font    # Barlow Bold Italic


static func load_fonts() -> void:
	if display:
		return
	display = load("res://fonts/Bungee.woff2")
	var fv := FontVariation.new()
	fv.base_font = display
	fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)   # itálico "de corrida"
	display_it = fv
	body = load("res://fonts/Barlow-Medium.ttf")
	body_it = load("res://fonts/Barlow-SemiBoldItalic.ttf")
	body_bold = load("res://fonts/Barlow-BoldItalic.ttf")


static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, skew := SKEW, lip := 0, lip_col := Color(0, 0, 0, 0.5), radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.skew = Vector2(skew, 0)
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	if lip > 0:
		s.border_width_bottom = lip
		if bw == 0:
			s.border_color = lip_col
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8 + lip
	s.anti_aliasing = true
	return s


## botão da identidade: primary = âmbar (ação principal); secundário = tinta com contorno
static func style_button(b: Button, primary: bool, fs := 0) -> void:
	load_fonts()
	var base := HOT if primary else Color(0.13, 0.11, 0.24, 0.92)
	var normal := box(base, Color(0, 0, 0, 0), 0, SKEW, 5, HOT_DARK if primary else Color(0, 0, 0, 0.55))
	if not primary:
		normal.border_color = LINE
		normal.set_border_width_all(2)
		normal.border_width_bottom = 5
	var hover := box(HOT.lightened(0.18) if primary else Color(0.2, 0.17, 0.36, 0.95), Color.WHITE, 3, SKEW, 5)
	hover.border_width_bottom = 6
	var pressed := box(HOT2 if primary else HOT.darkened(0.15), Color.WHITE, 3, SKEW, 2)
	var dis := box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.08), 2, SKEW, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_font_override("font", display_it)
	if fs > 0:
		b.add_theme_font_size_override("font_size", fs)
	var fc := INK if primary else TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", INK if primary else Color.WHITE)
	b.add_theme_color_override("font_focus_color", INK if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	if not b.has_meta("ui_anim"):
		b.set_meta("ui_anim", true)
		b.set_meta("txt", b.text)
		b.focus_entered.connect(_pop.bind(b, true))
		b.focus_exited.connect(_pop.bind(b, false))
		b.mouse_entered.connect(_pop.bind(b, true))
		b.mouse_exited.connect(func(): if not b.has_focus(): _pop(b, false))
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)


## foco/hover: cresce um pouco e ganha a seta ▸ (não depende só da cor)
static func _pop(b: Button, on: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.05, 1.05) if on else Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t: String = b.text
	if on and not t.begins_with("▸ "):
		b.text = "▸ " + t
	elif not on and t.begins_with("▸ "):
		b.text = t.substr(2)


static func panel_box(accent := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := box(PANEL, LINE, 2, 0.0, 0, Color(0, 0, 0, 0), 10)
	if accent.a > 0.0:
		s.border_color = accent
		s.border_width_left = 6
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	return s


## tema geral (campos de texto, sliders, caixas de seleção, rolagem) para o que não usa os helpers
static func make_theme() -> Theme:
	load_fonts()
	var th := Theme.new()
	th.default_font = body
	th.default_font_size = 18
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.45), LINE, 2, 0.0, 0, Color.BLACK, 6))
	th.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.55), HOT, 2, 0.0, 0, Color.BLACK, 6))
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", MUTED)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = HOT
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var gr := _grabber(Color.WHITE)
	th.set_icon("grabber", "HSlider", gr)
	th.set_icon("grabber_highlight", "HSlider", _grabber(HOT.lightened(0.4)))
	th.set_stylebox("focus", "HSlider", box(Color(0, 0, 0, 0), HOT, 2, 0.0, 0, Color.BLACK, 6))
	return th


static func _grabber(c: Color) -> Texture2D:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 22:
			var d := Vector2(x - 10.5, y - 10.5).length()
			var a := clampf(10.5 - d, 0.0, 1.0)
			var col := c if d < 8.0 else HOT2
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


## fundo dos menus: escurece à esquerda (onde fica a navegação) e desenha linhas de velocidade animadas
static func backdrop(parent: Control, dim := 0.85) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ui_backdrop.gdshader")
	m.set_shader_parameter("dim", dim)
	m.set_shader_parameter("ink", INK)
	m.set_shader_parameter("hot", HOT)
	r.material = m
	parent.add_child(r)
	return r


## rótulo com a tipografia da identidade
static func title(parent: Node, txt: String, fs := 44, col := HOT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	load_fonts()
	var l := Label.new()
	l.text = txt
	var ls := LabelSettings.new()
	ls.font = display_it
	ls.font_size = fs
	ls.font_color = col
	ls.outline_size = maxi(4, fs / 7)
	ls.outline_color = INK
	ls.shadow_size = 0
	ls.shadow_color = HOT_DARK if col == HOT else Color(0, 0, 0, 0.5)
	ls.shadow_offset = Vector2(maxf(2, fs * 0.06), maxf(2, fs * 0.06))
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func text(parent: Node, txt: String, fs := 16, col := MUTED, italic := false) -> Label:
	load_fonts()
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", body_it if italic else body)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## faixa "zebra" (xadrez) de corrida para separar o cabeçalho
static func checker(parent: Node, w := 260.0, h := 10.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var n := int(c.size.x / h)
		for i in n:
			for j in 2:
				if (i + j) % 2 == 0:
					c.draw_rect(Rect2(i * h + j * 0.0, j * h * 0.5, h, h * 0.5), Color(1, 1, 1, 0.85))
		)
	parent.add_child(c)
	return c
