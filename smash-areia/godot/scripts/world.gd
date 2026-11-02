class_name World
extends Node3D
## Monta a praia de fim de tarde: areia, mar, céu, morros, quadra, rede, juiz,
## arquibancadas com torcida viva, placas, bandeiras, palmeiras ao vento,
## veleiros, gaivotas e siris. Os modelos vêm dos .glb gerados pelo Blender.

const SHORE_Z := -26.0

const PALM := preload("res://assets/models/palm.glb")
const UMBRELLA := preload("res://assets/models/umbrella.glb")
const CHAIR := preload("res://assets/models/chair.glb")
const TOWER := preload("res://assets/models/tower.glb")
const CLOUD := preload("res://assets/models/cloud.glb")
const POST := preload("res://assets/models/post.glb")
const BLEACHERS := preload("res://assets/models/bleachers.glb")
const SURFBOARD := preload("res://assets/models/surfboard.glb")
const ISLAND := preload("res://assets/models/island.glb")
const CRAB := preload("res://assets/models/crab.glb")
const MOUNTAINS := preload("res://assets/models/mountains.glb")
const SAILBOAT := preload("res://assets/models/sailboat.glb")
const KIOSK := preload("res://assets/models/kiosk.glb")
const REFCHAIR := preload("res://assets/models/refchair.glb")
const FANS := [preload("res://assets/models/fan_up.glb"), preload("res://assets/models/fan_sign.glb"),
	preload("res://assets/models/fan_finger.glb"), preload("res://assets/models/fan_clap.glb")]
const FONT := preload("res://assets/fonts/Bangers.woff")

var crowd_mat: ShaderMaterial
var crowd_excite := 0.0
var ola_t := -10.0
var clouds: Array[Node3D] = []
var crabs: Array[Dictionary] = []
var boats: Array[Dictionary] = []
var gulls: Array[Dictionary] = []
var referee: Dictionary = {}
var ref_whistle := 0.0
var ball_pos := Vector3(0, 1, 0)
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2026
	_environment()
	_ground()
	_court()
	_net()
	_referee()
	_props()
	_stands()
	_boards()
	_land_side()
	_setup_marks()


func _process(dt: float) -> void:
	_update_marks(dt)
	net_hit_t += dt
	if net_mat:
		net_mat.set_shader_parameter("hit_t", net_hit_t)
	crowd_excite = move_toward(crowd_excite, 0.0, dt * 0.45)
	ola_t += dt
	if crowd_mat:
		crowd_mat.set_shader_parameter("excitement", crowd_excite)
		crowd_mat.set_shader_parameter("ball_pos", ball_pos)
		crowd_mat.set_shader_parameter("ola_t", ola_t)
	for c in clouds:
		c.position.x += dt * 0.6
		if c.position.x > 180.0:
			c.position.x = -180.0
	for crab in crabs:
		var n: Node3D = crab["node"]
		crab["t"] = float(crab["t"]) + dt
		var t: float = crab["t"]
		n.position.x = float(crab["x"]) + sin(t * 0.5) * 2.5
		n.rotation.z = sin(t * 14.0) * 0.08
		n.position.y = absf(sin(t * 14.0)) * 0.03
	for b in boats:
		var bn: Node3D = b["node"]
		bn.position.x += float(b["speed"]) * dt
		if bn.position.x > 260.0:
			bn.position.x = -260.0
		bn.rotation.z = sin(Time.get_ticks_msec() * 0.001 * 0.8 + float(b["ph"])) * 0.05
		bn.position.y = sin(Time.get_ticks_msec() * 0.001 * 1.1 + float(b["ph"])) * 0.15
	var tt := Time.get_ticks_msec() * 0.001
	for g in gulls:
		var gn: Node3D = g["node"]
		var a := tt * float(g["speed"]) + float(g["ph"])
		var c2: Vector3 = g["center"]
		gn.position = c2 + Vector3(cos(a) * float(g["r"]), sin(a * 0.7) * 1.5, sin(a) * float(g["r"]) * 0.6)
		gn.rotation.y = -a + PI * (0.5 if float(g["speed"]) > 0 else -0.5)
		var flap := sin(tt * 9.0 + float(g["ph"])) * 0.6
		(g["wl"] as Node3D).rotation.z = flap
		(g["wr"] as Node3D).rotation.z = -flap
	_update_referee(dt)


