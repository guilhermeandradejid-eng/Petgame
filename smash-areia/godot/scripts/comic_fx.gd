class_name ComicFX
extends Control
## Onomatopeias de gibi (estrela + texto), linhas de velocidade e flash.

const FONT := preload("res://assets/fonts/Bangers.woff")
const INK := Color(0.07, 0.04, 0.12)

var pops: Array[Dictionary] = []
var speed_lines := 0.0
var speed_center := Vector2.ZERO
var flash := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func pop(screen_pos: Vector2, text: String, color: Color, size := 1.0, star := true) -> void:
	pops.append({
		"pos": screen_pos, "text": text, "color": color, "t": 0.0, "life": 0.95,
		"size": size, "rot": rng.randf_range(-0.25, 0.25), "star": star, "seed": rng.randf() * 10.0,
	})
	if pops.size() > 8:
		pops.pop_front()


func smash_lines(center: Vector2) -> void:
	speed_lines = 0.45
	speed_center = center


func do_flash(amount := 0.6) -> void:
	flash = maxf(flash, amount)


func _process(dt: float) -> void:
	for p in pops:
		p["t"] = float(p["t"]) + dt
	pops = pops.filter(func(p): return float(p["t"]) < float(p["life"]))
	speed_lines = maxf(speed_lines - dt, 0.0)
	flash = maxf(flash - dt * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	var ui := vs.y / 720.0
	if speed_lines > 0.0:
		var a := speed_lines / 0.45
		var r := RandomNumberGenerator.new()
		r.seed = int(Time.get_ticks_msec() / 50)
		for i in 46:
			var ang := r.randf() * TAU
			var dir := Vector2(cos(ang), sin(ang))
			var inner := r.randf_range(0.28, 0.5) * vs.length() * 0.5
			var outer := vs.length()
			var w := r.randf_range(2.0, 7.0) * ui
			var p1 := speed_center + dir * inner
			var p2 := speed_center + dir * outer
			var n := Vector2(-dir.y, dir.x) * w
			draw_colored_polygon(PackedVector2Array([p1, p2 + n, p2 - n]), Color(1, 1, 1, 0.75 * a))
	for p in pops:
		_draw_pop(p, ui)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, flash * 0.5))


func _draw_pop(p: Dictionary, ui: float) -> void:
	var t: float = p["t"]
	var life: float = p["life"]
	var appear := minf(t / 0.12, 1.0)
	var s := (0.6 + 0.6 * _back_out(appear)) * float(p["size"]) * ui
	var fade := clampf((life - t) / 0.25, 0.0, 1.0)
	var pos: Vector2 = p["pos"] + Vector2(0, -t * 40.0 * ui)
	draw_set_transform(pos, float(p["rot"]), Vector2(s, s))
	var col: Color = p["color"]
	col.a = fade
	var ink := INK
	ink.a = fade
	var text: String = p["text"]
	var fs := 54
	var tw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if p["star"]:
		var pts := PackedVector2Array()
		var n := 14
		var rx := tw * 0.5 + 46.0
		var ry := 62.0
		var seed: float = p["seed"]
		for i in n * 2:
			var a := float(i) / float(n * 2) * TAU
			var rr := 1.0 if i % 2 == 0 else 0.62 + 0.12 * sin(seed + i)
			pts.append(Vector2(cos(a) * rx * rr, sin(a) * ry * rr))
		var outline := PackedVector2Array()
		for v in pts:
			outline.append(v * 1.09)
		draw_colored_polygon(outline, ink)
		draw_colored_polygon(pts, col)
	var tpos := Vector2(-tw * 0.5, fs * 0.36)
	var txt_col := Color.WHITE if p["star"] else col
	txt_col.a = fade
	draw_string_outline(FONT, tpos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, ink)
	draw_string(FONT, tpos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _back_out(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
