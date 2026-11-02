extends Node
## Automated mechanics test: `godot --headless --path . -- --playtest`.
## Loads level 1, drives both characters with simulated input and checks
## the numbers that the level design depends on. Prints PASS/FAIL lines.

var level: LevelBase
var lumi: Player
var bolota: Player
var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.coop = true
	Game.current_level = 0
	get_tree().change_scene_to_file.call_deferred("res://scenes/level.tscn")
	await get_tree().create_timer(1.0).timeout
	level = get_tree().current_scene.get_node("Level")
	lumi = level.players[0]
	bolota = level.players[1]
	await _run()
	print("PLAYTEST DONE, failures: ", fails)
	get_tree().quit(1 if fails else 0)


func check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func press(p: int, a: String) -> void:
	Input.action_press(Game.act(p, a))


func release(p: int, a: String) -> void:
	Input.action_release(Game.act(p, a))


func tap(p: int, a: String) -> void:
	press(p, a)
	await frames(2)
	release(p, a)


func place(pl: Player, pos: Vector3) -> void:
	pl.global_position = pos
	pl.velocity = Vector3.ZERO
	pl._set_state("normal")


func max_height(pl: Player, n: int) -> float:
	var y0 := pl.global_position.y
	var best := y0
	for i in n:
		await get_tree().physics_frame
		best = maxf(best, pl.global_position.y)
	return best - y0


