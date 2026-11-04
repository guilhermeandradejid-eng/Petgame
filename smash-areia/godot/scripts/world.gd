class_name World
extends Node3D
## Monta a praia de dia claro: areia, mar, céu, morros, quadra, rede, juiz,
## arquibancadas com torcida viva, placas, palmeiras ao vento, quiosque,
## salva-vidas, veleiros e siris. Os modelos vêm dos .glb gerados pelo Blender.
##
## Direção de arte (composição vista da câmera, que olha para o mar):
##  * frente: areia clara e lisa; o mais escuro/saturado é a quadra, a bola e os jogadores;
##  * meio: palmeiras em "asas" dos dois lados, inclinadas para a quadra; à esquerda
##    o quiosque, à direita a torre do salva-vidas com pranchas; arquibancadas nas laterais;
##  * fundo: mar, um morro herói à esquerda e uma ilhota à direita, mais claros e azulados;
##  * o céu acima do fundo da quadra fica limpo (é por onde a bola passa).

const SHORE_Z := -26.0

const PALM := preload("res://assets/models/palm.glb")
const PALM_B := preload("res://assets/models/palm_b.glb")
const BUSH := preload("res://assets/models/bush.glb")
const TOWEL := preload("res://assets/models/towel.glb")
const COOLER := preload("res://assets/models/cooler.glb")
const ADBOARD := preload("res://assets/models/adboard.glb")
const UMBRELLA := preload("res://assets/models/umbrella.glb")
const CHAIR := preload("res://assets/models/chair.glb")
const TOWER := preload("res://assets/models/tower.glb")
const CLOUD := preload("res://assets/models/cloud.glb")
const CLOUDS := [preload("res://assets/models/cloud.glb"), preload("res://assets/models/cloud_puff.glb"),
	preload("res://assets/models/cloud_long.glb")]
const CLOUD_SHADER := preload("res://shaders/cloud.gdshader")
const POST := preload("res://assets/models/post.glb")
const BLEACHERS := preload("res://assets/models/bleachers.glb")
const SURFBOARD := preload("res://assets/models/surfboard.glb")
const ISLAND := preload("res://assets/models/island.glb")
const CRAB := preload("res://assets/models/crab.glb")
const MOUNTAINS := preload("res://assets/models/mountains.glb")
const SAILBOAT := preload("res://assets/models/sailboat.glb")
const KIOSK := preload("res://assets/models/kiosk.glb")
const REFCHAIR := preload("res://assets/models/refchair.glb")
# torcedores: 0 sentado palma, 1 sentado torcendo, 2 sentado inclinado, 3 em pé, 4 em pé com placa, 5 criança
const FANS := [preload("res://assets/models/fan_sit_clap.glb"), preload("res://assets/models/fan_sit_cheer.glb"),
	preload("res://assets/models/fan_sit_lean.glb"), preload("res://assets/models/fan_stand_up.glb"),
	preload("res://assets/models/fan_stand_sign.glb"), preload("res://assets/models/fan_kid.glb")]
const FLAG_SHADER := preload("res://shaders/flag.gdshader")
# paleta fechada do cenário (só estes acentos)
const C_BLUE := Color("2f7bff")
const C_BLUE_D := Color("1f4fbf")
const C_RED := Color("ff4d4d")
const C_RED_D := Color("c8333a")
const C_YELLOW := Color("ffc93c")
const C_CORAL := Color("ff7a59")
const C_MINT := Color("3fd6a8")
const C_WHITE := Color("fffdf6")
const C_NAVY := Color("1f3a8a")
const C_LINE := Color("1f5fe0")
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
var night := false
var net_cb := Callable()   # online: o anfitrião replica estes efeitos nos convidados
var bulbs: Array[Dictionary] = []
var fire: Dictionary = {}


func _ready() -> void:
	rng.seed = 2026
	night = GameData.ARENAS[GameData.arena]["id"] == "night"
	RenderingServer.global_shader_parameter_set("arena_night", 1.0 if night else 0.0)
	_environment()
	_ground()
	_court()
	_net()
	_referee()
	_props()
	_stands()
	_boards()
	_land_side()
	if night:
		_night_props()
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
		if crowd_outline_mat:
			crowd_outline_mat.set_shader_parameter("excitement", crowd_excite)
			crowd_outline_mat.set_shader_parameter("ball_pos", ball_pos)
			crowd_outline_mat.set_shader_parameter("ola_t", ola_t)
	for c in clouds:
		c.position.x += dt * float(c.get_meta("speed", 0.6))
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
	_update_night(tt)


