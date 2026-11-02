class_name Hud
extends CanvasLayer
## Interface de gibi: tela de título, escolha de modo, seleção de personagem
## em cards, placar por dupla, aviso do especial, pausa e fim de jogo.
## Tudo navegável por toque, mouse, teclado e controle.

signal play_pressed
signal rematch_pressed
signal menu_pressed

const FONT := preload("res://assets/fonts/Bangers.woff")
const INK := Color(0.07, 0.04, 0.12)
const YELLOW := Color("ffd23f")
const RED := Color("ff4b3e")
const CYAN := Color("4fe0ff")
const GREEN := Color("35e0a1")
const CREAM := Color("fff4e0")
const PORTRAITS := ["res://assets/ui/char_0.png", "res://assets/ui/char_1.png",
	"res://assets/ui/char_2.png", "res://assets/ui/char_3.png"]
const MODES := [
	{"id": "solo", "title": "1 JOGADOR", "tag": "1P", "desc": "Você + parceiro CPU\ncontra a dupla CPU", "color": Color("ffd23f")},
	{"id": "vs", "title": "VERSUS", "tag": "2P", "desc": "Um contra o outro\ntela dividida", "color": Color("ff4b3e")},
	{"id": "coop", "title": "CO-OP", "tag": "2P", "desc": "Vocês dois na mesma\ndupla contra a CPU", "color": Color("35e0a1")},
]

var fx: ComicFX
var touch: TouchControls
var score_panel: Control
var banner: Label
var banner_sub: Label
var hint: Label
var super_hint: Label
var super_hint_t := 0.0
var pause_btn: Button
var pause_panel: Control
var end_panel: Control
var end_title: Label
var end_sub: Label
var help_panel: Control
var theme_main: Theme
var dots_tex: ImageTexture
var portraits: Array[Texture2D] = []

var score := {"points": [0, 0], "games": [0, 0], "serving": 0, "golden": false, "target": 2}
var energy := [0.0, 0.0]
var pop_t := [0.0, 0.0]
var split_line: ColorRect
var again_btn: Button
var cont_btn: Button
var sfx_cb: Callable
var t := 0.0

# estado da interface
var in_game := false
var replay_on := false
var split_on := false
var pad_mode := false        # controle em uso pelo J1: esconde os botões de toque
var last_input_pad := false

# menu
var menu: Control
var menu_bg: Control
var title_scr: Control
var mode_scr: Control
var char_scr: Control
var screen := "title"
var screen_t := 0.0
var booted := false
var mode_tiles: Array[Button] = []
var tile_lift := [0.0, 0.0, 0.0]
var cards: Array[Button] = []
var card_lift := [0.0, 0.0, 0.0, 0.0]
var pick_stage := 0          # 0 = J1 escolhe, 1 = J2 escolhe
var play_btn: Button
var next_btn: Button
var locker_scr: Control
var lockers: Array[Dictionary] = []
var diff_btn: Button
var len_btn: Button
var music_btn: Button
var back_btn: Button
var mode_back_btn: Button
var help_btn: Button
var pads_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_main = _make_theme()
	dots_tex = _make_dots()
	for pth in PORTRAITS:
		portraits.append(load(pth) as Texture2D if ResourceLoader.exists(pth) else null)
	# vinheta suave de cinema nas bordas
	var vig := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gg.colors = PackedColorArray([Color(0.2, 0.08, 0.1, 0.0), Color(0.2, 0.08, 0.1, 0.0), Color(0.18, 0.06, 0.14, 0.32)])
	gt.gradient = gg
	gt.width = 256
	gt.height = 256
	vig.texture = gt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	fx = ComicFX.new()
	add_child(fx)
	score_panel = Control.new()
	score_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_panel.draw.connect(_draw_score)
	add_child(score_panel)
	touch = TouchControls.new()
	add_child(touch)

	banner = _label("", 96, Color.WHITE, 22)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.custom_minimum_size = Vector2(1200, 140)
	banner.position = Vector2(-600, -150)
	banner.pivot_offset = Vector2(600, 70)
	banner.visible = false
	add_child(banner)
	banner_sub = _label("", 40, YELLOW, 12)
	banner_sub.set_anchors_preset(Control.PRESET_CENTER)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.custom_minimum_size = Vector2(1200, 60)
	banner_sub.position = Vector2(-600, -40)
	banner_sub.visible = false
	add_child(banner_sub)

	hint = _label("", 30, Color.WHITE, 10)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(1000, 40)
	hint.position = Vector2(-500, 128)
	add_child(hint)

	super_hint = _label("", 38, YELLOW, 14)
	super_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	super_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	super_hint.custom_minimum_size = Vector2(900, 50)
	super_hint.position = Vector2(-450, -205)
	super_hint.pivot_offset = Vector2(450, 25)
	super_hint.visible = false
	add_child(super_hint)

	pause_btn = _button("II", 34, Color.WHITE)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.custom_minimum_size = Vector2(70, 64)
	pause_btn.position = Vector2(-90, 16)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	_build_menu()
	_build_help()
	_build_pause()
	_build_end()
	get_viewport().size_changed.connect(_layout_menu)
	show_menu()


# ---------------------------------------------------------------- estilo

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 32
	return th


