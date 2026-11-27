extends "res://cena_poca.gd"
# Estresse da prévia web (Compatibility, 1280x720): 4 heróis com cor e símbolo de jogador na base, 20 inimigos
# (16 Ouvidores, 4 Bocalumes), 3 efeitos (Corrente na poça, Enxame de Lume, Incensar da Coveira) e a atmosfera
# barata (névoa de altura no shader, 2 lâminas em cartão, cartões aditivos, sem sombra do motor).
var her := []
var inim := []
var mask := false
const HPOS := [["escorador", Vector3(-3.4, 0, 1.0), "ambar", 0, "escorar", 0.5], ["cristaleira", Vector3(0.3, 0, 0.2), "cobalto", 2, "poca", 1.03],
	["coveira", Vector3(3.6, 0, 2.2), "giz", 3, "incensar", 0.0], ["gancheiro", Vector3(-2.2, 0, 3.4), "veneno", 1, "poca", 1.87]]
const CJ := {"ambar": Color("f0a030"), "veneno": Color("7cd04a"), "cobalto": Color("3e7cf0"), "giz": Color("f2eee6")}

func montar(main) -> void:
	mask = main.arg("mascara", 0) == 1
	main.args["lite"] = "1"
	super.montar(main)
	if mask:
		mundo.visible = false
		vfx.visible = false
		M.sol.visible = false
		for k in luzes: luzes[k].visible = false
		halo_ambar.visible = false; pegar.visible = false
		var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color.BLACK
		env.environment = e; add_child(env)

func elenco() -> void:
	var i := 0
	for hdef in HPOS:
		var mc = null
		if mask:
			mc = Color8(255, 0, [60, 110, 160, 210][i])
		var b = Boneco.new(); add_child(b); b.setup(hdef[0], mc); b.jogo = true
		b.position = chao(hdef[1].x, hdef[1].z) + (Vector3(0, -0.04, 0) if hdef[0] == "cristaleira" else Vector3.ZERO)
		b.rotation.y = deg_to_rad([20.0, -12.0, -30.0, 150.0][i])
		b.springs_default()
		b.pose(hdef[4], hdef[5])
		if not mask:
			base_de(b, CJ[hdef[2]], true, hdef[3], 0.3)
		elif M.arg("so_herois", 0) == 0:
			base_mask(b, mc, 0.3)
		her.append(b)
		i += 1
	cri = her[1]; gan = her[3]
	var rr := RandomNumberGenerator.new(); rr.seed = 7
	var j := 0
	for k in 16:
		var a := TAU * k / 16.0 + rr.randf_range(-0.15, 0.15)
		var r := rr.randf_range(2.3, 5.0)
		var p := Vector3(0.3 + cos(a) * r * 1.25, 0, 0.4 + sin(a) * r * 0.85)
		var mc = Color8(0, 255, 40 + j * 9) if mask else null
		var o = Boneco.new(); add_child(o); o.setup("ouvidor", mc)
		o.position = chao(p.x, p.z); o.rotation.y = yaw_para(p, Vector3(0.3, 0, 0.4))
		o.springs_default()
		var tele := k % 3 == 0
		if k < 5:
			o.pose("eletro", 0.02 * k)
			var a2 := TAU * k / 5.0 + 0.4
			o.position = Vector3(0.3 + cos(a2) * 1.7, 0.95, 0.2 + sin(a2) * 1.3)
			o.rotation.y = yaw_para(o.position, Vector3(0.3, 0, 0.2))
		elif tele:
			o.pose("telegrafa", 0.3)
			o.param(["emis"], "perigo", 1.0)
		else:
			o.pose("idle", 0.05 * k)
		if k >= 12:
			o.todos("dano", 0.5)
		if not mask:
			base_de(o, Color.BLACK, false, 0, 0.25)
		elif k >= 5:
			base_mask(o, mc, 0.25)
		inim.append(o); ouv.append(o)
		j += 1
	for k in 4:
		var p: Vector3 = [Vector3(-4.2, 0, -3.4), Vector3(3.4, 0, -3.6), Vector3(5.8, 0, 3.4), Vector3(-6.0, 0, 2.8)][k]
		var mc = Color8(0, 255, 40 + j * 9) if mask else null
		var b2 = Boneco.new(); add_child(b2); b2.setup("bocalume", mc)
		b2.position = chao(p.x, p.z); b2.rotation.y = yaw_para(p, Vector3.ZERO)
		b2.springs_default()
		b2.pose("telegrafa" if k == 1 else "idle", 0.5 if k == 1 else 0.0)
		if k == 1:
			b2.param(["emis"], "acende", 0.0); b2.param(["emis"], "perigo", 1.0)
		if not mask:
			base_de(b2, Color.BLACK, false, 0, 0.62)
			bases[b2].scale = Vector3(1, 1, 1.9)
		else:
			base_mask(b2, mc, 0.62, 1.9)
		inim.append(b2)
		j += 1
	boc = inim[17]
	if mask and M.arg("so_herois", 0) == 1:
		for o in inim:
			o.visible = false
		for k in bases:
			bases[k].visible = false
	prumo = Boneco.new(); add_child(prumo); prumo.setup("prumo"); prumo.visible = false
	frasco = MeshInstance3D.new(); add_child(frasco)
	halo_ambar = mundo.luz_cartao(Vector3.ZERO, Color(0.95, 0.62, 0.18), 2.4, 0.0)
	pegar = mundo.luz_cartao(Vector3.ZERO, Color(0.49, 0.82, 0.29), 0.8, 0.0)
	luz("geodo", Color(1.0, 0.82, 0.5), 4.0, false)
	luz("corrente", Color(0.5, 0.95, 1.0), 9.0)
	luz("enxame", Color(0.5, 0.95, 0.95), 7.0)
	luz("isca", Color(1.0, 0.72, 0.38), 4.0)