# ---------------------------------------------------------------- marcas na areia

var prints_mm: MultiMesh
var prints_age: PackedFloat32Array
var prints_next := 0
const PRINTS := 180
var rings: Array[Dictionary] = []
var color_rings: Array[Dictionary] = []   # anéis de luz coloridos (golpe perfeito, carregado, chance)


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
	for i in 4:
		var r := Toon.blob(1.0, Color(1, 1, 1, 0.0), true)
		r.material_override = r.material_override.duplicate()
		r.visible = false
		add_child(r)
		color_rings.append({"node": r, "t": 1.0, "size": 1.0, "color": Color.WHITE})


## Pegada (ou marca de mergulho) na areia
func footprint(pos: Vector3, yaw: float, size := 1.0) -> void:
	if net_cb.is_valid():
		net_cb.call("w:footprint", [pos, yaw, size])
	var i := prints_next
	prints_next = (prints_next + 1) % PRINTS
	prints_age[i] = 0.0
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(size, 1.0, size))
	prints_mm.set_instance_transform(i, Transform3D(b, Vector3(pos.x, 0.008, pos.z)))
	# pegada de pé descalço só nos passos; mergulho/carrinho deixa a marca oval
	prints_mm.set_instance_color(i, Color(1.0 if size < 2.0 else 0.0, 1, 1, 1))


## Onda de areia quando a bola cai ou alguém mergulha
func sand_ring(pos: Vector3, size := 1.0) -> void:
	if net_cb.is_valid():
		net_cb.call("w:sand_ring", [pos, size])
	for d in rings:
		if float(d["t"]) >= 1.0:
			var n: MeshInstance3D = d["node"]
			n.global_position = Vector3(pos.x, 0.03, pos.z)
			n.visible = true
			d["t"] = 0.0
			d["size"] = size
			return


## Anel de luz que abre no chão (feedback sem texto)
func ground_ring(pos: Vector3, color: Color, size := 1.0) -> void:
	if net_cb.is_valid():
		net_cb.call("w:ground_ring", [pos, color, size])
	var best: Dictionary = color_rings[0]
	for d in color_rings:
		if float(d["t"]) >= 1.0:
			best = d
			break
	var n: MeshInstance3D = best["node"]
	n.global_position = Vector3(pos.x, 0.035, pos.z)
	n.visible = true
	best["t"] = 0.0
	best["size"] = size
	best["color"] = color


func _update_marks(dt: float) -> void:
	for d in color_rings:
		if float(d["t"]) < 1.0:
			d["t"] = minf(float(d["t"]) + dt / 0.38, 1.0)
			var t: float = d["t"]
			var n: MeshInstance3D = d["node"]
			n.scale = Vector3.ONE * lerpf(0.5, 3.0, 1.0 - pow(1.0 - t, 3.0)) * float(d["size"])
			var c: Color = d["color"]
			c.a = 0.9 * (1.0 - t)
			(n.material_override as ShaderMaterial).set_shader_parameter("color", c)
			(n.material_override as ShaderMaterial).set_shader_parameter("pulse", 0.0)
			if t >= 1.0:
				n.visible = false
	for i in PRINTS:
		if prints_age[i] < 8.0:
			prints_age[i] += dt
			prints_mm.set_instance_color(i, Color(prints_mm.get_instance_color(i).r, 1, 1, clampf(1.0 - prints_age[i] / 8.0, 0.0, 1.0)))
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
	if net_cb.is_valid():
		net_cb.call("w:cheer", [amount])
	crowd_excite = clampf(maxf(crowd_excite, amount), 0.0, 1.0)


func ola() -> void:
	if net_cb.is_valid():
		net_cb.call("w:ola", [])
	ola_t = 0.0
	cheer(1.0)


func whistle() -> void:
	if net_cb.is_valid():
		net_cb.call("w:whistle", [])
	ref_whistle = 1.0


