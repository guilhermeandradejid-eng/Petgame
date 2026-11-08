class_name Icon
extends Control
## Ícones vetoriais da identidade FÚRIA (desenhados, sem imagem): medidores, abas, compras e equipamentos.
## Uso: Icon.make("spd", 28, UI.TEXT) ou Icon.paint(canvas, "lock", rect, cor).

var icon := ""
var color := Color.WHITE


static func make(nm: String, sz: float, col: Color) -> Icon:
	var ic := Icon.new()
	ic.icon = nm
	ic.color = col
	ic.custom_minimum_size = Vector2(sz, sz)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func set_icon(nm: String, col := Color(-1, 0, 0)) -> void:
	icon = nm
	if col.r >= 0.0:
		color = col
	queue_redraw()


func _draw() -> void:
	paint(self, icon, Rect2(Vector2.ZERO, size), color)


static func _arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	ci.draw_arc(c, r, a0, a1, 24, col, w, true)


## desenha o ícone 'nm' dentro de 'rc'
static func paint(ci: CanvasItem, nm: String, rc: Rect2, col: Color) -> void:
	var s := minf(rc.size.x, rc.size.y)
	var c := rc.get_center()
	var u := s / 24.0   # grade de 24 unidades
	var w := maxf(1.5, 2.2 * u)
	match nm:
		"spd":   # velocímetro
			_arc(ci, c + Vector2(0, 2 * u), 9 * u, PI * 0.9, PI * 2.1, col, w)
			ci.draw_line(c + Vector2(0, 2 * u), c + Vector2(6 * u, -4 * u), col, w * 1.1, true)
			ci.draw_circle(c + Vector2(0, 2 * u), 2.2 * u, col)
		"acc":   # setas duplas
			for k in 2:
				var x := -6 * u + k * 7 * u
				ci.draw_polyline(PackedVector2Array([c + Vector2(x, -7 * u), c + Vector2(x + 6 * u, 0), c + Vector2(x, 7 * u)]), col, w * 1.2, true)
		"han":   # volante
			_arc(ci, c, 9 * u, 0, TAU, col, w)
			ci.draw_circle(c, 2.6 * u, col)
			for a in [PI * 0.5, PI * 1.15, PI * 1.85]:
				ci.draw_line(c, c + Vector2(cos(a), -sin(a)) * 8.5 * u, col, w, true)
		"arm":   # escudo
			var pts := PackedVector2Array([c + Vector2(0, -10 * u), c + Vector2(8 * u, -7 * u), c + Vector2(7 * u, 3 * u), c + Vector2(0, 10 * u),
				c + Vector2(-7 * u, 3 * u), c + Vector2(-8 * u, -7 * u)])
			ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, col.a * 0.25))
			pts.append(pts[0])
			ci.draw_polyline(pts, col, w, true)
			ci.draw_line(c + Vector2(0, -6 * u), c + Vector2(0, 6 * u), col, w, true)
		"atk", "wpn":   # mira
			_arc(ci, c, 7.5 * u, 0, TAU, col, w)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * 4 * u, c + d * 11 * u, col, w, true)
			ci.draw_circle(c, 1.6 * u, col)
		"coin":
			ci.draw_circle(c, 9 * u, col)
			ci.draw_circle(c, 6.5 * u, col.darkened(0.25))
			ci.draw_string(UI.display, c + Vector2(-3.2 * u, 4.2 * u), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), col.lightened(0.4))
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-7 * u, -1 * u), Vector2(14 * u, 11 * u)), col)
			_arc(ci, c + Vector2(0, -2 * u), 5 * u, PI, TAU, col, w * 1.1)
			ci.draw_line(c + Vector2(-5 * u, -2 * u), c + Vector2(-5 * u, 0), col, w * 1.1)
			ci.draw_line(c + Vector2(5 * u, -2 * u), c + Vector2(5 * u, 0), col, w * 1.1)
			ci.draw_circle(c + Vector2(0, 4 * u), 1.8 * u, Color(0, 0, 0, 0.6))
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-8 * u, 0), c + Vector2(-2 * u, 6 * u), c + Vector2(9 * u, -7 * u)]), col, w * 1.5, true)
		"wrench", "repair":
			ci.draw_line(c + Vector2(-7 * u, 7 * u), c + Vector2(3 * u, -3 * u), col, w * 1.8, true)
			_arc(ci, c + Vector2(5 * u, -5 * u), 4.5 * u, -PI * 0.25, PI * 1.25, col, w * 1.3)
		"paint":   # gota de tinta
			var pts2 := PackedVector2Array()
			for i in 17:
				var a := PI * (0.0 + i / 16.0)
				pts2.append(c + Vector2(cos(a) * 7 * u, 3 * u + sin(a) * 7 * u))
			pts2.append(c + Vector2(0, -10 * u))
			ci.draw_colored_polygon(pts2, col)
		"shield":
			paint(ci, "arm", rc, col)
		"shock":   # ondas concêntricas
			ci.draw_circle(c, 2.5 * u, col)
			_arc(ci, c, 6 * u, 0, TAU, col, w)
			_arc(ci, c, 10 * u, 0.3, PI - 0.3, Color(col, col.a * 0.6), w)
			_arc(ci, c, 10 * u, PI + 0.3, TAU - 0.3, Color(col, col.a * 0.6), w)
		"nitro", "short", "long":   # garrafa
			ci.draw_rect(Rect2(c + Vector2(-4 * u, -5 * u), Vector2(8 * u, 15 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-2 * u, -9 * u), Vector2(4 * u, 4 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-4 * u, 0), Vector2(8 * u, 3 * u)), col.darkened(0.45))
		"jump", "glide":   # arco para cima
			_arc(ci, c + Vector2(0, 6 * u), 8 * u, PI, TAU, col, w * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(8 * u, 9 * u), c + Vector2(5 * u, 2 * u), c + Vector2(11 * u, 3 * u)]), col)
		"ram":   # punho / impacto
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9 * u, -4 * u), c + Vector2(2 * u, -4 * u), c + Vector2(2 * u, -8 * u),
				c + Vector2(10 * u, 0), c + Vector2(2 * u, 8 * u), c + Vector2(2 * u, 4 * u), c + Vector2(-9 * u, 4 * u)]), col)
		"dash":   # seta lateral com rastro
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2 * u, -7 * u), c + Vector2(10 * u, 0), c + Vector2(2 * u, 7 * u)]), col)
			for k in 3:
				ci.draw_line(c + Vector2(-9 * u + k * 2 * u, -4 * u + k * 4 * u), c + Vector2(1 * u, -4 * u + k * 4 * u), col, w, true)
		"rear", "mine", "oil", "spikes", "barrel", "smoke", "mud", "fire", "ice", "emp", "vortex":   # item de chão: triângulo de perigo
			var tri := PackedVector2Array([c + Vector2(0, -9 * u), c + Vector2(10 * u, 8 * u), c + Vector2(-10 * u, 8 * u)])
			ci.draw_colored_polygon(tri, col)
			ci.draw_line(c + Vector2(0, -3 * u), c + Vector2(0, 3 * u), Color(0, 0, 0, 0.75), w * 1.1)
			ci.draw_circle(c + Vector2(0, 5.6 * u), 1.3 * u, Color(0, 0, 0, 0.75))
		"engine":   # pistão
			ci.draw_rect(Rect2(c + Vector2(-6 * u, -9 * u), Vector2(12 * u, 9 * u)), col)
			for k in 3:
				ci.draw_line(c + Vector2(-6 * u, -6.5 * u + k * 2.5 * u), c + Vector2(6 * u, -6.5 * u + k * 2.5 * u), col.darkened(0.5), u)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(3 * u, 9 * u), col, w * 1.4, true)
		"tires":
			_arc(ci, c, 8.5 * u, 0, TAU, col, w * 1.8)
			_arc(ci, c, 3.5 * u, 0, TAU, col, w)
		"ammo":   # balas
			for k in 3:
				var x := -6 * u + k * 6 * u
				ci.draw_rect(Rect2(c + Vector2(x - 2 * u, -2 * u), Vector2(4 * u, 10 * u)), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 2 * u, -2 * u), c + Vector2(x + 2 * u, -2 * u), c + Vector2(x, -8 * u)]), col)
		"dmg":   # explosão
			var star := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				var r: float = (10.0 if i % 2 == 0 else 4.5) * u
				star.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(star, col)
		"rate":   # raio
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2 * u, -10 * u), c + Vector2(-6 * u, 1 * u), c + Vector2(-1 * u, 1 * u),
				c + Vector2(-3 * u, 10 * u), c + Vector2(6 * u, -2 * u), c + Vector2(1 * u, -2 * u)]), col)
		"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(4 * u, -8 * u), c + Vector2(-4 * u, 0), c + Vector2(4 * u, 8 * u)]), col, w * 1.6, true)
		"star":
			var st := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * i / 10.0
				var r: float = (10.0 if i % 2 == 0 else 4.2) * u
				st.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(st, col)
		"flag":   # bandeira xadrez
			ci.draw_line(c + Vector2(-8 * u, -10 * u), c + Vector2(-8 * u, 10 * u), col, w)
			for i in 4:
				for j in 3:
					if (i + j) % 2 == 0:
						ci.draw_rect(Rect2(c + Vector2(-7 * u + i * 4 * u, -9 * u + j * 4 * u), Vector2(4 * u, 4 * u)), col)
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7 * u, -9 * u), c + Vector2(7 * u, -9 * u), c + Vector2(5 * u, 0), c + Vector2(-5 * u, 0)]), col)
			ci.draw_rect(Rect2(c + Vector2(-1.5 * u, 0), Vector2(3 * u, 6 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(-6 * u, 6 * u), Vector2(12 * u, 3 * u)), col)
			_arc(ci, c + Vector2(-7 * u, -5 * u), 3 * u, PI * 0.5, PI * 1.5, col, w)
			_arc(ci, c + Vector2(7 * u, -5 * u), 3 * u, -PI * 0.5, PI * 0.5, col, w)
		"skull":   # chefe
			ci.draw_circle(c + Vector2(0, -2 * u), 8 * u, col)
			ci.draw_rect(Rect2(c + Vector2(-5 * u, 3 * u), Vector2(10 * u, 6 * u)), col)
			ci.draw_circle(c + Vector2(-3.2 * u, -2 * u), 2.4 * u, Color(0, 0, 0, 0.8))
			ci.draw_circle(c + Vector2(3.2 * u, -2 * u), 2.4 * u, Color(0, 0, 0, 0.8))
			for k in 3:
				ci.draw_line(c + Vector2(-3 * u + k * 3 * u, 5 * u), c + Vector2(-3 * u + k * 3 * u, 9 * u), Color(0, 0, 0, 0.8), u)
		"loop":
			_arc(ci, c + Vector2(0, -1 * u), 7 * u, PI * 0.6, PI * 2.4, col, w * 1.2)
			ci.draw_line(c + Vector2(-10 * u, 8 * u), c + Vector2(10 * u, 8 * u), col, w * 1.2)
		"helix":
			for k in 3:
				_arc(ci, c + Vector2(0, -6 * u + k * 6 * u), 7 * u, PI * 0.15, PI * 0.85, col, w)
		"cork":
			_arc(ci, c, 8 * u, 0.2, PI * 1.8, col, w * 1.2)
			ci.draw_line(c + Vector2(-10 * u, 0), c + Vector2(10 * u, 0), col, w)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6 * u, -9 * u), c + Vector2(9 * u, 0), c + Vector2(-6 * u, 9 * u)]), col)
		"gear":
			_arc(ci, c, 6 * u, 0, TAU, col, w * 1.6)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 7 * u, c + Vector2(cos(a), sin(a)) * 10.5 * u, col, w * 1.8)
		"people":
			ci.draw_circle(c + Vector2(-4 * u, -4 * u), 3.5 * u, col)
			ci.draw_circle(c + Vector2(5 * u, -3 * u), 3 * u, col)
			ci.draw_rect(Rect2(c + Vector2(-9 * u, 1 * u), Vector2(10 * u, 8 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(1 * u, 2 * u), Vector2(8 * u, 7 * u)), col)
		"globe":
			_arc(ci, c, 9 * u, 0, TAU, col, w)
			ci.draw_line(c + Vector2(-9 * u, 0), c + Vector2(9 * u, 0), col, w * 0.8)
			ci.draw_arc(c, 9 * u, -PI * 0.5, PI * 0.5, 16, col, w * 0.8)
			var pts3 := PackedVector2Array()
			for i in 13:
				var a := -PI * 0.5 + PI * i / 12.0
				pts3.append(c + Vector2(cos(a) * 4 * u, sin(a) * 9 * u))
			ci.draw_polyline(pts3, col, w * 0.8, true)
			for i in 13:
				pts3[i] = c + Vector2(-cos(-PI * 0.5 + PI * i / 12.0) * 4 * u, sin(-PI * 0.5 + PI * i / 12.0) * 9 * u)
			ci.draw_polyline(pts3, col, w * 0.8, true)
		"exit":
			ci.draw_rect(Rect2(c + Vector2(-8 * u, -9 * u), Vector2(9 * u, 18 * u)), col, false, w)
			ci.draw_line(c + Vector2(-2 * u, 0), c + Vector2(9 * u, 0), col, w * 1.2)
			ci.draw_polyline(PackedVector2Array([c + Vector2(5 * u, -4 * u), c + Vector2(9 * u, 0), c + Vector2(5 * u, 4 * u)]), col, w * 1.2)
		"brake":   # disco de freio com pinça
			_arc(ci, c, 8.5 * u, 0, TAU, col, w * 1.3)
			ci.draw_circle(c, 3 * u, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(3 * u, -11 * u), c + Vector2(11 * u, -6 * u), c + Vector2(8 * u, -1 * u), c + Vector2(1 * u, -6 * u)]), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-7 * u, -8 * u), Vector2(5 * u, 16 * u)), col)
			ci.draw_rect(Rect2(c + Vector2(2 * u, -8 * u), Vector2(5 * u, 16 * u)), col)
		"sound", "mute":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9 * u, -3 * u), c + Vector2(-5 * u, -3 * u), c + Vector2(1 * u, -8 * u),
				c + Vector2(1 * u, 8 * u), c + Vector2(-5 * u, 3 * u), c + Vector2(-9 * u, 3 * u)]), col)
			if nm == "sound":
				_arc(ci, c + Vector2(1 * u, 0), 5 * u, -0.9, 0.9, col, w)
				_arc(ci, c + Vector2(1 * u, 0), 9 * u, -0.9, 0.9, col, w)
			else:
				ci.draw_line(c + Vector2(4 * u, -5 * u), c + Vector2(11 * u, 5 * u), col, w)
				ci.draw_line(c + Vector2(4 * u, 5 * u), c + Vector2(11 * u, -5 * u), col, w)
		"clock":
			_arc(ci, c, 9 * u, 0, TAU, col, w)
			ci.draw_line(c, c + Vector2(0, -6 * u), col, w, true)
			ci.draw_line(c, c + Vector2(4.5 * u, 2 * u), col, w, true)
		_:
			ci.draw_circle(c, 4 * u, col)
