extends Node3D
# "O Vau da Tempestade" (v2): mundo aberto em profundidade, câmera de 22°, FOV 42°, 15 m, curvatura leve (0,004)
# e yaw de 28° (o rio corre na diagonal e leva o olho ao forte em ruína e ao moinho queimado).
# Linha do tempo global (g, 60 fps), 17 s:
#   g 0-150   chegada: os 4 heróis correm pela estrada do sul até o vau; a câmera desce da altura de exploração
#   g 150-     cena de combate (f = g - 150, com hit-stop global de 4, 3 e 3 quadros nos contatos):
#     f 0   Sineira arremessa a Unção (solta no 9)          f 14  Sapador joga o Pote de Breu na margem norte (cai no 48)
#     f 27  pote quebra no ombro do Porta-Estandarte: contorno de cera (isolado)
#     f 50  Investida (CONTATO no 63: hit-stop global e tremor)     f 98  Fincar (crava no 138)
#     f 142 telegrafia do raio: círculo vermelhão de 6 m enche como relógio     f 157 Bruxa assina o contrato (aponta)
#     f 190 RAIO (hit-stop): negativo, clarão, sombras duras, 3 anéis de 6 m, vau eletrificado (fios até 5,5 m)
#     f 196 a faísca acha o breu: Incêndio de Breu (reação de dois jogadores)
#     f 205 Carpideira inspira; f 224 Sineira passa o sino no golpe; f 242 Recepção (hit-stop): Dobre Duplo
#     f 280 milícia atravessa; f 316 passe desajeitado de volta; f 332 sino na cabeça dela
#     f 370+ o grupo atravessa o vau e sobe a estrada do norte até a brecha da cerca; a câmera acompanha
const Boneco = preload("res://boneco.gd")
const Mundo = preload("res://mundo.gd")
const Mola = preload("res://mola.gd")
const INTRO := 150
const HOLDS := [[63, 4], [190, 3], [242, 3]]
const YAW0 := 50.0
var main
var mundo
var pc := false
var porta; var sineira; var sapador; var bruxa; var carp
var piq: Array = []; var pen: Array = []; var mil: Array = []; var corpos: Array = []
var mastro: Node3D; var sino: Node3D; var pote: Node3D; var pote_breu: Node3D
var bandeira: MeshInstance3D; var band_mat: ShaderMaterial; var band_im: ArrayMesh
var faixas: Array = []; var circulo: MeshInstance3D; var circ_raio: MeshInstance3D
var raio: MeshInstance3D; var raio_im: ImmediateMesh
var ondas: Array = []        # [{mi, f0, dur, r, cor}]
var faiscas: Array = []; var gotas: Array = []; var manchas: Array = []
var breu: MeshInstance3D; var chamas: Array = []; var brasas: MultiMeshInstance3D; var queimado: MeshInstance3D
var flash: OmniLight3D
var conv_q: MeshInstance3D
var smear: MeshInstance3D; var smear_im: ImmediateMesh; var hist: Array = []
var P0 := Vector3(-1.9, 0, 2.5)
var P1 := Vector3(0.15, 0, -1.55)
var S0 := Vector3(-2.75, 0.02, 3.35)
var S1 := Vector3(-3.55, 0.36, 3.95)
var SP0 := Vector3(2.2, 0, 3.9)
var BR0 := Vector3(-1.1, 0, 4.4)
var BREU := Vector3(3.2, 0, -6.4)
var SAIDA := Vector3(-3.4, 0, -7.6)
var mastro_pos := Vector3.ZERO
var f_off := 0
var cam_yaw := YAW0
var sol0 := Vector3(0.7, 0.48, 0.55)
var ultimo_f := -999
var cdx := 0.6
var cdz := 0.4
# pano da bandeira (verlet)
const BNX := 11
const BNY := 7
const BW := 0.66
const BH := 0.44
var pano_p := PackedVector3Array(); var pano_o := PackedVector3Array()

func lin(h: String) -> Color:
	return Color(h)   # uniforms vec3 com source_color (o motor converte)

func yaw_para(d: Vector3) -> float:
	return atan2(d.x, d.z)

func bon(n: String, p: Vector3, yaw_deg: float, px := 1.5):
	var b = Boneco.new()
	add_child(b)
	b.setup(n, px)
	b.position = p
	b.rotation.y = deg_to_rad(yaw_deg)
	b.springs_default()
	return b

func alt(p: Vector3) -> Vector3:
	return Vector3(p.x, mundo.altura(p.x, p.z), p.z)

func setup(m) -> void:
	main = m
	pc = main.pc
	f_off = int(main.A("f0", "0"))
	cdx = main.F("cdx", 0.6); cdz = main.F("cdz", 0.4)
	var e: Environment = main.env
	main.gset("curva_k", main.F("curva", 0.008))
	main.gset("curva_r0", main.F("curva_r0", 8.0))
	main.gset("escuro_base", main.F("eb", 1.0))
	main.gset("escuro_faixa", main.F("ef", 2.5))
	main.gset("escuro_mundo", main.F("em", 2.8))
	main.gset("frente_x", Vector2(main.F("fx0", -6.0), main.F("fx1", 14.0)))
	main.gset("nevoa", Vector4(main.F("n0", 24.0), main.F("n1", 70.0), main.F("nmax", 0.92), 0.25))
	main.gset("nevoa_alt", Vector4(main.F("na0", 0.2), main.F("na1", -3.5), main.F("na2", 21.0), main.F("namax", 0.8)))
	main.gset("vento", Vector2(1.0, 0.25))
	main.gset("papel_frio", Color("#8E97A3").srgb_to_linear())
	main.gset("papel_quente", Color("#E3C99A").srgb_to_linear())
	main.sol(sol0)
	main.sun.light_energy = 1.0
	if pc:
		main.sun.shadow_enabled = true
		main.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		main.sun.directional_shadow_max_distance = 45.0
		main.sun.light_angular_distance = 1.2
		main.sun.shadow_blur = 1.5
	var cam: Camera3D = main.cam
	cam.fov = main.F("fov", 42.0)
	cam.near = 0.3
	cam.far = 4000.0
	_cam_em(alvo_de(0), 22.0, 15.0, YAW0)
	mundo = Mundo.new()
	add_child(mundo)
	mundo.setup(main, pc)
	mundo.terreno()
	if main.A("agua", "1") == "1":
		mundo.agua()
	mundo.trigo(11000 if pc else 4000)
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
	mundo.corvos(mundo.FORTE + Vector3(0, 0, 0), 4, 4.0, 13.0)
	# oclusores de primeiro plano: estacas e cardos nas bordas de baixo, árvore morta no canto de cima à esquerda
	var fw := Vector3(sin(deg_to_rad(YAW0)), 0, -cos(deg_to_rad(YAW0)))
	var rt := Vector3(cos(deg_to_rad(YAW0)), 0, sin(deg_to_rad(YAW0)))
	var c0 := alvo_de(351) - fw * 15.0 * cos(deg_to_rad(22.0))
	mundo.estacas([c0 + fw * 7.2 - rt * 6.6, c0 + fw * 7.6 + rt * 7.4, c0 + fw * 12.0 + rt * 10.5])
	mundo.arvore_perto(c0 + fw * 3.4 - rt * 4.6)
	mundo.ceu(e)
	mundo.ceu_mat.set_shader_parameter("yaw0", deg_to_rad(YAW0))
	print("PROBE hy ", hy_calc(22.0, 15.0))
	mundo.horizonte(cam, main.F("hy", hy_calc(22.0, 15.0)))
	if main.A("nevoa", "1") == "1":
		mundo.nevoa(4 if pc else 2)
	if main.A("part", "1") == "1":
		mundo.particulas(1700 if pc else 480, 300 if pc else 120)
	_ambiente(e)
	_elenco()
	_efeitos()
	main.pos_mat.set_shader_parameter("vinheta", main.F("vinheta", 0.85))
	main.pos_mat.set_shader_parameter("manchas", main.F("manchas", 1.0))

