class_name Hud
extends CanvasLayer
## Interface: menu com seleção de personagem, placar, faixas de aviso,
## controles de toque, pausa e tela de fim de jogo.

signal play_pressed
signal rematch_pressed
signal menu_pressed

const FONT := preload("res://assets/fonts/Bangers.woff")
const INK := Color(0.07, 0.04, 0.12)
const YELLOW := Color("ffd23f")

var fx: ComicFX
var touch: TouchControls
var score_panel: Control
var banner: Label
var banner_sub: Label
var hint: Label
var menu: Control
var pause_btn: Button
var pause_panel: Control
var end_panel: Control
var end_title: Label
var end_sub: Label
var help_panel: Control
var char_name: Label
var char_desc: Label
var stat_bars: Array[ProgressBar] = []
var diff_buttons: Array[Button] = []
var len_buttons: Array[Button] = []
var preview_vp: SubViewport
var preview_player: Player
var preview_pivot: Node3D
var theme_main: Theme

var score := {"points": [0, 0], "games": [0, 0], "serving": 0, "golden": false, "target": 2}
var energy := [0.0, 0.0]
var sfx_cb: Callable


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_main = _make_theme()
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
	hint.position = Vector2(-500, 150)
	add_child(hint)

	pause_btn = _button("II", 34, Color.WHITE)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.custom_minimum_size = Vector2(70, 64)
	pause_btn.position = Vector2(-90, 16)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	_build_menu()
	_build_pause()
	_build_end()
	show_menu()


# ---------------------------------------------------------------- estilo

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 32
	return t


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
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	var n := _style(col)
	n.shadow_size = 1
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _style(col.darkened(0.4)))
	b.pressed.connect(func(): _click())
	return b


func _click() -> void:
	if sfx_cb.is_valid():
		sfx_cb.call("click")


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


