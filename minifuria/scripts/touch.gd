class_name TouchPad
extends Control
## Controles na tela (toque e mouse): analógico à esquerda; TIRO, NITRO (mobilidade), ESPECIAL, MINA/ÓLEO e FREIO à direita.

var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var btn := {"fire": false, "nitro": false, "drift": false, "drop": false, "brake": false, "special": false}
var btn_ids := {}
var active := true
var used := false
var counts := {"fire": "", "nitro": "", "drop": "", "special": ""}
var labels := {"fire": "TIRO", "nitro": "NITRO", "drift": "DRIFT", "drop": "MINA", "brake": "FREIO", "special": ""}
var nitro_on := false
var icons := {"fire": "atk", "nitro": "short", "drop": "rear", "brake": "brake", "special": "shield"}
var font: Font
const R := 70.0


## os botões de toque só aparecem com tela de toque: no PC ficam escondidos até alguém tocar na tela e
## somem de novo quando o teclado ou o controle é usado
static var touch_mode := false
var want := false   # o HUD quer mostrar (tela da corrida)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_mode = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or (OS.get_name() != "Web" and DisplayServer.is_touchscreen_available())


func show_if(on: bool) -> void:
	want = on
	visible = on and touch_mode


func _btn_rects() -> Dictionary:
	var s := size
	var u := minf(s.y, s.x) / 720.0 * 1.12
	var base := Vector2(s.x - 26 * u, s.y - 26 * u)
	var r := {
		"fire": [base + Vector2(-86, -86) * u, 84.0 * u],
		"nitro": [base + Vector2(-238, -60) * u, 58.0 * u],
		"drop": [base + Vector2(-70, -248) * u, 52.0 * u],
		"brake": [base + Vector2(-206, -196) * u, 42.0 * u],
	}
	# especial comprado: botão próprio ao lado do nitro (some se o carro não tiver)
	if String(labels.get("special", "")) != "":
		r["special"] = [base + Vector2(-350, -64) * u, 46.0 * u]
	return r


func _input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or e is InputEventScreenDrag) and not touch_mode:
		touch_mode = true
		visible = want
	elif not OS.has_feature("mobile") and touch_mode and e.is_pressed() and (e is InputEventKey or e is InputEventJoypadButton):
		touch_mode = false
		visible = false
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
		font = UI.display_it if UI.display_it else get_theme_default_font()
	var rects := _btn_rects()
	var cols := {"fire": Color("#ff5a3a"), "nitro": Color("#2ee6ff"), "drift": Color(0.78, 0.49, 1.0), "drop": Color("#ffb21a"), "brake": Color("#a49ec4"), "special": Color("#5dff6a")}
	for k in rects:
		var c: Vector2 = rects[k][0]
		var r: float = rects[k][1]
		var down: bool = btn[k]
		var off := Vector2(0, 3) if down else Vector2.ZERO
		var cc: Color = cols[k]
		if k == "nitro" and nitro_on:
			cc = Color.WHITE
		var cnt: String = counts.get(k, "")
		var empty := cnt == "0"
		# vidro escuro com anel colorido; apertado = cheio da cor
		draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.3))
		draw_circle(c + off, r, Color(cc, 0.85) if down else Color(0.06, 0.05, 0.11, 0.62))
		draw_arc(c + off, r - 3.0, 0, TAU, 48, Color(cc, 0.35 if empty else 0.95), 5.0, true)
		draw_arc(c + off, r * 0.78, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.12), 3.0, true)
		var ic_col := UI.INK if down else (Color(1, 1, 1, 0.35) if empty else Color.WHITE)
		var isz := r * (0.78 if cnt != "" else 0.95)
		var icy := -r * 0.16 if cnt != "" else 0.0
		Icon.paint(self, String(icons.get(k, "atk")), Rect2(c + off + Vector2(-isz * 0.5, -isz * 0.5 + icy), Vector2(isz, isz)), ic_col)
		if cnt != "":
			var fs2 := int(r * 0.36)
			var tw2 := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var tp := c + off + Vector2(-tw2 / 2.0, r * 0.62)
			draw_string_outline(font, tp, cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 4, Color(0.03, 0.02, 0.07, 0.8))
			draw_string(font, tp, cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, UI.INK if down else (Color(1, 1, 1, 0.4) if empty else cc.lightened(0.4)))
	if stick_id != -1:
		draw_circle(stick_origin, R * 1.05, Color(0.06, 0.05, 0.11, 0.35))
		draw_arc(stick_origin, R * 1.05, 0, TAU, 48, Color(1, 1, 1, 0.4), 3.0, true)
		draw_circle(stick_origin + stick_vec * R, 30, Color(0.06, 0.05, 0.11, 0.75))
		draw_arc(stick_origin + stick_vec * R, 28, 0, TAU, 32, UI.HOT, 4.0, true)
	else:
		# dica do analógico: anel com quatro setas (sem texto)
		var hint := Vector2(size.x * 0.15, size.y * 0.72)
		draw_arc(hint, R, 0, TAU, 48, Color(1, 1, 1, 0.16), 2.0, true)
		draw_circle(hint, 24, Color(1, 1, 1, 0.1))
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var tip: Vector2 = hint + d * (R - 10)
			var sd := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([tip, tip - d * 12 + sd * 9, tip - d * 12 - sd * 9]), Color(1, 1, 1, 0.22))
