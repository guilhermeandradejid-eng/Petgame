extends CanvasLayer
## Interface da luta, desenhada à mão: vida, espírito, cartas, combo, timer, anúncios e faixas de feitiço.

var battle
var view: Control
var t := 0.0
var shake := [0.0, 0.0]
var combo := [{"hits": 0, "dmg": 0.0, "t": 0.0, "pop": 0.0}, {"hits": 0, "dmg": 0.0, "t": 0.0, "pop": 0.0}]
var card_pop := [[], []]           # animação por slot
var card_fly := []                 # cartas voando até a mão
var used_fly := []
var banners := ["", ""]
var banner_t := [0.0, 0.0]
var ann_text := ""
var ann_color := Color.WHITE
var ann_t := 99.0
var ann_dur := 1.0
var ann_big := false
var orb_flash := [0.0, 0.0]
var graze_t := [0.0, 0.0]
var graze_n := [0, 0]
var last_spirit := [5.0, 5.0]
var wins_pop := [0.0, 0.0]


func _ready() -> void:
	layer = 20
	view = _View.new()
	view.hud = self
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	for p in 2:
		card_pop[p] = [0.0, 0.0, 0.0, 0.0]


class _View extends Control:
	var hud
	func _draw() -> void:
		hud._draw_all(self)


func _process(delta: float) -> void:
	t += delta
	ann_t += delta
	for p in 2:
		shake[p] = maxf(0.0, shake[p] - delta * 3.0)
		combo[p]["t"] += delta
		combo[p]["pop"] = maxf(0.0, combo[p]["pop"] - delta * 5.0)
		banner_t[p] += delta
		orb_flash[p] = maxf(0.0, orb_flash[p] - delta * 2.0)
		graze_t[p] += delta
		wins_pop[p] = maxf(0.0, wins_pop[p] - delta * 2.0)
		for i in 4:
			card_pop[p][i] = maxf(0.0, card_pop[p][i] - delta * 3.0)
		var f: Fighter = battle.fighters[p]
		if f.spirit >= 4.99 and last_spirit[p] < 4.99:
			orb_flash[p] = 1.0
		last_spirit[p] = f.spirit
		if f.combo_hits == 0 and combo[1 - p]["hits"] > 0 and combo[1 - p]["t"] > 1.4:
			combo[1 - p]["hits"] = 0
	for i in range(card_fly.size() - 1, -1, -1):
		card_fly[i]["t"] += delta * 2.6
		if card_fly[i]["t"] >= 1.0:
			card_pop[card_fly[i]["p"]][mini(3, card_fly[i]["slot"])] = 1.0
			card_fly.remove_at(i)
	for i in range(used_fly.size() - 1, -1, -1):
		used_fly[i]["t"] += delta * 1.8
		if used_fly[i]["t"] >= 1.0:
			used_fly.remove_at(i)
	view.queue_redraw()


# ------------------------------------------------------------------ eventos

func round_start(_n: int) -> void:
	combo = [{"hits": 0, "dmg": 0.0, "t": 9.0, "pop": 0.0}, {"hits": 0, "dmg": 0.0, "t": 9.0, "pop": 0.0}]


func announce(txt: String, col: Color, dur := 1.0, big := false) -> void:
	ann_text = txt
	ann_color = col
	ann_t = 0.0
	ann_dur = dur
	ann_big = big


func on_hit(att_pid: int, def: Fighter) -> void:
	shake[def.pid] = 1.0
	var c: Dictionary = combo[att_pid]
	c["hits"] = def.combo_hits
	c["dmg"] = def.combo_dmg
	c["t"] = 0.0
	c["pop"] = 1.0


func on_graze(pid: int) -> void:
	if graze_t[pid] > 1.2:
		graze_n[pid] = 0
	graze_n[pid] += 1
	graze_t[pid] = 0.0


func card_drawn(pid: int, _cid) -> void:
	var f: Fighter = battle.fighters[pid]
	card_fly.append({"p": pid, "slot": f.hand.size() - 1, "t": 0.0, "id": _cid})


func card_used(pid: int, cid: String, used: Array) -> void:
	used_fly.append({"p": pid, "id": cid, "t": 0.0, "n": used.size()})


func card_cycled(pid: int) -> void:
	for i in 4:
		card_pop[pid][i] = 0.5


func spell_banner(pid: int, cid: String) -> void:
	banners[pid] = cid
	banner_t[pid] = 0.0


func update_wins() -> void:
	wins_pop = [1.0, 1.0]


