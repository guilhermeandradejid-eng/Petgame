class_name OptionsMenu
extends Control
## Tela de OPÇÕES (no menu de modos e na pausa), com três abas:
##  - GRÁFICOS: qualidade, pós-processamento e desempenho;
##  - CONTROLES: remapeia teclas do J1 e do J2 e os botões do controle
##    (clique na célula e aperte a tecla/botão; Esc ou Start cancela);
##  - TOQUE: lado dos botões (canhoto), tamanho e visibilidade.
## Funciona no toque, mouse, teclado e controle (D-pad + A, B volta).

signal changed            # opções de gráfico/toque mudaram (reaplicar)
signal closed

var hud: Hud
var panel: PanelContainer
var tabs: Array[Button] = []
var pages: Array[Control] = []
var tab := 0
var gfx_btns := {}
var ctl_cells := {}       # "col|action" -> Button
var touch_btns := {}
var listen := {}          # célula esperando tecla/botão: {"col", "action", "btn"}
var listen_t := 0.0
var status: Label
var axis_prev := {}


func _init(h: Hud) -> void:
	hud = h


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	panel = hud._panel(Hud.CREAM)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1060, 640)
	panel.offset_left = -530
	panel.offset_top = -330
	panel.offset_right = 530
	panel.offset_bottom = 330
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	var title := hud._label("OPÇÕES", 54, Hud.RED, 12)
	title.custom_minimum_size = Vector2(250, 0)
	top.add_child(title)
	for i in 3:
		var b := hud._button(["GRÁFICOS", "CONTROLES", "TOQUE"][i], 30, Color.WHITE)
		b.custom_minimum_size = Vector2(230, 58)
		b.pressed.connect(_set_tab.bind(i))
		top.add_child(b)
		tabs.append(b)
	var body := Control.new()
	body.custom_minimum_size = Vector2(1000, 452)
	v.add_child(body)
	for i in 3:
		var sc := ScrollContainer.new()
		sc.set_anchors_preset(Control.PRESET_FULL_RECT)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		body.add_child(sc)
		pages.append(sc)
	_build_gfx(pages[0])
	_build_controls(pages[1])
	_build_touch(pages[2])
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	status = hud._label("", 24, Hud.INK, 0)
	status.custom_minimum_size = Vector2(590, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	bottom.add_child(status)
	var reset := hud._button("PADRÃO", 30, Hud.YELLOW)
	reset.custom_minimum_size = Vector2(190, 62)
	reset.pressed.connect(_reset_page)
	bottom.add_child(reset)
	var back := hud._button("VOLTAR", 30, Hud.GREEN)
	back.custom_minimum_size = Vector2(190, 62)
	back.pressed.connect(close)
	bottom.add_child(back)
	set_meta("back", back)
	_set_tab(0)


func open() -> void:
	visible = true
	listen = {}
	_refresh()
	_set_tab(tab)


func close() -> void:
	if not visible:
		return
	_stop_listen()
	Settings.save()
	visible = false
	closed.emit()


func _set_tab(i: int) -> void:
	tab = i
	_stop_listen()
	for k in 3:
		pages[k].visible = k == i
		var col := Hud.YELLOW if k == i else Color.WHITE
		tabs[k].add_theme_stylebox_override("normal", hud._style(col))
	match i:
		0:
			status.text = "ALTA: mais nitidez e raios de sol. No celular, MÉDIA ou BAIXA economizam bateria."
		1:
			status.text = "Toque numa célula e aperte a nova tecla ou botão.  ESC / START cancela."
		2:
			status.text = "Ajuste os botões de toque da partida."
	if visible:
		var first := _first_button(pages[i])
		if first:
			first.grab_focus.call_deferred()
		else:
			tabs[i].grab_focus.call_deferred()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).focus_mode != Control.FOCUS_NONE and not (c as Button).disabled:
			return c
		var r := _first_button(c)
		if r:
			return r
	return null


