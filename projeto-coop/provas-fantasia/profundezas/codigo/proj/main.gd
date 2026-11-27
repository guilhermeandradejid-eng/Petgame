extends Node3D
# Prova de estilo Plumbdeep. Cenas: folha (folha de modelo), poses, poca (quadro bonito e clipe), estresse.
const Boneco = preload("res://boneco.gd")

var args := {}
var out := ""
var frames := 3
var f := 0
var cam: Camera3D
var sol: DirectionalLight3D
var env: WorldEnvironment
var cena_passo := Callable()

func arg(k: String, d: Variant = null) -> Variant:
	if not args.has(k):
		return d
	var v: String = args[k]
	if d is float: return float(v)
	if d is int: return int(v)
	if d is bool: return v == "1" or v == "true"
	return v

func gp(n: String, tipo: int, v) -> void:
	RenderingServer.global_shader_parameter_add(n, tipo, v)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	out = arg("out", "")
	frames = arg("frames", 3)
	var V4 := RenderingServer.GLOBAL_VAR_TYPE_VEC4
	gp("nevoa_cor", V4, Vector4(0.36, 0.42, 0.5, 0.0))
	gp("nevoa_par", V4, Vector4(20.0, 250.0, 0.3, 0.4))
	gp("nevoa_alt", V4, Vector4(-3.0, 0.006, 0.0, 6.0))
	gp("nevoa_alt_cor", V4, Vector4(0.42, 0.5, 0.58, 1.0))
	gp("dbg", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, float(arg("dbg", 0.0)))
	gp("vento", V4, Vector4(1, 0, 0.5, 0))
	gp("resp", V4, Vector4(0, 0, 0, 0))
	gp("flash", V4, Vector4(0, 0, 0, 0))
	gp("flash_cor", V4, Vector4(0.4, 0.9, 1.0, 1.0))
	for i in 10:
		gp("lq%d" % i, V4, Vector4(0, -999, 0, 0))
	match arg("cena", "folha"):
		"folha":
			cena_folha()
		"poses":
			cena_poses()
		"poca":
			var C = load("res://cena_poca.gd").new()
			add_child(C)
			C.montar(self)
			cena_passo = C.passo
		"estresse":
			var C = load("res://cena_estresse.gd").new()
			add_child(C)
			C.montar(self)
			cena_passo = C.passo
		_:
			push_error("cena?")

func gset(n: String, v) -> void:
	RenderingServer.global_shader_parameter_set(n, v)

func base_luz(az := -135.0, el := 50.0, energia := 1.0) -> void:
	sol = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-el, az, 0)
	sol.light_energy = energia
	sol.shadow_enabled = true
	sol.light_volumetric_fog_energy = 0.12
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

func _process(_d: float) -> void:
	if cena_passo.is_valid():
		cena_passo.call(f)
	f += 1
	if f >= frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("PROBE salvo ", out, " ", img.get_size())
		get_tree().quit()
		OS.kill(OS.get_process_id())
		set_process(false)

# ------------------------------------------------------------------ folha de modelo
const CORES := {"escorador": "ambar", "cristaleira": "cobalto", "coveira": "giz", "gancheiro": "veneno"}
func cena_folha() -> void:
	ambiente(Color(arg("bg", "#2a2c33")))
	base_luz(arg("az", -135.0), arg("el", 60.0), arg("luz", 1.0))
	var who: Array = String(arg("who", "escorador,cristaleira,coveira,gancheiro")).split(",")
	var yaws: Array = [0.0, 35.0, 90.0]
	if args.has("yaws"):
		yaws = []
		for y in String(arg("yaws", "")).split(","):
			yaws.append(float(y))
	var dx: float = arg("dx", 1.1)
	var x0 := -dx * (who.size() * yaws.size() - 1) / 2.0
	var i := 0
	for w in who:
		for y in yaws:
			var b = Boneco.new()
			add_child(b)
			b.setup(w)
			b.jogo = arg("jogo", 0) == 1
			b.position = Vector3(x0 + i * dx, 0, 0)
			b.rotation_degrees.y = y
			b.todos("dano", arg("dano", 0.0))
			b.todos("pintura", arg("pintura", 1.0))
			if w == "ouvidor" and arg("perigo", 0) == 1:
				b.param(["emis"], "perigo", 1.0)
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

func cena_poses() -> void:
	ambiente(Color(arg("bg", "#2a2c33")))
	base_luz(arg("az", -135.0), arg("el", 60.0))
	var w: String = arg("who", "gancheiro")
	var a: String = arg("anim", "folha")
	var qs: Array = String(arg("q", "0,1,2,3,4,5,6,7")).split(",")
	var dx: float = arg("dx", 1.2)
	var x0 := -dx * (qs.size() - 1) / 2.0
	for i in qs.size():
		var b = Boneco.new()
		add_child(b)
		b.setup(w)
		b.position = Vector3(x0 + i * dx, 0, 0)
		b.rotation_degrees.y = arg("yaw", 30.0)
		b.pose(a, float(qs[i]) / 60.0)
		if w == "ouvidor" and int(qs[i]) == 1:
			b.param(["emis"], "perigo", 1.0)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = arg("size", 1.6)
	add_child(cam)
	cam.rotation_degrees = Vector3(-arg("pitch", 20.0), 0, 0)
	cam.position = Vector3(0, float(arg("cy", 0.55)), 0) + cam.global_transform.basis.z * 20.0
	cam.current = true