func hy_calc(pitch: float, d: float) -> float:
	# fração da tela (de cima) onde cai o horizonte do mundo curvo, para assentar os cartões de colina
	var p := deg_to_rad(pitch)
	var k := float(main.F("curva", 0.008)); var r0 := float(main.F("curva_r0", 8.0))
	var best := 9.0
	for i in 400:
		var dd := i * 0.25
		var drop := k * pow(maxf(dd - r0, 0.0), 2.0)
		best = minf(best, atan2(d * sin(p) - 1.8 * smoothstep(8.0, 30.0, dd) + drop, dd + d * cos(p)))
	return 0.5 + 0.5 * tan(best - p) / tan(deg_to_rad(main.cam.fov * 0.5))

func _cam_em(foco: Vector3, pitch: float, d: float, yaw: float) -> void:
	var cam: Camera3D = main.cam
	var pit := deg_to_rad(pitch)
	var fw := Vector3(sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
	cam.global_position = foco - fw * d * cos(pit) + Vector3(0, d * sin(pit), 0)
	cam.look_at(foco + Vector3(0, 0.0, 0), Vector3.UP)
	main.gset("foco", foco)
	main.gset("curva_dir", Vector2(fw.x, fw.z))

func _ambiente(e: Environment) -> void:
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if pc:
		e.glow_enabled = true
		e.glow_intensity = 0.55
		e.glow_strength = 0.9
		e.glow_bloom = 0.0
		e.glow_hdr_threshold = 1.05
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		e.volumetric_fog_enabled = main.A("vol", "1") == "1"
		e.volumetric_fog_density = 0.005
		e.volumetric_fog_albedo = Color("#E3C99A")
		e.volumetric_fog_emission = Color(0, 0, 0)
		e.volumetric_fog_length = 64.0
		e.volumetric_fog_detail_spread = 1.5
		e.volumetric_fog_gi_inject = 0.0
		e.volumetric_fog_ambient_inject = 0.0
		e.volumetric_fog_anisotropy = 0.6
		main.sun.light_volumetric_fog_energy = 1.6
		# névoa de altura em volumes (vale do forte, rio, várzea ao longe), cada vez mais densa com a distância
		for fv in [[Vector3(4, 0.4, -4), Vector3(70, 1.2, 14), 0.02], [Vector3(10, 0.8, -15), Vector3(90, 2.4, 12), 0.03],
				[Vector3(14, 1.2, -28), Vector3(140, 4.0, 18), 0.05], [Vector3(14, 2.0, -52), Vector3(220, 7.0, 34), 0.08]]:
			var v := FogVolume.new()
			v.size = fv[1]
			v.position = fv[0]
			var fm := FogMaterial.new()
			fm.density = fv[2]
			fm.albedo = Color("#E9DFC9")
			fm.height_falloff = 0.8
			fm.edge_fade = 0.7
			v.material = fm
			add_child(v)
		# feixes de sol (luz de verdade na névoa volumétrica) saindo do rasgo âmbar sobre o forte
		for k in 2:
			var sp := SpotLight3D.new()
			sp.position = Vector3(40 + k * 8, 22, -40 + k * 6)
			add_child(sp)
			sp.look_at(Vector3(6 - k * 6, 0, -12 + k * 4), Vector3.UP)
			sp.spot_angle = 6.0 + k * 2.0
			sp.spot_range = 90.0
			sp.light_energy = 0.0
			sp.light_volumetric_fog_energy = 12.0
			sp.light_color = Color("#E3C99A")
			sp.light_cull_mask = 0
		flash = OmniLight3D.new()
		flash.omni_range = 18.0
		flash.light_energy = 0.0
		flash.light_volumetric_fog_energy = 6.0
		flash.light_color = Color("#F4F1E8")
		flash.light_cull_mask = 0
		add_child(flash)
	# feixes em cartão (Web e PC): lâminas de aquatinta âmbar caindo do rasgo do céu
	for k in 3:
		var fx := MeshInstance3D.new()
		var qm := QuadMesh.new(); qm.size = Vector2(3.0 + k, 34.0)
		fx.mesh = qm
		fx.position = Vector3(12 + k * 5.0, 8.0, -20 - k * 4.0)
		fx.rotation_degrees = Vector3(-50, -20, 40)
		var fm2 := ShaderMaterial.new(); fm2.shader = load("res://shaders/aquatinta.gdshader")
		fm2.set_shader_parameter("modo", 2); fm2.set_shader_parameter("cor", lin("#E9DFC9")); fm2.set_shader_parameter("cor2", lin("#E3C99A"))
		fm2.set_shader_parameter("dens", 0.34 - k * 0.06); fm2.set_shader_parameter("curvar", 0.0); fm2.set_shader_parameter("fase", k * 2.0)
		fx.material_override = fm2
		fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fx)

func _elenco() -> void:
	porta = bon("porta", P0, rad_to_deg(yaw_para(P1 - P0)), 2.0)
	var eq: Dictionary = main.equipa(porta)
	mastro = eq["mastro"]
	sineira = bon("sineira", S0, 125.0, 2.0)
	sino = main.equipa(sineira)["sino"]
	sapador = bon("sapador", SP0, 200.0, 2.0)
	bruxa = bon("bruxa", BR0, 190.0, 2.0)
	_bandeira()
	pote = main.prop("pote"); pote.visible = false
	pote_breu = main.prop("pote"); pote_breu.visible = false; pote_breu.scale = Vector3.ONE * 1.4
	# formação de 6 Piqueiros virada para o sul, 14 Penitentes atrás, a Carpideira no plano médio
	for i in 6:
		var p = bon("piqueiro", Vector3(-2.6 + i * 1.08, 0, -2.85 + 0.12 * sin(i * 2.0)), 4.0 * sin(i * 3.1))
		p.pose("idle", 0.0)
		piq.append(p)
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for i in 14:
		var x := -3.6 + (i % 5) * 1.6 + rng.randf_range(-0.4, 0.4)
		var z := -4.2 - (i / 5) * 1.05 + rng.randf_range(-0.3, 0.3)
		var p = bon("penitente", Vector3(x, 0, z), rng.randf_range(-25, 25))
		p.set_meta("fase", rng.randf())
		pen.append(p)
	carp = bon("carpideira", alt(Vector3(1.6, 0, -7.4)), -12.0)
	# milícia de 8 com chapéu de piqueiro na margem sul, 3 com tochas
	for i in 8:
		var x := 1.6 + (i % 4) * 1.05 + (0.5 if i >= 4 else 0.0)
		var z := 5.0 + (i / 4) * 0.95
		var mm = bon("miliciano", alt(Vector3(x, 0, z)), 180.0 + rng.randf_range(-20, 20))
		if i in [1, 4, 6]:
			var t = main.prop("tocha"); mm.anexar(t, "hand.R", Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.05, 0)).translated_local(Vector3(0, -0.12, 0)))
			mm.set_meta("tocha", t)
		else:
			main.equipa(mm)
		mm.set_meta("fase", rng.randf())
		mm.set_meta("vel", rng.randf_range(0.92, 1.08))
		mm.set_meta("p0", mm.position)
		mil.append(mm)
	# mortos de batalhas antigas, meio afundados no rio (sem olho aceso)
	for c in [[Vector3(5.6, -0.3, -1.4), 80.0, 30.0], [Vector3(-6.4, -0.28, -3.2), -75.0, 110.0], [Vector3(8.6, -0.35, -4.6), 95.0, -40.0], [Vector3(-9.4, -0.3, -0.9), -80.0, 200.0], [Vector3(2.6, -0.3, -9.2), 70.0, 10.0]]:
		var b = Boneco.new(); add_child(b); b.setup("penitente" if corpos.size() % 2 == 0 else "piqueiro", 1.5)
		b.position = c[0]; b.rotation_degrees = Vector3(c[1], c[2], 0)
		b.pose("idle", 0.3)
		b.param(["verde"], "aceso", 0.0)
		corpos.append(b)

func _bandeira() -> void:
	band_im = ArrayMesh.new()
	bandeira = MeshInstance3D.new()
	bandeira.mesh = band_im
	band_mat = ShaderMaterial.new()
	band_mat.shader = load("res://shaders/bandeira.gdshader")
	band_mat.set_shader_parameter("cor", lin("#D9472B"))
	band_mat.set_shader_parameter("ondas", 0.0)
	band_mat.set_shader_parameter("abre", 1.0)
	bandeira.material_override = band_mat
	bandeira.extra_cull_margin = 4.0
	add_child(bandeira)
	pano_p.resize(BNX * BNY); pano_o.resize(BNX * BNY)