# ------------------------------------------------------------------ desenho

func _draw_all(c: Control) -> void:
	for p in 2:
		_draw_health(c, p)
		_draw_spirit(c, p)
		_draw_cards(c, p)
		_draw_combo(c, p)
		_draw_banner(c, p)
	_draw_timer(c)
	_draw_announce(c)
	for u in used_fly:
		_draw_used(c, u)
	for fl in card_fly:
		_draw_flying(c, fl)
	if Game.mode == Game.Mode.TRAINING:
		_text(c, "TREINO  ·  F1 caixas de colisão  ·  Esc pausa", Vector2(320, 352), 8, Color(0.8, 0.85, 1, 0.8), 1, Game.font_small)
	if Game.show_boxes:
		_draw_boxes(c)


func _text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, align := 0, font: Font = null,
		outline := 3, ocol := Color(0.05, 0.03, 0.12)) -> void:
	var fnt: Font = font if font else Game.font_main
	var w := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == 1:
		x -= w * 0.5
	elif align == 2:
		x -= w
	if outline > 0:
		c.draw_string_outline(fnt, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
	c.draw_string(fnt, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar_poly(x0: float, x1: float, y: float, h: float, slant: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0 + slant, y), Vector2(x1, y), Vector2(x1 - slant, y + h), Vector2(x0, y + h)])


func _draw_health(c: Control, p: int) -> void:
	var f: Fighter = battle.fighters[p]
	var info: Dictionary = Game.CHAR_INFO[f.kit.id]
	var sx = (sin(t * 70.0) * 2.0 * shake[p])
	var W := 250.0
	var y := 12.0
	var x0 = 46.0 + sx if p == 0 else 640.0 - 46.0 - W + sx
	# moldura
	c.draw_colored_polygon(_bar_poly(x0 - 3, x0 + W + 3, y - 3, 16, 6), Color(0.04, 0.02, 0.1, 0.9))
	c.draw_colored_polygon(_bar_poly(x0 - 2, x0 + W + 2, y - 2, 14, 6), Color(0.35, 0.3, 0.55))
	c.draw_colored_polygon(_bar_poly(x0, x0 + W, y, 10, 5), Color(0.1, 0.06, 0.18))
	var k := clampf(f.hp / Fighter.HP_MAX, 0.0, 1.0)
	var ks := clampf(f.hp_shown / Fighter.HP_MAX, 0.0, 1.0)
	var col := Color("ffd25a")
	if k < 0.25:
		col = Color("ff4a4a").lerp(Color("ff9a6a"), 0.5 + 0.5 * sin(t * 10.0))
	elif k < 0.5:
		col = Color("ff9a3a")
	# barra fantasma
	if ks > k:
		var gx0 = x0 + W * (1.0 - ks) if p == 0 else x0
		var gx1 = x0 + W if p == 0 else x0 + W * ks
		c.draw_colored_polygon(_bar_poly(gx0, gx1, y, 10, 5), Color(1.0, 0.3, 0.35, 0.85))
	if k > 0.0:
		var hx0 = x0 + W * (1.0 - k) if p == 0 else x0
		var hx1 = x0 + W if p == 0 else x0 + W * k
		c.draw_colored_polygon(_bar_poly(hx0, hx1, y, 10, 5), col)
		c.draw_colored_polygon(_bar_poly(hx0 + 1, hx1 - 1, y + 1, 3, 2), Color(1, 1, 1, 0.45))
		c.draw_colored_polygon(_bar_poly(hx0, hx1, y + 7, 3, 1), Color(col.darkened(0.35), 0.9))
	# retrato e nome
	var px := 6.0 if p == 0 else 640.0 - 6.0 - 36.0
	c.draw_rect(Rect2(px - 1, 3, 38, 38), Color(0.04, 0.02, 0.1))
	c.draw_rect(Rect2(px, 4, 36, 36), info["color"].darkened(0.55))
	c.draw_rect(Rect2(px, 4, 36, 36), info["color"], false, 1.0)
	var tex: Texture2D = f.data.portrait_b if f.alt_palette else f.data.portrait_a
	if tex:
		var tw := tex.get_width()
		var src := Rect2(maxf(0, tw * 0.5 - 16), 0, minf(32, tw), 32)
		c.draw_set_transform(Vector2(px + (36 if p == 1 else 0), 4), 0, Vector2(-1.0 if p == 1 else 1.0, 1.0))
		c.draw_texture_rect_region(tex, Rect2(2, 2, 32, 32), src)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var nx = x0 + 4 if p == 0 else x0 + W - 4
	_text(c, info["name"].to_upper(), Vector2(nx, y + 22), 8, Color(1, 1, 1), 0 if p == 0 else 2, Game.font_title)
	# vitórias
	for i in Game.rounds_to_win:
		var wx = x0 + W - 10 - i * 12 if p == 0 else x0 + 10 + i * 12
		var won := f.wins > i
		var s = 4.0 + (2.0 * wins_pop[p] if won else 0.0)
		_star(c, Vector2(wx, y + 19), s, Color("ffd66b") if won else Color(0.2, 0.15, 0.3), Color(0.04, 0.02, 0.1))


