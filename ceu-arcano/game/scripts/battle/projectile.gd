class_name Projectile
extends Node2D
## Projétil genérico. A aparência e o comportamento vêm de `kind`; o resto são parâmetros de luta.

var battle: Node
var owner_f: Fighter
var kind := "firefly"
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var accel := Vector2.ZERO
var drag := 1.0
var life := 120
var age := 0
var radius := 4.0
var shape := "circle"          # circle | rect | segment
var rect := Rect2()            # relativo a pos (shape rect)
var seg_b := Vector2.ZERO      # fim do segmento (mundo); começo = pos
var thick := 4.0

var dmg := 100.0
var stun := 12
var bstun := 10
var kb := Vector2(2.0, 0.0)
var level := 0
var prorate := 0.94
var limit := 4.0
var spirit_dmg := 0.12
var guard := "mid"
var launch := false
var knockdown := false
var unblockable := false
var hits := 1
var hit_every := 8
var hit_cd := 0
var strength := 1
var grazeable := true
var clashable := true
var homing := 0.0
var homing_delay := 0
var homing_until := 9999
var max_speed := 99.0
var active_from := 0
var color := Color(1.0, 0.85, 0.35)
var color2 := Color(1.0, 1.0, 1.0)
var dead := false
var dying := 0
var grazed := false
var spin := 0.0
var size := 1.0
var data := {}
var tick_cb: Callable
var hit_cb: Callable
var trail: Array = []
var trail_len := 0
var hitstop := 0
var hit_sfx := ""
var spark := "magic"
var face := 1
var seed := 0.0

var _glow: Node2D
static var _tex_cache := {}


func _ready() -> void:
	seed = randf() * 100.0
	_glow = _GlowLayer.new()
	_glow.p = self
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.show_behind_parent = true
	add_child(_glow)
	position = pos


class _GlowLayer extends Node2D:
	var p
	func _draw() -> void:
		p._draw_glow(self)


func active() -> bool:
	return age >= active_from and not dead and dying == 0


func tick() -> void:
	age += 1
	if dying > 0:
		dying -= 1
		if dying <= 0:
			queue_free()
			dead = true
		return
	if hit_cd > 0:
		hit_cd -= 1
	if tick_cb.is_valid():
		tick_cb.call(self)
	if homing > 0.0 and age >= homing_delay and age < homing_until and owner_f and owner_f.opp:
		var to := (owner_f.opp.center() - pos)
		if to.length() > 4.0:
			var cur := vel.angle()
			var want := to.angle()
			var d := wrapf(want - cur, -PI, PI)
			var turn := clampf(d, -homing, homing)
			vel = Vector2.from_angle(cur + turn) * vel.length()
	vel += accel
	vel *= drag
	if vel.length() > max_speed:
		vel = vel.normalized() * max_speed
	pos += vel
	if trail_len > 0:
		trail.push_front(pos)
		if trail.size() > trail_len:
			trail.pop_back()
	spin += 0.15
	if age >= life:
		kill(false)
	if absf(pos.x) > 1100.0 or pos.y < -1100.0 or pos.y > 220.0:
		dead = true
		queue_free()


func kill(pop := true) -> void:
	if dying > 0 or dead:
		return
	dying = 8
	if pop and battle:
		battle.fx.pop(pos, color)


func world_rect() -> Rect2:
	match shape:
		"rect":
			return Rect2(pos + rect.position, rect.size)
		"segment":
			var a := pos
			var b := seg_b
			return Rect2(a.min(b) - Vector2(thick, thick), (a - b).abs() + Vector2(thick, thick) * 2.0)
	return Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func overlaps_rect(r: Rect2) -> bool:
	match shape:
		"rect":
			return world_rect().intersects(r)
		"segment":
			var n := int(ceil(pos.distance_to(seg_b) / maxf(thick, 2.0))) + 1
			for i in n + 1:
				var p := pos.lerp(seg_b, float(i) / float(n))
				if _circle_rect(p, thick, r):
					return true
			return false
	return _circle_rect(pos, radius, r)


static func _circle_rect(c: Vector2, rad: float, r: Rect2) -> bool:
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return q.distance_squared_to(c) <= rad * rad