func _onda(cor: String, aneis: int, larg: float) -> Dictionary:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/onda.gdshader")
	m.set_shader_parameter("cor", lin(cor)); m.set_shader_parameter("aneis", aneis); m.set_shader_parameter("largura", larg)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return {"mi": mi, "m": m}

func _efeitos() -> void:
	var pm := load("res://shaders/perigo.gdshader")
	for i in 6:
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new(); q.size = Vector2(0.8, 3.6)
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = pm
		m.set_shader_parameter("verde", lin("#B5301F"))
		m.set_shader_parameter("modo", 0); m.set_shader_parameter("semente", float(i) * 3.7)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		faixas.append(mi)
	circulo = _circulo(8.0, pm)
	circ_raio = _circulo(12.0, pm)
	raio_im = ImmediateMesh.new()
	raio = MeshInstance3D.new(); raio.mesh = raio_im
	var rm := ShaderMaterial.new(); rm.shader = load("res://shaders/fx.gdshader")
	rm.set_shader_parameter("modo", 3); rm.set_shader_parameter("cor", lin("#F4F1E8")); rm.set_shader_parameter("cor_borda", lin("#7FA3E0")); rm.set_shader_parameter("cor_halo", lin("#231C17"))
	rm.set_shader_parameter("brilho", 2.2 if pc else 1.0); rm.set_shader_parameter("curvar", 0.0)
	raio.material_override = rm
	raio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(raio)
	conv_q = MeshInstance3D.new()
	var cqm := QuadMesh.new(); cqm.size = Vector2(7.0, 7.0)
	conv_q.mesh = cqm
	var cvm := ShaderMaterial.new(); cvm.shader = load("res://shaders/convergencia.gdshader")
	conv_q.material_override = cvm
	conv_q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	conv_q.visible = false
	add_child(conv_q)
	smear_im = ImmediateMesh.new()
	smear = MeshInstance3D.new(); smear.mesh = smear_im
	var smm := ShaderMaterial.new(); smm.shader = load("res://shaders/fx.gdshader")
	smm.set_shader_parameter("modo", 1); smm.set_shader_parameter("curvar", 0.0)
	smear.material_override = smm
	smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smear)
	# ondas de impacto: investida (2,2 m), raio (6 m), Dobre Duplo (7 m, cera), breu caindo (1,5 m)
	ondas.append(_onda("#E9DFC9", 2, 0.09).merged({"f0": 63, "dur": 24, "r": 2.2}))
	ondas.append(_onda("#E9DFC9", 3, 0.05).merged({"f0": 190, "dur": 24, "r": 6.0}))
	ondas.append(_onda("#F2E6C2", 3, 0.045).merged({"f0": 250, "dur": 30, "r": 7.0}))
	ondas.append(_onda("#231C17", 2, 0.12).merged({"f0": 48, "dur": 20, "r": 1.6}))
	for i in 14:
		var s := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.08; sm.radial_segments = 6; sm.rings = 3
		s.mesh = sm
		var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/fx.gdshader"); fm.set_shader_parameter("cor", lin("#F4F1E8")); fm.set_shader_parameter("brilho", 2.0 if pc else 1.0)
		s.material_override = fm; s.visible = false; add_child(s); faiscas.append(s)
	for i in 14:
		var s := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.07; sm.radial_segments = 6; sm.rings = 3
		s.mesh = sm
		var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/fx.gdshader"); fm.set_shader_parameter("cor", lin("#F2E6C2"))
		s.material_override = fm; s.visible = false; add_child(s); gotas.append(s)
	# breu do Sapador (poça de tinta), línguas de fogo, brasas, marca de queimado do raio
	breu = MeshInstance3D.new(); var bq := PlaneMesh.new(); bq.size = Vector2(3.4, 2.8); breu.mesh = bq
	var bm := ShaderMaterial.new(); bm.shader = load("res://shaders/aquatinta.gdshader")
	bm.set_shader_parameter("modo", 0); bm.set_shader_parameter("cor", lin("#231C17")); bm.set_shader_parameter("cor2", lin("#6E4A33"))
	bm.set_shader_parameter("dens", 0.0); bm.set_shader_parameter("escala", 1.3); bm.set_shader_parameter("borda", 2.5); bm.set_shader_parameter("deriva", Vector2.ZERO)
	breu.material_override = bm; breu.position = alt(BREU) + Vector3(0, 0.04, 0); breu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(breu)
	var rr := RandomNumberGenerator.new(); rr.seed = 9
	for k in 11:
		var f := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1, 1); q.center_offset = Vector3(0, 0.5, 0); f.mesh = q
		var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/fogo.gdshader")
		fm.set_shader_parameter("cor", lin("#E2672B")); fm.set_shader_parameter("miolo", lin("#F2E6C2")); fm.set_shader_parameter("brilho", 1.3 if pc else 1.0)
		f.material_override = fm
		var a := rr.randf() * TAU; var rd := sqrt(rr.randf()) * 1.25
		f.position = alt(BREU) + Vector3(cos(a) * rd, 0.0, sin(a) * rd * 0.8)
		var hh := rr.randf_range(0.6, 1.4) * (1.3 - rd * 0.4)
		f.scale = Vector3(hh * 0.8, hh, 1.0)
		f.set_meta("h", hh); f.set_meta("d", rd)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		add_child(f); chamas.append(f)
	brasas = mundo._mm_part(90 if pc else 40, 3)
	brasas.material_override.set_shader_parameter("caixa", Vector3(2.6, 4.0, 2.2))
	brasas.material_override.set_shader_parameter("origem", alt(BREU))
	brasas.material_override.set_shader_parameter("brasa", lin("#E2672B"))
	brasas.visible = false
	queimado = MeshInstance3D.new(); var qq := PlaneMesh.new(); qq.size = Vector2(2.2, 2.2); queimado.mesh = qq
	var qmm := ShaderMaterial.new(); qmm.shader = load("res://shaders/aquatinta.gdshader")
	qmm.set_shader_parameter("modo", 4); qmm.set_shader_parameter("cor", lin("#231C17")); qmm.set_shader_parameter("cor2", lin("#231C17")); qmm.set_shader_parameter("dens", 1.0)
	queimado.material_override = qmm; queimado.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; queimado.visible = false
	add_child(queimado)

func _circulo(tam: float, pm: Shader) -> MeshInstance3D:
	var c := MeshInstance3D.new()
	var cq := PlaneMesh.new(); cq.size = Vector2(tam, tam)
	c.mesh = cq
	var cmat := ShaderMaterial.new(); cmat.shader = pm
	cmat.set_shader_parameter("verde", lin("#B5301F")); cmat.set_shader_parameter("modo", 1); cmat.set_shader_parameter("aceso", 0.0)
	c.material_override = cmat
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(c)
	return c

# ------------------------------------------------------------------ tempo: g global -> f da cena (hit-stop global)
func g_para_f(g: int) -> Array:
	var x := g - INTRO
	if x < 0:
		return [x, false]
	for hd in HOLDS:
		var hf: int = hd[0]; var n: int = hd[1]
		if x <= hf:
			return [x, false]
		if x <= hf + n:
			return [hf, true]
		x -= n
	return [x, false]

func h(n: float) -> float:
	return fract_(sin(n * 12.9898) * 43758.5453)

func fract_(x: float) -> float:
	return x - floor(x)

func sm(a: float, b: float, x: float) -> float:
	return clampf((x - a) / (b - a), 0.0, 1.0)

func ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func ciclo(b, anim: String, t: float, vel := 1.0) -> void:
	var d: float = b.dur(anim)
	b.pose(anim, fmod(t * vel, maxf(d - 1.0 / 60.0, 0.05)))