## Textura de retícula (pontinhos de gibi) usada em cards e fundos
func _make_dots() -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var a := 0.0
			for c in [Vector2(6, 6), Vector2(18, 18)]:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				a = maxf(a, clampf(4.2 - d, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _style(col: Color, border := 5, radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = INK
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(INK, 0.5)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	return s


func _label(text: String, size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.theme = theme_main
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size: int, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme_main
	# navegável com controle (D-pad + A) nos menus
	b.focus_mode = Control.FOCUS_ALL
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = YELLOW
	fs.set_border_width_all(6)
	fs.set_corner_radius_all(20)
	fs.expand_margin_left = 5
	fs.expand_margin_right = 5
	fs.expand_margin_top = 5
	fs.expand_margin_bottom = 5
	b.add_theme_stylebox_override("focus", fs)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	var n := _style(col)
	n.shadow_size = 1
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _style(col.darkened(0.4)))
	b.pressed.connect(_click)
	b.mouse_entered.connect(b.grab_focus)
	return b


## Botão sem estilo: o desenho é todo feito à mão (tiles e cards)
func _blank_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.flat = true
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, e)
	b.mouse_entered.connect(b.grab_focus)
	return b


func _click() -> void:
	_sfx("click")


func _sfx(n: String) -> void:
	if sfx_cb.is_valid():
		sfx_cb.call(n)


func _panel(col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(col, 6, 26)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 18
	s.content_margin_bottom = 22
	s.shadow_size = 1
	s.shadow_offset = Vector2(8, 10)
	p.add_theme_stylebox_override("panel", s)
	return p


# ---------------------------------------------------------------- desenho

func _txt(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline := 0, center := true,
		outline_col := INK) -> void:
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos + Vector2(-w * 0.5 if center else 0.0, size * 0.36)
	if outline > 0:
		ci.draw_string_outline(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	ci.draw_string(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _para(r: Rect2, sk: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(sk, 0), Vector2(r.position.x, r.end.y)])


func _grow(pts: PackedVector2Array, g: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var o := PackedVector2Array()
	for p in pts:
		o.append(p + (p - c).normalized() * g)
	return o


## Polígono com retícula por cima
func _comic_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, dots := 0.16, border := 6.0) -> void:
	if border > 0.0:
		ci.draw_colored_polygon(_grow(pts, border), INK)
	ci.draw_colored_polygon(pts, col)
	if dots > 0.0:
		var uv := PackedVector2Array()
		for p in pts:
			uv.append(p / 24.0)
		ci.draw_colored_polygon(pts, Color(1, 1, 1, dots), uv, dots_tex)


func _burst(ci: CanvasItem, c: Vector2, r: float, n: int, rot: float, col: Color, fade := true) -> void:
	for i in n:
		var a0 := rot + float(i) / n * TAU
		var a1 := a0 + TAU / n * 0.5
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r])
		var outer := Color(col, 0.0) if fade else col
		ci.draw_polygon(pts, PackedColorArray([col, outer, outer]))


func _star(ci: CanvasItem, c: Vector2, r: float, col: Color, border := 3.0, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	var pb := PackedVector2Array()
	for i in 10:
		var a := rot - PI * 0.5 + float(i) / 10.0 * TAU
		var k := 1.0 if i % 2 == 0 else 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * r * k)
		pb.append(c + Vector2(cos(a), sin(a)) * (r * k + border * (1.6 if i % 2 == 0 else 1.0)))
	if border > 0.0:
		ci.draw_colored_polygon(pb, INK)
	ci.draw_colored_polygon(pts, col)


## Carinha de jogador usada nos ícones dos modos
func _head(ci: CanvasItem, c: Vector2, r: float, shirt: Color, tag: String, tag_col: Color, skin := Color("f2b98a")) -> void:
	ci.draw_circle(c + Vector2(0, r * 1.35), r * 0.95 + 4, INK)
	ci.draw_circle(c + Vector2(0, r * 1.35), r * 0.95, shirt)
	ci.draw_circle(c, r + 4, INK)
	ci.draw_circle(c, r, skin)
	ci.draw_arc(c + Vector2(0, -r * 0.05), r * 0.98, PI * 1.05, PI * 1.95, 14, Color("3b2416"), r * 0.42)
	ci.draw_circle(c + Vector2(-r * 0.33, r * 0.12), r * 0.13, INK)
	ci.draw_circle(c + Vector2(r * 0.33, r * 0.12), r * 0.13, INK)
	ci.draw_arc(c + Vector2(0, r * 0.32), r * 0.25, 0.3, PI - 0.3, 8, INK, 2.5)
	if tag != "":
		var tr := Rect2(c + Vector2(-r * 0.85, r * 1.95), Vector2(r * 1.7, r * 0.8))
		ci.draw_rect(tr.grow(3), INK)
		ci.draw_rect(tr, tag_col)
		_txt(ci, tr.get_center() + Vector2(0, -1), tag, int(r * 0.62), INK)


# ---------------------------------------------------------------- menu

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	menu_bg = Control.new()
	menu_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	menu_bg.draw.connect(_draw_menu_bg)
	menu.add_child(menu_bg)

	# --- título
	title_scr = Control.new()
	title_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_scr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	title_scr.draw.connect(_draw_title)
	menu.add_child(title_scr)

	# --- modos
	mode_scr = Control.new()
	mode_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	mode_scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_scr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mode_scr.draw.connect(_draw_mode_header)
	menu.add_child(mode_scr)
	for i in MODES.size():
		var b := _blank_button()
		b.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		b.draw.connect(_draw_tile.bind(b, i))
		b.pressed.connect(_on_mode_pressed.bind(i))
		b.focus_entered.connect(_on_focus_move)
		mode_scr.add_child(b)
		mode_tiles.append(b)
	mode_back_btn = _button("< VOLTAR", 28, Color.WHITE)
	mode_back_btn.pressed.connect(_back)
	mode_scr.add_child(mode_back_btn)
	help_btn = _button("COMO JOGAR?", 30, CYAN)
	help_btn.pressed.connect(_toggle_help)
	mode_scr.add_child(help_btn)
	pads_label = _label("", 24, Color.WHITE, 8)
	pads_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_scr.add_child(pads_label)

	# --- personagens
	char_scr = Control.new()
	char_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_scr.draw.connect(_draw_char_header)
	menu.add_child(char_scr)
	for i in GameData.CHARACTERS.size():
		var b := _blank_button()
		b.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		b.draw.connect(_draw_card.bind(b, i))
		b.pressed.connect(_on_card_pressed.bind(i))
		b.focus_entered.connect(_on_card_focus.bind(i))
		char_scr.add_child(b)
		cards.append(b)
	back_btn = _button("< VOLTAR", 28, Color.WHITE)
	back_btn.pressed.connect(_back)
	char_scr.add_child(back_btn)
	diff_btn = _button("", 26, Color.WHITE)
	diff_btn.pressed.connect(_cycle_diff)
	char_scr.add_child(diff_btn)
	len_btn = _button("", 26, Color.WHITE)
	len_btn.pressed.connect(_cycle_len)
	char_scr.add_child(len_btn)
	music_btn = _button("", 26, Color.WHITE)
	music_btn.pressed.connect(_cycle_music)
	char_scr.add_child(music_btn)
	next_btn = _big_button("VESTIÁRIO >", 50, GREEN)
	next_btn.pressed.connect(func():
		_sfx("ui_start")
		_go_screen("locker")
	)
	char_scr.add_child(next_btn)

	# --- vestiário: roupa, cores e raquete de cada jogador, com prévia 3D
	locker_scr = Control.new()
	locker_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	locker_scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locker_scr.draw.connect(_draw_locker_header)
	menu.add_child(locker_scr)
	for j in 2:
		lockers.append(_build_locker(j))
	var lb := _button("< VOLTAR", 28, Color.WHITE)
	lb.pressed.connect(_back)
	locker_scr.add_child(lb)
	locker_scr.set_meta("back", lb)
	play_btn = _big_button("JOGAR!", 66, RED)
	play_btn.pressed.connect(func():
		_sfx("ui_start")
		play_pressed.emit()
	)
	locker_scr.add_child(play_btn)
	_layout_menu()


func _big_button(text: String, size: int, col: Color) -> Button:
	var b := _button(text, size, col)
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 16)
	return b


func _build_locker(j: int) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_locker.bind(j))
	locker_scr.add_child(root)
	var pv := SubViewportContainer.new()
	pv.stretch = true
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.position = Vector2(14, 60)
	pv.size = Vector2(240, 330)
	root.add_child(pv)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pv.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 34
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.25, 3.3), Vector3(0, 0.95, 0))
	var pivot := Node3D.new()
	vp.add_child(pivot)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.76
	cyl.height = 0.1
	disc.mesh = cyl
	disc.position.y = -0.05
	disc.material_override = Toon.make(Color("f4d9a0"), {"outline": 0.03})
	vp.add_child(disc)
	var btns: Array[Button] = []
	for k in ["outfit", "palette", "racket", "racket_color"]:
		var b := _button("", 24, Color.WHITE)
		b.custom_minimum_size = Vector2(0, 0)
		b.pressed.connect(_cycle_look.bind(j, k))
		b.focus_entered.connect(_on_focus_move)
		root.add_child(b)
		btns.append(b)
	return {"root": root, "svc": pv, "vp": vp, "pivot": pivot, "player": null, "btns": btns, "key": ""}


func _look_team(j: int) -> int:
	return 1 if j == 1 and GameData.mode == "vs" else 0


func _look_char(j: int) -> int:
	return GameData.char_index if j == 0 else GameData.char_index_p2