func overlaps_proj(o: Projectile) -> bool:
	if shape == "circle" and o.shape == "circle":
		var rr := radius + o.radius
		return pos.distance_squared_to(o.pos) <= rr * rr
	if shape == "circle":
		return o.overlaps_rect(Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	if o.shape == "circle":
		return overlaps_rect(Rect2(o.pos - Vector2(o.radius, o.radius), Vector2(o.radius, o.radius) * 2.0))
	return world_rect().intersects(o.world_rect())


func as_move() -> Dictionary:
	return {"type": "bullet", "dmg": dmg, "stun": stun, "bstun": bstun, "kb": kb, "level": level,
			"prorate": prorate, "limit": limit, "spirit_dmg": spirit_dmg, "guard": guard,
			"launch": launch, "knockdown": knockdown, "push": 1.6 + kb.x * 0.3, "unblockable": unblockable,
			"hitstop": hitstop, "spark": spark, "hit_sfx": hit_sfx}


# ------------------------------------------------------------------ desenho

func _process(_d: float) -> void:
	position = pos
	queue_redraw()
	_glow.queue_redraw()


func _alpha() -> float:
	if dying > 0:
		return float(dying) / 8.0
	if age < active_from:
		return 0.6
	return 1.0


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _draw() -> void:
	var a := _alpha()
	var t := float(age) + seed
	match kind:
		"firefly", "orb", "spore":
			_draw_trail(color, radius * 0.9, a * 0.8)
			var pulse := 1.0 + 0.12 * sin(t * 0.6)
			draw_circle(Vector2.ZERO, radius * 1.15 * pulse, Color(color, a))
			draw_circle(Vector2.ZERO, radius * 0.62 * pulse, Color(color2, a))
		"star":
			var tex := _tex("res://assets/vfx/star_spin.png")
			if tex:
				var fw := tex.get_width() / 16.0
				var idx := int(age / 2) % 16
				draw_texture_rect_region(tex, Rect2(-fw * 0.5 * size, -fw * 0.5 * size, fw * size, fw * size),
					Rect2(idx * fw, 0, fw, tex.get_height()), Color(1, 1, 1, a))
			else:
				_draw_star(Vector2.ZERO, radius * 1.6, radius * 0.7, spin, Color(color, a))
				_draw_star(Vector2.ZERO, radius * 0.9, radius * 0.4, spin, Color(color2, a))
		"comet":
			_draw_trail(color, radius * 1.1, a)
			draw_circle(Vector2.ZERO, radius * 1.2, Color(color, a))
			draw_circle(Vector2.ZERO, radius * 0.75, Color(color2, a))
		"moth":
			var flap := absf(sin(t * 0.45))
			var ang := vel.angle()
			var fwd := Vector2.from_angle(ang)
			var side := Vector2(-fwd.y, fwd.x)
			var c1 := Color(color, a)
			var c2 := Color(color2, a)
			for s in [-1.0, 1.0]:
				var wing := PackedVector2Array([
					Vector2.ZERO, side * s * 7.0 * (0.35 + flap) + fwd * 3.0,
					side * s * 9.0 * (0.35 + flap) - fwd * 2.0, side * s * 3.0 - fwd * 4.0])
				draw_colored_polygon(wing, c1)
				draw_line(Vector2.ZERO, side * s * 6.0 * (0.35 + flap), c2, 1.0)
			draw_line(-fwd * 3.0, fwd * 3.0, Color(1, 1, 1, a), 2.0)
		"lantern":
			var tex2 := _tex("res://assets/vfx/lantern_spin.png")
			var bob := sin(t * 0.08) * 2.0
			if tex2:
				var fw2 := tex2.get_width() / 16.0
				var idx2 := int(age / 3) % 16
				draw_texture_rect_region(tex2, Rect2(-fw2 * 0.5, -tex2.get_height() * 0.5 + bob, fw2, tex2.get_height()),
					Rect2(idx2 * fw2, 0, fw2, tex2.get_height()), Color(1, 1, 1, a))
			else:
				draw_rect(Rect2(-5, -7 + bob, 10, 14), Color(1.0, 0.85, 0.4, a))
				draw_rect(Rect2(-6, -9 + bob, 12, 3), Color(0.9, 0.6, 0.2, a))
				draw_rect(Rect2(-6, 6 + bob, 12, 3), Color(0.9, 0.6, 0.2, a))
		"spark":
			var dir := vel.normalized() if vel.length() > 0.1 else Vector2(face, 0)
			var nrm := Vector2(-dir.y, dir.x)
			var pts := PackedVector2Array()
			var L := 18.0 * size
			var rng := RandomNumberGenerator.new()
			rng.seed = int(age / 2) * 977 + int(seed * 100.0)
			for i in 7:
				var u := float(i) / 6.0
				pts.append(dir * (L * 0.5 - u * L) + nrm * rng.randf_range(-3.5, 3.5) * (1.0 - absf(u - 0.5)))
			draw_polyline(pts, Color(color, a), 3.0)
			draw_polyline(pts, Color(color2, a), 1.2)
			draw_circle(dir * L * 0.5, 3.0 * size, Color(color2, a))
		"eorb":
			var rr := radius
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = int(age / 2) * 131 + int(seed * 10.0)
			draw_circle(Vector2.ZERO, rr * 0.8, Color(color, a * 0.85))
			draw_circle(Vector2.ZERO, rr * 0.45, Color(color2, a))
			for i in 4:
				var ang0 := rng2.randf() * TAU
				var p0 := Vector2.from_angle(ang0) * rr * 0.4
				var arc := PackedVector2Array([p0])
				for k in 3:
					p0 += Vector2.from_angle(ang0 + rng2.randf_range(-0.9, 0.9)) * rr * 0.35
					arc.append(p0)
				draw_polyline(arc, Color(color2, a), 1.5)
		"bolt":
			_draw_bolt(a)
		"laser":
			var b := seg_b - pos
			var w := thick * (0.6 + 0.4 * sin(t * 0.8))
			if age < active_from:
				draw_line(Vector2.ZERO, b, Color(color, 0.5), 1.0)
			else:
				draw_line(Vector2.ZERO, b, Color(color, a), w * 1.4)
				draw_line(Vector2.ZERO, b, Color(color2, a), w * 0.6)
		"beam":
			pass
		"burst":
			var k := clampf(float(age) / float(maxi(1, life)), 0.0, 1.0)
			draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * k), 0, TAU, 32, Color(color, (1.0 - k) * a), 4.0 * (1.0 - k) + 1.0)
		"marker":
			var k2 := float(age % 20) / 20.0
			draw_arc(Vector2.ZERO, 10.0 + 8.0 * k2, 0, TAU, 24, Color(color, 1.0 - k2), 1.5)


