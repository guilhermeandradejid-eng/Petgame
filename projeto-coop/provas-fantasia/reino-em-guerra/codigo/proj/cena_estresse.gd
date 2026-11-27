extends Node3D
# Captura de estresse da prévia Web (Compatibility), v2: o mesmo vau em profundidade (câmera de 22°, FOV 42°, yaw 50°),
# 4 heróis com cor e símbolo de chão de jogador, 20 mortos em gravura negativa, 3 efeitos (vau eletrificado pelo Raio
# de Contrato da Bruxa, chão consagrado da Sineira, Incêndio de Breu do Sapador com barril tombado, chamas e brasas),
# telegrafias em vermelhão de perigo, atmosfera barata (névoa de distância e de altura no shader, 2 cartões de névoa,
# céu próprio, chuva e cinzas em MultiMesh calculados no shader).
# mascara=1: heróis brancos, mortos cinza, resto preto (para os portões).
const Boneco = preload("res://boneco.gd")
const Mundo = preload("res://mundo.gd")
const YAW := 50.0
var main
var mundo
var herois: Array = []
var mortos: Array = []
var mascara := false
const SIMB := {"porta": 0, "sineira": 1, "sapador": 2, "bruxa": 3}

func bon(n: String, p: Vector3, yaw_deg: float, anim: String, tt: float):
	var b = Boneco.new()
	add_child(b)
	if mascara:
		b.setup(n, 1.5, Color(1, 1, 1) if n in SIMB else Color(0.5, 0.5, 0.5))
	else:
		b.setup(n, 2.0 if n in SIMB else 1.5)
	b.position = p
	b.rotation.y = deg_to_rad(yaw_deg)
	b.pose(anim, tt)
	return b

func alt(p: Vector3) -> Vector3:
	return Vector3(p.x, mundo.altura(p.x, p.z), p.z)

