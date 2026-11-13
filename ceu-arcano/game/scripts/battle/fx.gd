class_name Fx
extends Node2D
## Efeitos: faíscas de impacto, partículas de pixel, anéis, poeira, pós-imagens e textos.

var parts: Array = []      # partículas comuns
var glows: Array = []      # partículas aditivas
var shapes: Array = []     # anéis, raios, flashes (aditivos)
var _add: Node2D
var _norm: Node2D


class _Layer extends Node2D:
	var fx
	var additive := false
	func _draw() -> void:
		fx._draw_layer(self, additive)


func _ready() -> void:
	_norm = _Layer.new()
	_norm.fx = self
	add_child(_norm)
	_add = _Layer.new()
	_add.fx = self
	_add.additive = true
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = m
	_add.z_index = 30
	_norm.z_index = 29
	add_child(_add)


func _process(delta: float) -> void:
	var k := delta * 60.0
	for arr in [parts, glows]:
		for i in range(arr.size() - 1, -1, -1):
			var p: Dictionary = arr[i]
			p["life"] -= k
			if p["life"] <= 0.0:
				arr.remove_at(i)
				continue
			p["v"] = p["v"] * pow(p["drag"], k) + Vector2(0, p["grav"] * k)
			p["p"] += p["v"] * k
			if p.get("floor", false) and p["p"].y > 0.0:
				p["p"].y = 0.0
				p["v"].y *= -0.35
				p["v"].x *= 0.6
	for i in range(shapes.size() - 1, -1, -1):
		var s: Dictionary = shapes[i]
		s["t"] += k
		if s["t"] >= s["dur"]:
			shapes.remove_at(i)
	_norm.queue_redraw()
	_add.queue_redraw()