# ---------------------------------------------------------------- ambiente

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sm
	sm.set_shader_parameter("night", 1.0 if night else 0.0)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# tudo é unshaded: sem reflexo do céu (o céu não precisa virar cubemap a cada frame)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	sky.radiance_size = Sky.RADIANCE_SIZE_32
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
	sand.position = Vector3(0, 0, SHORE_Z + 254.0)   # passa da linha curva; o shader recorta
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sand.gdshader")
	m.set_shader_parameter("shore_z", SHORE_Z)
	m.set_shader_parameter("court_half", Vector2(GameData.COURT_HALF_W, GameData.COURT_HALF_L))
	sand.material_override = m
	add_child(sand)
	var sea := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(1000, 460)
	sp.subdivide_width = 48
	sp.subdivide_depth = 24
	sea.mesh = sp
	sea.position = Vector3(0, -0.05, SHORE_Z - 224.0)   # entra por baixo da areia na enseada
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
	var tape := C_LINE
	var w := 0.11
	_box(Vector3(w, 0.02, hl * 2.0 + w), Vector3(-hw, 0.01, 0), tape)
	_box(Vector3(w, 0.02, hl * 2.0 + w), Vector3(hw, 0.01, 0), tape)
	_box(Vector3(hw * 2.0 + w, 0.02, w), Vector3(0, 0.01, -hl), tape)
	_box(Vector3(hw * 2.0 + w, 0.02, w), Vector3(0, 0.01, hl), tape)


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
	var blue := C_BLUE
	for sx in [-1.0, 1.0]:
		var post: Node3D = POST.instantiate()
		post.position = Vector3(sx * half, 0, 0)
		# poste único e gordinho (azul, faixa e tampa brancas): sem estais nem estacas
		Toon.apply(post, {}, {"outline": 0.025, "halftone": 0.0})
		add_child(post)
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
		t.text = "SMASH NA AREIA"
		t.font = FONT
		t.font_size = 48
		t.pixel_size = 0.0016
		t.outline_size = 0
		t.modulate = blue
		t.shaded = false
		t.position = Vector3(0, nh - 0.035, sz * 0.022)
		t.rotation.y = 0.0 if sz > 0 else PI
		add_child(t)
	# antenas listradas (vermelho e branco)
	for sx in [-1.0, 1.0]:
		for k in 8:
			var col := C_RED if k % 2 == 0 else Color("ffffff")
			_cyl(0.02, 0.1, Vector3(sx * GameData.COURT_HALF_W, nh - depth + 0.05 + k * 0.1 + 0.9, 0.0) - Vector3(0, 0.0, 0), col, 0.0)
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
	if net_cb.is_valid():
		net_cb.call("w:net_hit", [pos])
	net_hit_t = 0.0
	if net_mat:
		net_mat.set_shader_parameter("hit_x", pos.x)
		net_mat.set_shader_parameter("hit_amp", 0.22)


func _referee() -> void:
	var chair := _place(REFCHAIR, Vector3(5.6, 0, 0), -PI * 0.5, 1.0, {"bg": 0.0, "outline": 0.025, "rim": 0.3})
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
	# política de contorno: peças do meio (até ~40 m) com traço fino na cor da peça;
	# o fundo distante passa outline 0 e rim 0 (duas cores chapadas)
	var o := {"outline": 0.017, "halftone": 0.0, "bg": 1.0, "rim": 0.25}
	o.merge(opts, true)
	var pal: Dictionary = o.get("palette", {})
	o.erase("palette")
	# folhas: sombra verde-clara (vistas de baixo não ficam pretas), traço bem fino
	var leaf := {"wind": 1.0, "outline": 0.008, "rim": 0.0, "shadow": Color(0.72, 0.86, 0.62)}
	Toon.apply(n, pal, o, ds, {"Leaf": leaf, "LeafDark": leaf})
	add_child(n)
	return n