func _run() -> void:
	# park Bolota out of the way
	place(bolota, Vector3(5, 0.3, 4))
	place(lumi, Vector3(-3, 0.3, 4))
	await frames(30)
	check("lumi grounded at spawn", lumi.is_on_floor())

	# --- jump heights
	press(0, "jump")
	var h := await max_height(lumi, 50)
	release(0, "jump")
	check("lumi full jump ~2m", h > 1.8 and h < 2.6, "h=%.2f" % h)
	await frames(40)
	press(1, "jump")
	h = await max_height(bolota, 50)
	release(1, "jump")
	check("bolota full jump ~2.25m", h > 2.0 and h < 2.8, "h=%.2f" % h)
	await frames(40)
	await tap(0, "jump")
	h = await max_height(lumi, 40)
	check("short hop lower than full jump", h < 1.5, "h=%.2f" % h)
	await frames(40)
	# double jump
	var y0 := lumi.global_position.y
	press(0, "jump")
	await frames(20)
	release(0, "jump")
	await frames(2)
	press(0, "jump")
	var best := 0.0
	for i in 60:
		await get_tree().physics_frame
		best = maxf(best, lumi.global_position.y - y0)
	release(0, "jump")
	check("lumi double jump > 3m", best > 3.0, "h=%.2f" % best)
	await frames(60)

	# --- run speed
	press(0, "right")
	await frames(40)
	var sp := Vector2(lumi.velocity.x, lumi.velocity.z).length()
	release(0, "right")
	check("lumi reaches run speed", sp > 7.5, "v=%.2f" % sp)
	await frames(30)

	# --- two plates open the gate (level 1, island C)
	place(lumi, Vector3(-5, 0.4, -38))
	place(bolota, Vector3(5, 0.4, -38))
	await frames(30)
	check("plates a+b active", level.channel("a") and level.channel("b"))
	var gates := level.get_children().filter(func(n): return n is Gate)
	check("first gate opened", gates.size() > 0 and gates[0].opened)

	# --- carry and throw Lumi onto the tower (top y=4.5 at (-4,-68))
	place(bolota, Vector3(-4, 0.4, -64.4))
	place(lumi, Vector3(-4.6, 0.4, -64.0))
	bolota.facing = Vector3.FORWARD
	await frames(20)
	await tap(1, "grab")
	await frames(5)
	check("bolota lifted lumi", lumi.state == "carried", lumi.state)
	place(bolota, Vector3(-4, 0.4, -65.5))
	await frames(5)
	await tap(1, "grab")
	var top := 0.0
	for i in 28:
		await get_tree().physics_frame
		top = maxf(top, lumi.global_position.y)
	press(0, "fwd")
	for i in 26:
		await get_tree().physics_frame
		top = maxf(top, lumi.global_position.y)
	release(0, "fwd")
	for i in 60:
		await get_tree().physics_frame
		top = maxf(top, lumi.global_position.y)
	await frames(60)
	check("thrown lumi gets high (> 5.5)", top > 5.5, "top=%.2f" % top)
	check("lumi landed on tower plate", level.channel("c"), "pos=%s" % lumi.global_position)
	place(bolota, Vector3(4, 0.4, -65))
	await frames(20)
	check("bolota holds heavy plate", level.channel("d"))
	check("second gate opened", gates.size() > 1 and gates[1].opened)
	place(bolota, Vector3(0, 0.4, -60))
	place(lumi, Vector3(4, 0.4, -65))
	await frames(20)
	check("lumi alone is too light for heavy plate", not level.channel("d"))

	# --- ground pound defeats an urchin
	var urchins := level.get_children().filter(func(n): return n is Urchin)
	var u: Urchin = urchins[0]
	place(lumi, Vector3(-8, 0.4, -90))
	place(bolota, u.global_position + Vector3(0, 3.5, 0))
	await frames(4)
	await tap(1, "pound")
	await frames(60)
	check("bolota pound defeats urchin", not is_instance_valid(u) or u._dead)

	# --- crate on plate holds the non-latching gate
	var crates := level.get_children().filter(func(n): return n is Crate and not n.breakable)
	var cr: Crate = crates[0]
	place(bolota, cr.global_position + Vector3(0, 0, 1.2))
	await frames(10)
	await tap(1, "grab")
	await frames(5)
	check("bolota picked crate", bolota.carrying == cr)
	place(bolota, Vector3(-4.5, 0.4, -95.6))
	bolota.facing = Vector3.FORWARD
	await frames(5)
	await tap(1, "grab")
	await frames(90)
	check("crate holds plate e", level.channel("e"), "crate=%s" % cr.global_position)

	# --- tether: Lumi on the high island pulls Bolota up
	place(lumi, Vector3(0, 9.4, -136))
	place(bolota, Vector3(0, 0.4, -126))
	await frames(20)
	await tap(0, "grab")
	await frames(60)
	var d := bolota.global_position.distance_to(lumi.global_position)
	check("tether pulled bolota to lumi", d < 3.0 and bolota.global_position.y > 8.0, "d=%.2f y=%.2f" % [d, bolota.global_position.y])

	# --- wind fan lifts a hovering Lumi
	place(bolota, Vector3(-3, 9.4, -140))
	place(lumi, Vector3(0, 1.5, -125.5))
	press(0, "jump")
	await frames(18)
	release(0, "jump")
	await frames(2)
	press(0, "jump")
	await frames(4)
	release(0, "jump")
	await frames(2)
	press(0, "jump")
	var hy := 0.0
	for i in 120:
		await get_tree().physics_frame
		hy = maxf(hy, lumi.global_position.y)
	release(0, "jump")
	check("fan lifts hovering lumi above the high island (9)", hy > 9.5, "max y=%.2f" % hy)
	await frames(90)

	# --- falling out of the world -> bubble back to the partner
	place(bolota, Vector3(0, 9.4, -142))
	await frames(30)
	place(lumi, Vector3(30, -35, -60))
	await frames(5)
	check("fallen lumi becomes a bubble", lumi.state == "bubble", lumi.state)
	await frames(300)
	check("bubble returned lumi to bolota", lumi.state != "bubble" and lumi.global_position.distance_to(bolota.global_position) < 4.0,
			"state=%s d=%.1f" % [lumi.state, lumi.global_position.distance_to(bolota.global_position)])

	# --- goal needs both
	place(lumi, Vector3(0, 9.6, -146))
	await frames(30)
	check("goal waits for partner", not level.done)
	place(bolota, Vector3(1, 9.6, -146))
	await frames(30)
	check("goal completes with both", level.done)