func setup(m) -> void:
	main = m
	mascara = main.A("mascara", "0") == "1"
	main.gset("curva_k", 0.008)
	main.gset("curva_r0", 8.0)
	main.gset("escuro_base", 1.0)
	main.gset("escuro_faixa", 2.5)
	main.gset("escuro_mundo", float(main.A("em", "2.8")))
	main.gset("frente_x", Vector2(-6.0, 14.0))
	main.gset("nevoa", Vector4(24.0, 70.0, 0.92, 0.25))
	main.gset("nevoa_alt", Vector4(0.2, -3.5, 21.0, 0.8))
	main.gset("vento", Vector2(1.0, 0.25))
	main.gset("papel_frio", Color("#8E97A3").srgb_to_linear())
	main.gset("papel_quente", Color("#E3C99A").srgb_to_linear())
	main.sol(Vector3(0.7, 0.48, 0.55))
	var cam: Camera3D = main.cam
	cam.fov = 42.0
	cam.near = 0.3
	cam.far = 4000.0
	var foco := Vector3(main.F("fxx", 0.7), 0, main.F("fzz", 0.2))
	var fw := Vector3(sin(deg_to_rad(YAW)), 0, -cos(deg_to_rad(YAW)))
	var rt := Vector3(cos(deg_to_rad(YAW)), 0, sin(deg_to_rad(YAW)))
	var pit := deg_to_rad(22.0)
	cam.global_position = foco - fw * 15.0 * cos(pit) + Vector3(0, 15.0 * sin(pit), 0)
	cam.look_at(foco, Vector3.UP)
	main.gset("foco", foco)
	main.gset("curva_dir", Vector2(fw.x, fw.z))
	main.gset("tempo", 2.1)
	mundo = Mundo.new()
	add_child(mundo)
	mundo.setup(main, false)
	mundo.terreno()
	mundo.agua()
	mundo.trigo(4000)
	mundo.pedras()
	mundo.ponte()
	mundo.casa(Vector3(9.6, mundo.altura(9.6, 8.0), 8.0), 80.0)
	mundo.agulhas()
	mundo.arvore_forca()
	mundo.forte()
	mundo.moinho3d()
	mundo.cerca()
	mundo.estandarte_queimado(Vector3(-10.5, 0, -10.8), 14.0, 1)
	mundo.estandarte_queimado(Vector3(9.2, 0, -10.5), -10.0, 2)
	mundo.estandarte_queimado(Vector3(5.2, 0, -0.9), 24.0, 3)
	mundo.corvos(mundo.ARVORE + Vector3(1.0, 0, 0), 5, 2.6, 5.5)
	var c0 := foco - fw * 15.0 * cos(pit)
	mundo.estacas([c0 + fw * 7.2 - rt * 6.6, c0 + fw * 7.6 + rt * 7.4])
	mundo.arvore_perto(c0 + fw * 3.4 - rt * 4.6)
	mundo.ceu(main.env)
	mundo.ceu_mat.set_shader_parameter("yaw0", deg_to_rad(YAW))
	mundo.horizonte(cam, 0.206)
	mundo.nevoa(2)
	mundo.particulas(480, 120)
	mundo.passo(2.1)
	# 4 heróis
	var porta = bon("porta", Vector3(2.8, 0, 0.3), -40.0, "juramento", 0.2)
	var mastro = main.prop("mastro"); mastro.position = Vector3(3.3, -0.12, -0.3); mastro.rotation.z = 0.06
	var sineira = bon("sineira", alt(Vector3(-1.3, 0, 4.0)), 35.0, "grita", 0.3)
	var s = main.prop("sino"); sineira.anexar(s, "prop")
	var sap = bon("sapador", Vector3(4.9, -0.05, 0.6), 250.0, "arremessa", 0.12)
	var bru = bon("bruxa", Vector3(-4.2, 0.0, 0.2), 70.0, "contrato", 0.2)
	herois = [porta, sineira, sap, bru]
	if not mascara:
		porta.param(["contorno"], "isolado", 0.0)
	for b in herois:
		b.springs_default()
	main.reservas = [porta.position, sineira.position, sap.position, bru.position]
	# 20 mortos: 6 Piqueiros em linha com telegrafia, 13 Penitentes, 1 Carpideira
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in 6:
		var p = bon("piqueiro", Vector3(-2.9 + i * 1.15, 0, -3.6 + 0.15 * sin(i * 2.0)), rng.randf_range(-8, 8), "baixa", 0.75)
		mortos.append(p)
		if not mascara: _faixa(p, i)
	for i in 13:
		var x := -4.5 + (i % 5) * 2.0 + rng.randf_range(-0.5, 0.5)
		var z := -5.0 - (i / 5) * 1.2 + rng.randf_range(-0.3, 0.3)
		var p = bon("penitente", Vector3(x, 0, z), rng.randf_range(-30, 30), "gira" if i % 3 == 0 else "anda", rng.randf() * 0.5)
		mortos.append(p)
	var carp = bon("carpideira", alt(Vector3(1.8, 0, -7.6)) + Vector3(0, 0.2, 0), -15.0, "inspira", 0.6)
	mortos.append(carp)
	if not mascara:
		# anéis de chão dos jogadores (as cores vivas de identificação ficam só no anel)
		var cores := ["#D9472B", "#E8B23A", "#3F62C8", "#9B3FA8"]
		for i in 4:
			_anel_jog(herois[i], Color(cores[i]), i)
		# efeito 1: vau eletrificado pelo Raio de Contrato da Bruxa (fios até 4,6 m e 3 anéis de pena)
		mundo.agua_mat.set_shader_parameter("elet", Vector4(-0.6, -4.2, 4.6, 1.0))
		_onda(Vector3(-0.6, 0.07, -4.2), 4.6, 0.38)
		_raio(Vector3(-0.6, 0.0, -4.2))
		_queimado(Vector3(-0.6, 0.05, -4.2))
		# efeito 2: chão consagrado da Sineira (círculo de papel com borda de cera)
		mundo.agua_mat.set_shader_parameter("cons", Vector4(-2.9, -1.2, 1.9, 1.0))
		# efeito 3: Incêndio de Breu do Sapador na margem direita (barril tombado, poça, chamas, brasas, fumaça)
		_breu(alt(Vector3(4.6, 0, -8.4)))
		# telegrafia da Carpideira em vermelhão de perigo
		var circ := MeshInstance3D.new(); var cq := PlaneMesh.new(); cq.size = Vector2(7, 7); circ.mesh = cq
		var cm := ShaderMaterial.new(); cm.shader = load("res://shaders/perigo.gdshader"); cm.set_shader_parameter("verde", Color("#B5301F")); cm.set_shader_parameter("modo", 1); cm.set_shader_parameter("progresso", 0.6)
		circ.material_override = cm; circ.position = Vector3(1.4, 0.06, -5.4); add_child(circ)
		main.luzes = [{"p": sineira.osso_global("coroa").origin + Vector3(0, 0.25, 0), "r": 3.0, "k": 1.0, "q": 1.0},
			{"p": sap.osso_global("lanterna").origin, "r": 2.4, "k": 0.95, "q": 1.0},
			{"p": alt(Vector3(4.6, 0, -8.4)) + Vector3(0, 0.6, 0), "r": 3.6, "k": 1.0, "q": 1.0},
			{"p": Vector3(-0.6, 0.5, -4.2), "r": 3.0, "k": 0.9, "q": 0.0},
			{"p": mundo.to_global(Vector3(9.6, 1.9, 8.0)), "r": 2.4, "k": 0.8, "q": 1.0},
			{"p": mundo.portao_luz, "r": 2.2, "k": 0.85, "q": 1.0}]
		main.pos_mat.set_shader_parameter("vinheta", 0.85)
		main.pos_mat.set_shader_parameter("manchas", 1.0)
	else:
		_mascara_mundo(mundo)
		_mascara_mundo(mastro)
		_mascara_mundo(s)
		main.pos_mat.set_shader_parameter("peneira", 0.0)
		main.pos_mat.set_shader_parameter("registro", 0.0)
		main.pos_mat.set_shader_parameter("fibra", 0.0)
		main.env.background_mode = Environment.BG_COLOR
		main.env.background_color = Color.BLACK

