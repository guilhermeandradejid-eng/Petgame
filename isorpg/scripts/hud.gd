extends Control
## Health pips, the spell bar (mouse) or thumb buttons (touch), toggles and a line of help.

const SLOT := 30.0
const GAP := 6.0
const AIM_DRAG := 70.0  # keep in sync with main.gd
const HELP_MOUSE := "Clique: andar · clique no slime: atacar · 1-4 / Q W E R: magias (no cursor)"
const HELP_TOUCH := "Toque: andar (segure p/ seguir) · toque no slime: atacar · magia: toque = mira auto, arraste = mirar"

var world: Node
var label: Label
var icons: Texture2D = preload("res://assets/gen/fx/icons.png")
var deny_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var font: Font
var touch_mode := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	touch_mode = DisplayServer.is_touchscreen_available()
	label = Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(8, 22)
	add_child(label)


# ---------------------------------------------------------------- layout

func _slot_rect(i: int) -> Rect2:
	var n := Spells.LIST.size()
	var w := n * SLOT + (n - 1) * GAP
	var vs := get_viewport_rect().size
	return Rect2(Vector2((vs.x - w) * 0.5 + i * (SLOT + GAP), vs.y - SLOT - 10), Vector2(SLOT, SLOT))


func slot_at(p: Vector2) -> int:
	if touch_mode:
		return touch_button_at(p)
	for i in Spells.LIST.size():
		if _slot_rect(i).grow(3).has_point(p):
			return i
	return -1


## Thumb buttons in an arc around the bottom-right corner: the bolt is the big one.
func touch_button_center(i: int) -> Vector2:
	var vs := get_viewport_rect().size
	var main := Vector2(vs.x - 46, vs.y - 46)
	if i == 0:
		return main
	var ang: float = [0.0, 180.0, 225.0, 270.0][i]
	return main + Vector2.from_angle(deg_to_rad(ang)) * 68.0


func touch_button_radius(i: int) -> float:
	return 28.0 if i == 0 else 20.0


func touch_button_at(p: Vector2) -> int:
	for i in Spells.LIST.size():
		if p.distance_to(touch_button_center(i)) <= touch_button_radius(i) + 6.0:
			return i
	return -1


func _toggle_rect(name: String) -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(Vector2(vs.x - (104 if name == "auto" else 54), 6), Vector2(48, 18))


func toggle_at(p: Vector2) -> String:
	for n in ["auto", "slow"]:
		if _toggle_rect(n).grow(4).has_point(p):
			return n
	return ""


func deny(i: int) -> void:
	deny_t[i] = 0.3


func _process(delta: float) -> void:
	for i in deny_t.size():
		deny_t[i] = max(deny_t[i] - delta, 0.0)
	label.text = HELP_TOUCH if touch_mode else HELP_MOUSE
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var p: Player = world.player
	for i in Player.MAX_HP:
		var c := Vector2(14 + i * 13, 12)
		draw_colored_polygon(_diamond(c, 5.0), Color(0.08, 0.05, 0.12))
		draw_colored_polygon(_diamond(c, 3.5), Color(0.93, 0.36, 0.26) if i < p.hp else Color(0.25, 0.2, 0.3))
	_draw_toggle("auto", "AUTO", world.demo)
	_draw_toggle("slow", "LENTO", world.time_base < 1.0)
	if touch_mode:
		_draw_touch_buttons(p)
	else:
		_draw_bar(p)


func _draw_toggle(name: String, text: String, on: bool) -> void:
	var r := _toggle_rect(name)
	draw_rect(r.grow(1), Color(0.08, 0.05, 0.12))
	draw_rect(r, Color(0.33, 0.27, 0.55) if on else Color(0.16, 0.13, 0.27))
	draw_rect(r, Color(1, 0.85, 0.5) if on else Color(0.35, 0.33, 0.55), false, 1.0)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_text(r.position + Vector2((r.size.x - w) * 0.5, 13), text, 9, Color(1, 0.92, 0.7) if on else Color(0.75, 0.72, 0.9))


func _draw_bar(p: Player) -> void:
	for i in Spells.LIST.size():
		var sp: Dictionary = Spells.LIST[i]
		var r := _slot_rect(i)
		if deny_t[i] > 0.0:
			r.position.x += sin(deny_t[i] * 60.0) * 2.0
		var armed: bool = world.armed == i
		draw_rect(r.grow(2), Color(0.08, 0.05, 0.12))
		draw_rect(r, Color(0.16, 0.13, 0.27))
		draw_texture_rect_region(icons, Rect2(r.position + Vector2(3, 3), Vector2(24, 24)), Rect2(i * 24, 0, 24, 24))
		_cooldown(r.get_center(), 15.0, p.cooldowns[i], sp.cd)
		draw_rect(r, sp.color if armed else Color(0.35, 0.33, 0.55), false, 2.0 if armed else 1.0)
		_text(r.position + Vector2(-3, 6), str(i + 1), 9, Color(1, 0.9, 0.6))
	if world.armed >= 0:
		var sp: Dictionary = Spells.LIST[world.armed]
		var r := _slot_rect(0)
		_text(Vector2(r.position.x, r.position.y - 10), sp.name + ": clique no alvo", 10, sp.color)


func _draw_touch_buttons(p: Player) -> void:
	var aiming := {}
	for t in world.touches.values():
		if t.kind == "spell":
			aiming[t.slot] = t
	for i in Spells.LIST.size():
		var sp: Dictionary = Spells.LIST[i]
		var c := touch_button_center(i)
		if deny_t[i] > 0.0:
			c.x += sin(deny_t[i] * 60.0) * 2.0
		var r := touch_button_radius(i)
		var ready: bool = p.cooldowns[i] <= 0.0
		draw_circle(c, r + 2.0, Color(0.08, 0.05, 0.12, 0.9))
		draw_circle(c, r, Color(0.16, 0.13, 0.27, 0.85))
		var s := 48.0 if i == 0 else 24.0
		draw_texture_rect_region(icons, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(i * 24, 0, 24, 24))
		_cooldown(c, r, p.cooldowns[i], sp.cd)
		var ring: Color = sp.color if ready else Color(0.35, 0.33, 0.55)
		draw_arc(c, r, 0, TAU, 40, ring, 3.0 if aiming.has(i) else 1.5)
		if aiming.has(i):
			var t: Dictionary = aiming[i]
			var d: Vector2 = t.pos - c
			var knob := c + d.limit_length(AIM_DRAG)
			draw_arc(c, AIM_DRAG, 0, TAU, 48, Color(sp.color, 0.35), 1.0)
			draw_line(c, knob, Color(sp.color, 0.6), 1.0)
			draw_circle(knob, 7.0, Color(sp.color, 0.85))
			var tip: String = sp.name + (" · mira auto" if world.is_auto(t) else "")
			_text(touch_button_center(3) + Vector2(-60, -34), tip, 10, sp.color)


func _cooldown(c: Vector2, r: float, cd: float, total: float) -> void:
	if cd <= 0.0:
		return
	_pie(c, r, cd / total, Color(0.05, 0.03, 0.1, 0.72))
	if cd >= 1.0:
		var txt := str(ceili(cd))
		_text(c + Vector2(-3, 4), txt, 11, Color.WHITE)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.08, 0.05, 0.12))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


func _pie(c: Vector2, r: float, k: float, color: Color) -> void:
	var pts := PackedVector2Array([c])
	var steps := 24
	for s in steps + 1:
		var a := -PI * 0.5 + TAU * k * float(s) / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if pts.size() >= 3 and k > 0.01:
		draw_colored_polygon(pts, color)
