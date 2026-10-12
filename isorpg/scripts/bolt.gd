class_name Bolt
extends Node2D
## Arcane bolt. Flies in grid space at a height, so y-sorting follows its ground shadow.

const SPEED := 7.0
const HIT_RADIUS := 0.45

var world: Node
var g := Vector2.ZERO
var vel := Vector2.ZERO
var height := 40.0
var h0 := 40.0
var dist0 := 1.0
var traveled := 0.0
var target: Node2D = null
var life := 1.4
var spr: Sprite2D
var anim_t := 0.0


func launch(from_g: Vector2, from_h: float, aim: Vector2, tgt: Node2D) -> void:
	g = from_g
	h0 = from_h
	height = from_h
	target = tgt
	var d := aim - g
	dist0 = max(d.length(), 0.5)
	vel = d.normalized() * SPEED if d.length() > 0.001 else Vector2(1, 1).normalized() * SPEED


func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = preload("res://assets/gen/fx/bolt.png")
	spr.hframes = 4
	spr.scale = Vector2(1.25, 1.25)
	add_child(spr)
	var l := PointLight2D.new()
	l.texture = world.light_texture
	l.color = Color(0.5, 1.0, 1.0)
	l.energy = 0.8
	l.texture_scale = 0.6
	l.height = 18.0
	spr.add_child(l)


func _process(delta: float) -> void:
	life -= delta
	anim_t += delta
	spr.frame = int(anim_t * 16.0) % 4
	if target != null and is_instance_valid(target) and target.alive():
		var want: Vector2 = (target.g - g).normalized() * SPEED
		vel = vel.lerp(want, min(1.0, 6.0 * delta))
	var step := vel * delta
	g += step
	traveled += step.length()
	height = lerp(h0, 12.0, clamp(traveled / dist0, 0.0, 1.0))
	position = Iso.to_screen(g)
	spr.position = Vector2(0, -height)
	queue_redraw()
	for e in world.enemies:
		if e.alive() and e.visible and e.g.distance_to(g) < HIT_RADIUS:
			e.take_damage(1, g - vel.normalized() * 0.5)
			_explode()
			return
	if not world.walkable(g) or life <= 0.0:
		_explode()


func _explode() -> void:
	world.burst(position + Vector2(0, -height), Color(0.55, 1.0, 1.0), 14)
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.25))
