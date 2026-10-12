class_name Controls
extends RefCounted
## One place that reads keyboard, gamepad and the on-screen touch controls.

static var touch_move := Vector2.ZERO
static var touch_jump := false
static var touch_cam := Vector2.ZERO
static var touch_active := false


static func setup() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("move_forward", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_back", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("jump", [KEY_SPACE], -1, 0.0, [JOY_BUTTON_A])
	_action("walk", [KEY_SHIFT], -1, 0.0, [])


static func _action(name: String, keys: Array, axis: int, dir: float, buttons: Array = []) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	if axis >= 0:
		var j := InputEventJoypadMotion.new()
		j.axis = axis
		j.axis_value = dir
		InputMap.action_add_event(name, j)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(name, jb)


## x: right, y: back (like a stick). Length up to 1.
static func move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length() > v.length():
		v = touch_move
	if Input.is_action_pressed("walk"):
		v = v.limit_length(0.45)
	return v


static func jump_held() -> bool:
	return Input.is_action_pressed("jump") or touch_jump


static func camera_stick() -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	return v if v.length() > 0.18 else Vector2.ZERO