# ---------------------------------------------------------------- menu

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)

	var title := _label("SMASH NA AREIA", 92, YELLOW, 26)
	title.position = Vector2(40, 18)
	title.rotation = -0.04
	menu.add_child(title)
	var sub := _label("BEACH TENNIS DE GIBI  •  DEMO", 30, Color.WHITE, 12)
	sub.position = Vector2(56, 120)
	sub.rotation = -0.04
	menu.add_child(sub)

	var panel := _panel(Color("fff4e0"))
	panel.position = Vector2(40, 170)
	menu.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	# prévia 3D do personagem (modelo do Blender girando)
	var pv := SubViewportContainer.new()
	pv.stretch = true
	pv.custom_minimum_size = Vector2(220, 300)
	row.add_child(pv)
	preview_vp = SubViewport.new()
	preview_vp.own_world_3d = true
	preview_vp.transparent_bg = true
	preview_vp.msaa_3d = Viewport.MSAA_2X
	pv.add_child(preview_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.6)
	cam.fov = 38
	preview_vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
	preview_pivot = Node3D.new()
	preview_vp.add_child(preview_pivot)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.8
	cyl.height = 0.12
	disc.mesh = cyl
	disc.position.y = -0.06
	disc.material_override = Toon.make(Color("ffd23f"), {"outline": 0.03})
	preview_vp.add_child(disc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 10)
	col.add_child(pick)
	var prev := _button("<", 34, Color("4fc3ff"))
	prev.custom_minimum_size = Vector2(60, 60)
	prev.pressed.connect(func(): _change_char(-1))
	pick.add_child(prev)
	var namebox := VBoxContainer.new()
	namebox.custom_minimum_size = Vector2(230, 0)
	namebox.add_theme_constant_override("separation", -6)
	pick.add_child(namebox)
	char_name = _label("", 52, Color("ff4b3e"), 12)
	char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	namebox.add_child(char_name)
	char_desc = _label("", 20, INK, 0)
	char_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	namebox.add_child(char_desc)
	var nxt := _button(">", 34, Color("4fc3ff"))
	nxt.custom_minimum_size = Vector2(60, 60)
	nxt.pressed.connect(func(): _change_char(1))
	pick.add_child(nxt)

	for s in ["VELOCIDADE", "FORÇA", "CONTROLE"]:
		var h := HBoxContainer.new()
		col.add_child(h)
		var l := _label(s, 24, INK, 0)
		l.custom_minimum_size = Vector2(130, 0)
		h.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(230, 22)
		bar.min_value = 0.7
		bar.max_value = 1.25
		var bg := _style(Color("e8d9bd"), 3, 10)
		var fg := _style(Color("35e0a1"), 3, 10)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		stat_bars.append(bar)

	col.add_child(_label("DIFICULDADE", 24, INK, 0))
	var drow := HBoxContainer.new()
	col.add_child(drow)
	for i in GameData.DIFFICULTIES.size():
		var b := _button(GameData.DIFFICULTIES[i]["name"], 24, Color.WHITE)
		b.custom_minimum_size = Vector2(118, 46)
		b.pressed.connect(func(): _set_diff(i))
		drow.add_child(b)
		diff_buttons.append(b)
	col.add_child(_label("PARTIDA", 24, INK, 0))
	var lrow := HBoxContainer.new()
	col.add_child(lrow)
	for i in GameData.LENGTHS.size():
		var L: Dictionary = GameData.LENGTHS[i]
		var b := _button("%s (%d GAMES)" % [L["name"], L["games"]], 22, Color.WHITE)
		b.custom_minimum_size = Vector2(178, 46)
		b.pressed.connect(func(): _set_len(i))
		lrow.add_child(b)
		len_buttons.append(b)

	var play := _button("JOGAR!", 64, Color("ff4b3e"))
	play.add_theme_color_override("font_color", Color.WHITE)
	play.add_theme_color_override("font_hover_color", Color.WHITE)
	play.add_theme_color_override("font_outline_color", INK)
	play.add_theme_constant_override("outline_size", 14)
	play.position = Vector2(40, 600)
	play.custom_minimum_size = Vector2(330, 96)
	play.rotation = -0.03
	play.pressed.connect(func(): play_pressed.emit())
	menu.add_child(play)
	var how := _button("COMO JOGAR", 32, YELLOW)
	how.position = Vector2(400, 618)
	how.custom_minimum_size = Vector2(230, 70)
	how.pressed.connect(func(): help_panel.visible = not help_panel.visible)
	menu.add_child(how)

	help_panel = _panel(Color("ffffff"))
	help_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	help_panel.position = Vector2(-600, -280)
	help_panel.visible = false
	add_child(help_panel)
	var hv := VBoxContainer.new()
	help_panel.add_child(hv)
	hv.add_child(_label("COMO JOGAR", 46, Color("ff4b3e"), 10))
	var txt := Label.new()
	txt.theme = theme_main
	txt.add_theme_font_size_override("font_size", 24)
	txt.add_theme_color_override("font_color", INK)
	txt.text = "• No beach tennis a bola NÃO pode quicar: rebata no ar! Um toque por dupla.\n" + \
		"• Analógico: corre. Na batida, a direção mira (lado e profundidade).\n" + \
		"• FORTE: topspin rápido que mergulha.  LOB: alto, cai no fundo.\n" + \
		"• CURTA: slice que flutua e morre perto da rede.  Bolas curvam com efeito!\n" + \
		"• SMASH: com bola alta você pula e crava.  PEIXINHO: mergulho de defesa.\n" + \
		"• Aperte o golpe ANTES: quanto mais cedo, mais o golpe CARREGA (aura colorida).\n" + \
		"• ESTRELA de chance no chão: pare em cima e use o golpe da mesma cor = CHANCE!\n" + \
		"• Bons golpes enchem a barra de energia. Cheia: aperte SUPER para o golpe\n" + \
		"   especial do seu personagem. Quem recebe um super é empurrado para trás!\n" + \
		"• Teclado: WASD, J forte, K lob, L curta, I smash, U super, Espaço, Shift."
	hv.add_child(txt)
	var close := _button("FECHAR", 28, YELLOW)
	close.pressed.connect(func(): help_panel.visible = false)
	hv.add_child(close)
	_refresh_menu()


func _change_char(d: int) -> void:
	GameData.char_index = posmod(GameData.char_index + d, GameData.CHARACTERS.size())
	_refresh_menu()
	if preview_player:
		preview_player.celebrate()


func _set_diff(i: int) -> void:
	GameData.difficulty = i
	_refresh_menu()


func _set_len(i: int) -> void:
	GameData.length_index = i
	_refresh_menu()