func _star(c: CanvasItem, ctr: Vector2, r: float, col: Color, ocol: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(ctr + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
	var pts2 := PackedVector2Array()
	for i in 10:
		var rr2 := (r + 1.5) if i % 2 == 0 else (r + 1.5) * 0.5
		pts2.append(ctr + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr2)
	c.draw_colored_polygon(pts2, ocol)
	c.draw_colored_polygon(pts, col)


func _draw_spirit(c: Control, p: int) -> void:
	var f: Fighter = battle.fighters[p]
	var y := 50.0
	var crushed := f.crushed > 0
	for i in 5:
		var x := 52.0 + i * 15.0 if p == 0 else 640.0 - 52.0 - i * 15.0
		var ctr := Vector2(x, y)
		var fill := clampf(f.spirit - i, 0.0, 1.0)
		c.draw_circle(ctr, 6.5, Color(0.04, 0.02, 0.1))
		c.draw_circle(ctr, 5.5, Color(0.16, 0.12, 0.28))
		var base := Color("6ad8ff") if not crushed else Color("ff5a7a")
		if f.buffs.has("vento"):
			base = Color("b8ffe8")
		if fill > 0.0:
			if fill >= 1.0:
				c.draw_circle(ctr, 5.0, base)
				c.draw_circle(ctr + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.7))
			else:
				# preenchimento de baixo para cima
				var h := 10.0 * fill
				for row in int(ceil(h)):
					var yy := 5.0 - row
					var half := sqrt(maxf(0.0, 25.0 - yy * yy))
					c.draw_line(ctr + Vector2(-half, yy - 0.5), ctr + Vector2(half, yy - 0.5), Color(base, 0.75), 1.0)
		if crushed:
			c.draw_line(ctr + Vector2(-3, -4), ctr + Vector2(1, 0), Color(0.05, 0, 0.1), 1.0)
			c.draw_line(ctr + Vector2(1, 0), ctr + Vector2(-1, 4), Color(0.05, 0, 0.1), 1.0)
		if orb_flash[p] > 0.0:
			c.draw_circle(ctr, 7.0 + 4.0 * (1.0 - orb_flash[p]), Color(1, 1, 1, orb_flash[p] * 0.5))
	if graze_t[p] < 0.8 and graze_n[p] > 1:
		var gx := 52.0 + 80.0 if p == 0 else 640.0 - 52.0 - 80.0
		_text(c, "GRAZE x%d" % graze_n[p], Vector2(gx, 54), 8, Color(0.8, 0.95, 1.0, 1.0 - graze_t[p]), 0 if p == 0 else 2, Game.font_small)


func _slot_pos(p: int, i: int) -> Vector2:
	var x := 14.0 + i * 31.0 if p == 0 else 640.0 - 14.0 - 28.0 - i * 31.0
	return Vector2(x, 312.0)


func _draw_cards(c: Control, p: int) -> void:
	var f: Fighter = battle.fighters[p]
	for i in 4:
		var sp := _slot_pos(p, i)
		c.draw_rect(Rect2(sp + Vector2(0, 2), Vector2(28, 38)), Color(0.04, 0.02, 0.1, 0.6))
		c.draw_rect(Rect2(sp + Vector2(0, 2), Vector2(28, 38)), Color(0.4, 0.35, 0.6, 0.5), false, 1.0)
	# medidor da próxima carta (contorno enchendo)
	if f.hand.size() < 4:
		var sp2 := _slot_pos(p, f.hand.size())
		var k := clampf(f.card_gauge / 100.0, 0.0, 1.0)
		var h := 38.0 * k
		c.draw_rect(Rect2(sp2 + Vector2(0, 2 + 38 - h), Vector2(28, h)), Color(0.55, 0.75, 1.0, 0.35))
		if k > 0.8:
			c.draw_rect(Rect2(sp2 + Vector2(0, 2), Vector2(28, 38)), Color(1, 1, 1, 0.3 + 0.3 * sin(t * 12.0)), false, 1.0)
	var flying := []
	for fl in card_fly:
		if fl["p"] == p:
			flying.append(fl["slot"])
	for i in f.hand.size():
		if i in flying:
			continue
		var sp3 := _slot_pos(p, i)
		var lift = (4.0 if i == 0 else 0.0) + card_pop[p][mini(i, 3)] * 6.0
		var usable := f.hand.size() >= int(Cards.get_card(f.hand[i])["cost"]) if i == 0 else false
		_card(c, f.hand[i], sp3 + Vector2(0, -lift), 1.0, i == 0, usable)
	if not f.hand.is_empty():
		var cd: Dictionary = Cards.get_card(f.hand[0])
		var label: String = cd["name"]
		var lx := 14.0 if p == 0 else 626.0
		_text(c, label, Vector2(lx, 304), 8, cd["color"].lerp(Color.WHITE, 0.5), 0 if p == 0 else 2, Game.font_main)


func _card(c: CanvasItem, id: String, pos: Vector2, s: float, active: bool, usable: bool) -> void:
	var cd: Dictionary = Cards.get_card(id)
	var W := 28.0 * s
	var H := 38.0 * s
	var col: Color = cd["color"]
	var border := Color("e0a038") if cd["kind"] == "spell" else Color("b8c4dc")
	c.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(W + 2, H + 2)), Color(0.04, 0.02, 0.1))
	c.draw_rect(Rect2(pos, Vector2(W, H)), border)
	c.draw_rect(Rect2(pos + Vector2(2, 2) * s, Vector2(W - 4 * s, H - 4 * s)), Color(0.1, 0.07, 0.2))
	var art := Rect2(pos + Vector2(3, 7) * s, Vector2(W - 6 * s, H - 14 * s))
	c.draw_rect(art, col.darkened(0.6))
	_icon(c, cd["icon"], art, col)
	for k in int(cd["cost"]):
		c.draw_rect(Rect2(pos + Vector2(4 + k * 5, 2.5) * s, Vector2(3, 3) * s), Color("fff4b8") if usable else Color(0.5, 0.45, 0.6))
	if active:
		var a := 0.5 + 0.5 * sin(t * 6.0)
		c.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(W + 4, H + 4)), Color(1, 1, 1, 0.35 + 0.4 * a if usable else 0.25), false, 1.0)


