extends LevelBase
## Title screen: a little floating island where Lumi and Bolota idle and
## cheer, a slowly orbiting camera, and the main menu.

var _cam: Camera3D
var _rigs: Array = []
var _t := 0.0
var _menu: VBoxContainer
var _panel: Control
var _logo: Control
var _ui: Control


func configure() -> void:
	music_seed = 0
	kill_y = -20.0


func _ready() -> void:
	_rng.seed = 7
	configure()
	_build_environment()
	island(Vector3.ZERO, 7.0)
	tree(Vector3(-4.5, 0, -2.5), 1.6, true)
	tree(Vector3(4.8, 0, -3.0), 1.4)
	bush(Vector3(3.0, 0, 3.5), 1.1)
	crystal(Vector3(-4.0, 0, 2.5), 1.0)
	mushroom(Vector3(5.0, 0, 1.5), 19.0, 1.0)
	for i in 2:
		var holder := Node3D.new()
		add_child(holder)
		holder.position = Vector3(-0.9 if i == 0 else 0.9, 0.05, 0.6)
		holder.rotation.y = 0.25 if i == 0 else -0.25
		var rig := CharacterRig.new()
		holder.add_child(rig)
		rig.setup(load(Game.CHARACTERS[i]["model"]), Game.CHARACTERS[i]["kind"])
		holder.scale = Vector3.ONE * 1.3
		_rigs.append(rig)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.current = true
	_build_ui()
	if Game.crash_note != "":
		_show_crash_note()
	Game.trace("title")
	get_tree().create_timer(4.0).timeout.connect(func(): Game.trace("ok"))
	Sfx.play_music(0)
	Vfx.set_vignette(0.3)


func _physics_process(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	var a := sin(_t * 0.15) * 0.5
	_cam.position = Vector3(sin(a) * 7.0, 2.4, cos(a) * 7.0)
	var right := Vector3(cos(a), 0, -sin(a))
	_cam.look_at(Vector3(0, 1.3, 0) + right * 2.1)
	for i in _rigs.size():
		var cheer := fmod(_t + i * 1.7, 7.0) < 1.6
		_rigs[i].animate(delta, {"speed": 0.0, "on_floor": true, "state": "celebrate" if cheer else "normal", "t_state": fmod(_t + i * 1.7, 7.0)})
	if _logo:
		_logo.rotation = sin(_t * 1.3) * 0.02
		_logo.scale = Vector2.ONE * (1.0 + sin(_t * 2.6) * 0.015)


func _unhandled_input(event: InputEvent) -> void:
	if _panel and event.is_action_pressed("ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UiTheme.make()
	layer.add_child(_ui)

	var logo := VBoxContainer.new()
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(-450, 30)
	logo.custom_minimum_size = Vector2(900, 200)
	logo.pivot_offset = Vector2(450, 100)
	_ui.add_child(logo)
	var t1 := UiTheme.outlined("Lumi & Bolota", 120, Color(1.0, 0.82, 0.45), 26)
	var t2 := UiTheme.outlined("Jardins Orbitais", 54, Color(0.75, 0.95, 1.0), 16)
	logo.add_child(t1)
	logo.add_child(t2)
	_logo = logo
	logo.scale = Vector2(0.2, 0.2)
	logo.create_tween().tween_property(logo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_menu.position = Vector2(-560, -120)
	_menu.custom_minimum_size = Vector2(460, 0)
	_menu.add_theme_constant_override("separation", 12)
	_ui.add_child(_menu)
	if OS.has_feature("mobile"):
		_add_btn(_menu, "Jogar Solo (botão Trocar)", func(): _start(false))
		_add_btn(_menu, "Jogar Coop (2 controles)", func(): _start(true))
	else:
		_add_btn(_menu, "Jogar Coop (2 jogadores)", func(): _start(true))
		_add_btn(_menu, "Jogar Solo (troca com Tab)", func(): _start(false))
	_add_btn(_menu, "Escolher fase", _show_levels)
	_add_btn(_menu, "Controles", _show_controls)
	_add_btn(_menu, "Sair", func(): get_tree().quit())
	UiTheme.juice_buttons(_menu)
	var i := 0
	for b in _menu.get_children():
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.4 + i * 0.07)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)
		i += 1
	(_menu.get_child(0) as Button).grab_focus()

	var info := Label.new()
	info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(20, -60)
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color.WHITE)
	info.add_theme_constant_override("outline_size", 8)
	info.add_theme_color_override("font_outline_color", UiTheme.INK)
	info.text = "P1 Lumi: %s   •   P2 Bolota: %s   •   Sementes: %d" % [Game.device_label(0), Game.device_label(1), Game.total_seeds()]
	_ui.add_child(info)