func _mascara_mundo(n: Node) -> void:
	var preto := StandardMaterial3D.new()
	preto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preto.albedo_color = Color.BLACK
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		c.material_override = preto

func _faixa(p, i: int) -> void:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(0.8, 3.6)
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/perigo.gdshader")
	m.set_shader_parameter("verde", Color("#B5301F")); m.set_shader_parameter("modo", 0); m.set_shader_parameter("progresso", 0.45 + 0.08 * i); m.set_shader_parameter("semente", float(i) * 3.7)
	mi.material_override = m
	var d := Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))
	mi.global_transform = Transform3D(Basis(Vector3.UP, p.rotation.y), p.position + d * 2.0 + Vector3(0, 0.035, 0))
	add_child(mi)

func _anel_jog(b, c: Color, i: int) -> void:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(1.9, 1.9)
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/anel_jog.gdshader")
	m.set_shader_parameter("cor", c); m.set_shader_parameter("simbolo", i)
	mi.material_override = m
	mi.position = b.position + Vector3(0, 0.05, 0)
	mi.rotation.y = deg_to_rad(-YAW)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if i == 0 or i == 2:
		return   # Porta na água e Sapador no barro escuro: sem disco (o disco escuro come o contraste deles)
	var sd := MeshInstance3D.new(); var sq := PlaneMesh.new(); sq.size = Vector2(1.5, 1.3); sd.mesh = sq
	var smat := ShaderMaterial.new(); smat.shader = load("res://shaders/aquatinta.gdshader")
	smat.set_shader_parameter("modo", 3); smat.set_shader_parameter("cor", Color("#231C17")); smat.set_shader_parameter("cor2", Color("#231C17")); smat.set_shader_parameter("dens", 0.8)
	sd.material_override = smat; sd.position = b.position + Vector3(0.12, 0.04, -0.1); sd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sd)

