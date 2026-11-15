class_name Ui
## Ajudantes de interface: fontes, estilos de painel, botoes e icones.

const INK := Color("1b1730")
const PANEL := Color("231e3fee")
const PANEL_LIGHT := Color("332b5c")
const GOLD := Color("ffd36b")
const CYAN := Color("7df9ff")
const TEXT := Color("f4efe6")
const MUTED := Color("b0a8cc")

static var _bold: Font
static var _body: Font
static var _icons: Dictionary = {}
static var _theme: Theme

static func _variation(path: String, weight: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv

static func font_bold() -> Font:
	if _bold == null:
		_bold = _variation("res://assets/fonts/Baloo2.ttf", 700)
	return _bold

static func font_body() -> Font:
	if _body == null:
		_body = _variation("res://assets/fonts/Nunito.ttf", 650)
	return _body

static func icon(nm: String) -> Texture2D:
	if _icons.has(nm):
		return _icons[nm]
	var path := "res://assets/icons/%s.svg" % nm
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null and nm != "star":
		t = icon("star")
	_icons[nm] = t
	return t

static func box(color: Color = PANEL, radius: int = 16, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb

static func theme() -> Theme:
	if _theme:
		return _theme
	var th := Theme.new()
	th.default_font = font_body()
	th.default_font_size = 20
	th.set_color("font_color", "Label", TEXT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := PANEL_LIGHT
		var b := Color("5a4f96")
		match st:
			"hover":
				c = Color("463b7d")
				b = GOLD
			"pressed":
				c = Color("2a2350")
				b = GOLD
			"disabled":
				c = Color("25203f")
				b = Color("3a3360")
			"focus":
				c = Color(0, 0, 0, 0)
				b = Color(GOLD, 0.6)
		th.set_stylebox(st, "Button", box(c, 12, b, 2, 10))
	th.set_font("font", "Button", font_bold())
	th.set_font_size("font_size", "Button", 22)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("7a7399"))
	th.set_stylebox("normal", "LineEdit", box(Color("16122b"), 10, Color("5a4f96"), 2, 10))
	th.set_stylebox("focus", "LineEdit", box(Color("16122b"), 10, GOLD, 2, 10))
	th.set_font("font", "LineEdit", font_body())
	th.set_font_size("font_size", "LineEdit", 22)
	th.set_stylebox("panel", "PanelContainer", box())
	th.set_stylebox("panel", "TooltipPanel", box(Color("16122bf5"), 8, Color("5a4f96"), 1, 8))
	th.set_constant("separation", "VBoxContainer", 10)
	th.set_constant("separation", "HBoxContainer", 10)
	th.set_stylebox("slider", "HSlider", box(Color("16122b"), 6, Color("5a4f96"), 1, 4))
	th.set_stylebox("grabber_area", "HSlider", box(GOLD.darkened(0.2), 6, Color(0, 0, 0, 0), 0, 4))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, 6, Color(0, 0, 0, 0), 0, 4))
	var sb := box(Color("16122b"), 6, Color(0, 0, 0, 0), 0, 2)
	th.set_stylebox("scroll", "VScrollBar", sb)
	th.set_stylebox("grabber", "VScrollBar", box(Color("5a4f96"), 6, Color(0, 0, 0, 0), 0, 4))
	_theme = th
	return th

static func label(text: String, size: int = 20, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l

static func title(text: String, size: int = 34, color: Color = GOLD) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 8)
	return l

static func button(text: String, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func() -> void: Sfx.ui("ui_hover"))
	b.pressed.connect(func() -> void: Sfx.ui("ui_click"))
	return b

static func icon_rect(nm: String, size: int, color: Color = Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon(nm)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.modulate = color
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Quadro de icone com fundo na cor da raridade.
static func icon_tile(nm: String, size: int, bg: Color, fg: Color = Color.WHITE) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(bg.darkened(0.45), int(size * 0.24), bg, 3, int(size * 0.12)))
	pc.custom_minimum_size = Vector2(size, size)
	pc.add_child(icon_rect(nm, int(size * 0.7), fg))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc

static func panel(color: Color = PANEL, radius: int = 18, border: Color = Color("5a4f96"), bw: int = 2, pad: int = 18) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(color, radius, border, bw, pad))
	return pc

static func bar(fill: Color, back: Color = Color("16122b"), h: int = 22) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	pb.add_theme_stylebox_override("background", box(back, h / 2, INK, 2, 0))
	pb.add_theme_stylebox_override("fill", box(fill, h / 2, INK, 2, 0))
	pb.max_value = 1.0
	pb.step = 0.001
	pb.value = 1.0
	return pb

static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