# caminho de corrida: lista de pontos, partida em f0, velocidade v (m/quadro). Devolve [pos, dir, correndo]
func caminho(pts: Array, f0: float, v: float, f: float) -> Array:
	var dist := maxf(f - f0, 0.0) * v
	var p: Vector3 = pts[0]
	var dir: Vector3 = (pts[1] - pts[0]).normalized() if pts.size() > 1 else Vector3.FORWARD
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var L := a.distance_to(b)
		dir = (b - a).normalized()
		if dist <= L:
			return [a + dir * dist, dir, f > f0]
		dist -= L
		p = b
	return [p, dir, false]

# posições dos heróis por quadro (funções puras: a câmera é simulada a partir delas)
func pos_porta(f: float) -> Array:
	var fwd := (P1 - P0).normalized()
	if f < 0:
		return caminho([Vector3(-1.9, 0, 13.4), Vector3(-1.2, 0, 7.5), P0], -150.0, 0.0745, f)
	if f < 50:
		return [P0.lerp(P1, f / 52.0), fwd, true]
	if f < 380:
		return [P1 + fwd * 0.65 if f >= 98 else P1, fwd, false]
	return caminho([P1 + fwd * 0.65, Vector3(-1.6, 0, -5.4), SAIDA, Vector3(-3.2, 0, -10.4), Vector3(-2.6, 0, -12.2)], 380.0, 0.056, f)

func pos_sineira(f: float) -> Array:
	if f < 0:
		return caminho([Vector3(-2.6, 0, 13.0), Vector3(-2.2, 0, 7.0), S0], -150.0, 0.072, f)
	if f < 400:
		var k := sm(36, 92, f)
		return [S0.lerp(S1, k), Vector3(0, 0, -1), false]
	return caminho([S1, Vector3(-2.6, 0, 1.2), Vector3(-3.0, 0, -3.0), SAIDA, Vector3(-4.2, 0, -10.2)], 400.0, 0.05, f)

func pos_sapador(f: float) -> Array:
	if f < 0:
		return caminho([Vector3(0.6, 0, 14.2), Vector3(1.4, 0, 8.0), SP0], -150.0, 0.08, f)
	if f < 392:
		return [SP0, Vector3(0, 0, -1), false]
	return caminho([SP0, Vector3(0.6, 0, 1.0), Vector3(-1.0, 0, -4.4), SAIDA, Vector3(-2.0, 0, -9.8)], 392.0, 0.062, f)

func pos_bruxa(f: float) -> Array:
	if f < 0:
		return caminho([Vector3(-1.6, 0, 15.4), Vector3(-0.9, 0, 9.0), BR0], -150.0, 0.078, f)
	if f < 372:
		return [BR0, Vector3(0, 0, -1), false]
	return caminho([BR0, Vector3(-1.6, 0, 1.0), Vector3(-2.4, 0, -3.6), SAIDA, Vector3(-4.6, 0, -11.6)], 372.0, 0.052, f)

func alvo_de(g: int) -> Vector3:
	var f: float = g_para_f(g)[0]
	var pp: Vector3 = pos_porta(f)[0]; var ss: Vector3 = pos_sineira(f)[0]
	var sp: Vector3 = pos_sapador(f)[0]; var bb: Vector3 = pos_bruxa(f)[0]
	var a: Vector3
	if f < 360:
		a = pp * 0.6 + ss * 0.15 + sp * 0.1 + bb * 0.15
		if f > 140 and f < 360:
			var fwd := (P1 - P0).normalized()
			a = a.lerp((P1 + fwd * 1.05) * 0.7 + ss * 0.3, 0.3)
	else:
		a = (pp + ss + sp + bb) * 0.25
	a += Vector3(cdx, 0, cdz)
	a.y = mundo.altura(a.x, a.z) * 0.7 if mundo else 0.0
	return a

func cam_params(g: int) -> Array:
	# [pitch, dist, yaw]: desce da exploração (30°, 24 m) para o combate (22°, 15 m); no fim recua e gira um pouco
	var k := ease_io(sm(0, 170, g))
	var pitch := lerpf(30.0, 22.0, k)
	var d := lerpf(24.0, 15.0, k)
	var yaw := lerpf(62.0, YAW0, k)
	var f: float = g_para_f(g)[0]
	var k2 := ease_io(sm(380, 700, f))
	pitch = lerpf(pitch, 21.0, k2); d = lerpf(d, 16.5, k2); yaw = lerpf(yaw, 54.0, k2)
	return [pitch, d, yaw]

# ------------------------------------------------------------------ pano da bandeira (verlet)
func _pinos() -> Array:
	var out := []
	var xf := mastro.global_transform
	for j in BNY:
		out.append(xf * Vector3(-0.02, 1.38 - j * BH / (BNY - 1), 0))
	return out

func _pano_passo(f: int, abre: float) -> void:
	var pins := _pinos()
	var dx := BW / (BNX - 1); var dy := BH / (BNY - 1)
	var vt := Vector3(1.0, 0, 0.25).normalized()
	if f != ultimo_f + 1 or pano_p[0] == Vector3.ZERO:
		var base: Vector3 = pins[0]
		for j in BNY:
			for i in BNX:
				pano_p[j * BNX + i] = pins[j] + vt * i * dx
				pano_o[j * BNX + i] = pano_p[j * BNX + i]
		for k in 80:
			_pano_integra(pins, dx, dy, f - 80 + k, abre)
	_pano_integra(pins, dx, dy, f, abre)
	ultimo_f = f
	# malha
	var vs := PackedVector3Array(); var uvs := PackedVector2Array(); var ns := PackedVector3Array(); var idx := PackedInt32Array()
	for j in BNY:
		for i in BNX:
			vs.append(pano_p[j * BNX + i]); uvs.append(Vector2(float(i) / (BNX - 1), float(j) / (BNY - 1)))
	for j in BNY:
		for i in BNX:
			var a := pano_p[j * BNX + mini(i + 1, BNX - 1)] - pano_p[j * BNX + maxi(i - 1, 0)]
			var b := pano_p[mini(j + 1, BNY - 1) * BNX + i] - pano_p[maxi(j - 1, 0) * BNX + i]
			ns.append(a.cross(b).normalized())
	for j in BNY - 1:
		for i in BNX - 1:
			var q := j * BNX + i
			idx.append_array([q, q + 1, q + BNX, q + 1, q + BNX + 1, q + BNX])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_INDEX] = idx
	band_im.clear_surfaces()
	band_im.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

func _pano_integra(pins: Array, dx: float, dy: float, f: int, abre: float) -> void:
	var dt := 1.0 / 60.0
	var raj := 1.0 + 0.5 * sin(f * 0.13) + 0.3 * sin(f * 0.41 + 1.0)
	var vento := Vector3(1.0, 0.05, 0.25).normalized() * 7.0 * raj * abre
	for j in BNY:
		for i in BNX:
			var k := j * BNX + i
			if i == 0:
				continue
			var p := pano_p[k]
			var v := (p - pano_o[k]) * 0.96
			var flap := Vector3(0, sin(f * 0.37 + i * 0.9 + j * 0.4) * 2.5, cos(f * 0.29 + i * 0.7) * 3.5) * abre * float(i) / BNX
			pano_o[k] = p
			pano_p[k] = p + v + (vento + flap + Vector3(0, -9.8 * (1.1 - abre * 0.6), 0)) * dt * dt
	for it in 5:
		for j in BNY:
			pano_p[j * BNX] = pins[j]
			pano_o[j * BNX] = pins[j]
		for j in BNY:
			for i in BNX:
				var k := j * BNX + i
				if i < BNX - 1: _restr(k, k + 1, dx * mix_abre(abre))
				if j < BNY - 1: _restr(k, k + BNX, dy)
				if i < BNX - 1 and j < BNY - 1: _restr(k, k + BNX + 1, sqrt(dx * dx * mix_abre(abre) * mix_abre(abre) + dy * dy))

func mix_abre(a: float) -> float:
	return lerpf(0.35, 1.0, a)

func _restr(a: int, b: int, L: float) -> void:
	var d := pano_p[b] - pano_p[a]
	var l := d.length()
	if l < 1e-5: return
	var c := d * (0.5 * (l - L) / l)
	var fa := 0.0 if a % BNX == 0 else 1.0
	var fb := 0.0 if b % BNX == 0 else 1.0
	var s := fa + fb
	if s <= 0.0: return
	pano_p[a] += c * (2.0 * fa / s)
	pano_p[b] -= c * (2.0 * fb / s)

