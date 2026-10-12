extends Control
## Health pips, the spell bar and a line of help, drawn in screen space.

const SLOT := 30.0
const GAP := 6.0

var world: Node
var label: Label
var icons: Texture2D = preload("res://assets/gen/fx/icons.png")
var deny_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	label = Label.new()
	label.text = "Clique: andar · clique no slime: atacar · 1-4 / Q W E R: magias (no cursor)"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(8, 22)
	add_child(label)


func _slot_rect(i: int) -> Rect2:
	var n := Spells.LIST.size()
	var w := n * SLOT + (n - 1) * GAP
	var vs := get_viewport_rect().size
	return Rect2(Vector2((vs.x - w) * 0.5 + i * (SLOT + GAP), vs.y - SLOT - 10), Vector2(SLOT, SLOT))


func slot_at(p: Vector2) -> int:
	for i in Spells.LIST.size():
		if _slot_rect(i).grow(3).has_point(p):
			return i
	return -1


func deny(i: int) -> void:
	deny_t[i] = 0.3


func _process(delta: float) -> void:
	for i in deny_t.size():
		deny_t[i] = max(deny_t[i] - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var p: Player = world.player
	for i in Player.MAX_HP:
		var c := Vector2(14 + i * 13, 12)
		draw_colored_polygon(_diamond(c, 5.0), Color(0.08, 0.05, 0.12))
		draw_colored_polygon(_diamond(c, 3.5), Color(0.93, 0.36, 0.26) if i < p.hp else Color(0.25, 0.2, 0.3))

	for i in Spells.LIST.size():
		var sp: Dictionary = Spells.LIST[i]
		var r := _slot_rect(i)
		if deny_t[i] > 0.0:
			r.position.x += sin(deny_t[i] * 60.0) * 2.0
		var armed: bool = world.armed == i
		draw_rect(r.grow(2), Color(0.08, 0.05, 0.12))
		draw_rect(r, Color(0.16, 0.13, 0.27))
		var src := Rect2(i * 24, 0, 24, 24)
		draw_texture_rect_region(icons, Rect2(r.position + Vector2(3, 3), Vector2(24, 24)), src)
		var cd: float = p.cooldowns[i]
		if cd > 0.0:
			var k: float = cd / float(sp.cd)
			_pie(r.get_center(), 15.0, k, Color(0.05, 0.03, 0.1, 0.72))
			var txt := str(ceili(cd)) if cd >= 1.0 else ""
			if txt != "":
				draw_string_outline(font, r.position + Vector2(10, 20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.08, 0.05, 0.12))
				draw_string(font, r.position + Vector2(10, 20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		var border: Color = sp.color if armed else Color(0.35, 0.33, 0.55)
		draw_rect(r, border, false, 2.0 if armed else 1.0)
		var key := str(i + 1)
		draw_string_outline(font, r.position + Vector2(-3, 6), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.08, 0.05, 0.12))
		draw_string(font, r.position + Vector2(-3, 6), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.6))
	if world.armed >= 0:
		var sp: Dictionary = Spells.LIST[world.armed]
		var msg: String = sp.name + ": toque no alvo"
		var r := _slot_rect(0)
		var pos := Vector2(r.position.x, r.position.y - 10)
		draw_string_outline(font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.08, 0.05, 0.12))
		draw_string(font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, sp.color)


func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


func _pie(c: Vector2, r: float, k: float, color: Color) -> void:
	var pts := PackedVector2Array([c])
	var steps := 20
	for s in steps + 1:
		var a := -PI * 0.5 + TAU * k * float(s) / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if pts.size() >= 3:
		draw_colored_polygon(pts, color)
