extends Node3D
# "A Poça sob a Cascata": terraço de musgo no Andar 1, Chuva de Cima, começo de uma Expira. Câmera de combate
# (22 m, 52°, 28° de campo de visão). O Gancheiro envisga a Cristaleira de propósito (Visgo isola), ela eletrifica a
# poça (Estalo + Água = Corrente, força 1,0), o Bocalume cospe esporos, o Gancheiro cancela o combo num Lance do
# Prumo, ela pega no ar (Para-raio) e atira o Prumo carregado na nuvem (Estalo + Esporo = Enxame de Lume).
const Boneco = preload("res://boneco.gd")
const Mundo = preload("res://mundo.gd")
const Vfx = preload("res://vfx.gd")

var M          # main
var cam: Camera3D
var mundo
var vfx
var pc := false
var lite := false
var cri; var gan
var ouv := []
var boc
var prumo
var frasco: MeshInstance3D
var bases := {}
var alt := {}
var cam_alvo := Vector3(0.0, 0.0, 0.6)
var cam_alvo0 := Vector3.ZERO
var cam_dist := 22.0
var cam_pitch := 52.0
var cam_yaw := 0.0
var trauma := 0.0
var zoom := 1.0
var luzes := {}
var resp_x := 0.25
var resp_r := 0.0
var resp_o := Vector2(0.0, 6.0)
var halo_ambar: MeshInstance3D
var pegar: MeshInstance3D
var olhos := {}
var setas := {}

# ---- linha do tempo (quadros a 60 fps)
const F_VISGO := 10      # o frasco sai da mão do Gancheiro
const F_SPLASH := 36     # o Visgo cobre a Cristaleira
const F_TELE := 6        # Ouvidores telegrafam (30 quadros)
const F_PULO := 40       # Ouvidores pulam
const F_ESTALO := 58     # o cajado toca a água: Corrente
const F_SOLTA := 76      # 18 quadros de congelamento
const F_BOC_T := 84      # Bocalume telegrafa (36 quadros)
const F_CUSPE := 120
const F_LANCE := 136     # o Prumo sai da mão do Gancheiro
const F_PEGA := 155      # ela pega nos últimos 0,2 s do voo (voo de 27 quadros)
const F_ARREM := 167
const F_ENXAME := 178
const F_FRENTE := 236
var CP := Vector3(0.3, 0, 0.2)
var OPOS := [Vector3(-2.2, 0, 1.2), Vector3(-1.6, 0, -1.6), Vector3(0.6, 0, -2.4), Vector3(2.5, 0, -1.2), Vector3(2.4, 0, 1.7)]
var NUVEM := Vector3(0.6, 0.55, -1.7)
var ALVO_F := [0, 1, 2, 3, 4, -1]           # alvos das faíscas: Ouvidores e o Bocalume (-1)
var F_HIT := [188, 192, 196, 201, 205, 210]
var G0 := Vector3(-4.8, 0, 2.4)
var G1 := Vector3(-2.2, 0, 1.75)

func h(x: float, z: float) -> float:
	var a: Dictionary = alt
	var gx: float = (x - float(a["x0"])) / float(a["res"])
	var gy: float = (-z - float(a["y0"])) / float(a["res"])
	var ix := clampi(int(gx), 0, int(a["nx"]) - 2); var iy := clampi(int(gy), 0, int(a["ny"]) - 2)
	var fx := clampf(gx - ix, 0, 1); var fy := clampf(gy - iy, 0, 1)
	var Z: Array = a["z"]; var nx := int(a["nx"])
	var z00: float = Z[iy * nx + ix]; var z10: float = Z[iy * nx + ix + 1]; var z01: float = Z[(iy + 1) * nx + ix]; var z11: float = Z[(iy + 1) * nx + ix + 1]
	return lerpf(lerpf(z00, z10, fx), lerpf(z01, z11, fx), fy)

func chao(x: float, z: float) -> Vector3:
	return Vector3(x, maxf(h(x, z), -0.07), z)

func montar(main) -> void:
	M = main
	pc = M.arg("pc", 0) == 1
	lite = M.arg("lite", 0) == 1
	cam = Camera3D.new()
	cam.fov = M.arg("fov", 28.0)   # v2: câmera de combate mais baixa e mais perto (16 m, 46°): herói com 70 a 90 px em 1080p
	cam.near = 0.5
	cam.far = 2500.0
	add_child(cam)
	cam.current = true
	cam_dist = M.arg("dist", 16.0); cam_pitch = M.arg("pitch", 46.0); cam_yaw = M.arg("yaw", 0.0)
	cam_alvo0 = Vector3(M.arg("cx", 0.0), 0.0, M.arg("cz", 0.6))
	cam_alvo = cam_alvo0
	por_camera(Vector3.ZERO)
	vinheta()
	ambiente()
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir({"pc": pc, "lite": lite})
	alt = mundo.dados["altura"]
	vfx = Vfx.new()
	add_child(vfx)
	vfx.iniciar(self, pc, lite)
	elenco()
	if M.arg("sem_luz", 0) == 1:
		M.sol.visible = false
		for k in luzes:
			luzes[k].visible = false

func vinheta() -> void:
	# vinheta pintada presa à câmera: escurece as bordas para o quente dos heróis ancorar a tela (os dois renderers)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/vinheta.gdshader")
	m.set_shader_parameter("forca", M.arg("vinheta", 0.55))
	m.render_priority = 100
	mi.material_override = m
	mi.extra_cull_margin = 10000.0
	mi.position = Vector3(0, 0, -1.0)
	cam.add_child(mi)

func por_camera(off: Vector3) -> void:
	var yaw := deg_to_rad(cam_yaw)
	var pr := deg_to_rad(cam_pitch)
	var back := Vector3(sin(yaw), 0, cos(yaw))
	cam.position = cam_alvo + back * cos(pr) * cam_dist * zoom + Vector3(0, sin(pr) * cam_dist * zoom, 0) + off
	cam.look_at(cam_alvo + off * 0.6, Vector3.UP)

