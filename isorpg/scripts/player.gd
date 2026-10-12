class_name Player
extends Node2D
## Vesper. Click to move, click a slime to fire arcane bolts at it, 1-4 / Q W E R for spells.

const BOLT_RANGE := 4.5
const RADIUS := 0.28
const MAX_HP := 6

var world: Node
var spr: GenSprite
var rune: Sprite2D
var light: PointLight2D
var g := Vector2.ZERO
var spawn := Vector2.ZERO
var path: PackedVector2Array = []
var state := "idle"
var hp := MAX_HP
var speed := 1.5
var target: Node2D = null
var cast_at := Vector2.ZERO
var spell := 0
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var marker: Node2D = null
var repath := 0.0
var knock := Vector2.ZERO
var flash := 0.0
var invuln := 0.0
var rune_t := 0.0


func _ready() -> void:
	rune = Sprite2D.new()
	rune.hframes = 8
	rune.visible = false
	add_child(rune)
	spr = GenSprite.new()
	add_child(spr)
	spr.setup("res://assets/gen/mage", "mage")
	speed = spr.root_speed("walk") / Iso.CELL_UNITS
	spr.event.connect(_on_event)
	spr.finished.connect(_on_finished)
	light = world.make_light(Color(0.45, 0.95, 1.0), 0.7, 0.9, 24.0)
	add_child(light)
	position = Iso.to_screen(g)


func alive() -> bool:
	return state != "dead"


func busy() -> bool:
	return state == "cast" or state == "hurt" or state == "dead"


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
	if not busy():
		state = "walk"


## Cast spell i toward a grid point. Returns false when it cannot be cast right now.
func cast_spell(i: int, point: Vector2) -> bool:
	if busy() or cooldowns[i] > 0.0:
		return false
	var sp: Dictionary = Spells.LIST[i]
	if i != 0:
		target = null
	path = []
	var r: float = sp.range
	if r > 0.0 and (point - g).length() > r:
		point = g + (point - g).normalized() * r
	_begin_cast(i, point)
	return true


func _begin_cast(i: int, point: Vector2) -> void:
	var sp: Dictionary = Spells.LIST[i]
	spell = i
	cast_at = point
	state = "cast"
	cooldowns[i] = sp.cd
	if (point - g).length() > 0.01:
		spr.set_dir(Iso.dir_index(point - g))
	spr.play(sp.anim, true)
	rune.texture = Spells.rune_texture(sp.rune)
	rune.visible = true
	rune.modulate = Color(1, 1, 1, 0)
	rune_t = 0.0
	light.color = sp.color
	if sp.id == "comet":
		marker = world.target_marker(point, "astral")


func take_damage(n: int, from: Vector2, _strength := 2.2) -> void:
	if not alive() or invuln > 0.0:
		return
	invuln = 0.9
	hp -= n
	flash = 0.25
	world.shake(3.0)
	world.damage_number(position + Vector2(0, -60), n, Color(1.0, 0.45, 0.4))
	var away := (g - from)
	knock = away.normalized() * 2.2 if away.length() > 0.001 else Vector2.ZERO
	_cancel_cast()
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


func _cancel_cast() -> void:
	rune.visible = false
	if is_instance_valid(marker):
		marker.queue_free()
	marker = null


func _process(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = max(cooldowns[i] - delta, 0.0)
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
				if g.distance_to(target.g) <= BOLT_RANGE and world.line_clear(g, target.g):
					path = []
					if cooldowns[0] <= 0.0:
						_begin_cast(0, target.g)
					else:
						spr.set_dir(Iso.dir_index(target.g - g))
						spr.play("idle")
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

	if state == "walk" and not (target != null and path.is_empty()):
		spr.play("walk")
	position = Iso.to_screen(g)
	_update_rune(delta)
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


func _update_rune(delta: float) -> void:
	if not rune.visible:
		return
	rune_t += delta
	rune.frame = int(rune_t * 12.0) % 8
	var a := rune.modulate.a
	if state == "cast":
		a = min(a + delta * 6.0, 1.0)
	else:
		a = max(a - delta * 4.0, 0.0)
		if a <= 0.0:
			rune.visible = false
	rune.modulate.a = a
	var s := 1.0 + 0.08 * sin(rune_t * 10.0)
	rune.scale = Vector2(s, s)


func _update_light() -> void:
	light.position = spr.anchor("staff_tip")
	var glow := 0.7
	if state == "cast":
		var a: Dictionary = spr.meta.animations[spr.anim]
		var rel := 0
		for i in a.logical.size():
			if a.logical[i].event == "release":
				rel = i
		var li := spr.logical()
		glow = lerp(0.8, 1.5, float(li) / max(rel, 1)) if li <= rel else lerp(1.5, 0.7, float(li - rel) / max(a.logical.size() - 1 - rel, 1))
	elif spr.anim == "death":
		glow = 0.25
	else:
		light.color = light.color.lerp(Color(0.45, 0.95, 1.0), 0.05)
	light.energy = glow


func _on_event(_anim: String, ev: String) -> void:
	if ev != "release":
		return
	var sp: Dictionary = Spells.LIST[spell]
	var tip := spr.anchor("staff_tip")
	match sp.id:
		"bolt":
			var aim := cast_at
			if target != null and is_instance_valid(target) and target.alive():
				aim = target.g
			world.spawn_bolt(self, g, -tip.y, aim, target)
		"comet":
			world.spawn_comet(cast_at, marker)
			marker = null
		"fire":
			world.spawn_fire_ring(g)
		"ice":
			world.spawn_ice_lance(position + tip, cast_at)


func _on_finished(anim: String) -> void:
	match anim:
		"death":
			await get_tree().create_timer(2.5).timeout
			hp = MAX_HP
			g = spawn
			knock = Vector2.ZERO
			state = "idle"
			spr.play("idle", true)
		"hurt":
			_resume()
		_:
			if state == "cast":
				_resume()


func _resume() -> void:
	if target != null and is_instance_valid(target) and target.alive():
		state = "walk"
	elif not path.is_empty():
		state = "walk"
	else:
		state = "idle"
		spr.play("idle")


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
