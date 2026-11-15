class_name Room
extends Level
## Sala de uma run, gerada a partir da semente: todos os jogadores montam a mesma arena.

const BIOME_LOOK := {
	"forest": {
		"floor_a": "3f9a68", "floor_b": "58b56a", "edge": "2a6658", "path": "b9b08a",
		"env": {"sun_dir": Vector2(-34, 48), "sun_col": "ffd9a0", "sun_e": 1.55, "amb": "8c8fe0", "amb_e": 0.75,
			"sky_top": "4a78c8", "sky_hor": "ffd2a6", "ground": "5a7a6a", "fog": "f2c4b8", "fog_d": 0.006, "glow": 0.75, "vol": true, "vol_d": 0.008},
		"motes": "fff2a0",
		"obst": ["rock", "pillar", "tree", "ruin", "log"], "deco": {"grass": 240, "flower": 46, "bush": 12, "mushroom": 7, "pebble": 16, "fern": 16, "tile": 12},
	},
	"crystal": {
		"floor_a": "4f4892", "floor_b": "6159ad", "edge": "2c2858", "path": "8a80d0",
		"env": {"sun_dir": Vector2(-62, 25), "sun_col": "b4c2ff", "sun_e": 0.95, "amb": "7266d8", "amb_e": 1.15,
			"sky_top": "120f2a", "sky_hor": "2a2358", "ground": "120f2a", "fog": "4a3c96", "fog_d": 0.012, "glow": 1.0, "vol": true, "vol_d": 0.01, "sat": 1.15},
		"motes": "9ffbff",
		"obst": ["crystal_big", "rock", "pillar", "ruin"], "deco": {"crystal_small": 46, "mushroom": 10, "pebble": 18, "tile": 14},
	},
	"boss": {
		"floor_a": "8a82b8", "floor_b": "a59ccc", "edge": "4a4070", "path": "d4cbef",
		"env": {"sun_dir": Vector2(-22, 150), "sun_col": "ffb27a", "sun_e": 1.5, "amb": "8a6fd8", "amb_e": 0.8,
			"sky_top": "3a2a78", "sky_hor": "ff9a7a", "ground": "5a3f78", "fog": "d99ab8", "fog_d": 0.008, "glow": 0.95, "vol": true, "vol_d": 0.008},
		"motes": "ffd0f0",
		"obst": ["rock"], "deco": {"tile": 10},
	},
}

var room: Dictionary = {}
var biome := "forest"
var kit := "env_forest"
var look: Dictionary = {}
var reward_node: Node3D
var portals: Array = []
var portal_points: Array = []
var cleared := false

func build(p_room: Dictionary) -> void:
	room = p_room
	biome = str(room.get("biome", "forest"))
	kit = str(DB.BIOMES[biome]["kit"])
	look = BIOME_LOOK[biome]
	rng.seed = int(room.get("seed", 1))
	var type := str(room.get("type", "combat"))
	var r := 15.5 + rng.randf() * 2.0
	var wob := 0.10
	match type:
		"elite":
			r = 16.5
		"boss":
			r = 20.0
			wob = 0.0
		"shop", "rest", "treasure":
			r = 10.5
			wob = 0.07
	make_bounds(r, wob)
	spawn_yaw = 0.0
	for i in 4:
		spawn_points.append(Vector3((i - 1.5) * 1.5, 0.1, bounds_r(PI * 0.5) - 3.2))
	make_environment(look["env"])
	build_floor(Color(str(look["floor_a"])), Color(str(look["floor_b"])), Color(str(look["edge"])), 10.0, Color(Color(str(look["path"])), 0.55))
	add_floor_collision()
	add_wall_collision()
	_walls()
	# pontos dos portais: no fundo da sala
	var n_opts := Game.next_options().size()
	for i in maxi(n_opts, 1):
		var a := -PI * 0.5 + (i - (n_opts - 1) * 0.5) * 0.42
		portal_points.append(point_at(a, 1.0) - Vector3(cos(a), 0, sin(a)) * 2.6)
	if type in ["combat", "elite"]:
		_obstacles(5 + rng.randi() % 4)
	elif type == "boss":
		_boss_dressing()
	_decorate()
	_backdrop()
	add_motes(Color(str(look["motes"])), 70, r * 0.9, 5.0)
	match type:
		"shop":
			_feature("shop", Vector3(0, 0, -2.5))
		"rest":
			_feature("fountain", Vector3(0, 0, -1.0))
		"treasure":
			_feature("chest", Vector3(0, 0, -1.5))

