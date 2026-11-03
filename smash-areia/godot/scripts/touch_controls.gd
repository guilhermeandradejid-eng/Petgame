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


const IDLE_ALPHA := 0.55     # botões semitransparentes; acendem ao tocar
const PRESS_ALPHA := 0.95


func _layout() -> void:
	var vs := get_viewport_rect().size
	var u := vs.y / 720.0
	# losango compacto no canto, botões secundários num arco à esquerda dele
	var c := Vector2(vs.x - 128.0 * u, vs.y - 122.0 * u)
	var d := 72.0 * u
	var r := 42.0 * u
	buttons = [
		{"id": "lob", "type": Shots.LOB, "pos": c + Vector2(0, -d), "r": r, "label": "LOB", "color": Shots.COLORS[Shots.LOB]},
		{"id": "smash", "type": Shots.SMASH, "pos": c + Vector2(d, 0), "r": r, "label": "SMASH", "color": Shots.COLORS[Shots.SMASH]},
		{"id": "drop", "type": Shots.DROP, "pos": c + Vector2(0, d), "r": r, "label": "CURTA", "color": Shots.COLORS[Shots.DROP]},
		{"id": "drive", "type": Shots.DRIVE, "pos": c + Vector2(-d, 0), "r": r, "label": "FORTE", "color": Shots.COLORS[Shots.DRIVE]},
		# especial: botão grande de estrela logo acima do losango
		{"id": "super", "type": -2, "pos": c + Vector2(0, -d * 2.3), "r": 48.0 * u, "label": "ESPECIAL", "color": Color("ffe14d")},
		{"id": "defense", "type": Shots.DEFENSE, "pos": c + Vector2(-d * 2.15, -d * 0.05), "r": 36.0 * u, "label": "DEFESA", "color": Color("e8e2d4")},
		{"id": "dive", "type": -1, "pos": c + Vector2(-d * 2.05, d * 1.1), "r": 34.0 * u, "label": "PEIXINHO", "color": Color("ffffff")},
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
	# analógico flutuante (base translúcida)
	if joy_index >= 0:
		draw_circle(joy_origin, 78.0 * u, Color(1, 1, 1, 0.12))
		draw_arc(joy_origin, 78.0 * u, 0, TAU, 40, Color(1, 1, 1, 0.45), 3.0 * u)
		var k := joy_origin + joy_vec * 70.0 * u
		draw_circle(k, 36.0 * u, Color(INK, 0.6))
		draw_circle(k, 31.0 * u, Color(1.0, 0.82, 0.25, 0.75))
	else:
		var hint := Vector2(128.0 * u, get_viewport_rect().size.y - 128.0 * u)
		draw_circle(hint, 66.0 * u, Color(1, 1, 1, 0.07))
		draw_arc(hint, 66.0 * u, 0, TAU, 40, Color(1, 1, 1, 0.25), 3.0 * u)
		_text(hint + Vector2(0, 6 * u), "MOVER", 24, Color(1, 1, 1, 0.45), u, 0.4)
	for b in buttons:
		if b["id"] == "super":
			_draw_super(b, u)
			continue
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var lit: bool = pressed.has(b["id"])
		var a := PRESS_ALPHA if lit else IDLE_ALPHA
		var col: Color = b["color"]
		col = col.lightened(0.35) if lit else col
		col.a = a
		var off := Vector2(0, 2.0 * u) if lit else Vector2.ZERO
		draw_circle(p + Vector2(0, 4.0 * u), r, Color(INK, 0.25 * a))
		draw_circle(p + off, r, Color(INK, 0.7 * a))
		draw_circle(p + off, r - 3.5 * u, col)
		draw_circle(p + off - Vector2(r * 0.3, r * 0.35), r * 0.2, Color(1, 1, 1, 0.35 * a))
		var fs := 22 if String(b["label"]).length() <= 5 else 15
		_text(p + off + Vector2(0, 2.0 * u), b["label"], fs, Color(1, 1, 1, minf(1.0, a + 0.3)), u, a)


func _text(center: Vector2, s: String, fs: int, col: Color, u: float, alpha := 1.0) -> void:
	var size := int(fs * u)
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := center + Vector2(-w * 0.5, size * 0.35)
	draw_string_outline(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(6 * u), Color(INK, minf(1.0, alpha + 0.2)))
	draw_string(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Botão do especial: estrela que enche com a barra de energia e pulsa quando está pronto
func _draw_super(b: Dictionary, u: float) -> void:
	var p: Vector2 = b["pos"]
	var r: float = b["r"]
	var ready := super_fill >= 1.0
	var lit := pressed.has("super")
	var a := PRESS_ALPHA if ready or lit else IDLE_ALPHA + 0.1
	var rr := r * (1.0 + (sin(t * 9.0) * 0.07 if ready else 0.0))
	if ready:
		var rays := PackedVector2Array()
		for i in 24:
			var ang := float(i) / 24.0 * TAU + t * 1.2
			var k := 1.55 if i % 2 == 0 else 1.08
			rays.append(p + Vector2(cos(ang), sin(ang)) * rr * k)
		draw_colored_polygon(rays, Color(1.0, 0.85, 0.25, 0.5))
	draw_circle(p + Vector2(0, 4.0 * u), rr, Color(INK, 0.25 * a))
	draw_circle(p, rr, Color(INK, 0.75 * a))
	var base := Color("ff9f1c") if ready else Color(0.36, 0.33, 0.46)
	base.a = a
	draw_circle(p, rr - 3.5 * u, base)
	# carga em volta
	if not ready:
		draw_arc(p, rr - 6.0 * u, -PI * 0.5, -PI * 0.5 + TAU * maxf(super_fill, 0.001), 40, Color(1.0, 0.88, 0.3, 0.95), 7.0 * u)
	# estrela
	var sc := p + Vector2(0, -7.0 * u)
	var sr := rr * 0.62
	var star := PackedVector2Array()
	var outl := PackedVector2Array()
	var rot := sin(t * 3.0) * 0.15 if ready else 0.0
	for i in 10:
		var ang := rot - PI * 0.5 + float(i) / 10.0 * TAU
		var k := 1.0 if i % 2 == 0 else 0.45
		star.append(sc + Vector2(cos(ang), sin(ang)) * sr * k)
		outl.append(sc + Vector2(cos(ang), sin(ang)) * (sr * k + 3.5 * u))
	draw_colored_polygon(outl, Color(INK, 0.8 * a))
	var sf := Color("ffe14d") if ready else Color(1.0, 0.9, 0.5, 0.35 + 0.5 * super_fill)
	sf.a *= a
	draw_colored_polygon(star, sf)
	_text(p + Vector2(0, rr * 0.62), "ESPECIAL", 15, Color(1, 1, 1, 1.0 if ready else 0.75), u, a)
	if ready:
		_text(p + Vector2(0, -rr - 14.0 * u), "PRONTO!", 20 + int(2.0 * sin(t * 9.0)), Color("ffe14d"), u, 1.0)