# ------------------------------------------------------------------ quadro
func passo(_t: float, g0: int) -> void:
	var g := g0 + f_off
	var fz: Array = g_para_f(g)
	var f: int = fz[0]
	var congelado: bool = fz[1]
	# no hit-stop o mundo para (inclusive chuva e névoa); só a câmera treme
	var t := (f + INTRO) / 60.0
	main.gset("tempo", t)
	mundo.passo(t)
	for b in [porta, sineira, sapador, bruxa] + piq + pen + mil + [carp]:
		if b.mola: b.mola.time_scale = 0.0 if congelado else 1.0
	Mola.vento = Vector3(1.0, 0.0, 0.25) * (2.5 + 1.8 * sin(t * 1.7) + 0.8 * sin(t * 4.1))
	var luzes: Array = []
	var fwd := (P1 - P0).normalized()
	# ---------------- Sineira
	var sn: Array = pos_sineira(f)
	if f < 0:
		sineira.position = alt(sn[0]); sineira.rotation.y = yaw_para(sn[1])
		if sn[2]: ciclo(sineira, "recua", f / 60.0, 1.3)
		else: sineira.pose("idle", (f + 20) / 60.0)
	elif f < 36:
		sineira.position = S0
		sineira.rotation.y = deg_to_rad(125.0)
		sineira.pose("arremessa", f / 60.0)
	elif f < 92:
		var k := sm(36, 92, f)
		sineira.position = S0.lerp(S1, k)
		sineira.rotation.y = deg_to_rad(lerpf(125.0, 110.0, k))
		sineira.pose("recua", (f - 36) / 60.0)
	elif f < 150:
		sineira.position = S1; sineira.pose("idle", (f - 92) / 60.0)
		sineira.rotation.y = deg_to_rad(110.0)
	elif f < 212:
		sineira.position = S1; sineira.pose("grita", minf((f - 150) / 60.0, 0.5))
		sineira.rotation.y = deg_to_rad(lerpf(110.0, 40.0, sm(150, 162, f)))
	elif f < 252:
		sineira.position = S1; sineira.rotation.y = deg_to_rad(lerpf(40.0, 140.0, sm(212, 218, f))); sineira.pose("passa", (f - 212) / 60.0)
	elif f < 332:
		sineira.position = S1; sineira.pose("idle", (f - 252) / 60.0)
		sineira.rotation.y = deg_to_rad(lerpf(140.0, 115.0, sm(260, 290, f)))
	elif f < 400:
		sineira.position = S1; sineira.pose("bonk", (f - 332) / 60.0)
	else:
		sineira.position = alt(sn[0]); sineira.rotation.y = yaw_para(sn[1])
		if sn[2]: ciclo(sineira, "recua", (f - 400) / 60.0, 1.2)
		else: sineira.pose("idle", (f - 400) / 60.0)
	# ---------------- Porta-Estandarte
	var pr: Array = pos_porta(f)
	if f < 50:
		porta.position = alt(pr[0]) if f < 0 else pr[0]
		porta.rotation.y = yaw_para(pr[1])
		ciclo(porta, "corre", (f + 150) / 60.0)
	elif f < 98:
		porta.position = P1
		porta.pose("investida", (f - 50) / 60.0)
	elif f < 164:
		porta.position = P1 + fwd * 0.65
		porta.pose("fincar", (f - 98) / 60.0)
	elif f < 233:
		porta.position = P1 + fwd * 0.65
		porta.rotation.y = lerp_angle(yaw_para(fwd), yaw_para(S1 - porta.position), sm(164, 180, f))
		porta.pose("juramento", fmod((f - 164) / 60.0, 0.8))
	elif f < 300:
		porta.position = P1 + fwd * 0.65
		porta.rotation.y = yaw_para(S1 - porta.position) + TAU * ease_io(sm(246, 268, f))
		porta.pose("recepcao", (f - 233) / 60.0)
	elif f < 380:
		porta.position = P1 + fwd * 0.65
		porta.rotation.y = yaw_para(S1 - porta.position)
		porta.pose("passa", (f - 300) / 60.0)
	else:
		porta.position = alt(pr[0]); porta.rotation.y = yaw_para(pr[1])
		if pr[2]: ciclo(porta, "corre", (f - 380) / 60.0, 0.85)
		else: porta.pose("idle", (f - 380) / 60.0)
	var iso := sm(27, 33, f) * (1.0 - sm(300, 330, f) * 0.6)
	porta.param(["contorno"], "isolado", iso)
	porta.param(["grav"], "isolado", iso)
	# ---------------- Sapador: chega, joga o Pote de Breu (14), olha para os lados, atravessa (392)
	var sa: Array = pos_sapador(f)
	sapador.position = alt(sa[0])
	if f < 0:
		sapador.rotation.y = yaw_para(sa[1])
		if sa[2]: ciclo(sapador, "corre", (f + 150) / 60.0)
		else: sapador.pose("olha", (f + 20) / 60.0)
	elif f < 392:
		sapador.rotation.y = yaw_para(BREU - SP0) if f < 60 else lerp_angle(yaw_para(BREU - SP0), yaw_para(P1 - SP0), sm(150, 170, f))
		if f >= 14 and f < 34: sapador.pose("arremessa", (f - 14) / 60.0)
		elif f >= 60 and f < 100: sapador.pose("olha", (f - 60) / 60.0)
		elif f >= 196 and f < 236: sapador.pose("olha", (f - 196) / 60.0)
		else: sapador.pose("idle", f / 60.0)
	else:
		sapador.rotation.y = yaw_para(sa[1])
		if sa[2]: ciclo(sapador, "corre", (f - 392) / 60.0)
		else: sapador.pose("olha", fmod((f - 392) / 60.0, 0.66))
	# pote de breu em voo (21 -> 48)
	if f >= 21 and f < 48:
		pote_breu.visible = true
		var a: Vector3 = sapador.osso_global("hand.L").origin
		var k := (f - 21) / 27.0
		pote_breu.global_position = a.lerp(alt(BREU), k) + Vector3(0, sin(k * PI) * 2.4, 0)
		pote_breu.rotation = Vector3(f * 0.4, f * 0.2, 0)
	else:
		pote_breu.visible = false
	breu.material_override.set_shader_parameter("dens", 1.05 * ease_out(sm(48, 56, f)))
	# ---------------- Bruxa: chega, assina o contrato (aponta para o céu no 157, achata no raio), atravessa (372)
	var br: Array = pos_bruxa(f)
	bruxa.position = alt(br[0])
	if f < 0:
		bruxa.rotation.y = yaw_para(br[1])
		if br[2]: ciclo(bruxa, "corre", (f + 150) / 60.0)
		else: bruxa.pose("idle", (f + 10) / 60.0)
	elif f < 372:
		bruxa.rotation.y = lerp_angle(deg_to_rad(190.0), yaw_para(P1 - BR0) + 0.5, sm(140, 156, f))
		if f >= 157 and f < 227: bruxa.pose("contrato", (f - 157) / 60.0)
		else: bruxa.pose("idle", f / 60.0)
	else:
		bruxa.rotation.y = yaw_para(br[1])
		if br[2]: ciclo(bruxa, "corre", (f - 372) / 60.0)
		else: bruxa.pose("idle", (f - 372) / 60.0)
	# ---------------- pote de cera em voo (9 -> 27)
	if f >= 9 and f < 27:
		pote.visible = true
		var a: Vector3 = sineira.osso_global("hand.L").origin
		var b: Vector3 = porta.osso_global("shoulder.L").origin + Vector3(0, 0.1, 0)
		var k := (f - 9) / 18.0
		pote.global_position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 1.2, 0)
		pote.rotation = Vector3(f * 0.5, f * 0.3, 0)
	else:
		pote.visible = false
	_gotas(f, 27, porta.osso_global("shoulder.L").origin if f >= 27 and f < 60 else Vector3.ZERO)
	# ---------------- mastro: nas costas, nas mãos, fincado
	if f >= 118 and f < 138:
		if mastro.get_parent() != self:
			var gt := mastro.global_transform
			mastro.get_parent().remove_child(mastro); add_child(mastro); mastro.global_transform = gt
		var hand: Vector3 = porta.osso_global("hand.R").origin
		var handl: Vector3 = porta.osso_global("hand.L").origin
		var mid := (hand + handl) * 0.5
		var up := Vector3(0, 1, 0).lerp(-fwd, 0.15).normalized()
		mastro.global_transform = Transform3D(Basis.looking_at(fwd, up), mid - up * 0.45)
		mastro_pos = mid
	elif f >= 138:
		if mastro.get_parent() != self:
			var gt := mastro.global_transform
			mastro.get_parent().remove_child(mastro); add_child(mastro); mastro.global_transform = gt
		var pt := P1 + fwd * 1.05
		var tilt := 0.07 * (1.0 + 0.4 * exp(-(f - 138) / 6.0) * sin((f - 138) * 1.2))
		mastro.global_transform = Transform3D(Basis(fwd.cross(Vector3.UP).normalized(), tilt).rotated(Vector3.UP, yaw_para(fwd)), pt + Vector3(0, -0.12, 0))
		mastro_pos = pt
	var tip: Vector3 = mastro.global_transform * Vector3(0, 1.62, 0)
	if not congelado:
		_pano_passo(f, 0.35 + 0.65 * ease_out(sm(140, 160, f)) if f >= 138 else 0.4)
	# ---------------- Piqueiros (telegrafia vermelhã de 36 quadros)
	for i in piq.size():
		var p = piq[i]
		var cai := (i == 2 or i == 3)
		if f < 6:
			p.pose("idle", (f + 150) / 60.0 + i * 0.3)
		elif f < 63 or not cai:
			if f < 191:
				p.pose("baixa", minf((f - 6) / 60.0, 0.8))
				if f > 70:
					p.rotation.y = lerp_angle(p.rotation.y, yaw_para(P1 + fwd * 0.65 - p.position), 0.08)
			elif f < 215:
				p.pose("choque", fmod((f - 191) / 60.0, 0.2))
			else:
				_achata(p, f - 215)
		else:
			if f < 191:
				p.pose("cai", (f - 63) / 60.0)
				p.position.z = -2.85 - 0.6 * ease_out(sm(63, 80, f))
			elif f < 215:
				p.pose("cai", 0.66)
			else:
				_achata(p, f - 215)
		p.param(["verde"], "aceso", 1.0)
	for i in faixas.size():
		var fx: MeshInstance3D = faixas[i]
		var p = piq[i]
		var dirp := Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))
		fx.global_transform = Transform3D(Basis(Vector3.UP, p.rotation.y), p.position + dirp * 2.0 + Vector3(0, 0.035, 0))
		var on := 1.0 if (f >= 6 and f < 190 and not ((i == 2 or i == 3) and f >= 63)) else 0.0
		fx.material_override.set_shader_parameter("aceso", on)
		fx.material_override.set_shader_parameter("progresso", sm(6, 42, f))
	# ---------------- Penitentes
	for i in pen.size():
		var p = pen[i]
		var ph: float = p.get_meta("fase")
		var dpor: float = p.position.distance_to(P1)
		if f < 191 or dpor > 7.0:
			if f < 120:
				p.pose("anda" if i % 3 != 0 else "gira", fmod((f + 150) / 60.0 + ph, 0.6))
			else:
				p.pose("gira", fmod(f / 60.0 + ph, 0.6))
				p.rotation.y = lerp_angle(p.rotation.y, yaw_para(P1 - p.position), 0.05)
		elif f < 212:
			p.pose("choque", fmod((f - 191) / 60.0 + ph * 0.1, 0.2))
		else:
			_achata(p, f - 212 - int(ph * 6))
		p.param(["verde"], "aceso", 1.0 if p.position.distance_to(porta.position) < 12.0 else 0.25)
	# ---------------- Carpideira: inspira no 205 (48), o Dobre Duplo corta no 256, recua para a névoa
	if f < 205:
		carp.pose("flutua", (f + 150) / 60.0)
	elif f < 256:
		carp.pose("inspira", (f - 205) / 60.0)
	else:
		carp.pose("recua", minf((f - 256) / 60.0, 0.65))
		carp.position = alt(Vector3(1.6, 0, -7.4).lerp(Vector3(4.5, 0, -15.0), ease_io(sm(256, 520, f)))) + Vector3(0, 0.2, 0)
	var cm: ShaderMaterial = circulo.material_override
	circulo.position = carp.position * Vector3(1, 0, 1) + Vector3(-0.7, 0.05, 3.2)
	cm.set_shader_parameter("aceso", 1.0 if (f >= 205 and f < 256) else 0.0)
	cm.set_shader_parameter("progresso", sm(205, 253, f))
	carp.param(["verde"], "aceso", 1.0)
	# ---------------- sino
	if f >= 224 and f < 242:
		_voa(sino, sineira.osso_global("prop").origin, porta.osso_global("hand.R").origin + Vector3(0, 0.25, 0), (f - 224) / 18.0, 2.2, f)
	elif f >= 242 and f < 316:
		if sino.get_parent() != porta.anexos.get("prop"):
			porta.anexar(sino, "prop")
	elif f >= 316 and f < 332:
		_voa(sino, porta.osso_global("prop").origin, sineira.osso_global("head").origin + Vector3(0, 0.45, 0), (f - 316) / 16.0, 1.4, f)
	elif f >= 332:
		if sino.get_parent() != sineira.anexos.get("prop"):
			sineira.anexar(sino, "prop")
	# ---------------- telegrafia do raio: céu converge, faíscas, círculo vermelhão de 6 m que enche como relógio
	var ceu: ShaderMaterial = mundo.ceu_mat
	var cam: Camera3D = main.cam
	var conv := sm(142, 186, f) * (1.0 - sm(192, 200, f))
	ceu.set_shader_parameter("conv_k", conv)
	var dtip := (tip - cam.global_position).normalized()
	ceu.set_shader_parameter("conv", Vector2(atan2(dtip.x, -dtip.z) - deg_to_rad(YAW0), 0.42))
	ceu.set_shader_parameter("tempo", t)
	_faiscas(f, tip)
	conv_q.visible = conv > 0.01
	if conv_q.visible:
		conv_q.global_position = tip + Vector3(0, 0.1, 0)
		conv_q.look_at(cam.global_position, Vector3.UP)
		conv_q.rotate_object_local(Vector3.UP, PI)
		conv_q.material_override.set_shader_parameter("k", conv)
		conv_q.material_override.set_shader_parameter("t", t)
	var crm: ShaderMaterial = circ_raio.material_override
	circ_raio.position = Vector3(mastro_pos.x, 0.06, mastro_pos.z)
	crm.set_shader_parameter("aceso", 1.0 if (f >= 142 and f < 190) else 0.0)
	crm.set_shader_parameter("progresso", sm(142, 189, f))
	# ---------------- RAIO no 190: 2 quadros de negativo, 2 de clarão, sombras duras vindas do raio
	raio.visible = f >= 190 and f < 202
	if raio.visible:
		_desenha_raio(tip, f)
	var gq := g  # contagem global dentro do hit-stop
	var neg := 1.0 if (f == 190 and congelado and gq % 2 == 0) or (f == 190 and not congelado) or f == 250 or f == 251 else 0.0
	main.pos_mat.set_shader_parameter("negativo", neg)
	main.pos_mat.set_shader_parameter("clarao", 0.85 if (f == 191) else (0.45 if f == 192 else 0.0))
	main.pos_mat.set_shader_parameter("reimpressao", 1.0 if (f >= 252 and f < 255) else (0.4 if (f >= 193 and f < 195) else 0.0))
	if pc:
		if f >= 190 and f < 197:
			main.sol((Vector3(-5.0, 26.0, -9.0)).normalized())
			main.sun.light_angular_distance = 0.0; main.sun.shadow_blur = 0.3; main.sun.light_energy = 1.3
		else:
			main.sol(sol0)
			main.sun.light_angular_distance = 1.2; main.sun.shadow_blur = 1.5; main.sun.light_energy = 1.0
	var wm: ShaderMaterial = mundo.agua_mat
	var el := (1.0 if (f >= 190 and f < 250) else 0.0) * (1.0 - sm(236, 250, f))
	wm.set_shader_parameter("elet", Vector4(mastro_pos.x, mastro_pos.z, 5.5, el))
	queimado.visible = f >= 190
	queimado.position = Vector3(mastro_pos.x + 0.1, 0.05, mastro_pos.z + 0.05)
	porta.todos("clarao", 0.0)
	for p in piq + pen:
		p.todos("clarao", 1.0 if (f >= 190 and f < 194) else 0.0)
	if flash:
		flash.global_position = tip + Vector3(0, 1.0, 0)
		flash.light_volumetric_fog_energy = 14.0 * exp(-maxf(f - 190, 0) / 5.0) if f >= 190 else 0.0
	if f >= 190 and f < 214:
		luzes.append({"p": tip - Vector3(0, 0.8, 0), "r": 9.0 * exp(-(f - 190) / 8.0) + 1.0, "k": 1.0, "q": 0.0})
	# ---------------- Incêndio de Breu: a faísca do vau eletrificado chega ao breu do Sapador (196)
	var fogo := sm(196, 212, f)
	brasas.visible = f >= 198
	for c in chamas:
		c.visible = f >= 196 + int(float(c.get_meta("d")) * 8.0)
		var vida := ease_out(sm(196 + float(c.get_meta("d")) * 8.0, 212 + float(c.get_meta("d")) * 8.0, f))
		c.material_override.set_shader_parameter("vida", vida)
	if f >= 196:
		luzes.append({"p": alt(BREU) + Vector3(0, 0.6, 0), "r": 3.6 * fogo + 0.2 * sin(f * 0.9), "k": 1.0, "q": 1.0})
	# ---------------- Dobre Duplo: chão consagrado (7 m)
	var rc := 7.0 * ease_out(sm(250, 275, f))
	var cons_on := 1.0 if f >= 250 else 0.0
	wm.set_shader_parameter("cons", Vector4(mastro_pos.x, mastro_pos.z, rc, cons_on * (1.0 - 0.3 * sm(330, 360, f))))
	for mm in manchas:
		var dm: float = Vector2(mm.position.x - mastro_pos.x, mm.position.z - mastro_pos.z).length()
		var morre := sm(255 + dm * 3.0, 300 + dm * 3.0, f) if (f >= 250 and dm < rc) else 0.0
		mm.material_override.set_shader_parameter("dens", 1.05 * (1.0 - morre))
	# ---------------- ondas de impacto (anéis de pena)
	var centros := [porta.position + fwd * 0.5, mastro_pos, mastro_pos, alt(BREU)]
	for i in ondas.size():
		var o: Dictionary = ondas[i]
		var k := (f - float(o["f0"])) / float(o["dur"])
		var mi: MeshInstance3D = o["mi"]
		mi.visible = k >= 0.0 and k <= 1.0
		if mi.visible:
			var c: Vector3 = centros[i]
			var r: float = o["r"]
			mi.global_transform = Transform3D(Basis().scaled(Vector3(r, 1, r)), Vector3(c.x, 0.07, c.z))
			o["m"].set_shader_parameter("k", k)
			o["m"].set_shader_parameter("semente", float(i) * 3.3)
	# ---------------- milícia: espera com tochas, grita, atravessa (280+) e para na margem norte
	for i in mil.size():
		var m = mil[i]
		var ph: float = m.get_meta("fase")
		var vel: float = m.get_meta("vel")
		var p0: Vector3 = m.get_meta("p0")
		if f < 200:
			m.pose("idle", (f + 150) / 60.0 * vel + ph)
		elif f < 280:
			m.pose("grita", fmod((f - 200) / 60.0 * vel + ph * 0.3, 0.4))
		else:
			var k := (f - 280 - ph * 14.0) / 60.0 * vel
			var zalvo := -7.9 - (i % 3) * 0.7 - (i / 3) * 0.3
			var z := p0.z - maxf(k, 0.0) * 4.4
			if k > 0.0 and z > zalvo:
				ciclo(m, "corre", k + ph, 1.0)
				m.rotation.y = PI + 0.15 * sin(i * 2.3)
				var xw := p0.x + 0.35 * sin(z * 0.9 + i) - 2.6 * sm(p0.z, zalvo, z)
				m.position = Vector3(xw, 0, z)
				m.position.y = mundo.altura(m.position.x, m.position.z) * (0.6 if z > 3.2 else 1.0)
			elif k > 0.0:
				m.position = alt(Vector3(p0.x - 2.6, 0, zalvo))
				m.rotation.y = PI * 0.0 + 0.6 * sin(i * 1.7)
				m.pose("grita", fmod(k * 0.7 + ph * 0.3, 0.4))
			else:
				m.pose("grita", 0.1)
		if m.has_meta("tocha"):
			var tp: Vector3 = m.get_meta("tocha").global_position + Vector3(0, 0.45, 0)
			luzes.append({"p": tp, "r": 3.4 + 0.15 * sin(f * 0.7 + i), "k": 1.0, "q": 1.0})
	# luzes que apagam tinta: coroa da Sineira, lanterna do Sapador, ponta do chapéu da Bruxa, janela, portão do forte
	luzes.append({"p": sineira.osso_global("coroa").origin + Vector3(0, 0.25, 0), "r": 3.0 + 0.12 * sin(f * 0.9), "k": 1.0, "q": 1.0})
	luzes.append({"p": sapador.osso_global("lanterna").origin + Vector3(0, -0.1, 0), "r": 2.4 + 0.1 * sin(f * 1.3), "k": 0.95, "q": 1.0})
	luzes.append({"p": mundo.to_global(Vector3(9.6, 1.9, 8.0)), "r": 2.4, "k": 0.8, "q": 1.0})
	luzes.append({"p": mundo.portao_luz, "r": 2.2 + 0.2 * sin(f * 0.21), "k": 0.85, "q": 1.0})
	if f >= 142 and f < 190:
		luzes.append({"p": tip, "r": 1.0 + sm(142, 190, f) * 0.8, "k": 1.0, "q": 0.0})
	if f >= 250 and f < 290:
		luzes.append({"p": Vector3(mastro_pos.x, 0.3, mastro_pos.z), "r": rc + 1.0, "k": 0.8 * (1.0 - sm(270, 290, f)), "q": 0.0})
	_smear(f)
	main.luzes = luzes
	main.reservas = [porta.position, sineira.position, sapador.position, bruxa.position]
	var sombras: Array[Vector4] = []
	for b in [porta, sineira, sapador, bruxa] + piq + pen.slice(0, 8) + mil.slice(0, 6):
		if b.visible:
			sombras.append(Vector4(b.position.x, b.position.z, 0.7, 0.9))
	if mastro_pos != Vector3.ZERO:
		sombras.append(Vector4(mastro_pos.x, mastro_pos.z, 0.35, 1.0))
	wm.set_shader_parameter("sombras", sombras.slice(0, 24))
	wm.set_shader_parameter("n_sombras", mini(sombras.size(), 24))
	if mundo.campanario:
		if not mundo.campanario.has_meta("p0"): mundo.campanario.set_meta("p0", mundo.campanario.position)
		mundo.campanario.position = mundo.campanario.get_meta("p0") + mundo.campanario.global_transform.basis.x.normalized() * (g / 1020.0) * 6.0
	# ---------------- câmera: mola criticamente amortecida simulada desde g = 0 (todo quadro isolado sai igual)
	var alvo := alvo_de(0); var vel_c := Vector3.ZERO
	for q in g + 1:
		var dd := alvo_de(q) - alvo
		vel_c = vel_c * 0.8 + dd * 0.025
		alvo += vel_c
	var cp: Array = cam_params(g)
	_cam_em(alvo, cp[0], cp[1], cp[2])
	if mundo.hz:
		mundo.hz.position = cam.global_position - mundo.hz_cam0
		mundo.hz.visible = main.A("hz", "1") == "1"
	# tremor curto (2-3 quadros) nos contatos, contado no tempo global (anda durante o hit-stop)
	var tremor := 0.0
	var gc := [INTRO + 63, INTRO + 190 + 4, INTRO + 242 + 7]
	if g >= gc[0] and g < gc[0] + 3: tremor = 0.07
	if g >= gc[1] and g < gc[1] + 6: tremor = 0.16 * (gc[1] + 6 - g) / 6.0
	if g >= gc[2] and g < gc[2] + 3: tremor = 0.08
	if tremor > 0.0:
		var rt := cam.global_transform.basis.x; var up := cam.global_transform.basis.y
		cam.global_position += (rt * (h(g) - 0.5) + up * (h(g + 31) - 0.5) * 0.6) * tremor * 2.0

