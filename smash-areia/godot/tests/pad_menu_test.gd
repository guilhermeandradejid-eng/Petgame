extends Node
## Teste: simula um controle apertando A pelos menus (godot --headless -- --padtest).
var t := 0.0
var step := 0
func _process(dt):
	t += dt
	var main = get_tree().current_scene
	var h = main.hud
	if t > 1.0 and step == 0:
		_press(JOY_BUTTON_A); step = 1; print("T1 screen=", h.screen)
	elif t > 1.6 and step == 1:
		print("T2 screen=", h.screen, " focus=", get_viewport().gui_get_focus_owner())
		_press(JOY_BUTTON_A); step = 2
	elif t > 2.2 and step == 2:
		print("T3 screen=", h.screen, " mode=", GameData.mode, " focus=", get_viewport().gui_get_focus_owner())
		_press(JOY_BUTTON_A); step = 3
	elif t > 2.8 and step == 3:
		print("T4 screen=", h.screen, " focus=", get_viewport().gui_get_focus_owner())
		_press(JOY_BUTTON_A); step = 4
	elif t > 3.4 and step == 4:
		print("T5 screen=", h.screen, " focus=", get_viewport().gui_get_focus_owner())
		_press(JOY_BUTTON_A); step = 5
	elif t > 4.2 and step == 5:
		print("T6 menu_visible=", h.menu.visible, " demo=", main.demo)
		get_tree().quit()
func _press(b):
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = p
		e.device = 0
		Input.parse_input_event(e)
