extends CanvasLayer
## Cut-in da declaração de feitiço: faixa diagonal, retrato ampliado, linhas de velocidade e nome da carta.

var battle
var view: Control
var active := false
var t := 0.0
var dur := 1.05
var side := 0
var tex: Texture2D
var col := Color.WHITE
var sign_txt := ""
var name_txt := ""
var lines: Array = []


func _ready() -> void:
	layer = 40
	view = _View.new()
	view.cut = self
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


class _View extends Control:
	var cut
	func _draw() -> void:
		cut._draw_cut(self)


func play(f: Fighter, cid: String) -> void:
	var cd := Cards.get_card(cid)
	active = true
	t = 0.0
	side = f.pid
	tex = f.data.portrait_b if f.alt_palette else f.data.portrait_a
	col = cd["color"]
	sign_txt = cd["sign"]
	name_txt = "「%s」" % cd["name"]
	lines.clear()
	for i in 26:
		lines.append({"y": randf_range(-80, 80), "x": randf() * 900.0, "w": randf_range(30, 140), "s": randf_range(14, 30)})


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	if t > dur:
		active = false
	view.queue_redraw()


func _draw_cut(c: Control) -> void:
	if not active:
		return
	var k_in := clampf(t / 0.16, 0.0, 1.0)
	var k_out := clampf((t - (dur - 0.2)) / 0.2, 0.0, 1.0)
	var open := ease(k_in, 0.3) * (1.0 - ease(k_out, 2.0))
	var dir := 1.0 if side == 0 else -1.0
	var ctr := Vector2(320, 180)
	var ang := -0.18 * dir
	c.draw_set_transform(ctr, ang, Vector2.ONE)
	var h := 92.0 * open
	c.draw_rect(Rect2(-500, -h * 0.5 - 4, 1000, h + 8), Color(0.02, 0.01, 0.06, 0.92))
	var deep := Color(0.12, 0.06, 0.26)
	c.draw_rect(Rect2(-500, -h * 0.5, 1000, h), Color(deep.lerp(col, 0.35), 0.95))
	for i in 6:
		var yy := -h * 0.5 + h * (i + 0.5) / 6.0
		c.draw_rect(Rect2(-500, yy - 1, 1000, 2), Color(col, 0.08))
	c.draw_rect(Rect2(-500, -h * 0.5, 1000, h * 0.35), Color(1, 1, 1, 0.05))
	c.draw_rect(Rect2(-500, -h * 0.5, 1000, 2), col)
	c.draw_rect(Rect2(-500, h * 0.5 - 2, 1000, 2), col)
	# linhas de velocidade
	for ln in lines:
		var x: float = fmod(ln["x"] + t * ln["s"] * 60.0 * dir, 1000.0) - 500.0
		if dir < 0:
			x = -x
		var y: float = ln["y"] * open
		if absf(y) < h * 0.5 - 2:
			c.draw_line(Vector2(x, y), Vector2(x - ln["w"] * dir, y), Color(col.lerp(Color.WHITE, 0.5), 0.35), 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# retrato
	if tex and open > 0.05:
		var scale := 3.0 if tex.get_height() * 3 <= 320 else 2.0
		var tw := tex.get_width() * scale
		var th := tex.get_height() * scale
		var slide := 1.0 - pow(1.0 - clampf(t / 0.22, 0.0, 1.0), 3.0)
		var drift := t * 14.0
		var px := -tw + (180.0 + tw) * slide + drift if side == 0 else 640.0 - (180.0 + tw) * slide - drift
		var py := clampf(196.0 - th * 0.5, 8.0, 360.0 - th)
		var m := Color(1, 1, 1, 1.0 - k_out)
		# rastro
		for i in 3:
			var off := (i + 1) * 14.0 * (1.0 - slide) * dir
			c.draw_texture_rect(tex, Rect2(px - off, py, tw, th), false, Color(col, 0.25 * (1.0 - k_out)))
		c.draw_texture_rect(tex, Rect2(px, py, tw, th), false, m)
	# textos
	var tx := 320.0 + 40.0 * dir
	var e := 1.0 - pow(1.0 - clampf((t - 0.08) / 0.25, 0.0, 1.0), 3.0)
	var a := e * (1.0 - k_out)
	var off2 := (1.0 - e) * 120.0 * dir
	var font: Font = Game.font_main
	var s1 := 10
	var s2 := 20
	var al := 0 if side == 0 else 2
	var x1 := tx + off2 if side == 0 else 640.0 - tx - off2 + 320.0 - 320.0
	if side == 1:
		x1 = 320.0 - 40.0 - off2
	_txt(c, font, sign_txt, Vector2(x1, 168), s1, Color(col.lerp(Color.WHITE, 0.6), a), al)
	_txt(c, font, name_txt, Vector2(x1, 192), s2, Color(1, 1, 1, a), al)
	# flash inicial
	if t < 0.1:
		c.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, (0.1 - t) * 4.0))


func _txt(c: Control, font: Font, s: String, pos: Vector2, size: int, color: Color, align: int) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x - (w if align == 2 else 0.0)
	c.draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.03, 0.01, 0.08, color.a))
	c.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
