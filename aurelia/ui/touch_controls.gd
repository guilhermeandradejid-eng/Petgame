extends CanvasLayer
## On-screen controls for tablets/phones: a floating virtual stick on the left half and four
## action buttons on the right. They drive the same InputMap actions as keyboard/gamepad, so the
## gameplay code does not know the difference. Multi-touch safe (each finger tracked by index).

const K := 0.5                     # layout below is authored for 1280x720; the base viewport is 640x360
const STICK_RADIUS := 48.0
const BUTTONS := {
	"attack": {"label": "ATK", "color": Color(1.0, 0.45, 0.4)},
	"jump": {"label": "JMP", "color": Color(0.5, 0.9, 0.6)},
	"dash": {"label": "DSH", "color": Color(0.45, 0.8, 1.0)},
	"cast": {"label": "ICE", "color": Color(0.7, 0.6, 1.0)},
}

var _c: Control
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _btn_touch: Dictionary = {}     # finger index -> action
var _layout: Dictionary = {}        # action -> {c: Vector2, r: float}
var _menu_c := Vector2.ZERO
var _last_size := Vector2.ZERO


func _ready() -> void:
	layer = 70
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.gui_input.connect(_on_input)
	_c.draw.connect(_draw_pad)
	add_child(_c)


func _relayout() -> void:
	var s := _c.size
	_last_size = s
	var u := clampf(minf(s.x / 640.0, s.y / 360.0), 0.9, 1.5) * K
	_layout = {
		"attack": {"c": Vector2(s.x - 165 * u, s.y - 160 * u), "r": 82.0 * u},
		"dash": {"c": Vector2(s.x - 330 * u, s.y - 100 * u), "r": 56.0 * u},
		"cast": {"c": Vector2(s.x - 330 * u, s.y - 235 * u), "r": 56.0 * u},
		"jump": {"c": Vector2(s.x - 150 * u, s.y - 345 * u), "r": 56.0 * u},
	}
	_menu_c = Vector2(s.x - 44 * K, 44 * K)


func _action_at(p: Vector2) -> String:
	for a in _layout:
		var d: Dictionary = _layout[a]
		if p.distance_to(d["c"]) <= d["r"] * 1.25:
			return a
	return ""


func _on_input(e: InputEvent) -> void:
	if _c.size != _last_size:
		_relayout()
	var idx := -1
	var pos := Vector2.ZERO
	var down := false
	var is_move := false
	if e is InputEventScreenTouch:
		idx = e.index
		pos = e.position
		down = e.pressed
	elif e is InputEventScreenDrag:
		idx = e.index
		pos = e.position
		is_move = true
		down = true
	elif Game.args.has("touch") and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		idx = 99
		pos = e.position
		down = e.pressed
	elif Game.args.has("touch") and e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		idx = 99
		pos = e.position
		down = true
		is_move = true
	else:
		return
	if is_move:
		if idx == _stick_id:
			_update_stick(pos)
		return
	if down:
		if pos.distance_to(_menu_c) < 36.0 * K * 1.4:
			Net.go_offline()
			get_tree().change_scene_to_file("res://ui/title.tscn")
			return
		var a := _action_at(pos)
		if a != "":
			_btn_touch[idx] = a
			Input.action_press(a)
		elif _stick_id == -1 and pos.x < _c.size.x * 0.5:
			_stick_id = idx
			_stick_origin = pos
			_stick_pos = pos
			_update_stick(pos)
	else:
		if _btn_touch.has(idx):
			Input.action_release(_btn_touch[idx])
			_btn_touch.erase(idx)
		if idx == _stick_id:
			_stick_id = -1
			_set_move(Vector2.ZERO)
	_c.queue_redraw()


func _update_stick(pos: Vector2) -> void:
	var d := pos - _stick_origin
	if d.length() > STICK_RADIUS:
		# the stick base follows the thumb so you never run out of room
		_stick_origin += d.normalized() * (d.length() - STICK_RADIUS)
		d = pos - _stick_origin
	_stick_pos = pos
	_set_move(d / STICK_RADIUS)
	_c.queue_redraw()


func _set_move(v: Vector2) -> void:
	_strength("move_left", maxf(-v.x, 0.0))
	_strength("move_right", maxf(v.x, 0.0))
	_strength("move_up", maxf(-v.y, 0.0))
	_strength("move_down", maxf(v.y, 0.0))


func _strength(action: String, s: float) -> void:
	if s > 0.05:
		Input.action_press(action, s)
	else:
		Input.action_release(action)


func _exit_tree() -> void:
	for a in InputRouter.ACTIONS:
		Input.action_release(a)


func _draw_pad() -> void:
	if _c.size != _last_size:
		_relayout()
	var font := ThemeDB.fallback_font
	# stick
	if _stick_id != -1:
		_c.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.10))
		_c.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 2.0)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		_c.draw_circle(knob, 21.0, Color(1, 1, 1, 0.35))
	else:
		var hint := Vector2(78, _c.size.y - 78)
		_c.draw_arc(hint, 36.0, 0, TAU, 40, Color(1, 1, 1, 0.18), 2.0)
		_c.draw_circle(hint, 14.0, Color(1, 1, 1, 0.10))
	for a in _layout:
		var d: Dictionary = _layout[a]
		var col: Color = BUTTONS[a]["color"]
		var pressed := Input.is_action_pressed(a)
		_c.draw_circle(d["c"], d["r"], Color(col.r, col.g, col.b, 0.42 if pressed else 0.2))
		_c.draw_arc(d["c"], d["r"], 0, TAU, 40, Color(col.r, col.g, col.b, 0.85), 2.0)
		var label: String = BUTTONS[a]["label"]
		var fs := int(d["r"] * 0.5)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_c.draw_string(font, d["c"] + Vector2(-tw * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	# menu
	_c.draw_circle(_menu_c, 15.0, Color(0, 0, 0, 0.35))
	_c.draw_string(font, _menu_c + Vector2(-11, 3), "MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.85))
