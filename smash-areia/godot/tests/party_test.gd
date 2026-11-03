extends Node
## Teste: J1 (WASD/Enter) e J2 (setas/N) escolhem personagens ao mesmo tempo no VS
## (godot --headless -- --partytest).
var t := 0.0
var step := 0
var steps := []


func _ready() -> void:
	GameData.mode = "vs"
	steps = [
		[0.6, func(): get_tree().current_scene.hud._go_screen("char")],
		[1.0, func(): _key(KEY_D)],
		[1.2, func(): _key(KEY_ENTER)],
		[1.4, func(): _key(KEY_RIGHT)],
		[1.6, func(): _key(KEY_RIGHT)],
		[1.8, func(): _key(KEY_N)],
		[2.1, func(): _report("char")],
		[2.3, func(): _key(KEY_ENTER)],
		[2.8, func(): _report("after next")],
		[3.0, func(): _key(KEY_DOWN)],
		[3.2, func(): _key(KEY_N)],
		[3.5, func(): _report("locker J2 row1")],
		[3.7, func(): get_tree().quit()],
	]


func _process(dt: float) -> void:
	t += dt
	while step < steps.size() and t >= steps[step][0]:
		(steps[step][1] as Callable).call()
		step += 1


func _key(k: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = p
		Input.parse_input_event(e)


func _report(tag: String) -> void:
	var h = get_tree().current_scene.hud
	print("PARTY ", tag, " screen=", h.screen, " j1=", GameData.char_index, " j2=", GameData.char_index_p2,
		" ready=", h.party_ready, " look2=", GameData.looks[1])