func _icon(c: CanvasItem, icon: String, r: Rect2, col: Color) -> void:
	var ctr := r.get_center()
	var s := minf(r.size.x, r.size.y) / 20.0
	var tt := t
	match icon:
		"fireflies":
			for i in 7:
				var a := i * 0.9 + tt * 1.5
				var rr := (2.0 + i * 1.2) * s
				c.draw_circle(ctr + Vector2.from_angle(a) * rr, 1.2 * s, col.lerp(Color.WHITE, 0.4))
		"constellation":
			var pts := [Vector2(-6, -6), Vector2(2, -8), Vector2(7, -1), Vector2(1, 6), Vector2(-6, 3)]
			for i in pts.size():
				c.draw_line(ctr + pts[i] * s, ctr + pts[(i + 1) % pts.size()] * s, Color(col, 0.7), 1.0)
			for pp in pts:
				c.draw_circle(ctr + pp * s, 1.3 * s, Color.WHITE)
		"aurora":
			for i in 3:
				var pts2 := PackedVector2Array()
				for k in 8:
					pts2.append(ctr + Vector2(-8 + k * 2.3, sin(k * 0.9 + i + tt * 2.0) * 2.5 - 4 + i * 4) * s)
				c.draw_polyline(pts2, [Color("7affc8"), Color("8fd8ff"), Color("d08aff")][i], 1.5 * s)
		"fist":
			c.draw_rect(Rect2(ctr + Vector2(-5, -3) * s, Vector2(9, 8) * s), Color("8d9ab8"))
			c.draw_polyline(PackedVector2Array([ctr + Vector2(5, -8) * s, ctr + Vector2(1, -2) * s, ctr + Vector2(5, -1) * s, ctr + Vector2(0, 7) * s]), col, 1.5)
		"flurry":
			for i in 5:
				var y := -7.0 + i * 3.5
				c.draw_line(ctr + Vector2(-8, y) * s, ctr + Vector2(4 + (i % 2) * 3, y) * s, Color(col, 0.9), 1.2)
			c.draw_circle(ctr + Vector2(6, 0) * s, 3.0 * s, Color("ffd2b0"))
		"thunder":
			c.draw_polyline(PackedVector2Array([ctr + Vector2(2, -9) * s, ctr + Vector2(-3, 0) * s, ctr + Vector2(2, 0) * s, ctr + Vector2(-2, 9) * s]), Color.WHITE, 2.0)
			c.draw_polyline(PackedVector2Array([ctr + Vector2(2, -9) * s, ctr + Vector2(-3, 0) * s, ctr + Vector2(2, 0) * s, ctr + Vector2(-2, 9) * s]), col, 1.0)
		"elixir":
			c.draw_rect(Rect2(ctr + Vector2(-4, -2) * s, Vector2(8, 9) * s), Color(col, 0.9))
			c.draw_rect(Rect2(ctr + Vector2(-1.5, -7) * s, Vector2(3, 5) * s), Color(0.8, 0.85, 0.95))
			c.draw_circle(ctr + Vector2(-1, 1) * s, 1.0 * s, Color.WHITE)
		"wind":
			for i in 3:
				var pts3 := PackedVector2Array()
				for k in 7:
					pts3.append(ctr + Vector2(-8 + k * 2.5, -5 + i * 5 + sin(k + tt * 3.0 + i) * 1.2) * s)
				c.draw_polyline(pts3, Color(col, 0.9), 1.2)


