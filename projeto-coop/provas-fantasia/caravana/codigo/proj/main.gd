extends Node3D
# Prova de estilo Wickwain. Cenas: folha (folha de modelo), poses, cena (quadro bonito / clipe), estresse.
const Boneco = preload("res://boneco.gd")
const Mundo = preload("res://mundo.gd")

var args := {}
var out := ""
var frames := 3
var f := 0
var cam: Camera3D
var sol: DirectionalLight3D
var env: WorldEnvironment
var pav := []          # luzes de pavio: Vector4 (pos, raio)
var cena: Node3D = null

func arg(k: String, d: Variant = null) -> Variant:
	if not args.has(k):
		return d
	var v: String = args[k]
	if d is float: return float(v)
	if d is int: return int(v)
	if d is bool: return v == "1" or v == "true"
	return v

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	out = arg("out", "")
	frames = arg("frames", 3)
	for i in 8:
		RenderingServer.global_shader_parameter_add("pavio_%d" % i, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_add("curva_piv", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, -1))
	RenderingServer.global_shader_parameter_add("curva_par", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_add("ferve", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add("vento", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1, 0, 0.5, 0))
	match arg("cena", "folha"):
		"folha":
			cena_folha()
		"cena":
			cena_brejo()
		"poses":
			cena_poses()
		"estresse":
			cena_estresse()
		_:
			push_error("cena?")

func set_pavio(lst: Array) -> void:
	for i in 8:
		var v: Vector4 = lst[i] if i < lst.size() else Vector4.ZERO
		RenderingServer.global_shader_parameter_set("pavio_%d" % i, v)

func base_luz(az := -135.0, el := 50.0, energia := 1.0) -> void:
	sol = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-el, az, 0)
	sol.light_energy = energia
	sol.shadow_enabled = true
	add_child(sol)

func ambiente(bg: Color) -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.BLACK
	e.ambient_light_energy = 0.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

# ------------------------------------------------------------------ folha de modelo
func cena_folha() -> void:
	ambiente(Color(arg("bg", "#d8ccb0")))
	base_luz(arg("az", -135.0), arg("el", 50.0))
	var who: Array = String(arg("who", "rodeira,pavieiro,sineira,gatuno")).split(",")
	var yaws := [0.0, 35.0, 90.0]
	var dx: float = arg("dx", 1.1)
	var x0 := -dx * (who.size() * 3 - 1) / 2.0
	var i := 0
	var cores := {"rodeira": "carmim", "pavieiro": "ouro", "sineira": "celeste", "gatuno": "lilas"}
	for w in who:
		for y in yaws:
			var b = Boneco.new()
			add_child(b)
			b.setup(w, cores.get(w, ""))
			b.position = Vector3(x0 + i * dx, 0, 0)
			b.rotation_degrees.y = y
			b.param(["cor", "metal", "contorno"], "forcar", Vector4(float(arg("pint", 1.0)), float(arg("grav", 0.0)), 0, 0))
			if b.ap and b.ap.has_animation(arg("anim", "idle")):
				b.pose(arg("anim", "idle"), arg("t", 0.0))
			i += 1
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = arg("size", 1.6)
	var pitch: float = arg("pitch", 20.0)
	add_child(cam)
	cam.rotation_degrees = Vector3(-pitch, 0, 0)
	cam.position = Vector3(0, float(arg("cy", 0.55)), 0) + cam.global_transform.basis.z * 20.0
	cam.current = true

func _process(_d: float) -> void:
	if est:
		passo_estresse(f)
	elif vfx != null:
		passo_cena(f + arg("f0", 0))
	f += 1
	if f >= frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("PROBE salvo ", out, " ", img.get_size())
		get_tree().quit()
		OS.kill(OS.get_process_id())
		set_process(false)

# ------------------------------------------------------------------ câmera do jogo e curvatura do mundo
var piv := Vector3.ZERO
var cam_dist := 16.0
var cam_pitch := 52.0
var cam_yaw := 0.0
var mundo
var herois := {}
var inimigos := []
var pc := false

func por_camera() -> void:
	var yaw := deg_to_rad(cam_yaw)
	var pr := deg_to_rad(cam_pitch)
	var back := Vector3(sin(yaw), 0, cos(yaw))
	cam.position = piv + back * cos(pr) * cam_dist + Vector3(0, sin(pr) * cam_dist, 0)
	cam.look_at(piv, Vector3.UP)
	var fwd := -back
	RenderingServer.global_shader_parameter_set("curva_piv", Vector4(piv.x, piv.z, fwd.x, fwd.z))
	RenderingServer.global_shader_parameter_set("curva_par", Vector4(arg("c_a", 2.5), arg("c_l", 2.5), arg("c_s", 0.93), arg("curva", 1.0)))

