extends Control
## On-screen controls for phones: a floating stick on the left, a jump button on the right,
## and dragging anywhere else on the right turns the camera.

const STICK_R := 70.0
const JUMP_R := 62.0

var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var jump_id := -1
var cam_id := -1
var font: Font
var help: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	Controls.touch_active = DisplayServer.is_touchscreen_available()
	help = Label.new()
	help.position = Vector2(16, 12)
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color("3a2a55"))
	help.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	help.add_theme_constant_override("outline_size", 6)
	add_child(help)


func _jump_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - 110, s.y - 110)


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		Controls.touch_active = true
		var s := get_viewport_rect().size
		if e.pressed:
			if e.position.distance_to(_jump_center()) < JUMP_R + 20 and jump_id < 0:
				jump_id = e.index
				Controls.touch_jump = true
			elif e.position.x < s.x * 0.45 and stick_id < 0:
				stick_id = e.index
				stick_origin = e.position
				stick_pos = e.position
			elif cam_id < 0:
				cam_id = e.index
		else:
			if e.index == jump_id:
				jump_id = -1
				Controls.touch_jump = false
			elif e.index == stick_id:
				stick_id = -1
				Controls.touch_move = Vector2.ZERO
			elif e.index == cam_id:
				cam_id = -1
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_pos = e.position
			var v: Vector2 = (stick_pos - stick_origin) / STICK_R
			Controls.touch_move = v.limit_length(1.0)
		elif e.index == cam_id:
			Controls.touch_cam += e.relative
		get_viewport().set_input_as_handled()


func _process(_d: float) -> void:
	if Controls.touch_active:
		help.text = "Esquerda: mover · PULO: pular (de novo no ar: pulo duplo, segure caindo: planar) · arraste à direita: câmera"
	else:
		help.text = "WASD/analógico: mover · Shift: andar · Espaço/A: pular (2x: pulo duplo, segure caindo: planar) · Mouse/analógico direito: câmera · Esc: soltar o mouse"
	queue_redraw()


func _draw() -> void:
	if not Controls.touch_active:
		return
	var ink := Color(0.23, 0.16, 0.33, 0.55)
	var paper := Color(1, 1, 1, 0.35)
	if stick_id >= 0:
		draw_circle(stick_origin, STICK_R, paper)
		draw_arc(stick_origin, STICK_R, 0, TAU, 48, ink, 3.0)
		draw_circle(stick_origin + (stick_pos - stick_origin).limit_length(STICK_R), 30.0, Color(1, 1, 1, 0.8))
	else:
		var s := get_viewport_rect().size
		var c := Vector2(150, s.y - 150)
		draw_arc(c, STICK_R, 0, TAU, 48, Color(ink, 0.25), 3.0)
	var jc := _jump_center()
	draw_circle(jc, JUMP_R, Color(1, 0.79, 0.66, 0.85) if jump_id >= 0 else paper)
	draw_arc(jc, JUMP_R, 0, TAU, 48, ink, 4.0)
	var w := font.get_string_size("PULO", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(font, jc + Vector2(-w * 0.5, 9), "PULO", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("3a2a55"))