func _onda(c: Vector3, r: float, k: float) -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(2, 2); mi.mesh = pm
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/onda.gdshader")
	m.set_shader_parameter("cor", Color("#E9DFC9")); m.set_shader_parameter("aneis", 3); m.set_shader_parameter("largura", 0.05); m.set_shader_parameter("k", k)
	mi.material_override = m
	mi.global_transform = Transform3D(Basis().scaled(Vector3(r, 1, r)), c)
	add_child(mi)

func _queimado(c: Vector3) -> void:
	var mi := MeshInstance3D.new(); var qq := PlaneMesh.new(); qq.size = Vector2(2.2, 2.2); mi.mesh = qq
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/aquatinta.gdshader")
	m.set_shader_parameter("modo", 4); m.set_shader_parameter("cor", Color("#231C17")); m.set_shader_parameter("cor2", Color("#231C17")); m.set_shader_parameter("dens", 1.0)
	mi.material_override = m; mi.position = c; add_child(mi)

func _breu(p: Vector3) -> void:
	# poça de breu (tinta com borda sombra), barril do Sapador tombado vazando, línguas de fogo, brasas e fumaça
	var mi := MeshInstance3D.new(); var q := PlaneMesh.new(); q.size = Vector2(3.0, 2.4); mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/aquatinta.gdshader")
	m.set_shader_parameter("modo", 0); m.set_shader_parameter("cor", Color("#231C17")); m.set_shader_parameter("cor2", Color("#6E4A33"))
	m.set_shader_parameter("dens", 1.1); m.set_shader_parameter("escala", 1.3); m.set_shader_parameter("borda", 2.5); m.set_shader_parameter("deriva", Vector2.ZERO)
	mi.material_override = m; mi.position = p + Vector3(0, 0.04, 0); add_child(mi)
	var bar := Node3D.new(); bar.position = p + Vector3(1.2, 0.2, 0.7); bar.rotation_degrees = Vector3(0, 30, 90); add_child(bar)
	var mad: ShaderMaterial = mundo.mat_mundo("#A8834F", 1.0, 0.0, 0.3, 0.2)
	mundo.cilindro(bar, 0.2, 0.2, 0.5, Vector3.ZERO, mad, Vector3.ZERO, 12, 1.5)
	for y in [-0.18, 0.18]:
		mundo.cilindro(bar, 0.215, 0.215, 0.05, Vector3(0, y, 0), mundo.mat_mundo("", 0.0, 0.0, 3.0, 0.1), Vector3.ZERO, 12, 0.0)
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for k in 10:
		var f := MeshInstance3D.new(); var qd := QuadMesh.new(); qd.size = Vector2(1, 1); qd.center_offset = Vector3(0, 0.5, 0); f.mesh = qd
		var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/fogo.gdshader")
		fm.set_shader_parameter("cor", Color("#E2672B")); fm.set_shader_parameter("miolo", Color("#F2E6C2")); fm.set_shader_parameter("vida", 1.0)
		f.material_override = fm
		var a := rng.randf() * TAU; var rd := sqrt(rng.randf()) * 1.15
		f.position = p + Vector3(cos(a) * rd, 0.0, sin(a) * rd * 0.8)
		var hh := rng.randf_range(0.6, 1.4) * (1.3 - rd * 0.4)
		f.scale = Vector3(hh * 0.8, hh, 1.0)
		add_child(f)
	var br = mundo._mm_part(40, 3)
	br.material_override.set_shader_parameter("caixa", Vector3(2.6, 4.0, 2.2))
	br.material_override.set_shader_parameter("origem", p)
	br.material_override.set_shader_parameter("brasa", Color("#E2672B"))
	var fu := MeshInstance3D.new(); var fq := QuadMesh.new(); fq.size = Vector2(2.4, 6.0); fu.mesh = fq
	var fum := ShaderMaterial.new(); fum.shader = load("res://shaders/aquatinta.gdshader")
	fum.set_shader_parameter("modo", 1); fum.set_shader_parameter("cor", Color("#231C17")); fum.set_shader_parameter("cor2", Color("#6E4A33")); fum.set_shader_parameter("dens", 0.7); fum.set_shader_parameter("curvar", 0.0)
	fu.material_override = fum; fu.position = p + Vector3(0.6, 3.6, -0.4)
	add_child(fu)
	fu.look_at(main.cam.global_position, Vector3.UP); fu.rotate_object_local(Vector3.UP, PI)

