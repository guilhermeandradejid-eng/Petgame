class_name IceLance
extends Node2D
## A crystal spear that pierces everything in a line and freezes it solid.

const SPEED := 10.0
const HEIGHT := 22.0
const DAMAGE := 2
const FREEZE := 2.6

var world: Node
var g := Vector2.ZERO
var dir := Vector2.RIGHT
var max_dist := 9.0
var traveled := 0.0
var hit := {}
var spr: Sprite2D
var trail: CPUParticles2D


func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = preload("res://assets/gen/fx/ice_lance.png")
	spr.hframes = 16
	spr.position = Vector2(0, -HEIGHT)
	var gx := dir.x - dir.y
	var gd := -(dir.x + dir.y)
	spr.frame = posmod(int(round(atan2(gd, gx) / (TAU / 16.0))), 16)
	add_child(spr)
	trail = CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 30
	trail.lifetime = 0.4
	trail.position = Vector2(0, -HEIGHT)
	trail.spread = 180.0
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 20.0
	trail.gravity = Vector2(0, 40)
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.0
	trail.color = Color(0.85, 0.97, 1.0)
	add_child(trail)
	var l: PointLight2D = world.make_light(Color(0.7, 0.92, 1.0), 0.9, 0.6, 20.0)
	l.position = Vector2(0, -HEIGHT)
	add_child(l)
	position = Iso.to_screen(g)


func _process(delta: float) -> void:
	var step := dir * SPEED * delta
	g += step
	traveled += step.length()
	position = Iso.to_screen(g)
	for e in world.enemies:
		if e.alive() and e.visible and not hit.has(e) and e.g.distance_to(g) < 0.55:
			hit[e] = true
			e.take_damage(DAMAGE, g - dir, 1.5)
			e.freeze(FREEZE)
			FxAnim.spawn(world.fx_layer, preload("res://assets/gen/fx/ice_burst.png"), 6, e.position + Vector2(0, -12), 18.0, 5)
			world.hitstop(0.04)
	if not world.walkable(g) or traveled >= max_dist:
		_shatter()


func _shatter() -> void:
	FxAnim.spawn(world.fx_layer, preload("res://assets/gen/fx/ice_burst.png"), 6, position + Vector2(0, -HEIGHT), 16.0, 5)
	world.burst(position + Vector2(0, -HEIGHT), Color(0.85, 0.97, 1.0), 12)
	queue_free()
