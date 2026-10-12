class_name Look
extends RefCounted
## Shared look: vinyl materials, blob shadow and dust puffs.


## Make imported glTF materials read as glossy vinyl: soft rim light and a clear coat.
static func vinylize(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var mat: StandardMaterial3D = src.duplicate()
				mat.rim_enabled = true
				mat.rim = 0.35
				mat.rim_tint = 0.6
				mat.clearcoat_enabled = true
				mat.clearcoat = 0.6
				mat.clearcoat_roughness = 0.15
				mat.metallic_specular = 0.6
				m.set_surface_override_material(i, mat)


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
	m.no_depth_test = false
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
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 8
	s.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.97, 0.92)
	mat.roughness = 0.6
	mat.vertex_color_use_as_albedo = true
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
