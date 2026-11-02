class_name TouchControls
extends Control
## Controles de toque multi-touch: analógico flutuante à esquerda e
## botões de golpe em losango à direita (com teclado/mouse no PC).

signal shot(type: int)
signal dive
signal super_pressed
signal defense_pressed
signal jump

const FONT := preload("res://assets/fonts/Bangers.woff")
const INK := Color(0.07, 0.04, 0.12)

var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
var pressed := {}      # botão -> tempo de brilho
var buttons: Array[Dictionary] = []
var touch_buttons := {}  # índice do toque -> id do botão
var super_fill := 0.0
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var u := vs.y / 720.0
	var c := Vector2(vs.x - 178.0 * u, vs.y - 178.0 * u)
	var d := 98.0 * u
	var r := 58.0 * u
	buttons = [
		{"id": "lob", "type": Shots.LOB, "pos": c + Vector2(0, -d), "r": r, "label": "LOB", "color": Shots.COLORS[Shots.LOB]},
		{"id": "smash", "type": Shots.SMASH, "pos": c + Vector2(d, 0), "r": r, "label": "SMASH", "color": Shots.COLORS[Shots.SMASH]},
		{"id": "drop", "type": Shots.DROP, "pos": c + Vector2(0, d), "r": r, "label": "CURTA", "color": Shots.COLORS[Shots.DROP]},
		{"id": "drive", "type": Shots.DRIVE, "pos": c + Vector2(-d, 0), "r": r, "label": "FORTE", "color": Shots.COLORS[Shots.DRIVE]},
		{"id": "defense", "type": Shots.DEFENSE, "pos": c + Vector2(-d * 2.15, d * 0.55), "r": 54.0 * u, "label": "DEFESA", "color": Color("e8e2d4")},
		{"id": "dive", "type": -1, "pos": c + Vector2(-d * 3.25, d * 0.95), "r": 48.0 * u, "label": "PEIXINHO", "color": Color("ffffff")},
		{"id": "super", "type": -2, "pos": c + Vector2(-d * 1.2, -d * 1.2), "r": 50.0 * u, "label": "SUPER", "color": Color("ffe14d")},
	]


func reset() -> void:
	joy_index = -1
	joy_vec = Vector2.ZERO
	touch_buttons.clear()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var b := _button_at(e.position)
			if not b.is_empty():
				touch_buttons[e.index] = b["id"]
				_fire(b)
				get_viewport().set_input_as_handled()
			elif e.position.x < get_viewport_rect().size.x * 0.55 and joy_index < 0:
				joy_index = e.index
				joy_origin = e.position
				joy_pos = e.position
				joy_vec = Vector2.ZERO
		else:
			touch_buttons.erase(e.index)
			if e.index == joy_index:
				joy_index = -1
				joy_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == joy_index:
			var u := get_viewport_rect().size.y / 720.0
			var max_r := 85.0 * u
			var off := e.position - joy_origin
			if off.length() > max_r:
				joy_origin += off.normalized() * (off.length() - max_r)  # base segue o dedo
				off = e.position - joy_origin
			joy_pos = e.position
			joy_vec = off / max_r


func _button_at(p: Vector2) -> Dictionary:
	for b in buttons:
		if p.distance_to(b["pos"]) <= float(b["r"]) * 1.18:
			return b
	return {}


func _fire(b: Dictionary) -> void:
	pressed[b["id"]] = 0.18
	if b["id"] == "dive":
		dive.emit()
	elif b["id"] == "defense":
		defense_pressed.emit()
	elif b["id"] == "super":
		super_pressed.emit()
	else:
		shot.emit(int(b["type"]))


func flash_button(type: int) -> void:
	for b in buttons:
		if int(b["type"]) == type:
			pressed[b["id"]] = 0.18


func _process(dt: float) -> void:
	t += dt
	for k in pressed.keys():
		pressed[k] = float(pressed[k]) - dt
		if pressed[k] <= 0.0:
			pressed.erase(k)
	queue_redraw()


func _draw() -> void:
	var u := get_viewport_rect().size.y / 720.0
	# analógico
	if joy_index >= 0:
		draw_circle(joy_origin, 92.0 * u, Color(1, 1, 1, 0.18))
		draw_arc(joy_origin, 92.0 * u, 0, TAU, 40, Color(INK, 0.6), 5.0 * u)
		var k := joy_origin + joy_vec * 85.0 * u
		draw_circle(k, 46.0 * u, INK)
		draw_circle(k, 40.0 * u, Color("ffd23f"))
	else:
		var hint := Vector2(150.0 * u, get_viewport_rect().size.y - 150.0 * u)
		draw_circle(hint, 80.0 * u, Color(1, 1, 1, 0.1))
		draw_arc(hint, 80.0 * u, 0, TAU, 40, Color(1, 1, 1, 0.35), 4.0 * u)
		_text(hint + Vector2(0, 8 * u), "MOVER", 30, Color(1, 1, 1, 0.6), u)
	for b in buttons:
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var lit: bool = pressed.has(b["id"])
		var col: Color = b["color"]
		if b["id"] == "super":
			_draw_super(b, u)
			continue
		var off := Vector2(0, 6.0 * u) if not lit else Vector2(0, 2.0 * u)
		draw_circle(p + Vector2(0, 7.0 * u), r, Color(INK, 0.55))
		draw_circle(p + off - Vector2(0, 6.0 * u), r, INK)
		draw_circle(p + off - Vector2(0, 6.0 * u), r - 5.0 * u, col.lightened(0.35) if lit else col)
		draw_circle(p + off - Vector2(r * 0.3, r * 0.35 + 6.0 * u), r * 0.22, Color(1, 1, 1, 0.45))
		var fs := 30 if String(b["label"]).length() <= 5 else 22
		_text(p + off + Vector2(0, 4.0 * u), b["label"], fs, Color.WHITE, u)


func _text(center: Vector2, s: String, fs: int, col: Color, u: float) -> void:
	var size := int(fs * u)
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := center + Vector2(-w * 0.5, size * 0.35)
	draw_string_outline(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(8 * u), INK)
	draw_string(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Botão do super golpe: enche com a barra de energia e brilha quando está pronto
func _draw_super(b: Dictionary, u: float) -> void:
	var p: Vector2 = b["pos"]
	var r: float = b["r"]
	var ready := super_fill >= 1.0
	var pulse := 1.0 + (sin(t * 10.0) * 0.06 if ready else 0.0)
	var rr := r * pulse
	if ready:
		var pts := PackedVector2Array()
		for i in 20:
			var a := float(i) / 20.0 * TAU + t * 1.5
			var k := 1.45 if i % 2 == 0 else 1.05
			pts.append(p + Vector2(cos(a), sin(a)) * rr * k)
		draw_colored_polygon(pts, Color(1.0, 0.9, 0.3, 0.55))
	draw_circle(p + Vector2(0, 6.0 * u), rr, Color(INK, 0.55))
	draw_circle(p, rr, INK)
	draw_circle(p, rr - 5.0 * u, Color("ffe14d") if ready else Color("8f8aa3"))
	if not ready and super_fill > 0.0:
		draw_arc(p, rr - 10.0 * u, -PI * 0.5, -PI * 0.5 + TAU * super_fill, 32, Color("ffe14d"), 8.0 * u)
	_text(p + Vector2(0, 4.0 * u), "SUPER", 22, Color.WHITE if ready else Color(1, 1, 1, 0.7), u)