func ambiente_brejo() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/ceu.gdshader")
	var top := -sin(deg_to_rad(cam_pitch - cam.fov * 0.5))
	sm.set_shader_parameter("topo", top)
	sm.set_shader_parameter("horiz", arg("horiz", -0.68))
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.BLACK
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# névoa exponencial de altura, tingida pelo pôr do sol: os vales (o mundo dobrado para baixo) afundam numa
	# névoa malva que esquenta na direção do sol; o perto fica limpo
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color(arg("fog_cor", "#4a3c58"))
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = arg("fog_sol", 0.0)
	e.fog_density = arg("fog_dens", 0.004)
	e.fog_sky_affect = 0.0
	e.fog_height = arg("fog_h", -20.0)
	e.fog_height_density = arg("fog_hd", 0.06)
	if pc:
		e.glow_enabled = true
		e.glow_intensity = arg("glow", 0.7)
		e.glow_bloom = 0.04
		e.glow_hdr_threshold = 1.1
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		e.set_glow_level(0, 0.0); e.set_glow_level(1, 1.0); e.set_glow_level(2, 0.8); e.set_glow_level(3, 0.6); e.set_glow_level(4, 0.4)
		if arg("vol", 1) == 1:
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = arg("vol_dens", 0.008)
			e.volumetric_fog_albedo = Color(0.55, 0.6, 0.75)
			e.volumetric_fog_emission = Color(0.02, 0.025, 0.05)
			e.volumetric_fog_emission_energy = 1.0
			e.volumetric_fog_length = 80.0
			e.volumetric_fog_detail_spread = 2.0
			e.volumetric_fog_gi_inject = 0.0
			e.volumetric_fog_ambient_inject = 0.0
			e.volumetric_fog_sky_affect = 0.0
			e.volumetric_fog_anisotropy = 0.3
	env.environment = e
	add_child(env)

