extends Control
## Health pips and a one-line help, drawn in screen space.

var world: Node
var label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.text = "Clique: andar   Clique no slime: atacar   Botão direito: magia"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(8, 22)
	add_child(label)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p: Player = world.player
	for i in Player.MAX_HP:
		var c := Vector2(14 + i * 13, 12)
		var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
		draw_colored_polygon(pts, Color(0.08, 0.05, 0.12))
		var inner := PackedVector2Array([c + Vector2(0, -3.5), c + Vector2(3.5, 0), c + Vector2(0, 3.5), c + Vector2(-3.5, 0)])
		draw_colored_polygon(inner, Color(0.93, 0.36, 0.26) if i < p.hp else Color(0.25, 0.2, 0.3))