func _cycle_look(j: int, k: String) -> void:
	var lk: Dictionary = GameData.looks[j]
	match k:
		"outfit":
			lk["outfit"] = (int(lk["outfit"]) + 1) % GameData.OUTFITS.size()
		"palette":
			lk["palette"] = (int(lk["palette"]) + 1) % GameData.PALETTES[_look_team(j)].size()
		"racket":
			lk["racket"] = (int(lk["racket"]) + 1) % GameData.RACKETS.size()
		"racket_color":
			lk["racket_color"] = (int(lk["racket_color"]) + 2) % (GameData.RACKET_COLORS.size() + 1) - 1
	_refresh_lockers()
	var pl: Player = lockers[j]["player"]
	if pl:
		pl.celebrate()


func _refresh_lockers() -> void:
	for j in lockers.size():
		var L: Dictionary = lockers[j]
		var on := screen == "locker" and (j == 0 or _two_players())
		(L["root"] as Control).visible = on
		(L["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		var lk: Dictionary = GameData.looks[j]
		var team := _look_team(j)
		var ch: Dictionary = GameData.CHARACTERS[_look_char(j)]
		var btns: Array[Button] = L["btns"]
		btns[0].text = "ROUPA: %s" % GameData.OUTFITS[int(lk["outfit"])]["name"]
		btns[1].text = "CORES: %s" % GameData.PALETTES[team][int(lk["palette"]) % 3]["name"]
		var rk: Dictionary = GameData.RACKETS[int(lk["racket"])]
		btns[2].text = "RAQUETE: %s" % rk["name"]
		var rci: int = lk["racket_color"]
		btns[3].text = "COR: %s" % ("DO PERSONAGEM" if rci < 0 else GameData.RACKET_COLOR_NAMES[rci])
		(L["root"] as Control).queue_redraw()
		var key := "%d|%d|%s" % [_look_char(j), team, str(lk)]
		if on and key != L["key"]:
			L["key"] = key
			if L["player"]:
				(L["player"] as Player).queue_free()
			var p := Player.new()
			(L["pivot"] as Node3D).add_child(p)
			p.setup(ch, team, false, lk)
			p.side = -1.0
			p.reset_state()
			p.rotation.y = 0.0
			p.facing = 0.0
			p.shadow.visible = false
			L["player"] = p


func _draw_locker_header() -> void:
	_draw_header(locker_scr, "VESTIÁRIO", "", Color("9b5de5"))


func _draw_locker(j: int) -> void:
	var L: Dictionary = lockers[j]
	var ci: Control = L["root"]
	var sz := ci.size
	var team := _look_team(j)
	var col: Color = GameData.PALETTES[team][int(GameData.looks[j]["palette"]) % 3]["shirt"]
	var r := Rect2(Vector2.ZERO, sz)
	var sh := PackedVector2Array()
	for p in _para(r, 16):
		sh.append(p + Vector2(9, 12))
	ci.draw_colored_polygon(sh, Color(INK, 0.5))
	_comic_poly(ci, _para(r, 16), CREAM, 0.0, 6.0)
	var pr := Rect2(14, 60, 240, 330)
	ci.draw_rect(pr.grow(4), INK)
	ci.draw_rect(pr, col.lightened(0.25))
	ci.draw_colored_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]),
		Color(1, 1, 1, 0.22), PackedVector2Array([pr.position / 24.0, Vector2(pr.end.x, pr.position.y) / 24.0, pr.end / 24.0,
		Vector2(pr.position.x, pr.end.y) / 24.0]), dots_tex)
	_burst(ci, pr.get_center() + Vector2(0, -30), 220, 12, t * 0.3, Color(1, 1, 1, 0.25))
	var ch: Dictionary = GameData.CHARACTERS[_look_char(j)]
	var who := "J%d" % (j + 1)
	var band := Rect2(-8, 10, sz.x + 16, 46)
	_comic_poly(ci, _para(band, 12), INK, 0.0, 0.0)
	_txt(ci, band.get_center(), "%s  •  %s" % [who, String(ch["name"]).to_upper()], 36, YELLOW if j == 0 else CYAN, 0)
	var rk: Dictionary = GameData.RACKETS[int(GameData.looks[j]["racket"])]
	var d := GameData.with_racket(ch, GameData.looks[j])
	var info_y := 340.0
	_txt(ci, Vector2(400, info_y), "RAQUETE %s: %s" % [rk["name"], rk["desc"]], 22, INK, 0)
	var stats := [["FOR", d["power"]], ["CTRL", d["control"]]]
	for k in 2:
		var y := info_y + 26 + k * 22
		_txt(ci, Vector2(296, y), stats[k][0], 18, INK, 0, false)
		var n := _pips(float(stats[k][1]))
		for q in 5:
			var pp := Vector2(360 + q * 24, y)
			ci.draw_rect(Rect2(pp - Vector2(9, 7), Vector2(18, 14)), INK)
			ci.draw_rect(Rect2(pp - Vector2(7, 5), Vector2(14, 10)), RED if q < n else Color(0.82, 0.78, 0.7))


func _layout_menu() -> void:
	if menu == null:
		return
	var vs := get_viewport().get_visible_rect().size
	# tiles dos modos
	var tw := 300.0
	var th := 380.0
	var gap := 38.0
	var x0 := (vs.x - (tw * 3 + gap * 2)) * 0.5
	for i in mode_tiles.size():
		mode_tiles[i].position = Vector2(x0 + i * (tw + gap), 150)
		mode_tiles[i].size = Vector2(tw, th)
		mode_tiles[i].pivot_offset = Vector2(tw, th) * 0.5
	mode_back_btn.position = Vector2(28, vs.y - 92)
	mode_back_btn.size = Vector2(190, 66)
	help_btn.position = Vector2(vs.x - 268, vs.y - 92)
	help_btn.size = Vector2(240, 66)
	pads_label.position = Vector2(vs.x * 0.5 - 300, vs.y - 78)
	pads_label.size = Vector2(600, 40)
	# cards dos personagens
	var cw := 236.0
	var chh := 392.0
	var cg := 26.0
	var cx0 := (vs.x - (cw * 4 + cg * 3)) * 0.5
	for i in cards.size():
		cards[i].position = Vector2(cx0 + i * (cw + cg), 150)
		cards[i].size = Vector2(cw, chh)
	back_btn.position = Vector2(24, 20)
	back_btn.size = Vector2(170, 60)
	var full := cw * 4 + cg * 3
	var oy := vs.y - 124.0
	diff_btn.position = Vector2(cx0, oy)
	diff_btn.size = Vector2(196, 70)
	len_btn.position = Vector2(cx0 + 210, oy)
	len_btn.size = Vector2(250, 70)
	music_btn.position = Vector2(cx0 + 474, oy)
	music_btn.size = Vector2(170, 70)
	next_btn.position = Vector2(cx0 + full - 330, oy - 14)
	next_btn.size = Vector2(330, 96)
	next_btn.pivot_offset = next_btn.size * 0.5
	# vestiário
	var lw := 540.0
	var lh := 404.0
	var two := _two_players()
	var lx0 := (vs.x - (lw * 2 + 40.0)) * 0.5 if two else (vs.x - lw) * 0.5 - 150.0
	for j in lockers.size():
		var root: Control = lockers[j]["root"]
		root.position = Vector2(lx0 + j * (lw + 40.0), 124)
		root.size = Vector2(lw, lh)
		var btns: Array[Button] = lockers[j]["btns"]
		for k in btns.size():
			btns[k].position = Vector2(272, 66 + k * 64)
			btns[k].size = Vector2(250, 54)
	(locker_scr.get_meta("back") as Button).position = Vector2(24, 20)
	(locker_scr.get_meta("back") as Button).size = Vector2(170, 60)
	if two:
		play_btn.position = Vector2(vs.x * 0.5 - 165, vs.y - 150)
	else:
		play_btn.position = Vector2(lx0 + lw + 50, 124 + lh - 120)
	play_btn.size = Vector2(330, 104)
	play_btn.pivot_offset = play_btn.size * 0.5


