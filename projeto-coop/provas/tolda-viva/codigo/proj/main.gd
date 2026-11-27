extends Node3D
# Prova de estilo "Tolda Viva": monta cenas por código e captura quadros (Movie Maker ou captura direta).
# Args (depois de --): cena=folha|beauty|stress|clip  out=arquivo.png  frames=N

const Boneco = preload("res://boneco.gd")
const Palco = preload("res://palco.gd")
const Vfx = preload("res://vfx.gd")
var vfx
var sim_f := 0
var sim_ate := -1
var trauma := 0.0
var kick := 0.0
var cam_base: Transform3D
var S := {}
var beauty := false
var palco
var chars: Array = []
const PCOR := [Color("#E5337F"), Color("#22BFD6"), Color("#FFD84A"), Color("#2E7D22")]
var cam_fov0 := 30.0
var punch_fov := 0.0
var sx_px := 0.0   # metros por pixel (720p) no alvo, para o tremor em pixels
const HEROI_SIMB := {"tarugo": 0, "retros": 1, "pavio": 2, "anilina": 3}
const HEROI_P := {"tarugo": 0, "retros": 1, "pavio": 2, "anilina": 3}
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
	_env(Color(A("bg", "#3a3550")))
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	match cena:
		"folha":
			_folha()
		"beauty":
			_beauty()
		"poses":
			_poses()
		"duelo":
			_duelo()
		"estresse":
			_estresse()

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
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = false
	add_child(sun)
	# v2: luz-chave mais alta (sombras curtas) e mais fraca; os canhões de palco fazem o centro
	sun.light_energy = float(A("sol", "0.85"))
	sun.look_at_from_position(Vector3(float(A("solx", "-3")), float(A("soly", "14")), float(A("solz", "5"))), Vector3.ZERO)

func boneco(n: String, pos: Vector3, yaw: float, anim := "repouso", t := 0.0):
	var b = Boneco.new()
	add_child(b)
	b.setup(n)
	b.position = pos
	b.rotation.y = deg_to_rad(yaw)
	b.pose(anim, t)
	return b

func camarote(alvo: Vector3, dist: float, pitch := 38.0, yaw := 0.0, fov := 30.0) -> void:
	cam.fov = fov
	var d := Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))) * dist
	d = d.rotated(Vector3.UP, deg_to_rad(yaw))
	cam.look_at_from_position(alvo + d, alvo)

func decal(size: Vector2, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi = palco.quad(size, pos, mat, true)
	mi.rotation.y = deg_to_rad(yaw)
	return mi

func por_em_cena(b, heroi := true) -> void:
	# sombra de contato (+ braço do bonequeiro para heróis), anel e símbolo de jogador
	# v2: sombra do braço do bonequeiro mais curta e mais leve (competia com as telegrafias)
	var sz := Vector2(1.0, 1.8) if heroi else Vector2(0.9, 0.9)
	var sm = palco.sm("sombra", {"braco": 1.0 if heroi else 0.0, "forca": 0.75})
	var s := decal(sz if heroi else Vector2(0.9, 0.9 * 2.6 / 2.6), b.position + Vector3(0, 0.006, 0), sm)
	if heroi:
		s.position += Vector3(0, 0, sz.y * 0.5 - 0.12)
		s.mesh.size = sz
	else:
		s.mesh.size = Vector2(1.0, 1.0) * (1.6 if b.nome == "bastidor" else 1.0)
	b.set_meta("sombra", s)
	if heroi:
		var i: int = HEROI_P[b.nome]
		var a := decal(Vector2(1.35, 1.35), b.position + Vector3(0, 0.012, 0), palco.sm("anel", {"cor": PCOR[i], "simbolo": HEROI_SIMB[b.nome]}))
		b.set_meta("anel", a)
		if A("slot", "1") == "1":
			b.contorno_jogador(PCOR[i].darkened(0.08))
		if A("canhao", "1") == "1":
			var sp = palco.canhao(float(A("canhao_e", "1.0")), float(A("canhao_a", "10")))
			palco.mira(sp, b.position)
			b.set_meta("canhao", sp)
	palco.luas_no_boneco(b)

func _beauty() -> void:
	palco = Palco.new(); add_child(palco)
	camarote(Vector3(float(A("tx", "0.0")), 0.4, float(A("tz", "0.3"))), float(A("dist", "9.5")), float(A("pitch", "38")))
	palco.montar(cam, [[Vector3(0.2, 3.6, 0.0), 0.5, 2.9], [Vector3(-4.6, 3.2, -1.8), 0.42, 2.0], [Vector3(4.4, 3.0, 2.3), 0.45, 2.1]])
	palco.tolda_na_camera()
	palco.contrapeso(Vector3(-2.6, 0, 1.6), 3.4)
	var t = boneco("tarugo", Vector3(-1.0, 0, 0.6), 60.0); por_em_cena(t)
	var an = boneco("anilina", Vector3(1.6, 0, -0.6), -110.0); por_em_cena(an)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for k in 6:
		var e = boneco("caruncho", Vector3(rng.randf_range(-3.5, 4.0), 0, rng.randf_range(-2.5, 2.5)), rng.randf_range(-180, 180)); por_em_cena(e, false)
	var tr = boneco("traca", Vector3(2.8, 0, 1.0), -130.0); por_em_cena(tr, false)
	var bs = boneco("bastidor", Vector3(-3.6, 0, -2.4), 30.0); por_em_cena(bs, false)

func _poses() -> void:
	var who := A("who", "tarugo")
	var an := A("anim", "golpe")
	var fr := A("f", "0,3,6,10,20,21,24,30,46").split(",")
	var yaw := float(A("yaw", "90"))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	var dx := float(A("dx", "1.6"))
	cam.size = fr.size() * dx
	var cx := (fr.size() - 1) * dx * 0.5
	var pit := deg_to_rad(float(A("pitch", "0")))
	var cy := float(A("cy", "0.8"))
	cam.look_at_from_position(Vector3(cx, cy + 10.0 * sin(pit), 10.0 * cos(pit)), Vector3(cx, cy, 0))
	for k in fr.size():
		boneco(who, Vector3(k * dx, 0, 0), yaw, an, float(fr[k]) / 60.0 + 0.001)
	var chao := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 0.02); chao.mesh = pm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.3, 0.25, 0.2); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; chao.material_override = m
	add_child(chao)

