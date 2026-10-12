extends Node2D
## Draws the flat test floor and the click marker. Sits below every y-sorted entity.

var world: Node
var tex: Texture2D = preload("res://assets/gen/tiles/floor.png")
var marker := Vector2.ZERO
var marker_t := 0.0


func show_marker(g: Vector2) -> void:
	marker = g
	marker_t = 0.6


func _process(delta: float) -> void:
	if marker_t > 0.0:
		marker_t -= delta
		queue_redraw()


func _draw() -> void:
	for c: Vector2i in world.floor_cells:
		var p := Iso.to_screen(Vector2(c) + Vector2(0.5, 0.5))
		var v: int = (c.x + c.y) % 2
		draw_texture_rect_region(tex, Rect2(p - Vector2(32, 16), Vector2(64, 32)), Rect2(v * 64, 0, 64, 32))
	if marker_t > 0.0:
		var s := Iso.to_screen(marker)
		var k := marker_t / 0.6
		var r := 4.0 + (1.0 - k) * 8.0
		var col := Color(0.6, 1.0, 1.0, k)
		var pts := PackedVector2Array([s + Vector2(0, -r * 0.5), s + Vector2(r, 0), s + Vector2(0, r * 0.5), s + Vector2(-r, 0), s + Vector2(0, -r * 0.5)])
		draw_polyline(pts, col, 1.0)