func _props() -> void:
	# palmeiras em "asas" dos dois lados, inclinadas para a quadra; o centro do
	# fundo fica aberto (placas, mar e horizonte). palm_b é baixa e bem torta.
	# O tronco do modelo inclina para +X: rot_y escolhe para onde ele aponta.
	var palms := [
		[PALM, Vector3(-15.0, 0, -19.0), 1.3], [PALM_B, Vector3(-17.5, 0, -21.5), 1.1],
		[PALM, Vector3(16.0, 0, -20.0), 1.35], [PALM, Vector3(19.5, 0, -23.0), 1.0], [PALM_B, Vector3(13.5, 0, -24.0), 0.9],
	]
	for pd in palms:
		var pp: Vector3 = pd[1]
		var to_c := Vector3(-pp.x, 0, -pp.z * 0.25).normalized()
		_place(pd[0], pp, atan2(-to_c.z, to_c.x) + rng.randf_range(-0.15, 0.15), pd[2])
		_place(BUSH, pp + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(0.4, 0.9)), rng.randf() * TAU,
				rng.randf_range(0.9, 1.25))
	# canto do quiosque (esquerda): quiosque, dois guarda-sóis com toalha,
	# cadeiras e uma caixa térmica (a fogueira da noite fica aqui perto)
	var kiosk := _place(KIOSK, Vector3(-21.0, 0, -19.0), 0.5, 1.2)
	_label(kiosk, "ÁGUA DE COCO", Vector3(0, 2.35, 1.62), 0.006, C_WHITE)
	_beach_spot(Vector3(-15.0, 0, -16.5), C_CORAL, C_YELLOW, 0.3)
	_beach_spot(Vector3(-18.5, 0, -21.5), C_YELLOW, C_MINT, -0.4)
	_place(CHAIR, Vector3(-13.6, 0, -15.6), 0.6, 1.0)
	_place(COOLER, Vector3(-19.2, 0, -16.8), 0.3, 1.0)
	# canto do salva-vidas (direita): torre com bandeira e pranchas fincadas em leque
	var tower := _place(TOWER, Vector3(18.0, 0, -17.5), -0.4, 1.1)
	_flag(tower, Vector3(0.9, 4.2, 0.2), C_RED, C_YELLOW, 1.6)
	var boards := [[C_YELLOW, C_CORAL], [C_MINT, C_WHITE], [C_BLUE, C_YELLOW]]
	for k in 3:
		var sb := _place(SURFBOARD, Vector3(14.2 + k * 0.75, -0.25, -17.2 - k * 0.15), 0.25 - k * 0.1, 1.0,
				{"palette": {"BoardBase": boards[k][0], "BoardStripe": boards[k][1]}})
		sb.rotation.z = deg_to_rad(-10.0 + k * 10.0)
	_beach_spot(Vector3(13.0, 0, -21.2), C_MINT, C_WHITE, 0.2)
	# siris só perto da água
	for k in 3:
		# longe do corredor da bola (|x| >= 9)
		var cx: float = [-15.0, 11.0, 20.0][k] + rng.randf_range(-1.5, 1.5)
		var cn := _place(CRAB, Vector3(cx, 0, SHORE_Z + 4.0 + rng.randf_range(0, 1.5)), rng.randf() * TAU, 0.9)
		crabs.append({"node": cn, "x": cx, "t": rng.randf() * 10.0})
	# horizonte: morro herói à esquerda, serra baixa à direita, uma ilhota
	var far := {"outline": 0.0, "halftone": 0.0, "rim": 0.0, "fog": 0.6}
	_place(MOUNTAINS, Vector3(-210, -1, -380), 0.3, 2.0, far)
	_place(MOUNTAINS, Vector3(220, -1, -350), PI - 0.2, 1.8, far)
	for p in [Vector3(95, -0.5, -240), Vector3(-60, -0.5, -255)]:
		_place(ISLAND, p, rng.randf_range(0, TAU), 3.0 if p.x > 0 else 2.2, far)
	# nuvens: poucas, espaçadas de forma irregular, nenhuma no corredor da bola (|x| < 50 no fundo)
	var cloud_spots := [Vector3(-160, 52, -260), Vector3(-95, 66, -230), Vector3(-62, 44, -290), Vector3(70, 58, -270),
		Vector3(128, 46, -240), Vector3(185, 68, -300), Vector3(-120, 50, 220), Vector3(40, 62, 240), Vector3(150, 44, 210)]
	for i in cloud_spots.size():
		var cp: Vector3 = cloud_spots[i]
		var kind := i % 3
		var sc := rng.randf_range(8.0, 12.0)
		var c: Node3D = (CLOUDS[kind] as PackedScene).instantiate()
		c.position = cp
		c.rotation.y = rng.randf_range(-0.25, 0.25) + (PI if cp.z > 0 else 0.0)
		c.scale = Vector3(sc, sc * rng.randf_range(0.85, 1.0), sc)
		add_child(c)
		var m := ShaderMaterial.new()
		m.shader = CLOUD_SHADER
		m.set_shader_parameter("haze", clampf((absf(cp.z) - 200.0) / 160.0, 0.0, 1.0) * 0.3)
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = m
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.set_meta("speed", rng.randf_range(0.4, 0.9))
		clouds.append(c)
	for i in 2:
		var b := _place(SAILBOAT, Vector3(-120 + i * 210, 0, rng.randf_range(-150, -95)),
				PI * 0.5, 1.6, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
		boats.append({"node": b, "speed": rng.randf_range(1.0, 2.0), "ph": rng.randf() * 10.0})


## Guarda-sol inclinado com toalha listrada embaixo (cores por instância)
func _beach_spot(pos: Vector3, top: Color, towel: Color, yaw: float) -> void:
	var u := _place(UMBRELLA, pos, yaw, 1.0, {"palette": {"UmbrellaA": top}})
	u.rotation.x = deg_to_rad(rng.randf_range(8.0, 12.0))
	_place(TOWEL, pos + Vector3(0.6, 0.0, 0.9), yaw + 0.3, 1.0, {"palette": {"TowelA": towel}, "outline": 0.0})


## Bandeira tremulando presa num poste fino
func _flag(parent: Node3D, pos: Vector3, a: Color, b: Color, size := 1.2) -> void:
	_cyl(0.045, size * 1.4, pos + Vector3(0, -size * 0.7 + size * 1.4 * 0.5, 0), C_WHITE, 0.012, parent)
	var fm := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size * 0.6)
	q.subdivide_width = 8
	fm.mesh = q
	fm.position = pos + Vector3(size * 0.5, size * 0.7 - size * 0.3, 0)
	var m := ShaderMaterial.new()
	m.shader = FLAG_SHADER
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("phase", rng.randf() * TAU)
	fm.material_override = m
	parent.add_child(fm)


