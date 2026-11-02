extends Node
## Global game state: co-op input bindings, character data, level list,
## persistent progress and scene flow.

const SAVE_PATH := "user://save.cfg"
const TRACE_PATH := "user://gpu_trace.txt"

const CHARACTERS := [
	{
		"name": "Lumi",
		"kind": "lumi",
		"model": "res://assets/models/lumi.glb",
		"color": Color(1.0, 0.54, 0.3),
		"light": Color(1.0, 0.86, 0.4),
		"desc": "Pulo duplo, planar com a lanterna e Elo de Luz (puxa o parceiro).",
	},
	{
		"name": "Bolota",
		"kind": "bolota",
		"model": "res://assets/models/bolota.glb",
		"color": Color(0.43, 0.75, 0.27),
		"light": Color(0.5, 1.0, 0.6),
		"desc": "Pesado: aciona placas pesadas, carrega e arremessa a Lumi e caixotes.",
	},
]

const LEVELS := [
	{"title": "Campo de Treino", "script": "res://scripts/levels/level_test.gd", "sub": "Todas as mecânicas numa fase só"},
	{"title": "Prado das Lanternas", "script": "res://scripts/levels/level_1.gd", "sub": "Aprendam a se ajudar"},
	{"title": "Jardim Orbital", "script": "res://scripts/levels/level_2.gd", "sub": "Pequenos planetas, grandes saltos"},
	{"title": "Ruínas da Fenda", "script": "res://scripts/levels/level_3.gd", "sub": "Fendas, marés e relógios"},
]

const ACTIONS := ["left", "right", "fwd", "back", "jump", "dash", "grab", "pound", "cam_left", "cam_right", "swap", "pause"]

# Keyboard layouts (physical keys, so they work on any keyboard layout).
const KB_LAYOUTS := [
	{
		"left": [KEY_A], "right": [KEY_D], "fwd": [KEY_W], "back": [KEY_S],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "grab": [KEY_F], "pound": [KEY_C, KEY_CTRL],
		"cam_left": [KEY_Q], "cam_right": [KEY_E], "swap": [KEY_TAB], "pause": [KEY_ESCAPE],
	},
	{
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "fwd": [KEY_UP], "back": [KEY_DOWN],
		"jump": [KEY_ENTER, KEY_KP_0], "dash": [KEY_KP_1, KEY_SLASH], "grab": [KEY_PERIOD, KEY_KP_2],
		"pound": [KEY_KP_3, KEY_COMMA], "cam_left": [KEY_PAGEUP, KEY_KP_7], "cam_right": [KEY_PAGEDOWN, KEY_KP_9],
		"swap": [KEY_BACKSPACE], "pause": [KEY_P],
	},
]

const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A], "dash": [JOY_BUTTON_X], "grab": [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER],
	"pound": [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], "swap": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "fwd": [JOY_BUTTON_DPAD_UP], "back": [JOY_BUTTON_DPAD_DOWN],
}
const PAD_AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"fwd": [JOY_AXIS_LEFT_Y, -1.0], "back": [JOY_AXIS_LEFT_Y, 1.0],
	"cam_left": [JOY_AXIS_RIGHT_X, -1.0], "cam_right": [JOY_AXIS_RIGHT_X, 1.0],
}

## Joypad device id per player (-1 = keyboard only).
var pad_of_player := [-1, -1]
## Two players (true) or solo with character swapping (false).
var coop := true
var current_level := 0
var unlocked := 1
var best := {}  # level index -> {"sparks": int, "seeds": Array[bool]}
var settings := {"shake": 1.0, "music": 0.6, "sfx": 0.9}
## Shaders replaced by their safe twins (filled automatically after a crash).
var safe_shaders: Array = []
## Replace every custom shader with its safe twin.
var safe_graphics := false
## Set when the previous run closed unexpectedly (shown on the title).
var crash_note := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_changed)
	_load()
	_check_last_run()
	auto_assign_pads()
	bind_all()
	if "--safe-graphics" in OS.get_cmdline_user_args():
		safe_graphics = true
	for a in OS.get_cmdline_user_args():
		if a == "--playtest":
			add_child(load("res://scripts/dev/playtest.gd").new())
			break
		if a.begins_with("--shot="):
			var shot: Node = load("res://scripts/dev/autoshot.gd").new()
			add_child(shot)
			break


# ------------------------------------------------------------------- input
func act(player: int, action: String) -> StringName:
	return StringName("p%d_%s" % [player, action])