# ---------------------------------------------------------------- gráficos

const GFX_ROWS := [
	["quality", "QUALIDADE"], ["postfx", "PÓS-PROCESSAMENTO"],
	["bloom", "BRILHO (BLOOM)"], ["sun_rays", "RAIOS DE SOL"],
	["color_grade", "CORES DE CINEMA"], ["vignette", "VINHETA"],
	["impact_fx", "EFEITO NAS PANCADAS"], ["grain", "GRANULADO DE FILME"],
	["msaa", "ANTISSERRILHADO"], ["scale", "RESOLUÇÃO 3D"],
	["fps_cap", "LIMITE DE FPS"], ["show_fps", "MOSTRAR FPS"],
	["shake", "TREMIDA DA CÂMERA"], ["split_swap", "TELA DIVIDIDA"],
	["fullscreen", "TELA CHEIA (F11)"],
	["vsync", "VSYNC"],
]


func _build_gfx(page: Control) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 10)
	page.add_child(g)
	for row in GFX_ROWS:
		var id: String = row[0]
		if (id == "fullscreen" or id == "vsync") and OS.has_feature("mobile"):
			continue
		var b := hud._button("", 25, Color.WHITE)
		b.custom_minimum_size = Vector2(486, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_cycle_gfx.bind(id))
		b.set_meta("label", row[1])
		g.add_child(b)
		gfx_btns[id] = b


func _cycle_gfx(id: String) -> void:
	match id:
		"quality":
			Settings.apply_preset((Settings.quality + 1) % 3)
		"msaa":
			Settings.msaa = {0: 2, 2: 4, 4: 0}.get(Settings.msaa, 2)
		"scale":
			Settings.scale_index = (Settings.scale_index + 1) % Settings.SCALES.size()
		"fps_cap":
			Settings.fps_cap = (Settings.fps_cap + 1) % Settings.FPS_CAPS.size()
		_:
			Settings.set_flag(id, not Settings.get_flag(id))
	Settings.save()
	_refresh()
	changed.emit()


func _gfx_value(id: String) -> String:
	match id:
		"quality":
			return Settings.QUALITY_NAMES[Settings.quality]
		"msaa":
			return "DESLIGADO" if Settings.msaa == 0 else "%dX" % Settings.msaa
		"scale":
			return "%d%%" % int(round(Settings.render_scale() * 100.0))
		"fps_cap":
			var c: int = Settings.FPS_CAPS[Settings.fps_cap]
			return "SEM LIMITE" if c == 0 else str(c)
		"split_swap":
			return "J2 | J1" if Settings.split_swap else "J1 | J2"
	return "SIM" if Settings.get_flag(id) else "NÃO"


# ---------------------------------------------------------------- controles

func _build_controls(page: Control) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 8)
	page.add_child(g)
	for h in ["AÇÃO", "TECLADO J1", "TECLADO J2", "CONTROLE"]:
		var l := hud._label(h, 26, Hud.RED, 0)
		l.custom_minimum_size = Vector2(220 if h == "AÇÃO" else 236, 34)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if h != "AÇÃO" else HORIZONTAL_ALIGNMENT_LEFT
		g.add_child(l)
	var rows: Array = []
	for m in [["move_up", "MOVER  ↑"], ["move_down", "MOVER  ↓"], ["move_left", "MOVER  ←"], ["move_right", "MOVER  →"]]:
		rows.append({"name": m[1], "key": m[0], "p2": Settings.MOVE_ACTIONS[m[0]], "pad": ""})
	for a in Settings.ACTIONS:
		rows.append({"name": a["name"], "key": a["key"], "p2": a["p2"], "pad": a["id"]})
	for r in rows:
		var l := hud._label(r["name"], 25, Color("2f6cd6"), 0)
		l.custom_minimum_size = Vector2(220, 46)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_child(l)
		for col in ["key", "p2", "pad"]:
			var act: String = r[col]
			if act == "":
				var na := hud._label("ANALÓGICO / D-PAD" if col == "pad" else "—", 20, Color(Hud.INK, 0.5), 0)
				na.custom_minimum_size = Vector2(236, 46)
				na.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				na.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				g.add_child(na)
				continue
			var b := hud._button("", 25, Color.WHITE)
			b.custom_minimum_size = Vector2(236, 46)
			b.pressed.connect(_start_listen.bind(col, act, b))
			g.add_child(b)
			ctl_cells["%s|%s" % [col, act]] = b