func _draw_glow(c: CanvasItem) -> void:
	var a := _alpha()
	var t := float(age) + seed
	match kind:
		"firefly", "orb", "spore", "star":
			var g := radius * (2.6 + 0.4 * sin(t * 0.3))
			c.draw_circle(Vector2.ZERO, g, Color(color, 0.16 * a))
			c.draw_circle(Vector2.ZERO, g * 0.6, Color(color, 0.22 * a))
		"comet":
			c.draw_circle(Vector2.ZERO, radius * 3.2, Color(color, 0.18 * a))
			c.draw_circle(Vector2.ZERO, radius * 1.9, Color(color, 0.3 * a))
		"moth":
			c.draw_circle(Vector2.ZERO, 10.0, Color(color, 0.18 * a))
		"lantern":
			var fl := 0.8 + 0.2 * sin(t * 0.37) * sin(t * 0.13)
			c.draw_circle(Vector2.ZERO, 26.0 * fl, Color(1.0, 0.7, 0.3, 0.12 * a))
			c.draw_circle(Vector2.ZERO, 14.0 * fl, Color(1.0, 0.8, 0.4, 0.22 * a))
		"spark":
			c.draw_circle(Vector2.ZERO, 12.0 * size, Color(color, 0.2 * a))
		"eorb":
			c.draw_circle(Vector2.ZERO, radius * 2.4, Color(color, 0.2 * a))
			c.draw_circle(Vector2.ZERO, radius * 1.4, Color(color, 0.25 * a))
		"laser":
			if age >= active_from:
				c.draw_line(Vector2.ZERO, seg_b - pos, Color(color, 0.25 * a), thick * 5.0)
		"bolt":
			if age >= active_from:
				var top := Vector2(0, -pos.y - 700.0)
				c.draw_line(top, Vector2.ZERO, Color(color, 0.18 * a), 40.0 * size)
				c.draw_circle(Vector2.ZERO, 40.0 * size, Color(color, 0.25 * a))


func _draw_trail(col: Color, w: float, a: float) -> void:
	var n := trail.size()
	if n < 2:
		return
	for i in n - 1:
		var k := 1.0 - float(i) / float(n)
		draw_line(trail[i] - pos, trail[i + 1] - pos, Color(col, a * k * 0.8), maxf(1.0, w * 2.0 * k))


func _draw_star(c: Vector2, r1: float, r2: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := r1 if i % 2 == 0 else r2
		pts.append(c + Vector2.from_angle(rot - PI / 2 + i * PI / 5) * r)
	draw_colored_polygon(pts, col)


func _draw_bolt(a: float) -> void:
	var top_y := -pos.y - 700.0
	if age < active_from:
		# aviso: linha fina + círculo pulsando no chão
		var k := float(age) / float(maxi(1, active_from))
		draw_line(Vector2(0, top_y), Vector2.ZERO, Color(color, 0.25 + 0.3 * k), 1.0 + k * 2.0)
		draw_arc(Vector2.ZERO, 24.0 * size * (1.2 - k * 0.4), 0, TAU, 28, Color(color, 0.7), 2.0)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(age / 2) * 7919 + int(seed * 1000.0)
	var pts := PackedVector2Array()
	var y := top_y
	var x := 0.0
	while y < 0.0:
		pts.append(Vector2(x, y))
		y += rng.randf_range(18.0, 34.0)
		x = clampf(x + rng.randf_range(-12.0, 12.0) * size, -18.0 * size, 18.0 * size)
	pts.append(Vector2.ZERO)
	var w := (10.0 * size) * (1.0 - clampf(float(age - active_from) / float(maxi(1, life - active_from)), 0.0, 0.8))
	draw_polyline(pts, Color(color, a), w + 4.0)
	draw_polyline(pts, Color(color2, a), maxf(1.5, w * 0.45))
	# galhos
	for i in range(2, pts.size() - 2, 3):
		var p0: Vector2 = pts[i]
		var br := PackedVector2Array([p0])
		var dirx := -1.0 if rng.randf() < 0.5 else 1.0
		for k in 3:
			p0 += Vector2(dirx * rng.randf_range(6.0, 14.0), rng.randf_range(8.0, 16.0))
			br.append(p0)
		draw_polyline(br, Color(color, a * 0.8), 1.5)
	draw_circle(Vector2.ZERO, 14.0 * size, Color(color2, a * 0.8))
