class_name Look
extends RefCounted
## Shared look: character materials (shell fur, leather, brass, knit, glass, eyes),
## level materials, blob shadow and dust.

static var _strands: Texture2D
static var _grain: Texture2D
static var _knit: Texture2D


static func compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


static func strands() -> Texture2D:
	if _strands == null:
		var img := Image.create(128, 128, true, Image.FORMAT_L8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for y in 128:
			for x in 128:
				img.set_pixel(x, y, Color(rng.randf(), 0, 0))
		img.generate_mipmaps()
		_strands = ImageTexture.create_from_image(img)
	return _strands


static func _noise_normal(freq: float, bump: float, cellular := false) -> Texture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = bump
	return t


## Fur as a chain of shell passes. Fewer shells on the web/Compatibility renderer.
static func fur_material(length: float) -> ShaderMaterial:
	var shells := 7 if compat() else 18
	var shader: Shader = load("res://shaders/fur.gdshader")
	var first: ShaderMaterial = null
	var prev: ShaderMaterial = null
	for i in shells + 1:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("shell", float(i) / shells)
		m.set_shader_parameter("fur_length", length)
		m.set_shader_parameter("strands", strands())
		m.set_shader_parameter("density", 6.0)
		m.render_priority = i
		if prev == null:
			first = m
		else:
			prev.next_pass = m
		prev = m
	return first


static func leather(color: Color, rough := 0.55) -> StandardMaterial3D:
	if _grain == null:
		_grain = _noise_normal(0.09, 6.0, true)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.normal_enabled = true
	m.normal_texture = _grain
	m.normal_scale = 0.5
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(6, 6, 6)
	m.clearcoat_enabled = true
	m.clearcoat = 0.25
	m.clearcoat_roughness = 0.35
	return m


static func knit(color: Color) -> StandardMaterial3D:
	if _knit == null:
		_knit = _noise_normal(0.06, 10.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.normal_enabled = true
	m.normal_texture = _knit
	m.normal_scale = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(14, 14, 14)
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.7
	return m


static func metal(color: Color, rough := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 1.0
	m.roughness = rough
	return m


static func glass(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic_specular = 1.0
	return m


static func eye(tex_path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.roughness = 0.08
	m.metallic_specular = 0.9
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.02
	return m


static func plain(color: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## Swap the placeholder glTF materials (matched by name) for the real ones.
static func dress(root: Node, fur_len: float) -> void:
	var cache := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			var name := src.resource_name if src else ""
			if not cache.has(name):
				cache[name] = _make(name, fur_len)
			if cache[name] != null:
				m.set_surface_override_material(i, cache[name])


static func _make(name: String, fur_len: float) -> Material:
	match name:
		"fur":
			return fur_material(fur_len)
		"eye":
			return eye("res://assets/eye_bolo.png")
		"owl_eye":
			return eye("res://assets/eye_owl.png")
		"lid":
			return plain(Color("a8401a"), 0.8)
		"nose":
			var n := plain(Color("1b1210"), 0.4)
			n.clearcoat_enabled = true
			n.clearcoat = 0.4
			return n
		"mitten":
			return leather(Color("3e2418"), 0.5)
		"boot":
			return leather(Color("9a6a42"), 0.55)
		"bag":
			return leather(Color("5a3320"), 0.45)
		"sole":
			return plain(Color("3a2f28"), 0.85)
		"knit":
			return knit(Color("2f6f73"))
		"brass":
			return metal(Color("c9a24a"), 0.28)
		"lens":
			return glass(Color("bfe4ff"))
		"talon", "beak":
			return plain(Color("d9c48a"), 0.45)
	return null


static func vinyl(color: Color, rough := 0.38) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	m.metallic_specular = 0.55
	return m


static func blob_shadow() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.08, 0.05, 0.15, a * a * 0.55))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.render_priority = 1
	return m


static func dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.55
	p.amount = 8
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	s.radial_segments = 8
	s.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.89, 0.82)
	mat.roughness = 0.9
	s.material = mat
	p.mesh = s
	p.direction = Vector3(0, 0.4, 0)
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -2.0, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.05
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	p.local_coords = false
	return p
