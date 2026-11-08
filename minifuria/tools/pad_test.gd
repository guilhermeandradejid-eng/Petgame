extends SceneTree
## godot --headless --path . -s res://tools/pad_test.gd — injeta eventos de controle e confere as ações do jogo
func _init() -> void:
	var main = load("res://scripts/main.gd").new()
	main._setup_input()
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 0.9
	Input.parse_input_event(ev)
	var b := InputEventJoypadButton.new()
	b.device = 0
	b.button_index = JOY_BUTTON_X
	b.pressed = true
	Input.parse_input_event(b)
	var t := InputEventJoypadMotion.new()
	t.device = 0
	t.axis = JOY_AXIS_TRIGGER_RIGHT
	t.axis_value = 1.0
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	print("PADTEST right=%.2f left=%.2f accel=%.2f fire=%s" % [Input.get_action_strength("right"), Input.get_action_strength("left"), Input.get_action_strength("accel"), Input.is_action_pressed("fire")])
	var j := InputEventJoypadButton.new()
	j.device = 2
	j.button_index = JOY_BUTTON_A
	j.pressed = true
	var k := InputEventKey.new()
	k.physical_keycode = KEY_ENTER
	k.pressed = true
	print("PADTEST join=%s,%s" % [PInput.join_device(j), PInput.join_device(k)])
	main.free()
	quit()
