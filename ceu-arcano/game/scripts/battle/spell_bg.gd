extends Node2D
## Círculo mágico girando sob (e atrás de) quem conjura um feitiço.

var battle
var circles := []   # {f, col, t, alive}


func start(f: Fighter, cid: String) -> void:
	for c in circles:
		if c["f"] == f:
			c["alive"] = true
			c["col"] = Cards.get_card(cid)["color"]
			return
	circles.append({"f": f, "col": Cards.get_card(cid)["color"], "t": 0.0, "fade": 0.0, "alive": true})


func clear() -> void:
	circles.clear()


func stop(f: Fighter) -> void:
	for c in circles:
		if c["f"] == f:
			c["alive"] = false


func _process(delta: float) -> void:
	for i in range(circles.size() - 1, -1, -1):
		var c: Dictionary = circles[i]
		c["t"] += delta
		c["fade"] = clampf(c["fade"] + delta * (3.0 if c["alive"] else -2.0), 0.0, 1.0)
		if not c["alive"] and c["fade"] <= 0.0:
			circles.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for c in circles:
		var f: Fighter = c["f"]
		var a: float = c["fade"]
		var col: Color = c["col"]
		var tt: float = c["t"]
		var r := 70.0 * (0.6 + 0.4 * ease(a, 0.4))
		# atrás (vertical)
		_circle(f.center() + Vector2(0, -6), r * 1.15, tt * 0.6, Color(col, 0.28 * a), Vector2(1, 1))
		# no chão (achatado)
		_circle(Vector2(f.pos.x, 0), r, -tt * 0.9, Color(col, 0.75 * a), Vector2(1, 0.3))


func _circle(ctr: Vector2, r: float, rot: float, col: Color, sc: Vector2) -> void:
	draw_set_transform(ctr, 0.0, sc)
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, col, 2.0)
	draw_arc(Vector2.ZERO, r * 0.92, 0, TAU, 64, Color(col, col.a * 0.6), 1.0)
	draw_arc(Vector2.ZERO, r * 0.55, 0, TAU, 48, col, 1.5)
	# hexagrama
	for tri in 2:
		var pts := PackedVector2Array()
		for i in 4:
			pts.append(Vector2.from_angle(rot + tri * PI / 3.0 + i * TAU / 3.0) * r * 0.9)
		draw_polyline(pts, Color(col, col.a * 0.8), 1.0)
	# runas
	for i in 16:
		var ang := -rot * 0.7 + i * TAU / 16.0
		var p := Vector2.from_angle(ang) * r * 0.74
		var d := Vector2.from_angle(ang + PI / 2) * 3.0
		draw_line(p - d, p + d, col, 1.0)
		if i % 2 == 0:
			draw_circle(p + Vector2.from_angle(ang) * 5.0, 1.0, col)
	for i in 6:
		var p2 := Vector2.from_angle(rot * 1.5 + i * TAU / 6.0) * r * 0.55
		draw_arc(p2, 5.0, 0, TAU, 12, col, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
