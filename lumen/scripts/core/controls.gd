class_name Controls
## Mapa de controles criado por codigo (teclado/mouse e controle).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE], "dodge": [KEY_SHIFT], "skill1": [KEY_Q], "skill2": [KEY_R], "ultimate": [KEY_F], "interact": [KEY_E],
	"flask": [KEY_V], "emote1": [KEY_1], "emote2": [KEY_2], "emote3": [KEY_3], "emote4": [KEY_4], "inventory": [KEY_TAB],
	"pause": [KEY_ESCAPE],
}
const MOUSE := {"attack": MOUSE_BUTTON_LEFT, "secondary": MOUSE_BUTTON_RIGHT}
const PAD := {
	"jump": JOY_BUTTON_A, "dodge": JOY_BUTTON_B, "interact": JOY_BUTTON_X, "ultimate": JOY_BUTTON_Y,
	"skill1": JOY_BUTTON_LEFT_SHOULDER, "skill2": JOY_BUTTON_RIGHT_SHOULDER, "flask": JOY_BUTTON_DPAD_UP,
	"pause": JOY_BUTTON_START, "inventory": JOY_BUTTON_BACK,
}
const AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0], "look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"attack": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "secondary": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}
const LABELS := {"attack": "Mouse Esq.", "secondary": "Mouse Dir.", "skill1": "Q", "skill2": "R", "ultimate": "F", "dodge": "Shift",
	"jump": "Espaço", "interact": "E", "flask": "V"}

static func setup() -> void:
	var all := {}
	for a in KEYS:
		all[a] = true
	for a in MOUSE:
		all[a] = true
	for a in PAD:
		all[a] = true
	for a in AXES:
		all[a] = true
	for a in all:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
	for a in KEYS:
		for k in KEYS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for a in MOUSE:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[a]
		InputMap.action_add_event(a, mb)
	for a in PAD:
		var jb := InputEventJoypadButton.new()
		jb.button_index = PAD[a]
		InputMap.action_add_event(a, jb)
	for a in AXES:
		var jm := InputEventJoypadMotion.new()
		jm.axis = AXES[a][0]
		jm.axis_value = AXES[a][1]
		InputMap.action_add_event(a, jm)
