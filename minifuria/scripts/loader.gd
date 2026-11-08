class_name Loader
extends Control
## Tela de carregamento da identidade FÚRIA: um carrinho andando numa estrada (rodas girando, suspensão
## quicando, fumaça do escapamento e linhas de velocidade), barra inclinada de progresso que o carrinho
## percorre e dicas. Usada ao abrir o jogo (cena boot) e ao carregar cada pista.

const TIPS := [
	"Cada volta recarrega munição e nitro.",
	"Placas de turbo laranja dão um tranco de velocidade.",
	"Manobras (drift, pulos, quase-batidas) enchem o medidor de nitro extra.",
	"Pneus slick: +12% de aderência em relação aos de rua.",
	"Foguetes perseguem quem está na frente: dá para fugir com nitro.",
	"Mina atrás de você + rival colado = destruição.",
	"No online, a voz fica mais alta quando os carros estão perto.",
	"Até 4 pessoas na mesma tela: cada uma com seu controle ou metade do teclado.",
	"Preso na mureta? Aperte R (ou BACK no controle) para voltar à pista.",
]

var progress := 0.0
var shown := 0.0
var t := 0.0
var title := "MINI FÚRIA"
var sub := "CARREGANDO"
var tip := ""
var puffs: Array = []
var _fade_tw: Tween
var car_tex: Texture2D = preload("res://ui/load_car.png")
var wheel_tex: Texture2D = preload("res://ui/load_wheel.png")
## posição das rodas no sprite (px do sprite 900x420) e tamanho da roda — gerado por tools/render_sprites.gd
const WHEELS := [Vector2(620.2, 217.2), Vector2(279.8, 211.4)]
const WHEEL_PX := 152.1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	UI.load_fonts()
	tip = TIPS[randi() % TIPS.size()]


func show_for(name_: String, sub_ := "CARREGANDO PISTA") -> void:
	title = name_
	sub = sub_
	progress = 0.0
	shown = 0.0
	tip = TIPS[randi() % TIPS.size()]
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	modulate.a = 1.0
	visible = true
	queue_redraw()


func finish() -> void:
	progress = 1.0
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_interval(0.15)
	_fade_tw.tween_property(self, "modulate:a", 0.0, 0.35)
	_fade_tw.tween_callback(func(): visible = false)


