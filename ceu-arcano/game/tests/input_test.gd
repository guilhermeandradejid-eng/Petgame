extends Node
# Simula o jogador 1 apertando teclas e confere se cada ação muda o estado esperado.
# godot --headless --fixed-fps 60 --path . res://tests/input_test.tscn -- --char=lumia
var battle
var frame := 0
var t0 := 0
var results := []
var steps := []
var cid := "lumia"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--char="): cid = a.substr(7)
	Game.mode = Game.Mode.VS_CPU
	Game.p_cpu = [false, true]
	Game.cpu_level = -1
	Game.p_chars = [cid, "rubi" if cid == "lumia" else "lumia"]
	process_mode = Node.PROCESS_MODE_ALWAYS
	# [frame relativo, ação, segurar frames, estado/anim esperado depois de N frames, N]
	steps = [
		[0, "p1_right", 20, "walk_f", 10],
		[30, "p1_left", 20, "walk_b", 10],
		[60, "p1_down", 20, "crouch", 10],
		[90, "p1_up", 2, "air", 8],
		[100, "p1_up", 2, "jump", 4],          # pulo duplo (anim)
		[110, "p1_dash", 12, "fly", 4],         # voo no ar
		[200, "p1_a", 2, "a5_1", 2],
		[212, "p1_a", 2, "a5_2", 6],            # encadeia mesmo errando
		[232, "p1_a", 2, "a5_3", 6],
		[300, "p1_b", 2, "b5", 3],
		[360, "p1_c", 2, "c5", 3],
		[420, "p1_dash", 2, "dash_f", 3],
		[470, "p1_dash", 2, "dash_f", 2],
		[474, "p1_a", 2, "ad", 3],              # ataque correndo
		[540, "p1_switch", 2, "", 0],
		[560, "p1_spell", 2, "declare", 3],     # carta de feitiço
		[800, "p1_down", 2, "crouch", 1],
	]
	_start.call_deferred()

func _start() -> void:
	battle = load("res://scenes/battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle

func _physics_process(_d: float) -> void:
	frame += 1
	if battle == null or battle.phase != "fight":
		t0 = frame + 5
		return
	var f = battle.fighters[0]
	var rel := frame - t0
	if rel == 1:
		battle.fighters[1].pos.x = 300.0
		f.hand = [cid + "_s1", cid + "_s1", "elixir", cid + "_s2"]
		f.spirit = 5.0
	if rel == 535:
		f.spirit = 5.0
		f.hand = ["elixir", cid + "_s1", cid + "_s1", cid + "_s1"]   # o switch põe s1 na frente
	for s in steps:
		if rel == s[0]:
			Input.action_press(s[1])
		if rel == s[0] + s[2]:
			Input.action_release(s[1])
		if s[3] != "" and rel == s[0] + s[4]:
			var ok: bool = f.state == s[3] or f.anim == s[3] or f.mv_id == s[3] and f.state == "move"
			results.append([s[1], s[3], f.state, f.anim, ok])
	if rel == 900:
		var bad := 0
		for r in results:
			print("%-10s esperado=%-8s estado=%-10s anim=%-10s %s" % [r[0], r[1], r[2], r[3], "OK" if r[4] else "FALHOU"])
			if not r[4]:
				bad += 1
		print("RESULTADO falhas=%d de %d" % [bad, results.size()])
		get_tree().quit(1 if bad > 0 else 0)
