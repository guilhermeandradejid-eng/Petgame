class_name Planetoid
extends StaticBody3D
## Small planet with point gravity (Area3D gravity_point). Characters,
## crates and the camera all re-orient to its surface.

var radius := 6.0
var gravity_area: Area3D


func setup(_lvl: Node, r: float, style := "planet", gravity_range := 2.4) -> void:
	radius = r
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	mi.mesh = sm
	add_child(mi)
	mi.material_override = Mats.terrain(style, Vector3.ZERO, true).duplicate()
	(mi.material_override as ShaderMaterial).set_shader_parameter("planet_center", global_position if is_inside_tree() else Vector3.ZERO)
	mi.set_meta("needs_center", true)
	gravity_area = Area3D.new()
	gravity_area.collision_layer = 0
	gravity_area.collision_mask = 2 | 4
	gravity_area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity_area.gravity_point = true
	gravity_area.gravity_point_center = Vector3.ZERO
	gravity_area.gravity_point_unit_distance = 0.0
	gravity_area.gravity = 30.0
	gravity_area.priority = 1
	var gcs := CollisionShape3D.new()
	var gsh := SphereShape3D.new()
	gsh.radius = r * gravity_range
	gcs.shape = gsh
	gravity_area.add_child(gcs)
	add_child(gravity_area)
	# soft atmosphere halo
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = r * 1.12
	hm.height = r * 2.24
	halo.mesh = hm
	var hmat := ShaderMaterial.new()
	hmat.shader = ShaderLib.get_shader("bubble")
	hmat.set_shader_parameter("tint", Color(0.85, 0.95, 1.0))
	hmat.set_shader_parameter("wobble", 0.0)
	halo.material_override = hmat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)


func _ready() -> void:
	for c in get_children():
		if c.has_meta("needs_center"):
			(c.material_override as ShaderMaterial).set_shader_parameter("planet_center", global_position)


## World transform for something standing on the surface along `dir`.
func surface_xform(dir: Vector3, extra := 0.0) -> Transform3D:
	var up := dir.normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(ref).normalized()
	return Transform3D(Basis(x, up, x.cross(up)), global_position + up * (radius + extra))
