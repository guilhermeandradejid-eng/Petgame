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


func _process(dt: float) -> void:
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
	pm.size = Vector2(300, 120)
	sand.mesh = pm
	sand.position = Vector3(0, 0, SHORE_Z + 60.0)
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
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.03, 0.8, 0.03), Vector3(sx * GameData.COURT_HALF_W, nh + 0.38, 0), Color("ff4b3e"), 0.01)
	var sh := MeshInstance3D.new()
	var sq := PlaneMesh.new()
	sq.size = Vector2(half * 2.0, 0.5)
	sh.mesh = sq
	sh.position = Vector3(0.4, 0.012, 0.55)
	sh.material_override = Toon.blob(1.0, Color(0.3, 0.12, 0.2, 0.16)).material_override
	add_child(sh)


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
	var o := {"outline": 0.03}
	o.merge(opts, true)
	Toon.apply(n, {}, o, ds)
	add_child(n)
	return n


func _props() -> void:
	var leaves := ["Leaf", "LeafDark"]
	var palm_spots := [
		Vector3(-15, 0, -19), Vector3(16, 0, -20), Vector3(-21, 0, -7), Vector3(22, 0, -9),
		Vector3(-25, 0, 6), Vector3(26, 0, 4), Vector3(-9, 0, -24), Vector3(11, 0, -24.5),
		Vector3(-31, 0, -16), Vector3(32, 0, -17), Vector3(-19, 0, 18), Vector3(20, 0, 20),
	]
	for p in palm_spots:
		var palm := _place(PALM, p, rng.randf_range(0, TAU), rng.randf_range(1.1, 1.5), {"outline": 0.04}, leaves)
		for mi in Toon._meshes(palm):
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(s) as ShaderMaterial
				if mat and mat.shader != Toon.TOON_SHADER:
					var w := mat.duplicate() as ShaderMaterial
					w.set_shader_parameter("wind", 1.0)
					mi.set_surface_override_material(s, w)
	var umb_spots := [Vector3(-13.5, 0, -12), Vector3(14, 0, -13), Vector3(-6, 0, -20), Vector3(7, 0, -19.5)]
	for p in umb_spots:
		var u := _place(UMBRELLA, p, rng.randf_range(0, TAU), 1.2)
		u.rotation.z = rng.randf_range(-0.12, 0.12)
		_place(CHAIR, p + Vector3(rng.randf_range(-1.2, 1.2), 0, 1.3), rng.randf_range(2.5, 3.8), 1.3)
	_place(KIOSK, Vector3(-17, 0, -13), 0.4, 1.3)
	_place(TOWER, Vector3(19, 0, -16), -0.5, 1.4)
	_place(SURFBOARD, Vector3(12.5, 0, -17), 0.3, 1.3).rotation.x = -0.15
	_place(SURFBOARD, Vector3(13.6, 0, -16.6), -0.2, 1.2).rotation.x = -0.1
	_place(SURFBOARD, Vector3(-12, 0, -17.5), 0.6, 1.25).rotation.x = -0.2
	# horizonte: morros, ilhas, nuvens, veleiros, gaivotas
	_place(MOUNTAINS, Vector3(-210, -1, -330), 0.3, 2.6, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	_place(MOUNTAINS, Vector3(230, -1, -360), PI - 0.2, 2.2, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	for i in 4:
		_place(ISLAND, Vector3(rng.randf_range(-140, 140), -0.5, rng.randf_range(-300, -220)), rng.randf_range(0, TAU),
				rng.randf_range(2.5, 4.0), {"outline": 0.0, "halftone": 0.0})
	for i in 9:
		var c := _place(CLOUD, Vector3(rng.randf_range(-180, 180), rng.randf_range(35, 70), rng.randf_range(-280, -160)),
				0.0, rng.randf_range(6.0, 12.0), {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
		clouds.append(c)
	for i in 4:
		var b := _place(SAILBOAT, Vector3(rng.randf_range(-200, 200), 0, rng.randf_range(-150, -60)),
				PI * 0.5, rng.randf_range(1.4, 2.2), {"outline": 0.0, "halftone": 0.0})
		boats.append({"node": b, "speed": rng.randf_range(1.0, 2.5), "ph": rng.randf() * 10.0})
	for i in 6:
		var g := Node3D.new()
		add_child(g)
		var body := _box(Vector3(0.14, 0.12, 0.45), Vector3.ZERO, Color("ffffff"), 0.015, g)
		body.name = "Body"
		var wl := Node3D.new()
		g.add_child(wl)
		_box(Vector3(0.6, 0.03, 0.2), Vector3(0.32, 0, 0), Color("f2f2f2"), 0.012, wl)
		var wr := Node3D.new()
		g.add_child(wr)
		_box(Vector3(0.6, 0.03, 0.2), Vector3(-0.32, 0, 0), Color("f2f2f2"), 0.012, wr)
		g.scale = Vector3.ONE * 1.4
		gulls.append({"node": g, "wl": wl, "wr": wr, "center": Vector3(rng.randf_range(-30, 30), rng.randf_range(16, 26),
			rng.randf_range(-60, -30)), "r": rng.randf_range(8, 18), "speed": rng.randf_range(0.2, 0.4) * (1 if i % 2 else -1),
			"ph": rng.randf() * TAU})
	for i in 4:
		var crab := _place(CRAB, Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-23, -15)), 0.0, 1.5, {"outline": 0.012})
		crabs.append({"node": crab, "x": crab.position.x, "t": rng.randf_range(0, 10)})
	# bandeirinhas nos cantos
	for corner in [Vector3(-6.5, 0, -10.5), Vector3(6.5, 0, -10.5), Vector3(-6.5, 0, 10.5), Vector3(6.5, 0, 10.5)]:
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
		fm.set_shader_parameter("color_a", GameData.TEAMS[0]["shirt"] if corner.z > 0 else GameData.TEAMS[1]["shirt"])
		fm.set_shader_parameter("color_b", Color("ffd23f"))
		flag.material_override = fm
		flag.rotation.y = PI * 0.5
		add_child(flag)


func _stands() -> void:
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = preload("res://shaders/crowd.gdshader")
	var shirts := [Color("ff4b3e"), Color("2f8cff"), Color("ffd23f"), Color("35e0a1"), Color("ff5fa2"),
		Color("ffffff"), Color("9b5de5"), Color("ff9f1c"), Color("1f2a44"), Color("19d3ff")]
	# laterais e fundo da quadra
	var stands := [
		{"pos": Vector3(-11.6, 0, -0.5), "rot": PI * 0.5, "rows": 5},
		{"pos": Vector3(11.6, 0, -0.5), "rot": -PI * 0.5, "rows": 5},
		{"pos": Vector3(0, 0, -14.4), "rot": 0.0, "rows": 5},
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
	# placas de publicidade fictícias em volta da quadra
	var texts := ["SMASH NA AREIA", "RÁDIO PRAIA FM", "AÇAÍ DO ZÉ", "COCO GELADO", "PROTETOR 50+", "PICOLÉ TROPICAL"]
	var colors := [Color("ff4b3e"), Color("2f8cff"), Color("9b5de5"), Color("35e0a1"), Color("ff9f1c"), Color("ff5fa2")]
	var spots := []
	for i in 5:
		spots.append({"pos": Vector3(-8.0 + i * 4.0, 0.45, -10.6), "rot": 0.0})
	for i in 5:
		spots.append({"pos": Vector3(-8.5, 0.45, -8.0 + i * 4.0), "rot": PI * 0.5})
		spots.append({"pos": Vector3(8.5, 0.45, -8.0 + i * 4.0), "rot": -PI * 0.5})
	for i in spots.size():
		var sp: Dictionary = spots[i]
		var holder := Node3D.new()
		holder.position = sp["pos"]
		holder.rotation.y = sp["rot"]
		add_child(holder)
		var c: Color = colors[i % colors.size()]
		_box(Vector3(3.8, 0.9, 0.12), Vector3.ZERO, c, 0.015, holder)
		_box(Vector3(3.8, 0.1, 0.14), Vector3(0, 0.45, 0), Color("ffffff"), 0.0, holder)
		var l := Label3D.new()
		l.text = texts[i % texts.size()]
		l.font = FONT
		l.font_size = 96
		l.pixel_size = 0.0055
		l.outline_size = 18
		l.outline_modulate = Color(0.07, 0.04, 0.12)
		l.modulate = Color("ffffff")
		l.position = Vector3(0, 0, 0.07)
		l.shaded = false
		l.double_sided = false
		holder.add_child(l)
