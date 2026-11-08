extends SceneTree
## godot --headless --path . -s res://tools/kit_bench.gd
## Mede quanto tempo o kit de upgrades leva para encaixar as peças (raios na lataria) em cada carro.
func _init() -> void:
	var lib: Node3D = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	var gm: Node = load("res://scripts/main.gd").new()
	gm._prep_materials(lib, {})
	var up := {"engine": 3, "armor": 3, "ammo": 3, "nitro": 3, "tires": 3, "dmg": 3, "rate": 3, "rear": 3}
	for k in Car.PLAYABLE:
		var c := Car.new()
		c.setup(lib, k, "rival", Color.RED)
		var t0 := Time.get_ticks_usec()
		var lo: Array = Car.LOADOUT[k]
		c.configure(lib, lo[0], lo[1], lo[2], up)
		var t1 := Time.get_ticks_usec()
		c.configure(lib, lo[0], lo[1], lo[2], up)
		var t2 := Time.get_ticks_usec()
		print("%-10s 1a vez %6.1f ms   de novo %5.1f ms   peças %d" % [k, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, c._kit.size()])
		c.free()
	lib.free()
	gm.free()
	quit()