func _go_screen(s: String) -> void:
	screen = s
	screen_t = 0.0
	title_scr.visible = s == "title"
	mode_scr.visible = s == "mode"
	char_scr.visible = s == "char"
	locker_scr.visible = s == "locker"
	help_panel.visible = false
	_layout_menu()
	_refresh_menu()
	match s:
		"title":
			get_viewport().gui_release_focus()
		"mode":
			var idx := 0
			for i in MODES.size():
				if MODES[i]["id"] == GameData.mode:
					idx = i
			mode_tiles[idx].grab_focus.call_deferred()
		"char":
			pick_stage = 0
			cards[GameData.char_index].grab_focus.call_deferred()
		"locker":
			((lockers[0]["btns"] as Array)[0] as Button).grab_focus.call_deferred()


func _back() -> void:
	if help_panel.visible:
		_toggle_help()
		return
	match screen:
		"mode":
			_go_screen("title")
		"locker":
			_go_screen("char")
		"char":
			if pick_stage == 1:
				pick_stage = 0
				cards[GameData.char_index].grab_focus()
				_refresh_menu()
			else:
				_go_screen("mode")


func _on_focus_move() -> void:
	if screen_t > 0.05:
		_sfx("ui_move")


func _on_mode_pressed(i: int) -> void:
	if screen_t < 0.15:
		return
	GameData.mode = MODES[i]["id"]
	_sfx("ui_start")
	_go_screen("char")


func _two_players() -> bool:
	return GameData.mode != "solo"


func _on_card_focus(i: int) -> void:
	_on_focus_move()
	if pick_stage == 0:
		GameData.char_index = i
		if GameData.char_index_p2 == i:
			GameData.char_index_p2 = (i + 2) % GameData.CHARACTERS.size()
	elif i != GameData.char_index:
		GameData.char_index_p2 = i
	_refresh_menu()


func _on_card_pressed(i: int) -> void:
	if screen_t < 0.15:
		return
	_click()
	if pick_stage == 0:
		GameData.char_index = i
		if _two_players():
			pick_stage = 1
			if GameData.char_index_p2 == i:
				GameData.char_index_p2 = (i + 2) % GameData.CHARACTERS.size()
			cards[GameData.char_index_p2].grab_focus()
		else:
			next_btn.grab_focus()
	else:
		if i == GameData.char_index:
			return   # já é do J1
		GameData.char_index_p2 = i
		next_btn.grab_focus()
	_refresh_menu()


func _cycle_diff() -> void:
	GameData.difficulty = (GameData.difficulty + 1) % GameData.DIFFICULTIES.size()
	_refresh_menu()


func _cycle_len() -> void:
	GameData.length_index = (GameData.length_index + 1) % GameData.LENGTHS.size()
	_refresh_menu()


func _cycle_music() -> void:
	GameData.music_on = not GameData.music_on
	_sfx("music_toggle")
	_refresh_menu()


func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	if help_panel.visible:
		(help_panel.get_meta("close") as Button).grab_focus.call_deferred()
	elif pause_panel.visible:
		(pause_panel.get_meta("ctl") as Button).grab_focus.call_deferred()
	else:
		help_btn.grab_focus.call_deferred()


func _refresh_menu() -> void:
	if diff_btn == null:
		return
	diff_btn.text = "CPU: %s" % GameData.DIFFICULTIES[GameData.difficulty]["name"]
	var L: Dictionary = GameData.LENGTHS[GameData.length_index]
	len_btn.text = "PARTIDA: OFICIAL" if L.get("official", false) else "PARTIDA: %s (%d)" % [L["name"], L["games"]]
	music_btn.text = "MÚSICA: %s" % ("SIM" if GameData.music_on else "NÃO")
	if GameData.char_index_p2 == GameData.char_index:
		GameData.char_index_p2 = (GameData.char_index + 2) % GameData.CHARACTERS.size()
	var n := Input.get_connected_joypads().size()
	var tx := "SEM CONTROLE: TOQUE OU TECLADO"
	if n == 1:
		tx = "1 CONTROLE CONECTADO"
	elif n > 1:
		tx = "%d CONTROLES CONECTADOS" % n
	pads_label.text = tx
	for c in cards:
		c.queue_redraw()
	char_scr.queue_redraw()
	_refresh_lockers()


func _input(event: InputEvent) -> void:
	# lembra se o último toque nos menus veio do controle ou da tela
	if event is InputEventJoypadButton and event.is_pressed():
		last_input_pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		last_input_pad = true
	elif event is InputEventScreenTouch and event.is_pressed():
		last_input_pad = false
	if not menu.visible:
		return
	if screen == "title" and screen_t > 0.35:
		var go := false
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch or event is InputEventMouseButton:
			go = event.is_pressed() and not event.is_echo()
		if go:
			get_viewport().set_input_as_handled()
			_sfx("ui_start")
			_go_screen("mode")
		return
	if event.is_action_pressed("ui_cancel") and screen != "title":
		get_viewport().set_input_as_handled()
		_click()
		_back()


func _draw_menu_bg() -> void:
	if screen == "title":
		return
	var vs := menu_bg.get_viewport_rect().size
	menu_bg.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.13, 0.05, 0.22, 0.66))
	# listras diagonais em movimento
	var off := fmod(t * 30.0, 160.0)
	var x := -vs.y - 160.0 + off
	while x < vs.x + 160.0:
		menu_bg.draw_colored_polygon(PackedVector2Array([Vector2(x, vs.y), Vector2(x + 70, vs.y),
			Vector2(x + 70 + vs.y, 0), Vector2(x + vs.y, 0)]), Color(1, 1, 1, 0.035))
		x += 160.0
	menu_bg.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y)]),
		Color(1, 1, 1, 0.08), PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0) / 24.0, vs / 24.0]), dots_tex)


# --- tela de título