# ------------------------------------------------------------------ paredes e cenario
func _walls() -> void:
	var names := KitLib.by_tag(kit, "wall")
	var pillars := KitLib.by_tag(kit, "wall_pillar")
	if names.is_empty():
		_fallback_walls()
		return
	# percorre o contorno colocando segmentos de 4 m virados para o centro
	var a := 0.0
	var k := 0
	while a < TAU - 0.02:
		var p := point_at(a)
		var step := 3.7 / maxf(p.length(), 1.0)
		var mid := a + step * 0.5
		var pm := point_at(mid)
		var out := Vector3(cos(mid), 0, sin(mid))
		var piece: String = names[rng.randi() % names.size()]
		var depth := float(KitLib.meta(kit, piece).get("size", [4, 2, 4])[1])
		var mi := KitLib.make(kit, piece)
		mi.position = pm + out * (depth * 0.5 - 0.15)
		mi.rotation.y = atan2(out.x, out.z) + PI
		mi.scale = Vector3(1.04, rng.randf_range(0.95, 1.2), 1.0)
		add_child(mi)
		if pillars.size() > 0 and k % 3 == 0:
			var pp := KitLib.make(kit, pillars[0])
			pp.position = p + Vector3(cos(a), 0, sin(a)) * 0.2
			pp.rotation.y = atan2(cos(a), sin(a)) + PI
			add_child(pp)
		a += step
		k += 1

func _fallback_walls() -> void:
	var col := Color(str(look["edge"])).lightened(0.15)
	for i in 40:
		var a := TAU * i / 40.0
		var p := point_at(a, 1.06)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, rng.randf_range(3.5, 6.0), 2.4)
		mi.mesh = bm
		mi.position = p + Vector3(0, bm.size.y * 0.5 - 0.3, 0)
		mi.rotation.y = -a + PI * 0.5
		mi.material_override = Mats.toon(col.darkened(rng.randf() * 0.15))
		add_child(mi)

func _reserved(p: Vector3, r: float) -> bool:
	if Vector2(p.x, p.z).length() < 3.2 + r:
		return true
	for sp: Vector3 in spawn_points:
		if sp.distance_to(p) < 3.5 + r:
			return true
	for pp: Vector3 in portal_points:
		if pp.distance_to(p) < 3.5 + r:
			return true
	return false

func _obstacles(count: int) -> void:
	var pool: Array = []
	for tag in look["obst"]:
		for nm in KitLib.by_tag(kit, tag):
			pool.append(nm)
	var placed := 0
	var tries := 0
	while placed < count and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var p := point_at(a, rng.randf_range(0.28, 0.82))
		if pool.is_empty():
			if _reserved(p, 1.0) or not is_free(p, 2.4):
				continue
			fallback_block(p, rng.randf_range(0.7, 1.2), rng.randf_range(1.2, 3.0), Color(str(look["edge"])).lightened(0.25))
			placed += 1
			continue
		var piece: String = pool[rng.randi() % pool.size()]
		var cr := maxf(KitLib.collider_radius(kit, piece), 0.5)
		if _reserved(p, cr) or not is_free(p, cr + 1.8):
			continue
		place(kit, piece, p, rng.randf() * TAU, rng.randf_range(0.9, 1.15))
		placed += 1

func _boss_dressing() -> void:
	if KitLib.has(kit, "rune_floor"):
		var f := KitLib.make(kit, "rune_floor")
		f.position.y = 0.02
		f.scale = Vector3(1.6, 1.0, 1.6)
		add_child(f)
	for nm in KitLib.by_tag(kit, "light"):
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			place(kit, nm, point_at(a, 0.86), a, 1.0)
		break
	var deco := KitLib.by_tag(kit, "deco")
	for i in 8:
		if deco.is_empty():
			break
		var a2 := TAU * i / 8.0
		place(kit, deco[i % deco.size()], point_at(a2, 0.95), -a2 + PI * 0.5, 1.0, false)