func _label(parent: Node3D, text: String, pos: Vector3, px: float, col: Color, outline_col := Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 18 if outline_col.a > 0.0 else 0
	l.outline_modulate = outline_col
	l.modulate = col
	l.position = pos
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l


func _stands() -> void:
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = preload("res://shaders/crowd.gdshader")
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://shaders/crowd_outline.gdshader")
	outline.render_priority = -1
	crowd_mat.next_pass = outline
	crowd_outline_mat = outline
	# camisas: 45% tons do time, 20% branco, 35% "civis" (amarelo, menta, coral, lilás, cinza)
	var team_shirts := [[C_BLUE, Color("5fa0ff"), C_BLUE_D], [C_RED, Color("ff7a70"), C_RED_D]]
	var civil := [C_YELLOW, C_MINT, C_CORAL, Color("9b7bff"), Color("6e7b8f")]
	# só nas laterais: o fundo fica livre para ver o mar
	var stands := [
		{"pos": Vector3(-11.6, 0, -0.5), "rot": PI * 0.5, "rows": 5, "team": 0},
		{"pos": Vector3(11.6, 0, -0.5), "rot": -PI * 0.5, "rows": 5, "team": 1},
	]
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.35
	for si in stands.size():
		var st: Dictionary = stands[si]
		var tc: Color = C_BLUE if si == 0 else C_RED
		var td: Color = C_BLUE_D if si == 0 else C_RED_D
		var b := _place(BLEACHERS, st["pos"], st["rot"], 1.0, {"outline": 0.014, "halftone": 0.0, "rim": 0.2,
			"palette": {"BleachSeatA": tc, "BleachSeatB": tc.lightened(0.12), "BleachTeam": tc, "BleachSkirt": td}})
		var per_variant: Array = [[], [], [], [], [], []]
		var colors: Array = [[], [], [], [], [], []]
		for row in int(st["rows"]):
			var count := 16
			for i in count:
				var along := -7.0 + (i + (0.5 if row % 2 == 1 else 0.0)) * (14.0 / float(count)) + rng.randf_range(-0.18, 0.18)
				if along > 7.0:
					continue
				# lugares vazios em grupinhos (ruído), não espalhados por igual
				if noise.get_noise_2d(along + si * 40.0, row * 3.0) > 0.42:
					continue
				var lp := Vector3(along, 0.45 + row * 0.5, -(row * 0.75 - 0.12))
				var centre := absf(along) < 4.0 and row <= 2
				var rv := rng.randf()
				var v := 0
				if centre and rv < 0.3:
					v = 3 if rng.randf() < 0.7 else 4        # em pé na frente e no meio
				elif rv < 0.07:
					v = 5                                     # criança
				else:
					var r2 := rng.randf()
					v = 0 if r2 < 0.45 else (1 if r2 < 0.75 else 2)
				var ts: Array = team_shirts[si]
				var shirt: Color
				var rc := rng.randf()
				if rc < 0.45:
					shirt = ts[rng.randi() % ts.size()]
				elif rc < 0.65:
					shirt = C_WHITE
				else:
					shirt = civil[rng.randi() % civil.size()]
				var sc := rng.randf_range(0.85, 1.1)
				per_variant[v].append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * sc), lp))
				colors[v].append(shirt)
		for v in FANS.size():
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
				mm.set_instance_color(i, colors[v][i])
				mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = crowd_mat
			b.add_child(mmi)
		# faixa da torcida na frente (segurada pela primeira fileira) e uma bandeira no alto
		var banner := Node3D.new()
		banner.position = Vector3(-1.5, 1.55, 0.25)
		b.add_child(banner)
		_box(Vector3(3.2, 0.62, 0.05), Vector3.ZERO, C_WHITE, 0.012, banner)
		_box(Vector3(3.0, 0.48, 0.07), Vector3.ZERO, tc, 0.0, banner)
		_label(banner, "VAI TUBARÕES!" if si == 0 else "VAI SIRIS!", Vector3(0, 0, 0.045), 0.0042, C_WHITE)
		_flag(b, Vector3(7.95 if si == 0 else -7.95, 4.0, -1.2), tc, C_WHITE, 1.3)


