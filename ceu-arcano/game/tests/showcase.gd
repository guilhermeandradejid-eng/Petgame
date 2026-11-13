extends Node
# Vitrine: bonecos parados; força cada carta de feitiço e captura quadros-chave.
# godot --path . res://tests/showcase.tscn -- --out=/caminho
var out := "user://showcase"
var battle
var frame := 0
var plan := []   # [frame, pid, card]
var shots := {}  # frame -> nome

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Game.mode = Game.Mode.WATCH
	Game.p_cpu = [true, true]
	Game.cpu_level = -1
	Game.p_chars = ["lumia", "rubi"]
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := 170
	for c in [[0, "lumia_s1"], [0, "lumia_s2"], [0, "lumia_s3"], [1, "rubi_s1"], [1, "rubi_s2"], [1, "rubi_s3"]]:
		plan.append([t, c[0], c[1]])
		for off in [12, 30, 70, 110, 160]:
			shots[t + off] = "%s_%03d" % [c[1], off]
		t += 300
	_start.call_deferred()

func _start() -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle

func _physics_process(_d: float) -> void:
	frame += 1
	for p in plan:
		if frame == p[0]:
			var f = battle.fighters[p[1]]
			var o = battle.fighters[1 - p[1]]
			f.pos.x = -60.0 if p[1] == 0 else 60.0
			o.pos.x = 60.0 if p[1] == 0 else -60.0
			o.hp = 10000.0
			f.hand = [p[2], p[2], p[2], p[2]]
			f.inp.age["spell"] = 0
	if shots.has(frame):
		var name: String = shots[frame]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	if frame > 170 + 300 * 6:
		get_tree().quit()