func _show_crash_note() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position = Vector2(0, 250)
	var l := Label.new()
	l.text = Game.crash_note + "\nSe puder, conte qual mensagem apareceu aqui."
	l.add_theme_font_size_override("font_size", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_ui.add_child(p)
	p.position.x = -p.size.x * 0.5
	Game.crash_note = ""


func _add_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _start(coop: bool) -> void:
	Game.coop = coop
	Game.play_level(0)  # demo: always start at the training stage


func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	_menu.visible = true
	(_menu.get_child(0) as Button).grab_focus()


func _open_panel(title: String) -> VBoxContainer:
	_menu.visible = false
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.position.y = 80
	_ui.add_child(p)
	_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(760, 0)
	p.add_child(v)
	v.add_child(UiTheme.outlined(title, 56, UiTheme.ACCENT, 12))
	p.pivot_offset = Vector2(380, 200)
	p.scale = Vector2(0.7, 0.7)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


func _show_levels() -> void:
	var v := _open_panel("Fases")
	for i in Game.LEVELS.size():
		var info: Dictionary = Game.LEVELS[i]
		var rec := Game.level_record(i)
		var seeds := "●".repeat(rec["seeds"].count(true)) + "○".repeat(3 - rec["seeds"].count(true))
		var b := _add_btn(v, "%d. %s   %s" % [i + 1, info["title"], seeds], func():
			Game.play_level(i))
		b.disabled = i >= Game.unlocked
	var mode := HBoxContainer.new()
	mode.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(mode)
	var coop := CheckButton.new()
	coop.text = "Modo coop (2 jogadores)"
	coop.button_pressed = Game.coop
	coop.toggled.connect(func(on): Game.coop = on)
	mode.add_child(coop)
	_add_btn(v, "Voltar", _close_panel)
	UiTheme.juice_buttons(v)
	(v.get_child(1) as Button).grab_focus()


func _show_controls() -> void:
	var v := _open_panel("Controles")
	var txt := Label.new()
	txt.add_theme_font_size_override("font_size", 22)
	txt.text = """             P1 (Lumi)        P2 (Bolota)      Controle
Mover        WASD             Setas            Analógico esq.
Pular        Espaço           Enter / Num0     A
Dash         Shift            Num1 / "/"       X
Erguer/Elo   F                .  / Num2        Y / RB
Ground pound C / Ctrl (no ar) Num3 / ,         B / LB / LT
Câmera       Q / E            PgUp / PgDn      Analógico dir.
Pausa        Esc              P                Start

Lumi: pulo duplo, PLANAR (segure pulo) e ELO DE LUZ (puxa o Bolota).
Bolota: pesado (placas ⬇⬇), ERGUE e ARREMESSA a Lumi e caixotes.
Dash + pulo = pulo longo. Caiu? Uma bolha leva você até o parceiro.
Solo: Tab / Back troca de personagem."""
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Monospace"])
	txt.add_theme_font_override("font", mono)
	v.add_child(txt)
	var safe := CheckButton.new()
	safe.text = "Gráficos seguros (se o jogo fechar sozinho)"
	safe.button_pressed = Game.safe_graphics
	safe.toggled.connect(func(on):
		Game.safe_graphics = on
		Mats.clear()
		Game.save())
	v.add_child(safe)
	_add_btn(v, "Trocar controles entre P1 e P2", func():
		Game.swap_pads()
		Sfx.play("unlock"))
	_add_btn(v, "Voltar", _close_panel)
	UiTheme.juice_buttons(v)
	(v.get_child(v.get_child_count() - 1) as Button).grab_focus()
