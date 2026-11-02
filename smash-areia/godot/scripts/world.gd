class_name World
extends Node3D
## Monta a praia: areia, mar, céu, quadra, rede, palmeiras, arquibancadas,
## torcida e bichinhos. Os objetos vêm dos .glb gerados pelo Blender.

const SHORE_Z := -26.0

const PALM := preload("res://assets/models/palm.glb")
const UMBRELLA := preload("res://assets/models/umbrella.glb")
const CHAIR := preload("res://assets/models/chair.glb")
const TOWER := preload("res://assets/models/tower.glb")
const CLOUD := preload("res://assets/models/cloud.glb")
const POST := preload("res://assets/models/post.glb")
const STANDS := preload("res://assets/models/stands.glb")
const SURFBOARD := preload("res://assets/models/surfboard.glb")
const ISLAND := preload("res://assets/models/island.glb")
const CRAB := preload("res://assets/models/crab.glb")

var crowd_mat: ShaderMaterial
var crowd_excite := 0.0
var clouds: Array[Node3D] = []
var crabs: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2026
	_environment()
	_ground()
	_court()
	_net()
	_props()
	_stands()


func _process(dt: float) -> void:
	crowd_excite = move_toward(crowd_excite, 0.0, dt * 0.45)
	if crowd_mat:
		crowd_mat.set_shader_parameter("excitement", crowd_excite)
	for c in clouds:
		c.position.x += dt * 0.6
		if c.position.x > 160.0:
			c.position.x = -160.0
	for crab in crabs:
		var n: Node3D = crab["node"]
		crab["t"] = float(crab["t"]) + dt
		var t: float = crab["t"]
		n.position.x = float(crab["x"]) + sin(t * 0.5) * 2.5
		n.rotation.z = sin(t * 14.0) * 0.08
		n.position.y = absf(sin(t * 14.0)) * 0.03


func cheer(amount: float) -> void:
	crowd_excite = clampf(maxf(crowd_excite, amount), 0.0, 1.0)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _ground() -> void:
	var sand := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 110)
	sand.mesh = pm
	sand.position = Vector3(0, 0, SHORE_Z + 55.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sand.gdshader")
	m.set_shader_parameter("shore_z", SHORE_Z)
	sand.material_override = m
	add_child(sand)

	var sea := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(900, 420)
	sp.subdivide_width = 48
	sp.subdivide_depth = 24
	sea.mesh = sp
	sea.position = Vector3(0, -0.05, SHORE_Z - 209.0)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sea.gdshader")
	sm.set_shader_parameter("shore_z", SHORE_Z)
	sea.material_override = sm
	add_child(sea)


func _box(size: Vector3, pos: Vector3, color: Color, outline := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Toon.make(color, {"outline": outline, "halftone": 0.0, "rim": 0.0})
	add_child(mi)
	return mi


func _court() -> void:
	var hw := GameData.COURT_HALF_W
	var hl := GameData.COURT_HALF_L
	var tape := Color("1f6bff")
	var w := 0.08
	_box(Vector3(w, 0.02, hl * 2.0 + w), Vector3(-hw, 0.01, 0), tape)
	_box(Vector3(w, 0.02, hl * 2.0 + w), Vector3(hw, 0.01, 0), tape)
	_box(Vector3(hw * 2.0 + w, 0.02, w), Vector3(0, 0.01, -hl), tape)
	_box(Vector3(hw * 2.0 + w, 0.02, w), Vector3(0, 0.01, hl), tape)
	# âncoras dos cantos
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.16, 0.05, 0.16), Vector3(sx * hw, 0.02, sz * hl), Color("ffd23f"))


