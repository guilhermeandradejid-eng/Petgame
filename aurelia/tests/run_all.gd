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
	for ch in ["ren", "capmook"]:
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
				var r := sheet.contact_range(name)
				_check(r.y - r.x == int(ticks[int(contact[0])]) and r.y - r.x >= 6, "%s.%s contact frame held >= 6 ticks" % [ch, name])


func _test_data() -> void:
	print("data")
	var w := Registry.weapon("bronze_sword")
	_check(w != null and w.combo.size() == 3, "bronze_sword has a 3-hit combo")
	var ren := AnimSheet.get_sheet("ren")
	for a in w.combo:
		_check(ren.has_anim(a.anim) and ren.contact_range(a.anim).x >= 0, "attack '%s' maps to an animation with a contact frame" % a.id)
	_check(w.combo[2].launch_height_px > 0.0, "finisher defines an explicit launch height")
	var sp := Registry.spell("ice_lance")
	_check(sp != null and ren.contact_range(sp.cast_anim).x >= 0, "ice_lance loads and has a release frame")
	var cm := Registry.enemy("capmook")
	_check(cm != null and AnimSheet.get_sheet(cm.sprite_id).has_anim(cm.attack.anim), "capmook attack animation exists")
	_check(Registry.enemy("dummy").dummy, "training dummy flagged")


func _test_combat_math() -> void:
	print("combat math")
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
	_check((info["enemy_spawns"] as Array).size() >= 3, "stage defines enemy spawns")
	holder.free()
