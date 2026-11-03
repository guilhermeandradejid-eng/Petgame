class_name OnlineMenu
extends Control
## Telas do modo ONLINE (só no PC):
##  - LOBBY: seu nome, quantos jogam neste PC (1 ou 2, modo híbrido), lista de
##    salas públicas, criar sala (pública ou privada) e entrar com código;
##  - SALA: código grande para passar aos amigos, as 4 vagas por time (humanos de
##    cada PC + CPU), troca de personagem dos jogadores locais, opções do
##    anfitrião (modo, arena, partida, CPU, pública/privada), voz e COMEÇAR.

var hud: Hud
var online: Online
var panel: PanelContainer
var title: Label
var status: Label
var lobby_box: Control
var room_box: Control
var name_edit: LineEdit
var locals_btn: Button
var list_box: VBoxContainer
var empty_label: Label
var code_edit: LineEdit
var code_label: Label
var slot_labels: Array[Label] = []
var char_btns: Array[Button] = []
var opt_btns := {}
var mic_btn: Button
var vol_btn: Button
var mic_bar: ProgressBar
var start_btn: Button
var wait_label: Label
var refresh_t := 0.0


func _init(h: Hud, o: Online) -> void:
	hud = h
	online = o


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = hud._panel(Hud.CREAM)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_top = -340
	panel.offset_right = 560
	panel.offset_bottom = 340
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	title = hud._label("ONLINE", 52, Hud.RED, 12)
	title.custom_minimum_size = Vector2(560, 0)
	top.add_child(title)
	status = hud._label("", 22, Hud.INK, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.custom_minimum_size = Vector2(480, 0)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(status)
	var body := Control.new()
	body.custom_minimum_size = Vector2(1060, 560)
	v.add_child(body)
	lobby_box = Control.new()
	lobby_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(lobby_box)
	room_box = Control.new()
	room_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(room_box)
	_build_lobby()
	_build_room()
	online.lobby_changed.connect(_refresh_list)
	online.room_changed.connect(_refresh)
	online.status.connect(func(s: String): status.text = s)


func _edit(size: int, placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.theme = hud.theme_main
	e.add_theme_font_size_override("font_size", size)
	e.add_theme_color_override("font_color", Hud.INK)
	e.add_theme_color_override("font_placeholder_color", Color(Hud.INK, 0.4))
	var sb := hud._style(Color.WHITE, 4, 14)
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", hud._style(Color("fff6c8"), 5, 14))
	e.placeholder_text = placeholder
	e.max_length = max_len
	return e


# ---------------------------------------------------------------- lobby

func _build_lobby() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby_box.add_child(h)
	# esquerda: salas públicas
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(hud._label("SALAS PÚBLICAS", 32, Color("2f6cd6"), 0))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	left.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	sc.add_child(list_box)
	empty_label = hud._label("Procurando salas...\nNenhuma ainda? Crie uma e chame os amigos!", 24, Color(Hud.INK, 0.6), 0)
	list_box.add_child(empty_label)
	# direita: nome, jogadores neste PC, criar, código
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	right.add_child(hud._label("SEU NOME", 26, Color("2f6cd6"), 0))
	name_edit = _edit(30, "NOME", 12)
	name_edit.custom_minimum_size = Vector2(430, 58)
	name_edit.text_submitted.connect(func(_t: String): online.set_my_name(name_edit.text))
	name_edit.focus_exited.connect(func(): online.set_my_name(name_edit.text))
	right.add_child(name_edit)
	locals_btn = hud._button("", 26, Color.WHITE)
	locals_btn.custom_minimum_size = Vector2(430, 56)
	locals_btn.pressed.connect(func():
		GameData.online_locals = 2 if GameData.online_locals == 1 else 1
		_refresh()
		online._send_my_info()
	)
	right.add_child(locals_btn)
	var pub := hud._button("CRIAR SALA PÚBLICA", 28, Hud.GREEN)
	pub.custom_minimum_size = Vector2(430, 62)
	pub.pressed.connect(func():
		online.set_my_name(name_edit.text)
		online.host(true))
	right.add_child(pub)
	var priv := hud._button("CRIAR SALA PRIVADA", 28, Hud.YELLOW)
	priv.custom_minimum_size = Vector2(430, 62)
	priv.pressed.connect(func():
		online.set_my_name(name_edit.text)
		online.host(false))
	right.add_child(priv)
	right.add_child(hud._label("ENTRAR COM CÓDIGO", 26, Color("2f6cd6"), 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	right.add_child(row)
	code_edit = _edit(34, "K7QPM", 6)
	code_edit.custom_minimum_size = Vector2(250, 62)
	code_edit.text_changed.connect(func(tx: String):
		var c := code_edit.caret_column
		code_edit.text = tx.to_upper()
		code_edit.caret_column = c)
	code_edit.text_submitted.connect(func(_t: String): _join_code())
	row.add_child(code_edit)
	var jb := hud._button("ENTRAR", 28, Hud.CYAN)
	jb.custom_minimum_size = Vector2(170, 62)
	jb.pressed.connect(_join_code)
	row.add_child(jb)
	var back := hud._button("< VOLTAR", 28, Color.WHITE)
	back.custom_minimum_size = Vector2(430, 58)
	back.pressed.connect(close)
	right.add_child(back)
	lobby_box.set_meta("first", pub)


func _join_code() -> void:
	online.set_my_name(name_edit.text)
	online.join(code_edit.text)


func _refresh_list() -> void:
	for c in list_box.get_children():
		if c != empty_label:
			c.queue_free()
	var codes: Array = online.public_rooms.keys()
	empty_label.visible = codes.is_empty()
	for c in codes:
		var r: Dictionary = online.public_rooms[c]
		var full := int(r.get("humans", 0)) >= int(r.get("max", 4))
		var arena_name: String = GameData.ARENAS[clampi(int(r.get("arena", 0)), 0, GameData.ARENAS.size() - 1)]["name"]
		var b := hud._button("%s   %d/%d   %s   %s" % [String(r.get("name", "SALA")).left(22), int(r.get("humans", 1)),
			int(r.get("max", 4)), "CO-OP" if r.get("mode", "vs") == "coop" else "VS", arena_name], 22,
			Color(0.85, 0.85, 0.85) if full else Color.WHITE)
		b.custom_minimum_size = Vector2(580, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = full
		b.pressed.connect(func():
			online.set_my_name(name_edit.text)
			online.join(String(c)))
		list_box.add_child(b)


# ---------------------------------------------------------------- sala

func _build_room() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	code_label = hud._label("", 40, Hud.INK, 0)
	code_label.custom_minimum_size = Vector2(430, 0)
	top.add_child(code_label)
	var copy := hud._button("COPIAR CÓDIGO", 24, Hud.YELLOW)
	copy.custom_minimum_size = Vector2(230, 52)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(online.code)
		status.text = "Código %s copiado!" % online.code)
	top.add_child(copy)
	# times e vagas
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 30)
	v.add_child(teams)
	for team in 2:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(515, 0)
		col.add_theme_constant_override("separation", 4)
		teams.add_child(col)
		var tc: Color = GameData.TEAMS[team]["shirt"]
		col.add_child(hud._label(GameData.TEAMS[team]["name"], 30, tc.darkened(0.15), 0))
		for k in 2:
			var l := hud._label("", 26, Hud.INK, 0)
			l.custom_minimum_size = Vector2(515, 40)
			col.add_child(l)
			slot_labels.append(l)
	# personagens dos jogadores deste PC
	var chars := HBoxContainer.new()
	chars.add_theme_constant_override("separation", 14)
	v.add_child(chars)
	for li in 2:
		var b := hud._button("", 24, Color.WHITE)
		b.custom_minimum_size = Vector2(380, 52)
		b.pressed.connect(_cycle_char.bind(li))
		chars.add_child(b)
		char_btns.append(b)
	var ploc := hud._button("", 24, Color.WHITE)
	ploc.custom_minimum_size = Vector2(250, 52)
	ploc.pressed.connect(func():
		GameData.online_locals = 2 if GameData.online_locals == 1 else 1
		online._send_my_info()
		_refresh())
	chars.add_child(ploc)
	opt_btns["locals"] = ploc
	# opções do anfitrião
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	for id in ["mode", "arena", "len", "diff", "public"]:
		var b := hud._button("", 22, Color.WHITE)
		b.custom_minimum_size = Vector2(345, 48)
		b.pressed.connect(_cycle_opt.bind(id))
		g.add_child(b)
		opt_btns[id] = b
	# voz
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 12)
	v.add_child(vrow)
	mic_btn = hud._button("", 22, Hud.CYAN)
	mic_btn.custom_minimum_size = Vector2(400, 48)
	mic_btn.pressed.connect(func():
		online.voice.cycle_mode()
		_refresh())
	vrow.add_child(mic_btn)
	vol_btn = hud._button("", 22, Color.WHITE)
	vol_btn.custom_minimum_size = Vector2(260, 48)
	vol_btn.pressed.connect(func():
		var vv := online.voice.volume + 0.25
		online.voice.volume = 0.0 if vv > 1.51 else vv
		online.voice.save()
		_refresh())
	vrow.add_child(vol_btn)
	mic_bar = ProgressBar.new()
	mic_bar.custom_minimum_size = Vector2(150, 22)
	mic_bar.max_value = 1.0
	mic_bar.show_percentage = false
	mic_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vrow.add_child(mic_bar)
	# rodapé
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	var leave := hud._button("SAIR DA SALA", 28, Hud.RED)
	leave.custom_minimum_size = Vector2(260, 62)
	leave.pressed.connect(func(): online.leave())
	bottom.add_child(leave)
	wait_label = hud._label("", 24, Color(Hud.INK, 0.7), 0)
	wait_label.custom_minimum_size = Vector2(420, 0)
	wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(wait_label)
	start_btn = hud._big_button("COMEÇAR!", 40, Hud.GREEN)
	start_btn.custom_minimum_size = Vector2(300, 66)
	start_btn.pressed.connect(func(): online.start_match())
	bottom.add_child(start_btn)
	room_box.set_meta("first", start_btn)


func _cycle_char(li: int) -> void:
	var n := GameData.CHARACTERS.size()
	if li == 0:
		GameData.char_index = (GameData.char_index + 1) % n
		if GameData.online_locals > 1 and GameData.char_index == GameData.char_index_p2:
			GameData.char_index = (GameData.char_index + 1) % n
	else:
		GameData.char_index_p2 = (GameData.char_index_p2 + 1) % n
		if GameData.char_index_p2 == GameData.char_index:
			GameData.char_index_p2 = (GameData.char_index_p2 + 1) % n
	online._send_my_info()
	_refresh()


func _cycle_opt(id: String) -> void:
	if not online.is_host():
		return
	match id:
		"mode":
			online.set_option("mode", "coop" if online.opts["mode"] == "vs" else "vs")
		"arena":
			online.set_option("arena", (int(online.opts["arena"]) + 1) % GameData.ARENAS.size())
		"len":
			online.set_option("len", (int(online.opts["len"]) + 1) % GameData.LENGTHS.size())
		"diff":
			online.set_option("diff", (int(online.opts["diff"]) + 1) % GameData.DIFFICULTIES.size())
		"public":
			online.set_option("public", not bool(online.opts["public"]))
	_refresh()


# ---------------------------------------------------------------- geral

func open() -> void:
	visible = true
	name_edit.text = online.my_name
	if not online.available():
		status.text = "O online precisa da extensão WebRTC (só no PC: Windows ou Linux)."
	else:
		online.open_lobby()
	_refresh()
	_refresh_list()
	_focus_first.call_deferred()


func close() -> void:
	online.set_my_name(name_edit.text)
	if online.active():
		online.leave()
	online.close_lobby()
	visible = false
	hud._on_online_closed()


func _focus_first() -> void:
	var f: Control = (room_box if online.active() else lobby_box).get_meta("first")
	if f and f.is_visible_in_tree():
		f.grab_focus()


func _refresh() -> void:
	var in_room := online.active()
	lobby_box.visible = not in_room
	room_box.visible = in_room
	locals_btn.text = "JOGADORES NESTE PC: %d" % GameData.online_locals
	if not in_room:
		title.text = "ONLINE"
		return
	var host := online.is_host()
	title.text = "SALA" + (" (ANFITRIÃO)" if host else "")
	code_label.text = "CÓDIGO: %s" % online.code if online.code != "" else "CONECTANDO..."
	var connected := host or not online.members.is_empty()
	for i in 4:
		var l := slot_labels[i]
		if i >= online.slots.size():
			l.text = "  ..."
			continue
		var s: Dictionary = online.slots[i]
		if s["kind"] == "human":
			var who := String(s["name"])
			var cn: String = GameData.CHARACTERS[int(s.get("char", 0))]["name"]
			var talk := "  ♪" if online.voice.is_speaking(int(s["owner"])) else ""
			var me := "  (VOCÊ)" if int(s["owner"]) == online.my_id() else ""
			l.text = "  %s  •  %s%s%s" % [who, cn.to_upper(), me, talk]
			l.add_theme_color_override("font_color", Hud.INK)
		else:
			l.text = "  CPU"
			l.add_theme_color_override("font_color", Color(Hud.INK, 0.45))
	for li in 2:
		var b := char_btns[li]
		b.visible = li < GameData.online_locals
		var ci := GameData.char_index if li == 0 else GameData.char_index_p2
		b.text = "J%d: %s  ▶" % [li + 1, String(GameData.CHARACTERS[ci]["name"]).to_upper()]
	(opt_btns["locals"] as Button).text = "NESTE PC: %d" % GameData.online_locals
	var o: Dictionary = online.opts
	var L: Dictionary = GameData.LENGTHS[int(o["len"])]
	(opt_btns["mode"] as Button).text = "MODO: %s" % ("CO-OP" if o["mode"] == "coop" else "VERSUS")
	(opt_btns["arena"] as Button).text = "ARENA: %s" % GameData.ARENAS[int(o["arena"])]["name"]
	(opt_btns["len"] as Button).text = "PARTIDA: %s" % L["name"]
	(opt_btns["diff"] as Button).text = "CPU: %s" % GameData.DIFFICULTIES[int(o["diff"])]["name"]
	(opt_btns["public"] as Button).text = "SALA: %s" % ("PÚBLICA" if o["public"] else "PRIVADA")
	for id in ["mode", "arena", "len", "diff", "public"]:
		(opt_btns[id] as Button).disabled = not host
	mic_btn.text = "VOZ: " + VoiceChat.MODE_NAMES[online.voice.mode]
	vol_btn.text = "VOLUME DAS VOZES: %d%%" % int(round(online.voice.volume * 100.0))
	start_btn.visible = host
	wait_label.text = "" if host else ("Aguardando o anfitrião começar..." if connected else "Procurando a sala...")
	if host:
		wait_label.text = "Passe o código ou espere entrarem."


func _process(dt: float) -> void:
	if not visible:
		return
	refresh_t -= dt
	mic_bar.value = online.voice.level * 8.0
	if refresh_t <= 0.0:
		refresh_t = 0.25
		if online.active():
			_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			if jb.pressed and get_viewport().gui_get_focus_owner() == null:
				_focus_first()
			return
		get_viewport().set_input_as_handled()
		if not jb.pressed:
			return
		match jb.button_index:
			JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y:
				var f := get_viewport().gui_get_focus_owner()
				if f is BaseButton and is_ancestor_of(f) and not (f as BaseButton).disabled:
					(f as BaseButton).pressed.emit()
				else:
					_focus_first()
			JOY_BUTTON_B:
				hud._click()
				if online.active():
					online.leave()
				else:
					close()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if online.active():
				online.leave()
			else:
				close()
