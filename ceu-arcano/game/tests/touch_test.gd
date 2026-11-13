extends Node
# Injeta toques de tela e confere se viram ações do jogador 1.
func _ready() -> void:
	await get_tree().process_frame
	var ok := 0
	var checks := [
		[Vector2(598, 300), "p1_a"], [Vector2(548, 322), "p1_b"], [Vector2(548, 268), "p1_dash"],
		[Vector2(494, 300), "p1_spell"], [Vector2(120, 288), "p1_right"], [Vector2(66, 340), "p1_down"],
		[Vector2(20, 288), "p1_left"], [Vector2(66, 230), "p1_up"],
	]
	for i in checks.size():
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = checks[i][0]
		e.pressed = true
		Touch._input(e)
		await get_tree().process_frame
		await get_tree().process_frame
		var good := Input.is_action_pressed(checks[i][1])
		print("%-10s %s" % [checks[i][1], "OK" if good else "FALHOU"])
		ok += 1 if good else 0
		e = InputEventScreenTouch.new()
		e.index = i
		e.position = checks[i][0]
		e.pressed = false
		Touch._input(e)
		await get_tree().process_frame
		await get_tree().process_frame
	print("RESULTADO %d de %d" % [ok, checks.size()])
	get_tree().quit(0 if ok == checks.size() else 1)
