extends Node3D
# Prova de estilo "Tralha da Cheia": monta as cenas por código e captura quadros.
# Args (depois de --): cena=folha|poses|duelo|estresse|colisao  out=arquivo.png  frames=N  (ver cada cena)

const Boneco = preload("res://boneco.gd")
const Cenario = preload("res://cenario.gd")
const Vfx = preload("res://vfx.gd")
var cen
var vfx
const COR := {"marola": Color("#D9452B"), "piaba": Color("#2C63D6"), "remanso": Color("#53B83A"), "breu": Color("#8E3FA8")}
const VERSO := {"marola": Color("#7a2416"), "piaba": Color("#16336f"), "remanso": Color("#2c6a1f"), "breu": Color("#4c2059")}
const SIMB := {"marola": 0, "piaba": 1, "remanso": 2, "breu": 3}
const LAMA := Color("#5E4E44")
const CREME := Color("#EDE1C6")
const ESCALA_BUCHO := [1.0, 1.15, 0.85, 1.2, 0.8, 1.05, 0.9]   # v2: Buchos de tamanhos diferentes (0,8 a 1,2)

# v2: herói jogável ganha recorte na cor do dono (facetas de borda) e um fio de contorno colorido por fora do preto
func marca_jogador(b, cor: Color, px := 2.8) -> void:
	if A("rim", "1") != "1":
		return
	b.todos("rim_jog", cor)
	b.todos("rim_jog_amt", float(A("rim_amt", "0.45")))
	if A("fio", "0") == "1" and b.mats.has("contorno"):
		for m in b.mats["contorno"]:
			var m2 := ShaderMaterial.new()
			m2.shader = m.shader
			m2.set_shader_parameter("px_1080", px + float(A("fio_px", "1.8")))
			var vc: Color = cor
			for k in COR:
				if COR[k] == cor and A("fio_cor", "verso") == "verso":
					vc = VERSO[k]
			m2.set_shader_parameter("ink_col", vc)
			m.next_pass = m2
var args := {}
var cam: Camera3D
var frame_i := 0
var frames := 6
var cena := ""
var sun: DirectionalLight3D
var we: WorldEnvironment

func A(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d

func _ready() -> void:
	cena = A("cena", "folha")
	frames = int(A("frames", "6"))
	_env(Color(A("bg", "#3b3a48")))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	match cena:
		"folha":
			_folha()
		"poses":
			_poses()
		"teste":
			_teste()
		"duelo":
			_duelo()
		"estresse":
			_estresse()
		"colisao":
			_colisao()

func _env(bg: Color) -> void:
	we = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.BLACK
	e.ambient_light_energy = 0.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = e
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = float(A("sol_e", "1.0"))
	sun.light_color = Color(A("sol_cor", "#fff0d8"))
	sun.shadow_enabled = false
	add_child(sun)
	sun.look_at_from_position(Vector3(-6, 8, 6), Vector3.ZERO)

func boneco(n: String, pos: Vector3, yaw: float, anim := "", t := 0.0):
	var b = Boneco.new()
	add_child(b)
	b.setup(n)
	b.position = pos
	b.rotation.y = deg_to_rad(yaw)
	if anim != "":
		b.pose(anim, t)
	return b

func _folha() -> void:
	var who := A("who", "marola,piaba").split(",")
	var yaws := [0.0, 35.0, 90.0]
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	var n := who.size() * 3
	var dx := float(A("dx", "1.0"))
	cam.size = n * dx
	var cx := (n - 1) * dx * 0.5
	var pit := deg_to_rad(float(A("pitch", "8")))
	var cy := float(A("cy", "0.7"))
	cam.look_at_from_position(Vector3(cx, cy + 20.0 * sin(pit), 20.0 * cos(pit)), Vector3(cx, cy, 0))
	var k := 0
	for w in who:
		for y in yaws:
			var bb = boneco(w, Vector3(k * dx, 0, 0), y, A("anim", ""), 0.001)
			if A("arma", "") != "" and bb.skel and bb.skel.find_bone("prop") >= 0:
				var ar = Boneco.new(); add_child(ar); ar.setup(A("arma", "remo")); bb.segurar(ar)
			k += 1

func nivel_pc() -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 0.5
	var e: Environment = we.environment
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 0.95
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.fog_enabled = A("nevoa", "1") == "1"
	e.fog_light_color = Color("#e9d2b0")
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_density = float(A("nevoa_d", "0.55"))
	e.fog_depth_begin = float(A("nevoa_ini", "11.0"))
	e.fog_depth_end = float(A("nevoa_fim", "30.0"))
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = float(A("contraste", "1.06"))
	e.adjustment_saturation = float(A("saturacao", "1.06"))

func camarote(alvo: Vector3, dist: float, pitch := 38.0, yaw := 0.0, fov := 30.0) -> void:
	cam.fov = fov
	var d := Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))) * dist
	d = d.rotated(Vector3.UP, deg_to_rad(yaw))
	cam.look_at_from_position(alvo + d, alvo)

