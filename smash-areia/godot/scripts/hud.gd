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
var play_btn: Button
var mode_buttons: Array[Button] = []
var p2_box: Control
var p2_name: Label
var pads_label: Label
var split_line: ColorRect
var again_btn: Button
var cont_btn: Button
var sfx_cb: Callable


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_main = _make_theme()
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
	# navegável com controle (D-pad + A) nos menus
	b.focus_mode = Control.FOCUS_ALL
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = Color("ffd23f")
	fs.set_border_width_all(6)
	fs.set_corner_radius_all(20)
	fs.expand_margin_left = 4
	fs.expand_margin_right = 4
	fs.expand_margin_top = 4
	fs.expand_margin_bottom = 4
	b.add_theme_stylebox_override("focus", fs)
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
	play.pressed.connect(func():
		if sfx_cb.is_valid():
			sfx_cb.call("ui_start")
		play_pressed.emit()
	)
	menu.add_child(play)
	play_btn = play
	_build_modes()
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
		"• DEFESA: bola alta e segura, alcança mais e aguenta pancada.\n" + \
		"• Controle: A forte, X lob, B curta, Y smash, RT defesa, RB super, LB peixinho.\n" + \
		"• Teclado: WASD, J forte, K lob, L curta, I smash, O defesa, U super, Shift."
	hv.add_child(txt)
	var close := _button("FECHAR", 28, YELLOW)
	close.pressed.connect(func(): help_panel.visible = false)
	hv.add_child(close)
	_refresh_menu()


## Modos: 1 jogador, VS com tela dividida ou co-op (2 jogadores na mesma dupla)
func _build_modes() -> void:
	var mp := _panel(Color("fff4e0"))
	mp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mp.position = Vector2(-560, -250)
	menu.add_child(mp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mp.add_child(v)
	v.add_child(_label("MODO", 24, INK, 0))
	var row := HBoxContainer.new()
	v.add_child(row)
	var modes := [["solo", "1 JOGADOR"], ["vs", "VS (2P)"], ["coop", "CO-OP (2P)"]]
	for m in modes:
		var b := _button(m[1], 24, Color.WHITE)
		b.custom_minimum_size = Vector2(160, 50)
		var id: String = m[0]
		b.pressed.connect(func(): _set_mode(id))
		row.add_child(b)
		mode_buttons.append(b)
	p2_box = HBoxContainer.new()
	p2_box.add_theme_constant_override("separation", 10)
	v.add_child(p2_box)
	p2_box.add_child(_label("J2:", 30, Color("1f9fd6"), 0))
	var pv := _button("<", 28, Color("4fc3ff"))
	pv.custom_minimum_size = Vector2(52, 50)
	pv.pressed.connect(func(): _change_p2(-1))
	p2_box.add_child(pv)
	p2_name = _label("", 34, Color("1f9fd6"), 8)
	p2_name.custom_minimum_size = Vector2(150, 0)
	p2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_box.add_child(p2_name)
	var nx := _button(">", 28, Color("4fc3ff"))
	nx.custom_minimum_size = Vector2(52, 50)
	nx.pressed.connect(func(): _change_p2(1))
	p2_box.add_child(nx)
	pads_label = _label("", 20, INK, 0)
	v.add_child(pads_label)


func _set_mode(m: String) -> void:
	GameData.mode = m
	_refresh_menu()


func _change_p2(d: int) -> void:
	GameData.char_index_p2 = posmod(GameData.char_index_p2 + d, GameData.CHARACTERS.size())
	if GameData.char_index_p2 == GameData.char_index:
		GameData.char_index_p2 = posmod(GameData.char_index_p2 + d, GameData.CHARACTERS.size())
	_refresh_menu()


func set_split(on: bool) -> void:
	if split_line == null:
		split_line = ColorRect.new()
		split_line.color = INK
		split_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		split_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
		add_child(split_line)
		move_child(split_line, 0)
	var vs := get_viewport().get_visible_rect().size
	split_line.set_anchors_preset(Control.PRESET_TOP_LEFT)
	split_line.size = Vector2(8, vs.y)
	split_line.position = Vector2(vs.x * 0.5 - 4, 0)
	split_line.visible = on
	if not menu.visible:
		touch.visible = not on and not end_panel.visible


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
	var ids := ["solo", "vs", "coop"]
	for i in mode_buttons.size():
		var on2: bool = ids[i] == GameData.mode
		mode_buttons[i].add_theme_stylebox_override("normal", _style(YELLOW if on2 else Color("ffffff"), 5 if on2 else 3))
	if p2_box:
		if GameData.char_index_p2 == GameData.char_index:
			GameData.char_index_p2 = (GameData.char_index + 2) % GameData.CHARACTERS.size()
		p2_box.visible = GameData.mode != "solo"
		p2_name.text = GameData.CHARACTERS[GameData.char_index_p2]["name"]
		var n := Input.get_connected_joypads().size()
		var t := "Controles conectados: %d" % n
		if GameData.mode == "vs":
			t += "  (VS: J1 teclado/controle, J2 controle)"
		elif GameData.mode == "coop":
			t += "  (CO-OP: J2 no controle)"
		pads_label.text = t
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
	if replay_layer and replay_layer.visible:
		replay_t += dt
		replay_layer.queue_redraw()


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
	cont_btn = cont
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
	if sfx_cb.is_valid():
		sfx_cb.call("pause_on" if p else "pause_off")
	if p and cont_btn:
		cont_btn.grab_focus()
	elif not p:
		get_viewport().gui_release_focus()


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
	again_btn = again
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
	if play_btn:
		play_btn.grab_focus.call_deferred()


func show_game() -> void:
	menu.visible = false
	help_panel.visible = false
	get_viewport().gui_release_focus()
	touch.visible = GameData.mode != "vs"
	touch.reset()
	pause_btn.visible = true
	score_panel.visible = true
	end_panel.visible = false


func show_end(won: bool, games: Array, vs := false) -> void:
	touch.visible = false
	pause_btn.visible = false
	end_panel.visible = true
	if vs:
		end_title.text = "J1 VENCEU!" if won else "J2 VENCEU!"
		end_title.add_theme_color_override("font_color", YELLOW if won else Color("4fe0ff"))
	else:
		end_title.text = "VITÓRIA!" if won else "DERROTA!"
		end_title.add_theme_color_override("font_color", YELLOW if won else Color("ff4b3e"))
	if again_btn:
		again_btn.grab_focus.call_deferred()
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


var replay_layer: Control
var replay_t := 0.0


func set_replay(on: bool) -> void:
	if replay_layer == null:
		replay_layer = Control.new()
		replay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		replay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		replay_layer.draw.connect(_draw_replay)
		add_child(replay_layer)
		move_child(replay_layer, 1)
	replay_layer.visible = on
	if not menu.visible:
		touch.visible = not on and GameData.mode != "vs"
		score_panel.visible = not on
	if on:
		hint.text = ""
		banner.visible = false
		banner_sub.visible = false


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