func luz_motor(p: Vector3, cor: Color, energia: float, alcance: float, sombra := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.2
	l.shadow_enabled = sombra
	l.light_volumetric_fog_energy = arg("vol_luz", 2.0)
	add_child(l)
	return l

func cena_brejo() -> void:
	pc = arg("pc", 0) == 1
	cam = Camera3D.new()
	cam.fov = arg("fov", 30.0)
	cam.near = 0.5
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	piv = Vector3(arg("px", 1.2), 0.0, arg("pz", 0.35))
	cam_dist = arg("dist", 16.5); cam_pitch = arg("pitch", 52.0); cam_yaw = arg("yaw", 0.0)
	por_camera()
	ambiente_brejo()
	base_luz(arg("az", -70.0), arg("el", 40.0), 1.0)
	sol.directional_shadow_max_distance = 70.0
	sol.light_color = Color(arg("sol_cor", "#c9b8c8"))
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir({"pc": pc})
	vfx = Vfx.new()
	add_child(vfx)
	vfx.iniciar(pc)
	montar_cena()

# ------------------------------------------------------------------ a cena da prova: Lance + Eixo + Labareda
const Vfx = preload("res://vfx.gd")
var vfx
var lant: Node3D
var cores_j := {"rodeira": Color("e0503c"), "pavieiro": Color("e8c34a"), "sineira": Color("5cb8ee"), "gatuno": Color("b07be6")}
const CF := Vector3(1.9, 0.0, 0.45)      # centro da Labareda
const LP := Vector3(0.78, 0.0, 0.36)    # onde a lanterna é cravada
const R0 := Vector3(0.4, 0.0, -0.2)
const P0 := Vector3(-3.7, 0.0, -0.5)
const A0 := Vector3(-1.9, 0.0, 1.15)
const F_THROW := 48
const F_CATCH := 75
const F_C := 89
const F_SPARK := 52
var fpos := [Vector3(3.6, 0, 1.6), Vector3(3.9, 0, -0.7), Vector3(2.7, 0, -1.5), Vector3(3.0, 0, 2.7), Vector3(5.9, 0, -1.6), Vector3(6.2, 0, 1.9)]
var fhit := []
var fdados := []
var mats_fx := {}
var oleos := []
var luzes := {}
var trauma := 0.0
var cam_base := Transform3D()
var rastro_pts := []
var fog_vols := []

func yaw_para(d: Vector3) -> float:
	return atan2(d.x, d.z)

func h1(i: int, k: int) -> float:
	var x := sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return x - floor(x)

func montar_cena() -> void:
	var rod = Boneco.new(); add_child(rod); rod.setup("rodeira", "carmim"); rod.position = R0
	rod.springs_default(); herois["rodeira"] = rod
	var pv = Boneco.new(); add_child(pv); pv.setup("pavieiro", "ouro"); pv.position = P0
	pv.rotation.y = yaw_para(R0 - P0); pv.springs_default(); herois["pavieiro"] = pv
	for i in fpos.size():
		var b = Boneco.new(); add_child(b); b.setup("fuligento"); b.position = fpos[i]
		b.rotation.y = yaw_para(R0 - fpos[i]); b.springs_default()
		b.scale = Vector3.ONE * (0.92 + 0.16 * h1(i, 3))
		inimigos.append(b)
		fhit.append(-1)
		fdados.append({})
		if i < 4:
			# mancha de óleo no corpo (contorno Carmim de quem untou)
			var g := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 10; sm.rings = 6
			g.mesh = sm
			var m1 := StandardMaterial3D.new(); m1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m1.albedo_color = Color("2a1f18")
			g.material_override = m1
			var o := MeshInstance3D.new(); o.mesh = sm
			var m2 := StandardMaterial3D.new(); m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m2.albedo_color = Color("e0503c"); m2.cull_mode = BaseMaterial3D.CULL_FRONT
			o.material_override = m2; o.scale = Vector3.ONE * 1.18
			g.add_child(o)
			g.scale = Vector3(0.26, 0.1, 0.22)
			var at := BoneAttachment3D.new(); b.skel.add_child(at); at.bone_name = "corpo"
			at.add_child(g); g.position = Vector3(0.0, 0.12, 0.05)
	var ap = Boneco.new(); add_child(ap); ap.setup("apagador"); ap.position = A0
	ap.rotation.y = yaw_para(P0 + Vector3(0.3, 0, 0.25) - A0); ap.springs_default()
	inimigos.append(ap)
	lant = Mundo.carregar("lanterna")
	lant.scale = Vector3.ONE * Boneco.ESCALA
	add_child(lant)
	# marcas no chão: óleo (Carmim), anéis de jogador, telegrafia do Apagador, frente de pincel
	var oil := [[Vector3(1.6, 0.03, 0.45), 1.5], [Vector3(2.5, 0.03, 0.95), 1.3], [Vector3(2.3, 0.03, -0.3), 1.3], [Vector3(1.1, 0.03, 0.95), 0.9],
				[Vector3(3.1, 0.03, 0.2), 0.9], [Vector3(1.9, 0.03, 1.6), 0.9], [Vector3(3.3, 0.03, -1.0), 0.7]]
	for i in oil.size():
		var mt = vfx.marca("oleo%d" % i, 0, oil[i][0], oil[i][1], cores_j["rodeira"], {"semente": float(i) * 3.7})
		oleos.append([mt, oil[i][0]])
	mats_fx["anel_rod"] = vfx.marca("anel_rod", 1, R0 + Vector3(0, 0.12, 0), 1.2, cores_j["rodeira"], {"simbolo": 0})
	mats_fx["anel_pav"] = vfx.marca("anel_pav", 1, P0 + Vector3(0, 0.12, 0), 1.2, cores_j["pavieiro"], {"simbolo": 1})
	mats_fx["tele"] = vfx.marca("tele", 2, P0 + Vector3(0.35, 0.13, 0.3), 2.8, Color.WHITE, {"fecha": 0.2})
	mats_fx["frente"] = vfx.marca("frente", 3, CF + Vector3(0, 0.05, 0), 1.0, Color.WHITE, {"semente": 2.0})
	vfx.marcas["frente"].visible = false
	# Labareda: um núcleo de 5 chamas altas no centro do óleo e chamas menores nas outras manchas (nascem quando a
	# frente de pincel passa); todas inclinam juntas com o vento
	var cs := []; var hs := []
	for i in 5:
		var a := float(i) / 5.0 * TAU + h1(i, 7) * 0.8
		var r := 0.15 + h1(i, 8) * 0.45
		cs.append(Vector3(CF.x - 0.2 + cos(a) * r, 0.02, CF.z + sin(a) * r * 0.7)); hs.append(1.7 + h1(i, 6) * 0.8)
	for i in 11:
		var o: Array = oil[(i + 1) % oil.size()]
		var a := h1(i, 17) * TAU
		var r := sqrt(h1(i, 18)) * float(o[1]) * 0.33
		cs.append(Vector3(o[0].x + cos(a) * r, 0.02, o[0].z + sin(a) * r)); hs.append(0.55 + h1(i, 16) * 0.7)
	vfx.criar_fogo(cs, hs, 99.0)
	for i in vfx.fogo.size():
		var d: float = (vfx.fogo[i][2] - CF).length()
		vfx.fogo[i][5] = F_C / 60.0 + tempo_frente(d) + h1(i, 4) * 0.05
	# névoa pintada em três camadas (8, 25 e 80 m da câmera) e a névoa de maré na canela
	var vp := Vector2(1280, 720)
	var sc := get_viewport().get_visible_rect().size / vp
	mats_fx["nv8a"] = vfx.nevoa(cam.project_position(Vector2(170, 150) * sc, 8.0), Vector2(2.4, 0.5), cam.global_position, {"alfa": 0.14, "vel": 1.1, "semente": 1.0, "curva": 0.0, "freq_linhas": 18.0})
	mats_fx["nv8b"] = vfx.nevoa(cam.project_position(Vector2(1130, 170) * sc, 8.0), Vector2(2.2, 0.45), cam.global_position, {"alfa": 0.2, "vel": 1.1, "semente": 4.0, "curva": 0.0, "freq_linhas": 18.0})
	mats_fx["nv25"] = vfx.nevoa(cam.project_position(Vector2(640, 175) * sc, 25.0), Vector2(30.0, 2.6), cam.global_position, {"alfa": 0.5, "vel": 0.5, "semente": 7.0, "curva": 0.0, "freq_linhas": 30.0})
	mats_fx["nv80"] = vfx.nevoa(cam.project_position(Vector2(640, 92) * sc, 80.0), Vector2(110.0, 7.0), cam.global_position, {"alfa": 0.6, "vel": 0.2, "semente": 11.0, "curva": 0.0, "freq_linhas": 34.0})
	mats_fx["mare"] = vfx.bruma(Vector3(piv.x, 0.2, piv.z - 2.0), Vector2(36, 22), {"alfa": 0.32, "vel": 0.6, "semente": 3.0, "freq_linhas": 70.0, "luz_alfa": 0.12})
	# luzes do motor no PC (sombras longas das lanternas, volumes de névoa)
	if pc:
		luzes["fogo"] = luz_motor(CF + Vector3(-0.2, 1.1, 0), Color("ff8a38"), 0.0, 10.0, true)
		luzes["fogo2"] = luz_motor(Vector3(2.5, 0.6, 0.95), Color("ff7a30"), 0.0, 5.0, false)
		luzes["fogo3"] = luz_motor(Vector3(2.3, 0.6, -0.3), Color("ffa048"), 0.0, 5.0, false)
		luzes["lant"] = luz_motor(P0, Color("ffb060"), 1.2, 5.0, false)
		luzes["wain"] = luz_motor(Vector3(6.4, 5.3, -25.2), Color("ffb060"), 5.0, 30.0, true)
		luzes["wain2"] = luz_motor(Vector3(-1.0, 3.0, -24.0), Color("ff9a50"), 3.0, 18.0, false)
		var sp := SpotLight3D.new()
		sp.position = Vector3(-46.5, 26.0, -150.0)
		sp.light_color = Color("b8c8e0"); sp.light_energy = 6.0; sp.spot_range = 160.0; sp.spot_angle = 7.0
		sp.light_volumetric_fog_energy = 6.0
		add_child(sp)
		luzes["farol"] = sp
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(40, 0.7, 30)
		fv.position = Vector3(piv.x, 0.1, piv.z - 4.0)
		var fm := FogMaterial.new(); fm.density = arg("mare_dens", 0.5); fm.albedo = Color(0.6, 0.66, 0.8); fm.height_falloff = 2.0; fm.edge_fade = 0.4
		fv.material = fm
		add_child(fv)
		var fv2 := FogVolume.new()
		fv2.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv2.size = Vector3(30, 10, 14)
		fv2.position = Vector3(1.0, 1.5, -25.0)
		var fm2 := FogMaterial.new(); fm2.density = 0.25; fm2.albedo = Color(1.0, 0.8, 0.6)
		fv2.material = fm2
		add_child(fv2)
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = arg("dof_far", 42.0)
		ca.dof_blur_far_transition = 20.0
		ca.dof_blur_amount = arg("dof", 0.035)
		cam.attributes = ca
	cam_base = cam.global_transform

# pontos de interesse acesos no plano médio: o braseiro da ruína e a lanterna caída da carroça (abrem guache longe)
const BRASEIRO := Vector3(-5.02, 1.1, -8.57)
const LANT_CAIDA := Vector3(6.87, 0.3, -9.33)
func luzes_poi(t: float) -> Array:
	return [Vector4(BRASEIRO.x, BRASEIRO.y, BRASEIRO.z, 2.6 * (1.0 + 0.05 * sin(t * 17.0) + 0.03 * sin(t * 29.0))),
			Vector4(LANT_CAIDA.x, LANT_CAIDA.y, LANT_CAIDA.z, 1.6 * (1.0 + 0.04 * sin(t * 13.0)))]

func tempo_frente(d: float) -> float:
	# inverso de r(u) = Rmax * (1 - (1-u)^2.2), u em 0..1 ao longo de 0,4 s
	var rmax := 4.0
	if d >= rmax:
		return 99.0
	var u := 1.0 - pow(1.0 - d / rmax, 1.0 / 2.2)
	return u * 0.4

func raio_frente(t: float) -> float:
	var u: float = clamp((t - F_C / 60.0) / 0.4, 0.0, 1.0)
	if t < F_C / 60.0:
		return 0.0
	return 4.0 * (1.0 - pow(1.0 - u, 2.2))

func arco(a: Vector3, b: Vector3, u: float, alt: float) -> Vector3:
	return a.lerp(b, u) + Vector3(0, 4.0 * alt * u * (1.0 - u), 0)

func passo_cena(fr: int) -> void:
	var t := fr / 60.0
	RenderingServer.global_shader_parameter_set("ferve", floor(t * 8.0))
	RenderingServer.global_shader_parameter_set("vento", Vector4(0.9, 0.25, 0.6, t))
	mundo.passo(t)
	var rod = herois["rodeira"]; var pv = herois["pavieiro"]
	# --- Pavieiro: Lance (antecipação, arremesso, Fagulha, continuidade, susto)
	if fr - 20 < 150:
		pv.pose("lance", clamp(fr - 20, 0, 200) / 60.0)
	else:
		pv.pose("espera", fposmod((fr - 170) / 60.0, pv.dur("espera")))
	# rajada de vento nas molas (capa, mangas, trança, chama): o idle respira e balança
	var raj := Vector3(0.9, 0.0, 0.25) * (0.8 + 0.6 * sin(t * 2.3) + 0.3 * sin(t * 5.1))
	for hb in [pv, herois["rodeira"]]:
		if hb.mola: hb.mola.vento = raj
	var fh: float = clamp((fr - 60) / 70.0, 0.0, 1.0)
	pv.param(["cor", "metal"], "fuligem_h", 0.24 * fh * fh * (3.0 - 2.0 * fh))
	# --- Rodeira: Eixo, com congelamento local de 4 quadros na pegada e 8 na Labareda
	var fa := fr - 20
	if fr > F_CATCH: fa -= min(fr - F_CATCH, 4)
	if fr > F_C: fa -= min(fr - F_C, 4)
	if fa < 0 or fa / 60.0 < rod.dur("eixo"):
		rod.pose("eixo", clamp(fa, 0, 400) / 60.0)
	else:
		rod.pose("espera", fposmod(fa / 60.0 - rod.dur("eixo"), rod.dur("espera")))
	var yaw_a := yaw_para(P0 - R0)
	var yaw_b := yaw_para(CF - R0)
	var gira := 0.0
	if fr < F_CATCH + 4:
		rod.rotation.y = yaw_a
	elif fr < F_C:
		var u: float = clamp((fr - F_CATCH - 4) / 8.0, 0.0, 1.0)
		rod.rotation.y = lerp_angle(yaw_a, yaw_b, u * u * (3.0 - 2.0 * u))
	else:
		rod.rotation.y = yaw_b
		# o giro em volta da lanterna cravada (Eixo): 360° entre fa 70 e 90, desacelera no fim
		var u2: float = clamp((fa - 72) / 22.0, 0.0, 1.0)
		gira = TAU * (1.0 - pow(1.0 - u2, 2.0))
		var off := (R0 - LP).rotated(Vector3.UP, gira)
		rod.position = LP + off
		rod.rotation.y = yaw_b + gira
	# --- a lanterna: na mão do Pavieiro, voo em arco, na mão da Rodeira, cravada no lodo
	var p_lant := Vector3.ZERO
	var r_lant := 3.0
	var mao_p: Vector3 = pv.osso_global("hand.R").origin
	var mao_r: Vector3 = rod.osso_global("hand.R").origin
	lant.rotation = Vector3.ZERO
	if fr < F_THROW:
		p_lant = mao_p + Vector3(0, -0.28, 0)
		lant.rotation.z = sin(t * 7.0) * 0.15
	elif fr < F_CATCH:
		var u: float = (fr - F_THROW) / float(F_CATCH - F_THROW)
		var a := P0 + Vector3(0.2, 1.05, 0.1)
		var b := R0 + Vector3(0.05, 1.25, 0.05)
		p_lant = arco(a, b, u, 1.6)
		lant.rotation = Vector3(u * 7.0, u * 2.0, u * 3.0)
		r_lant = 1.4
		# rastro do Lance (Ouro velho)
		rastro_pts.clear()
		for k in 12:
			var uk := u - k * 0.025
			if uk > 0.0:
				rastro_pts.append([arco(a, b, uk, 1.6) + Vector3(0, 0.15, 0), 1.6 - k * 0.12])
	elif fr < F_C:
		p_lant = mao_r + Vector3(0, -0.25, 0)
		r_lant = 1.6
		rastro_pts.clear()
	elif fr == F_C:
		p_lant = LP + Vector3(0, -0.06, 0)
		r_lant = 1.6
		rastro_pts.clear()
	else:
		rastro_pts.clear()
		p_lant = LP + Vector3(0, -0.06, 0)
		lant.rotation.z = 0.2
		r_lant = 1.6 + clamp((fr - F_C) / 40.0, 0.0, 1.0) * 1.4
	lant.position = p_lant
	# --- Fagulha: da mão esquerda do Pavieiro até o óleo, rastro de faíscas
	if fr >= F_SPARK and fr < F_C:
		var u: float = (fr - F_SPARK) / float(F_C - F_SPARK)
		var a: Vector3 = pv.osso_global("hand.L").origin if fr == F_SPARK else P0 + Vector3(0.45, 0.65, 0.15)
		var b := CF + Vector3(-0.4, 0.15, 0.0)
		for k in 14:
			var uk := u - k * 0.018
			if uk > 0.0 and rastro_pts.size() < 40:
				rastro_pts.append([arco(a, b, uk, 0.7), 2.4 - k * 0.15])
	vfx.passo_rastro(t, rastro_pts)
	# --- Fuligentos: telegrafia (agacha, olhos em fenda), pulo, frente de pincel, susto, voam para trás
	var rf := raio_frente(t)
	for i in fpos.size():
		var b = inimigos[i]
		var p0: Vector3 = fpos[i]
		var alvo: Vector3 = (R0 - p0).normalized()
		var d0: float = (p0 - CF).length()
		var longe := i >= 4
		var olho := 0.0
		if longe:
			var ag: int = (fr + i * 17) % 120
			b.pose("acao", (min(ag, 34) if ag < 70 else 8) / 60.0)
			olho = 1.0 if (ag > 12 and ag < 70) else 0.0
			b.position = p0 + alvo * min(fr / 300.0, 0.6)
		else:
			var thit: float = F_C / 60.0 + tempo_frente(d0 - 0.3)
			var fl := fr - 70
			if t < thit:
				var at: float = clamp(fr - 34, 0, 47)
				b.pose("acao", at / 60.0)
				olho = 1.0 if (fr > 40) else 0.0
				var u: float = clamp(fl / 34.0, 0.0, 1.0)
				b.position = arco(p0, p0 + alvo * 2.0, u, 0.75) if fl > 0 else p0
				fdados[i] = {"pos": b.position, "u": u}
			else:
				var a2 := t - thit
				b.pose("acao", (48 + a2 * 60.0) / 60.0)
				olho = 0.0
				var ph: Vector3 = fdados[i].get("pos", p0)
				var fora: Vector3 = (ph - CF); fora.y = 0; fora = fora.normalized()
				var u: float = clamp(a2 / 0.65, 0.0, 1.0)
				var dest := ph + fora * 2.2
				dest.y = 0.0
				b.position = arco(ph, dest, u, 0.55)
				if u >= 1.0:
					b.rotation.x = -1.2
			b.param(["olho"], "fenda", olho)
		b.param(["olho"], "fenda", olho)
	# --- Apagador: Abafar sobre a lanterna; a telegrafia se fecha; a frente o pinta pela metade e ele recua
	var ap = inimigos[fpos.size()]
	ap.pose("acao", clamp(fr - 18, 0, 400) / 60.0)
	var fecha: float = clamp(0.2 + fr / 170.0, 0.0, 0.52)
	var t_ap := F_C / 60.0 + tempo_frente((A0 - CF).length() - 0.2)
	var quebra: float = clamp((t - t_ap) / 0.25, 0.0, 1.0) if t > t_ap else 0.0
	mats_fx["tele"].set_shader_parameter("fecha", fecha)
	mats_fx["tele"].set_shader_parameter("quebra", quebra)
	vfx.marcas["tele"].visible = quebra < 0.98
	if t > t_ap:
		ap.position = A0 + (A0 - CF).normalized() * 0.35 * clamp((t - t_ap) / 0.8, 0.0, 1.0)
	# --- anéis de jogador seguem os heróis
	vfx.marcas["anel_rod"].position = Vector3(rod.position.x, 0.12, rod.position.z)
	# --- Labareda: frente de pincel (luz que cresce), fogo, brasas, vapor, gotas de tinta, óleo queimando
	# a borda molhada da máscara de luz já é a frente de pincel; o anel decalcado da v1 saiu
	vfx.marcas["frente"].visible = false
	if vfx.marcas["frente"].visible:
		var s: float = max(rf, 0.1) * 2.0 / 0.9
		vfx.marcas["frente"].scale = Vector3(s, 1, s)
		mats_fx["frente"].set_shader_parameter("semente", floor(t * 12.0))
	for o in oleos:
		var d: float = (o[1] - CF).length()
		var q: float = clamp((t - F_C / 60.0 - tempo_frente(max(d - 0.6, 0.0))) / 0.15, 0.0, 1.0)
		o[0].set_shader_parameter("queima", q)
		o[0].set_shader_parameter("tempo", t)
	vfx.passo_fogo(t)
	var tc := F_C / 60.0
	vfx.passo_brasas(t, CF, tc if t > tc else -1.0, 1.4)
	vfx.passo_vapor(t, CF, tc + 0.15 if t > tc else -1.0, 1.2)
	vfx.passo_gotas(t, CF, tc, 4.0)
	vfx.passo_vagalumes(t, Vector3(piv.x, 0, piv.z))
	vfx.evitar([rod.global_position, pv.global_position])
	vfx.passo_chuva(t, Vector3(piv.x, 0, piv.z))
	vfx.passo_mariposas(t, [Vector3(1.0, 1.5, -24.0), Vector3(6.4, 4.0, -25.0), Vector3(-2.0, 2.5, -24.5), CF + Vector3(0, 1.2, 0)])
	var aceso: float = clamp((t - tc) / 0.3, 0.0, 1.0) * (1.0 - clamp((t - tc - 2.0) / 2.0, 0.0, 0.6))
	mats_fx["nv8a"].set_shader_parameter("aceso", aceso * 0.4)
	mats_fx["nv25"].set_shader_parameter("aceso", 0.0)
	# --- luzes de pavio (uniforme global, até 8)
	# cada grupo de chamas acende a máscara de luz com tremor (o fogo abre guache no chão)
	var fl := 1.0 + 0.05 * sin(t * 19.0) + 0.04 * sin(t * 31.0 + 1.3)
	var luz_fogo := rf * fl if t > tc else 0.0
	var acf: float = clamp((t - tc - 0.1) / 0.3, 0.0, 1.0)
	set_pavio([Vector4(1.0, 1.5, -25.2, arg("halo", 15.0)), Vector4(p_lant.x, 0.5, p_lant.z, r_lant), Vector4(CF.x, 0.3, CF.z, luz_fogo),
			   Vector4(-7.0, 3.5, -25.4, 6.0), Vector4(2.5, 0.3, 0.95, 2.0 * acf * (1.0 + 0.07 * sin(t * 27.0))),
			   Vector4(2.3, 0.3, -0.3, 1.8 * acf * (1.0 + 0.07 * sin(t * 23.0 + 2.0)))] + luzes_poi(t))
	if pc:
		luzes["lant"].position = p_lant + Vector3(0, 0.3, 0)
		luzes["fogo"].light_energy = 3.5 * clamp((t - tc) / 0.15, 0.0, 1.0) * (1.0 + 0.15 * sin(t * 23.0) + 0.08 * sin(t * 41.0))
		luzes["fogo2"].light_energy = 1.4 * acf * (1.0 + 0.2 * sin(t * 27.0))
		luzes["fogo3"].light_energy = 1.2 * acf * (1.0 + 0.2 * sin(t * 23.0 + 2.0))
		luzes["farol"].rotation = Vector3(deg_to_rad(-9.0), deg_to_rad(-30.0 + 18.0 * sin(t * 0.35)) - PI / 2, 0)
	# --- câmera: tremor por trauma² e um empurrão na direção do golpe
	if fr == F_CATCH: trauma = max(trauma, 0.3)
	if fr == F_C: trauma = 0.75
	trauma = max(trauma - 1.0 / 60.0 * 1.4, 0.0)
	var k := trauma * trauma
	var empurra: float = clamp((t - tc) / 0.25, 0.0, 1.0) * exp(-max(t - tc, 0.0) * 1.2)
	var off := Vector3((h1(fr, 1) - 0.5) * 0.5 * k, (h1(fr, 2) - 0.5) * 0.4 * k, 0) + (CF - piv).normalized() * 0.35 * empurra
	cam.global_transform = cam_base.translated(off)
	cam.rotate_object_local(Vector3(0, 0, 1), (h1(fr, 3) - 0.5) * 0.02 * k)

func cena_poses() -> void:
	ambiente(Color(arg("bg", "#d8ccb0")))
	base_luz(arg("az", -135.0), arg("el", 50.0))
	var w: String = arg("who", "rodeira")
	var an: String = arg("anim", "eixo")
	var qs: Array = String(arg("q", "0,30,45,50,60,65,80,105")).split(",")
	var dx: float = arg("dx", 1.0)
	var cores := {"rodeira": "carmim", "pavieiro": "ouro", "sineira": "celeste", "gatuno": "lilas"}
	for i in qs.size():
		var b = Boneco.new()
		add_child(b)
		b.setup(w, cores.get(w, ""))
		b.position = Vector3((i - (qs.size() - 1) / 2.0) * dx, 0, 0)
		b.rotation_degrees.y = arg("yaw", 30.0)
		b.param(["cor", "metal", "contorno"], "forcar", Vector4(1, 0, 0, 0))
		b.pose(an, float(qs[i]) / 60.0)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = arg("size", 1.6)
	add_child(cam)
	cam.rotation_degrees = Vector3(-float(arg("pitch", 20.0)), 0, 0)
	cam.position = Vector3(0, float(arg("cy", 0.55)), 0) + cam.global_transform.basis.z * 20.0
	cam.current = true

# ------------------------------------------------------------------ quadro de estresse (prévia web, Compatibility)
var est := false
var est_dados := {}
var mascara := false

func cena_estresse() -> void:
	est = true
	mascara = arg("mascara", 0) == 1
	pc = false
	cam = Camera3D.new()
	cam.fov = 30.0; cam.near = 0.5; cam.far = 900.0
	add_child(cam); cam.current = true
	piv = Vector3(arg("px", 0.6), 0.0, arg("pz", 0.2))
	cam_dist = arg("dist", 16.5); cam_pitch = arg("pitch", 52.0)
	por_camera()
	if mascara:
		ambiente(Color.BLACK)
	else:
		ambiente_brejo()
		base_luz(arg("az", -70.0), arg("el", 40.0), 1.0)
		sol.directional_shadow_max_distance = 60.0
		sol.shadow_enabled = arg("sombra", 1) == 1
		sol.light_color = Color("#c9b8c8")
		mundo = Mundo.new(); add_child(mundo); mundo.construir({"pc": false, "lite": true})
		vfx = Vfx.new(); add_child(vfx); vfx.iniciar(false, true)
	var hpos := {"rodeira": [Vector3(0.2, 0, 0.6), 60.0, "espera", 0.0], "pavieiro": [Vector3(-3.8, 0, 1.4), 70.0, "lance", 0.62],
				 "sineira": [Vector3(-1.4, 0, -1.6), 20.0, "badalada", 1.0], "gatuno": [Vector3(3.4, 0, 2.0), 110.0, "bote", 0.32]}
	var ids := {"rodeira": 60, "pavieiro": 110, "sineira": 160, "gatuno": 210}
	var cj := {"rodeira": "carmim", "pavieiro": "ouro", "sineira": "celeste", "gatuno": "lilas"}
	var simb := {"rodeira": 0, "pavieiro": 1, "sineira": 2, "gatuno": 3}
	for n in hpos:
		var b = Boneco.new(); add_child(b)
		if mascara:
			b.setup(n, "", Color8(255, 0, ids[n]))
		else:
			b.setup(n, cj[n]); b.springs_default()
		b.position = hpos[n][0]; b.rotation_degrees.y = hpos[n][1]
		herois[n] = b
		if not mascara:
			vfx.marca("anel_" + n, 1, hpos[n][0] + Vector3(0, 0.12, 0), 1.2, cores_j[n], {"simbolo": simb[n]})
	# 20 inimigos: 17 Fuligentos e 3 Apagadores, em volta, saindo da Treva
	var ens := []
	for i in 17:
		var a := -0.9 + i * 0.42 + h1(i, 1) * 0.2
		var r := 3.6 + h1(i, 2) * 3.4
		ens.append(["fuligento", Vector3(0.6 + cos(a) * r * 1.25, 0, 0.2 + sin(a) * r * 0.62)])
	ens.append(["apagador", Vector3(-5.6, 0, -1.4)]); ens.append(["apagador", Vector3(6.3, 0, -1.6)]); ens.append(["apagador", Vector3(1.4, 0, -3.3)])
	for j in ens.size():
		var b = Boneco.new(); add_child(b)
		if mascara:
			b.setup(ens[j][0], "", Color8(0, 255, 40 + j * 9))
		else:
			b.setup(ens[j][0]); b.springs_default()
		b.position = ens[j][1]
		b.rotation.y = yaw_para(Vector3(0.4, 0, 0.4) - ens[j][1])
		if ens[j][0] == "fuligento":
			b.scale = Vector3.ONE * (0.85 + 0.25 * h1(j, 5))
		inimigos.append(b)
	est_dados["ens"] = ens
	if mascara:
		return
	# sombras de contato em disco (a prévia web desliga a sombra do motor)
	if arg("sombra", 1) == 0:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
		var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
		var dm := ShaderMaterial.new(); dm.shader = load("res://shaders/chao_fx.gdshader"); dm.set_shader_parameter("tipo", 8)
		pm.material = dm
		mm.mesh = pm
		var todos := herois.values() + inimigos
		mm.instance_count = todos.size()
		for i in todos.size():
			var k := 1.6 if todos[i].nome == "apagador" else (1.5 if todos[i].heroi else 0.9)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(k, 1, k * 0.8)), todos[i].position + Vector3(0.05, 0.1, 0.0)))
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.custom_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
		add_child(mmi)
	lant = Mundo.carregar("lanterna"); add_child(lant); lant.position = Vector3(0.75, -0.05, 0.85); lant.rotation.z = 0.2
	# efeito 1: Labareda no óleo; efeito 2: Badalada Funda (onda do sino, chão consagrado); efeito 3: Pederneira na poça (faíscas)
	var oil := [[Vector3(1.6, 0.03, 0.0), 1.4], [Vector3(2.4, 0.03, 0.6), 1.1], [Vector3(2.2, 0.03, -0.7), 1.0], [Vector3(1.0, 0.03, -0.4), 0.8]]
	var cs := []; var hs := []
	for i in 14:
		var o: Array = oil[i % oil.size()]
		var a := h1(i, 7) * TAU; var r := sqrt(h1(i, 8)) * float(o[1]) * 0.36
		cs.append(Vector3(o[0].x + cos(a) * r, 0.02, o[0].z + sin(a) * r)); hs.append(0.8 + h1(i, 6) * 0.9)
	for i in oil.size():
		var mt = vfx.marca("oleo%d" % i, 0, oil[i][0], oil[i][1], cores_j["rodeira"], {"semente": float(i) * 3.7, "queima": 1.0})
	vfx.criar_fogo(cs, hs, 0.0)
	mats_fx["sino"] = vfx.marca("sino", 5, herois["sineira"].position + Vector3(0, 0.14, 0), 7.0, Color("#e8e4da"), {"semente": 1.0})
	mats_fx["sal"] = vfx.marca("sal", 6, herois["sineira"].position + Vector3(0, 0.12, 0), 3.4, Color("#e8e4da"), {"semente": 2.0})
	mats_fx["faisca"] = vfx.marca("faisca", 7, Vector3(4.6, 0.12, 1.8), 2.6, cores_j["gatuno"], {"semente": 3.0})
	for k in 3:
		var alvo: Vector3 = [Vector3(-3.8, 0, 1.4), Vector3(0.75, 0, 0.85), Vector3(3.4, 0, 2.0)][k]
		vfx.marca("tele%d" % k, 2, alvo + Vector3(0, 0.13, 0), 2.4, Color.WHITE, {"fecha": [0.35, 0.6, 0.2][k]})
	var vp := Vector2(1280, 720)
	var sc := get_viewport().get_visible_rect().size / vp
	vfx.nevoa(cam.project_position(Vector2(640, 175) * sc, 25.0), Vector2(30.0, 2.6), cam.global_position, {"alfa": 0.5, "vel": 0.5, "semente": 7.0, "curva": 0.0, "freq_linhas": 30.0})
	vfx.nevoa(cam.project_position(Vector2(640, 92) * sc, 80.0), Vector2(110.0, 7.0), cam.global_position, {"alfa": 0.6, "vel": 0.2, "semente": 11.0, "curva": 0.0, "freq_linhas": 34.0})
	vfx.bruma(Vector3(piv.x, 0.2, piv.z - 2.0), Vector2(36, 22), {"alfa": 0.32, "vel": 0.6, "semente": 3.0, "freq_linhas": 70.0, "luz_alfa": 0.12})