func _draw_title() -> void:
	var ci := title_scr
	var vs := ci.get_viewport_rect().size
	var c := Vector2(vs.x * 0.5, vs.y * 0.4)
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(1.0, 0.55, 0.2, 0.22))
	_burst(ci, c, vs.length() * 0.75, 22, t * 0.12, Color(1.0, 0.86, 0.3, 0.75))
	ci.draw_circle(c, vs.y * 0.33, Color(1.0, 0.92, 0.5, 0.35))
	# personagens espiando dos lados
	var spots := [0.1, 0.24, 0.76, 0.9]
	for i in 4:
		var tex: Texture2D = portraits[i]
		if tex == null:
			continue
		var h := vs.y * 0.62
		var w := h * tex.get_width() / tex.get_height()
		var bob := sin(t * 2.4 + i * 1.7) * 8.0
		var px: float = vs.x * spots[i]
		var r := Rect2(px - w * 0.5, vs.y - h + 40 + bob, w, h)
		ci.draw_set_transform(Vector2(px, vs.y), (-0.08 if i < 2 else 0.08), Vector2(-1 if i >= 2 else 1, 1))
		ci.draw_texture_rect(tex, Rect2(r.position - Vector2(px, vs.y), r.size), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# logo
	var wob := sin(t * 1.6) * 0.012
	ci.draw_set_transform(c + Vector2(0, -36), -0.07 + wob, Vector2.ONE * (1.0 + sin(t * 3.2) * 0.012))
	_txt(ci, Vector2(10, 12), "SMASH", 176, INK, 34)
	_txt(ci, Vector2.ZERO, "SMASH", 176, YELLOW, 30)
	_txt(ci, Vector2(-2, -6), "SMASH", 176, Color(1, 1, 1, 0.0), 0)
	_txt(ci, Vector2(48, 128), "NA AREIA", 100, INK, 26)
	_txt(ci, Vector2(40, 118), "NA AREIA", 100, RED, 22)
	# bolinha com rastro
	var bc := Vector2(222, -78)
	for k in 3:
		ci.draw_line(bc + Vector2(-60 - k * 22, -14 + k * 16), bc + Vector2(-26 - k * 14, -10 + k * 14), Color(1, 1, 1, 0.9), 7.0)
	ci.draw_circle(bc, 40, INK)
	ci.draw_circle(bc, 34, Color("d8ff3e"))
	ci.draw_arc(bc + Vector2(-40, 0), 32, -0.9, 0.9, 12, Color.WHITE, 5.0)
	ci.draw_arc(bc + Vector2(40, 0), 32, PI - 0.9, PI + 0.9, 12, Color.WHITE, 5.0)
	ci.draw_circle(bc + Vector2(-12, -14), 7, Color(1, 1, 1, 0.7))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# aviso pulsante
	var prompt := "APERTE ENTER PARA JOGAR"
	if Input.get_connected_joypads().size() > 0:
		prompt = "APERTE (A) PARA JOGAR"
	elif DisplayServer.is_touchscreen_available():
		prompt = "TOQUE NA TELA PARA JOGAR"
	var a := 0.55 + 0.45 * sin(t * 5.0)
	_txt(ci, Vector2(c.x, vs.y - 64), prompt, int(40 + 3 * sin(t * 5.0)), Color(1, 1, 1, a), 12, true, Color(INK, a))
	_txt(ci, Vector2(vs.x - 60, vs.y - 22), "DEMO 0.2", 22, Color(1, 1, 1, 0.75), 6)


# --- tela de modos

func _draw_header(ci: CanvasItem, text: String, sub: String, col: Color) -> void:
	var vs := ci.get_viewport_rect().size
	var r := Rect2(vs.x * 0.5 - 290, 28, 580, 70)
	_comic_poly(ci, _para(r, 24), col, 0.18, 6.0)
	_txt(ci, r.get_center() + Vector2(0, -2), text, 54, Color.WHITE, 14)
	if sub != "":
		_txt(ci, Vector2(vs.x * 0.5, r.end.y + 20), sub, 24, YELLOW, 8)


func _draw_mode_header() -> void:
	_draw_header(mode_scr, "ESCOLHA O MODO", "", RED)


func _draw_tile(b: Button, i: int) -> void:
	var m: Dictionary = MODES[i]
	var sz := b.size
	var f := b.has_focus()
	var lift: float = tile_lift[i]
	var col: Color = m["color"]
	var r := Rect2(Vector2(0, -18.0 * lift), sz)
	var pts := _para(r, 22)
	b.draw_colored_polygon(_grow(pts, 6).duplicate() if not f else _grow(pts, 16), YELLOW if f else Color(INK, 0.0))
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(10, 12))
	b.draw_colored_polygon(sh, Color(INK, 0.5))
	_comic_poly(b, pts, col if f else col.darkened(0.25), 0.2, 6.0)
	if f:
		_burst(b, r.position + Vector2(sz.x * 0.5, sz.y * 0.4), sz.y * 0.55, 14, t * 0.6, Color(1, 1, 1, 0.35))
	# selo
	_txt(b, r.position + Vector2(sz.x * 0.5, 50), m["tag"], 72, Color.WHITE, 16)
	# ícone: carinhas de cada lado
	var cy := r.position.y + 162.0
	var cxm := r.position.x + sz.x * 0.5
	var blue := Color("2f8cff")
	var red := Color("ff4b3e")
	match m["id"]:
		"solo":
			_head(b, Vector2(cxm - 78, cy), 26, blue, "J1", YELLOW)
			_head(b, Vector2(cxm - 30, cy + 10), 18, blue, "CPU", Color.WHITE, Color("d39a6a"))
			_head(b, Vector2(cxm + 46, cy + 10), 18, red, "CPU", Color.WHITE, Color("8d5a3b"))
			_head(b, Vector2(cxm + 90, cy + 10), 18, red, "CPU", Color.WHITE, Color("5e3a26"))
		"vs":
			_head(b, Vector2(cxm - 70, cy), 30, blue, "J1", YELLOW)
			_head(b, Vector2(cxm + 70, cy), 30, red, "J2", CYAN, Color("d39a6a"))
		"coop":
			_head(b, Vector2(cxm - 92, cy), 24, blue, "J1", YELLOW)
			_head(b, Vector2(cxm - 40, cy), 24, blue, "J2", CYAN, Color("d39a6a"))
			_head(b, Vector2(cxm + 50, cy + 10), 18, red, "CPU", Color.WHITE, Color("8d5a3b"))
			_head(b, Vector2(cxm + 92, cy + 10), 18, red, "CPU", Color.WHITE, Color("5e3a26"))
	_txt(b, Vector2(cxm + (-5 if m["id"] != "vs" else 0), cy + 4), "VS", 34, YELLOW, 10)
	# faixa com nome
	var band := Rect2(r.position + Vector2(-10, 248), Vector2(sz.x + 20, 62))
	_comic_poly(b, _para(band, 14), INK, 0.0, 0.0)
	_txt(b, band.get_center(), m["title"], 48, Color.WHITE if not f else YELLOW, 0)
	var lines: PackedStringArray = String(m["desc"]).split("\n")
	for k in lines.size():
		_txt(b, r.position + Vector2(sz.x * 0.5, 334 + k * 24), lines[k], 22, INK, 0)


# --- tela de personagens

func _draw_char_header() -> void:
	if pick_stage == 0:
		_draw_header(char_scr, "J1: ESCOLHA SEU JOGADOR" if _two_players() else "ESCOLHA SEU JOGADOR",
			"", YELLOW.darkened(0.1) if not _two_players() else Color("2f8cff"))
	else:
		_draw_header(char_scr, "J2: ESCOLHA SEU JOGADOR", "", RED)


func _pips(v: float) -> int:
	return clampi(roundi(3.0 + (v - 1.0) / 0.07), 1, 5)


