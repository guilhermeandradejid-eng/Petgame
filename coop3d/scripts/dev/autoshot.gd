extends Node
## Developer tool: `godot -- --shot=<level|title> --out=file.png [--frames=N]
## [--script=steps]` loads a scene, optionally drives the players with a
## simple scripted input sequence, saves screenshots and quits.

var target := "title"
var out := "user://shot.png"
var frames := 150
var steps := ""
var _f := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			target = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--steps="):
			steps = a.substr(8)
	if target != "title":
		Game.coop = true
		Game.current_level = int(target) - 1
		get_tree().change_scene_to_file.call_deferred("res://scenes/level.tscn")


func _process(_delta: float) -> void:
	_f += 1
	_drive()
	if _f in [int(frames * 0.5), frames]:
		var img := get_viewport().get_texture().get_image()
		var path := out if _f == frames else out.replace(".png", "_a.png")
		img.save_png(path)
		print("saved ", path)
	if _f >= frames:
		get_tree().quit()


## steps: "action@from-to,action@from-to" using player-1 actions (p0_*)
func _drive() -> void:
	if steps == "":
		return
	for s in steps.split(","):
		var parts := s.split("@")
		var rng := parts[1].split("-")
		var on := _f >= int(rng[0]) and _f <= int(rng[1])
		for act in parts[0].split("+"):
			var name := StringName(act)
			if InputMap.has_action(name):
				if on and not Input.is_action_pressed(name):
					Input.action_press(name)
				elif not on and Input.is_action_pressed(name) and _f == int(rng[1]) + 1:
					Input.action_release(name)
