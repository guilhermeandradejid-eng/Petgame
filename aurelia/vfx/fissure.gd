class_name Fissure
extends Node3D
## "Quake Cleave": a glowing crack races across the ground, throwing rocks up and launching whatever
## stands on it.

const SHADER := preload("res://vfx/shaders/fissure.gdshader")
const LENGTH := 7.5
const TICKS := 18

var special: SpecialData
var dir := Vector3.RIGHT
var owner_peer := 1
var age := 0
var hit_set: Array = []
var _mat: ShaderMaterial
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(LENGTH, 1.5)
	q.center_offset = Vector3(LENGTH * 0.5, 0, 0)
	_mesh.mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("color", special.color)
	_mat.set_shader_parameter("seed", float(randi() % 100))
	_mesh.material_override = _mat
	_mesh.rotation_degrees = Vector3(-90, 0, 0)
	_mesh.position.y = 0.04
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	if dir.x < 0.0:
		rotation.y = PI
	Juice.shake(0.5)


func _physics_process(_delta: float) -> void:
	age += 1
	var t := clampf(float(age) / TICKS, 0.0, 1.0)
	_mat.set_shader_parameter("progress", t * 1.05)
	if age > TICKS:
		_mat.set_shader_parameter("fade", clampf(1.0 - float(age - TICKS) / 40.0, 0.0, 1.0))
	var head := LENGTH * t
	if age % 2 == 0 and age <= TICKS:
		Juice.shake(0.08)
		var p := global_position + dir * head
		Juice.rock_burst(p, special.color, 1 + age % 2)
		if age % 4 == 0:
			Sfx.play("step", -6.0, 0.6)
	if owner_peer == multiplayer.get_unique_id() and age <= TICKS + 2:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e in hit_set or e.is_dead():
				continue
			var rel: Vector3 = e.global_position - global_position
			var along := rel.dot(dir)
			var side := absf(rel.dot(Vector3(-dir.z, 0, dir.x)))
			if along > -0.5 and along < head + 0.4 and side < 0.7 + e.data.radius_m:
				hit_set.append(e)
				Combat.deal(e, owner_peer, global_position, dir, {
					"dmg": special.damage, "kb": special.knockback, "launch": special.launch_height_px, "hs": special.hitstop,
					"sh": special.shake, "col": special.color, "sfx": "hit_heavy", "sp": 2.0, "id": special.id, "seed": age})
	if age > TICKS + 45:
		queue_free()
