class_name Crate
extends RigidBody3D
## Wooden crate: Bolota can carry and throw it, it weighs 2 on plates.
## `breakable` crates burst into sparks when pounded or dashed into.

var level: Node
var weight := 2
var breakable := false
var _held_by: Node = null
var _mesh: MeshInstance3D
var _home := Vector3.ZERO


func setup(lvl: Node, can_break := false) -> void:
	level = lvl
	breakable = can_break
	add_to_group("crate")
	if can_break:
		add_to_group("pound_target")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	mass = 3.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.1
	contact_monitor = true
	max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = bs
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)
	_mesh.mesh = bm
	var col := Color(0.95, 0.66, 0.38) if not breakable else Color(1.0, 0.8, 0.45)
	_mesh.material_override = Mats.toon(col, {"detail_normal": Mats.N_WOOD, "detail_strength": 0.7, "detail_scale": 1.0, "outline": 0.025})
	add_child(_mesh)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.04, 0.18, 1.04)
	band.mesh = bb
	band.material_override = Mats.toon(Color(0.45, 0.3, 0.25) if not breakable else Color(1.0, 0.85, 0.3), {"spec_amount": 0.8})
	add_child(band)
	if not breakable:
		var l := Label3D.new()
		l.text = "⬇⬇"
		l.font_size = 64
		l.position = Vector3(0, 0, 0.53)
		l.pixel_size = 0.006
		l.modulate = Color(1, 0.95, 0.8)
		l.outline_size = 10
		add_child(l)
	body_entered.connect(_on_hit)


func _ready() -> void:
	_home = global_position


func can_pick() -> bool:
	return _held_by == null and not breakable


func pick(by: Node) -> void:
	_held_by = by
	freeze = true
	collision_layer = 0
	collision_mask = 0


func throw(vel: Vector3) -> void:
	_held_by = null
	freeze = false
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	linear_velocity = vel
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))


func _physics_process(_delta: float) -> void:
	# respawn if it falls out of the world
	if _held_by == null and level and level.is_out_of_bounds(global_position):
		linear_velocity = Vector3.ZERO
		global_position = _home + Vector3.UP
		Vfx.burst(global_position, Color(1, 0.9, 0.6), 10, 3.0)


func _on_hit(_b: Node) -> void:
	if linear_velocity.length() > 6.0:
		Sfx.play("thud", 1.5, -8.0)
		Vfx.dust(global_position - Vector3.UP * 0.5, Vector3.UP, 4, 0.7)


func on_pound(p: Node) -> void:
	if breakable:
		smash(p)


func on_dash(p: Node) -> void:
	if breakable and p.heavy:
		smash(p)


func smash(_p: Node) -> void:
	if not is_inside_tree():
		return
	Sfx.play("break", 1.0)
	Juice.hitstop(0.04)
	Juice.shake(0.15)
	Vfx.burst(global_position, Color(1, 0.75, 0.4), 18, 6.0, 1.2)
	Vfx.dust(global_position, Vector3.UP, 10, 1.3)
	for i in 4:
		level.spawn_spark(global_position + Vector3(randf_range(-0.8, 0.8), 0.6 + i * 0.25, randf_range(-0.8, 0.8)))
	queue_free()