# ---------------------------------------------------------------- marcas na areia

var prints_mm: MultiMesh
var prints_age: PackedFloat32Array
var prints_next := 0
const PRINTS := 180
var rings: Array[Dictionary] = []


func _setup_marks() -> void:
	prints_mm = MultiMesh.new()
	prints_mm.transform_format = MultiMesh.TRANSFORM_3D
	prints_mm.use_colors = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.16, 0.28)
	prints_mm.mesh = pm
	prints_mm.instance_count = PRINTS
	prints_age.resize(PRINTS)
	for i in PRINTS:
		prints_age[i] = 99.0
		prints_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -5, 0)))
		prints_mm.set_instance_color(i, Color(1, 1, 1, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = prints_mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/footprint.gdshader")
	m.render_priority = 0
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i in 3:
		var r := Toon.blob(1.0, Color(1, 0.97, 0.88, 0.0), true)
		r.visible = false
		add_child(r)
		rings.append({"node": r, "t": 1.0, "size": 1.0})


## Pegada (ou marca de mergulho) na areia
func footprint(pos: Vector3, yaw: float, size := 1.0) -> void:
	var i := prints_next
	prints_next = (prints_next + 1) % PRINTS
	prints_age[i] = 0.0
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(size, 1.0, size))
	prints_mm.set_instance_transform(i, Transform3D(b, Vector3(pos.x, 0.008, pos.z)))
	prints_mm.set_instance_color(i, Color(1, 1, 1, 1))


## Onda de areia quando a bola cai ou alguém mergulha
func sand_ring(pos: Vector3, size := 1.0) -> void:
	for d in rings:
		if float(d["t"]) >= 1.0:
			var n: MeshInstance3D = d["node"]
			n.global_position = Vector3(pos.x, 0.03, pos.z)
			n.visible = true
			d["t"] = 0.0
			d["size"] = size
			return


func _update_marks(dt: float) -> void:
	for i in PRINTS:
		if prints_age[i] < 8.0:
			prints_age[i] += dt
			prints_mm.set_instance_color(i, Color(1, 1, 1, clampf(1.0 - prints_age[i] / 8.0, 0.0, 1.0)))
	for d in rings:
		if float(d["t"]) < 1.0:
			d["t"] = minf(float(d["t"]) + dt / 0.45, 1.0)
			var t: float = d["t"]
			var n: MeshInstance3D = d["node"]
			n.scale = Vector3.ONE * lerpf(0.4, 2.6, sqrt(t)) * float(d["size"])
			(n.material_override as ShaderMaterial).set_shader_parameter("color", Color(1, 0.97, 0.88, 0.75 * (1.0 - t)))
			if t >= 1.0:
				n.visible = false


func set_ball(p: Vector3) -> void:
	ball_pos = p


func cheer(amount: float) -> void:
	crowd_excite = clampf(maxf(crowd_excite, amount), 0.0, 1.0)


func ola() -> void:
	ola_t = 0.0
	cheer(1.0)


func whistle() -> void:
	ref_whistle = 1.0


# ---------------------------------------------------------------- ambiente

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
	pm.size = Vector2(700, 520)
	sand.mesh = pm
	sand.position = Vector3(0, 0, SHORE_Z + 260.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sand.gdshader")
	m.set_shader_parameter("shore_z", SHORE_Z)
	sand.material_override = m
	add_child(sand)
	var sea := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(1000, 460)
	sp.subdivide_width = 48
	sp.subdivide_depth = 24
	sea.mesh = sp
	sea.position = Vector3(0, -0.05, SHORE_Z - 229.0)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sea.gdshader")
	sm.set_shader_parameter("shore_z", SHORE_Z)
	sea.material_override = sm
	add_child(sea)


func _box(size: Vector3, pos: Vector3, color: Color, outline := 0.0, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Toon.make(color, {"outline": outline, "halftone": 0.0, "rim": 0.0})
	(parent if parent else self).add_child(mi)
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
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.16, 0.05, 0.16), Vector3(sx * hw, 0.02, sz * hl), Color("ffd23f"))
	# areia mais clarinha (rastelada) dentro da quadra
	var inner := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(hw * 2.0, hl * 2.0)
	inner.mesh = q
	inner.position = Vector3(0, 0.004, 0)
	inner.material_override = Toon.blob(1.0, Color(1.0, 0.97, 0.85, 0.22)).material_override.duplicate()
	(inner.material_override as ShaderMaterial).set_shader_parameter("ring", 0.0)
	add_child(inner)


var net_mat: ShaderMaterial
var net_hit_t := 10.0


func _cyl(r: float, h: float, pos: Vector3, color: Color, outline := 0.01, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.material_override = Toon.make(color, {"outline": outline, "halftone": 0.0, "rim": 0.3})
	(parent if parent else self).add_child(mi)
	return mi


## Cilindro fino ligando dois pontos (cabos e estais)
func _rope(a: Vector3, b: Vector3, r: float, color: Color) -> void:
	var mid := (a + b) * 0.5
	var mi := _cyl(r, a.distance_to(b), mid, color, 0.006)
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.0001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))