func _draw_flying(c: Control, fl: Dictionary) -> void:
	var p: int = fl["p"]
	var k: float = fl["t"]
	var f: Fighter = battle.fighters[p]
	var start = Vector2(320, 200) if f == null else battle.get_viewport().get_canvas_transform() * f.center()
	start = start / (battle.get_viewport().get_visible_rect().size / Vector2(640, 360))
	var end := _slot_pos(p, mini(3, fl["slot"]))
	var e := 1.0 - pow(1.0 - k, 3.0)
	var pos = start.lerp(end, e) + Vector2(0, -sin(k * PI) * 40.0)
	var s := 0.6 + 0.4 * e
	var flip := absf(cos(k * PI * 2.0))
	c.draw_set_transform(pos + Vector2(14, 19), 0.0, Vector2(maxf(0.1, flip) * s, s))
	_card(c, fl["id"], Vector2(-14, -19), 1.0, false, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_used(c: Control, u: Dictionary) -> void:
	var p: int = u["p"]
	var k: float = u["t"]
	var sp := _slot_pos(p, 0)
	var pos := sp + Vector2(0, -k * 50.0)
	var s := 1.0 + k * 0.8
	c.draw_set_transform(pos + Vector2(14, 19), 0.0, Vector2(s, s))
	var a := 1.0 - k
	_card(c, u["id"], Vector2(-14, -19), 1.0, true, true)
	c.draw_rect(Rect2(Vector2(-16, -21), Vector2(32, 42)), Color(1, 1, 1, a * 0.6))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_combo(c: Control, p: int) -> void:
	var cb: Dictionary = combo[p]
	if cb["hits"] < 2 or cb["t"] > 1.6:
		return
	var a := clampf(1.6 - cb["t"], 0.0, 1.0) * 2.0
	var x := 20.0 if p == 0 else 620.0
	var al := 0 if p == 0 else 2
	var pop: float = cb["pop"]
	var size := int(22 + 10 * pop)
	var col := Color(1, 0.85, 0.4, minf(1.0, a)).lerp(Color(1, 1, 1, minf(1.0, a)), pop)
	_text(c, str(cb["hits"]), Vector2(x, 120), size, col, al, Game.font_title, 4)
	_text(c, "HITS", Vector2(x + (size * 0.75 * len(str(cb["hits"])) + 4 if p == 0 else -(size * 0.75 * len(str(cb["hits"])) + 4)), 120),
		10, Color(1, 1, 1, minf(1.0, a)), al, Game.font_title)
	_text(c, "%d dano" % int(cb["dmg"]), Vector2(x, 134), 9, Color(0.85, 0.9, 1.0, minf(1.0, a)), al, Game.font_main)


func _draw_banner(c: Control, p: int) -> void:
	var cid: String = banners[p]
	if cid == "":
		return
	var cd: Dictionary = Cards.get_card(cid)
	var k := clampf(banner_t[p] * 3.0, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var W := 250.0
	var y := 64.0
	var x := -W + (W + 46.0) * e if p == 0 else 640.0 - 46.0 - W + (W + 46.0) * (1.0 - e)
	var col: Color = cd["color"]
	c.draw_colored_polygon(_bar_poly(x, x + W, y, 18, 8), Color(0.05, 0.02, 0.12, 0.85))
	c.draw_colored_polygon(_bar_poly(x, x + W, y + 16, 2, 1), col)
	var shine := fmod(banner_t[p] * 0.8, 1.6) - 0.3
	if shine > 0.0 and shine < 1.0:
		var sx := x + W * shine
		c.draw_colored_polygon(_bar_poly(sx, sx + 14, y, 16, 8), Color(1, 1, 1, 0.15))
	var txt := "%s「%s」" % [cd["sign"], cd["name"]]
	_text(c, txt, Vector2(x + (8 if p == 0 else W - 8), y + 13), 9, Color(1, 1, 1), 0 if p == 0 else 2, Game.font_main)


func _draw_timer(c: Control) -> void:
	var secs := int(ceil(battle.timer / 60.0))
	var ctr := Vector2(320, 22)
	c.draw_circle(ctr, 17, Color(0.04, 0.02, 0.1))
	c.draw_circle(ctr, 15, Color(0.25, 0.2, 0.45))
	c.draw_circle(ctr, 13, Color(0.08, 0.05, 0.18))
	for i in 8:
		var a := i * TAU / 8.0 + t * 0.3
		c.draw_circle(ctr + Vector2.from_angle(a) * 16.0, 1.2, Color("ffd66b"))
	var col := Color(1, 1, 1) if secs > 10 else Color(1, 0.4, 0.4).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 12.0))
	if Game.mode == Game.Mode.TRAINING:
		_text(c, "∞", ctr + Vector2(0, 6), 16, col, 1, Game.font_main)
	else:
		_text(c, "%02d" % clampi(secs, 0, 99), ctr + Vector2(0, 6), 16, col, 1, Game.font_title)