func _draw_card(b: Button, i: int) -> void:
	var ch: Dictionary = GameData.CHARACTERS[i]
	var sz := b.size
	var f := b.has_focus()
	var lift: float = card_lift[i]
	var sel1 := GameData.char_index == i
	var sel2 := _two_players() and GameData.char_index_p2 == i
	var acc: Color = ch["accent"]
	var r := Rect2(Vector2(0, -20.0 * lift), sz)
	var pts := _para(r, 16)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(9, 12))
	b.draw_colored_polygon(sh, Color(INK, 0.5))
	if f:
		b.draw_colored_polygon(_grow(pts, 16), YELLOW)
	var dim := 0.0 if (f or sel1 or sel2) else 0.3
	_comic_poly(b, pts, acc.darkened(dim), 0.2, 6.0)
	var pc := r.position + Vector2(sz.x * 0.5, sz.y * 0.32)
	_burst(b, pc, sz.y * 0.5, 12, t * (0.5 if f else 0.0) + i, Color(1, 1, 1, 0.28 if f else 0.12))
	# retrato (a cabeça escapa do card, estilo gibi)
	var tex: Texture2D = portraits[i]
	var band_y := r.position.y + sz.y * 0.5
	if tex:
		var h := sz.y * 0.6 * (1.0 + 0.05 * lift)
		var w := h * tex.get_width() / tex.get_height()
		b.draw_texture_rect(tex, Rect2(pc.x - w * 0.5, band_y + 16 - h, w, h), false,
			Color(1, 1, 1) if dim == 0.0 else Color(0.75, 0.75, 0.8))
	# faixa do nome
	var band := Rect2(r.position.x - 8, band_y, sz.x + 16, 56)
	_comic_poly(b, _para(band, 12), INK, 0.0, 0.0)
	_txt(b, band.get_center() + Vector2(0, -1), String(ch["name"]).to_upper(), 46, Color.WHITE, 10, true, acc.darkened(0.45))
	# quadro de atributos
	var info := Rect2(r.position + Vector2(14, band.end.y - r.position.y + 6), Vector2(sz.x - 28, sz.y - (band.end.y - r.position.y) - 18))
	b.draw_rect(info, Color(CREAM, 0.95))
	_txt(b, Vector2(info.get_center().x, info.position.y + 14), String(ch["desc"]).to_upper(), 22, acc.darkened(0.35), 0)
	var stats := [["VEL", ch["speed"]], ["FOR", ch["power"]], ["CTRL", ch["control"]]]
	for k in 3:
		var y := info.position.y + 38 + k * 22
		_txt(b, Vector2(info.position.x + 8, y), stats[k][0], 18, INK, 0, false)
		var n := _pips(float(stats[k][1]))
		for q in 5:
			var pp := Vector2(info.position.x + 72 + q * 24, y)
			b.draw_rect(Rect2(pp - Vector2(9, 7), Vector2(18, 14)), INK)
			b.draw_rect(Rect2(pp - Vector2(7, 5), Vector2(14, 10)), acc if q < n else Color(0.82, 0.78, 0.7))
	var sp: String = String(Shots.SPECIALS[ch["special"]]["name"]).trim_suffix("!")
	var sy := info.end.y - 14
	_star(b, Vector2(info.position.x + 16, sy), 10, YELLOW, 2.0)
	_txt(b, Vector2(info.position.x + 32, sy), sp, 20, RED.darkened(0.2), 0, false)
	# marcadores J1 / J2
	if sel1:
		_tag(b, Vector2(r.position.x + 36, r.position.y - 26), "J1", YELLOW)
	if sel2:
		_tag(b, Vector2(r.end.x - 36, r.position.y - 26), "J2", CYAN)


func _tag(ci: CanvasItem, c: Vector2, s: String, col: Color) -> void:
	var r := Rect2(c - Vector2(30, 20), Vector2(60, 40))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 18), c + Vector2(10, 18), c + Vector2(0, 32)]), INK)
	ci.draw_rect(r.grow(4), INK)
	ci.draw_rect(r, col)
	_txt(ci, c + Vector2(0, -1), s, 32, INK, 0)


func _build_help() -> void:
	help_panel = _panel(CREAM)
	help_panel.set_anchors_preset(Control.PRESET_CENTER)
	help_panel.position = Vector2(-470, -320)
	help_panel.custom_minimum_size = Vector2(940, 0)
	help_panel.visible = false
	add_child(help_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	help_panel.add_child(v)
	var hd := _label("COMO JOGAR", 50, RED, 12)
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hd)
	var tip := _label("A bola NÃO pode quicar: rebata no ar! Um toque por dupla.  Aperte o golpe antes da bola chegar para carregar.", 22, INK, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.custom_minimum_size = Vector2(880, 0)
	v.add_child(tip)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 0)
	v.add_child(g)
	var rows := [
		["", "CONTROLE", "TECLADO", "TOQUE"],
		["MOVER", "ANALÓGICO", "W A S D", "ARRASTE À ESQUERDA"],
		["FORTE (topspin)", "A", "J", "FORTE"],
		["LOB (alto, fundo)", "X", "K", "LOB"],
		["CURTA (slice)", "B", "L", "CURTA"],
		["SMASH (bola alta)", "Y", "I", "SMASH"],
		["DEFESA (escudo azul)", "LB  ou  RT", "O", "DEFESA"],
		["ESPECIAL (barra cheia)", "RB", "U", "ESTRELA ESPECIAL"],
		["PEIXINHO", "LT  ou  L3", "SHIFT", "PEIXINHO"],
		["PAUSA", "START", "ESC", "II"],
	]
	for ri in rows.size():
		for ci in 4:
			var col := INK
			if ri == 0:
				col = RED
			elif ci == 0:
				col = Color("2f6cd6")
			var l := _label(rows[ri][ci], 24 if ri > 0 else 26, col, 0)
			g.add_child(l)
	var tip2 := _label("Estrela de CHANCE no chão: pare em cima e use o golpe da mesma cor.  Bons golpes enchem a barra ESPECIAL.", 22, INK, 0)
	tip2.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip2.custom_minimum_size = Vector2(880, 0)
	v.add_child(tip2)
	var close := _button("FECHAR", 28, YELLOW)
	close.pressed.connect(_toggle_help)
	v.add_child(close)
	help_panel.set_meta("close", close)


func set_split(on: bool) -> void:
	split_on = on
	if split_line == null:
		split_line = ColorRect.new()
		split_line.color = INK
		split_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(split_line)
		move_child(split_line, 0)
	var vs := get_viewport().get_visible_rect().size
	split_line.set_anchors_preset(Control.PRESET_TOP_LEFT)
	split_line.size = Vector2(8, vs.y)
	split_line.position = Vector2(vs.x * 0.5 - 4, 0)
	split_line.visible = on
	_update_touch()


## Botões de toque só aparecem quando fazem sentido
func _update_touch() -> void:
	var want := in_game and not menu.visible and not end_panel.visible and not replay_on \
		and GameData.mode != "vs" and not split_on and not pad_mode
	if touch.visible != want:
		touch.reset()
	touch.visible = want


## Controle em uso pelo J1 esconde os botões; tocar na tela traz de volta
func set_pad_mode(on: bool) -> void:
	if pad_mode == on:
		return
	pad_mode = on
	_update_touch()


