class_name Pickup
extends Node3D
## Saque individual (cada jogador ve e coleta o seu): moedas, coracoes e fragmentos.

var kind := "coin"
var value := 1
var vel := Vector3.ZERO
var age := 0.0
var mesh: Node3D

func setup(p_kind: String, p_value: int, pos: Vector3) -> void:
	kind = p_kind
	value = p_value
	position = pos + Vector3(0, 0.5, 0)
	var a := randf() * TAU
	vel = Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(4.0, 6.5), sin(a) * randf_range(1.5, 3.5))

func _ready() -> void:
	var piece: String = {"coin": "coin", "heart": "heart", "shard": "shard"}.get(kind, "coin")
	mesh = KitLib.make("props", piece)
	if mesh == null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.16
		cm.height = 0.05
		cm.radial_segments = 8
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
		var col: Color = {"coin": Color("ffd23e"), "heart": Color("ff6b8a"), "shard": Color("7df9ff")}.get(kind, Color.WHITE)
		mi.material_override = Mats.toon(col, {"shade_boost": 0.5, "gloss": 1.0})
		mesh = mi
	add_child(mesh)

func _process(delta: float) -> void:
	age += delta
	var me: Player = Game.me()
	if mesh:
		mesh.rotate_y(delta * 4.0)
	if me == null:
		return
	var to := me.global_position + Vector3(0, 0.7, 0) - global_position
	var dist := to.length()
	var mag := float(me.stats.get("magnet", 2.2))
	if age > 0.45 and (dist < mag or age > 9.0) and me.alive():
		vel = vel.lerp(to.normalized() * 16.0, 1.0 - exp(-10.0 * delta))
		if dist < 0.6:
			_collect(me)
			return
	else:
		vel.y -= 18.0 * delta
		if position.y <= 0.3 and vel.y < 0.0:
			position.y = 0.3
			vel = Vector3(vel.x * 0.5, -vel.y * 0.35, vel.z * 0.5)
	position += vel * delta
	position.y = maxf(position.y, 0.25)

func _collect(me: Player) -> void:
	match kind:
		"coin":
			me.gold += value
			Sfx.play("coin", global_position, 0.5)
		"heart":
			me.heal(float(value))
			Sfx.play("heal", global_position, 0.6)
		"shard":
			Save.add_shards(value)
			Sfx.play("shard", global_position, 0.7)
	queue_free()