var crowd_outline_mat: ShaderMaterial


func _boards() -> void:
	# quatro placas coloridas e diferentes atrás do fundo da quadra
	var boards := [
		[C_BLUE, "SMASH", C_WHITE], [C_YELLOW, "BEACH TENNIS", C_NAVY],
		[C_RED, "NA AREIA", C_WHITE], [C_MINT, "ÁGUA DE COCO", C_NAVY],
	]
	for i in 4:
		var x := -5.7 + i * 3.8
		var bd := _place(ADBOARD, Vector3(x, 0, -11.5), 0.0, 1.0,
				{"outline": 0.018, "bg": 0.0, "rim": 0.2, "palette": {"BoardFace": boards[i][0]}})
		_label(bd, boards[i][1], Vector3(0, 0.47, 0.105), 0.0052 if String(boards[i][1]).length() < 10 else 0.0042, boards[i][2])


## Lado da terra (visto pela câmera do J2 no VS): calçadão, palmeiras, prédios e morros
func _land_side() -> void:
	_box(Vector3(260, 0.12, 5.0), Vector3(0, 0.06, 31.0), Color("f4efe6"), 0.0)
	_box(Vector3(260, 0.25, 1.2), Vector3(0, 0.12, 34.0), Color("4fbf6b"), 0.0)
	for xk in [-52.0, -38.0, -31.0, -14.0, 9.0, 21.0, 37.0, 50.0]:
		var pb := PALM if int(absf(xk)) % 2 == 0 else PALM_B
		_place(pb, Vector3(xk, 0, 34.0 + rng.randf_range(-0.6, 1.2)), rng.randf() * TAU, rng.randf_range(1.1, 1.4))
	var cols := [Color("ffd9b8"), Color("bfe8d8"), Color("bfdcff"), Color("e5d1ff"), Color("fff1c2"), Color("ffc9c9")]
	var r2 := RandomNumberGenerator.new()
	r2.seed = 77
	var x := -190.0
	while x < 190.0:
		var w := r2.randf_range(10.0, 18.0)
		var h := r2.randf_range(12.0, 30.0)
		var c: Color = cols[r2.randi() % cols.size()]
		var z := r2.randf_range(118.0, 132.0)
		# camada distante: chapada, sem contorno (só a silhueta e as janelas)
		var bld := _box(Vector3(w, h, 10.0), Vector3(x + w * 0.5, h * 0.5, z), c, 0.0)
		bld.material_override = Toon.make(c, {"outline": 0.0, "halftone": 0.0, "rim": 0.0, "shadow": Color(0.86, 0.82, 0.92)})
		_box(Vector3(w + 0.6, 0.5, 10.6), Vector3(0, h * 0.5 + 0.25, 0), c.darkened(0.15), 0.0, bld)
		if r2.randf() < 0.5:
			# recuo no topo (60% da largura, +4 m)
			_box(Vector3(w * 0.6, 4.0, 8.0), Vector3(r2.randf_range(-0.15, 0.15) * w, h * 0.5 + 2.5, 0.5), c, 0.0, bld)
			_box(Vector3(w * 0.6 + 0.5, 0.45, 8.5), Vector3(0, 2.2, 0), c.darkened(0.15), 0.0, bld.get_child(-1))
		# janelas individuais (grade 2,6 x 3,6 m), algumas acesas à noite
		var cols_n := int((w - 1.4) / 2.6)
		var rows_n := int((h - 3.0) / 3.6)
		var wc := c.darkened(0.3)
		for j in rows_n:
			for wi in cols_n:
				var wp := Vector3(-(cols_n - 1) * 1.3 + wi * 2.6, -h * 0.5 + 3.0 + j * 3.6, -5.05)
				_box(Vector3(1.1, 1.3, 0.15), wp, wc, 0.0, bld)
				if night and r2.randf() < 0.45:
					var lw := MeshInstance3D.new()
					var lq := QuadMesh.new()
					lq.size = Vector2(1.0, 1.2)
					lw.mesh = lq
					lw.position = wp + Vector3(0, 0, -0.09)
					lw.rotation.y = PI
					lw.material_override = _glow_mat(Color(1.0, 0.85, 0.5) if r2.randf() < 0.7 else Color(0.7, 0.85, 1.0))
					bld.add_child(lw)
		x += w + r2.randf_range(1.0, 4.0)
	_place(MOUNTAINS, Vector3(-140, -1, 330), PI + 0.4, 2.4, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})
	_place(MOUNTAINS, Vector3(170, -1, 360), 0.2, 2.0, {"outline": 0.0, "halftone": 0.0, "rim": 0.0})