func _process(dt: float) -> void:
	t += dt
	screen_t += dt
	if menu.visible:
		menu_bg.queue_redraw()
		if screen == "title":
			title_scr.queue_redraw()
		elif screen == "mode":
			for i in mode_tiles.size():
				var tg := 1.0 if mode_tiles[i].has_focus() else 0.0
				tile_lift[i] = lerpf(tile_lift[i], tg, 1.0 - exp(-14.0 * dt))
				mode_tiles[i].queue_redraw()
		elif screen == "char":
			for i in cards.size():
				var tg2 := 1.0 if cards[i].has_focus() else 0.0
				card_lift[i] = lerpf(card_lift[i], tg2, 1.0 - exp(-14.0 * dt))
				cards[i].queue_redraw()
		for pb in [next_btn, play_btn]:
			(pb as Button).scale = Vector2.ONE * (1.0 + 0.04 * sin(t * 8.0)) if (pb as Button).has_focus() else Vector2.ONE
		if screen == "locker":
			for L in lockers:
				var pl: Player = L["player"]
				if pl and (L["root"] as Control).visible:
					(L["pivot"] as Node3D).rotation.y += dt * 0.7
					pl.facing = 0.0
					pl.update(dt)
					if pl.state == Player.State.CELEBRATE and pl.state_t > 1.2:
						pl.state = Player.State.NORMAL
	if banner.visible:
		banner.scale = banner.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * dt))
	if super_hint.visible:
		super_hint_t -= dt
		super_hint.scale = Vector2.ONE * (1.0 + 0.06 * sin(t * 9.0))
		super_hint.modulate.a = clampf(super_hint_t * 2.0, 0.0, 1.0)
		if super_hint_t <= 0.0:
			super_hint.visible = false
	for k in 2:
		pop_t[k] = maxf(0.0, pop_t[k] - dt * 1.6)
	if score_panel.visible:
		score_panel.queue_redraw()
	if replay_layer and replay_layer.visible:
		replay_t += dt
		replay_layer.queue_redraw()


# ---------------------------------------------------------------- pausa / fim

func _build_pause() -> void:
	pause_panel = _panel(CREAM)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-200, -190)
	pause_panel.custom_minimum_size = Vector2(400, 0)
	pause_panel.visible = false
	add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pause_panel.add_child(v)
	var tl := _label("PAUSA", 70, YELLOW, 18)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var cont := _button("CONTINUAR", 40, GREEN)
	cont_btn = cont
	cont.pressed.connect(_on_pause)
	v.add_child(cont)
	var mus := _button("MÚSICA: SIM", 32, CYAN)
	mus.pressed.connect(_toggle_music.bind(mus))
	v.add_child(mus)
	var ctl := _button("CONTROLES", 32, YELLOW)
	ctl.pressed.connect(_toggle_help)
	v.add_child(ctl)
	pause_panel.set_meta("ctl", ctl)
	var quit := _button("MENU", 40, RED)
	quit.pressed.connect(_quit_to_menu)
	v.add_child(quit)


func _toggle_music(btn: Button) -> void:
	GameData.music_on = not GameData.music_on
	btn.text = "MÚSICA: SIM" if GameData.music_on else "MÚSICA: NÃO"
	_sfx("music_toggle")


func _quit_to_menu() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	menu_pressed.emit()


func _on_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	help_panel.visible = false
	touch.reset()
	_sfx("pause_on" if p else "pause_off")
	if p and cont_btn:
		cont_btn.grab_focus()
	elif not p:
		get_viewport().gui_release_focus()


func _build_end() -> void:
	end_panel = _panel(CREAM)
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-270, -200)
	end_panel.custom_minimum_size = Vector2(540, 0)
	end_panel.visible = false
	add_child(end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	end_panel.add_child(v)
	end_title = _label("VITÓRIA!", 90, YELLOW, 22)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	end_sub = _label("", 36, INK, 0)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_sub)
	var again := _button("REVANCHE!", 44, GREEN)
	again_btn = again
	again.pressed.connect(func(): rematch_pressed.emit())
	v.add_child(again)
	var m := _button("MENU", 40, CYAN)
	m.pressed.connect(func(): menu_pressed.emit())
	v.add_child(m)


# ---------------------------------------------------------------- API

func show_menu() -> void:
	in_game = false
	menu.visible = true
	pause_btn.visible = false
	score_panel.visible = false
	end_panel.visible = false
	pause_panel.visible = false
	super_hint.visible = false
	hint.text = ""
	banner.visible = false
	banner_sub.visible = false
	_update_touch()
	# na primeira vez abre no título; depois de uma partida volta para os personagens
	_go_screen("char" if booted else "title")


func show_game() -> void:
	in_game = true
	booted = true   # depois de uma partida, o menu volta direto para os personagens
	menu.visible = false
	help_panel.visible = false
	get_viewport().gui_release_focus()
	pause_btn.visible = true
	score_panel.visible = true
	end_panel.visible = false
	_update_touch()


func show_end(won: bool, games: Array, vs := false) -> void:
	pause_btn.visible = false
	end_panel.visible = true
	super_hint.visible = false
	_update_touch()
	if vs:
		end_title.text = "J1 VENCEU!" if won else "J2 VENCEU!"
		end_title.add_theme_color_override("font_color", YELLOW if won else CYAN)
	else:
		end_title.text = "VITÓRIA!" if won else "DERROTA!"
		end_title.add_theme_color_override("font_color", YELLOW if won else RED)
	if again_btn:
		again_btn.grab_focus.call_deferred()
	end_sub.text = "%s  %d  x  %d  %s" % [GameData.TEAMS[0]["name"], games[0], games[1], GameData.TEAMS[1]["name"]]


func show_banner(text: String, sub: String = "", color: Color = Color.WHITE, time := 1.4) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.scale = Vector2(1.6, 1.6)
	banner.rotation = randf_range(-0.05, 0.05)
	banner_sub.text = ""
	banner_sub.visible = false   # sem subtítulo nas faixas
	get_tree().create_timer(time, true, false, true).timeout.connect(_hide_banner.bind(text))


func _hide_banner(text: String) -> void:
	if banner.text == text:
		banner.visible = false
		banner_sub.visible = false


func set_hint(text: String) -> void:
	hint.text = text


## Aviso de especial pronto, com o botão certo para cada jeito de jogar
func super_ready_hint(pad: bool, who := "") -> void:
	var how := "APERTE RB" if pad else ("TOQUE NA ESTRELA" if touch.visible else "APERTE U")
	flash_tip("%sESPECIAL PRONTO!  %s" % [(who + ": ") if who != "" else "", how], 3.2)


## Aviso pulsante embaixo da tela
func flash_tip(text: String, time := 3.0, col := YELLOW) -> void:
	super_hint.text = text
	super_hint.add_theme_color_override("font_color", col)
	super_hint.visible = true
	super_hint_t = time


## Destaque no placar da dupla que fez o ponto
func score_pop(team: int) -> void:
	if team >= 0 and team < 2:
		pop_t[team] = 1.0


var replay_layer: Control
var replay_t := 0.0
var charge_layer: Control
var charges: Array = []


## Medidor de carga do golpe: anel que enche em cima do jogador e "MAX!" quando cheio
func set_charges(marks: Array) -> void:
	if charge_layer == null:
		charge_layer = Control.new()
		charge_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		charge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		charge_layer.draw.connect(_draw_charges)
		add_child(charge_layer)
		move_child(charge_layer, 2)
	if marks.is_empty() and charges.is_empty():
		return
	charges = marks
	charge_layer.queue_redraw()


func _draw_charges() -> void:
	if replay_on or menu.visible:
		return
	for m in charges:
		var c: Vector2 = m["pos"]
		var v: float = m["v"]
		var col: Color = m["col"]
		var full := v >= 1.0
		var r := 19.0 * (1.0 + (0.12 * sin(t * 18.0) if full else 0.0))
		charge_layer.draw_circle(c, r + 6.0, Color(INK, 0.75))
		charge_layer.draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.18), 7.0)
		if v > 0.0:
			charge_layer.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * v, 32, Color.WHITE if full and fmod(t, 0.2) < 0.1 else col, 7.0)
		if full:
			_txt(charge_layer, c + Vector2(0, -r - 18), "MAX!", 24, YELLOW, 8)
		_txt(charge_layer, c + Vector2(0, 1), String(m["name"]).substr(0, 1), 18, Color.WHITE, 0)