func _achata(p, k: int) -> void:
	var a := clampf(k / 6.0, 0.0, 1.0)
	p.scale = Vector3(1.0 + 0.5 * a, 1.0 - 0.93 * a, 1.0 + 0.5 * a)
	p.todos("achata", a)
	if k >= 6 and not p.has_meta("mancha"):
		p.set_meta("mancha", true)
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new(); q.size = Vector2(0.9, 1.1)
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/aquatinta.gdshader")
		m.set_shader_parameter("modo", 0); m.set_shader_parameter("cor", lin("#231C17")); m.set_shader_parameter("cor2", lin("#231C17"))
		m.set_shader_parameter("dens", 1.05); m.set_shader_parameter("escala", 2.2); m.set_shader_parameter("deriva", Vector2(0.0, 0.0)); m.set_shader_parameter("borda", 2.5)
		mi.material_override = m
		mi.position = Vector3(p.position.x, 0.03, p.position.z)
		mi.rotation.y = p.rotation.y
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		manchas.append(mi)
	if k >= 9:
		p.visible = false

func _voa(n: Node3D, a: Vector3, b: Vector3, k: float, altura_: float, f: int) -> void:
	if n.get_parent() != self:
		var gt := n.global_transform
		n.get_parent().remove_child(n); add_child(n); n.global_transform = gt
	k = clampf(k, 0.0, 1.0)
	n.global_position = a.lerp(b, k) + Vector3(0, sin(k * PI) * altura_, 0)
	n.rotation = Vector3(-f * 0.42, 0.3, 0.2)

