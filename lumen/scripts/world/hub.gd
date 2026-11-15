class_name Hub
extends Level
## Vila do Farol: o ponto de encontro entre as runs. Aqui o grupo troca de classe e de
## roupa, compra melhorias permanentes, treina no boneco e abre o portal.

var dummy_point := Vector3(7.5, 0, 3.0)
var dummy_yaw := -PI * 0.5

func build(_room: Dictionary) -> void:
	rng.seed = 20261
	make_bounds(17.0, 0.06)
	spawn_yaw = 0.0
	for i in 4:
		spawn_points.append(Vector3((i - 1.5) * 1.6, 0.1, 5.0))
	make_environment({"sun_dir": Vector2(-38, 35), "sun_col": "ffe2b0", "sun_e": 1.6, "amb": "9a9cf0", "amb_e": 0.8,
		"sky_top": "4f8fe0", "sky_hor": "ffe0b8", "ground": "6a8a70", "fog": "ffe6c8", "fog_d": 0.007, "glow": 0.7, "vol": true, "vol_d": 0.006})
	build_floor(Color("5aa868"), Color("78c06a"), Color("2e6e5a"), 12.0, Color(Color("d8c79a"), 0.75))
	add_floor_collision()
	add_wall_collision()
	_ring()
	_village()
	_spots()
	_greens()
	add_motes(Color("fff2a0"), 50, 15.0, 5.0)

func _ring() -> void:
	var walls := KitLib.by_tag("env_forest", "wall")
	var trees := KitLib.by_tag("env_forest", "tree")
	var a := 0.0
	while a < TAU - 0.02:
		var p := point_at(a)
		var step := 3.7 / maxf(p.length(), 1.0)
		var mid := a + step * 0.5
		var out := Vector3(cos(mid), 0, sin(mid))
		if walls.size() > 0:
			var piece: String = walls[rng.randi() % walls.size()]
			var depth := float(KitLib.meta("env_forest", piece).get("size", [4, 2, 4])[1])
			var mi := KitLib.make("env_forest", piece)
			mi.position = point_at(mid) + out * (depth * 0.5 - 0.15)
			mi.rotation.y = atan2(out.x, out.z) + PI
			mi.scale = Vector3(1.04, rng.randf_range(0.8, 1.0), 1.0)
			add_child(mi)
		elif trees.is_empty():
			var mi2 := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3.4, rng.randf_range(3.0, 4.5), 2.4)
			mi2.mesh = bm
			mi2.position = point_at(mid, 1.06) + Vector3(0, bm.size.y * 0.5 - 0.3, 0)
			mi2.rotation.y = -mid + PI * 0.5
			mi2.material_override = Mats.toon(Color("6f8f7a").darkened(rng.randf() * 0.15))
			add_child(mi2)
		a += step
	for i in 26:
		if trees.is_empty():
			break
		var a2 := rng.randf() * TAU
		var mi3 := KitLib.make("env_forest", trees[rng.randi() % trees.size()])
		mi3.position = point_at(a2) + Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(3.0, 11.0)
		mi3.rotation.y = rng.randf() * TAU
		mi3.scale = Vector3.ONE * rng.randf_range(1.1, 1.8)
		add_child(mi3)
	for nm in KitLib.by_tag("env_hub", "backdrop"):
		if nm.contains("blades"):
			continue
		var mi4 := KitLib.make("env_hub", nm)
		mi4.position = Vector3(-17.0, 0, -22.0)
		mi4.rotation.y = 0.5
		add_child(mi4)
		if KitLib.has("env_hub", "windmill_blades"):
			var bl := KitLib.make("env_hub", "windmill_blades")
			var bp: Array = KitLib.meta("env_hub", nm).get("blades", {}).get("pos", [0, -2.05, 6.7])
			bl.position = Vector3(float(bp[0]), float(bp[2]), -float(bp[1]))
			mi4.add_child(bl)
			var tw := bl.create_tween().set_loops()
			tw.tween_property(bl, "rotation:z", TAU, 14.0).from(0.0)