func set_replay(on: bool) -> void:
	if replay_layer == null:
		replay_layer = Control.new()
		replay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		replay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		replay_layer.draw.connect(_draw_replay)
		add_child(replay_layer)
		move_child(replay_layer, 1)
	replay_layer.visible = on
	replay_on = on
	if not menu.visible:
		score_panel.visible = not on
	_update_touch()
	if on:
		hint.text = ""
		banner.visible = false
		banner_sub.visible = false
		super_hint.visible = false


func _draw_replay() -> void:
	var vs := replay_layer.get_viewport_rect().size
	var bar := vs.y * 0.1
	replay_layer.draw_rect(Rect2(0, 0, vs.x, bar), INK)
	replay_layer.draw_rect(Rect2(0, vs.y - bar, vs.x, bar), INK)
	var blink := fmod(replay_t, 1.0) < 0.6
	if blink:
		replay_layer.draw_circle(Vector2(46, bar * 0.5), 12, Color("ff3b3b"))
	replay_layer.draw_string(FONT, Vector2(70, bar * 0.5 + 16), "REPLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color.WHITE)
	var tip := "toque para pular"
	var tw := FONT.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	if not menu.visible:
		replay_layer.draw_string(FONT, Vector2(vs.x - tw - 30, vs.y - bar * 0.5 + 9), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))


func set_energy(e: Array) -> void:
	energy = e.duplicate()
	touch.super_fill = energy[0]
	score_panel.queue_redraw()


func set_score(points: Array, games: Array, serving: int, target: int, tiebreak := false) -> void:
	score = {"points": points.duplicate(), "games": games.duplicate(), "serving": serving,
		"golden": points[0] == 3 and points[1] == 3 and not tiebreak, "target": target, "tiebreak": tiebreak}
	score_panel.queue_redraw()


## Placar: cada dupla com seus pontos grandes, games em bolinhas,
## quem saca e a barra do especial.
func _draw_score() -> void:
	var ci := score_panel
	var vs := ci.get_viewport_rect().size
	var cx := vs.x * 0.5
	var top := 12.0
	var pw := 268.0
	var ph := 64.0
	var gap := 14.0
	var pts: Array = score["points"]
	var golden: bool = score["golden"]
	var vs_mode := GameData.mode == "vs" and in_game
	for side in [0, 1]:
		var team: Dictionary = GameData.TEAMS[side]
		var col: Color = team["shirt"]
		var x0: float = cx - gap * 0.5 - pw if side == 0 else cx + gap * 0.5
		var rect := Rect2(x0, top, pw, ph)
		var sk := 14.0 if side == 0 else -14.0
		var poly := PackedVector2Array([rect.position + Vector2(maxf(sk, 0.0), 0), Vector2(rect.end.x - maxf(-sk, 0.0), rect.position.y),
			Vector2(rect.end.x - maxf(sk, 0.0), rect.end.y), Vector2(rect.position.x + maxf(-sk, 0.0), rect.end.y)])
		var shp := PackedVector2Array()
		for p in poly:
			shp.append(p + Vector2(5, 7))
		ci.draw_colored_polygon(shp, Color(INK, 0.45))
		_comic_poly(ci, poly, col, 0.14, 4.0)
		# caixa dos pontos (do lado de dentro, perto do centro)
		var bw := 84.0
		var bx: float = rect.end.x - bw - 6.0 if side == 0 else rect.position.x + 6.0
		var pop: float = pop_t[side]
		var box := Rect2(bx, top + 6, bw, ph - 12)
		ci.draw_rect(box.grow(3), INK)
		ci.draw_rect(box, Color.WHITE.lerp(YELLOW, pop))
		var ps: String = str(pts[side]) if score.get("tiebreak", false) else GameData.POINT_NAMES[mini(pts[side], 3)]
		var s := 1.0 + 0.6 * pop * pop
		ci.draw_set_transform(box.get_center(), 0.0, Vector2.ONE * s)
		_txt(ci, Vector2(0, -2), ps, 48, RED.darkened(0.3) if golden else INK, 0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# nome + games em bolinhas
		var nx: float = rect.position.x + 24.0 if side == 0 else rect.end.x - 24.0
		var nm: String = team["name"]
		if vs_mode:
			nm = ("J1 " if side == 0 else "J2 ") + nm
		var fs := 30
		var tw := FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_txt(ci, Vector2(nx if side == 0 else nx - tw, top + 22), nm, fs, Color.WHITE, 9, false)
		var target: int = score["target"]
		if int(score["games"][side]) > target:
			target = int(score["games"][side])
		for g in target:
			var gx: float = nx + 10.0 + g * 21.0 if side == 0 else nx - 10.0 - g * 21.0
			var gp := Vector2(gx, top + 48)
			ci.draw_circle(gp, 9, INK)
			ci.draw_circle(gp, 6.5, YELLOW if g < int(score["games"][side]) else Color(1, 1, 1, 0.3))
		# saque
		if score["serving"] == side and in_game:
			var sx: float = rect.position.x - 26.0 if side == 0 else rect.end.x + 26.0
			var sp := Vector2(sx, top + ph * 0.5 - 6)
			ci.draw_circle(sp, 15, INK)
			ci.draw_circle(sp, 11, Color("d8ff3e"))
			ci.draw_arc(sp + Vector2(-11, 0), 9, -0.9, 0.9, 8, Color.WHITE, 2.5)
			_txt(ci, sp + Vector2(0, 26), "SAQUE", 16, Color.WHITE, 6)
		# barra do especial
		var er := Rect2(rect.position.x + 10.0, top + ph + 8.0, pw - 20.0, 14.0)
		ci.draw_rect(er.grow(3), INK)
		ci.draw_rect(er, Color(0.25, 0.22, 0.32))
		var ev: float = clampf(float(energy[side]), 0.0, 1.0)
		var fill := Rect2(er.position, Vector2(er.size.x * ev, er.size.y))
		if side == 1:
			fill.position.x = er.end.x - fill.size.x
		var full := ev >= 1.0
		var fc := Color("ffe14d").lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 10.0)) if full else Color("ff9f1c")
		ci.draw_rect(fill, fc)
		var stc := Vector2(er.position.x - 4.0 if side == 0 else er.end.x + 4.0, er.get_center().y)
		_star(ci, stc, 14.0 * (1.0 + (0.15 * sin(t * 10.0) if full else 0.0)), YELLOW if full else Color(0.6, 0.58, 0.66), 2.5, t if full else 0.0)
		_txt(ci, Vector2(er.get_center().x, er.get_center().y), "ESPECIAL PRONTO!" if full else "ESPECIAL", 15,
			INK if full else Color(1, 1, 1, 0.8), 0 if full else 5)
	# centro
	var mid := Rect2(cx - 24, top + 14, 48, 36)
	ci.draw_rect(mid.grow(3), INK)
	var tb: bool = score.get("tiebreak", false)
	ci.draw_rect(mid, RED if golden or tb else YELLOW)
	_txt(ci, mid.get_center(), "TB" if tb else "x", 26 if tb else 30, INK, 0)
	if tb:
		_txt(ci, Vector2(cx, top + ph + 44), "TIE-BREAK ATÉ 7", 26, YELLOW, 9)
	if golden:
		var a := 0.6 + 0.4 * sin(t * 8.0)
		_txt(ci, Vector2(cx, top + ph + 44), "PONTO DE OURO!", 28, Color(1, 0.85, 0.3, a), 9, true, Color(INK, a))