func _net() -> void:
	var nh := GameData.NET_H
	var half := GameData.NET_HALF_W
	for sx in [-1.0, 1.0]:
		var post: Node3D = POST.instantiate()
		post.position = Vector3(sx * half, 0, 0)
		Toon.apply(post, {}, {"outline": 0.02})
		add_child(post)
	var net := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(half * 2.0, 0.92)
	net.mesh = q
	net.position = Vector3(0, nh - 0.46, 0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/net.gdshader")
	m.set_shader_parameter("cells", Vector2(half * 2.0 / 0.1, 0.92 / 0.1))
	net.material_override = m
	add_child(net)
	_box(Vector3(half * 2.0, 0.07, 0.035), Vector3(0, nh - 0.03, 0), Color("ffffff"), 0.012)
	_box(Vector3(half * 2.0, 0.04, 0.03), Vector3(0, nh - 0.92, 0), Color("ffffff"), 0.0)
	# antenas
	for sx in [-1.0, 1.0]:
		var a := _box(Vector3(0.03, 0.8, 0.03), Vector3(sx * GameData.COURT_HALF_W, nh + 0.38, 0), Color("ff4b3e"), 0.01)
		a.name = "Antenna"
	# sombra da rede
	var sh := MeshInstance3D.new()
	var sq := PlaneMesh.new()
	sq.size = Vector2(half * 2.0, 0.5)
	sh.mesh = sq
	sh.position = Vector3(0.0, 0.012, -0.6)
	sh.material_override = Toon.blob(1.0, Color(0.3, 0.12, 0.2, 0.18)).material_override
	add_child(sh)


func _place(scene: PackedScene, pos: Vector3, rot_y := 0.0, s := 1.0, opts: Dictionary = {}, ds: Array = []) -> Node3D:
	var n: Node3D = scene.instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * s
	var o := {"outline": 0.03}
	o.merge(opts, true)
	Toon.apply(n, {}, o, ds)
	add_child(n)
	return n


func _props() -> void:
	var leaves := ["Leaf", "LeafDark"]
	var palm_spots := [
		Vector3(-14, 0, -18), Vector3(15, 0, -20), Vector3(-20, 0, -6), Vector3(21, 0, -8),
		Vector3(-24, 0, 6), Vector3(25, 0, 4), Vector3(-9, 0, -23), Vector3(10, 0, -23.5),
		Vector3(-30, 0, -15), Vector3(31, 0, -16), Vector3(-18, 0, 18), Vector3(19, 0, 20),
	]
	for i in palm_spots.size():
		_place(PALM, palm_spots[i], rng.randf_range(0, TAU), rng.randf_range(1.1, 1.5), {"outline": 0.04}, leaves)
	var umb_spots := [Vector3(-13, 0, -11), Vector3(13.5, 0, -12), Vector3(-17, 0, 1), Vector3(17, 0, -1),
		Vector3(-6, 0, -20), Vector3(7, 0, -19)]
	for p in umb_spots:
		var u := _place(UMBRELLA, p, rng.randf_range(0, TAU), 1.2)
		u.rotation.z = rng.randf_range(-0.12, 0.12)
		_place(CHAIR, p + Vector3(rng.randf_range(-1.2, 1.2), 0, 1.3), rng.randf_range(2.5, 3.8), 1.3)
	_place(TOWER, Vector3(-21, 0, -14), 0.5, 1.4)
	_place(SURFBOARD, Vector3(12.5, 0, -16), 0.3, 1.3).rotation.x = -0.15
	_place(SURFBOARD, Vector3(13.6, 0, -15.6), -0.2, 1.2).rotation.x = -0.1
	_place(SURFBOARD, Vector3(-12, 0, -16.5), 0.6, 1.25).rotation.x = -0.2
	for i in 5:
		var x := rng.randf_range(-260, 260)
		_place(ISLAND, Vector3(x, -0.5, rng.randf_range(-330, -230)), rng.randf_range(0, TAU),
				rng.randf_range(2.5, 4.5), {"outline": 0.0, "halftone": 0.0})
	for i in 9:
		var c := _place(CLOUD, Vector3(rng.randf_range(-160, 160), rng.randf_range(30, 60), rng.randf_range(-240, -140)),
				0.0, rng.randf_range(6.0, 11.0), {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
		clouds.append(c)
	for i in 4:
		var crab := _place(CRAB, Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-22, -14)), 0.0, 1.5, {"outline": 0.012})
		crabs.append({"node": crab, "x": crab.position.x, "t": rng.randf_range(0, 10)})


func _stands() -> void:
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = preload("res://shaders/crowd.gdshader")
	var body := CapsuleMesh.new()
	body.radius = 0.24
	body.height = 1.0
	body.radial_segments = 8
	body.rings = 2
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.radial_segments = 8
	head.rings = 4
	var shirts := [Color("ff4b3e"), Color("2f8cff"), Color("ffd23f"), Color("35e0a1"), Color("ff5fa2"),
		Color("ffffff"), Color("9b5de5"), Color("ff9f1c")]
	var skins := [Color("f2b98a"), Color("d39a6a"), Color("8d5a3b"), Color("5e3a26"), Color("ffd7b0")]
	for sgn in [-1.0, 1.0]:
		var stand := _place(STANDS, Vector3(sgn * 11.2, 0, -1.0), -sgn * PI * 0.5, 1.0, {"outline": 0.0, "halftone": 0.0})
		var mm_body := MultiMesh.new()
		mm_body.transform_format = MultiMesh.TRANSFORM_3D
		mm_body.use_colors = true
		mm_body.use_custom_data = true
		mm_body.mesh = body
		var mm_head := MultiMesh.new()
		mm_head.transform_format = MultiMesh.TRANSFORM_3D
		mm_head.use_colors = true
		mm_head.use_custom_data = true
		mm_head.mesh = head
		var spots: Array[Transform3D] = []
		for row in 4:
			var count := 17
			for i in count:
				if rng.randf() < 0.15:
					continue
				var along := -6.6 + i * (13.2 / float(count - 1)) + rng.randf_range(-0.15, 0.15)
				var depth := row * 0.8 + 0.1
				# coordenadas locais da arquibancada: X = comprimento, -Z = subida
				var lp := Vector3(along, 0.5 + row + 0.5, -depth)
				spots.append(Transform3D(Basis(), lp))
		mm_body.instance_count = spots.size()
		mm_head.instance_count = spots.size()
		for i in spots.size():
			var tr: Transform3D = spots[i]
			var seed := rng.randf()
			mm_body.set_instance_transform(i, tr)
			mm_body.set_instance_color(i, shirts[rng.randi() % shirts.size()])
			mm_body.set_instance_custom_data(i, Color(seed, 0, 0, 0))
			mm_head.set_instance_transform(i, tr.translated_local(Vector3(0, 0.66, 0)))
			mm_head.set_instance_color(i, skins[rng.randi() % skins.size()])
			mm_head.set_instance_custom_data(i, Color(seed, 0, 0, 0))
		for mm in [mm_body, mm_head]:
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = crowd_mat
			stand.add_child(mmi)
