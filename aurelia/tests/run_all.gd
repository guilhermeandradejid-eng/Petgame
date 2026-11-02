extends Node
## Headless unit checks.  godot --headless --path aurelia res://tests/run_all.tscn
## (run `godot --headless --path aurelia --import` once first on a fresh clone)

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		_fail += 1


func _ready() -> void:
	await get_tree().process_frame
	_test_contracts()
	_test_data()
	_test_combat_math()
	_test_stage()
	print("TESTS ", "FAILED: %d" % _fail if _fail > 0 else "PASSED")
	get_tree().quit(1 if _fail > 0 else 0)


func _test_contracts() -> void:
	print("contracts")
	for ch in ["ren", "capmook", "hopkin"]:
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/contracts/%s.contract.json" % ch))
		var sheet := AnimSheet.get_sheet(ch)
		_check(sheet.tex != null and sheet.ntex != null, "%s textures load" % ch)
		for name in contract["anims"]:
			var ticks: Array = contract["anims"][name]["ticks"]
			var total := 0
			for t in ticks:
				total += int(t)
			_check(sheet.total_ticks(name) == total, "%s.%s total ticks == contract (%d)" % [ch, name, total])
			var acc := 0
			var ok := true
			for l in ticks.size():
				if sheet.at(name, acc)["logical"] != l or sheet.at(name, acc + int(ticks[l]) - 1)["logical"] != l:
					ok = false
				acc += int(ticks[l])
			_check(ok, "%s.%s tick->logical frame mapping" % [ch, name])
			var contact: Array = contract["anims"][name].get("contact", [])
			if not contact.is_empty():
				var wins := sheet.contact_ranges(name)
				var last: Vector2i = wins[-1]
				_check(wins.size() == contact.size() and last.y - last.x >= 6, "%s.%s %d contact window(s), last held >= 6 ticks" % [ch, name, wins.size()])


func _test_data() -> void:
	print("data")
	var ren := AnimSheet.get_sheet("ren")
	_check(Registry.weapon_order.size() == 3, "three weapons registered")
	for wid in Registry.weapon_order:
		var w := Registry.weapon(wid)
		_check(w != null and w.combo.size() == 3 and w.specials.size() == 2, "%s: 3-hit combo + 2 specials" % wid)
		for a in w.combo:
			_check(ren.has_anim(a.anim) and ren.contact_range(a.anim).x >= 0, "attack '%s' maps to an animation with a contact frame" % a.id)
		for sp in w.specials:
			_check(ren.has_anim(sp.anim) and not ren.contact_ranges(sp.anim).is_empty(), "special '%s' -> %s" % [sp.id, sp.anim])
			_check(sp.sp_cost > 0 and Registry.special_for_anim(sp.anim) == sp, "special '%s' indexed by animation" % sp.id)
		_check(w.combo[2].launch_height_px > 0.0, "%s finisher defines an explicit launch height" % wid)
	_check(Registry.spell_order.size() == 3, "three spells registered")
	for sid in Registry.spell_order:
		var sp := Registry.spell(sid)
		_check(sp != null and ren.has_anim(sp.cast_anim) and ren.contact_range(sp.cast_anim).x >= 0, "spell %s has a cast animation with a release frame" % sid)
	for eid in ["capmook", "hopkin"]:
		var e := Registry.enemy(eid)
		_check(e != null and AnimSheet.get_sheet(e.sprite_id).has_anim(e.attack_anim), "%s attack animation '%s' exists" % [eid, e.attack_anim])
		_check(AnimSheet.get_sheet(e.sprite_id).has_anim("windup") and AnimSheet.get_sheet(e.sprite_id).has_anim("walk"), "%s has windup + walk" % eid)
	_check(Registry.enemy("dummy").dummy, "training dummy flagged")
	for a in ["ready", "victory", "death", "hurt", "jump", "dash", "run", "walk", "idle"]:
		_check(ren.has_anim(a), "ren has '%s'" % a)


func _test_combat_math() -> void:
	print("combat math")
	Game.arena_active = true
	Game.arena_center = Vector3.ZERO
	Game.arena_radius = 4.0
	var cl := Game.clamp_to_arena(Vector3(9, 0, 0), 0.5)
	_check(absf(cl.x - 3.5) < 0.01, "arena clamp keeps bodies inside the ring")
	Game.arena_active = false
	var v := Combat.launch_speed(26.0)
	var apex := v * v / (2.0 * Game.GRAVITY)
	_check(absf(apex - 26.0 * Game.PX) < 0.001, "launch apex == requested pixels (same launch every hit)")
	var dummy := Node3D.new()
	add_child(dummy)
	dummy.global_position = Vector3(1.0, 0, 0)
	_check(Combat.hit_test(Vector3(0.8, 0, 0), 0.5, dummy, 0.5), "hit_test connects in range")
	_check(not Combat.hit_test(Vector3(-3, 0, 0), 0.5, dummy, 0.5), "hit_test misses out of range")
	dummy.free()


func _test_stage() -> void:
	print("stage")
	var holder := Node3D.new()
	add_child(holder)
	var info := StageBuilder.new().build(holder, 1337)
	_check(int(info["props"]) > 1500, "stage generated %d props" % info["props"])
	_check((info["encounters"] as Array).size() >= 3, "stage defines encounters")
	holder.free()