func _refresh_menu() -> void:
	var c: Dictionary = GameData.CHARACTERS[GameData.char_index]
	char_name.text = c["name"]
	char_desc.text = "%s  •  SUPER: %s" % [c["desc"], String(Shots.SPECIALS[c["special"]]["name"]).trim_suffix("!")]
	stat_bars[0].value = c["speed"]
	stat_bars[1].value = c["power"]
	stat_bars[2].value = c["control"]
	for i in diff_buttons.size():
		var on := i == GameData.difficulty
		diff_buttons[i].add_theme_stylebox_override("normal", _style(YELLOW if on else Color("ffffff"), 5 if on else 3))
	for i in len_buttons.size():
		var on := i == GameData.length_index
		len_buttons[i].add_theme_stylebox_override("normal", _style(YELLOW if on else Color("ffffff"), 5 if on else 3))
	if preview_player:
		preview_player.queue_free()
	preview_player = Player.new()
	preview_pivot.add_child(preview_player)
	preview_player.setup(c, 0, false)
	preview_player.side = -1.0
	preview_player.reset_state()
	preview_player.rotation.y = 0.0
	preview_player.facing = 0.0


func _process(dt: float) -> void:
	if menu.visible and preview_player:
		preview_pivot.rotation.y += dt * 0.8
		preview_player.facing = 0.0
		preview_player.update(dt)
		if preview_player.state == Player.State.CELEBRATE and preview_player.state_t > 1.3:
			preview_player.state = Player.State.NORMAL
	if banner.visible:
		banner.scale = banner.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * dt))


# ---------------------------------------------------------------- pausa / fim

func _build_pause() -> void:
	pause_panel = _panel(Color("fff4e0"))
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-200, -170)
	pause_panel.custom_minimum_size = Vector2(400, 0)
	pause_panel.visible = false
	add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pause_panel.add_child(v)
	var t := _label("PAUSA", 64, YELLOW, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var cont := _button("CONTINUAR", 40, Color("35e0a1"))
	cont.pressed.connect(_on_pause)
	v.add_child(cont)
	var mus := _button("MÚSICA: SIM", 32, Color("4fc3ff"))
	mus.pressed.connect(_toggle_music.bind(mus))
	v.add_child(mus)
	var quit := _button("MENU", 40, Color("ff4b3e"))
	quit.pressed.connect(_quit_to_menu)
	v.add_child(quit)


func _toggle_music(btn: Button) -> void:
	GameData.music_on = not GameData.music_on
	btn.text = "MÚSICA: SIM" if GameData.music_on else "MÚSICA: NÃO"
	if sfx_cb.is_valid():
		sfx_cb.call("music_toggle")


func _quit_to_menu() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	menu_pressed.emit()


func _on_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	touch.reset()


func _build_end() -> void:
	end_panel = _panel(Color("fff4e0"))
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-260, -190)
	end_panel.custom_minimum_size = Vector2(520, 0)
	end_panel.visible = false
	add_child(end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	end_panel.add_child(v)
	end_title = _label("VITÓRIA!", 86, YELLOW, 20)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	end_sub = _label("", 36, INK, 0)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_sub)
	var again := _button("REVANCHE!", 44, Color("35e0a1"))
	again.pressed.connect(func(): rematch_pressed.emit())
	v.add_child(again)
	var m := _button("MENU", 40, Color("4fc3ff"))
	m.pressed.connect(func(): menu_pressed.emit())
	v.add_child(m)


# ---------------------------------------------------------------- API

func show_menu() -> void:
	menu.visible = true
	touch.visible = false
	pause_btn.visible = false
	score_panel.visible = false
	end_panel.visible = false
	pause_panel.visible = false
	hint.text = ""
	banner.visible = false
	banner_sub.visible = false
	_refresh_menu()


func show_game() -> void:
	menu.visible = false
	help_panel.visible = false
	touch.visible = true
	touch.reset()
	pause_btn.visible = true
	score_panel.visible = true
	end_panel.visible = false


func show_end(won: bool, games: Array) -> void:
	touch.visible = false
	pause_btn.visible = false
	end_panel.visible = true
	end_title.text = "VITÓRIA!" if won else "DERROTA!"
	end_title.add_theme_color_override("font_color", YELLOW if won else Color("ff4b3e"))
	end_sub.text = "%s  %d  x  %d  %s" % [GameData.TEAMS[0]["name"], games[0], games[1], GameData.TEAMS[1]["name"]]


