class_name Settings
extends Node
## Configurações: áudio (geral, música, efeitos, voz), vídeo (qualidade, resolução 3D, tela cheia, VSync,
## efeitos de tela, FPS), jogo (direção, tremor da câmera, vibração) e controles (referência).
## Fica salvo em save["cfg"] e é aplicado na hora.

const DEFAULTS := {"vol_master": 0.9, "vol_music": 0.75, "vol_sfx": 0.9, "vol_voice": 1.0,
	"quality": "alta", "scale": 1.0, "fullscreen": false, "vsync": true, "screen_fx": true, "fps": false,
	"shake": 1.0, "vibration": true}
const QUALITY := [["baixa", "BAIXA"], ["media", "MÉDIA"], ["alta", "ALTA"]]

var game: Node
var hud: Hud
var scr: Control
var body: VBoxContainer
var tab := "audio"
var back_to := "menu"
var tab_btns := {}
var fps_l: Label


func setup(g: Node, h: Hud) -> void:
	game = g
	hud = h
	var cfg: Dictionary = g.save.get("cfg", {})
	for k in DEFAULTS:
		if not cfg.has(k):
			cfg[k] = DEFAULTS[k]
	if OS.get_name() in ["Android", "iOS", "Web"]:
		cfg.erase("fullscreen")
	g.save.cfg = cfg
	_buses()
	_build()
	fps_l = UI.text(hud.root, "", 14, UI.OK)
	fps_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fps_l.offset_left = -110
	fps_l.offset_top = -26
	apply_all()


func cfg() -> Dictionary:
	return game.save.cfg


func val(k: String):
	return cfg().get(k, DEFAULTS.get(k))


## barramentos de áudio: Música, Efeitos e Voz (cada um com seu volume)
func _buses() -> void:
	for nm in ["Musica", "Efeitos", "Voz"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")


func _set_bus(nm: String, v: float) -> void:
	var i := AudioServer.get_bus_index(nm)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func apply_all() -> void:
	_set_bus("Master", float(val("vol_master")))
	_set_bus("Musica", float(val("vol_music")))
	_set_bus("Efeitos", float(val("vol_sfx")))
	_set_bus("Voz", float(val("vol_voice")))
	var vp := game.get_viewport()
	match String(val("quality")):
		"baixa":
			game.sun.shadow_enabled = false
			vp.msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		"media":
			game.sun.shadow_enabled = true
			vp.msaa_3d = Viewport.MSAA_2X
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			game.sun.shadow_enabled = true
			vp.msaa_3d = Viewport.MSAA_4X
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	vp.scaling_3d_scale = clampf(float(val("scale")), 0.5, 1.0)
	if cfg().has("fullscreen") and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(val("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(val("vsync")) else DisplayServer.VSYNC_DISABLED)
	if fps_l:
		fps_l.visible = bool(val("fps"))


func _process(_dt: float) -> void:
	if fps_l and fps_l.visible:
		fps_l.text = "%d FPS" % Engine.get_frames_per_second()


func _put(k: String, v) -> void:
	cfg()[k] = v
	if k == "steer":
		return
	apply_all()
	game._write_save()


# ------------------------------------------------------------------ tela
func _build() -> void:
	scr = hud._screen(0.86)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 64)
	m.add_theme_constant_override("margin_right", 64)
	m.add_theme_constant_override("margin_top", 36)
	m.add_theme_constant_override("margin_bottom", 30)
	scr.add_child(m)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	m.add_child(outer)
	UI.title(outer, "CONFIGURAÇÕES", 48)
	UI.checker(outer, 330, 10)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(cols)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	cols.add_child(nav)
	for t in [["audio", "ÁUDIO"], ["video", "VÍDEO"], ["jogo", "JOGO"], ["controles", "CONTROLES"], ["creditos", "CRÉDITOS"]]:
		var b := hud._btn(t[1], nav, false, 250, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var key: String = t[0]
		b.pressed.connect(func(): _show_tab(key))
		tab_btns[key] = b
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	var back := hud._btn("VOLTAR", nav, true, 250, 56)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): hud.show_screen(back_to))
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_box(UI.HOT))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	hud.extra_screens["config"] = scr
	scr.visible = false


func open(from: String) -> void:
	back_to = from
	_show_tab(tab)
	hud.show_screen("config")


func _show_tab(t: String) -> void:
	tab = t
	for k in tab_btns:
		UI.style_button(tab_btns[k], k == t, 18)
	for ch in body.get_children():
		ch.queue_free()
	match t:
		"audio":
			_slider("vol_master", "VOLUME GERAL")
			_slider("vol_music", "MÚSICA")
			_slider("vol_sfx", "EFEITOS (MOTOR, TIROS, BATIDAS)")
			_slider("vol_voice", "CHAT DE VOZ")
			_note("O chat de voz liga no lobby online ou no menu de pausa.")
		"video":
			_choice("quality", "QUALIDADE GRÁFICA", QUALITY)
			_note("Baixa: sem sombras e sem antisserrilhado (celulares simples). Média: sombras e MSAA 2x. Alta: sombras suaves e MSAA 4x.")
			_slider("scale", "RESOLUÇÃO 3D", 0.5, 1.0, 0.05)
			_note("Menos de 100% desenha o 3D menor e amplia: mais FPS, imagem mais suave.")
			if cfg().has("fullscreen"):
				_choice("fullscreen", "TELA CHEIA", [[false, "NÃO"], [true, "SIM"]])
			_choice("vsync", "VSYNC (SEM CORTES NA IMAGEM)", [[true, "LIGADO"], [false, "DESLIGADO"]])
			_choice("screen_fx", "EFEITOS DE TELA (BORRÃO, ABERRAÇÃO, LINHAS)", [[true, "LIGADOS"], [false, "DESLIGADOS"]])
			_choice("fps", "MOSTRAR FPS", [[false, "NÃO"], [true, "SIM"]])
		"jogo":
			_steer_row()
			_slider("shake", "TREMOR DA CÂMERA", 0.0, 1.0, 0.05)
			_choice("vibration", "VIBRAÇÃO (CELULAR E CONTROLE)", [[true, "LIGADA"], [false, "DESLIGADA"]])
			_note("Direção TELA: você aponta para onde quer ir na tela. CARRO: esquerda/direita giram o carro (clássico).")
		"controles":
			_ctrl_table()
		"creditos":
			_credits()
	hud._focus_first.call_deferred("config")


