class_name Player
extends Node2D
## Vesper. Click to move, click a slime to attack it, right click to cast where you point.

const CAST_RANGE := 4.5
const RADIUS := 0.28
const MAX_HP := 6

var world: Node
var spr: GenSprite
var light: PointLight2D
var g := Vector2.ZERO
var spawn := Vector2.ZERO
var path: PackedVector2Array = []
var state := "idle"
var hp := MAX_HP
var speed := 1.5
var target: Node2D = null
var cast_at := Vector2.ZERO
var repath := 0.0
var knock := Vector2.ZERO
var flash := 0.0
var invuln := 0.0


func _ready() -> void:
	spr = GenSprite.new()
	add_child(spr)
	spr.setup("res://assets/gen/mage", "mage")
	speed = spr.root_speed("walk") / Iso.CELL_UNITS
	spr.event.connect(_on_event)
	spr.finished.connect(_on_finished)
	light = PointLight2D.new()
	light.texture = world.light_texture
	light.color = Color(0.45, 0.95, 1.0)
	light.energy = 0.7
	light.texture_scale = 0.9
	light.height = 24.0
	add_child(light)
	position = Iso.to_screen(g)


func alive() -> bool:
	return state != "dead"


func move_to(dest: Vector2) -> void:
	if not alive() or state == "hurt":
		return
	target = null
	path = world.find_path(g, dest)
	if state == "cast":
		return
	if path.size() > 0:
		state = "walk"


func attack(enemy: Node2D) -> void:
	if not alive():
		return
	target = enemy
	repath = 0.0
	if state != "cast" and state != "hurt":
		state = "walk"


func cast_toward(point: Vector2) -> void:
	if not alive() or state == "hurt" or state == "cast":
		return
	target = null
	path = []
	_begin_cast(point)


func _begin_cast(point: Vector2) -> void:
	cast_at = point
	state = "cast"
	if (point - g).length() > 0.01:
		spr.set_dir(Iso.dir_index(point - g))
	spr.play("cast", true)


func take_damage(n: int, from: Vector2) -> void:
	if not alive() or invuln > 0.0:
		return
	invuln = 0.9
	hp -= n
	flash = 0.25
	world.shake(3.0)
	var away := (g - from)
	knock = away.normalized() * 2.2 if away.length() > 0.001 else Vector2.ZERO
	if hp <= 0:
		hp = 0
		state = "dead"
		path = []
		target = null
		spr.play("death", true)
		return
	state = "hurt"
	spr.set_dir(Iso.dir_index(from - g))
	spr.play("hurt", true)


func _process(delta: float) -> void:
	flash = max(flash - delta, 0.0)
	invuln = max(invuln - delta, 0.0)
	spr.modulate = Color(1, 0.55, 0.55) if flash > 0.0 and int(flash * 30) % 2 == 0 else Color.WHITE
	if knock.length() > 0.01:
		_try_move(knock * delta)
		knock = knock.move_toward(Vector2.ZERO, 8.0 * delta)

	if target != null and (not is_instance_valid(target) or not target.alive()):
		target = null
		if state == "walk" and path.is_empty():
			state = "idle"

	match state:
		"walk":
			if target != null:
				if g.distance_to(target.g) <= CAST_RANGE and world.line_clear(g, target.g):
					path = []
					_begin_cast(target.g)
				else:
					repath -= delta
					if repath <= 0.0:
						repath = 0.25
						path = world.find_path(g, target.g)
			_follow(delta)
		"idle":
			spr.play("idle")
			if target != null:
				state = "walk"

	if state == "walk":
		spr.play("walk")
	position = Iso.to_screen(g)
	_update_light()
	queue_redraw()


func _follow(delta: float) -> void:
	if path.is_empty():
		if target == null:
			state = "idle"
		return
	var step := speed * delta
	while step > 0.0 and not path.is_empty():
		var to := path[0] - g
		var d := to.length()
		if d < 0.001:
			path.remove_at(0)
			continue
		spr.set_dir(Iso.dir_index(to))
		var m: float = min(step, d)
		_try_move(to / d * m)
		step -= m
		if d <= m + 0.0001:
			path.remove_at(0)
	if path.is_empty() and target == null:
		state = "idle"


func _try_move(v: Vector2) -> void:
	var n := g + v
	if world.walkable_r(n, RADIUS):
		g = n
	elif world.walkable_r(Vector2(n.x, g.y), RADIUS):
		g.x = n.x
	elif world.walkable_r(Vector2(g.x, n.y), RADIUS):
		g.y = n.y


func _update_light() -> void:
	var tip := spr.anchor("staff_tip")
	light.position = tip
	var glow := 0.7
	if spr.anim == "cast":
		glow = [0.75, 0.9, 1.1, 1.25, 0.85, 0.7][spr.logical()]
	elif spr.anim == "death":
		glow = 0.25
	light.energy = glow


func _on_event(anim: String, ev: String) -> void:
	if anim == "cast" and ev == "release":
		var tip := spr.anchor("staff_tip")
		var aim := cast_at
		if target != null and is_instance_valid(target) and target.alive():
			aim = target.g
		world.spawn_bolt(self, g, -tip.y, aim, target)


func _on_finished(anim: String) -> void:
	match anim:
		"cast", "hurt":
			if target != null and is_instance_valid(target) and target.alive():
				state = "walk"
			elif not path.is_empty():
				state = "walk"
			else:
				state = "idle"
				spr.play("idle")
		"death":
			await get_tree().create_timer(2.5).timeout
			hp = MAX_HP
			g = spawn
			knock = Vector2.ZERO
			state = "idle"
			spr.play("idle", true)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
