extends Node
## Automated mechanics test: `godot --headless --path . -- --playtest`.
## Loads level 1, drives both characters with simulated input and checks
## the numbers that the level design depends on. Prints PASS/FAIL lines.

var level: LevelBase
var lumi: Player
var bolota: Player
var fails := 0
var which := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.coop = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			which = int(a.substr(8))
	Game.current_level = which
	get_tree().change_scene_to_file.call_deferred("res://scenes/level.tscn")
	await get_tree().create_timer(1.0).timeout
	level = get_tree().current_scene.get_node("Level")
	lumi = level.players[0]
	bolota = level.players[1]
	match which:
		0:
			await _run_valley()
		1:
			await _run0()
		2:
			await _run()
		3:
			await _run2()
		_:
			await _run3()
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

	# --- walk from the island onto the wooden bridge (step-up over the rim)
	place(lumi, Vector3(0, 0.4, -44))
	place(bolota, Vector3(1.0, 0.4, -40))
	press(0, "fwd")
	press(1, "fwd")
	await frames(70)
	release(0, "fwd")
	release(1, "fwd")
	check("walks off island onto bridge", lumi.global_position.z < -48.6 and lumi.global_position.y > -0.5, "p=%s" % lumi.global_position)
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


func of_type(t) -> Array:
	return level.get_children().filter(func(n): return is_instance_of(n, t))


func _run2() -> void:
	var planets := of_type(Planetoid)
	var rings := of_type(LaunchRing)
	var p1: Planetoid = planets[0]
	place(bolota, Vector3(4, 0.4, 3))
	place(lumi, rings[0].global_position + Vector3(0, 0.3, 0))
	await frames(150)
	var d := lumi.global_position.distance_to(p1.global_position)
	check("ring flew lumi onto planet 1", d < 8.6 and lumi.is_on_floor(), "d=%.2f state=%s" % [d, lumi.state])
	check("lumi up is radial", lumi.up.dot((lumi.global_position - p1.global_position).normalized()) > 0.95)
	press(0, "fwd")
	var mn := 99.0
	var mx := 0.0
	for i in 200:
		await get_tree().physics_frame
		var dd := lumi.global_position.distance_to(p1.global_position)
		mn = minf(mn, dd)
		mx = maxf(mx, dd)
	release(0, "fwd")
	check("walking stays on planet surface", mn > 6.5 and mx < 9.5, "min=%.2f max=%.2f" % [mn, mx])
	press(0, "jump")
	var hh := 0.0
	for i in 40:
		await get_tree().physics_frame
		hh = maxf(hh, lumi.global_position.distance_to(p1.global_position) - 7.0)
	release(0, "jump")
	await frames(60)
	check("jump on planet returns to surface", lumi.is_on_floor() and hh > 1.5, "h=%.2f" % hh)
	# plates on opposite sides
	var plates := of_type(PressurePlate)
	place(lumi, plates[0].global_position + plates[0].global_basis.y * 0.5)
	place(bolota, plates[1].global_position + plates[1].global_basis.y * 0.5)
	await frames(40)
	check("opposite plates power ring", level.channel("p1"))
	# ring 2 -> planet 2
	var p2: Planetoid = planets[1]
	place(bolota, rings[1].global_position + rings[1].global_basis.y * 0.5)
	await frames(160)
	d = bolota.global_position.distance_to(p2.global_position)
	check("ring 2 reaches planet 2", d < 6.8, "d=%.2f state=%s" % [d, bolota.state])
	var sw: PoundSwitch = of_type(PoundSwitch)[0]
	place(bolota, sw.global_position + sw.global_basis.y * 3.0)
	await frames(3)
	await tap(1, "pound")
	await frames(40)
	check("pound timed switch on planet", level.channel("p2"), "b=%s" % bolota.state)
	place(lumi, rings[2].global_position + rings[2].global_basis.y * 0.5)
	await frames(150)
	var m1: Planetoid = planets[2]
	d = lumi.global_position.distance_to(m1.global_position)
	check("ring 3 reaches moon 1", d < 5.2, "d=%.2f" % d)
	# hop from moon 1 to moon 2
	var m2: Planetoid = planets[3]
	var dir := (m2.global_position - m1.global_position).normalized()
	place(lumi, m1.global_position + dir * 3.9)
	await frames(30)
	press(0, "jump")
	await frames(30)
	release(0, "jump")
	await frames(90)
	d = lumi.global_position.distance_to(m2.global_position)
	check("jump between twin moons switches gravity", d < 4.6, "d=%.2f d1=%.2f" % [d, lumi.global_position.distance_to(m1.global_position)])
	place(lumi, rings[3].global_position + rings[3].global_basis.y * 0.5)
	await frames(150)
	check("last ring reaches goal island", lumi.global_position.distance_to(Vector3(55, 10, -129)) < 6.0 and lumi.is_on_floor(), "p=%s" % lumi.global_position)