func _start_listen(col: String, action: String, b: Button) -> void:
	_stop_listen()
	listen = {"col": col, "action": action, "btn": b}
	listen_t = 0.0
	b.text = "APERTE..."
	b.add_theme_stylebox_override("normal", hud._style(Hud.YELLOW))
	if col == "pad":
		status.text = "Aperte o botão do controle (START cancela)."
	else:
		status.text = "Aperte a tecla (ESC cancela)."


func _stop_listen() -> void:
	if listen.is_empty():
		return
	var b: Button = listen["btn"]
	b.add_theme_stylebox_override("normal", hud._style(Color.WHITE))
	listen = {}
	_refresh()


func _finish_listen(msg: String) -> void:
	var b: Button = listen.get("btn")
	_stop_listen()
	status.text = msg
	Settings.save()
	hud._sfx("click")
	if b:
		b.grab_focus()


# ---------------------------------------------------------------- toque

func _build_touch(page: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	page.add_child(v)
	for row in [["left", "LADO DOS BOTÕES"], ["size", "TAMANHO DOS BOTÕES"], ["alpha", "VISIBILIDADE"]]:
		var b := hud._button("", 28, Color.WHITE)
		b.custom_minimum_size = Vector2(640, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("label", row[1])
		b.pressed.connect(_cycle_touch.bind(row[0]))
		v.add_child(b)
		touch_btns[row[0]] = b
	var tip := hud._label("CANHOTO: golpes à esquerda e analógico à direita.", 24, Hud.INK, 0)
	v.add_child(tip)


func _cycle_touch(id: String) -> void:
	match id:
		"left":
			Settings.touch_left = not Settings.touch_left
		"size":
			Settings.touch_size = (Settings.touch_size + 1) % 3
		"alpha":
			Settings.touch_alpha = (Settings.touch_alpha + 1) % 3
	Settings.save()
	_refresh()
	changed.emit()


# ---------------------------------------------------------------- geral

func _refresh() -> void:
	for id in gfx_btns:
		var b: Button = gfx_btns[id]
		b.text = "%s:  %s" % [b.get_meta("label"), _gfx_value(id)]
	var on := Settings.postfx
	for id in ["bloom", "sun_rays", "color_grade", "vignette", "impact_fx", "grain"]:
		if gfx_btns.has(id):
			(gfx_btns[id] as Button).modulate = Color(1, 1, 1, 1.0 if on else 0.45)
	for k in ctl_cells:
		var b: Button = ctl_cells[k]
		var col: String = k.get_slice("|", 0)
		var act: String = k.get_slice("|", 1)
		b.text = Settings.pad_name(act) if col == "pad" else Settings.key_name(act)
	for id in touch_btns:
		var b: Button = touch_btns[id]
		var val := ""
		match id:
			"left":
				val = "ESQUERDA (CANHOTO)" if Settings.touch_left else "DIREITA"
			"size":
				val = ["PEQUENO", "MÉDIO", "GRANDE"][Settings.touch_size]
			"alpha":
				val = ["DISCRETA", "NORMAL", "FORTE"][Settings.touch_alpha]
		b.text = "%s:  %s" % [b.get_meta("label"), val]


func _reset_page() -> void:
	match tab:
		0:
			Settings.postfx = true
			Settings.bloom = false
			Settings.color_grade = true
			Settings.vignette = true
			Settings.impact_fx = true
			Settings.grain = false
			Settings.show_fps = false
			Settings.shake = true
			Settings.fps_cap = 1
			Settings.apply_preset(1 if OS.has_feature("mobile") else 2)
		1:
			Settings.reset_controls()
			status.text = "Controles voltaram ao padrão."
		2:
			Settings.touch_left = false
			Settings.touch_size = 1
			Settings.touch_alpha = 1
	Settings.save()
	_refresh()
	changed.emit()


func _process(dt: float) -> void:
	if not listen.is_empty():
		listen_t += dt
		var b: Button = listen["btn"]
		b.text = "APERTE..." if fmod(listen_t, 0.6) < 0.4 else ""
		if listen_t > 8.0:
			_stop_listen()
			status.text = "Tempo esgotado: nada mudou."


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not listen.is_empty():
		_capture(event)
		return
	# navegação própria no controle: A/X/Y confirmam, B/Select voltam, LB/RB trocam de aba
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		var b := jb.button_index
		if b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			if jb.pressed and get_viewport().gui_get_focus_owner() == null:
				_set_tab(tab)
			return   # foco normal do Godot
		get_viewport().set_input_as_handled()
		if not jb.pressed:
			return
		match b:
			JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y:
				var f := get_viewport().gui_get_focus_owner()
				if f is BaseButton and f.is_visible_in_tree() and is_ancestor_of(f):
					(f as BaseButton).pressed.emit()
				else:
					_set_tab(tab)
			JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_START:
				hud._click()
				close()
			JOY_BUTTON_LEFT_SHOULDER:
				_set_tab(posmod(tab - 1, 3))
				hud._sfx("ui_move")
			JOY_BUTTON_RIGHT_SHOULDER:
				_set_tab(posmod(tab + 1, 3))
				hud._sfx("ui_move")
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_ESCAPE or k == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			hud._click()
			close()
		elif k == KEY_Q or k == KEY_E:
			get_viewport().set_input_as_handled()
			_set_tab(posmod(tab + (1 if k == KEY_E else -1), 3))


func _capture(event: InputEvent) -> void:
	var col: String = listen["col"]
	var action: String = listen["action"]
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		if ke.physical_keycode == KEY_ESCAPE:
			_stop_listen()
			status.text = "Cancelado."
			return
		if col == "pad":
			return
		if ke.physical_keycode in [KEY_P, KEY_F11]:
			status.text = "Essa tecla é reservada (pausa / tela cheia)."
			return
		Settings.bind_key(action, ke.physical_keycode)
		_finish_listen("Tecla %s definida." % Settings.key_name(action))
	elif event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		if jb.button_index == JOY_BUTTON_START:
			_stop_listen()
			status.text = "Cancelado."
			return
		if col != "pad":
			return
		if jb.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			status.text = "O D-pad é usado para correr. Escolha outro botão."
			return
		Settings.bind_pad(action, jb.button_index)
		_finish_listen("Botão %s definido." % Settings.pad_name(action))
	elif event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		var jm := event as InputEventJoypadMotion
		if col != "pad":
			return
		if jm.axis == JOY_AXIS_TRIGGER_LEFT or jm.axis == JOY_AXIS_TRIGGER_RIGHT:
			if jm.axis_value > 0.6:
				Settings.bind_pad(action, Settings.PAD_LT if jm.axis == JOY_AXIS_TRIGGER_LEFT else Settings.PAD_RT)
				_finish_listen("Gatilho %s definido." % Settings.pad_name(action))
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		# toque fora da célula cancela
		if event.is_pressed():
			var b: Button = listen["btn"]
			var pos: Vector2 = event.position
			if not b.get_global_rect().has_point(pos):
				get_viewport().set_input_as_handled()
				_stop_listen()
				status.text = "Cancelado."