func show_banner(text: String, sub: String = "", color: Color = Color.WHITE, time := 1.4) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.scale = Vector2(1.6, 1.6)
	banner.rotation = randf_range(-0.05, 0.05)
	banner_sub.text = sub
	banner_sub.visible = sub != ""
	get_tree().create_timer(time, true, false, true).timeout.connect(_hide_banner.bind(text))


func _hide_banner(text: String) -> void:
	if banner.text == text:
		banner.visible = false
		banner_sub.visible = false


func set_hint(text: String) -> void:
	hint.text = text


func set_energy(e: Array) -> void:
	energy = e.duplicate()
	touch.super_fill = energy[0]
	score_panel.queue_redraw()


func set_score(points: Array, games: Array, serving: int, target: int) -> void:
	score = {"points": points.duplicate(), "games": games.duplicate(), "serving": serving,
		"golden": points[0] == 3 and points[1] == 3, "target": target}
	score_panel.queue_redraw()


func _draw_score() -> void:
	var vs := score_panel.get_viewport_rect().size
	var c := Vector2(vs.x * 0.5, 16)
	var w := 250.0
	var h := 64.0
	var ci := score_panel
	for side in [0, 1]:
		var team: Dictionary = GameData.TEAMS[side]
		var x0: float = c.x - w - 46.0 if side == 0 else c.x + 46.0
		var rect := Rect2(x0, c.y, w, h)
		ci.draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color(INK, 0.5))
		ci.draw_rect(rect, INK)
		ci.draw_rect(rect.grow(-4), team["shirt"])
		var name_x: float = x0 + 16.0 if side == 0 else x0 + w - 16.0
		var nm: String = team["name"]
		var fs := 34
		var tw := FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var px: float = name_x if side == 0 else name_x - tw
		ci.draw_string_outline(FONT, Vector2(px, c.y + 46), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, INK)
		ci.draw_string(FONT, Vector2(px, c.y + 46), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		# games
		var gx: float = x0 + w - 44.0 if side == 0 else x0 + 8.0
		ci.draw_rect(Rect2(gx, c.y + 8, 36, 48), INK)
		ci.draw_rect(Rect2(gx + 3, c.y + 11, 30, 42), Color.WHITE)
		var g := str(score["games"][side])
		var gw := FONT.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		ci.draw_string(FONT, Vector2(gx + 18 - gw * 0.5, c.y + 48), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, INK)
		# barra de energia do super
		var er := Rect2(x0 + 6.0, c.y + h + 6.0, w - 12.0, 12.0)
		ci.draw_rect(er.grow(3), INK)
		ci.draw_rect(er, Color(0.25, 0.22, 0.32))
		var ev: float = clampf(float(energy[side]), 0.0, 1.0)
		var fill := Rect2(er.position, Vector2(er.size.x * ev, er.size.y))
		if side == 1:
			fill.position.x = er.end.x - fill.size.x
		ci.draw_rect(fill, Color("ffe14d") if ev >= 1.0 else Color("ff9f1c"))
		if score["serving"] == side:
			var bx: float = x0 - 22.0 if side == 0 else x0 + w + 22.0
			ci.draw_circle(Vector2(bx, c.y + h * 0.5), 14, INK)
			ci.draw_circle(Vector2(bx, c.y + h * 0.5), 10, Color("ffe14d"))
	# pontos no meio
	var mid := Rect2(c.x - 46, c.y - 4, 92, h + 16)
	ci.draw_rect(Rect2(mid.position + Vector2(5, 7), mid.size), Color(INK, 0.5))
	ci.draw_rect(mid, INK)
	ci.draw_rect(mid.grow(-4), YELLOW)
	var pts: Array = score["points"]
	var s := "%s-%s" % [GameData.POINT_NAMES[mini(pts[0], 3)], GameData.POINT_NAMES[mini(pts[1], 3)]]
	var fs2 := 38 if s.length() <= 4 else 30
	var sw := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	ci.draw_string(FONT, Vector2(c.x - sw * 0.5, c.y + 50), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, INK)
	var tgt := "ATÉ %d GAMES" % score["target"]
	var tw2 := FONT.get_string_size(tgt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	ci.draw_string_outline(FONT, Vector2(c.x - tw2 * 0.5, c.y + h + 40), tgt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 8, INK)
	ci.draw_string(FONT, Vector2(c.x - tw2 * 0.5, c.y + h + 40), tgt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