func _draw_layer(c: CanvasItem, additive: bool) -> void:
	var arr: Array = glows if additive else parts
	for p in arr:
		var a: float = clampf(p["life"] / p["max"], 0.0, 1.0)
		var col: Color = p["c"]
		var sz: float = p["s"] * (0.4 + 0.6 * a) if p.get("shrink", true) else p["s"]
		match p["k"]:
			"sq":
				c.draw_rect(Rect2(p["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, col.a * minf(1.0, a * 1.6)))
			"line":
				var v: Vector2 = p["v"]
				c.draw_line(p["p"], p["p"] - v * p.get("len", 2.0), Color(col, col.a * a), sz)
			"dot":
				c.draw_circle(p["p"], sz, Color(col, col.a * a))
			"petal":
				var ang: float = p["life"] * 0.15
				var d := Vector2.from_angle(ang) * sz
				c.draw_line(p["p"] - d, p["p"] + d, Color(col, col.a * minf(1.0, a * 2.0)), sz * 0.8)
	if not additive:
		return
	for s in shapes:
		var t: float = s["t"] / s["dur"]
		var col2: Color = s["c"]
		match s["k"]:
			"ring":
				var r: float = s["r"] * (1.0 - pow(1.0 - t, 3.0))
				c.draw_arc(s["p"], r, 0, TAU, 40, Color(col2, col2.a * (1.0 - t)), s["w"] * (1.0 - t) + 1.0)
			"flash":
				var r2: float = s["r"] * (1.0 - t * 0.6)
				c.draw_circle(s["p"], r2, Color(col2, col2.a * (1.0 - t) * 0.9))
				c.draw_circle(s["p"], r2 * 0.55, Color(1, 1, 1, (1.0 - t)))
			"ray":
				var dir := Vector2.from_angle(s["ang"])
				var L: float = s["len"] * (0.3 + 0.7 * pow(minf(1.0, t * 2.5), 0.5))
				var w: float = s["w"] * (1.0 - t)
				var base: Vector2 = s["p"] + dir * s["len"] * 0.15 * t
				var nrm := Vector2(-dir.y, dir.x)
				c.draw_colored_polygon(PackedVector2Array([base + nrm * w, base + dir * L, base - nrm * w]),
					Color(col2, col2.a * (1.0 - t * t)))
			"arc":
				var pts: PackedVector2Array = s["pts"]
				c.draw_polyline(pts, Color(col2, col2.a * (1.0 - t)), 2.0 * (1.0 - t) + 0.8)
			"slash":
				var ang0: float = s["ang"]
				var r3: float = s["r"]
				var span := 1.9
				var pts2 := PackedVector2Array()
				var cnt := 14
				for i in cnt + 1:
					var u := float(i) / cnt
					pts2.append(s["p"] + Vector2.from_angle(ang0 - span * 0.5 + span * u) * r3 * (0.85 + 0.25 * t))
				c.draw_polyline(pts2, Color(col2, col2.a * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)
			"hex":
				var pts3 := PackedVector2Array()
				var rr: float = s["r"] * (0.8 + 0.3 * t)
				for i in 7:
					pts3.append(s["p"] + Vector2(cos(i * TAU / 6.0) * rr * 0.45, sin(i * TAU / 6.0) * rr))
				c.draw_polyline(pts3, Color(col2, col2.a * (1.0 - t)), 2.0)
				c.draw_colored_polygon(pts3, Color(col2, col2.a * 0.25 * (1.0 - t)))


# ------------------------------------------------------------------ API

func particle(p: Vector2, v: Vector2, life: float, col: Color, size := 2.0, kind := "sq", glow := false,
		grav := 0.0, drag := 0.92, extra := {}) -> void:
	var d := {"p": p, "v": v, "life": life, "max": life, "c": col, "s": size, "k": kind, "grav": grav, "drag": drag}
	d.merge(extra)
	(glows if glow else parts).append(d)
	if parts.size() > 900:
		parts.pop_front()
	if glows.size() > 900:
		glows.pop_front()


func ring(p: Vector2, col: Color, r: float, dur := 14, w := 0.5) -> void:
	shapes.append({"k": "ring", "p": p, "c": col, "r": r, "dur": float(dur), "t": 0.0, "w": 6.0 * w + 2.0})


func flash(p: Vector2, col: Color, r: float, dur := 8) -> void:
	shapes.append({"k": "flash", "p": p, "c": col, "r": r, "dur": float(dur), "t": 0.0})


func burst(p: Vector2, col: Color, count := 16, speed := 3.0, glow := true) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(0.4, 1.0) * speed
		particle(p, v, randf_range(18, 34), col, randf_range(1.5, 3.0), "sq", glow, 0.02, 0.93)


func spark(p: Vector2, kind: String, level: int, dir: int, col := Color(1, 0.9, 0.5)) -> void:
	var lv := float(level)
	match kind:
		"guard":
			shapes.append({"k": "hex", "p": p, "c": Color(0.55, 0.85, 1.0, 0.9), "r": 18.0 + lv * 4.0, "dur": 12.0, "t": 0.0})
			for i in 8 + level * 4:
				var a := (PI if dir > 0 else 0.0) + randf_range(-1.1, 1.1)
				particle(p, Vector2.from_angle(a) * randf_range(1.5, 4.0), randf_range(10, 20),
					Color(0.7, 0.9, 1.0), 1.5, "line", true, 0.05, 0.9, {"len": 2.5})
			flash(p, Color(0.5, 0.8, 1.0), 10.0 + lv * 4.0, 6)
			return
		"graze":
			for i in 3:
				particle(p, Vector2(randf_range(-2, 2), randf_range(-2.5, 0.5)), randf_range(8, 16),
					Color(0.85, 0.95, 1.0), 1.0, "line", true, 0.0, 0.9, {"len": 3.0})
			return
	var base := col
	if kind == "elec":
		base = Color(0.55, 0.95, 1.0)
	elif kind == "counter":
		base = Color(1.0, 0.45, 0.3)
	flash(p, base, 12.0 + lv * 7.0, 7 + level * 2)
	var n := 5 + level * 3
	for i in n:
		var a := randf() * TAU
		if dir != 0 and randf() < 0.6:
			a = (0.0 if dir > 0 else PI) + randf_range(-0.9, 0.9)
		shapes.append({"k": "ray", "p": p, "c": Color(base, 0.95), "ang": a,
			"len": randf_range(14, 26) * (1.0 + lv * 0.45), "w": 2.2 + lv, "dur": 9.0 + lv * 2.0, "t": 0.0})
	if level >= 1:
		ring(p, Color(base, 0.9), 20.0 + lv * 14.0, 12 + level * 3, 0.3 + lv * 0.2)
	if level >= 2:
		ring(p, Color(1, 1, 1, 0.7), 40.0, 18, 0.2)
		slash(p, base, randf() * TAU, 22.0)
	for i in 6 + level * 6:
		var a2 := (0.0 if dir > 0 else PI) + randf_range(-1.3, 1.3) if dir != 0 else randf() * TAU
		particle(p, Vector2.from_angle(a2) * randf_range(2.0, 5.5) * (1.0 + lv * 0.3), randf_range(12, 26),
			base.lerp(Color.WHITE, randf() * 0.6), randf_range(1.5, 2.5), "sq", true, 0.12, 0.9)
	if kind == "elec":
		for i in 3 + level * 2:
			arc(p, p + Vector2.from_angle(randf() * TAU) * randf_range(16, 30) * (1.0 + lv * 0.4), base)


func slash(p: Vector2, col: Color, ang: float, r: float) -> void:
	shapes.append({"k": "slash", "p": p, "c": col, "ang": ang, "r": r, "dur": 10.0, "t": 0.0})


func arc(a: Vector2, b: Vector2, col: Color, dur := 8) -> void:
	var pts := PackedVector2Array()
	var n := 6
	var nrm := (b - a).orthogonal().normalized()
	for i in n + 1:
		var u := float(i) / n
		var off := 0.0 if (i == 0 or i == n) else randf_range(-5.0, 5.0)
		pts.append(a.lerp(b, u) + nrm * off)
	shapes.append({"k": "arc", "p": a, "pts": pts, "c": col, "dur": float(dur), "t": 0.0})


func pop(p: Vector2, col: Color) -> void:
	ring(p, Color(col, 0.8), 9.0, 8, 0.15)
	for i in 4:
		particle(p, Vector2.from_angle(randf() * TAU) * randf_range(0.8, 2.0), randf_range(8, 14), col, 1.5, "sq", true)


func dust(p: Vector2, scale := 1.0, facing := 1) -> void:
	var col := Color(0.62, 0.55, 0.75, 0.85)
	for i in int(6 * scale) + 2:
		var vx := randf_range(-1.6, 1.6) * scale - facing * 0.6
		particle(p + Vector2(randf_range(-6, 6), -2), Vector2(vx, randf_range(-1.4, -0.2)),
			randf_range(14, 26), col.lerp(Color(0.85, 0.8, 0.95), randf()), randf_range(2.0, 4.0) * scale, "sq",
			false, 0.02, 0.9)


func afterimage(f: Fighter, col := Color(-1, 0, 0), life := 0.28) -> void:
	var s := Sprite2D.new()
	s.texture = f.spr.texture
	s.region_enabled = true
	s.region_rect = f.spr.region_rect
	s.centered = false
	s.offset = f.spr.offset
	s.scale = f.spr.scale
	s.position = f.pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	var c := f.ghost_color if col.r < 0.0 else col
	s.modulate = c
	s.z_index = 3
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.tween_callback(s.queue_free)


func text(p: Vector2, txt: String, col: Color, scale := 1.0, font_size := 12) -> void:
	var l := Game.make_label(txt, font_size, col, Game.font_title)
	l.z_index = 60
	l.position = p - Vector2(txt.length() * font_size * 0.32, font_size)
	l.pivot_offset = Vector2(txt.length() * font_size * 0.32, font_size * 0.6)
	l.scale = Vector2(0.4, 0.4) * scale
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15) * scale, 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "scale", Vector2(1, 1) * scale, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - 14, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