func _row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	body.add_child(r)
	var l := UI.text(r, label, 18, UI.TEXT)
	l.add_theme_font_override("font", UI.body_bold)
	l.custom_minimum_size = Vector2(380, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _slider(k: String, label: String, lo := 0.0, hi := 1.0, step := 0.05) -> void:
	var r := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(val(k))
	s.custom_minimum_size = Vector2(300, 32)
	s.focus_mode = Control.FOCUS_ALL
	r.add_child(s)
	var vl := UI.text(r, "", 18, UI.HOT)
	vl.add_theme_font_override("font", UI.display_it)
	vl.custom_minimum_size = Vector2(70, 0)
	vl.text = "%d%%" % int(round(s.value * 100.0))
	s.value_changed.connect(func(v: float):
		vl.text = "%d%%" % int(round(v * 100.0))
		_put(k, v)
		if k == "vol_sfx" or k == "vol_master":
			game.sfx.play("coin", -10.0))


func _choice(k: String, label: String, opts: Array) -> void:
	var r := _row(label)
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 46)
	r.add_child(b)
	var cur := 0
	for i in opts.size():
		if opts[i][0] == val(k):
			cur = i
	b.text = String(opts[cur][1])
	UI.style_button(b, false, 16)
	b.pressed.connect(func():
		var i := 0
		for j in opts.size():
			if opts[j][0] == val(k):
				i = j
		i = (i + 1) % opts.size()
		_put(k, opts[i][0])
		b.text = ("▸ " if b.has_focus() else "") + String(opts[i][1]))


func _steer_row() -> void:
	var r := _row("DIREÇÃO")
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 46)
	r.add_child(b)
	b.text = "TELA" if String(game.save.get("steer", "tela")) == "tela" else "CARRO"
	UI.style_button(b, false, 16)
	b.pressed.connect(func():
		game.toggle_steer()
		b.text = ("▸ " if b.has_focus() else "") + ("TELA" if String(game.save.steer) == "tela" else "CARRO"))


func _note(t: String) -> void:
	var l := UI.text(body, t, 14, UI.MUTED, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)


func _ctrl_table() -> void:
	var rows := [
		["", "TECLADO", "CONTROLE"],
		["Dirigir", "Setas / WASD", "Analógico esquerdo / direcional"],
		["Acelerar", "automático (modo TELA) · ↑", "A ou RT"],
		["Freio / ré", "B ou C", "B ou LT"],
		["Tiro / foguete", "Z, J ou Ctrl", "X"],
		["Mina / óleo", "X ou K", "Y"],
		["Nitro / mobilidade", "Shift ou N", "RB"],
		["Especial", "E ou L", "LB"],
		["Voltar à pista", "R", "BACK / SELECT"],
		["Pausa", "P ou Esc", "START"],
		["Falar (voz)", "V", "L3 (aperte o analógico)"],
	]
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 8)
	body.add_child(g)
	for i in rows.size():
		for j in 3:
			var l := UI.text(g, rows[i][j], 17, UI.HOT if i == 0 else (UI.TEXT if j == 0 else UI.MUTED))
			l.add_theme_font_override("font", UI.display_it if i == 0 else (UI.body_bold if j == 0 else UI.body))
	_note("Multijogador local: teclado WASD (E tiro · Q mina · Shift nitro · F especial · Espaço freio), teclado setas (. tiro · , mina · / nitro · L especial · Enter freio) e um controle por pessoa. Celular: analógico na tela e botões grandes.")


## autores das músicas e dos sons (lista completa, arquivo por arquivo, em sfx/CREDITOS.txt)
func _credits() -> void:
	var r := _row("MÚSICA")
	r.get_child(0).add_theme_color_override("font_color", UI.HOT)
	_note("Loyalty Freak Music e HoliznaCC0 — CC0 (domínio público).")
	r = _row("SONS (GRAVAÇÕES REAIS)")
	r.get_child(0).add_theme_color_override("font_color", UI.HOT)
	for t in [
		"Motores gravados no engine-sim, turbo, batidas e raspadas: CryHam / Stunt Rally 3 — CC-BY 4.0.",
		"Batidas de metal, terra e raspada: Halleck (freesound.org) — CC-BY 4.0. Água e lama: CGEffex — CC-BY 4.0. Turbo: shimsewn — CC-BY 4.0.",
		"Motor elétrico: JotrainG — CC0.",
		"Pneu cantando e pouso: Ya2 / Yorg — CC-BY-SA. Explosão: Michel Baradari — CC-BY 3.0.",
		"Armas, explosões, estalos e vento: Red Eclipse Team — CC-BY-SA 4.0 (as versões editadas seguem a mesma licença).",
		"Impactos, interface, fichas, vinhetas e narrador: Kenney (kenney.nl) — CC0. Arco e golpes: Battle Sound Effects (OpenGameArt) — CC0.",
	]:
		_note(t)
	_note("Lista completa, arquivo por arquivo: sfx/CREDITOS.txt no código do jogo.")
