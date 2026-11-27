extends Node3D
# Prova de estilo "A Pequena Hoste": monta as cenas por código e captura quadros.
# Args (depois de --): cena=folha|poses|vau|estresse  out=arquivo.png  frames=N  pc=1 (nível PC) ...

const Boneco = preload("res://boneco.gd")
const PAL := ["#231C17", "#E9DFC9", "#E3C99A", "#8E97A3", "#A8834F", "#7D8A5A", "#6E4A33", "#6F8894", "#C9A55A", "#5E8F7E",
	"#E2672B", "#F4F1E8", "#7FA3E0", "#F2E6C2", "#D9472B", "#E8B23A", "#3F62C8", "#9B3FA8", "#A8D82A",
	"#2F4677", "#6B2A63", "#B5301F"]
const COR_JOG := {"porta": "#D9472B", "sineira": "#E8B23A", "sapador": "#3F62C8", "bruxa": "#9B3FA8"}

var cam: Camera3D
var sun: DirectionalLight3D
var we: WorldEnvironment
var env: Environment
var pos_mat: ShaderMaterial
var luz_img: Image
var luz_tex: ImageTexture
var frame_i := 0
var frames := 4
var cena := ""
var pc := false
var t := 0.0
var luzes: Array = []      # [{p:Vector3, r:float, k:float, q:float}]
var reservas: Array = []   # [Vector3]
var cena_obj = null

func A(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d

func F(k: String, d: float) -> float:
	return float(A(k, str(d)))

func lin(h: String) -> Color:
	return Color(h).srgb_to_linear()

func _ready() -> void:
	cena = A("cena", "folha")
	frames = int(A("frames", "4"))
	pc = A("pc", "0") == "1"
	_globais()
	if A("msaa", "") != "":
		get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(A("msaa", "0"))]
	_env()
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_pos()
	match cena:
		"folha":
			_folha()
		"poses":
			_poses()
		_:
			var S = load("res://cena_%s.gd" % cena)
			cena_obj = S.new()
			add_child(cena_obj)
			cena_obj.setup(self)

func _globais() -> void:
	gset("conv_cor", 1.0 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0.0)
	var g := Image.load_from_file(ProjectSettings.globalize_path("res://assets/tex/grao.png"))
	RenderingServer.global_shader_parameter_set("grao", ImageTexture.create_from_image(g))
	luz_img = Image.create(16, 4, false, Image.FORMAT_RGBAF)
	luz_tex = ImageTexture.create_from_image(luz_img)
	RenderingServer.global_shader_parameter_set("luzes", luz_tex)
	gset("alvo_px", F("alvo", 4.5) * float(A("h", "1080")) / 1080.0 if A("alvo_rel", "0") == "1" else F("alvo", 4.5))

func gset(k: String, v) -> void:
	RenderingServer.global_shader_parameter_set(k, v)

func atualiza_luzes() -> void:
	luz_img.fill(Color(0, 0, 0, 0))
	var n := mini(luzes.size(), 16)
	for i in n:
		var L: Dictionary = luzes[i]
		var p: Vector3 = L["p"]
		luz_img.set_pixel(i, 0, Color(p.x, p.y, p.z, L["r"]))
		luz_img.set_pixel(i, 1, Color(L.get("k", 1.0), L.get("q", 1.0), 0, 0))
	for i in mini(reservas.size(), 4):
		var p: Vector3 = reservas[i]
		luz_img.set_pixel(i, 2, Color(p.x, p.y, p.z, 1.2))
	luz_tex.update(luz_img)
	gset("n_luzes", n)