func _net() -> void:
	var nh := GameData.NET_H
	var half := GameData.NET_HALF_W
	var depth := 0.92
	var blue := Color("1f6bff")
	for sx in [-1.0, 1.0]:
		var post: Node3D = POST.instantiate()
		post.position = Vector3(sx * half, 0, 0)
		Toon.apply(post, {}, {"outline": 0.02, "halftone": 0.0})
		add_child(post)
		# protetor acolchoado no poste
		_cyl(0.13, 1.25, Vector3(sx * half, 0.62, 0), blue, 0.015)
		_cyl(0.135, 0.08, Vector3(sx * half, 1.22, 0), Color("ffffff"), 0.0)
		# estais: do topo do poste até estacas na areia
		var top := Vector3(sx * half, 1.86, 0)
		for sz in [-1.0, 1.0]:
			var anchor := Vector3(sx * (half + 1.3), 0.02, sz * 0.9)
			_rope(top, anchor, 0.012, Color("f4f0e8"))
			_box(Vector3(0.22, 0.12, 0.22), anchor + Vector3(0, 0.05, 0), Color("c98a4b"), 0.012)
		# cabo da faixa superior até o poste
		_rope(Vector3(sx * GameData.COURT_HALF_W * 1.02, nh - 0.02, 0), Vector3(sx * half, nh + 0.02, 0), 0.01, Color("f4f0e8"))
		_rope(Vector3(sx * GameData.COURT_HALF_W * 1.02, nh - depth, 0), Vector3(sx * half, nh - depth + 0.02, 0), 0.008, Color("f4f0e8"))
	# malha
	var net := MeshInstance3D.new()
	var q := QuadMesh.new()
	var w := GameData.COURT_HALF_W * 2.0 + 0.2
	q.size = Vector2(w, depth)
	q.subdivide_width = 40
	q.subdivide_depth = 6
	net.mesh = q
	net.position = Vector3(0, nh - depth * 0.5, 0)
	net_mat = ShaderMaterial.new()
	net_mat.shader = preload("res://shaders/net.gdshader")
	net_mat.set_shader_parameter("cells", Vector2(w / 0.1, depth / 0.1))
	net_mat.render_priority = 3
	net.material_override = net_mat
	add_child(net)
	# faixas: em cima (com texto), embaixo e nas laterais
	var band := _box(Vector3(w, 0.075, 0.04), Vector3(0, nh - 0.035, 0), Color("ffffff"), 0.01)
	band.name = "TopBand"
	_box(Vector3(w, 0.045, 0.03), Vector3(0, nh - depth, 0), Color("ffffff"), 0.008)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.05, depth, 0.034), Vector3(sx * GameData.COURT_HALF_W, nh - depth * 0.5, 0), Color("ffffff"), 0.008)
	for sz in [-1.0, 1.0]:
		var t := Label3D.new()
		t.text = "SMASH NA AREIA   •   BEACH TENNIS   •   SMASH NA AREIA"
		t.font = FONT
		t.font_size = 48
		t.pixel_size = 0.0011
		t.outline_size = 0
		t.modulate = blue
		t.shaded = false
		t.position = Vector3(0, nh - 0.035, sz * 0.022)
		t.rotation.y = 0.0 if sz > 0 else PI
		add_child(t)
	# antenas listradas (vermelho e branco)
	for sx in [-1.0, 1.0]:
		for k in 8:
			var col := Color("ff3b3b") if k % 2 == 0 else Color("ffffff")
			_cyl(0.014, 0.1, Vector3(sx * GameData.COURT_HALF_W, nh - depth + 0.05 + k * 0.1 + 0.9, 0.0) - Vector3(0, 0.0, 0), col, 0.0)
	# sombra da rede
	var sh := MeshInstance3D.new()
	var sq := PlaneMesh.new()
	sq.size = Vector2(w, 0.5)
	sh.mesh = sq
	sh.position = Vector3(0.4, 0.012, 0.55)
	sh.material_override = Toon.blob(1.0, Color(0.3, 0.12, 0.2, 0.16)).material_override
	add_child(sh)


