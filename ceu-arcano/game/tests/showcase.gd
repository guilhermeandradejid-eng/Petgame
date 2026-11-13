extends Node
# Vitrine: bonecos parados; força cada carta de feitiço e captura quadros-chave.
# godot --path . res://tests/showcase.tscn -- --out=/caminho
var out := "user://showcase"
var battle
var frame := 0
var plan := []   # [frame, pid, card]
var shots := {}  # frame -> nome
var ko_only := false
var seq_from := -1
var seq_to := -1
var seq_every := 2

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
	ko_only = "--ko-only" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seq="):
			var pr := a.substr(6).split(":")
			seq_from = int(pr[0])
			seq_to = int(pr[1])
			seq_every = int(pr[2]) if pr.size() > 2 else 2
	for c in ([] if ko_only else [[0, "lumia_s1"], [0, "lumia_s2"], [0, "lumia_s3"], [1, "rubi_s1"], [1, "rubi_s2"], [1, "rubi_s3"]]):
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
	if seq_from >= 0:
		if frame >= seq_from and frame <= seq_to and (frame - seq_from) % seq_every == 0:
			var sn := "seq_%05d" % frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, sn])
		if frame > seq_to:
			get_tree().quit()
		return
	if shots.has(frame):
		var name: String = shots[frame]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	var ko_t := 200 if ko_only else 170 + 300 * 6
	if frame == ko_t:
		var f = battle.fighters[0]
		battle.fighters[1].hp = 200.0
		battle.fighters[1].pos.x = 50.0
		f.pos.x = 0.0
		f.start_move("a6")
	for off in [16, 24, 40, 70, 120, 200, 260]:
		if frame == ko_t + off:
			var nm := "ko_%03d" % off
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, nm])
	if frame > ko_t + 280:
		get_tree().quit()