func _run3() -> void:
	var sw: PoundSwitch = of_type(PoundSwitch)[0]
	place(lumi, Vector3(0, 0.4, -24))
	place(bolota, sw.global_position + Vector3(0, 3, 0))
	await frames(3)
	await tap(1, "pound")
	await frames(30)
	var bridges := of_type(Bridge).filter(func(b): return b.channel == "t1")
	check("timed switch materializes bridge", bridges[0].solid)
	press(0, "fwd")
	await frames(170)
	release(0, "fwd")
	check("lumi crossed timed bridge", lumi.global_position.z < -40.0 and lumi.global_position.y > -1.0, "p=%s" % lumi.global_position)
	await frames(400)
	check("timed bridge vanishes again", not bridges[0].solid)
	# rift held open from both sides
	var plates := of_type(PressurePlate)
	var rifts := of_type(Rift)
	place(bolota, plates[0].global_position + Vector3(0, 0.5, 0))
	await frames(20)
	check("rift opens with plate", rifts[0].is_open())
	place(lumi, rifts[0].global_position + Vector3(0, 1.2, 1.5))
	lumi.velocity = Vector3(0, 0, -3)
	for i in 30:
		await get_tree().physics_frame
		if lumi.global_position.x > 20.0:
			break
	check("rift teleports lumi", lumi.global_position.x > 25.0, "p=%s" % lumi.global_position)
	place(lumi, plates[1].global_position + Vector3(0, 0.5, 0))
	place(bolota, Vector3(-2, 0.4, -46))
	await frames(20)
	check("far plate keeps rift open", rifts[0].is_open())
	# tide toggle flips the staircase
	var tide := of_type(Bridge).filter(func(b): return b.channel == "tide")
	var before: bool = tide[0].solid
	var tsw: PoundSwitch = of_type(PoundSwitch)[1]
	place(bolota, tsw.global_position + Vector3(0, 3, 0))
	await frames(3)
	await tap(1, "pound")
	await frames(30)
	check("tide switch flips blocks", tide[0].solid != before and tide[1].solid == before)
	# both far plates open the final gate
	place(lumi, plates[2].global_position + Vector3(0, 0.5, 0))
	place(bolota, plates[3].global_position + Vector3(0, 0.5, 0))
	await frames(30)
	var g: Gate = of_type(Gate)[0]
	check("plates on two islands open final gate", g.opened)


func _run0() -> void:
	# walk the whole first island onto the bridge after opening the gate
	place(lumi, Vector3(-5, 0.4, -4))
	place(bolota, Vector3(5, 0.4, -4))
	await frames(30)
	check("T: plates open gate", of_type(Gate)[0].opened)
	place(lumi, Vector3(0, 0.4, -6))
	press(0, "fwd")
	await frames(150)
	release(0, "fwd")
	check("T: walk over bridge to island B", lumi.global_position.z < -19.0 and lumi.global_position.y > -0.5, "p=%s" % lumi.global_position)
	# throw onto tower
	place(bolota, Vector3(-4.5, 0.4, -26.5))
	place(lumi, Vector3(-5.0, 0.4, -26.0))
	bolota.facing = Vector3.FORWARD
	await frames(10)
	await tap(1, "grab")
	await frames(5)
	await tap(1, "grab")
	await frames(28)
	press(0, "fwd")
	await frames(26)
	release(0, "fwd")
	await frames(60)
	check("T: lumi on tower plate", level.channel("c"), "p=%s" % lumi.global_position)
	place(bolota, Vector3(4.5, 0.4, -26))
	await frames(20)
	check("T: second gate", of_type(Gate)[1].opened)
	# timed bridge
	var sw: PoundSwitch = of_type(PoundSwitch)[0]
	place(lumi, Vector3(0, 0.4, -55))
	place(bolota, sw.global_position + Vector3(0, 3, 0))
	await frames(3)
	await tap(1, "pound")
	await frames(20)
	press(0, "fwd")
	await frames(110)
	release(0, "fwd")
	check("T: crossed timed bridge to D", lumi.global_position.z < -66.0 and lumi.global_position.y > -0.5, "p=%s" % lumi.global_position)
	# fan + tether
	place(bolota, Vector3(0, 0.4, -75))
	place(lumi, Vector3(0, 1.0, -78.5))
	press(0, "jump")
	await frames(10)
	release(0, "jump")
	await frames(20)
	press(0, "jump")
	await frames(130)
	press(0, "fwd")
	await frames(60)
	release(0, "fwd")
	release(0, "jump")
	await frames(60)
	check("T: lumi reached high island via fan", lumi.global_position.y > 8.5 and lumi.is_on_floor(), "p=%s" % lumi.global_position)
	await tap(0, "grab")
	await frames(60)
	check("T: tether pulls bolota up", bolota.global_position.y > 8.0, "p=%s" % bolota.global_position)
	# ring -> planet -> ring -> goal
	var rings := of_type(LaunchRing)
	place(lumi, rings[0].global_position + Vector3(0, 0.4, 0))
	await frames(140)
	var p: Planetoid = of_type(Planetoid)[0]
	check("T: ring to planet", lumi.global_position.distance_to(p.global_position) < 5.8, "d=%.2f" % lumi.global_position.distance_to(p.global_position))
	place(lumi, rings[1].global_position + rings[1].global_basis.y * 0.5)
	place(bolota, rings[1].global_position + rings[1].global_basis.y * 0.5 + rings[1].global_basis.x * 0.6)
	await frames(160)
	check("T: both reach goal island", lumi.global_position.distance_to(Vector3(0, 9, -141)) < 9.0 and bolota.global_position.distance_to(Vector3(0, 9, -141)) < 9.0, "l=%s b=%s" % [lumi.global_position, bolota.global_position])
	place(lumi, Vector3(0, 9.6, -144))
	place(bolota, Vector3(1, 9.6, -144))
	await frames(30)
	check("T: goal completes", level.done)