func _folha() -> void:
	var who := A("who", "tarugo,anilina,retros,pavio,caruncho").split(",")
	var yaws := [0.0, 40.0, 90.0]
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	var n := who.size() * 3
	var dx := float(A("dx", "1.05"))
	cam.size = n * dx
	var cx := (n - 1) * dx * 0.5
	cam.look_at_from_position(Vector3(cx, float(A("cy", "0.85")) + 10.0 * tan(deg_to_rad(float(A("pitch", "0")))), 10), Vector3(cx, float(A("cy", "0.85")), 0))
	var k := 0
	for w in who:
		for y in yaws:
			var bb = boneco(w, Vector3(k * dx, 0, 0), y, A("anim", "idle"), 0.001)
			k += 1

func _process(_d: float) -> void:
	frame_i += 1
	if cena == "estresse" and frame_i < frames - 1:
		_tick_estresse(frame_i)
	if cena == "duelo":
		# simula até o quadro pedido (molas e partículas precisam da história); no clipe, um passo por quadro
		var alvo := sim_ate if sim_ate >= 0 else frame_i
		while sim_f < alvo:
			_tick(sim_f)
			sim_f += 1
		if sim_ate >= 0 and frame_i < 3:
			return
		if sim_ate < 0:
			if frame_i >= frames:
				get_tree().quit()
			return
	if frame_i == frames or (cena == "duelo" and frame_i >= 3):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(A("out", "/tmp/out.png"))
		print("PROBE draws=%d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		get_tree().quit()

# ================================================================== duelo: o golpe co-op (clipe e quadro bonito)
# Anilina prepara com Tinta, Tarugo detona com Serragem: reação cruzada Machê.

# ================================================================== duelo: o golpe co-op (clipe e quadro bonito)
# Anilina prepara com Tinta, Tarugo detona com Serragem: reação cruzada Machê.
# v2: hit-stop de 6 no atacante, soco de escala no alvo, tremor medido em pixels, susto e recuo dos
# vizinhos, idle vivo (balanço de marionete pendurada nos fios), carunchos que andam, canhões de palco.
const T_CONT := 71
const HS_T := 6
const MACHE_F := 9      # quadros até virar estátua
const RACHA_F := 4
var ESTOURO := T_CONT + MACHE_F + RACHA_F + 1

func _duelo() -> void:
	beauty = A("beauty", "0") == "1"
	sim_ate = int(A("quadro", "-1"))
	if A("pc", "0") == "1":
		# nível PC (Forward+): sombra real da luz-chave e brilho só no que já é luz (luas, clarão)
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 30.0
		sun.shadow_bias = 0.03
		sun.shadow_blur = 0.6
		var e: Environment = we.environment
		e.glow_enabled = true
		e.glow_intensity = 0.55
		e.glow_bloom = 0.0
		e.glow_hdr_threshold = 0.92
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	palco = Palco.new(); add_child(palco)
	var alvo := Vector3(float(A("tx", "-0.2")), 0.45, float(A("tz", "0.25")))
	var dist := float(A("dist", "8.2"))
	camarote(alvo, dist, float(A("pitch", "34")), float(A("yaw", "0")), float(A("fov", "30")))
	cam_fov0 = cam.fov
	sx_px = 2.0 * dist * tan(deg_to_rad(cam.fov * 0.5)) / 720.0
	cam_base = cam.global_transform
	palco.montar(cam, [[Vector3(0.6, 4.4, 0.4), 0.3, 3.3], [Vector3(float(A("l2x", "-2.6")), float(A("l2y", "2.3")), float(A("l2z", "-1.0"))), 0.34, 1.5], [Vector3(float(A("l3x", "4.6")), float(A("l3y", "2.4")), float(A("l3z", "-1.0"))), 0.32, 1.6]], {"telao_z": float(A("telao_z", "-2.5")), "arvores": [[-6.2, -2.0, 2.8, 0], [-3.6, -2.3, 3.1, 1], [3.1, -2.2, 3.0, 2], [6.0, -1.9, 2.7, 0], [0.2, -2.6, 2.5, 1]]})
	palco.tolda_na_camera(float(A("bamb", "0.04")), float(A("emp", "0.025")))
	palco.mats_luz[0].set_shader_parameter("pinho", Color(A("pinho", "#C2B399")).srgb_to_linear())
	if A("foco", "0") != "0":
		palco.mats_luz[0].set_shader_parameter("foco", Vector4(float(A("fx", "0.4")), float(A("fz", "0.3")), float(A("fr", "3.4")), float(A("foco", "0.45"))))
	var cp = palco.contrapeso(Vector3(float(A("cpx", "2.9")), 0, float(A("cpz", "-1.3"))), float(A("cpy", "1.75")), 0.55)
	var perigo := decal(Vector2(1.7, 1.7), Vector3(float(A("cpx", "2.9")), 0.01, float(A("cpz", "-1.3"))), palco.sm("perigo", {"modo": 0, "fecha": 0.35, "alpha": 0.9, "tam": Vector2(1.7, 1.7)}))
	vfx = Vfx.new(); add_child(vfx); vfx.setup(cam, 7)
	# elenco
	var yT := float(A("yawT", "62"))
	var dT := Vector3(sin(deg_to_rad(yT)), 0, cos(deg_to_rad(yT)))
	var c0p := Vector3(float(A("c0x", "0.35")), 0, float(A("c0z", "0.75")))
	var T = boneco("tarugo", c0p - dT * 2.75, yT, "idle", 0.0); por_em_cena(T)
	var N = boneco("anilina", Vector3(float(A("nx", "1.45")), 0, float(A("nz", "-0.55"))), float(A("yawN", "-40")), "idle", 0.3); por_em_cena(N)
	var C0 = boneco("caruncho", c0p, yT + 180.0, "telegrafia", 0.0); por_em_cena(C0, false)
	for b in [T, N]:
		b.springs_default()
	C0.springs_default()
	S = {"T": T, "N": N, "C0": C0, "cp": cp, "extras": [], "dT": dT, "c0p": c0p, "yT": yT, "perigo": perigo}
	# extras: tipo, posição, yaw, anim, escala, anda (m/s)
	var ex := [["caruncho", Vector3(2.5, 0, 1.6), -120.0, "andar", 0.9, 0.35], ["caruncho_chifre", Vector3(-3.4, 0, -1.3), 60.0, "idle", 1.15, 0.0],
		["caruncho", Vector3(3.6, 0, 0.1), -100.0, "telegrafia", 1.0, 0.0], ["caruncho", Vector3(-1.4, 0, 2.6), 20.0, "andar", 0.82, 0.3],
		["traca", Vector3(1.9, 0, -2.3), -150.0, "idle", 1.0, 0.0], ["bastidor", Vector3(-2.2, 0, -2.6), 25.0, "idle", 1.0, 0.0]]
	if beauty:
		ex.append(["caruncho", Vector3(float(A("c1x", "2.55")), 0, float(A("c1z", "0.55"))), float(A("yawC1", "-140")), "tinta", 1.0, 0.0])
	var k := 0
	for e in ex:
		var b = boneco(e[0], e[1], e[2], e[3], k * 0.17); por_em_cena(b, false)
		b.scale = Vector3.ONE * e[4]
		b.set_meta("esc", e[4]); b.set_meta("anda", e[5]); b.set_meta("p0", e[1]); b.set_meta("anim0", e[3])
		b.springs_default()
		S["extras"].append(b)
		k += 1
	if beauty:
		S["C1"] = S["extras"][-1]
	# Bastidor ao fundo telegrafando a queda: retângulo de impacto no chão
	var bs = S["extras"][5]
	S["ret"] = decal(Vector2(1.2, 2.0), bs.position + Vector3(0, 0.01, 1.05).rotated(Vector3.UP, deg_to_rad(25)), palco.sm("perigo", {"modo": 1, "fecha": 0.0, "alpha": 0.9, "tam": Vector2(1.2, 2.0)}), 25.0)
	# faixa de avanço do caruncho (telegrafia)
	S["faixa"] = decal(Vector2(2.6, 0.62), C0.position - dT * 1.45 + Vector3(0, 0.012, 0), palco.sm("perigo", {"modo": 2, "fecha": 0.0, "tam": Vector2(2.6, 0.62), "sentido": float(A("sentido", "-1"))}), yT + 90.0)
	# plaquinha de demão (tabuleta de madeira pendurada com o símbolo da Tinta)
	S["placa"] = _plaquinha()
	S["fitaN"] = null
	S["tN"] = 0.0
	S["susto"] = {}

func _plaquinha() -> Node3D:
	var n := Node3D.new(); add_child(n)
	var tab = palco.box(Vector3(0.26, 0.2, 0.03), Vector3(0, -0.12, 0), Color("#C9925E"), n)
	var gota := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.055; sp.height = 0.11; gota.mesh = sp
	var gm := StandardMaterial3D.new(); gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; gm.albedo_color = Color("#3550D8"); gota.material_override = gm
	gota.position = Vector3(-0.04, -0.12, 0.03); gota.scale = Vector3(1, 1.2, 0.3); n.add_child(gota)
	var notch = palco.box(Vector3(0.025, 0.08, 0.02), Vector3(0.08, -0.12, 0.02), Color("#1D1820"), n)
	for x in [-0.09, 0.09]:
		palco.box(Vector3(0.008, 0.24, 0.008), Vector3(x, 0.08, 0), Color("#1D1820"), n)
	n.visible = false
	return n

func _tip(b, dist: float) -> Vector3:
	var bi: int = b.skel.find_bone("prop")
	var g: Transform3D = b.skel.global_transform * b.skel.get_bone_global_pose(bi)
	return g * Vector3(0, dist, 0)

func _flash(b, v: float) -> void:
	b.param(["cor", "pano"], "flash", v)
	b.param(["contorno"], "flash", v * 0.0)

# balanço de marionete pendurada nos fios: sobe e desce contínuo a 60 (é a mão do bonequeiro), com
# um leve pêndulo lateral; a pose do corpo continua segurada
func _marionete(b, f: int, fase: float, amp := 1.0) -> void:
	var t := f / 60.0 + fase
	b.position.y = amp * (0.022 * (0.5 + 0.5 * sin(t * TAU / 1.7)))
	b.rotation.z = amp * deg_to_rad(1.8) * sin(t * TAU / 2.3 + 0.7)
	b.rotation.x = amp * deg_to_rad(1.2) * sin(t * TAU / 1.7 + 1.9)

func _shake(f: int) -> void:
	trauma = max(0.0, trauma - 1.6 / 60.0)
	kick *= 0.72
	punch_fov *= 0.8
	var sh2 := trauma * trauma
	# até 5 px (em 720p) de tremor, soco para baixo em pixels, e um soco de zoom de 3% no contato
	var off := Vector3(sin(f * 2.7) * 1.0, sin(f * 3.9 + 1.0) * 0.8, 0) * sh2 * 5.0 * sx_px + Vector3(0, -kick * sx_px, 0)
	cam.global_transform = cam_base
	cam.global_position += cam_base.basis * off
	cam.fov = cam_fov0 * (1.0 - punch_fov)

func _tick(f: int) -> void:
	var T = S["T"]; var N = S["N"]; var C0 = S["C0"]
	# ---------------- Tarugo: dois pulinhos até a marca, depois a marretada pesada (hit-stop de 6)
	var t_parado := false
	if f < 36:
		var ph := float(f % 18) / 18.0
		var e := ph * ph * (3.0 - 2.0 * ph)
		var dist: float = 2.75 - 0.7 * (floor(f / 18.0) + e)
		T.position = S["c0p"] - S["dT"] * dist + Vector3(0, 0.24 * sin(PI * min(1.0, ph / 0.8)), 0)
		T.rotation.x = deg_to_rad(8.0) * sin(PI * ph)
		T.pose("pulo", (f % 18) / 60.0 + 0.001)
	else:
		T.position = S["c0p"] - S["dT"] * 1.35; T.rotation.x = 0.0
		var tg := f - 50
		if tg < 0:
			T.pose("idle", (f - 36) / 60.0 + 0.001)
			_marionete(T, f, 0.0)
		else:
			var tt := tg
			if f >= T_CONT and f < T_CONT + HS_T:
				tt = 21
				T.mola.time_scale = 0.0
				t_parado = true
			elif f >= T_CONT + HS_T:
				tt = tg - HS_T
				T.mola.time_scale = 1.0
			if tt <= 72:
				T.pose("golpe", tt / 60.0 + 0.001)
				if tt < 10 or tt > 40:
					_marionete(T, f, 0.0, 0.5)
				else:
					T.position.y = 0.0; T.rotation.z = 0.0
			else:
				# comemoração: um pulinho de vaidade para a plateia, depois o idle vivo
				var tp := tt - 72
				if tp >= 50 and tp < 68:
					var ph2 := float(tp - 50) / 18.0
					T.pose("pulo", (tp - 50) / 60.0 + 0.001)
					T.position.y = 0.2 * sin(PI * min(1.0, ph2 / 0.8))
					T.rotation.y = deg_to_rad(S["yT"]) + deg_to_rad(-40.0) * min(1.0, ph2 * 1.5)
				else:
					T.pose("idle", tp / 60.0 + 0.001)
					_marionete(T, f, 0.0)
	# ---------------- Anilina: pincelada (contato no quadro 19 da ação, hit-stop de 4)
	var n_ini := 45 if beauty else 24
	var N_CONT := n_ini + 19
	var tn := f - n_ini
	if tn < 0:
		N.pose("idle", (f + 20) / 60.0 + 0.001)
		_marionete(N, f, 0.6)
	else:
		var nt := tn
		if f >= N_CONT and f < N_CONT + 4:
			nt = 19; N.mola.time_scale = 0.0
		elif f >= N_CONT + 4:
			nt = tn - 4; N.mola.time_scale = 1.0
		if nt <= 72:
			N.pose("golpe", nt / 60.0 + 0.001)
			if nt > 38:
				_marionete(N, f, 0.6, 0.6)
		else:
			var np := nt - 72
			if np >= 70 and np < 88:
				N.pose("pulo", (np - 70) / 60.0 + 0.001)
				N.position.y = 0.16 * sin(PI * min(1.0, float(np - 70) / 14.4))
			else:
				N.pose("idle", np / 60.0 + 0.001)
				_marionete(N, f, 0.6)
		# rastro de Tinta da ponta da broxa
		if nt >= 17 and nt <= 30:
			if S["fitaN"] == null:
				S["fitaN"] = vfx.nova_fita(PCOR[3])
			vfx.fita_ponto(S["fitaN"], _tip(N, 1.12), N.global_position + Vector3(0, 0.75, 0))
		elif S["fitaN"] != null:
			S["fitaN"]["ativa"] = false
	# gotas de tinta saem da broxa enquanto ela varre (poucas, de vida curta)
	if S.get("gotas", 0) > 0:
		S["gotas"] -= 1
		var tp := _tip(N, 1.12)
		var vv: Vector3 = (tp - S.get("tip_prev", tp)) * 60.0
		vfx.gotas(tp, vv * 0.5, 2)
	S["tip_prev"] = _tip(N, 1.12) if N.anim == "golpe" else Vector3.ZERO
	# ---------------- Caruncho alvo da Tinta
	var alvoN = S["C1"] if beauty else C0
	if f == N_CONT:
		alvoN.pose("tinta", 0.001); alvoN.mola.time_scale = 0.0
		alvoN.param(["cor", "pano"], "tinta", 1.0)
		S["gotas"] = 6
		# uma forma por arma: respingo de tinta assimétrico no sentido da pincelada
		var sw: Vector3 = (_tip(N, 1.12) - N.global_position)
		var scr := cam.global_basis.inverse() * sw.cross(Vector3.UP)
		vfx.respingo(alvoN.global_position + Vector3(0, 0.42, 0) + (cam.global_position - alvoN.global_position).normalized() * 0.3, 0.85, atan2(scr.y, scr.x))
		trauma = max(trauma, 0.35)
	if f >= N_CONT and f < N_CONT + 2:
		_flash(alvoN, 0.85 if f == N_CONT else 0.5)
		alvoN.scale = Vector3.ONE * (1.12 if f == N_CONT else 1.07)
	elif f == N_CONT + 2:
		_flash(alvoN, 0.0)
		alvoN.scale = Vector3.ONE
	if f >= N_CONT and f < N_CONT + 4:
		alvoN.position.x += 0.03 * (1 if f % 2 == 0 else -1)
	if f == N_CONT + 4:
		alvoN.mola.time_scale = 1.0
	if f > N_CONT + 4 and f < N_CONT + 22:
		alvoN.pose("tinta", (f - N_CONT - 4) / 60.0 + 0.001)
	if not beauty:
		if f < N_CONT:
			C0.pose("telegrafia", f / 60.0 + 0.001)
			S["faixa"].visible = true
			(S["faixa"].material_override as ShaderMaterial).set_shader_parameter("fecha", clamp(f / 40.0, 0.0, 1.0))
		elif f >= N_CONT and f < 62:
			S["faixa"].visible = false
		if f == N_CONT:
			S["placa"].visible = true
	else:
		if f == 0:
			C0.param(["cor", "pano"], "tinta", 1.0)
			S["placa"].visible = true
		if f < T_CONT:
			C0.pose("telegrafia", (f + 10) / 60.0 + 0.001)
			S["faixa"].visible = true
			(S["faixa"].material_override as ShaderMaterial).set_shader_parameter("fecha", clamp((f - 30) / 40.0, 0.0, 1.0))
	if not beauty and f >= 62 and f < T_CONT:
		C0.pose("telegrafia", (f - 62) / 60.0 + 0.001)
		S["faixa"].visible = true
		(S["faixa"].material_override as ShaderMaterial).set_shader_parameter("fecha", clamp((f - 62) / 9.0 * 0.5 + 0.5, 0.0, 1.0))
	# ---------------- contato do macete: reação cruzada Machê
	var top: Vector3 = C0.global_position + Vector3(0, 0.45, 0)
	var para_cam: Vector3 = (cam.global_position - top).normalized()
	if f == T_CONT:
		S["faixa"].visible = false
		C0.pose("golpeado", 0.001); C0.mola.time_scale = 0.0
		# macete: anel de choque achatado + lascas + nuvem de serragem em flipbook (12 por segundo)
		vfx.serragem(top, S["dT"] * 0.6 + Vector3(0, 0.2, 0), 70)
		vfx.onda(C0.global_position, PCOR[0], PCOR[3], 1.25, 0.42)
		# nuvem de serragem rente ao chão, dos lados (a estátua de machê fica à vista no centro)
		var lado: Vector3 = cam.global_basis.x
		vfx.nuvem(C0.global_position + lado * 0.55 + Vector3(0, 0.18, 0), 0.62)
		vfx.nuvem(C0.global_position - lado * 0.6 + Vector3(0, 0.15, 0), 0.55, 1.0 / 30.0)
		vfx.nuvem(C0.global_position - para_cam * 0.4 + Vector3(0, 0.25, 0), 0.5, 1.0 / 20.0)
		trauma = 1.0; kick = 4.0; punch_fov = 0.03
	if f >= T_CONT and f < T_CONT + 2:
		_flash(C0, [0.85, 0.6][f - T_CONT])
	elif f == T_CONT + 2:
		_flash(C0, 0.0)
	# soco de escala no alvo (1,15) e estátua de machê durante o congelamento
	if f >= T_CONT and f < ESTOURO:
		var ps := [1.15, 1.12, 1.08, 1.05]
		C0.scale = Vector3.ONE * (ps[f - T_CONT] if f - T_CONT < 4 else 1.04)
	if f >= T_CONT and f < T_CONT + MACHE_F:
		C0.position = S["c0p"] + S["dT"].cross(Vector3.UP) * 0.035 * (1 if f % 2 == 0 else -1) * (1.0 - (f - T_CONT) / float(MACHE_F))
		C0.param(["cor", "pano"], "mache", clamp((f - T_CONT + 1) / 6.0, 0.0, 1.0))
	if f >= T_CONT + MACHE_F and f < ESTOURO:
		C0.position = S["c0p"]
		C0.param(["cor", "pano"], "rachado", clamp((f - T_CONT - MACHE_F + 1) / float(RACHA_F), 0.0, 1.0))
	if f == ESTOURO:
		_estilhaca(C0)
		S["placa"].visible = false
		trauma = max(trauma, 0.7); kick = 3.0; punch_fov = 0.02
		# vizinhos levam susto e recuam
		for b in S["extras"]:
			if b.nome.begins_with("caruncho") and b != S.get("C1") and b.position.distance_to(C0.position) < 3.6:
				var away: Vector3 = (b.position - C0.position); away.y = 0
				S["susto"][b] = {"f0": f, "p0": b.position, "dir": away.normalized() * (0.75 - away.length() * 0.12)}
	# plaquinha balança sobre o alvo
	if S["placa"].visible:
		var pa: Node3D = S["placa"]
		pa.global_position = C0.global_position + Vector3(0, 1.0, 0)
		pa.basis = cam.global_basis
		pa.rotate(cam.global_basis.z, 0.35 * sin((f - N_CONT) * 0.25) * exp(-max(0, f - N_CONT) / 40.0))
	# ---------------- extras com o próprio ritmo (inimigos a 20 poses/s: o "clac-clac")
	var k := 0
	for b in S["extras"]:
		if beauty and b == S.get("C1"):
			k += 1
			continue
		var esc: float = b.get_meta("esc")
		if S["susto"].has(b):
			var su: Dictionary = S["susto"][b]
			var ts := f - int(su["f0"])
			if ts < 40:
				b.pose("susto", ts / 60.0 + 0.001)
				var ee: float = 1.0 - pow(1.0 - min(1.0, ts / 12.0), 3.0)
				b.position = su["p0"] + su["dir"] * ee
				b.param(["olho"], "tam_pupila", 0.2 if ts < 30 else 0.42)
				b.scale = Vector3(esc, esc * (1.12 if ts < 3 else 1.0), esc)
			else:
				b.param(["olho"], "tam_pupila", 0.42)
				b.set_meta("p0", b.position)
				S["susto"].erase(b)
			k += 1
			continue
		var an: String = b.get_meta("anim0")
		var spd: float = b.get_meta("anda")
		if spd > 0.0 and f > 20:
			# anda em direção ao herói mais próximo, parando a 1,6 m
			var tgt: Vector3 = T.position if b.position.distance_to(T.position) < b.position.distance_to(N.position) else N.position
			var d2: Vector3 = tgt - b.position; d2.y = 0
			if d2.length() > 1.6:
				b.position += d2.normalized() * spd / 60.0
				b.rotation.y = lerp_angle(b.rotation.y, atan2(d2.x, d2.z), 0.08)
				an = "andar"
			else:
				an = "idle"
		var len: float = b.ap.get_animation(an).length
		b.pose(an, fmod((f + k * 11) / 60.0, len - 0.02) + 0.001)
		# enxame "direto": tremidinha de cada inseto a 20 poses/s, e respiração na escala
		if b.nome.begins_with("caruncho"):
			var st := int(f / 3)
			b.scale = Vector3(esc, esc * (1.0 + 0.025 * sin(f * 0.21 + k)), esc)
			b.position.y = 0.0
			if an != "andar":
				b.rotation.y += deg_to_rad(2.0) * (fmod(sin(st * 12.9898 + k) * 43758.5453, 1.0) - 0.5) * 0.3
		if b.nome == "traca":
			b.position.y = 0.08 * sin(f * 0.11)
		k += 1
	# bastidor telegrafa a queda
	var bs = S["extras"][5]
	if f > 30:
		bs.pose("telegrafia", fmod(f / 60.0, 0.09) + 0.001)
		(S["ret"].material_override as ShaderMaterial).set_shader_parameter("fecha", clamp((f - 30) / 200.0, 0.0, 1.0))
	(S["perigo"].material_override as ShaderMaterial).set_shader_parameter("fecha", fmod(0.35 + f / 150.0, 1.0))
	# contrapeso balança na corda
	S["cp"].rotation.z = 0.05 * sin(f * 0.05)
	# decalques e canhões seguem os bonecos
	for b in [T, N, C0] + S["extras"]:
		if b.has_meta("sombra"):
			var sh: MeshInstance3D = b.get_meta("sombra")
			var hp: bool = b.has_meta("anel")
			sh.position = Vector3(b.position.x, 0.006, b.position.z + (0.78 if hp else 0.0))
			sh.visible = b.visible
		if b.has_meta("anel"):
			b.get_meta("anel").position = Vector3(b.position.x, 0.012, b.position.z)
		if b.has_meta("canhao"):
			palco.mira(b.get_meta("canhao"), Vector3(b.position.x, 0, b.position.z))
	vfx.step(1.0)
	vfx.draw(1.0)
	_shake(f)

func _estilhaca(C0) -> void:
	C0.visible = false
	var m := ShaderMaterial.new(); m.shader = Boneco.sh("mache")
	var c: Vector3 = C0.global_position + Vector3(0, 0.3, 0)
	# forma dominante: cacos de papel machê (creme). As cores dos dois jogadores só num punhado de
	# retalhos de seda de vida curta (a assinatura da reação cruzada)
	for i in 18:
		var d := Vector3(vfx.rng.randf_range(-1, 1), vfx.rng.randf_range(0.4, 1.4), vfx.rng.randf_range(-1, 1)).normalized()
		vfx.caco(c + d * 0.15, d * vfx.rng.randf_range(2.5, 5.0) + S["dT"] * 1.0, vfx.rng.randf_range(0.1, 0.2), m)
	for i in 6:
		var d := Vector3(vfx.rng.randf_range(-1, 1), vfx.rng.randf_range(0.5, 1.5), vfx.rng.randf_range(-1, 1)).normalized()
		vfx.seda_retalho(c + d * 0.2, d * vfx.rng.randf_range(2.0, 3.6), [PCOR[0], PCOR[3]][i % 2], vfx.rng.randf_range(0.12, 0.18), vfx.rng.randf())
	vfx.serragem(c, Vector3(0.3, 0.5, 0), 30)
	vfx.poeira(C0.global_position, 8, 0.6)
	var pc: Vector3 = (cam.global_position - c).normalized()
	vfx.nuvem(c + pc * 0.2, 0.95)
	vfx.nuvem(c + pc * 0.15 + cam.global_basis.x * 0.45, 0.6, 1.0 / 24.0)

# ================================================================== estresse: 4 heróis, 20 inimigos, 3 efeitos
var mask := false
func _estresse() -> void:
	mask = A("mask", "0") != "0"
	var aneis := A("mask", "0") == "2"
	palco = Palco.new(); add_child(palco)
	camarote(Vector3(float(A("tx", "0.0")), 0.4, float(A("tz", "0.6"))), float(A("dist", "12.0")), float(A("pitch", "36")))
	if mask:
		(we.environment as Environment).background_color = Color.BLACK
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	else:
		palco.montar(cam, [[Vector3(-1.0, 3.6, 0.8), 0.32, 3.0], [Vector3(-5.0, 2.8, -1.0), 0.3, 2.2], [Vector3(4.6, 2.8, 2.0), 0.3, 2.4]], {"telao_z": -3.4})
		palco.tolda_na_camera(float(A("bamb", "0.035")), float(A("emp", "0.022")))
		palco.mats_luz[0].set_shader_parameter("pinho", Color(A("pinho", "#C2B399")).srgb_to_linear())
	vfx = Vfx.new(); add_child(vfx); vfx.setup(cam, 11)
	var herois := [["tarugo", Vector3(-2.2, 0, 1.4), 40.0, "golpe", 26], ["retros", Vector3(2.6, 0, 2.2), -60.0, "golpe", 6], ["pavio", Vector3(0.6, 0, -1.2), 160.0, "golpe", 12], ["anilina", Vector3(-0.4, 0, 2.9), 120.0, "golpe", 30]]
	S = {"h": [], "e": []}
	var i := 0
	for h in herois:
		var b = Boneco.new(); add_child(b); b.setup(h[0], Color8(255, 0, 20 + 40 * i) if mask else null)
		b.position = h[1]; b.rotation.y = deg_to_rad(h[2]); b.pose(h[3], h[4] / 60.0 + 0.001)
		if not mask:
			por_em_cena(b)
		if aneis:
			b.visible = false
			decal(Vector2(1.35, 1.35), b.position + Vector3(0, 0.012, 0), palco.sm("anel", {"cor": PCOR[i], "simbolo": HEROI_SIMB[b.nome], "alpha": 1.0}))
		S["h"].append(b); i += 1
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	var placed: Array = []
	for h in herois:
		placed.append(h[1])
	var kinds := ["caruncho", "caruncho_chifre", "caruncho", "traca", "caruncho", "caruncho_chifre", "bastidor", "caruncho"]
	var j := 0
	var tries := 0
	while j < 20 and tries < 4000:
		tries += 1
		var p := Vector3(rng.randf_range(-5.4, 5.4), 0, rng.randf_range(-2.4, 4.4))
		var ok := true
		for q in placed:
			if p.distance_to(q) < (1.15 if j < 20 else 1.0):
				ok = false; break
		if not ok:
			continue
		placed.append(p)
		var near: Vector3 = herois[0][1]
		for h in herois:
			if p.distance_to(h[1]) < p.distance_to(near):
				near = h[1]
		var kind: String = kinds[j % kinds.size()]
		if kind == "bastidor" and p.z > 2.0:
			kind = "caruncho"
		var b = Boneco.new(); add_child(b); b.setup(kind, Color8(0, 255, 10 + 10 * j) if mask else null)
		b.position = p; b.rotation.y = atan2(near.x - p.x, near.z - p.z)
		# v2: variação de tamanho no enxame (0,8 a 1,2)
		if kind.begins_with("caruncho"):
			b.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)
		if aneis:
			b.visible = false
		var an := "idle"
		if kind == "caruncho" and j % 3 == 1:
			an = "telegrafia"
		elif kind.begins_with("caruncho") and j % 3 == 2:
			an = "andar"
		b.pose(an, rng.randf_range(0.0, 0.25) + 0.001)
		if not mask:
			por_em_cena(b, false)
		S["e"].append(b); j += 1
	if not mask:
		# telegrafias: faixa de um caruncho e retângulo de um bastidor
		for b in S["e"]:
			if b.anim == "telegrafia" and b.nome == "caruncho":
				var d := Vector3(sin(b.rotation.y), 0, cos(b.rotation.y))
				decal(Vector2(2.2, 0.55), b.position + d * 1.2 + Vector3(0, 0.012, 0), palco.sm("perigo", {"modo": 2, "fecha": 0.6, "tam": Vector2(2.2, 0.55), "sentido": float(A("sentido", "-1"))}), rad_to_deg(b.rotation.y) + 90.0)
				break
	S["fx_alvo"] = S["e"][0].position

