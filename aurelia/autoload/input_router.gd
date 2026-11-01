extends Node
## Registers input actions in code and produces one InputFrame per tick per source.

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "jump", "dash", "cast"]


func _ready() -> void:
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("attack", [KEY_J, KEY_Z])
	_key("jump", [KEY_K, KEY_SPACE])
	_key("dash", [KEY_L, KEY_SHIFT])
	_key("cast", [KEY_I, KEY_C])
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_btn("attack", JOY_BUTTON_X)
	_btn("jump", JOY_BUTTON_A)
	_btn("dash", JOY_BUTTON_B)
	_btn("cast", JOY_BUTTON_Y)


func _add(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _key(action: String, keys: Array) -> void:
	_add(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: int, value: float) -> void:
	_add(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _btn(action: String, button: int) -> void:
	_add(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
