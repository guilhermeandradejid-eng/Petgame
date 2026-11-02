class_name TouchControls
extends Control
## On-screen controls for phones/tablets. They drive player 1's actions
## (p0_*), which in solo mode control whichever hero is active.
## Left half: floating virtual joystick. Right side: action buttons.
## Dragging on empty space on the right rotates the camera.

const BTN := [
	{"action": "jump", "label": "Pular", "pos": Vector2(-150, -150), "r": 78.0, "color": Color(1.0, 0.75, 0.3)},
	{"action": "dash", "label": "Dash", "pos": Vector2(-320, -110), "r": 58.0, "color": Color(0.45, 0.8, 1.0)},
	{"action": "grab", "label": "Erguer\nElo", "pos": Vector2(-150, -330), "r": 58.0, "color": Color(0.6, 0.95, 0.5)},
	{"action": "pound", "label": "Pound", "pos": Vector2(-320, -280), "r": 52.0, "color": Color(1.0, 0.5, 0.6)},
	{"action": "swap", "label": "Trocar", "pos": Vector2(-90, -470), "r": 42.0, "color": Color(0.85, 0.7, 1.0)},
]

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _cam_finger := -1
var _cam_last := Vector2.ZERO
var _cam_v := 0.0
var _btn_fingers := {}  # finger -> action
var _pressed := {}  # action -> bool
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.FONT
	process_mode = Node.PROCESS_MODE_ALWAYS


func _btn_center(b: Dictionary) -> Vector2:
	return size + (b["pos"] as Vector2)


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			# pause button (top center)
			if t.position.distance_to(Vector2(size.x - 80, 150)) < 50:
				_tap_action("pause")
				return
			for b in BTN:
				if b["action"] == "swap" and Game.coop:
					continue
				if t.position.distance_to(_btn_center(b)) < float(b["r"]) * 1.25:
					_btn_fingers[t.index] = b["action"]
					_set_btn(b["action"], true)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if t.position.x < size.x * 0.45 and _stick_finger < 0:
				_stick_finger = t.index
				_stick_origin = t.position
				_stick_pos = t.position
			elif _cam_finger < 0:
				_cam_finger = t.index
				_cam_last = t.position
		else:
			if t.index == _stick_finger:
				_stick_finger = -1
				_apply_stick(Vector2.ZERO)
			elif t.index == _cam_finger:
				_cam_finger = -1
				_cam_v = 0.0
			elif _btn_fingers.has(t.index):
				_set_btn(_btn_fingers[t.index], false)
				_btn_fingers.erase(t.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_pos = d.position
			var v := (_stick_pos - _stick_origin) / 110.0
			if v.length() > 1.0:
				_stick_origin = _stick_pos - v.normalized() * 110.0  # floating stick follows the thumb
				v = v.normalized()
			_apply_stick(v)
			queue_redraw()
		elif d.index == _cam_finger:
			var dx := d.position.x - _cam_last.x
			_cam_last = d.position
			_cam_v = clampf(dx * 0.12, -1.0, 1.0)


func _apply_stick(v: Vector2) -> void:
	_axis("left", maxf(-v.x, 0.0))
	_axis("right", maxf(v.x, 0.0))
	_axis("fwd", maxf(-v.y, 0.0))
	_axis("back", maxf(v.y, 0.0))


func _axis(a: String, s: float) -> void:
	var name := Game.act(0, a)
	if s > 0.05:
		Input.action_press(name, s)
	else:
		Input.action_release(name)


func _set_cam(v: float) -> void:
	_axis("cam_right", maxf(v, 0.0))
	_axis("cam_left", maxf(-v, 0.0))


func _set_btn(action: String, on: bool) -> void:
	_pressed[action] = on
	if on:
		Input.action_press(Game.act(0, action))
		Sfx.play("tick", 1.5, -14.0)
	else:
		Input.action_release(Game.act(0, action))


func _tap_action(action: String) -> void:
	Input.action_press(Game.act(0, action))
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(Game.act(0, action))


func _process(delta: float) -> void:
	_set_cam(_cam_v)
	_cam_v = move_toward(_cam_v, 0.0, delta * 5.0)


func _draw() -> void:
	# joystick
	if _stick_finger >= 0:
		draw_circle(_stick_origin, 110.0, Color(1, 1, 1, 0.14))
		draw_arc(_stick_origin, 110.0, 0, TAU, 48, Color(1, 1, 1, 0.5), 4.0, true)
		draw_circle(_stick_pos, 48.0, Color(1, 1, 1, 0.55))
	else:
		var c := Vector2(220, size.y - 220)
		draw_arc(c, 110.0, 0, TAU, 48, Color(1, 1, 1, 0.25), 4.0, true)
		draw_string(_font, c + Vector2(-60, 8), "Mover", HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Color(1, 1, 1, 0.5))
	# buttons
	for b in BTN:
		if b["action"] == "swap" and Game.coop:
			continue
		var p := _btn_center(b)
		var r: float = b["r"]
		var on: bool = _pressed.get(b["action"], false)
		var col: Color = b["color"]
		draw_circle(p + Vector2(0, 6), r, Color(0.1, 0.03, 0.15, 0.35))
		draw_circle(p, r * (0.92 if on else 1.0), col if on else Color(col, 0.6))
		draw_arc(p, r * (0.92 if on else 1.0), 0, TAU, 40, Color(0.2, 0.08, 0.27, 0.9), 4.0, true)
		var lines: PackedStringArray = String(b["label"]).split("\n")
		for i in lines.size():
			var y := 9.0 + (i - (lines.size() - 1) * 0.5) * 26.0
			draw_string(_font, p + Vector2(-r, y), lines[i], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, Color(0.2, 0.08, 0.27))
	# pause
	var pp := Vector2(size.x - 80, 150)
	draw_circle(pp, 34.0, Color(1, 1, 1, 0.5))
	draw_rect(Rect2(pp + Vector2(-12, -14), Vector2(8, 28)), Color(0.2, 0.08, 0.27))
	draw_rect(Rect2(pp + Vector2(4, -14), Vector2(8, 28)), Color(0.2, 0.08, 0.27))