## Rede treme quando a bola bate
func net_hit(pos: Vector3) -> void:
	net_hit_t = 0.0
	if net_mat:
		net_mat.set_shader_parameter("hit_x", pos.x)
		net_mat.set_shader_parameter("hit_amp", 0.22)


func _referee() -> void:
	var chair := _place(REFCHAIR, Vector3(5.6, 0, 0), -PI * 0.5, 1.0)
	var data := {"skin": Color("c98a5b"), "hair_color": Color("1d1d1d"), "accent": Color("1d1d1d"),
		"hair": "Shades", "racket": Color.WHITE}
	var team := {"shirt": Color("ffffff"), "trim": Color("1d1d1d"), "shorts": Color("1d1d1d")}
	var mm := Player.make_model(data, team)
	var m: Node3D = mm["model"]
	(mm["racket"] as Node3D).visible = false
	m.position = Vector3(0, 1.48, 0.05)
	chair.add_child(m)
	m.rotation.y = 0.0
	referee = mm


func _update_referee(dt: float) -> void:
	if referee.is_empty():
		return
	var rig: Rig = referee["rig"]
	var m: Node3D = referee["model"]
	var local := m.global_transform.affine_inverse() * ball_pos
	var yaw := clampf(atan2(local.x, local.z), -1.2, 1.2)
	ref_whistle = maxf(ref_whistle - dt * 1.2, 0.0)
	var arm := -2.8 if ref_whistle > 0.2 else -0.5
	rig.apply({
		"UpperLeg.R": Vector3(-1.5, 0, -0.05), "UpperLeg.L": Vector3(-1.5, 0, 0.05),
		"LowerLeg.R": Vector3(1.4, 0, 0), "LowerLeg.L": Vector3(1.4, 0, 0),
		"Spine": Vector3(0.05, yaw * 0.3, 0), "Neck": Vector3(0.0, yaw * 0.3, 0), "Head": Vector3(0.15, yaw * 0.4, 0),
		"UpperArm.R": Vector3(arm, 0, -0.2), "LowerArm.R": Vector3(-0.3, 0, 0),
		"UpperArm.L": Vector3(-0.5, 0, 0.2), "LowerArm.L": Vector3(-1.3, 0, 0),
	}, 1.0 - exp(-10.0 * dt), Vector3(0, -0.05, 0))


func _place(scene: PackedScene, pos: Vector3, rot_y := 0.0, s := 1.0, opts: Dictionary = {}, ds: Array = []) -> Node3D:
	var n: Node3D = scene.instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * s
	var o := {"outline": 0.03, "halftone": 0.0}
	o.merge(opts, true)
	Toon.apply(n, {}, o, ds, {"Leaf": {"wind": 1.0}, "LeafDark": {"wind": 1.0}})
	add_child(n)
	return n


