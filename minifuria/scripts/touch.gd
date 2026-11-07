class_name TouchPad
extends Control
## Controles touch: analógico à esquerda (aponta a direção na tela), botões NITRO, DRIFT e FREIO à direita.

var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO     # -1..1, y para baixo
var btn := {"nitro": false, "drift": false, "brake": false}
var btn_ids := {}                 # índice do toque -> botão
var active := false               # já recebeu toque?
var nitro_fill := 0.0
const R := 70.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	active = DisplayServer.is_touchscreen_available()


func _btn_rects() -> Dictionary:
	var s := size
	var u := minf(s.y, s.x) / 720.0 * 1.15
	var base := Vector2(s.x - 30 * u, s.y - 30 * u)
	return {
		"nitro": [base + Vector2(-80, -80) * u, 80.0 * u],
		"drift": [base + Vector2(-220, -55) * u, 58.0 * u],
		"brake": [base + Vector2(-175, -185) * u, 44.0 * u],
	}


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		active = true
		var t := e as InputEventScreenTouch
		if t.pressed:
			var hitb := _hit_button(t.position)
			if hitb != "":
				btn_ids[t.index] = hitb
				btn[hitb] = true
				Input.vibrate_handheld(10)
			elif t.position.x < size.x * 0.5 and stick_id == -1 and t.position.y > size.y * 0.25:
				stick_id = t.index
				stick_origin = t.position
				stick_vec = Vector2.ZERO
		else:
			if btn_ids.has(t.index):
				btn[btn_ids[t.index]] = false
				btn_ids.erase(t.index)
			if t.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
		queue_redraw()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == stick_id:
			var v := (d.position - stick_origin) / R
			if v.length() > 1.0:
				stick_origin += v.normalized() * (v.length() - 1.0) * R
				v = v.normalized()
			stick_vec = v
			queue_redraw()
		elif btn_ids.has(d.index):
			# deslizar o dedo entre botões
			var hb := _hit_button(d.position)
			if hb != "" and hb != btn_ids[d.index]:
				btn[btn_ids[d.index]] = false
				btn_ids[d.index] = hb
				btn[hb] = true
				queue_redraw()


func _hit_button(p: Vector2) -> String:
	var rects := _btn_rects()
	for k in rects:
		if p.distance_to(rects[k][0]) < rects[k][1] * 1.15:
			return k
	return ""


func _process(_dt: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	if not active or not visible:
		return
	var font := get_theme_default_font()
	var rects := _btn_rects()
	var cols := {"nitro": Color(0.2, 0.75, 1.0), "drift": Color(0.78, 0.49, 1.0), "brake": Color(0.35, 0.35, 0.45)}
	var labels := {"nitro": "NITRO", "drift": "DRIFT", "brake": "FREIO"}
	for k in rects:
		var c: Vector2 = rects[k][0]
		var r: float = rects[k][1]
		var down: bool = btn[k]
		var off := Vector2(0, 4) if down else Vector2.ZERO
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.35))
		draw_circle(c + off, r, Color(0.12, 0.1, 0.2, 0.65))
		if k == "nitro":
			# enchimento do nitro
			var f := clampf(nitro_fill, 0.0, 1.0)
			var steps := 40
			var pts := PackedVector2Array()
			var top := c.y + off.y + r - 2.0 * r * f
			for i in steps + 1:
				var a := PI * 2.0 * i / steps
				var p := c + off + Vector2(cos(a), sin(a)) * r
				p.y = maxf(p.y, top)
				pts.append(p)
			if f > 0.01:
				draw_colored_polygon(pts, Color(0.15, 0.6, 1.0, 0.95) if f < 0.999 else Color(0.5, 0.95, 1.0))
		else:
			draw_circle(c + off, r * 0.92, cols[k] * Color(1, 1, 1, 0.85 if down else 0.6))
		draw_arc(c + off, r, 0, TAU, 48, Color(1, 1, 1, 0.7 if down else 0.35), 3.0)
		var fs := int(r * 0.32)
		var tw := font.get_string_size(labels[k], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + off + Vector2(-tw / 2.0, fs * 0.35), labels[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if stick_id != -1:
		draw_circle(stick_origin, R * 1.05, Color(1, 1, 1, 0.12))
		draw_arc(stick_origin, R * 1.05, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		draw_circle(stick_origin + stick_vec * R, 30, Color(1, 0.55, 0.65, 0.95))
		draw_circle(stick_origin + stick_vec * R - Vector2(8, 8), 10, Color(1, 1, 1, 0.6))
	else:
		var hint := Vector2(size.x * 0.16, size.y * 0.72)
		draw_arc(hint, R, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
		var t := "arraste p/ dirigir"
		draw_string(font, hint + Vector2(-60, 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.4))