func ambiente() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a2230")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.BLACK
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if pc:
		e.glow_enabled = true
		e.glow_intensity = M.arg("glow", 0.5)
		e.glow_bloom = 0.02
		e.glow_hdr_threshold = 0.9
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		e.set_glow_level(0, 0.0); e.set_glow_level(1, 1.0); e.set_glow_level(2, 0.8); e.set_glow_level(3, 0.6); e.set_glow_level(4, 0.4)
		if M.arg("vol", 1) == 1:
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = M.arg("vol_dens", 0.006)
			e.volumetric_fog_albedo = Color(0.35, 0.4, 0.5)
			e.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			e.volumetric_fog_length = 70.0
			e.volumetric_fog_detail_spread = 1.5
			e.volumetric_fog_gi_inject = 0.0
			e.volumetric_fog_ambient_inject = 0.0
			e.volumetric_fog_sky_affect = 0.0
			e.volumetric_fog_anisotropy = 0.5
		if M.arg("dof", 1) == 1:
			var ca := CameraAttributesPractical.new()
			ca.dof_blur_far_enabled = true
			ca.dof_blur_far_distance = M.arg("dof_far", cam_dist + 14.0)
			ca.dof_blur_far_transition = 20.0
			ca.dof_blur_near_enabled = true
			ca.dof_blur_near_distance = M.arg("dof_near", cam_dist * 0.55)
			ca.dof_blur_near_transition = 4.0
			ca.dof_blur_amount = M.arg("dof_amt", 0.045)
			cam.attributes = ca
	env.environment = e
	add_child(env)
	# névoa pintada (material): fria nos andares de baixo, de altura só abaixo do plano de jogo
	M.gset("nevoa_cor", Vector4(0.055, 0.075, 0.115, 1.0) if pc else Vector4(0.03, 0.045, 0.075, 1.0))
	M.gset("nevoa_par", Vector4(25.0, 250.0, 0.3, 0.4))
	M.gset("nevoa_alt", Vector4(-1.5, M.arg("alt_dens", 0.012), 0.0, 4.0))
	M.gset("nevoa_alt_cor", Vector4(0.075, 0.1, 0.14, 1.0) if pc else Vector4(0.045, 0.065, 0.095, 1.0))
	M.gset("vento", Vector4(0.6, -0.3, 0.4, 0.0))
	# luz-chave de cima: o sol da Coluna, morno
	M.base_luz(M.arg("az", 150.0), M.arg("el", 62.0), M.arg("sol_e", 1.0))
	M.sol.light_color = Color("9fb4d0")   # v2: luz-chave fria e direcional, vinda dos rasgos do teto; o quente é gente
	M.sol.shadow_enabled = pc
	M.sol.directional_shadow_max_distance = 50.0