func _draw_announce(c: Control) -> void:
	if ann_t > ann_dur + 0.4:
		return
	var k := ann_t
	var a := 1.0
	var s := 1.0
	if k < 0.18:
		s = lerpf(2.6, 1.0, ease(k / 0.18, 0.4))
		a = k / 0.18
	elif k > ann_dur:
		a = clampf(1.0 - (k - ann_dur) / 0.4, 0.0, 1.0)
		s = 1.0 + (k - ann_dur) * 0.6
	var size := 34 if ann_big else 24
	var ctr := Vector2(320, 150)
	# faixa
	var bh := 40.0 * minf(1.0, k * 6.0) * a
	c.draw_rect(Rect2(0, ctr.y - bh * 0.5 - 6, 640, bh), Color(0.04, 0.02, 0.1, 0.55 * a))
	c.draw_rect(Rect2(0, ctr.y - bh * 0.5 - 6, 640, 1), Color(ann_color, 0.6 * a))
	c.draw_rect(Rect2(0, ctr.y + bh * 0.5 - 7, 640, 1), Color(ann_color, 0.6 * a))
	c.draw_set_transform(ctr, 0.0, Vector2(s, s))
	_text(c, ann_text, Vector2(0, size * 0.35), size, Color(ann_color, a), 1, Game.font_title, 5)
	if k < 0.3:
		_text(c, ann_text, Vector2(0, size * 0.35), size, Color(1, 1, 1, (0.3 - k) / 0.3), 1, Game.font_title, 0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boxes(c: Control) -> void:
	var xf: Transform2D = battle.get_viewport().get_canvas_transform()
	var sc = Vector2(640, 360) / battle.get_viewport().get_visible_rect().size
	for f in battle.fighters:
		for r in f.hurtboxes():
			_box(c, xf, sc, r, Color(0.3, 0.6, 1.0))
		for r in f.hitboxes():
			_box(c, xf, sc, r, Color(1.0, 0.3, 0.3))
	for p in battle.projectiles:
		if is_instance_valid(p) and p.active():
			_box(c, xf, sc, p.world_rect(), Color(1.0, 0.8, 0.3))


func _box(c: Control, xf: Transform2D, sc: Vector2, r: Rect2, col: Color) -> void:
	var a := xf * r.position * sc
	var b := xf * r.end * sc
	c.draw_rect(Rect2(a, b - a), Color(col, 0.25))
	c.draw_rect(Rect2(a, b - a), col, false, 1.0)