func _env() -> void:
	we = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(A("bg", "#E3C99A"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)
	sol(Vector3(-0.55, 0.62, 0.55))

func sol(d: Vector3) -> void:
	d = d.normalized()
	sun.look_at_from_position(d * 10.0, Vector3.ZERO, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	gset("sol_dir", d)

func _pos() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_mat = ShaderMaterial.new()
	pos_mat.shader = load("res://shaders/pos.gdshader")
	var pal: Array[Vector3] = []
	for h in PAL:
		var c := Color(h)
		pal.append(Vector3(c.r, c.g, c.b))
	pos_mat.set_shader_parameter("pal", pal)
	pos_mat.set_shader_parameter("npal", pal.size())
	pos_mat.set_shader_parameter("tilt", F("tilt", 0.0))
	pos_mat.set_shader_parameter("peneira", F("peneira", 1.0))
	pos_mat.set_shader_parameter("registro", F("registro", 1.5) * float(get_viewport().size.y) / 1080.0)
	cr.material = pos_mat
	cl.add_child(cr)
	if A("pos", "1") == "0":
		cl.visible = false

func boneco(n: String, pos: Vector3, yaw: float, anim := "", tt := 0.0, px := 1.5):
	var b = Boneco.new()
	add_child(b)
	if A("mask", "0") == "1":
		b.setup(n, px, Color(0, 0, 0))
	else:
		b.setup(n, px)
	b.position = pos
	b.rotation.y = deg_to_rad(yaw)
	if anim != "":
		b.pose(anim, tt)
	return b

func _folha() -> void:
	gset("curva_k", 0.0)
	gset("escuro_base", F("eb", 0.35))
	gset("escuro_faixa", F("ef", 2.9))
	gset("frente_x", Vector2(-100, -99))
	gset("nevoa", Vector4(100, 200, 0, 1))
	var who := A("who", "porta,sineira").split(",")
	var yaws := [0.0, 40.0, 90.0]
	if A("yaws", "") != "":
		yaws = []
		for y in A("yaws", "").split(","):
			yaws.append(float(y))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	var n := who.size() * yaws.size()
	var dx := F("dx", 0.75)
	cam.size = n * dx
	var cx := (n - 1) * dx * 0.5
	var pit := deg_to_rad(F("pitch", 10))
	var cy := F("cy", 0.55)
	cam.look_at_from_position(Vector3(cx, cy + 20.0 * sin(pit), 20.0 * cos(pit)), Vector3(cx, cy, 0))
	var k := 0
	for w in who:
		for y in yaws:
			var bb = boneco(w, Vector3(k * dx, 0, 0), y, A("anim", "idle" if w != "carpideira" else "flutua"), F("at", 0.0), F("px", 1.5))
			equipa(bb)
			k += 1

func prop(n: String) -> Node3D:
	var s = Boneco.new(); add_child(s)
	if A("mask", "0") == "1":
		s.setup(n, 1.5, Color(0, 0, 0))
	else:
		s.setup(n, 1.5)
	return s

# adereços padrão de cada boneco
func equipa(b, sem_mastro := false) -> Dictionary:
	var out := {}
	match b.nome:
		"porta":
			if not sem_mastro:
				var m = prop("mastro"); b.anexar(m, "costas", Transform3D(Basis(), Vector3(0, -0.3, 0.02))); out["mastro"] = m
		"sineira":
			var s = prop("sino"); b.anexar(s, "prop"); out["sino"] = s
		"miliciano":
			var p = prop("piquemil"); b.anexar(p, "hand.R", Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.05, 0)).translated_local(Vector3(0, -0.45, 0))); out["pique"] = p
	return out

func _poses() -> void:
	gset("curva_k", 0.0)
	gset("escuro_base", F("eb", 0.0))
	gset("escuro_faixa", F("ef", 3.6))
	gset("frente_x", Vector2(-100, -99))
	gset("nevoa", Vector4(100, 200, 0, 1))
	var who := A("who", "sineira")
	var an := A("anim", "passa")
	var ts := A("ts", "0,4,9,12,16,20,30,40").split(",")
	var dx := F("dx", 0.8)
	var n := ts.size()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = n * dx
	var cx := (n - 1) * dx * 0.5
	var pit := deg_to_rad(F("pitch", 12))
	var cy := F("cy", 0.55)
	var yw := deg_to_rad(F("yaw", 60))
	cam.look_at_from_position(Vector3(cx, cy + 20.0 * sin(pit), 20.0 * cos(pit)), Vector3(cx, cy, 0))
	for i in n:
		var bb = boneco(who, Vector3(i * dx, 0, 0), rad_to_deg(yw), an, float(ts[i]) / 60.0, F("px", 1.5))
		equipa(bb)

func _process(delta: float) -> void:
	t = frame_i / 60.0
	gset("tempo", t)
	if cena_obj:
		cena_obj.passo(t, frame_i)
	atualiza_luzes()
	frame_i += 1
	if frame_i == frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(A("out", "/tmp/out.png"))
		print("PROBE salvo ", A("out", ""))
		get_tree().quit()
