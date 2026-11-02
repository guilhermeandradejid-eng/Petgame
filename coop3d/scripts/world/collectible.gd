class_name Collectible
extends Area3D
## Sparks (common) and Star Seeds (3 hidden per level).
## Bob + spin, gentle magnet toward nearby players, then a juicy pickup:
## rising pentatonic chime, star burst, squash-pop and a hop toward the player.

const SPARK := preload("res://assets/models/spark.glb")
const SEED := preload("res://assets/models/star_seed.glb")

var level: Node
var kind := "spark"
var seed_index := -1
var taken := false
var _model: Node3D
var _base := Vector3.ZERO
var _up := Vector3.UP
var _t := 0.0
var _vel := Vector3.ZERO
var _magnet: Player = null


func setup(lvl: Node, k := "spark", idx := -1, up := Vector3.UP) -> void:
	level = lvl
	kind = k
	seed_index = idx
	_up = up
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.55 if kind == "spark" else 0.9
	cs.shape = sh
	add_child(cs)
	_model = (SPARK if kind == "spark" else SEED).instantiate()
	add_child(_model)
	Mats.stylize(_model, 0.0)
	if kind == "seed":
		_model.scale = Vector3.ONE * 1.6
		var l := OmniLight3D.new()
		l.light_color = Color(0.75, 0.55, 1.0)
		l.light_energy = 1.4
		l.omni_range = 4.0
		add_child(l)
	_t = randf() * TAU
	body_entered.connect(_on_body)


func _ready() -> void:
	_base = position


func _process(delta: float) -> void:
	if taken:
		return
	_t += delta
	_model.position = _up * sin(_t * 2.5) * 0.12
	_model.rotate(_up, delta * (2.2 if kind == "spark" else 1.2))
	# magnet: drift toward a nearby player (helps pickups feel generous)
	if _magnet == null and kind == "spark":
		for p in level.players:
			if not p.is_busy() and p.global_position.distance_to(global_position) < 2.2:
				_magnet = p
	if _magnet and is_instance_valid(_magnet):
		var target := _magnet.global_position + _magnet.up * 0.6
		_vel = _vel.lerp((target - global_position) * 9.0, 1.0 - exp(-8.0 * delta))
		global_position += _vel * delta


func _on_body(b: Node) -> void:
	if taken or not (b is Player) or b.is_busy():
		return
	collect(b)


func collect(p: Player) -> void:
	taken = true
	set_deferred("monitoring", false)
	if kind == "spark":
		Sfx.pickup()
		Vfx.burst(global_position, Color(1, 0.88, 0.35), 8, 3.5, 0.6)
		level.add_spark(p)
	else:
		Sfx.play("fanfare")
		Sfx.play("sparkle", 1.0)
		Juice.slowmo(0.3, 0.5)
		Juice.shake(0.2)
		Vfx.confetti(global_position, 40)
		Vfx.burst(global_position, Color(0.75, 0.55, 1.0), 24, 7.0, 1.4)
		Vfx.text_pop(global_position + _up, "Semente Estelar!", Color(0.85, 0.7, 1.0), 72)
		level.add_seed(seed_index, p)
	var tw := create_tween()
	tw.tween_property(_model, "scale", _model.scale * 1.6, 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "global_position", p.global_position + p.up * 1.6, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_model, "scale", Vector3.ZERO, 0.18).set_delay(0.06)
	tw.tween_callback(queue_free)
