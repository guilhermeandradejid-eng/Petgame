class_name TouchPad
extends Control
## Controles na tela (toque e mouse): analógico à esquerda; TIRO, NITRO, DRIFT, MINA/ÓLEO e FREIO à direita.

var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var btn := {"fire": false, "nitro": false, "drift": false, "drop": false, "brake": false}
var btn_ids := {}
var active := true
var used := false
var counts := {"fire": "", "nitro": "", "drop": ""}
var labels := {"fire": "TIRO", "nitro": "NITRO", "drift": "DRIFT", "drop": "MINA", "brake": "FREIO"}
var nitro_on := false
var font: Font
const R := 70.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _btn_rects() -> Dictionary:
	var s := size
	var u := minf(s.y, s.x) / 720.0 * 1.12
	var base := Vector2(s.x - 26 * u, s.y - 26 * u)
	return {
		"fire": [base + Vector2(-86, -86) * u, 84.0 * u],
		"nitro": [base + Vector2(-238, -60) * u, 58.0 * u],
		"drift": [base + Vector2(-372, -48) * u, 48.0 * u],
		"drop": [base + Vector2(-70, -248) * u, 52.0 * u],
		"brake": [base + Vector2(-206, -196) * u, 42.0 * u],
	}


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		_touch(e.index, e.position, e.pressed)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position)
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION and e.button_index == MOUSE_BUTTON_LEFT:
		_touch(100, e.position, e.pressed)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_drag(100, e.position)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var hb := _hit_button(pos)
		if hb != "":
			used = true
			btn_ids[index] = hb
			btn[hb] = true
			Input.vibrate_handheld(10)
		elif pos.x < size.x * 0.5 and stick_id == -1 and pos.y > size.y * 0.22:
			used = true
			stick_id = index
			stick_origin = pos
			stick_vec = Vector2.ZERO
	else:
		if btn_ids.has(index):
			btn[btn_ids[index]] = false
			btn_ids.erase(index)
		if index == stick_id:
			stick_id = -1
			stick_vec = Vector2.ZERO


func _drag(index: int, pos: Vector2) -> void:
	if index == stick_id:
		var v := (pos - stick_origin) / R
		if v.length() > 1.0:
			stick_origin += v.normalized() * (v.length() - 1.0) * R
			v = v.normalized()
		stick_vec = v
	elif btn_ids.has(index):
		var hb := _hit_button(pos)
		if hb != "" and hb != btn_ids[index]:
			btn[btn_ids[index]] = false
			btn_ids[index] = hb
			btn[hb] = true


func _hit_button(p: Vector2) -> String:
	var rects := _btn_rects()
	for k in rects:
		if p.distance_to(rects[k][0]) < rects[k][1] * 1.12:
			return k
	return ""


func release_all() -> void:
	for k in btn:
		btn[k] = false
	btn_ids.clear()
	stick_id = -1
	stick_vec = Vector2.ZERO


func _process(_dt: float) -> void:
	var vs := get_viewport_rect().size
	if size != vs or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = vs
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if font == null:
		font = get_theme_default_font()
	var rects := _btn_rects()
	var cols := {"fire": Color(1.0, 0.32, 0.22), "nitro": Color(0.2, 0.75, 1.0), "drift": Color(0.78, 0.49, 1.0), "drop": Color(1.0, 0.8, 0.2), "brake": Color(0.4, 0.4, 0.5)}
	for k in rects:
		var c: Vector2 = rects[k][0]
		var r: float = rects[k][1]
		var down: bool = btn[k]
		var off := Vector2(0, 4) if down else Vector2.ZERO
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.35))
		var cc: Color = cols[k]
		if k == "nitro" and nitro_on:
			cc = Color(0.6, 0.95, 1.0)
		draw_circle(c + off, r, Color(0.1, 0.08, 0.18, 0.7))
		draw_circle(c + off, r * 0.9, cc * Color(1, 1, 1, 0.9 if down else 0.62))
		draw_arc(c + off, r, 0, TAU, 48, Color(1, 1, 1, 0.75 if down else 0.4), 3.0)
		var fs := int(r * 0.3)
		var lb: String = labels[k]
		var tw := font.get_string_size(lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ty := fs * 0.1 if counts.get(k, "") != "" else fs * 0.35
		draw_string_outline(font, c + off + Vector2(-tw / 2.0, ty), lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.5))
		draw_string(font, c + off + Vector2(-tw / 2.0, ty), lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var cnt: String = counts.get(k, "")
		if cnt != "":
			var fs2 := int(r * 0.34)
			var tw2 := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			draw_string_outline(font, c + off + Vector2(-tw2 / 2.0, fs2 * 1.25), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4, Color(0, 0, 0, 0.5))
			draw_string(font, c + off + Vector2(-tw2 / 2.0, fs2 * 1.25), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 0.8))
	if stick_id != -1:
		draw_circle(stick_origin, R * 1.05, Color(1, 1, 1, 0.12))
		draw_arc(stick_origin, R * 1.05, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		draw_circle(stick_origin + stick_vec * R, 30, Color(1, 0.55, 0.65, 0.95))
		draw_circle(stick_origin + stick_vec * R - Vector2(8, 8), 10, Color(1, 1, 1, 0.6))
	else:
		var hint := Vector2(size.x * 0.15, size.y * 0.72)
		draw_arc(hint, R, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
		draw_circle(hint, 26, Color(1, 1, 1, 0.12))
		var t := "ARRASTE PARA DIRIGIR"
		var tw3 := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, hint + Vector2(-tw3 / 2.0, R + 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
