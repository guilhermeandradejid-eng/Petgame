extends Node2D
## Ground preview while a finger drags a spell button: line, landing area or ring radius.

var world: Node


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	for t in world.touches.values():
		if t.kind != "spell":
			continue
		var sp: Dictionary = Spells.LIST[t.slot]
		var col: Color = sp.color
		var p0 := Iso.to_screen(world.player.g)
		if sp.id == "fire":
			_ring(p0, FireRing.R1, col)
			continue
		var aim: Vector2 = world.touch_aim(t)
		var p1 := Iso.to_screen(aim)
		_dashed(p0, p1, col)
		if sp.id == "comet":
			_ring(p1, Comet.RADIUS, col)
		else:
			draw_circle(p1, 3.0, col)
		var auto_target: Node2D = world.auto_enemy(t.slot) if world.is_auto(t) else null
		if auto_target != null:
			_ring(auto_target.position, 0.45, Color(1, 1, 1, 0.9))


func _ring(center: Vector2, r_grid: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(center + Iso.to_screen(Vector2(cos(a), sin(a)) * r_grid))
	draw_polyline(pts, Color(col, 0.9), 1.0)
	draw_polyline(pts, Color(col, 0.25), 3.0)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	var n := int(d.length() / 6.0)
	for k in n:
		if k % 2 == 0:
			draw_line(a + d * (float(k) / n), a + d * (float(k + 1) / n), col, 1.0)
