extends Node
## Estado global: configuração da partida, mapa de controles, fontes e transições de cena.

const CHARACTERS := ["lumia", "rubi"]
const CHAR_INFO := {
	"lumia": {
		"name": "Lumia",
		"title": "A Bruxa dos Vagalumes",
		"style": "Zoneadora",
		"blurb": "Guarda as lanternas do jardim suspenso. Controla o espaço com vagalumes, estrelas e cometas.",
		"color": Color("4fd8c0"),
		"accent": Color("ffd66b"),
	},
	"rubi": {
		"name": "Rubi",
		"title": "A Lutadora da Tempestade",
		"style": "Ofensiva",
		"blurb": "Desceu das nuvens de trovoada atrás de um bom desafio. Chega perto, bate rápido e fecha com raios.",
		"color": Color("ff5a4a"),
		"accent": Color("5fd8ff"),
	},
}

enum Mode { VS_CPU, VS_PLAYER, TRAINING, WATCH }

var mode: int = Mode.VS_CPU
var p_chars := ["lumia", "rubi"]
var p_cpu := [false, true]
var cpu_level := 1          # 0 fácil, 1 normal, 2 difícil
var rounds_to_win := 2
var show_boxes := false
var master_volume := 0.9
var music_volume := 0.75
var sfx_volume := 0.9

var font_main: FontFile
var font_title: FontFile
var font_small: FontFile

var _fade: ColorRect
var _fade_layer: CanvasLayer
var _changing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	font_main = _load_font("res://assets/fonts/PixelifySans.ttf")
	font_title = _load_font("res://assets/fonts/Silkscreen-Bold.ttf")
	font_small = _load_font("res://assets/fonts/Silkscreen-Regular.ttf")
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.02, 0.08, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)
	_apply_volumes()


func _load_font(path: String) -> FontFile:
	var f := load(path) as FontFile
	if f:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.generate_mipmaps = false
	return f


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif event.keycode == KEY_F1:
			show_boxes = not show_boxes


# ------------------------------------------------------------------ cenas

func goto(path: String, color := Color(0.03, 0.02, 0.08)) -> void:
	if _changing:
		return
	_changing = true
	_fade.color = Color(color.r, color.g, color.b, 0.0)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(_fade, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_changing = false


func flash_screen(color: Color, dur := 0.25) -> void:
	_fade.color = color
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 0.0, dur)


# ------------------------------------------------------------------ controles

const KEYS_P1 := {
	"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
	"a": [KEY_J], "b": [KEY_K], "c": [KEY_L], "dash": [KEY_SPACE, KEY_SHIFT],
	"spell": [KEY_I], "switch": [KEY_O], "start": [KEY_ESCAPE, KEY_ENTER],
}
const KEYS_P2 := {
	"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
	"a": [KEY_KP_1, KEY_COMMA], "b": [KEY_KP_2, KEY_PERIOD], "c": [KEY_KP_3, KEY_SLASH],
	"dash": [KEY_KP_0, KEY_CTRL], "spell": [KEY_KP_5, KEY_SEMICOLON], "switch": [KEY_KP_6, KEY_APOSTROPHE],
	"start": [KEY_BACKSPACE, KEY_KP_ENTER],
}
const PAD := {
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT], "a": [JOY_BUTTON_X], "b": [JOY_BUTTON_Y], "c": [JOY_BUTTON_B],
	"dash": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER], "spell": [JOY_BUTTON_LEFT_SHOULDER],
	"switch": [JOY_BUTTON_BACK], "start": [JOY_BUTTON_START],
}


func _setup_inputs() -> void:
	for p in 2:
		var keys: Dictionary = KEYS_P1 if p == 0 else KEYS_P2
		for act in keys:
			var name := "p%d_%s" % [p + 1, act]
			if InputMap.has_action(name):
				InputMap.erase_action(name)
			InputMap.add_action(name, 0.4)
			for k in keys[act]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(name, ev)
			for b in PAD[act]:
				var jb := InputEventJoypadButton.new()
				jb.button_index = b
				jb.device = p
				InputMap.action_add_event(name, jb)
			if act in ["up", "down", "left", "right"]:
				var ax := InputEventJoypadMotion.new()
				ax.device = p
				ax.axis = JOY_AXIS_LEFT_X if act in ["left", "right"] else JOY_AXIS_LEFT_Y
				ax.axis_value = -1.0 if act in ["left", "up"] else 1.0
				InputMap.action_add_event(name, ax)
	# menus aceitam os dois jogadores
	_menu_action("ui_accept", [KEY_J, KEY_ENTER, KEY_SPACE, KEY_KP_1, KEY_Z], [JOY_BUTTON_A, JOY_BUTTON_X])
	_menu_action("ui_cancel", [KEY_K, KEY_ESCAPE, KEY_BACKSPACE, KEY_KP_2, KEY_X], [JOY_BUTTON_B, JOY_BUTTON_Y])


func _menu_action(name: String, keys: Array, pads: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)
	for b in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		jb.device = -1
		InputMap.action_add_event(name, jb)


func _apply_volumes() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


# ------------------------------------------------------------------ utilidades

func make_label(text: String, size := 16, color := Color.WHITE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font if font else font_main
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(2, size / 5)
	ls.outline_color = Color(0.05, 0.03, 0.12)
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.6)
	ls.shadow_offset = Vector2(1, 2)
	l.label_settings = ls
	return l