func sol(az: float, el: float) -> void:
	# az: de onde vem a luz, em graus (0 = da câmera, 90 = da direita, -90 = da esquerda, 180 = do fundo)
	var d := Vector3(sin(deg_to_rad(az)) * cos(deg_to_rad(el)), sin(deg_to_rad(el)), cos(deg_to_rad(az)) * cos(deg_to_rad(el)))
	sun.look_at_from_position(d * 20.0, Vector3.ZERO)

func _teste() -> void:
	if A("pc", "0") == "1":
		nivel_pc()
	sol(float(A("az", "-120")), float(A("el", "34")))
	cen = Cenario.new(); add_child(cen); cen.montar()
	cen.passo(0.0)
	camarote(Vector3(float(A("tx", "0")), 0.3, float(A("tz", "0"))), float(A("dist", "11")), float(A("pitch", "38")), float(A("yaw", "0")))
	var m = boneco("marola", Vector3(1.4, 0, 0.4), -100, "remada", 12.0 / 60.0)
	var ar = Boneco.new(); add_child(ar); ar.setup("remo"); m.segurar(ar)
	var pb = boneco("piaba", Vector3(-2.4, 0, 0.9), 70, "arremesso", 19.0 / 60.0)
	for k in 3:
		boneco("bucho", Vector3(3.2 + k * 0.9, 0, -0.6 + k * 0.8), -90 + k * 20, "incha", 0.5)
	boneco("gaiola", Vector3(-0.2, 0, -1.4), 20, "abre", 0.4)
	boneco("lata", Vector3(5.5, 0, 1.6), -60, "treme", 0.2)

func _poses() -> void:
	var who := A("who", "marola")
	var an := A("anim", "malho")
	var fr := A("f", "0,6,12,32,33,40,52").split(",")
	var yaw := float(A("yaw", "30"))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	var dx := float(A("dx", "1.9"))
	cam.size = fr.size() * dx
	var cx := (fr.size() - 1) * dx * 0.5
	var pit := deg_to_rad(float(A("pitch", "20")))
	var cy := float(A("cy", "0.8"))
	cam.look_at_from_position(Vector3(cx, cy + 20.0 * sin(pit), 20.0 * cos(pit)), Vector3(cx, cy, 0))
	for k in fr.size():
		var b = boneco(who, Vector3(k * dx, 0, 0), yaw, an, float(fr[k]) / 60.0 + 0.0005)
		if A("arma", "") != "":
			var ar = Boneco.new(); add_child(ar); ar.setup(A("arma", "remo")); b.segurar(ar)
	var chao := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 6); chao.mesh = pm
	var m := StandardMaterial3D.new(); m.albedo_color = Color("#c9b68f"); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; chao.material_override = m
	chao.position = Vector3(cx, -0.002, 0)
	add_child(chao)