func _decorate() -> void:
	var counts: Dictionary = look["deco"]
	for tag in counts:
		var names := KitLib.by_tag(kit, tag)
		if names.is_empty():
			continue
		var per: Dictionary = {}
		var n := int(counts[tag] * (bounds_r(0.0) / 16.0))
		for i in n:
			var a := rng.randf() * TAU
			var rad := sqrt(rng.randf())
			if tag in ["bush", "fern", "mushroom", "crystal_small"]:
				rad = rng.randf_range(0.7, 0.99)
			var p := point_at(a, rad)
			if tag == "tile":
				p = Vector3(rng.randf_range(-2.2, 2.2), 0.01, lerpf(bounds_r(PI * 0.5) - 2.0, -bounds_r(-PI * 0.5) + 2.0, rng.randf()))
			var blocked := false
			for o in obstacles:
				if (o["pos"] as Vector3).distance_to(p) < float(o["r"]) + 0.3:
					blocked = true
			if blocked:
				continue
			var nm: String = names[rng.randi() % names.size()]
			var s := rng.randf_range(0.8, 1.3)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), p)
			if KitLib.meta(kit, nm).has("light") and tag != "tile":
				if per.get("_lights", 0) < 4:
					per["_lights"] = int(per.get("_lights", 0)) + 1
					place(kit, nm, p, rng.randf() * TAU, s, false)
					continue
			if not per.has(nm):
				per[nm] = []
			per[nm].append(xf)
		for nm in per:
			if nm != "_lights":
				scatter_multi(kit, nm, per[nm])
	# luzes de ambiente do kit
	var lights := KitLib.by_tag(kit, "light")
	var type := str(room.get("type", "combat"))
	if lights.size() > 0 and type != "boss":
		for i in 4:
			var a := TAU * (i + 0.5) / 4.0 + rng.randf_range(-0.3, 0.3)
			var p := point_at(a, 0.9)
			if not _reserved(p, 1.0):
				place(kit, lights[rng.randi() % lights.size()], p, rng.randf() * TAU, 1.0)

func _backdrop() -> void:
	var names := KitLib.by_tag(kit, "backdrop")
	var trees := KitLib.by_tag(kit, "tree")
	var n := 7
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var p := point_at(a, 1.0) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(11.0, 17.0)
		var nm := ""
		if names.size() > 0 and i % 2 == 0:
			nm = names[rng.randi() % names.size()]
		elif trees.size() > 0:
			nm = trees[rng.randi() % trees.size()]
		if nm == "":
			continue
		var mi := KitLib.make(kit, nm)
		mi.position = p
		mi.rotation.y = atan2(cos(a), sin(a)) + PI + rng.randf_range(-0.4, 0.4)
		var s := rng.randf_range(1.0, 1.5)
		mi.scale = Vector3(s, s, s)
		add_child(mi)
	# mais arvores/rochas atras do muro para fechar o horizonte
	var filler: Array = trees + KitLib.by_tag(kit, "rock")
	if filler.is_empty():
		return
	for i in 22:
		var a := rng.randf() * TAU
		var p := point_at(a, 1.0) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.5, 12.0)
		var mi := KitLib.make(kit, filler[rng.randi() % filler.size()])
		mi.position = p
		mi.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(1.1, 1.9)
		mi.scale = Vector3(s, s, s)
		add_child(mi)
	for nm in KitLib.by_tag(kit, "ceiling"):
		for i in 5:
			var a := rng.randf() * TAU
			var p := point_at(a, rng.randf_range(0.2, 1.0))
			var mi := KitLib.make(kit, nm)
			mi.position = p + Vector3(0, rng.randf_range(9.0, 12.0), 0)
			mi.rotation.y = rng.randf() * TAU
			mi.scale = Vector3.ONE * rng.randf_range(1.2, 2.2)
			add_child(mi)

func _feature(spot_kind: String, pos: Vector3) -> void:
	var sp := Spot.new()
	sp.kind = spot_kind
	sp.position = pos
	add_child(sp)

# ------------------------------------------------------------------ eventos da sala
func on_room_event(kind: String, data: Dictionary) -> void:
	match kind:
		"clear":
			if cleared:
				return
			cleared = true
			var rw := str(room.get("reward", ""))
			if rw in ["boon", "relic", "spell", "gold"] and str(room.get("type", "")) != "treasure":
				var rp := Spot.new()
				rp.kind = "reward"
				rp.reward_kind = rw
				rp.position = Vector3(0, 0, 0)
				add_child(rp)
				reward_node = rp
			var opts := Game.next_options()
			for i in opts.size():
				var po := Portal.new()
				po.idx = i
				po.option = opts[i]
				po.position = portal_points[i] if i < portal_points.size() else Vector3(i * 4.0, 0, -8)
				po.rotation.y = atan2(po.position.x, po.position.z) + PI
				add_child(po)
				portals.append(po)
			if not data.get("quiet", false):
				Sfx.play("clear", Vector3.ZERO, 1.0, true)
		"votes":
			for po: Portal in portals:
				po.set_votes(data.get("v", {}), float(data.get("t", -1.0)))