func base_mask(b, mc: Color, raio: float, oval := 1.0) -> void:
	# a base faz parte da miniatura: na máscara dos portões ela entra com a cor do personagem
	var mi := MeshInstance3D.new()
	var q := CylinderMesh.new(); q.top_radius = raio * 0.92; q.bottom_radius = raio * 0.92; q.height = 0.01
	mi.mesh = q
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = mc
	mi.material_override = m
	mi.position = chao(b.position.x, b.position.z) + Vector3(0, 0.03, 0)
	mi.scale = Vector3(1, 1, oval)
	mi.rotation.y = b.rotation.y
	add_child(mi)

func passo(f: int) -> void:
	var t := f / 60.0
	M.gset("vento", Vector4(0.6, -0.3, 0.5, t))
	mundo.passo(t)
	for b in her + inim:
		if bases.has(b): por_base(b)
	vfx.passo(f + 100)
	var fx := F_ESTALO + 14
	var ag: ShaderMaterial = mundo.agua_mat
	ag.set_shader_parameter("corrente", 1.0); ag.set_shader_parameter("corrente_t", 14.0)
	M.gset("flash", Vector4(0.3, 0.5, 0.2, 0.4)); M.gset("flash_cor", Vector4(0.5, 0.95, 1.0, 1.0))
	luzes["corrente"].position = Vector3(0.3, 0.6, 0.2); luzes["corrente"].light_energy = 2.0
	luzes["geodo"].position = her[1].osso_global("geodo").origin; luzes["geodo"].light_energy = 1.0
	halo_ambar.position = Vector3(0.3, 0.5, 0.2); halo_ambar.material_override.set_shader_parameter("forca", 0.45)
	her[1].todos("tingir", Color(0.88, 0.55, 0.14, 0.3))
	luzes["enxame"].position = Vector3(5.0, 0.6, -1.5); luzes["enxame"].light_energy = 2.0
	if mask:
		return
	vfx.fitas_inicio()
	var ci := Color(0.6, 0.97, 1.0, 1.0)
	for k in 11:
		var a := k * TAU / 11.0
		vfx.raio(Vector3(0.3 + cos(a) * 0.95, 0.0, 0.2 + sin(a) * 0.8), Vector3(0.3 + cos(a) * 3.2, 0.0, 0.2 + sin(a) * 2.4), k * 13, 0.035, Color(ci.r, ci.g, ci.b, 0.85), 8, 0.25)
	for i in 5:
		vfx.raio(Vector3(0.3, 0.05, 0.2) + (inim[i].global_position - Vector3(0.3, 0, 0.2)).normalized() * 0.8, inim[i].global_position + Vector3(0, 0.35, 0), 7 + i, 0.03, Color(ci.r, ci.g, ci.b, 0.85))
	# Enxame de Lume sobre os Ouvidores da direita: faíscas em arco com rastro
	var cen := Vector3(5.0, 0.6, -1.0)
	for k in 6:
		var tgt: Vector3 = inim[[6, 7, 8, 9, 10, 17][k]].global_position + Vector3(0, 0.4, 0)
		for jj in 12:
			var tt := clampf(0.75 - jj * 0.05, 0.0, 1.0)
			var side := (tgt - cen).cross(Vector3.UP).normalized() * (0.8 if k % 2 else -0.8)
			vfx.faisca.por(k * 12 + jj, cen.lerp(tgt, tt) + side * sin(tt * PI) + Vector3(0, sin(tt * PI) * 0.6, 0), (1.0 - jj / 12.0) * (2.4 if jj == 0 else 1.1))
	# Incensar da Coveira: rastro de fumaça benta em arco (cura) e brasas
	var cv: Vector3 = her[2].global_position
	var pts := []; var L := []; var cs := []
	for k in 16:
		var a := -0.5 + k * 0.22
		pts.append(cv + Vector3(cos(a) * 1.4, 0.35 + 0.1 * sin(k), sin(a) * 1.0)); L.append(0.35 * (1.0 - abs(k - 8) / 9.0)); cs.append(Color(0.9, 0.86, 0.75, 0.22))
	vfx.fita(pts, L, cs, false)
	for k in 10:
		vfx.resina.por(k, cv + Vector3(cos(k) * 1.2, 0.3 + 0.08 * k, sin(k) * 0.9), 1.4)
	vfx.resina.mat.set_shader_parameter("cor", Color("e8833a"))
	vfx.fitas_fim()