# raio: deslocamento de ponto médio com galhos que afinam (mesmo desenho da cena do vau)
func h(n: float) -> float:
	var x := sin(n * 12.9898) * 43758.5453
	return x - floor(x)

func _md(a: Vector3, b: Vector3, desv: float, n: int, sd: float, out: Array) -> void:
	if n == 0:
		out.append(b)
		return
	var mm := (a + b) * 0.5
	var L := a.distance_to(b)
	var d := (b - a).normalized()
	var s1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var s2 := d.cross(s1).normalized()
	mm += (s1 * (h(sd) - 0.5) + s2 * (h(sd + 1.7) - 0.5) * 0.6) * L * desv
	_md(a, mm, desv, n - 1, sd * 1.37 + 3.1, out)
	_md(mm, b, desv, n - 1, sd * 1.91 + 7.3, out)

func _raio(p: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new(); mi.mesh = im
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/fx.gdshader")
	m.set_shader_parameter("modo", 3); m.set_shader_parameter("cor", Color("#F4F1E8")); m.set_shader_parameter("cor_borda", Color("#7FA3E0")); m.set_shader_parameter("cor_halo", Color("#231C17")); m.set_shader_parameter("curvar", 0.0)
	mi.material_override = m
	add_child(mi)
	var top := p + Vector3(-4.0, 24.0, -7.0)
	var pts: Array = [top]
	_md(top, p, 0.55, 5, 23.0, pts)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_fita(im, pts, 0.3, 0.16)
	for b in 5:
		var i0 := 4 + b * 5
		if i0 >= pts.size() - 2: break
		var a: Vector3 = pts[i0]
		var dirb: Vector3 = (pts[i0 + 1] - a).normalized() + Vector3((h(23.0 + b) - 0.5) * 1.6, -0.2, (h(46.0 + b) - 0.5) * 1.2)
		var fim: Vector3 = a + dirb.normalized() * (3.0 + h(23.0 + b * 3.0) * 4.0) * (1.0 - float(i0) / pts.size())
		var br: Array = [a]
		_md(a, fim, 0.5, 3, 23.0 + b * 13.0, br)
		_fita(im, br, 0.15, 0.0)
	im.surface_end()

func _fita(im: ImmediateMesh, pts: Array, w0: float, w1: float) -> void:
	var cam: Camera3D = main.cam
	var n := pts.size()
	for i in n - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var d := (b - a).normalized()
		var vd := (cam.global_position - a).normalized()
		var s := d.cross(vd).normalized() * lerpf(w0, w1, float(i) / (n - 1)) * 0.5
		var s2 := d.cross(vd).normalized() * lerpf(w0, w1, float(i + 1) / (n - 1)) * 0.5
		for q in [[a - s, 0.0], [a + s, 1.0], [b + s2, 1.0], [a - s, 0.0], [b + s2, 1.0], [b - s2, 0.0]]:
			im.surface_set_uv(Vector2(q[1], 0)); im.surface_add_vertex(q[0])

func passo(t: float, f: int) -> void:
	main.gset("tempo", 2.1)
