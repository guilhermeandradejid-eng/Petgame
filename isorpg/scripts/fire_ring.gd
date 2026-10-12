class_name FireRing
extends Node2D
## A ring of fire pillars bursting out from the mage. Each pillar is a drawn flame, y-sorted
## with everything else, and the ring burns whatever it passes over.

const N := 16
const LIFE := 0.8
const GROW := 0.45
const R0 := 0.6
const R1 := 2.9
const DAMAGE := 2

var world: Node
var center := Vector2.ZERO
var t := 0.0
var pillars: Array[Sprite2D] = []
var hit := {}
var light: PointLight2D
var tex: Texture2D = preload("res://assets/gen/fx/flame.png")


func _ready() -> void:
	position = Iso.to_screen(center)
	for i in N:
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 8
		s.centered = false
		s.offset = Vector2(-13, -50)
		world.entities.add_child(s)
		pillars.append(s)
	FxAnim.spawn(world.fx_layer, preload("res://assets/gen/fx/fire_wave.png"), 8, position, 14.0)
	light = world.make_light(Color(1.0, 0.55, 0.2), 1.6, 1.2, 20.0)
	add_child(light)
	world.shake(3.0)


func _process(delta: float) -> void:
	t += delta
	var k: float = clamp(t / GROW, 0.0, 1.0)
	var r: float = lerp(R0, R1, 1.0 - (1.0 - k) * (1.0 - k))
	var f := mini(7, int(t / LIFE * 8.0))
	for i in N:
		var s := pillars[i]
		var gp := center + Vector2.from_angle(TAU * i / N + 0.2) * r
		s.visible = world.walkable(gp)
		s.position = Iso.to_screen(gp)
		s.frame = f
		s.flip_h = (i + f) % 2 == 0
	light.texture_scale = 0.8 + r * 0.6
	light.energy = 1.6 * (1.0 - t / LIFE)
	for e in world.enemies:
		if e.alive() and e.visible and not hit.has(e) and abs(e.g.distance_to(center) - r) < 0.6:
			hit[e] = true
			e.take_damage(DAMAGE, center, 5.0)
			world.burst(e.position + Vector2(0, -10), Color(1.0, 0.55, 0.2), 10)
	if t >= LIFE:
		for s in pillars:
			s.queue_free()
		queue_free()