func passo_estresse(fr: int) -> void:
	var t := 2.0 + fr / 60.0
	RenderingServer.global_shader_parameter_set("ferve", floor(t * 8.0))
	RenderingServer.global_shader_parameter_set("vento", Vector4(0.9, 0.25, 0.6, t))
	var hp := {"rodeira": ["espera", 0.0], "pavieiro": ["lance", 0.62], "sineira": ["badalada", 1.0], "gatuno": ["bote", 0.33]}
	for n in hp:
		herois[n].pose(hp[n][0], hp[n][1] + fr / 600.0)
	var ens: Array = est_dados["ens"]
	for j in ens.size():
		var b = inimigos[j]
		if ens[j][0] == "fuligento":
			var ag := (fr * 2 + j * 23) % 80
			b.pose("acao", float(min(ag, 50)) / 60.0)
			b.param(["olho"], "fenda", 1.0 if ag > 12 and ag < 50 else 0.0)
		else:
			b.pose("acao", 0.6)
	if mascara:
		return
	mundo.passo(t)
	vfx.passo_fogo(t)
	vfx.passo_brasas(t, Vector3(1.8, 0, 0.0), 0.0, 1.2)
	vfx.passo_vapor(t, Vector3(1.8, 0, 0.0), 1.9, 1.0)
	vfx.passo_chuva(t, Vector3(piv.x, 0, piv.z))
	vfx.passo_mariposas(t, [Vector3(1.0, 1.5, -24.0), Vector3(1.8, 0.8, 0.0)])
	vfx.passo_vagalumes(t, Vector3(piv.x, 0, piv.z))
	var hp_pos := []
	for n in herois:
		hp_pos.append(herois[n].global_position)
	vfx.evitar(hp_pos)
	var sp := []
	for k in 16:
		var a := h1(k + fr, 3) * TAU
		sp.append([Vector3(4.6 + cos(a) * h1(k, 4) * 1.0, 0.15 + h1(k + fr, 5) * 0.5, 1.8 + sin(a) * h1(k, 4) * 0.6), 1.6])
	vfx.passo_rastro(t, sp)
	mats_fx["sino"].set_shader_parameter("tempo", t)
	mats_fx["faisca"].set_shader_parameter("tempo", t)
	set_pavio([Vector4(1.0, 1.5, -25.2, 15.0), Vector4(0.75, 0.5, 0.85, 3.0), Vector4(1.8, 0.3, 0.0, 4.2), Vector4(-1.4, 0.4, -1.6, 2.6), Vector4(-7.0, 3.5, -25.4, 6.0), Vector4(0, 0, 0, 0)] + luzes_poi(t))
	if fr == frames - 1:
		print("PROBE draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objetos=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " prim=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