func _gotas(f: int, f0: int, c: Vector3) -> void:
	for i in gotas.size():
		var gg: MeshInstance3D = gotas[i]
		var k := f - f0
		if k < 0 or k > 32 or c == Vector3.ZERO:
			gg.visible = false
			continue
		gg.visible = true
		var dirv := Vector3(h(i) - 0.5, 0.5 + h(i + 9) * 0.8, h(i + 3) - 0.5) * Vector3(2.4, 2.2, 2.4)
		var tt := k / 60.0
		gg.global_position = c + dirv * tt + Vector3(0, -4.9 * tt * tt, 0)
		gg.scale = Vector3.ONE * (1.0 - k / 40.0)

func _smear(f: int) -> void:
	var fonte := Vector3.ZERO; var cor := Color.WHITE; var on := false
	if f >= 214 and f <= 228:
		fonte = sino.global_transform * Vector3(0, 0, 0.42); cor = lin("#E8B23A"); on = true
	elif f >= 246 and f <= 270:
		fonte = sino.global_transform * Vector3(0, 0, 0.42); cor = lin("#E8B23A"); on = true
	elif f >= 54 and f <= 64:
		fonte = porta.osso_global("forearm.L").origin + Vector3(0, 0.15, 0); cor = lin("#D9472B"); on = true
	if not on:
		hist.clear(); smear.visible = false; return
	if hist.is_empty() or hist[-1] != fonte:
		hist.append(fonte)
	if hist.size() > 6: hist.pop_front()
	smear.visible = hist.size() >= 2
	smear.material_override.set_shader_parameter("cor", cor)
	smear.material_override.set_shader_parameter("cor_borda", lin("#231C17"))
	smear_im.clear_surfaces()
	if hist.size() < 2: return
	var cam: Camera3D = main.cam
	smear_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in hist.size() - 1:
		var a: Vector3 = hist[i]; var b: Vector3 = hist[i + 1]
		var wa := 0.01 + 0.11 * float(i) / hist.size(); var wb := 0.01 + 0.11 * float(i + 1) / hist.size()
		var d := (b - a).normalized()
		var s := d.cross((cam.global_position - a).normalized()).normalized()
		for q in [[a - s * wa, 0.0], [a + s * wa, 1.0], [b + s * wb, 1.0], [a - s * wa, 0.0], [b + s * wb, 1.0], [b - s * wb, 0.0]]:
			smear_im.surface_set_uv(Vector2(q[1], 0)); smear_im.surface_add_vertex(q[0])
	smear_im.surface_end()