func _village() -> void:
	var k := "env_hub"
	var b := KitLib.by_tag(k, "building")
	var spots := [[Vector3(-10.5, 0, -6.5), 0.75], [Vector3(10.5, 0, -7.5), -0.7], [Vector3(-11.5, 0, 5.0), 1.3]]
	for i in spots.size():
		if b.is_empty():
			break
		place(k, b[i % b.size()], spots[i][0], spots[i][1])
	for nm in KitLib.by_tag(k, "landmark"):
		place(k, nm, Vector3(-4.5, 0, -3.0), 0.4)
		break
	_try(k, "well", Vector3(4.5, 0, 6.5), 0.3)
	_try(k, "cart", Vector3(11.5, 0, 1.0), -1.2)
	_try(k, "hay", Vector3(12.8, 0, 3.4), 0.6)
	_try(k, "market_crates", Vector3(9.6, 0, -1.6), -0.9)
	_try(k, "mailbox", Vector3(-7.4, 0, -3.4), 0.9)
	_try(k, "flower_bed", Vector3(-7.6, 0, 7.8), 0.2)
	_try(k, "flower_bed", Vector3(6.8, 0, -9.6), -0.4)
	_try(k, "gate", Vector3(0, 0, 14.6), 0.0)
	for p in [Vector3(-3.4, 0, 4.5), Vector3(3.4, 0, 4.5), Vector3(-3.2, 0, -9.0), Vector3(3.2, 0, -9.0)]:
		_try(k, "lamp_post", p, 0.0)
	if KitLib.has(k, "bunting"):
		for i in 3:
			var mi := KitLib.make(k, "bunting")
			mi.position = Vector3(0, 3.3, 4.5 - i * 4.4)
			mi.scale = Vector3(1.7, 1.0, 1.0)
			add_child(mi)
	if KitLib.has(k, "plaza_tile"):
		var xf: Array = []
		for ix in range(-2, 3):
			for iz in range(-3, 4):
				if rng.randf() < 0.8:
					xf.append(Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI * 0.5), Vector3(ix * 2.0, 0.01, iz * 2.0 + 1.0)))
		scatter_multi(k, "plaza_tile", xf)
	if KitLib.has(k, "fence"):
		for i in 5:
			_try(k, "fence", Vector3(-13.5 + i * 2.0, 0, 10.5), 0.0)
			_try(k, "fence", Vector3(5.5 + i * 2.0, 0, 10.5), 0.0)
	_try("props", "campfire", Vector3(5.5, 0, 1.5), 0.0)
	_try("props", "bench", Vector3(7.4, 0, 1.2), -1.4)
	_try("props", "bench", Vector3(5.2, 0, 3.6), 3.0)
	_try("props", "banner", Vector3(-2.6, 0, -11.6), 0.0)
	_try("props", "banner", Vector3(2.6, 0, -11.6), 0.0)
	_try("props", "barrel", Vector3(-9.0, 0, 1.6), 0.4)
	_try("props", "crate", Vector3(-9.8, 0, 2.6), 0.9)
	_try("props", "signpost", Vector3(1.9, 0, 10.6), -0.4)

func _try(kit: String, piece: String, pos: Vector3, yaw: float) -> void:
	if KitLib.has(kit, piece):
		place(kit, piece, pos, yaw)

func _spots() -> void:
	var defs := [["start", Vector3(0, 0, -12.2), 0.0], ["wardrobe", Vector3(-7.6, 0, 1.2), PI * 0.5],
		["altar", Vector3(7.8, 0, -4.6), -PI * 0.5], ["classes", Vector3(-6.4, 0, 6.2), PI * 0.6]]
	for d in defs:
		var s := Spot.new()
		s.kind = d[0]
		s.position = d[1]
		s.rotation.y = d[2]
		add_child(s)
		add_obstacle(d[1], 1.0)

func _greens() -> void:
	var k := "env_forest"
	for tag in ["grass", "flower", "bush", "fern", "pebble"]:
		var names := KitLib.by_tag(k, tag)
		if names.is_empty():
			continue
		var per: Dictionary = {}
		var n: int = {"grass": 260, "flower": 60, "bush": 14, "fern": 14, "pebble": 14}[tag]
		for i in n:
			var a := rng.randf() * TAU
			var p := point_at(a, sqrt(rng.randf()) if tag in ["grass", "flower"] else rng.randf_range(0.75, 0.98))
			if absf(p.x) < 5.0 and p.z > -9.0 and p.z < 8.0:
				continue
			if not is_free(p, 0.3):
				continue
			var nm: String = names[rng.randi() % names.size()]
			var s := rng.randf_range(0.8, 1.3)
			if not per.has(nm):
				per[nm] = []
			per[nm].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		for nm in per:
			scatter_multi(k, nm, per[nm])