func auto_assign_pads() -> void:
	var pads := Input.get_connected_joypads()
	pad_of_player = [-1, -1]
	for i in mini(pads.size(), 2):
		pad_of_player[i] = pads[i]


func bind_all() -> void:
	for p in 2:
		bind_player(p)


func bind_player(p: int) -> void:
	var layout: Dictionary = KB_LAYOUTS[p]
	var device: int = pad_of_player[p]
	for a in ACTIONS:
		var name := act(p, a)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name, 0.25)
		for key in layout.get(a, []):
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(name, e)
		if device >= 0:
			for b in PAD_BUTTONS.get(a, []):
				var jb := InputEventJoypadButton.new()
				jb.button_index = b
				jb.device = device
				InputMap.action_add_event(name, jb)
			if PAD_AXES.has(a):
				var jm := InputEventJoypadMotion.new()
				jm.axis = PAD_AXES[a][0]
				jm.axis_value = PAD_AXES[a][1]
				jm.device = device
				InputMap.action_add_event(name, jm)
	# Left trigger also pounds on pads.
	if device >= 0:
		var lt := InputEventJoypadMotion.new()
		lt.axis = JOY_AXIS_TRIGGER_LEFT
		lt.axis_value = 1.0
		lt.device = device
		InputMap.action_add_event(act(p, "pound"), lt)


## Swap which pad drives which character (handy with a single gamepad).
func swap_pads() -> void:
	pad_of_player = [pad_of_player[1], pad_of_player[0]]
	bind_all()


func _on_joy_changed(_device: int, _connected: bool) -> void:
	auto_assign_pads()
	bind_all()


func device_label(p: int) -> String:
	var kb := "WASD" if p == 0 else "Setas"
	if pad_of_player[p] >= 0:
		return "Controle %d + %s" % [pad_of_player[p] + 1, kb]
	return "Teclado (%s)" % kb


# ---------------------------------------------------------------- progress
func level_record(i: int) -> Dictionary:
	if not best.has(i):
		best[i] = {"sparks": 0, "seeds": [false, false, false], "done": false}
	return best[i]


func finish_level(i: int, sparks: int, seeds: Array) -> void:
	var r := level_record(i)
	r["sparks"] = maxi(r["sparks"], sparks)
	for k in 3:
		r["seeds"][k] = r["seeds"][k] or (k < seeds.size() and seeds[k])
	r["done"] = true
	unlocked = clampi(maxi(unlocked, i + 2), 1, LEVELS.size())
	save()


func total_seeds() -> int:
	var n := 0
	for k in best:
		for s in best[k]["seeds"]:
			n += 1 if s else 0
	return n


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "best", best)
	cf.set_value("settings", "values", settings)
	cf.set_value("graphics", "safe_shaders", safe_shaders)
	cf.set_value("graphics", "safe_graphics", safe_graphics)
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	unlocked = cf.get_value("progress", "unlocked", 1)
	best = cf.get_value("progress", "best", {})
	settings.merge(cf.get_value("settings", "values", {}), true)
	safe_shaders = cf.get_value("graphics", "safe_shaders", [])
	safe_graphics = cf.get_value("graphics", "safe_graphics", false)


# ------------------------------------------------------------- crash trace
## Records the current loading stage. If the app dies (e.g. a GPU driver
## crashes compiling a shader) the next launch knows where it happened.
func trace(stage: String) -> void:
	var f := FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(stage)
		f.flush()
		f.close()


func _check_last_run() -> void:
	if not FileAccess.file_exists(TRACE_PATH):
		return
	var last := FileAccess.get_file_as_string(TRACE_PATH).strip_edges()
	if last == "" or last == "ok":
		return
	if last.begins_with("shader:"):
		var name := last.substr(7)
		if name in ShaderLib.REAL and not name in safe_shaders:
			safe_shaders.append(name)
			crash_note = "O jogo fechou ao preparar o shader \"%s\". Ele foi trocado por uma versão simples." % name
		else:
			safe_graphics = true
			crash_note = "O jogo fechou ao preparar \"%s\". Gráficos seguros ativados." % name
	else:
		safe_graphics = true
		crash_note = "O jogo fechou na etapa \"%s\". Gráficos seguros ativados." % last
	save()
	trace("ok")


# -------------------------------------------------------------- scene flow
func play_level(i: int) -> void:
	current_level = clampi(i, 0, LEVELS.size() - 1)
	Transition.change_scene("res://scenes/level.tscn")


func to_title() -> void:
	Transition.change_scene("res://scenes/title.tscn")