func _tick_estresse(f: int) -> void:
	if mask or A("fx", "1") == "0":
		return
	var alvo: Vector3 = S["h"][0].position + Vector3(sin(deg_to_rad(40)), 0, cos(deg_to_rad(40))) * 1.3
	var q := frames - 2
	# efeito 1: estouro de Serragem do Tarugo (choque, lascas, nuvem em flipbook)
	if f == q - 5:
		vfx.serragem(alvo + Vector3(0, 0.4, 0), Vector3(0.4, 0.3, 0.3), 60)
		vfx.onda(alvo, PCOR[0], PCOR[3], 1.15, 0.45)
		vfx.nuvem(alvo + Vector3(0, 0.45, 0) + (cam.global_position - alvo).normalized() * 0.4, 1.0)
	# efeito 2: pincelada de Tinta da Anilina (rastro + gotas)
	var N = S["h"][3]
	if f >= q - 16 and f < q:
		var tt := 14 + (f - (q - 16))
		N.pose("golpe", tt / 60.0 + 0.001)
		if S.get("fitaN") == null:
			S["fitaN"] = vfx.nova_fita(PCOR[3])
			S["fitaN"]["m"].set_shader_parameter("opac", 0.8)
		vfx.fita_ponto(S["fitaN"], _tip(N, 1.12), N.global_position + Vector3(0, 0.75, 0))
		if f % 3 == 0:
			vfx.gotas(_tip(N, 1.12), Vector3(0, 1, 0), 2)
	# efeito 3: Rastilho (Linha + Estalo): fio de Linha da Retrós com estrelas de faísca do Estalo nos nós
	if f == q - 8:
		var R = S["h"][1]
		var a: Vector3 = R.position + Vector3(0, 0.6, 0)
		var pts: Array = [a]
		var used := {}
		for k in 3:
			var best = null
			for e in S["e"]:
				if used.has(e) or not e.nome.begins_with("caruncho"):
					continue
				if best == null or e.position.distance_to(pts[-1]) < best.position.distance_to(pts[-1]):
					best = e
			used[best] = true
			pts.append(best.position + Vector3(0, 0.35, 0))
		var fio = vfx.nova_fita(PCOR[1])
		fio["w"] = 0.035
		fio["hist"] = 999
		fio["m"].set_shader_parameter("cor", Color("#F2E6C8"))
		fio["m"].set_shader_parameter("borda", Color("#B8A98A"))
		for p2 in pts:
			fio["pts"].push_front(p2)
			fio["ts"].push_front(fio["q"])
		for p2 in pts.slice(1):
			vfx.seda_estrela(p2 + (cam.global_position - p2).normalized() * 0.2, Color("#EBC979"), 0.42, randf() * 3.0, 0.5)
			for k in 6:
				vfx.emit(p2, Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2)), 0.03, 3, 3, 0.6)
	vfx.step(1.0)
	vfx.draw(1.0)
