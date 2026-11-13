class_name MenuList
extends Control
## Lista de opções navegável por teclado/controle, com cursor animado.

signal chosen(index: int)
signal cancelled

var items: Array = []        # [{text, hint?, disabled?}]
var sel := 0
var active := true
var font_size := 14
var spacing := 20.0
var align := 1               # 0 esquerda, 1 centro
var accent := Color("ffd66b")
var t := 0.0
var bump := 0.0
var _repeat := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_items(arr: Array) -> void:
	items = arr
	sel = clampi(sel, 0, maxi(0, items.size() - 1))
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	bump = maxf(0.0, bump - delta * 6.0)
	if active and is_visible_in_tree():
		_poll(delta)
	queue_redraw()


func _act(name: String) -> bool:
	return Input.is_action_just_pressed("p1_" + name) or Input.is_action_just_pressed("p2_" + name)


func _poll(delta: float) -> void:
	var dy := 0
	if _act("up") or Input.is_action_just_pressed("ui_up"):
		dy = -1
	elif _act("down") or Input.is_action_just_pressed("ui_down"):
		dy = 1
	var held := Input.is_action_pressed("p1_up") or Input.is_action_pressed("p1_down") or Input.is_action_pressed("p2_up") \
		or Input.is_action_pressed("p2_down") or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")
	if held and dy == 0:
		_repeat += delta
		if _repeat > 0.35:
			_repeat = 0.27
			dy = 1 if (Input.is_action_pressed("p1_down") or Input.is_action_pressed("p2_down") or Input.is_action_pressed("ui_down")) else -1
	elif not held:
		_repeat = 0.0
	if dy != 0 and items.size() > 0:
		sel = posmod(sel + dy, items.size())
		bump = 1.0
		Audio.play("ui_move", -6.0)
	if _act("a") or Input.is_action_just_pressed("ui_accept"):
		if items.size() > 0 and not items[sel].get("disabled", false):
			Audio.play("ui_confirm", -4.0)
			chosen.emit(sel)
		else:
			Audio.play("ui_error", -6.0)
	elif _act("b") or Input.is_action_just_pressed("ui_cancel"):
		Audio.play("ui_back", -4.0)
		cancelled.emit()


func _draw() -> void:
	var font: Font = Game.font_main
	for i in items.size():
		var it: Dictionary = items[i]
		var y := i * spacing + font_size
		var is_sel := i == sel
		var col := Color(1, 1, 1) if is_sel else Color(0.7, 0.68, 0.85)
		if it.get("disabled", false):
			col = Color(0.4, 0.38, 0.5)
		var txt: String = it["text"]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := (size.x - w) * 0.5 if align == 1 else 16.0
		if is_sel:
			var off := sin(t * 6.0) * 2.0
			x += bump * 4.0
			var bw := w + 28.0
			var bx := (size.x - bw) * 0.5 if align == 1 else 4.0
			draw_rect(Rect2(bx, y - font_size + 1, bw, font_size + 6), Color(accent, 0.18))
			draw_rect(Rect2(bx, y + 6, bw, 1), Color(accent, 0.7))
			_diamond(Vector2(x - 10 + off, y - font_size * 0.35), accent)
			_diamond(Vector2(x + w + 10 - off, y - font_size * 0.35), accent)
		draw_string_outline(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.04, 0.02, 0.1))
		draw_string(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		if is_sel and it.has("hint"):
			var hs := 9
			var hw := font.get_string_size(it["hint"], HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
			var hx := (size.x - hw) * 0.5 if align == 1 else 16.0
			draw_string(font, Vector2(hx, items.size() * spacing + font_size + 10), it["hint"], HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(0.75, 0.8, 1.0, 0.8))


func _diamond(c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), col)