func _props() -> void:
	# composição limpa: poucas palmeiras emoldurando o fundo, sem objetos
	# competindo com a quadra
	var palm_spots := [Vector3(-16, 0, -21), Vector3(17, 0, -22), Vector3(-26, 0, -12), Vector3(27, 0, -13),
		Vector3(-8, 0, -26), Vector3(9, 0, -26.5)]
	for k in palm_spots.size():
		_place(PALM, palm_spots[k], 0.7 * k, 1.3 + 0.08 * (k % 3), {"outline": 0.035})
	for p in [Vector3(-11, 0, -19), Vector3(11.5, 0, -19.5)]:
		_place(UMBRELLA, p, 0.4, 1.2)
		_place(CHAIR, p + Vector3(0.9, 0, 1.2), 3.0, 1.3)
	_place(TOWER, Vector3(21, 0, -19), -0.5, 1.4)
	# horizonte: morros, ilhas, nuvens, veleiros, gaivotas
	_place(MOUNTAINS, Vector3(-210, -1, -330), 0.3, 2.6, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	_place(MOUNTAINS, Vector3(230, -1, -360), PI - 0.2, 2.2, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	for i in 3:
		_place(ISLAND, Vector3(-120 + i * 120 + rng.randf_range(-20, 20), -0.5, rng.randf_range(-300, -240)),
				rng.randf_range(0, TAU), rng.randf_range(2.5, 3.5), {"outline": 0.0, "halftone": 0.0})
	for i in 6:
		var c := _place(CLOUD, Vector3(-170 + i * 65 + rng.randf_range(-15, 15), rng.randf_range(40, 70),
				rng.randf_range(-280, -180)), 0.0, rng.randf_range(7.0, 11.0), {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
		clouds.append(c)
	for i in 3:
		var b := _place(SAILBOAT, Vector3(-150 + i * 140, 0, rng.randf_range(-150, -80)),
				PI * 0.5, rng.randf_range(1.6, 2.2), {"outline": 0.0, "halftone": 0.0})
		boats.append({"node": b, "speed": rng.randf_range(1.0, 2.0), "ph": rng.randf() * 10.0})
	for i in 3:
		var g := Node3D.new()
		add_child(g)
		_box(Vector3(0.14, 0.12, 0.45), Vector3.ZERO, Color("ffffff"), 0.015, g)
		var wl := Node3D.new()
		g.add_child(wl)
		_box(Vector3(0.6, 0.03, 0.2), Vector3(0.32, 0, 0), Color("f2f2f2"), 0.012, wl)
		var wr := Node3D.new()
		g.add_child(wr)
		_box(Vector3(0.6, 0.03, 0.2), Vector3(-0.32, 0, 0), Color("f2f2f2"), 0.012, wr)
		g.scale = Vector3.ONE * 1.3
		gulls.append({"node": g, "wl": wl, "wr": wr, "center": Vector3(rng.randf_range(-30, 30), rng.randf_range(20, 28),
			rng.randf_range(-70, -45)), "r": rng.randf_range(10, 18), "speed": rng.randf_range(0.2, 0.35) * (1 if i % 2 else -1),
			"ph": rng.randf() * TAU})
	# duas bandeiras só no fundo
	for corner in [Vector3(-6.8, 0, -11.2), Vector3(6.8, 0, -11.2)]:
		_box(Vector3(0.06, 3.6, 0.06), corner + Vector3(0, 1.8, 0), Color("ffffff"), 0.012)
		var flag := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(1.2, 0.7)
		fq.subdivide_width = 8
		flag.mesh = fq
		flag.position = corner + Vector3(0.62, 3.2, 0)
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://shaders/flag.gdshader")
		fm.set_shader_parameter("phase", rng.randf() * TAU)
		fm.set_shader_parameter("color_a", GameData.TEAMS[0]["shirt"] if corner.x < 0 else GameData.TEAMS[1]["shirt"])
		fm.set_shader_parameter("color_b", Color("ffffff"))
		flag.material_override = fm
		flag.rotation.y = PI * 0.5
		add_child(flag)


func _stands() -> void:
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = preload("res://shaders/crowd.gdshader")
	# torcida com as cores dos times + branco e amarelo (menos ruído visual)
	var shirts := [Color("2f8cff"), Color("2f8cff"), Color("ff4b3e"), Color("ff4b3e"), Color("ffffff"),
		Color("ffffff"), Color("ffd23f"), Color("5fb8ff")]
	# só nas laterais: o fundo fica livre para ver o mar
	var stands := [
		{"pos": Vector3(-11.6, 0, -0.5), "rot": PI * 0.5, "rows": 5},
		{"pos": Vector3(11.6, 0, -0.5), "rot": -PI * 0.5, "rows": 5},
	]
	for st in stands:
		var b := _place(BLEACHERS, st["pos"], st["rot"], 1.0, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
		var per_variant: Array = [[], [], [], []]
		for row in int(st["rows"]):
			var count := 18
			for i in count:
				if rng.randf() < 0.12:
					continue
				var along := -7.0 + i * (14.0 / float(count - 1)) + rng.randf_range(-0.12, 0.12)
				# coordenadas locais (Godot): X = comprimento, -Z = fundo (sobe), Y = altura do degrau
				var lp := Vector3(along, 0.43 + row * 0.5, -(row * 0.75 - 0.12))
				var v := rng.randi() % 4
				if rng.randf() < 0.35:
					v = 3
				per_variant[v].append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.9, 1.08)), lp))
		for v in 4:
			var list: Array = per_variant[v]
			if list.is_empty():
				continue
			var src: Node = FANS[v].instantiate()
			var mesh: Mesh = (Toon._meshes(src)[0] as MeshInstance3D).mesh
			src.free()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
				mm.set_instance_color(i, shirts[rng.randi() % shirts.size()])
				mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = crowd_mat
			b.add_child(mmi)


func _boards() -> void:
	# três placas baixas e iguais atrás do fundo da quadra (laterais ficam com a arquibancada)
	var texts := ["SMASH NA AREIA", "BEACH TENNIS", "SMASH NA AREIA"]
	for i in 3:
		var holder := Node3D.new()
		holder.position = Vector3(-5.2 + i * 5.2, 0.4, -11.0)
		add_child(holder)
		_box(Vector3(5.0, 0.8, 0.12), Vector3.ZERO, Color("ffffff"), 0.012, holder)
		_box(Vector3(5.0, 0.09, 0.14), Vector3(0, -0.36, 0), Color("1f6bff"), 0.0, holder)
		var l := Label3D.new()
		l.text = texts[i]
		l.font = FONT
		l.font_size = 96
		l.pixel_size = 0.005
		l.outline_size = 0
		l.modulate = Color("1f6bff")
		l.position = Vector3(0, 0.04, 0.07)
		l.shaded = false
		l.double_sided = false
		holder.add_child(l)


## Lado da terra (visto pela câmera do J2 no VS): calçadão, palmeiras, prédios e morros
func _land_side() -> void:
	_box(Vector3(260, 0.12, 5.0), Vector3(0, 0.06, 31.0), Color("f4efe6"), 0.0)
	for k in 26:
		_box(Vector3(5.0, 0.13, 0.5), Vector3(-130 + k * 10.4, 0.065, 31.0 + (0.9 if k % 2 == 0 else -0.9)), Color("2b2b33"), 0.0)
	_box(Vector3(260, 0.25, 1.2), Vector3(0, 0.12, 34.0), Color("4fbf6b"), 0.0)
	for k in 12:
		_place(PALM, Vector3(-55 + k * 10.0, 0, 34.0 + (k % 2) * 1.2), 0.5 * k, 1.35, {"outline": 0.035})
	var cols := [Color("ffd9b8"), Color("bfe8d8"), Color("bfdcff"), Color("e5d1ff"), Color("fff1c2"), Color("ffc9c9")]
	var r2 := RandomNumberGenerator.new()
	r2.seed = 77
	var x := -190.0
	while x < 190.0:
		var w := r2.randf_range(10.0, 18.0)
		var h := r2.randf_range(9.0, 24.0)
		var c: Color = cols[r2.randi() % cols.size()]
		var bld := _box(Vector3(w, h, 10.0), Vector3(x + w * 0.5, h * 0.5, r2.randf_range(118.0, 132.0)), c, 0.08)
		bld.material_override = Toon.make(c, {"outline": 0.08, "halftone": 0.0, "rim": 0.0, "shadow": Color(0.86, 0.82, 0.92)})
		# faixas de janelas
		for j in int(h / 4.0):
			_box(Vector3(w * 0.86, 0.9, 0.2), Vector3(0, -h * 0.5 + 2.5 + j * 4.0, -5.05) / Vector3(1, 1, 1), Color(c.darkened(0.22)), 0.0, bld)
		x += w + r2.randf_range(1.0, 4.0)
	_place(MOUNTAINS, Vector3(-140, -1, 330), PI + 0.4, 2.4, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	_place(MOUNTAINS, Vector3(170, -1, 360), 0.2, 2.0, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