func _faiscas(f: int, tip: Vector3) -> void:
	for i in faiscas.size():
		var s: MeshInstance3D = faiscas[i]
		var on := f >= 142 and f < 192
		if not on:
			s.visible = false
			continue
		var per := 14 + int(h(i) * 10)
		var k := (f - 142 + int(h(i + 5) * per)) % per
		var tt := k / 60.0
		s.visible = true
		s.global_position = tip + Vector3((h(i + f / per) - 0.5) * 0.25, 0.05 + tt * 2.2, (h(i * 3 + f / per) - 0.5) * 0.25)
		s.scale = Vector3.ONE * (1.0 - float(k) / per)

# raio: deslocamento de ponto médio recursivo, com galhos que afinam até zero; troca de desenho a cada 3 quadros
func _md(a: Vector3, b: Vector3, desv: float, n: int, sd: float, out: Array) -> void:
	if n == 0:
		out.append(b)
		return
	var m := (a + b) * 0.5
	var L := a.distance_to(b)
	var d := (b - a).normalized()
	var s1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var s2 := d.cross(s1).normalized()
	m += (s1 * (h(sd) - 0.5) + s2 * (h(sd + 1.7) - 0.5) * 0.6) * L * desv
	_md(a, m, desv, n - 1, sd * 1.37 + 3.1, out)
	_md(m, b, desv, n - 1, sd * 1.91 + 7.3, out)

func _desenha_raio(tip: Vector3, f: int) -> void:
	raio_im.clear_surfaces()
	var cam: Camera3D = main.cam
	var semente := float(f / 3) * 11.0 + 1.0
	var top := tip + Vector3(-5.0, 26.0, -9.0)
	var pts: Array = [top]
	_md(top, tip, 0.55, 5, semente, pts)
	var larg := 0.3 * (1.0 if f < 196 else 0.5)
	raio_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_fita(pts, larg, larg * 0.55, cam)
	# galhos que nascem do canal e afinam até a ponta
	for b in 5:
		var i0 := 4 + b * 5
		if i0 >= pts.size() - 2: break
		var a: Vector3 = pts[i0]
		var dirb: Vector3 = (pts[i0 + 1] - a).normalized() + Vector3((h(semente + b) - 0.5) * 1.6, -0.2, (h(semente * 2.0 + b) - 0.5) * 1.2)
		var fim: Vector3 = a + dirb.normalized() * (3.0 + h(semente + b * 3.0) * 4.0) * (1.0 - float(i0) / pts.size())
		var br: Array = [a]
		_md(a, fim, 0.5, 3, semente + b * 13.0, br)
		_fita(br, larg * 0.5, 0.0, cam)
	_fita([tip, tip + Vector3(0.02, -0.9, 0), tip + Vector3(-0.03, -1.62, 0.02)], larg * 0.5, larg * 0.3, cam)
	raio_im.surface_end()

func _fita(pts: Array, w0: float, w1: float, cam: Camera3D) -> void:
	var n := pts.size()
	for i in n - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var d := (b - a).normalized()
		var vd := (cam.global_position - a).normalized()
		var ka := float(i) / (n - 1); var kb := float(i + 1) / (n - 1)
		var s := d.cross(vd).normalized() * lerpf(w0, w1, ka) * 0.5
		var s2 := d.cross(vd).normalized() * lerpf(w0, w1, kb) * 0.5
		for q in [[a - s, 0.0], [a + s, 1.0], [b + s2, 1.0], [a - s, 0.0], [b + s2, 1.0], [b - s2, 0.0]]:
			raio_im.surface_set_uv(Vector2(q[1], 0))
			raio_im.surface_add_vertex(q[0])