func _process(dt: float) -> void:
	if not visible:
		return
	t += minf(dt, 0.05)
	shown = move_toward(shown, progress, dt * 1.6)
	# fumaça do escapamento
	if randf() < dt * 14.0:
		puffs.append({"p": Vector2(-62, -18), "v": Vector2(randf_range(-80, -40), randf_range(-26, -8)), "t": 0.0, "r": randf_range(5, 9)})
	for i in range(puffs.size() - 1, -1, -1):
		var p: Dictionary = puffs[i]
		p.t += dt
		p.p += p.v * dt
		if p.t > 0.9:
			puffs.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), UI.INK)
	# brilho âmbar e linhas de velocidade
	for i in 26:
		var y := fmod(i * 37.0, vs.y)
		var spd := 300.0 + fmod(i * 131.0, 500.0)
		var len := 60.0 + fmod(i * 53.0, 180.0)
		var x := vs.x - fmod(t * spd + i * 211.0, vs.x + len * 2.0) + len
		draw_line(Vector2(x, y), Vector2(x + len, y), Color(1, 1, 1, 0.05 + 0.04 * (i % 3)), 2.0)
	var cy := vs.y * 0.56
	# estrada (perspectiva lateral): faixa escura com zebra e tracejado correndo
	var road := Rect2(0, cy + 6, vs.x, 54)
	draw_rect(road, Color("#25222f"))
	var cell := 24.0
	var off := fmod(t * 520.0, cell * 2.0)
	for i in int(vs.x / cell) + 3:
		var x := i * cell - off
		draw_rect(Rect2(x, cy + 2, cell, 6), Color("#e8352b") if i % 2 == 0 else Color.WHITE)
		draw_rect(Rect2(x, cy + 58, cell, 5), Color("#e8352b") if i % 2 == 0 else Color.WHITE)
	var dash := fmod(t * 520.0, 90.0)
	for i in int(vs.x / 90.0) + 2:
		draw_rect(Rect2(i * 90.0 - dash, cy + 31, 46, 4), Color(1, 1, 1, 0.75))
	# carrinho (lado), quicando de leve
	var bounce := sin(t * 18.0) * 1.6 + sin(t * 7.0) * 0.8
	var cp := Vector2(vs.x * 0.5 + sin(t * 1.3) * 40.0, cy + 8)
	for p in puffs:
		var a: float = 1.0 - float(p.t) / 0.9
		draw_circle(cp + (p.p as Vector2) * 1.6 + Vector2(-90, 10), float(p.r) * 1.6 * (1.0 + float(p.t) * 1.6), Color(0.75, 0.73, 0.8, 0.35 * a))
	_draw_car(cp, bounce)
	# título e progresso (barra inclinada que o carrinho "percorre")
	var f: Font = UI.display_it
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	draw_string_outline(f, Vector2((vs.x - tw) * 0.5, vs.y * 0.3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 10, UI.INK)
	draw_string(f, Vector2((vs.x - tw) * 0.5, vs.y * 0.3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UI.HOT)
	var bw := minf(520.0, vs.x * 0.7)
	var bx := (vs.x - bw) * 0.5
	var by := vs.y * 0.78
	var sk := 10.0
	draw_colored_polygon(PackedVector2Array([Vector2(bx + sk, by), Vector2(bx + bw + sk, by), Vector2(bx + bw, by + 14), Vector2(bx, by + 14)]), Color(1, 1, 1, 0.1))
	var fw := bw * clampf(shown, 0.0, 1.0)
	if fw > 2.0:
		draw_colored_polygon(PackedVector2Array([Vector2(bx + sk, by), Vector2(bx + fw + sk, by), Vector2(bx + fw, by + 14), Vector2(bx, by + 14)]), UI.HOT)
	var s2 := "%s  %d%%" % [sub, int(shown * 100.0)]
	var sw := f.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2((vs.x - sw) * 0.5, by - 12), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.TEXT)
	var bf: Font = UI.body_it
	var tw2 := bf.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(bf, Vector2((vs.x - tw2) * 0.5, by + 50), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.MUTED)


## carro de verdade do jogo (sprite renderizado do modelo 3D) com as rodas girando por cima
func _draw_car(c: Vector2, bounce: float) -> void:
	var k := 0.42   # escala do sprite (900 px -> ~380 px)
	var org := c + Vector2(-450.0, -250.0) * k
	draw_colored_polygon(_ellipse(c + Vector2(0, 12), 170, 9), Color(0, 0, 0, 0.45))
	draw_texture_rect(car_tex, Rect2(org + Vector2(0, -bounce), Vector2(900, 420) * k), false)
	for wp in WHEELS:
		var wc: Vector2 = org + (wp as Vector2) * k
		var r := WHEEL_PX * k
		draw_set_transform(wc, t * 14.0, Vector2.ONE)
		draw_texture_rect(wheel_tex, Rect2(-r * 0.5, -r * 0.5, r, r), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_car_old(c: Vector2) -> void:
	var car_col := UI.HOT2
	var body := car_col
	# sombra
	draw_colored_polygon(_ellipse(c + Vector2(0, 26), 70, 6), Color(0, 0, 0, 0.35))
	# carroceria em cunha (frente para a direita)
	var pts := PackedVector2Array([c + Vector2(-66, 6), c + Vector2(-68, -14), c + Vector2(-50, -20), c + Vector2(-22, -22),
		c + Vector2(-8, -38), c + Vector2(26, -38), c + Vector2(44, -22), c + Vector2(70, -14), c + Vector2(74, 2), c + Vector2(66, 10), c + Vector2(-60, 10)])
	draw_colored_polygon(pts, body)
	draw_polyline(pts + PackedVector2Array([pts[0]]), UI.INK, 3.0, true)
	# vidro e faixa
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -34), c + Vector2(22, -34), c + Vector2(36, -22), c + Vector2(-16, -22)]), Color("#1c2a3a"))
	draw_line(c + Vector2(8, -34), c + Vector2(4, -22), Color(1, 1, 1, 0.35), 3.0)
	draw_line(c + Vector2(-60, -6), c + Vector2(66, -6), Color(1, 1, 1, 0.85), 4.0)
	# aerofólio e farol
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -26), c + Vector2(-44, -26), c + Vector2(-48, -20), c + Vector2(-68, -20)]), UI.INK)
	draw_circle(c + Vector2(70, -8), 4.0, Color("#fff3c4"))
	# rodas girando
	for wx in [-40.0, 44.0]:
		var wc := c + Vector2(wx, 12)
		draw_circle(wc, 15.0, Color("#16151c"))
		draw_circle(wc, 8.5, Color("#c9ccd4"))
		for k in 5:
			var a := -t * 22.0 + k * TAU / 5.0
			draw_line(wc, wc + Vector2(cos(a), sin(a)) * 8.0, Color("#4a4d57"), 2.5)
		draw_circle(wc, 2.5, Color.WHITE)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out