func _process(_d: float) -> void:
	frame_i += 1
	if cena == "duelo":
		var alvo := sim_ate if sim_ate >= 0 else frame_i
		while sim_f < alvo:
			_tick(sim_f)
			sim_f += 1
		if sim_ate >= 0:
			if frame_i < 3:
				return
		else:
			if frame_i >= frames:
				get_tree().quit()
			return
	elif cena == "estresse":
		if frame_i < frames:
			if frame_i == 1:
				_estresse_sim()
			return
	elif frame_i < frames:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(A("out", "/tmp/out.png"))
	print("PROBE draws=%d prims=%d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()

# ================================================================== o duelo: passe, pegada no ar, Despedida e recepção
# Linha do tempo única (quadros a 60 fps) usada pelo clipe e pelo quadro bonito.
var sim_f := 0
var sim_ate := -1
var beauty := false
var atores := {}          # nome -> {b, anim, lt, freeze}
var eventos := {}         # quadro -> Array[Callable]
var trauma := 0.0
var cam_base: Transform3D
var cam_fov := 30.0
var zoom_q := 0
var voo := {}             # arma no ar
var remo
var malho
var marcadores := {}
var sombras := []
var perigo_bb: ShaderMaterial
var perigo_lata: ShaderMaterial
var bb_voo := {}
var ultimo_pts := {}

func ev(f: int, c: Callable) -> void:
	if not eventos.has(f):
		eventos[f] = []
	eventos[f].append(c)

func ator(nome: String, modelo: String, pos: Vector3, yaw: float, anim: String, lt := -1) -> Dictionary:
	var b = boneco(modelo, pos, yaw, anim, float(max(lt, 0)) / 60.0 + 0.0005)
	b.springs_default()
	var d := {"b": b, "anim": anim, "lt": lt, "freeze": 0, "loop": anim in ["idle", "treme"]}
	atores[nome] = d
	# sombra de contato (base do Compatibility) e marcador de jogador
	var sz := 1.0 if modelo in ["marola", "piaba", "remanso", "breu"] else (1.1 if modelo == "gaiola" else 0.85)
	var sm: MeshInstance3D = vfx.quad_chao(Vector2(sz, sz * 0.8), pos + Vector3(0, 0.012, 0), vfx.mat("sombra", {"forca": 0.8 if beauty else 1.0}))
	sombras.append([sm, b])
	if COR.has(modelo):
		marca_jogador(b, COR[modelo])
		var mk: MeshInstance3D = vfx.quad_chao(Vector2(1.5, 1.5), pos + Vector3(0, 0.02, 0), vfx.mat("anel", {"cor": COR[modelo], "modo": 0, "simbolo": SIMB[modelo], "raio": 0.78, "esp": 0.07}))
		marcadores[nome] = mk
	return d

func anim(nome: String, a: String, lt := 0) -> void:
	var d: Dictionary = atores[nome]
	d["anim"] = a; d["lt"] = lt - 1
	d["loop"] = a in ["idle", "treme"]

func pontos_arma(b, arma_nome: String, gt = null) -> Array:
	var T: Transform3D = gt if gt != null else b.osso_global("prop")
	var ys := [0.0, 0.3, 0.6, 0.9, 1.1, 1.25, 1.38] if arma_nome == "remo" else [0.0, 0.3, 0.6, 0.75, 0.88]
	var out := []
	for y in ys:
		out.append(T * Vector3(0, y, 0))
	return out

func _duelo() -> void:
	beauty = A("beauty", "0") == "1"
	sim_ate = int(A("quadro", "-1"))
	if A("pc", "0") == "1":
		nivel_pc()
	sol(float(A("az", "-125")), float(A("el", "36")))
	cen = Cenario.new(); add_child(cen); cen.montar()
	vfx = Vfx.new(); add_child(vfx); vfx.cam = cam
	if A("msaa", "") == "4":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	# --- elenco
	var M := ator("M", "marola", Vector3(0.4, 0, 0.3), 20, "malho")
	var P := ator("P", "piaba", Vector3(-2.7, 0, 0.9), float(A("yaw_p", "-35")), "idle")
	var BA := ator("BA", "bucho", Vector3(0.75, 0, 1.25), -160, "idle")
	var BB := ator("BB", "bucho", Vector3(1.9, 0, 1.3), -124, "idle", 10)
	BB["b"].scale = Vector3.ONE * 1.12
	var BC := ator("BC", "bucho", Vector3(-1.2, 0, -1.6), 30, "idle", 25)
	BC["b"].scale = Vector3.ONE * 0.85
	ator("G", "gaiola", Vector3(-5.0, 0, -0.9), 60, "idle", 5)
	ator("L", "lata", Vector3(4.6, 0, -1.45), -90, "treme")
	malho = Boneco.new(); add_child(malho); malho.setup("malho"); M["b"].segurar(malho)
	remo = Boneco.new(); add_child(remo); remo.setup("remo"); P["b"].segurar(remo)
	# telegrafias: faixa listrada que se fecha (Bucho B) e rota da Lata-Velha
	perigo_bb = vfx.mat("perigo", {"modo": 0, "progresso": 0.0, "tam": 0.9})
	var pz: MeshInstance3D = vfx.quad_chao(Vector2(1.6, 1.6), BB["b"].position + Vector3(0, 0.025, 0), perigo_bb)
	pz.visible = false
	BB["perigo"] = pz
	perigo_lata = vfx.mat("perigo", {"modo": 1, "progresso": 0.0, "tam": 1.1})
	var lz: MeshInstance3D = vfx.quad_chao(Vector2(4.4, 0.9), Vector3(2.05, 0.024, -1.45), perigo_lata, 180)
	if A("lata", "1") == "0":
		lz.visible = false
		atores["L"]["b"].visible = false
	# --- câmera
	var tx := float(A("tx", "-0.9")); var ty := float(A("ty", "0.4")); var tz := float(A("tz", "0.7"))
	cam_fov = float(A("fov", "30"))
	camarote(Vector3(tx, ty, tz), float(A("dist", "10.5")), float(A("pitch", "38")), float(A("yaw", "0")), cam_fov)
	cam_base = cam.global_transform
	# --- eventos
	ev(46, func(): anim("BB", "incha"); BB["perigo"].visible = true)
	ev(20, func(): anim("P", "arremesso"))
	ev(40, _solta_remo)
	ev(33, _despedida_contato)
	ev(47, _despedida_estouro)
	ev(48, func(): vfx.balao(M["b"], 1.9, COR["marola"], 24, Vector3(0.6, 0, 0.1)))
	ev(50, func():
		# "me passa!": vira para o Piaba e abre os braços, pedindo a arma
		anim("M", "mepassa")
		M["b"].rotation.y = deg_to_rad(float(A("yaw_pede", "-25")))
	)
	ev(62, func():
		# vira para quem lançou (meio caminho entre o Piaba e a câmera) antes de pegar
		anim("M", "pegada")
		M["b"].rotation.y = deg_to_rad(float(A("yaw_pega", "-40")))
	)
	ev(67, _pegada)
	ev(78, _vira_para_bb)
	ev(109, _smear_remada)
	ev(32, func(): _smear_generico("M", "malho", 33, COR["marola"], VERSO["marola"]))
	ev(39, func(): _smear_generico("P", "arremesso", 19, COR["piaba"], VERSO["piaba"]))
	ev(110, _recepcao_contato)
	ev(123, _bb_voa)
	ev(70, func(): anim("P", "idle"))
	ev(128, func(): anim("P", "comemora"))
	ev(168, func(): anim("P", "idle"))
	ev(180, func(): anim("M", "idle"))
	if beauty:
		_extras_beauty()

func _beauty_pos() -> void:
	# v2: acabamento do quadro bonito: vinheta leve de valor, desfoque de perto (primeiro plano) e contraluz quente
	var cl := CanvasLayer.new(); add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/vinheta.gdshader")
	sm.set_shader_parameter("forca", float(A("vinheta", "0.22")))
	cr.material = sm
	cl.add_child(cr)
	if A("dof", "1") == "1":
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_near_enabled = true
		ca.dof_blur_near_distance = float(A("dof_perto", "4.2"))
		ca.dof_blur_near_transition = float(A("dof_trans", "1.2"))
		ca.dof_blur_amount = float(A("dof_amt", "0.12"))
		cam.attributes = ca
	var cdir := Vector3(sin(deg_to_rad(float(A("cl_az", "160")))), 0.45, cos(deg_to_rad(float(A("cl_az", "160"))))).normalized()
	for n in atores:
		var b = atores[n]["b"]
		b.todos("contraluz", float(A("contraluz", "0.6")) * (1.0 if COR.has(b.nome) else 0.5))
		b.todos("contraluz_dir", cdir)
	# Bucho escuro em primeiro plano, desfocado: profundidade
	if A("fg", "1") == "1":
		var bf := ator("BF", "bucho", Vector3(float(A("fg_x", "-3.4")), 0, float(A("fg_z", "3.3"))), float(A("fg_yaw", "40")), "idle", 7)
		bf["b"].scale = Vector3.ONE * 1.2
		bf["b"].todos("shadow_tint", Color(0.42, 0.38, 0.5))
		bf["b"].todos("mid", 0.5)

func _extras_beauty() -> void:
	_beauty_pos()
	# o mesmo instante do jogo, com o que o quadro (a) da proposta pede a mais: um Bucho que caiu na água
	# rasa (coroa de respingo) e a Gaiola abrindo a porta.
	var bc: Dictionary = atores["BC"]
	ev(int(A("coroa_f", "36")), func():
		vfx.coroa(Vector3(float(A("cx", "-0.3")), -0.5, float(A("cz", "-3.45"))), 1.3)
	)
	ev(30, func(): anim("G", "abre"))

func _solta_remo() -> void:
	var P: Dictionary = atores["P"]
	P["b"].soltar()
	var M: Dictionary = atores["M"]
	var ini: Transform3D = remo.global_transform
	var alvo: Vector3 = M["b"].global_position + Vector3(0.0, 1.62, 0.0) + M["b"].global_transform.basis.x * -0.15
	voo = {"ini": ini, "alvo": alvo, "f": 0, "n": 27}
	vfx.fita(remo, COR["piaba"], VERSO["piaba"], 0.7)

func _tick_voo() -> void:
	if voo.is_empty():
		return
	voo["f"] += 1
	var u := float(voo["f"]) / float(voo["n"])
	var p0: Vector3 = voo["ini"].origin
	var p1: Vector3 = voo["alvo"]
	var p := p0.lerp(p1, u) + Vector3(0, 0.95 * 4.0 * u * (1.0 - u), 0)
	# gira em volta do próprio centro (centro do remo a 0,6 m do punho)
	var dirv := (p1 - p0).normalized()
	var eixo := dirv.cross(Vector3.UP).normalized()
	var ang := -TAU * 1.75 * u
	var b: Basis = Basis(eixo, ang) * voo["ini"].basis
	var centro: Vector3 = b * Vector3(0, 0.6, 0)
	remo.global_transform = Transform3D(b, p - centro)

func _despedida_contato() -> void:
	var M: Dictionary = atores["M"]; var BA: Dictionary = atores["BA"]
	M["freeze"] = 14; BA["freeze"] = 14
	trauma = max(trauma, 0.55)
	var head: Vector3 = M["b"].osso_global("prop") * Vector3(0, 0.75, 0)
	# o Bucho está sob a cabeça do malho: amassa no contato e segura o congelamento
	var fw: Vector3 = M["b"].global_transform.basis.z
	BA["b"].global_position = Vector3(head.x, 0, head.z) + fw * 0.22
	anim("BA", "golpeado")
	vfx.estalo(head + Vector3(0, 0.35, 0), COR["marola"], 1.25, 6)
	BA["b"].todos("flash", 0.8)
	for k in 3:
		ev(34 + k * 3, func(): malho.todos("racha", 0.35 + 0.33 * k))
	for k in 14:
		ev(33 + k, func():
			malho.position = Vector3(0.012 * (1.0 if (k / 2) % 2 == 0 else -1.0), 0, 0)
		)
	ev(35, func(): BA["b"].todos("flash", 0.0))
	ev(39, func(): malho.todos("dois_tons", 1.0); BA["b"].todos("dois_tons", 1.0))
	ev(41, func(): malho.todos("dois_tons", 0.0); BA["b"].todos("dois_tons", 0.0))
	ev(42, func():
		var h: Vector3 = M["b"].osso_global("prop") * Vector3(0, 0.75, 0)
		vfx.lascas(h, [LAMA, CREME, COR["marola"]], 4, 0.5)
	)

func _despedida_estouro() -> void:
	var M: Dictionary = atores["M"]
	var head: Vector3 = M["b"].osso_global("prop") * Vector3(0, 0.75, 0)
	vfx.lascas(head, [COR["marola"], LAMA, CREME, Color("#C2A884")], 12, 1.0, Vector3(0.4, 0, 0.2), 1.0, true)
	vfx.estalo(head + Vector3(0, 0.3, 0), COR["marola"], 1.6, 5)
	malho.visible = false
	trauma = max(trauma, 0.85)
	anim("BA", "panqueca")

func _pegada() -> void:
	var M: Dictionary = atores["M"]
	voo = {}
	M["b"].segurar(remo)
	vfx.anel_pegada(M["b"].global_position, COR["marola"])
	remo.todos("flash", 0.7)
	ev(73, func(): remo.todos("flash", 0.0))
	for it in vfx.itens:
		if it["tipo"] == "fita":
			it["vivo"] = false
	zoom_q = 5
	trauma = max(trauma, 0.25)

func _vira_para_bb() -> void:
	var M: Dictionary = atores["M"]; var BB: Dictionary = atores["BB"]
	var d: Vector3 = BB["b"].global_position - M["b"].global_position
	M["b"].rotation.y = atan2(d.x, d.z)
	anim("M", "remada")

func _smear_remada() -> void:
	var M: Dictionary = atores["M"]
	var b = M["b"]
	var antes: Array = pontos_arma(b, "remo")
	# pose de contato (lt 31) lida do esqueleto e devolvida
	b.pose("remada", 31.0 / 60.0 + 0.0005)
	var depois: Array = pontos_arma(b, "remo")
	b.pose("remada", float(M["lt"]) / 60.0 + 0.0005)
	var piv: Vector3 = b.osso_global("upperarm.R").origin
	vfx.smear(ultimo_pts.get("M", antes), depois, piv, COR["marola"], VERSO["marola"])

func _smear_generico(quem: String, a: String, lt_ct: int, c1: Color, c2: Color) -> void:
	var d: Dictionary = atores[quem]
	var b = d["b"]
	var nome_arma := "malho" if b.arma == malho else "remo"
	var antes: Array = ultimo_pts.get(quem, pontos_arma(b, nome_arma))
	b.pose(a, float(lt_ct) / 60.0 + 0.0005)
	var depois: Array = pontos_arma(b, nome_arma)
	b.pose(a, float(d["lt"]) / 60.0 + 0.0005)
	vfx.smear(antes, depois, b.osso_global("upperarm.R").origin, c1, c2)

func _recepcao_contato() -> void:
	var M: Dictionary = atores["M"]; var BB: Dictionary = atores["BB"]
	M["freeze"] = 12; BB["freeze"] = 12
	anim("BB", "golpeado")
	BB["freeze"] = 12
	trauma = max(trauma, 0.75)
	var tip: Vector3 = M["b"].osso_global("prop") * Vector3(0, 1.15, 0)
	vfx.estalo(tip, COR["marola"], 1.1, 5)
	vfx.lascas(BB["b"].global_position + Vector3(0, 0.5, 0), [Color("#B99189"), CREME, Color("#615650")], 8, 0.7, Vector3(0.6, 0, 0.5), 0.8)
	BB["b"].todos("flash", 0.85)
	BB["perigo"].visible = false
	ev(113, func(): BB["b"].todos("flash", 0.0))

func _bb_voa() -> void:
	var M: Dictionary = atores["M"]; var BB: Dictionary = atores["BB"]
	var d: Vector3 = BB["b"].global_position - M["b"].global_position
	d.y = 0
	d = (d.normalized() * 0.1 + Vector3(0, 0, 1.0)).normalized()
	var p0: Vector3 = BB["b"].global_position
	bb_voo = {"p0": p0, "p1": p0 + d * float(A("voo_bb", "2.15")) + Vector3(0, -0.5, 0), "f": 0, "n": 24}

func _tick_bb() -> void:
	if bb_voo.is_empty():
		return
	bb_voo["f"] += 1
	var u := float(bb_voo["f"]) / float(bb_voo["n"])
	var BB: Dictionary = atores["BB"]
	if u <= 1.0:
		var p: Vector3 = bb_voo["p0"].lerp(bb_voo["p1"], u) + Vector3(0, 1.1 * 4.0 * u * (1.0 - u), 0)
		BB["b"].global_position = p
		# cambalhota em degrau de 3 quadros. v2: compõe pela base, porque somar em rotation.x passa de 90° e o Euler
		# decomposto vira o boneco de cabeça para baixo (era por isso que o Bucho sumia na água na v1)
		if not bb_voo.has("yaw"):
			bb_voo["yaw"] = BB["b"].rotation.y
		var giro := 0.7 * float(bb_voo["f"] / 3)
		BB["b"].basis = (Basis(Vector3.UP, bb_voo["yaw"]) * Basis(Vector3.RIGHT, giro)).scaled(BB["b"].scale)
	if bb_voo["f"] == bb_voo["n"]:
		vfx.coroa(bb_voo["p1"] + Vector3(0, -0.04, 0), 1.0)
		BB["b"].basis = Basis(Vector3.UP, bb_voo["yaw"]).scaled(Vector3.ONE * 1.12)
		trauma = max(trauma, 0.3)
	if u > 1.0:
		# boia de olho arregalado, sobe e desce em degrau com as marolas
		var k: int = (bb_voo["f"] / 10) % 2
		BB["b"].global_position = bb_voo["p1"] + Vector3(0, -0.12 + 0.04 * k, 0)

func _tick(f: int) -> void:
	for n in atores:
		var d: Dictionary = atores[n]
		if d["freeze"] > 0:
			d["freeze"] -= 1
		else:
			d["lt"] += 1
		var b = d["b"]
		var tt := float(d["lt"]) / 60.0
		if d["loop"]:
			var L: float = b.dur(d["anim"])
			if L > 0.0:
				tt = fmod(tt, L)
		b.pose(d["anim"], tt + 0.0005)
		b.mola.time_scale = 0.0 if d["freeze"] > 0 else 1.0
	if eventos.has(f):
		for c in eventos[f]:
			c.call()
	# telegrafias
	var bb: Dictionary = atores["BB"]
	if bb["anim"] == "incha":
		perigo_bb.set_shader_parameter("progresso", clampf(float(f - 46) / 64.0, 0.0, 1.0))
		atores["BB"]["b"].param(["olho"], "raiva", 1.0)
	perigo_lata.set_shader_parameter("progresso", clampf(float(f + 40) / 220.0, 0.0, 1.0))
	perigo_lata.set_shader_parameter("rolagem", float(f / 4) * 0.12)
	perigo_bb.set_shader_parameter("rolagem", float(f / 4) * 0.1)
	_tick_voo()
	_tick_bb()
	for s in sombras:
		var sm: MeshInstance3D = s[0]
		var b = s[1]
		sm.global_position = Vector3(b.global_position.x, 0.012 if b.global_position.y > -0.2 else -0.53, b.global_position.z)
	for n in marcadores:
		marcadores[n].global_position = atores[n]["b"].global_position * Vector3(1, 0, 1) + Vector3(0, 0.02, 0)
	vfx.tick()
	cen.passo(float(f) / 60.0)
	for q in ["M", "P"]:
		var bq = atores[q]["b"]
		if bq.arma != null:
			ultimo_pts[q] = pontos_arma(bq, "malho" if bq.arma == malho else "remo")
	# câmera: tremor por trauma (em degrau de 2 quadros) e zoom leve de 4 quadros no recebedor
	trauma = maxf(0.0, trauma - 0.035)
	var sh := trauma * trauma
	var k := float(f / 2)
	var off := Vector3(sin(k * 12.9898) * 43.7, sin(k * 78.233) * 37.1, 0.0)
	off = Vector3(fposmod(off.x, 2.0) - 1.0, fposmod(off.y, 2.0) - 1.0, 0.0) * 0.16 * sh
	cam.global_transform = cam_base
	cam.translate_object_local(off)
	cam.fov = cam_fov * (0.97 if zoom_q > 0 else 1.0)
	zoom_q = max(0, zoom_q - 1)


# ================================================================== quadro de estresse (Compatibility, 1280x720)
# 4 heróis com cor e símbolo de chão, 20 inimigos, 3 efeitos ao mesmo tempo (Despedida, passe no ar, Boia na água
# com coroa) e as telegrafias. mascara=1 grava a máscara de identificação; mascara=aneis, só os anéis.
var est_mask := ""
var est_remo
func _estresse() -> void:
	est_mask = A("mascara", "")
	sol(float(A("az", "-100")), float(A("el", "40")))
	if est_mask == "":
		cen = Cenario.new(); add_child(cen); cen.montar(); cen.passo(0.4)
	else:
		we.environment.background_color = Color.BLACK
	vfx = Vfx.new(); add_child(vfx); vfx.cam = cam
	camarote(Vector3(float(A("tx", "0.0")), 0.3, float(A("tz", "0.2"))), float(A("dist", "15.5")), float(A("pitch", "38")), float(A("yaw", "0")), float(A("fov", "30")))
	var herois := [["marola", Vector3(1.2, 0, 0.4), float(A("myaw", "-45")), "mepassa", 10], ["piaba", Vector3(-2.2, -0.56, float(A("pz", "3.8"))), 20, "idle", 0],
		["remanso", Vector3(-4.0, 0, 0.0), 80, "golpe", 24], ["breu", Vector3(5.2, 0, 0.9), -70, "golpe", 24]]
	var hid := [60, 110, 160, 210]
	var hn := {}
	for i in herois.size():
		var h: Array = herois[i]
		var b = Boneco.new(); add_child(b)
		if est_mask == "1":
			b.setup(h[0], Color8(255, 0, hid[i]), 2.8)
		else:
			b.setup(h[0])
			marca_jogador(b, COR[h[0]])
		b.position = h[1]; b.rotation.y = deg_to_rad(h[2]); b.pose(h[3], float(h[4]) / 60.0 + 0.0005)
		b.visible = est_mask != "aneis"
		hn[h[0]] = b
		if est_mask != "1":
			var on_water: bool = h[1].y < -0.3
			var mk: MeshInstance3D = vfx.quad_chao(Vector2(2.1, 2.1) if on_water else Vector2(1.5, 1.5), Vector3(h[1].x, (-0.42 if on_water else 0.02), h[1].z), vfx.mat("anel", {"cor": COR[h[0]], "modo": 0, "simbolo": SIMB[h[0]], "raio": 0.78, "esp": 0.07}))
			if on_water and est_mask == "":
				# Boia: espuma creme recortada em volta de quem caiu (lê na água escura)
				vfx.quad_chao(Vector2(1.45, 1.45), Vector3(h[1].x, -0.46, h[1].z + 0.04), vfx.mat("anel", {"cor": Color("#EDE1C6"), "modo": 1, "raio": 0.6, "esp": 0.3, "cortes": 14.0}))
			if est_mask == "aneis":
				pass
		if est_mask == "":
			vfx.quad_chao(Vector2(1.0, 0.8), Vector3(h[1].x, 0.012, h[1].z), vfx.mat("sombra", {})) if h[1].y > -0.3 else null
	# armas: Breu com malho (Despedida), Remanso lançando o remo para a Marola
	if est_mask == "":
		var ml = Boneco.new(); add_child(ml); ml.setup("malho"); hn["breu"].segurar(ml)
		malho = ml
	# 20 inimigos espalhados pelo trapiche (alguns telegrafando)
	var rng := RandomNumberGenerator.new(); rng.seed = int(A("semente", "11"))
	var eid := [60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250]
	var tipos := ["bucho", "bucho", "bucho", "gaiola", "bucho", "lata", "bucho", "gaiola", "bucho", "bucho", "lata", "bucho", "gaiola", "bucho", "bucho", "lata", "bucho", "gaiola", "bucho", "lata"]
	var ocup: Array = [Vector2(1.2, 0.4), Vector2(-4.0, 0.0), Vector2(5.2, 0.9), Vector2(-2.2, 3.8)]
	for j in 20:
		var pos := Vector3.ZERO
		for tent in 200:
			pos = Vector3(rng.randf_range(-8.5, 8.5), 0, rng.randf_range(-2.2, 2.2))
			var ok := true
			for o in ocup:
				if Vector2(pos.x, pos.z).distance_to(o) < 1.25:
					ok = false
			if ok:
				break
		ocup.append(Vector2(pos.x, pos.z))
		var e = Boneco.new(); add_child(e)
		if est_mask == "1":
			e.setup(tipos[j], Color8(0, 255, eid[j]), 2.0)
		else:
			e.setup(tipos[j])
		e.position = pos
		if tipos[j] == "bucho":
			e.scale = Vector3.ONE * ESCALA_BUCHO[j % ESCALA_BUCHO.size()]
		e.visible = est_mask != "aneis"
		e.rotation.y = rng.randf_range(-3.1, 3.1)
		var an := "idle"
		if tipos[j] == "bucho" and j % 4 == 1:
			an = "incha"
			var prog := rng.randf_range(0.3, 0.8)
			if est_mask == "":
				vfx.quad_chao(Vector2(1.6, 1.6), pos + Vector3(0, 0.025, 0), vfx.mat("perigo", {"modo": 0, "progresso": prog, "tam": 0.9}))
		elif tipos[j] == "gaiola" and j % 2 == 1:
			an = "abre"
		elif tipos[j] == "lata":
			an = "treme"
		e.pose(an, rng.randf_range(0.1, 0.6))
		if est_mask == "":
			vfx.quad_chao(Vector2(0.85, 0.7), pos + Vector3(0, 0.012, 0), vfx.mat("sombra", {}))
	if est_mask == "":
		vfx.quad_chao(Vector2(4.0, 0.85), Vector3(-6.6, 0.024, -1.9), vfx.mat("perigo", {"modo": 1, "progresso": 0.65, "tam": 1.1}), 0)
	atores = {"breu": {"b": hn["breu"]}, "remanso": {"b": hn["remanso"]}, "marola": {"b": hn["marola"]}, "piaba": {"b": hn["piaba"]}}

func _estresse_sim() -> void:
	if est_mask != "":
		return
	# passe no ar: remo do Remanso para a Marola, com a fita verde (22 quadros de voo)
	est_remo = Boneco.new(); add_child(est_remo); est_remo.setup("remo")
	var p0: Vector3 = atores["remanso"]["b"].global_position + Vector3(0.3, 1.6, 0)
	var p1: Vector3 = atores["marola"]["b"].global_position + Vector3(0, 1.7, 0)
	vfx.fita(est_remo, COR["remanso"], VERSO["remanso"], 0.7)
	var n := 21
	var eixo := (p1 - p0).normalized().cross(Vector3.UP).normalized()
	for f in n:
		var u := float(f) / 27.0
		var p := p0.lerp(p1, u) + Vector3(0, 0.95 * 4.0 * u * (1.0 - u), 0)
		var b := Basis(eixo, -TAU * 1.75 * u)
		est_remo.global_transform = Transform3D(b, p - b * Vector3(0, 0.6, 0))
		if f == n - 12:
			vfx.coroa(atores["piaba"]["b"].global_position + Vector3(0.0, 0.08, 0.0), 0.8)
		if f == n - 9:
			vfx.balao(atores["marola"]["b"], 1.95, COR["marola"], 60, Vector3(-0.5, 0, 0))
		if f == n - 6:
			var br = atores["breu"]["b"]
			var head: Vector3 = br.osso_global("prop") * Vector3(0, 0.75, 0)
			vfx.lascas(head, [COR["breu"], LAMA, CREME, Color("#C2A884")], 12, 1.0, Vector3.ZERO, 1.0, false)
			vfx.estalo(head + Vector3(0, 0.3, 0), COR["breu"], 1.5, 8)
			malho.visible = false
		vfx.tick()


# ================================================================== teste automático de colisão da arma
# Em cada quadro de cada golpe, os pontos da arma (do meio do cabo até a ponta) não podem entrar na cápsula do
# corpo (raio e altura de stats.json, eixo no osso do quadril) nem passar do plano do chão.
func _colisao() -> void:
	var stats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/glb/stats.json"))
	var casos := [["marola", "malho", "malho", 33], ["marola", "remada", "remo", -1], ["marola", "pegada", "remo", -1], ["piaba", "remada", "remo", -1], ["piaba", "arremesso", "remo", 18], ["remanso", "golpe", "malho", -1], ["breu", "golpe", "malho", -1]]
	var rel := {}
	for c in casos:
		var b = boneco(c[0], Vector3.ZERO, 0.0, c[1], 0.0)
		var corpo: Array = stats[c[0]]["body"]
		var n := int(round(b.dur(c[1]) * 60.0))
		if c[3] >= 0:
			n = min(n, c[3])   # o malho estoura no contato; o remo sai da mão no lançamento
		var piso := 9.0
		var folga := 9.0
		var viol := []
		for f in n + 1:
			b.pose(c[1], float(f) / 60.0 + 0.0005)
			var hips: Vector3 = b.osso_global("hips").origin
			for p in pontos_arma(b, c[2]).slice(2):
				piso = minf(piso, p.y)
				if p.y < -0.01:
					viol.append([f, "chão", snappedf(p.y, 0.001)])
				if p.y > corpo[1] and p.y < corpo[2]:
					var d := Vector2(p.x - hips.x, p.z - hips.z).length() - float(corpo[0])
					folga = minf(folga, d)
					if d < 0.0:
						viol.append([f, "corpo", snappedf(d, 0.001)])
		rel["%s/%s" % [c[0], c[1]]] = {"quadros": n + 1, "altura_min_arma": snappedf(piso, 0.001), "folga_min_corpo": snappedf(folga, 0.001), "violacoes": viol.size(), "exemplos": viol.slice(0, 6)}
		b.queue_free()
	var txt := JSON.stringify(rel, " ")
	print(txt)
	var fa := FileAccess.open(A("out", "/tmp/c.png").get_basename() + ".json", FileAccess.WRITE)
	fa.store_string(txt)