# ---------------------------------------------------------------- arena NOITE

## Material que brilha (não escurece com a noite e passa do limiar do bloom)
func _glow_mat(c: Color, add := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, alpha)
	if add or alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


## Refletores nos quatro cantos, com feixe de luz falso (cone aditivo), varal de
## lâmpadas no fundo e uma fogueira de luau na areia.
func _night_props() -> void:
	var beam_mat := _glow_mat(Color(1.0, 0.95, 0.8), true, 0.016)
	var lamp_mat := _glow_mat(Color(1.0, 1.0, 0.96))
	# refletores afastados (fora do quadro da câmera de rali), postes afinando
	for c in [Vector3(-17.5, 0, -16.0), Vector3(17.5, 0, -16.0), Vector3(-14.0, 0, 22.0), Vector3(14.0, 0, 22.0)]:
		var h := 9.0
		var pole := _cyl(0.22, h, c + Vector3(0, h * 0.5, 0), Color("2b2f4a"), 0.02)
		(pole.mesh as CylinderMesh).top_radius = 0.14
		_cyl(0.2, 0.3, c + Vector3(0, 2.2, 0), C_WHITE, 0.0)
		var head := Node3D.new()
		head.position = c + Vector3(0, h + 0.4, 0)
		add_child(head)
		head.look_at(Vector3(0, 0, c.z * 0.25), Vector3.UP)
		_box(Vector3(2.4, 1.3, 0.35), Vector3.ZERO, Color("2b2f4a"), 0.03, head)
		for ix in 3:
			for iy in 2:
				var lamp := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(0.62, 0.5)
				lamp.mesh = q
				lamp.position = Vector3(-0.78 + ix * 0.78, -0.28 + iy * 0.56, -0.19)
				lamp.rotation.y = PI
				lamp.material_override = lamp_mat
				head.add_child(lamp)
		if c.z > 0.0:
			continue   # o par de trás fica atrás da câmera: sem feixe
		# feixe: cone aditivo bem transparente do refletor até a quadra
		var target := Vector3(c.x * 0.2, 0, c.z * 0.25)
		var from := head.position
		var len := from.distance_to(target)
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.9
		cm.bottom_radius = 5.5
		cm.height = len
		cm.radial_segments = 20
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		beam.mesh = cm
		beam.material_override = beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		var dir := (target - from).normalized()
		beam.position = (from + target) * 0.5
		var axis := Vector3.DOWN.cross(dir)
		if axis.length() > 0.001:
			beam.basis = Basis(axis.normalized(), Vector3.DOWN.angle_to(dir))
	# varal de lâmpadas coloridas atrás do fundo, de palmeira a palmeira
	var cols := [Color("ffd23f"), Color("ff5fa2"), Color("4fe0ff"), Color("35e0a1"), Color("ff9f1c")]
	for side in [-1.0, 1.0]:
		var a := Vector3(-14.0, 4.6, side * 14.0)   # entre as palmeiras das "asas", atrás das placas
		var b := Vector3(14.0, 4.6, a.z)
		var n := 26
		var prev := a
		for i in n + 1:
			var t := float(i) / float(n)
			var sag := 1.0 - pow(2.0 * fmod(t * 2.0, 1.0) - 1.0, 2.0)   # caimento entre os postes
			var p := a.lerp(b, t) + Vector3(0, -sag * 0.9, 0)
			if i > 0:
				_rope(prev, p, 0.012, Color("1d1d26"))
			prev = p
			if i < n:
				var bl := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.11
				sm.height = 0.24
				sm.radial_segments = 8
				sm.rings = 4
				bl.mesh = sm
				var col: Color = cols[i % cols.size()]
				var mat := _glow_mat(col.lightened(0.35))
				bl.material_override = mat
				bl.position = p + Vector3(0, -0.14, 0)
				add_child(bl)
				bulbs.append({"mat": mat, "col": col.lightened(0.35), "ph": rng.randf() * TAU})
		for x in [a.x, b.x]:
			_cyl(0.07, 4.8, Vector3(x, 2.4, a.z), Color("3a2c22"), 0.015)
	# tochas tiki ao longo do fundo
	for tx in [-12.0, -8.0, 8.0, 12.0]:
		var tp := Vector3(tx, 0, -13.0)
		_cyl(0.08, 1.8, tp + Vector3(0, 0.9, 0), Color("8c5a35"), 0.012)
		_cyl(0.13, 0.25, tp + Vector3(0, 1.85, 0), Color("c9923f"), 0.012)
		var tf := MeshInstance3D.new()
		var tq := QuadMesh.new()
		tq.size = Vector2(0.32, 0.5)
		tf.mesh = tq
		var tm := _glow_mat(Color(1.0, 0.7, 0.3), true, 0.9)
		tm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		tf.material_override = tm
		tf.position = tp + Vector3(0, 2.2, 0)
		add_child(tf)
		var tg := Toon.blob(2.2, Color(1.0, 0.55, 0.2, 0.22))
		tg.position = tp + Vector3(0, 0.02, 0)
		add_child(tg)
	# fogueira de luau perto do quiosque, com toras e faíscas
	var fp := Vector3(-19.0, 0, -17.0)
	for k in 4:
		var lg := _cyl(0.09, 1.1, fp + Vector3(0, 0.1, 0), Color("5a3a24"), 0.012)
		lg.basis = Basis(Vector3.UP, k * PI * 0.25) * Basis(Vector3.RIGHT, PI * 0.5)
	var glow := Toon.blob(4.0, Color(1.0, 0.55, 0.2, 0.35))
	glow.position = fp + Vector3(0, 0.02, 0)
	add_child(glow)
	var flames := CPUParticles3D.new()
	flames.position = fp + Vector3(0, 0.15, 0)
	flames.amount = 40
	flames.lifetime = 0.9
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.28
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 2.2, 0)
	flames.initial_velocity_min = 0.6
	flames.initial_velocity_max = 1.4
	flames.scale_amount_min = 0.5
	flames.scale_amount_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.1))
	flames.scale_amount_curve = sc
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.8, 0.15, 0.05, 0.0)])
	flames.color_ramp = grad
	var fq := QuadMesh.new()
	fq.size = Vector2(0.45, 0.6)
	var fmat := _glow_mat(Color.WHITE, true)
	fmat.vertex_color_use_as_albedo = true
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fq.material = fmat
	flames.mesh = fq
	add_child(flames)
	fire = {"glow": glow, "pos": fp}


func _update_night(tt: float) -> void:
	if not night:
		return
	for b in bulbs:
		var k := 0.82 + 0.18 * sin(tt * 2.2 + float(b["ph"]))
		(b["mat"] as StandardMaterial3D).albedo_color = (b["col"] as Color) * k
	if not fire.is_empty():
		var g: MeshInstance3D = fire["glow"]
		g.scale = Vector3.ONE * (1.0 + 0.08 * sin(tt * 13.0) + 0.05 * sin(tt * 7.3))
