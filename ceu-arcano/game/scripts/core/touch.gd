extends CanvasLayer
## Controles de toque: direcional virtual à esquerda e botões à direita. Alimentam as ações do
## jogador 1 (p1_*), então servem para a luta e para os menus. Aparece no primeiro toque
## (ou já de início em aparelhos com tela de toque). F2 liga e desliga.

const DPAD_C := Vector2(66, 288)
const DPAD_R := 52.0
const BUTTONS := [
	{"id": "a", "pos": Vector2(598, 300), "r": 24.0, "label": "GOLPE", "col": Color("ffd66b")},
	{"id": "b", "pos": Vector2(548, 322), "r": 21.0, "label": "TIRO", "col": Color("6ad8ff")},
	{"id": "c", "pos": Vector2(598, 246), "r": 21.0, "label": "HABIL.", "col": Color("ff7aa8")},
	{"id": "dash", "pos": Vector2(548, 268), "r": 21.0, "label": "DASH", "col": Color("8affb0")},
	{"id": "spell", "pos": Vector2(494, 300), "r": 19.0, "label": "CARTA", "col": Color("ffffff")},
	{"id": "switch", "pos": Vector2(494, 252), "r": 15.0, "label": "TROCA", "col": Color("c8b8ff")},
	{"id": "start", "pos": Vector2(618, 108), "r": 13.0, "label": "II", "col": Color("ffffff")},
]

var shown := false
var fingers := {}        # índice do dedo -> "dpad" ou id do botão
var dpad_vec := Vector2.ZERO
var held := {}           # ação -> bool
var view: Control


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = _View.new()
	view.t = self
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	shown = DisplayServer.is_touchscreen_available()
	view.visible = shown


class _View extends Control:
	var t
	func _draw() -> void:
		t._draw_ui(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		shown = not shown
		view.visible = shown
		if not shown:
			_release_all()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not shown and event.pressed:
			shown = true
			view.visible = true
		if event.pressed:
			var hit := _hit(event.position)
			if hit != "":
				fingers[event.index] = hit
				if hit == "dpad":
					_update_dpad(event.position)
				else:
					press_act(hit, true)
			elif _in_menu():
				_tap("a")
		else:
			var h = fingers.get(event.index, "")
			fingers.erase(event.index)
			if h == "dpad":
				dpad_vec = Vector2.ZERO
				_apply_dpad()
			elif h != "":
				press_act(h, false)
	elif event is InputEventScreenDrag:
		if fingers.get(event.index, "") == "dpad":
			_update_dpad(event.position)


func _in_menu() -> bool:
	var s := get_tree().current_scene
	return s != null and s.name != "Battle"


func _hit(p: Vector2) -> String:
	for b in BUTTONS:
		if b["id"] == "start" and _in_menu():
			continue
		if p.distance_to(b["pos"]) <= b["r"] + 8.0:
			return b["id"]
	if p.x < 190.0 and p.y > 170.0:
		return "dpad"
	return ""


func _update_dpad(p: Vector2) -> void:
	dpad_vec = (p - DPAD_C).limit_length(DPAD_R * 1.6)
	_apply_dpad()


func _apply_dpad() -> void:
	var v := dpad_vec
	press_act("left", v.x < -14.0)
	press_act("right", v.x > 14.0)
	press_act("up", v.y < -22.0)
	press_act("down", v.y > 22.0)


func press_act(id: String, on: bool) -> void:
	if held.get(id, false) == on:
		return
	held[id] = on
	var act := "p1_" + id
	if on:
		Input.action_press(act)
	else:
		Input.action_release(act)


func _tap(id: String) -> void:
	press_act(id, true)
	await get_tree().create_timer(0.09).timeout
	press_act(id, false)


func _release_all() -> void:
	fingers.clear()
	dpad_vec = Vector2.ZERO
	for k in held.keys():
		press_act(k, false)


func _process(_d: float) -> void:
	if shown:
		view.queue_redraw()


func _draw_ui(c: Control) -> void:
	var font: Font = Game.font_small
	# direcional
	c.draw_circle(DPAD_C, DPAD_R, Color(0.05, 0.03, 0.14, 0.38))
	c.draw_arc(DPAD_C, DPAD_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 1.5)
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var tip: Vector2 = DPAD_C + d * 34.0
		var side := Vector2(-d.y, d.x) * 6.0
		c.draw_colored_polygon(PackedVector2Array([tip + d * 6.0, tip - d * 4.0 + side, tip - d * 4.0 - side]), Color(1, 1, 1, 0.45))
	var knob: Vector2 = DPAD_C + dpad_vec.limit_length(DPAD_R * 0.75)
	c.draw_circle(knob, 17.0, Color(1, 1, 1, 0.22 if dpad_vec == Vector2.ZERO else 0.42))
	c.draw_arc(knob, 17.0, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
	# botões
	for b in BUTTONS:
		if b["id"] == "start" and _in_menu():
			continue
		var on: bool = held.get(b["id"], false)
		var col: Color = b["col"]
		var p: Vector2 = b["pos"]
		var r: float = b["r"] * (0.93 if on else 1.0)
		c.draw_circle(p, r, Color(col.darkened(0.6), 0.5 if not on else 0.8))
		c.draw_arc(p, r, 0, TAU, 32, Color(col, 0.9 if on else 0.6), 2.0)
		var w := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		c.draw_string(font, p + Vector2(-w * 0.5, 3), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.95 if on else 0.8))
