class_name Slime
extends Node2D
## Test enemy. Hops toward the player when close, hurts on contact.

const RADIUS := 0.3
const MAX_HP := 3
const AGGRO := 4.0
const LEASH := 8.0

var world: Node
var spr: GenSprite
var g := Vector2.ZERO
var spawn := Vector2.ZERO
var hp := MAX_HP
var state := "idle"
var wander := Vector2.ZERO
var think := 0.0
var attack_cd := 0.0
var knock := Vector2.ZERO
var flash := 0.0
var frozen := 0.0
var ice: Sprite2D


func _ready() -> void:
	spr = GenSprite.new()
	add_child(spr)
	spr.setup("res://assets/gen/slime", "slime")
	spr.finished.connect(_on_finished)
	spr.speed_scale = randf_range(0.9, 1.1)
	ice = Sprite2D.new()
	ice.texture = preload("res://assets/gen/fx/frozen.png")
	ice.centered = false
	ice.offset = Vector2(-24, -40)
	ice.modulate = Color(1, 1, 1, 0.82)
	ice.visible = false
	add_child(ice)
	position = Iso.to_screen(g)


func alive() -> bool:
	return state != "dead"


func take_damage(n: int, from: Vector2, strength := 3.0) -> void:
	if not alive():
		return
	var color := Color(1, 1, 1)
	if frozen > 0.0 and n > 0:
		# hitting something frozen shatters the ice for an extra point
		n += 1
		color = Color(0.72, 0.92, 1.0)
		_thaw(true)
	hp -= n
	flash = 0.2
	world.damage_number(position + Vector2(0, -26), n, color)
	var away := g - from
	knock = away.normalized() * strength if away.length() > 0.001 else Vector2.ZERO
	world.burst(position + Vector2(0, -10), Color(0.6, 0.95, 0.4), 10)
	if hp <= 0:
		state = "dead"
		_thaw(false)
		spr.play("death", true)
		return
	state = "hurt"
	spr.play("hurt", true)


func freeze(t: float) -> void:
	if not alive():
		return
	frozen = t
	ice.visible = true
	spr.playing = false
	spr.modulate = Color(0.75, 0.9, 1.25)
	knock = Vector2.ZERO


func _thaw(shatter: bool) -> void:
	if frozen <= 0.0 and not ice.visible:
		return
	frozen = 0.0
	ice.visible = false
	spr.playing = true
	spr.modulate = Color.WHITE
	if shatter:
		FxAnim.spawn(world.fx_layer, preload("res://assets/gen/fx/ice_burst.png"), 6, position + Vector2(0, -12), 18.0, 5)


func _process(delta: float) -> void:
	if frozen > 0.0:
		frozen -= delta
		attack_cd = max(attack_cd, 0.4)
		if frozen <= 0.0:
			_thaw(true)
		position = Iso.to_screen(g)
		return
	flash = max(flash - delta, 0.0)
	spr.modulate = Color(3, 3, 3) if flash > 0.0 else spr.modulate
	if flash <= 0.0 and state != "dead":
		spr.modulate = Color.WHITE
	attack_cd = max(attack_cd - delta, 0.0)
	if knock.length() > 0.01:
		_try_move(knock * delta)
		knock = knock.move_toward(Vector2.ZERO, 10.0 * delta)

	var p: Player = world.player
	if state == "idle" or state == "walk":
		var to_p := p.g - g
		var home := spawn - g
		var chase := p.alive() and to_p.length() < AGGRO and (spawn - p.g).length() < LEASH
		think -= delta
		if think <= 0.0:
			think = randf_range(0.8, 2.0)
			wander = Vector2.from_angle(randf() * TAU) if randf() < 0.6 else Vector2.ZERO
		var want := to_p.normalized() if chase else wander
		if not chase and home.length() > 3.0:
			want = home.normalized()
		if want.length() > 0.01:
			state = "walk"
			spr.play("walk")
			spr.set_dir(Iso.dir_index(want))
			# only travel while airborne (logical frames 1..4 of the hop)
			var li := spr.logical()
			if li >= 1 and li <= 4 and not (chase and to_p.length() < 0.62):
				_try_move(want * (1.25 if chase else 0.7) * delta)
		else:
			state = "idle"
			spr.play("idle")
		if chase and to_p.length() < 0.8 and attack_cd <= 0.0:
			attack_cd = 1.4
			p.take_damage(1, g)
	position = Iso.to_screen(g)
	queue_redraw()


func _try_move(v: Vector2) -> void:
	var n := g + v
	if world.walkable_r(n, RADIUS):
		g = n
	elif world.walkable_r(Vector2(n.x, g.y), RADIUS):
		g.x = n.x
	elif world.walkable_r(Vector2(g.x, n.y), RADIUS):
		g.y = n.y


func _on_finished(anim: String) -> void:
	if anim == "hurt":
		state = "idle"
		spr.play("idle")
	elif anim == "death":
		var tw := create_tween()
		tw.tween_property(spr, "modulate:a", 0.0, 0.5)
		await tw.finished
		visible = false
		await get_tree().create_timer(4.0).timeout
		g = spawn
		hp = MAX_HP
		state = "idle"
		spr.modulate = Color.WHITE
		spr.play("idle", true)
		visible = true


func _draw() -> void:
	if not visible or not alive() and spr.modulate.a < 0.5:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