func luz(nome: String, cor: Color, alcance: float, sombra := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.omni_range = alcance
	l.omni_attenuation = 1.4
	l.light_energy = 0.0
	l.shadow_enabled = sombra and pc
	l.light_volumetric_fog_energy = 1.5
	add_child(l)
	luzes[nome] = l
	return l

func base_de(b, cor: Color, jog: bool, sinal: int, raio: float, oval := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(raio * 2.0, raio * 2.0 * oval)
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/base.gdshader")
	m.set_shader_parameter("cor", cor); m.set_shader_parameter("jogador", 1.0 if jog else 0.0); m.set_shader_parameter("sinal", sinal)
	mi.material_override = m
	add_child(mi)
	bases[b] = mi
	if jog:
		# v2: anel e seta do jogador por cima dos efeitos, e silhueta quando tampado
		m.set_shader_parameter("jogador", 0.0)
		var an := MeshInstance3D.new(); var aq := PlaneMesh.new(); aq.size = Vector2(raio * 2.6, raio * 2.6); an.mesh = aq
		var am := ShaderMaterial.new(); am.shader = load("res://shaders/anel_chao.gdshader")
		am.set_shader_parameter("cor", cor); am.set_shader_parameter("sinal", sinal); am.render_priority = 40
		an.material_override = am
		mi.add_child(an)
		var se := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(0.26, 0.26); se.mesh = sq
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/anel.gdshader")
		sm.set_shader_parameter("cor", cor); sm.set_shader_parameter("modo", 1); sm.render_priority = 41
		se.material_override = sm
		se.extra_cull_margin = 100.0
		add_child(se)
		setas[b] = se
		if M.arg("xray", 0) == 1:   # experimental: a leitura de profundidade ainda marca o próprio herói (ver notas)
			b.xray(cor)
	return mi

func por_base(b) -> void:
	var mi: MeshInstance3D = bases[b]
	var p: Vector3 = b.global_position
	var g := chao(p.x, p.z)
	mi.position = g + Vector3(0, 0.03, 0)
	mi.rotation.y = b.rotation.y
	mi.visible = b.visible
	mi.material_override.set_shader_parameter("altura", maxf(p.y - g.y, 0.0))
	for ch in mi.get_children():
		ch.material_override.set_shader_parameter("altura", maxf(p.y - g.y, 0.0))
	if b.has_method("xray_passo"):
		b.xray_passo(cam)
	if setas.has(b):
		setas[b].position = p + Vector3(0, 1.55 if b.nome != "cristaleira" else 1.85, 0)
		setas[b].visible = b.visible

func novo(n: String, p: Vector3, yaw: float) -> Node3D:
	var b = Boneco.new()
	add_child(b)
	b.setup(n)
	b.jogo = true
	b.position = chao(p.x, p.z)
	b.rotation.y = yaw
	b.springs_default()
	return b

func elenco() -> void:
	cri = novo("cristaleira", CP, deg_to_rad(-12.0))
	base_de(cri, Color("3e7cf0"), true, 2, 0.3)
	gan = novo("gancheiro", G0, yaw_para(G0, CP))
	base_de(gan, Color("7cd04a"), true, 1, 0.3)
	for i in OPOS.size():
		var p: Vector3 = OPOS[i] + CP
		var o = novo("ouvidor", p, yaw_para(p, CP))
		base_de(o, Color.BLACK, false, 0, 0.25)
		ouv.append(o)
	boc = novo("bocalume", Vector3(2.9, 0, -3.3), deg_to_rad(-150.0))
	base_de(boc, Color.BLACK, false, 0, 0.62)
	bases[boc].scale = Vector3(1.0, 1.0, 1.9)
	prumo = Boneco.new()
	add_child(prumo)
	prumo.setup("prumo")
	prumo.scale = Vector3.ONE * 0.9
	frasco = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.14
	frasco.mesh = sm
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color("e09a2a")
	frasco.material_override = fm
	add_child(frasco)
	# halo âmbar (o Visgo isolando a Cristaleira) e o botão "Pegar" no mundo
	halo_ambar = mundo.luz_cartao(Vector3.ZERO, Color(0.95, 0.62, 0.18), 2.4, 0.0)
	pegar = mundo.luz_cartao(Vector3.ZERO, Color(0.49, 0.82, 0.29), 0.8, 0.0)
	pegar.material_override.set_shader_parameter("nucleo", 0.0)
	# luzes do motor: geodo (quente), Corrente, Enxame, isca do Bocalume
	luz("geodo", Color(1.0, 0.82, 0.5), 4.0, true)
	luz("corrente", Color(0.5, 0.95, 1.0), 9.0)
	luz("enxame", Color(0.5, 0.95, 0.95), 7.0)
	luz("isca", Color(1.0, 0.72, 0.38), 4.0)
	if pc:
		luz("gancho", Color(1.0, 0.75, 0.45), 3.0, true)
		for i in mundo.postes.size():
			var l := luz("poste%d" % i, Color(1.0, 0.64, 0.3), 3.8, i < 2)
			l.position = mundo.postes[i]
			l.light_energy = 1.3
	cri.param(["olho"], "abertura", 0.85)

func yaw_para(a: Vector3, b: Vector3) -> float:
	return atan2(b.x - a.x, b.z - a.z)

func arco(a: Vector3, b: Vector3, hgt: float, t: float) -> Vector3:
	var p := a.lerp(b, t)
	p.y += hgt * 4.0 * t * (1.0 - t)
	return p

func ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)

# ------------------------------------------------------------------ linha do tempo
var hitstop := 0
# v2: hit-stop global de 50 a 67 ms (3 a 4 quadros) nos golpes, na recepção e em cada faísca do Enxame. O tempo da
# história para; a câmera treme, a água e as goteiras continuam (tempo real).
const HOLDS := {113: 3, 123: 4, 156: 4, 188: 4, 192: 3, 196: 3, 201: 3, 205: 3, 210: 4}
func historia(fr: int) -> int:
	var s := fr
	for h in HOLDS:
		if fr > h:
			s -= mini(fr - h, HOLDS[h])
	return s

func passo(fr: int) -> void:
	fr += int(M.arg("f0", 0))
	var f := historia(fr) if M.arg("hitstop", 1) == 1 else fr
	var t := fr / 60.0
	M.gset("vento", Vector4(0.6, -0.3, 0.4 + 0.3 * resp_x, t))
	mundo.passo(t)
	var frozen := f >= F_ESTALO and f < F_SOLTA
	# ---- Cristaleira
	cri.pose("poca", f / 60.0)
	cri.position = chao(CP.x, CP.z) + Vector3(0, -0.04, 0)   # pés na água rasa
	var tv := 0.0
	if f >= F_SPLASH:
		tv = 0.34 * ss(F_SPLASH, F_SPLASH + 4, f) * (1.0 - 0.75 * ss(230, 300, f))
	cri.todos("tingir", Color(0.88, 0.55, 0.14, tv))
	if f >= 290:
		cri.rotation.y = lerp_angle(deg_to_rad(-12.0), deg_to_rad(-40.0), ss(290, 300, f))
	# geodo: acende no Estalo, no Para-raio e no arremesso
	var ge := 1.6 + 2.5 * (ss(F_ESTALO - 2, F_ESTALO, f) * (1.0 - ss(F_ESTALO + 10, F_ESTALO + 30, f))) + 3.0 * (ss(F_PEGA, F_PEGA + 2, f) * (1.0 - ss(F_ARREM + 4, F_ARREM + 20, f)))
	if f >= 80 and f < 88 and f % 4 < 2:
		ge += 1.5   # pisca na pose de exibição
	cri.param(["emis"], "energia", ge)
	var geo: Vector3 = cri.osso_global("geodo").origin
	luzes["geodo"].position = geo + Vector3(0, 0.1, 0)
	luzes["geodo"].light_energy = 0.5 + ge * 0.25
	M.gset("lq0", Vector4(geo.x, geo.y - 0.9, geo.z, 2.2 + ge * 0.35))
	# ---- Gancheiro
	gan.pose("poca", f / 60.0)
	var gp := G0
	if f >= 96:
		gp = G0.lerp(G1, ss(96, 110, f))
	gan.position = chao(gp.x, gp.z)
	var gy := yaw_para(G0, CP)
	if f >= 96 and f < 128:
		gy = yaw_para(gp, OPOS[0] + CP + Vector3(-0.3, 0, 0.1))
	elif f >= 128 and f < 226:
		gy = yaw_para(gp, CP)
	elif f >= 226 and f < 292:
		gy = yaw_para(gp, prumo.global_position)
	elif f >= 292:
		gy = lerp_angle(yaw_para(gp, CP), deg_to_rad(-150.0), ss(292, 300, f))
	gan.rotation.y = gy
	if f >= 256 and f < 290:
		gan.param(["olho"], "abertura", 0.15)     # olhos de fenda feliz no abraço
	else:
		gan.param(["olho"], "abertura", 1.0)
	# ---- frasco de Visgo: arco por cima dos Ouvidores até a Cristaleira
	frasco.visible = f >= 2 and f < F_SPLASH
	if f < F_VISGO:
		frasco.global_position = gan.osso_global("hand.L").origin
	elif f < F_SPLASH:
		var a: Vector3 = gan.osso_global("hand.L").origin if f == F_VISGO else frasco_a
		if f == F_VISGO:
			frasco_a = a
		var tt := float(f - F_VISGO) / (F_SPLASH - F_VISGO)
		frasco.global_position = arco(frasco_a, CP + Vector3(0, 0.85, 0), 1.6, tt)
		frasco.rotation = Vector3(f * 0.5, f * 0.3, 0)
	# ---- Ouvidores
	for i in ouv.size():
		passo_ouvidor(i, f)
	# ---- Bocalume
	passo_bocalume(f)
	# ---- Prumo
	passo_prumo(f)
	# ---- efeitos
	efeitos(f)
	# ---- molas e congelamento local (hit-stop): Cristaleira e Ouvidores param juntos na Corrente
	for b in [cri] + ouv:
		if b.mola:
			b.mola.time_scale = 0.0 if frozen else 1.0
	# ---- Respiração: a frente passa pelo terraço e acende os fungos até o horizonte
	if f >= F_FRENTE:
		var k := float(f - F_FRENTE)
		resp_r = 0.22 * k + 0.028 * k * k
		resp_x = 0.25 + 0.75 * ss(F_FRENTE, F_FRENTE + 40, f)
	else:
		resp_r = 0.0
	M.gset("resp", Vector4(resp_x, resp_r if resp_r > 0.0 else -10.0, resp_o.x, resp_o.y))
	# ---- câmera: acompanha o golpe, empurrão de 3% no pico da Corrente, tremor por trauma²
	var alvo := cam_alvo0
	alvo.x += -0.9 * ss(92, 112, f) * (1.0 - ss(175, 200, f))
	cam_alvo = cam_alvo.lerp(alvo, 0.12) if f > 0 else alvo
	zoom = 1.0 - 0.03 * ss(F_ESTALO, F_ESTALO + 4, f) * (1.0 - ss(F_SOLTA, F_SOLTA + 30, f)) - 0.02 * ss(F_ENXAME, F_ENXAME + 4, f) * (1.0 - ss(F_ENXAME + 10, F_ENXAME + 40, f))
	if f == F_ESTALO: trauma = 0.75
	if f == F_ENXAME: trauma = 0.5
	if f in F_HIT: trauma = maxf(trauma, 0.3)
	var sh := trauma * trauma
	var off := Vector3(sin(fr * 2.7) * 0.22, sin(fr * 3.9 + 1.0) * 0.12, cos(fr * 2.1) * 0.18) * sh
	trauma = maxf(trauma - 0.045, 0.0)
	por_camera(off)
	for b in [cri, gan, boc] + ouv:
		por_base(b)
	vfx.passo(fr)
	vfx.fitas_inicio()
	fitas(f)
	vfx.fitas_fim()

var frasco_a := Vector3.ZERO
var prumo_a := Vector3.ZERO
var prumo_b := Vector3.ZERO
var oq := {}      # ouvidor -> [pos_pulo_inicio, pos_queda]

func passo_ouvidor(i: int, f: int) -> void:
	var o = ouv[i]
	var p0: Vector3 = OPOS[i] + CP
	var dir: Vector3 = (CP - p0).normalized()
	var top := p0 + dir * (p0.distance_to(CP) * 0.55)            # ponto no ar (congelado)
	var cai := CP - dir * 1.9 + Vector3(dir.z, 0, -dir.x) * (0.25 if i % 2 else -0.25)
	var dead: bool = f >= int(F_HIT[i]) + 14
	o.visible = not dead
	var em := 0.0
	var pos := chao(p0.x, p0.z)
	var yaw := yaw_para(p0, CP)
	o.todos("tingir", Color(0, 0, 0, 0))
	if f < F_TELE:
		o.pose("idle", f / 60.0)
	elif f < F_PULO:
		o.pose("telegrafa", (f - F_TELE) / 60.0)
		em = ss(F_TELE + 8, F_TELE + 12, f)
	elif f < F_ESTALO:
		o.pose("pulo", 0.0)
		var tt := float(f - F_PULO) / (F_ESTALO - F_PULO)
		pos = arco(chao(p0.x, p0.z), top, 1.3, tt * 0.5) if tt < 1.0 else top
		pos = chao(p0.x, p0.z).lerp(top, tt)
		pos.y = top.y + 1.05 * sin(tt * PI * 0.5)
		em = 1.0
	elif f < F_SOLTA:
		o.pose("eletro", (f - F_ESTALO) / 60.0)
		pos = top + Vector3(0, 1.05, 0)
		# a Corrente pega: estica 3 quadros e trava esticado no congelamento
		o.scale = Vector3(0.86, 1.2, 0.86) if f < F_ESTALO + 3 else Vector3(0.92, 1.1, 0.92)
		# o "esqueleto quase visível": a pele pisca em branco-ciano e escuro a cada 2 quadros
		o.todos("tingir", Color(0.75, 0.98, 1.0, 0.85) if (f / 2) % 2 == 0 else Color(0.05, 0.08, 0.12, 0.8))
	elif f < F_SOLTA + 10:
		o.pose("pulo", 0.0)
		var tt := float(f - F_SOLTA) / 10.0
		pos = (top + Vector3(0, 1.05, 0)).lerp(chao(cai.x, cai.z), tt * tt)
	else:
		pos = chao(cai.x, cai.z)
		if i == 0 and f >= 100 and f < 112:
			o.pose("levanta", (f - 100) / 60.0)
		elif i == 0 and f >= 112 and f < 132:
			o.pose("golpeado", 0.0)
			pos += Vector3(-0.08, 0, -0.05) * ss(112, 124, f)
		elif f >= F_HIT[i]:
			o.pose("golpeado", 0.0)
		else:
			o.pose("atordoado", fmod((f - F_SOLTA - 10) / 60.0, 0.6))
		if f >= F_SOLTA + 10 and f < F_SOLTA + 14:
			o.scale = Vector3(1.3, 0.66, 1.3)     # achata na queda
		else:
			o.scale = Vector3.ONE
		yaw = yaw_para(cai, CP) + PI * 0.0
	if f >= F_HIT[i]:
		var k: float = ss(F_HIT[i], F_HIT[i] + 10, f)
		o.todos("dano", k)
		# achata no impacto da faísca (lê a 40 px) e volta esticando
		var q := 1.0 - ss(F_HIT[i], F_HIT[i] + 5, f)
		o.scale = Vector3(1.0 + 0.3 * q, 1.0 - 0.32 * q + 0.1 * ss(F_HIT[i] + 5, F_HIT[i] + 8, f) * (1.0 - ss(F_HIT[i] + 8, F_HIT[i] + 12, f)), 1.0 + 0.3 * q)
	else:
		o.todos("dano", 0.0)
	o.position = pos
	o.rotation.y = yaw
	o.param(["emis"], "perigo", em)
	o.param(["emis"], "energia", 1.0)
	if i == 0 and f >= 112:
		o.rotation.y = yaw_para(o.position, gan.position)

func passo_bocalume(f: int) -> void:
	var e := 1.0
	var em := 0.0
	if f < F_BOC_T:
		boc.pose("idle", fmod(f / 60.0, boc.dur("idle")))
	elif f < F_CUSPE:
		boc.pose("telegrafa", (f - F_BOC_T) / 60.0)
		e = 1.0 - ss(F_BOC_T + 6, F_BOC_T + 12, f)          # a isca apaga
		em = ss(F_CUSPE - 8, F_CUSPE - 2, f)
	elif f < F_CUSPE + 30:
		boc.pose("cospe", (f - F_CUSPE) / 60.0)
		e = ss(F_CUSPE + 10, F_CUSPE + 30, f)
		em = 1.0 - ss(F_CUSPE + 6, F_CUSPE + 14, f)
	elif f < F_HIT[5]:
		boc.pose("idle", fmod(f / 60.0, boc.dur("idle")))
	else:
		boc.pose("golpeado", 0.0)
		boc.position.z = -3.3 - 0.4 * ss(F_HIT[5], F_HIT[5] + 16, f)
		boc.todos("dano", 0.55 * ss(F_HIT[5], F_HIT[5] + 10, f))
	# a isca é a única luz quente do inimigo: só o material 'emis' que não é a boca muda
	boc.param(["emis"], "acende", e)
	boc.param(["emis"], "perigo", em)
	if boc.mats.has("emis"):
		pass
	var isca: Vector3 = boc.osso_global("isca").origin + Vector3(0, -0.13, 0)
	luzes["isca"].position = isca
	luzes["isca"].light_energy = 0.9 * e
	M.gset("lq2", Vector4(isca.x, isca.y - 0.4, isca.z, 2.4 * e))
	boca_bocalume = em

var boca_bocalume := 0.0

func passo_prumo(f: int) -> void:
	var p: Vector3
	if f < 128:
		# pendurado no rolo de corda, nas costas do Gancheiro
		p = gan.osso_global("rolo").origin + gan.global_transform.basis * Vector3(0.12, -0.12, 0.12)
	elif f < F_LANCE:
		p = gan.osso_global("hand.R").origin + Vector3(0, -0.12, 0)
	elif f < F_PEGA:
		if f == F_LANCE:
			prumo_a = gan.osso_global("hand.R").origin
		var tt := float(f - F_LANCE) / 27.0
		p = arco(prumo_a, CP + Vector3(0.05, 1.35, 0.0), 2.4, tt)
		prumo_b = p
	elif f < F_ARREM:
		p = cri.osso_global("hand.L").origin + Vector3(0, 0.05, 0)
		if f < F_PEGA + 6:
			p += Vector3(0, 0.03, 0) * (F_PEGA + 6 - f) / 6.0   # trava no ar
	elif f < F_ENXAME:
		if f == F_ARREM:
			prumo_a = cri.osso_global("hand.L").origin
		var tt := float(f - F_ARREM) / float(F_ENXAME - F_ARREM)
		p = arco(prumo_a, NUVEM, 0.6, tt)
	elif f < 200:
		# atravessa a nuvem, bate no chão e quica uma vez
		var tt := float(f - F_ENXAME) / 22.0
		var a := NUVEM; var b := chao(-1.3, -1.9) + Vector3(0, 0.12, 0)
		p = a.lerp(b, tt)
		p.y = lerpf(a.y, b.y, minf(tt * 1.6, 1.0)) + 0.35 * maxf(0.0, sin((tt - 0.62) / 0.38 * PI)) * float(tt > 0.62)
	elif f < 226:
		p = chao(-1.3, -1.9) + Vector3(0, 0.12, 0)
	elif f < 256:
		# o Gancheiro puxa pela linha, em duas puxadas
		var tt := ss(226, 236, f) * 0.45 + ss(238, 250, f) * 0.55
		p = (chao(-1.3, -1.9) + Vector3(0, 0.12, 0)).lerp(gan.osso_global("chest").origin + gan.global_transform.basis.z * 0.2, tt)
		if tt > 0.85:
			p.y += 0.25 * (tt - 0.85) / 0.15
	else:
		p = gan.osso_global("chest").origin + gan.global_transform.basis.z * 0.17 + Vector3(0, -0.05, 0)
	prumo.global_position = p
	if f >= F_LANCE and f < 200:
		prumo.rotation = Vector3(f * 0.35, 0, f * 0.2)
	else:
		prumo.rotation = Vector3.ZERO

func efeitos(f: int) -> void:
	var ag: ShaderMaterial = mundo.agua_mat
	# Corrente na poça
	var cor := 0.0
	if f >= F_ESTALO:
		cor = 1.0 - ss(F_ESTALO + 30, F_ESTALO + 70, f)
	ag.set_shader_parameter("corrente", cor)
	ag.set_shader_parameter("corrente_t", float(f - F_ESTALO))
	ag.set_shader_parameter("luz0", Vector4(luzes["geodo"].position.x, luzes["geodo"].position.y, luzes["geodo"].position.z, 0.8))
	luzes["corrente"].position = CP + Vector3(0, 0.6, 0)
	luzes["corrente"].light_energy = 3.0 * cor * (0.7 + 0.3 * float(f % 3 == 0))
	# clarão pintado (barato, também no iPhone)
	var fl := Vector4(0, 0, 0, 0)
	var flc := Color(0.5, 0.95, 1.0)
	if cor > 0.0:
		fl = Vector4(CP.x, 0.5, CP.z, cor * (0.8 + 0.2 * float(f % 2)))
	if f >= F_ENXAME and f < F_ENXAME + 40:
		var k := 1.0 - ss(F_ENXAME, F_ENXAME + 40, f)
		if k * 1.0 > fl.w:
			fl = Vector4(NUVEM.x, NUVEM.y, NUVEM.z, k)
	M.gset("flash", fl)
	M.gset("flash_cor", Vector4(flc.r, flc.g, flc.b, 1.0))
	# halo âmbar em volta da Cristaleira durante a Corrente (o Visgo isola)
	var ha := 0.0
	if f >= F_ESTALO:
		ha = 0.85 * (1.0 - ss(F_SOLTA, F_SOLTA + 24, f))
	halo_ambar.position = CP + Vector3(0, 0.5, 0)
	halo_ambar.material_override.set_shader_parameter("forca", ha)
	# botão Pegar pulsando em verde-veneno sobre a Cristaleira (janela de 0,35 s)
	var pg := 0.0
	if f >= F_PEGA - 12 and f < F_PEGA + 2:
		pg = 0.6 + 0.4 * sin(f * 1.3)
	pegar.position = CP + Vector3(0, 1.45, 0)
	pegar.material_override.set_shader_parameter("forca", pg)
	pegar.scale = Vector3.ONE * (1.0 + 0.25 * sin(f * 1.3))
	# Visgo: respingo de resina no impacto e pedaços que se soltam no fim
	for i in vfx.resina.n:
		var p := Vector3(0, -9999, 0); var s := 0.0
		if f >= F_SPLASH and f < F_SPLASH + 24:
			var tt := float(f - F_SPLASH) / 24.0
			var a := Vfx.hh(i, 31) * TAU
			var v := Vector3(cos(a), 0, sin(a)) * (0.6 + Vfx.hh(i, 32) * 1.2)
			p = CP + Vector3(0, 0.9, 0) + v * tt * 0.8 + Vector3(0, 1.8 * tt - 4.0 * tt * tt, 0)
			s = 1.0 - tt * 0.5
		elif f >= 240 and f < 330 and i < 14:
			var tt := fposmod(float(f - 240) / 30.0 + Vfx.hh(i, 33), 1.0)
			p = CP + Vector3((Vfx.hh(i, 34) - 0.5) * 0.4, 0.8 - tt * 0.8, (Vfx.hh(i, 35) - 0.5) * 0.3)
			s = 0.8 * (1.0 - tt)
		vfx.resina.por(i, p, s)
	# nuvem de esporos do Bocalume: sai da boca, cobre os Ouvidores caídos e sobe com a Expira
	var bocap: Vector3 = boc.global_position + boc.global_transform.basis.z * -0.0 + boc.global_transform.basis * Vector3(0, 0.3, -0.9)
	for i in vfx.nuvem.n:
		var p := Vector3(0, -9999, 0); var s := 0.0
		if f >= F_CUSPE and f < F_ENXAME + 6:
			var tt := ss(F_CUSPE, F_CUSPE + 20, f)
			var o := Vector3((Vfx.hh(i, 41) - 0.5) * 3.0, Vfx.hh(i, 42) * 0.9, (Vfx.hh(i, 43) - 0.5) * 2.2)
			p = bocap.lerp(NUVEM + o, tt) + Vector3(0, (f - F_CUSPE) * 0.004, 0)
			s = (0.5 + tt * (0.8 + Vfx.hh(i, 44))) * 0.6
		vfx.nuvem.por(i, p, s)
	var npc: ShaderMaterial = vfx.nuvem.mat
	npc.set_shader_parameter("cor", Color(0.32, 0.4, 0.42) if f < F_ENXAME else Color(0.42, 0.7, 0.7))
	npc.set_shader_parameter("forca", 1.0 if f < F_ENXAME else 1.0 - ss(F_ENXAME, F_ENXAME + 8, f))
	for i in vfx.nuvem_pts.n:
		var p := Vector3(0, -9999, 0); var s := 0.0
		if f >= F_CUSPE and f < F_ENXAME + 10:
			var tt := ss(F_CUSPE, F_CUSPE + 20, f)
			var o := Vector3((Vfx.hh(i, 51) - 0.5) * 3.4, Vfx.hh(i, 52) * 1.2, (Vfx.hh(i, 53) - 0.5) * 2.6)
			p = bocap.lerp(NUVEM + o, tt) + Vector3(sin(f * 0.1 + i) * 0.05, (f - F_CUSPE) * 0.006, 0)
			s = 0.8 if f < F_ENXAME else 1.3 * (1.0 - ss(F_ENXAME, F_ENXAME + 10, f))
		vfx.nuvem_pts.por(i, p, s)
	vfx.nuvem_pts.mat.set_shader_parameter("cor", Color(0.5, 0.75, 0.68) if f < F_ENXAME else Color(0.7, 1.0, 1.0))
	# Enxame de Lume: 6 faíscas caçam em arcos curtos (com rastro), e os alvos se partem em gesso
	var li := 0
	var lum := 0.0
	for k in 6:
		var tgt: Vector3 = (ouv[ALVO_F[k]].global_position + Vector3(0, 0.4, 0)) if ALVO_F[k] >= 0 else (boc.global_position + Vector3(0, 0.45, 0))
		var f0 := F_ENXAME + 2 + k
		var f1: int = F_HIT[k]
		var a := NUVEM + Vector3((Vfx.hh(k, 61) - 0.5) * 1.2, 0.3, (Vfx.hh(k, 62) - 0.5) * 1.0)
		var side := (tgt - a).cross(Vector3.UP).normalized() * (0.9 if k % 2 else -0.9)
		for j in 12:
			var idx := k * 12 + j
			if idx >= vfx.faisca.n: break
			var ff := f - j
			var p := Vector3(0, -9999, 0); var s := 0.0
			if ff >= f0 and ff <= f1:
				var tt := float(ff - f0) / float(f1 - f0)
				p = a.lerp(tgt, tt) + side * sin(tt * PI) * 0.8 + Vector3(0, sin(tt * PI) * 0.7, 0)
				s = (1.0 - j / 12.0) * (2.4 if j == 0 else 1.1)
				if j == 0:
					lum += 1.0
			vfx.faisca.por(idx, p, s)
		if f >= f1 and f < f1 + 3 and li < 1:
			luzes["enxame"].position = tgt
			li += 1
	luzes["enxame"].light_energy = 2.5 * clampf(lum / 3.0, 0.0, 1.0) + (2.0 if li > 0 else 0.0)
	if luzes["enxame"].light_energy > 0.0 and li == 0:
		luzes["enxame"].position = NUVEM
	# gesso e pó: pedaços com gravidade (caem rápido) e pó que cai mais devagar; uma cabeça quica
	for i in vfx.gesso.n:
		var k: int = i % 6
		var p := Vector3(0, -9999, 0); var s := 0.0
		var f1: int = F_HIT[k] + 14
		if k < 5 and f >= f1 and f < f1 + 50:
			var tt := float(f - f1) / 60.0
			var o: Vector3 = ouv[k].position + Vector3(0, 0.35, 0)
			var a := Vfx.hh(i, 71) * TAU
			var v := Vector3(cos(a) * (0.8 + Vfx.hh(i, 72) * 1.6), 1.2 + Vfx.hh(i, 73) * 2.2, sin(a) * (0.8 + Vfx.hh(i, 72) * 1.6))
			p = o + v * tt + Vector3(0, -9.8 * tt * tt, 0)
			var g := chao(p.x, p.z).y + 0.02
			if p.y < g:
				p.y = g
			s = (1.6 if i % 9 else 3.6) * (1.0 - ss(f1 + 34, f1 + 50, f))
		vfx.gesso.por(i, p, s)
	for i in vfx.po.n:
		var k: int = i % 5
		var p := Vector3(0, -9999, 0); var s := 0.0
		var f1: int = F_HIT[k] + 14
		if f >= f1 and f < f1 + 70:
			var tt := float(f - f1) / 70.0
			p = ouv[k].position + Vector3((Vfx.hh(i, 81) - 0.5) * 0.8, 0.3 + tt * 0.4 - tt * tt * 0.3, (Vfx.hh(i, 82) - 0.5) * 0.8)
			s = (0.5 + tt * 0.9) * (1.0 - tt)
		vfx.po.por(i, p, s)

func fitas(f: int) -> void:
	var ci := Color(0.6, 0.97, 1.0, 1.0)
	# Corrente: relâmpagos que correm pela água em 6 quadros, pulam para os Ouvidores e contornam a Cristaleira
	if f >= F_ESTALO and f < F_ESTALO + 50:
		var reach := clampf((f - F_ESTALO) / 6.0, 0.0, 1.0)
		var fade := 1.0 - ss(F_ESTALO + 24, F_ESTALO + 50, f)
		for k in 11:
			var a := k * TAU / 11.0 + Vfx.hh(k, 3) * 0.4
			var R := (2.4 + Vfx.hh(k, 4) * 1.4) * reach
			var p0 := CP + Vector3(cos(a) * 0.85, 0.0, sin(a) * 0.75)
			var p1 := CP + Vector3(cos(a) * R, 0.0, sin(a) * R * 0.8)
			p0.y = 0.0; p1.y = 0.0
			vfx.raio(p0, p1, (f / 2) * 13 + k, 0.035, Color(0.6, 0.97, 1.0, fade), 8, 0.25)
	if f >= F_ESTALO and f < F_SOLTA + 4:
		for i in ouv.size():
			var o = ouv[i]
			var a: Vector3 = CP + Vector3(cos(i * 1.3) * 0.9, 0.05, sin(i * 1.3) * 0.9)
			vfx.raio(a, o.global_position + Vector3(0, 0.35, 0), f / 2 * 7 + i, 0.03, ci)
		for k in 3:
			var a0 := (f / 2) * 0.9 + k * 2.1
			var pts := []; var L := []; var cs := []
			for j in 9:
				var a := a0 + j * 0.32
				pts.append(CP + Vector3(cos(a) * 0.48, 0.15 + j * 0.1 + Vfx.hh(f / 2 + j, k) * 0.05, sin(a) * 0.48))
				L.append(0.022); cs.append(Color(0.6, 0.97, 1.0, 0.8))
			vfx.fita_cel(pts, L, Color(0.6, 0.97, 1.0, 0.8))
	# Para-raio: linhas de Estalo correm pelo chumbo do Prumo
	if f >= F_PEGA and f < F_ARREM + 10:
		var pp: Vector3 = prumo.global_position
		for k in 3:
			var a := pp + Vector3(cos(f + k * 2.0) * 0.18, 0.15, sin(f + k * 2.0) * 0.18)
			vfx.raio(pp + Vector3(0, -0.1, 0), a, f * 3 + k, 0.03, ci, 4, 0.06)
		var geo: Vector3 = cri.osso_global("geodo").origin
		vfx.raio(geo, pp, f / 2 * 5, 0.035, ci, 6, 0.12)
	# linha do Prumo: corda de verlet (catenária de verdade) que desenrola no voo e dá o estalo no puxão
	if f >= F_LANCE and f < 290:
		var a: Vector3 = gan.osso_global("hand.R").origin
		var b: Vector3 = prumo.global_position + Vector3(0, 0.12, 0)
		corda_passo(a, b, f)
		var pts := []; var L := []; var cs := []; var L2 := []; var c2 := []
		for p in corda:
			pts.append(p); L.append(0.03); cs.append(Color(0.2, 0.14, 0.08, 1.0)); L2.append(0.016); c2.append(Color(0.72, 0.58, 0.38, 1.0))
		vfx.fita(pts, L, cs, false)
		vfx.fita(pts, L2, c2, false)
	# borrão (smear) dos punhais: fita verde-veneno atrás da ponta, nos quadros do golpe
	for w in [[110, 118, "prop"], [120, 128, "adaga"]]:
		if f >= w[0] and f < w[1]:
			var pts := []; var L := []; var cs := []
			for j in 5:
				var ff: int = f - j
				var p := smear_pos(w[2], ff, f)
				pts.append(p); L.append(0.2 * (1.0 - j / 5.0)); cs.append(Color(0.49, 0.82, 0.29, 0.9))
			var L2 := []; var c2 := []
			for j in L.size():
				L2.append(L[j] * 0.45); c2.append(Color(0.85, 1.0, 0.7, 0.95))
			var L0 := []; var c0 := []
			for j in L.size():
				L0.append(L[j] * 1.5); c0.append(Color(0.1, 0.22, 0.06, 0.85))
			vfx.fita(pts, L0, c0, false); vfx.fita(pts, L, cs, false); vfx.fita(pts, L2, c2, false)
	# arco do Lance do Prumo (rastro curto) e do arremesso dela
	for w in [[F_LANCE, F_PEGA], [F_ARREM, F_ENXAME]]:
		if f >= w[0] and f < w[1]:
			var pts := [prumo.global_position]
			var L := [0.12]; var cs := [Color(0.95, 0.95, 0.85, 0.5)]
			pts.append(prumo.global_position - (prumo.global_position - prumo_b).normalized() * 0.5 if prumo_b != prumo.global_position else prumo.global_position + Vector3(0, -0.3, 0))
			L.append(0.0); cs.append(Color(0.95, 0.95, 0.85, 0.0))
			vfx.fita(pts, L, cs, true)

var corda := []
var corda_ant := []
var corda_f := -1
func corda_passo(a: Vector3, b: Vector3, f: int) -> void:
	const N := 16
	if corda.is_empty():
		for j in N:
			var p := a.lerp(b, j / float(N - 1))
			corda.append(p); corda_ant.append(p)
	if f == corda_f:
		corda[0] = a; corda[N - 1] = b
		return
	corda_f = f
	var d := a.distance_to(b)
	var L := d * 1.12 + 0.3                       # frouxa no voo e no chão
	if f >= 226 and f < 256:
		L = d * 0.99                               # o puxão estica a corda
	var seg := L / (N - 1)
	for j in range(1, N - 1):
		var p: Vector3 = corda[j]
		var v: Vector3 = (p - corda_ant[j]) * 0.96
		corda_ant[j] = p
		corda[j] = p + v + Vector3(0, -9.8, 0) / 3600.0
		var g := chao(corda[j].x, corda[j].z).y + 0.02
		if corda[j].y < g:
			corda[j].y = g
	if f == 226 or f == 238:
		# estalo: um chicote lateral que corre pela corda
		var side := (b - a).cross(Vector3.UP).normalized()
		for j in range(1, N - 1):
			corda_ant[j] = corda[j] - side * 0.05 * sin(j / float(N - 1) * PI)
	corda[0] = a; corda[N - 1] = b
	for it in 20:
		for j in N - 1:
			var p0: Vector3 = corda[j]; var p1: Vector3 = corda[j + 1]
			var dd := p1 - p0
			var l := dd.length()
			if l < 0.0001: continue
			var k := (l - seg) / l * 0.5
			if j > 0: corda[j] = p0 + dd * k
			if j + 1 < N - 1: corda[j + 1] = p1 - dd * k
		corda[0] = a; corda[N - 1] = b

var _smear_hist := {}
func smear_pos(osso: String, ff: int, f: int) -> Vector3:
	# guarda a posição da ponta da lâmina por quadro (o borrão usa as últimas 5)
	var key := osso + str(f)
	if ff == f:
		var tr: Transform3D = gan.osso_global(osso)
		var tip := tr.origin + tr.basis.y.normalized() * 0.2
		_smear_hist[osso + str(f)] = tip
		return tip
	return _smear_hist.get(osso + str(ff), gan.osso_global(osso).origin)