func _run_valley() -> void:
	var v = level
	check("V: spawn on ground", lumi.is_on_floor(), "p=%s" % lumi.global_position)
	# river: plates extend the bridge, then walk across
	place(lumi, v.at(-5, -25, 0.4))
	place(bolota, v.at(5, -25, 0.4))
	await frames(30)
	check("V: river bridge latched", level.channel("river"))
	place(bolota, v.at(0, -28, 0.4))
	place(lumi, v.at(1.2, -28, 0.4))
	press(0, "fwd")
	press(1, "fwd")
	await frames(230)
	release(0, "fwd")
	release(1, "fwd")
	check("V: both crossed the river", lumi.global_position.z < -50.0 and bolota.global_position.z < -50.0 and not lumi.state == "bubble",
			"l=%s b=%s" % [lumi.global_position, bolota.global_position])
	await frames(20)
	# falling in the river makes a bubble
	place(lumi, Vector3(-10, -1.0, -40))
	await frames(40)
	check("V: river is a hazard", lumi.state == "bubble", lumi.state)
	await frames(260)
	# cliff 1: throw Lumi up, she holds the elevator plate, Bolota rides up
	place(bolota, v.at(-4, -59.6, 0.4))
	place(lumi, v.at(-4.5, -59.0, 0.4))
	bolota.facing = Vector3.FORWARD
	await frames(10)
	await tap(1, "grab")
	await frames(5)
	await tap(1, "grab")
	await frames(16)
	press(0, "fwd")
	await frames(14)
	await tap(0, "jump")
	await frames(30)
	release(0, "fwd")
	await frames(30)
	check("V: lumi thrown up the cliff", lumi.global_position.y > 4.0, "p=%s" % lumi.global_position)
	place(lumi, v.at(-4, -68, 0.4))
	place(bolota, v.at(6, -58.9, 0.6))
	await frames(160)
	check("V: elevator lifts bolota", bolota.global_position.y > 4.3, "p=%s" % bolota.global_position)
	press(1, "fwd")
	await frames(60)
	release(1, "fwd")
	check("V: bolota walks onto the plateau", bolota.global_position.z < -63.0 and bolota.global_position.y > 4.0, "p=%s" % bolota.global_position)
	# forest gate with a crate on the heavy plate
	var cr: Crate = of_type(Crate).filter(func(c): return not c.breakable)[0]
	place(bolota, cr.global_position + Vector3(0, 0, 1.2))
	await frames(10)
	await tap(1, "grab")
	await frames(5)
	place(bolota, v.at(7, -84.6, 0.4))
	bolota.facing = Vector3.FORWARD
	await frames(5)
	await tap(1, "grab")
	await frames(90)
	check("V: crate holds the heavy plate", level.channel("heavy"), "c=%s" % cr.global_position)
	place(lumi, v.at(0, -88, 0.4))
	press(0, "fwd")
	await frames(60)
	release(0, "fwd")
	check("V: walk through the open forest gate", lumi.global_position.z < -95.0, "p=%s" % lumi.global_position)
	# cliff 2: fan + tether
	place(bolota, v.at(0, -97, 0.4))
	place(lumi, v.at(0, -100, 1.0))
	press(0, "jump")
	await frames(10)
	release(0, "jump")
	await frames(20)
	press(0, "jump")
	await frames(130)
	press(0, "fwd")
	await frames(60)
	release(0, "fwd")
	release(0, "jump")
	await frames(60)
	check("V: lumi on the upper plateau", lumi.global_position.y > 8.5 and lumi.is_on_floor(), "p=%s" % lumi.global_position)
	await tap(0, "grab")
	await frames(70)
	check("V: tether pulls bolota up", bolota.global_position.y > 8.0, "p=%s" % bolota.global_position)
	# ravine timed bridge
	var sw: PoundSwitch = of_type(PoundSwitch)[0]
	place(lumi, v.at(0, -117, 0.4))
	place(bolota, sw.global_position + Vector3(0, 3, 0))
	await frames(3)
	await tap(1, "pound")
	await frames(10)
	press(0, "fwd")
	await frames(170)
	release(0, "fwd")
	check("V: crossed the ravine", lumi.global_position.z < -134.0 and lumi.global_position.y > 8.0, "p=%s" % lumi.global_position)
	# goal
	place(lumi, v.at(0, -152, 0.6))
	place(bolota, v.at(1, -152, 0.6))
	await frames(30)
	check("V: goal completes", level.done)
