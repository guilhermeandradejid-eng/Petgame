class_name Comet
extends Node2D
## A burning star-rock called down on a point. Falls, cracks the ground, knocks everything away.

const FALL := 0.38
const RADIUS := 1.8
const DAMAGE := 3
const START := Vector2(165, -300)

var world: Node
var g := Vector2.ZERO
var marker: Node2D = null
var t := 0.0
var spr: Sprite2D
var trail: CPUParticles2D
var light: PointLight2D


func _ready() -> void:
	z_index = 10
	position = Iso.to_screen(g)
	spr = Sprite2D.new()
	spr.texture = preload("res://assets/gen/fx/comet.png")
	spr.hframes = 6
	spr.centered = false
	spr.offset = -Vector2(29, 54)
	add_child(spr)
	trail = CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 40
	trail.lifetime = 0.35
	trail.direction = Vector2(0.55, -1.0)
	trail.spread = 25.0
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 60.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.0
	trail.color_ramp = _ramp([Color(1, 0.95, 0.7), Color(0.96, 0.77, 0.32), Color(0.7, 0.42, 0.85, 0.0)])
	add_child(trail)
	light = world.make_light(Color(1.0, 0.8, 0.45), 1.2, 0.8, 30.0)
	add_child(light)
	_place(0.0)


static func _ramp(cols: Array) -> Gradient:
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gr.colors = PackedColorArray(cols)
	return gr


func _place(k: float) -> void:
	var p := START.lerp(Vector2.ZERO, k * k)
	spr.position = p
	trail.position = p
	light.position = p


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	spr.frame = int(t * 20.0) % 6
	_place(clamp(t / FALL, 0.0, 1.0))
	if t >= FALL:
		_impact()


func _draw() -> void:
	# its shadow grows on the ground as it comes down
	var k: float = clamp(t / FALL, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 4.0 + 14.0 * k, Color(0.05, 0.02, 0.1, 0.18 + 0.3 * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _impact() -> void:
	var at := position
	world.shake(7.0)
	world.hitstop(0.07)
	FxAnim.spawn(world.fx_layer, preload("res://assets/gen/fx/shockwave.png"), 8, at, 18.0)
	world.floor_layer.add_decal(preload("res://assets/gen/fx/scorch.png"), g, 4.0)
	world.flash(at + Vector2(0, -10), Color(1.0, 0.85, 0.5), 1.3, 1.5, 0.45)
	world.burst(at + Vector2(0, -6), Color(0.96, 0.77, 0.32), 22, 140.0)
	world.burst(at + Vector2(0, -4), Color(0.7, 0.42, 0.85), 14, 100.0)
	world.burst(at, Color(0.35, 0.3, 0.35), 10, 80.0)
	for e in world.enemies:
		if e.alive() and e.visible and e.g.distance_to(g) < RADIUS:
			e.take_damage(DAMAGE, g, 4.5)
	if is_instance_valid(marker):
		marker.queue_free()
	queue_free()
