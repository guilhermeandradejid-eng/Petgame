extends Node3D
## Graybox test course. Each station exercises one mechanic and is labelled in the world.

const MINT := Color("8fd1a8")
const CREAM := Color("efe4d2")
const PEACH := Color("ff9f78")
const LILAC := Color("a98ce6")
const SKY := Color("6fb6f0")
const LEMON := Color("ffd45e")

var bolo: Bolo
var pip: Pip
var cam: OrbitCam
var checker: Texture2D


func _ready() -> void:
	Controls.setup()
	checker = _checker()
	_environment()
	_course()

	bolo = Bolo.new()
	bolo.position = Vector3(0, 0.1, 8)
	# testing aid: #at=x,y,z in the web URL (or --at=x,y,z) starts Bolo somewhere else
	var at := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			at = a.substr(5)
	if OS.has_feature("web"):
		var h := str(JavaScriptBridge.eval("location.hash"))
		if h.contains("debug"):
			bolo.debug = true
		var i := h.find("at=")
		if i >= 0:
			at = h.substr(i + 3).split(";")[0]
	if at != "":
		var p := at.split(",")
		if p.size() >= 3:
			bolo.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	add_child(bolo)
	cam = OrbitCam.new()
	cam.target = bolo
	bolo.cam = cam
	add_child(cam)
	pip = Pip.new()
	pip.bolo = bolo
	bolo.pip = pip
	add_child(pip)

	var ui := CanvasLayer.new()
	add_child(ui)
	var touch := preload("res://scripts/touch_ui.gd").new()
	ui.add_child(touch)


# ---------------------------------------------------------------- world

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f9fe8")
	sm.sky_horizon_color = Color("bfe2ff")
	sm.sky_energy_multiplier = 1.0
	sm.ground_bottom_color = Color("cfe3d0")
	sm.ground_horizon_color = Color("e6f3ff")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# a soft lilac-grey fill instead of the sky's blue keeps the pastel colours true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9d3e6")
	# the Compatibility renderer (web, phones) has no HDR headroom: keep it linear and dimmer
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	env.ambient_light_energy = 0.32 if compat else 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if compat else Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color("e6f3ff")
	env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 0.78 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.1
	sun.light_color = Color("fff3e0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _checker() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var on := ((x / 32) + (y / 32)) % 2 == 0
			img.set_pixel(x, y, Color(1, 1, 1) if on else Color(0.9, 0.9, 0.92))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mat(color: Color) -> StandardMaterial3D:
	var m := Look.vinyl(color, 0.55)
	m.albedo_texture = checker
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


func box(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation_degrees = rot
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	add_child(b)
	return b


## A box standing on the ground (or on y0) with its top at `top`.
func block(x: float, z: float, w: float, d: float, top: float, color: Color, y0 := 0.0) -> void:
	box(Vector3(x, y0 + (top - y0) * 0.5, z), Vector3(w, top - y0, d), color)


func sign3d(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 48
	l.pixel_size = 0.004
	l.outline_size = 14
	l.modulate = Color("3a2a55")
	l.outline_modulate = Color(1, 1, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(l)


func _course() -> void:
	box(Vector3(0, -0.5, -10), Vector3(90, 1, 90), MINT)

	# spawn pad and open area for running and skidding
	block(0, 8, 6, 6, 0.15, CREAM)
	sign3d("Corrida e derrapagem\n(inverta a direção correndo)", Vector3(5, 2.2, 2))

	# steps of growing height
	sign3d("Degraus", Vector3(-9, 3.6, 4))
	for i in 5:
		block(-9, 2 - i * 2.2, 2.4, 2.2, 0.5 * (i + 1), PEACH)

	# a wall only the double jump clears (single jump apex 2.4 m)
	block(9, -2, 4, 3, 3.6, LILAC)
	sign3d("Pulo duplo\n(pule de novo no ar)", Vector3(9, 5.0, 0.2))

	# glide gap: climb to A (4 m), cross 9 m of air to B (3 m)
	block(-12, -14, 4, 4, 4.0, SKY)
	block(-15, -10.5, 2.5, 2.5, 2.0, SKY)
	block(-15, -13.5, 2.5, 2.5, 3.0, SKY)
	block(1, -14, 4, 4, 3.0, SKY)
	sign3d("Planar\n(segure o pulo caindo)", Vector3(-5.5, 6.2, -14))

	# ledge wall: too tall to land on, perfect to grab
	block(-2, -26, 10, 3, 2.9, LEMON)
	sign3d("Borda\n(pule na parede e agarre)", Vector3(-2, 4.6, -23.5))

	# tower for the heavy landing, with a spiral of steps
	var tower_x := 13.0
	var tower_z := -22.0
	block(tower_x, tower_z, 3, 3, 10.0, CREAM)
	for i in 11:
		var a := i * 0.9
		var r := 3.0
		block(tower_x + cos(a) * r, tower_z + sin(a) * r, 1.6, 1.6, 0.9 * (i + 1), PEACH, 0.9 * (i + 1) - 0.4)
	sign3d("Pouso pesado\n(pule lá de cima)", Vector3(tower_x, 11.6, tower_z))

	# ramps
	box(Vector3(-20, 1.0, 4), Vector3(4, 0.4, 8), PEACH, Vector3(-14, 0, 0))
	box(Vector3(-26, 1.9, 4), Vector3(4, 0.4, 8), LILAC, Vector3(-28, 0, 0))
	sign3d("Rampas", Vector3(-23, 4.5, 4))

	# a few soft vinyl props for scale
	for p in [Vector3(6, 0, 10), Vector3(-5, 0, 13), Vector3(18, 0, 2), Vector3(-20, 0, -18)]:
		_tree(p)


func _tree(p: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.25
	c.bottom_radius = 0.35
	c.height = 2.0
	trunk.mesh = c
	trunk.material_override = Look.vinyl(Color("b9805a"))
	trunk.position = p + Vector3.UP
	add_child(trunk)
	for k in 3:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.1 - k * 0.2
		sm.height = sm.radius * 2.0
		s.mesh = sm
		s.material_override = Look.vinyl(Color("7cc96a").lightened(k * 0.08), 0.32)
		s.position = p + Vector3(0, 2.4 + k * 0.9, 0)
		add_child(s)
	var st := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.0
	cs.shape = cyl
	st.position = p + Vector3.UP
	st.add_child(cs)
	add_child(st)
