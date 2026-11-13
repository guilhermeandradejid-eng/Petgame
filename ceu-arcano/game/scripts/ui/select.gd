extends Node2D
## Seleção de personagens: prévias animadas em tamanho grande, cursores dos dois lados e ficha.

var cursor := [0, 1]
var picked := [false, false]
var active_side := 0        # no modo contra CPU, o P1 escolhe os dois lados em sequência
var previews: Array = []
var t := 0.0
var ui: Control
var going := false
var flash := [0.0, 0.0]


func _ready() -> void:
	var bg := _BG.new()
	bg.sel = self
	add_child(bg)
	for side in 2:
		var p := CharPreview.new()
		p.setup(Game.CHARACTERS[cursor[side]], side == 1 and cursor[0] == cursor[1])
		p.position = Vector2(160 if side == 0 else 480, 292)
		p.scale = Vector2(1.75, 1.75)
		p.facing = 1 if side == 0 else -1
		add_child(p)
		previews.append(p)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = _UI.new()
	ui.sel = self
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	Audio.music("select")


class _BG extends Node2D:
	var sel
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		sel._draw_bg(self)


class _UI extends Control:
	var sel
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		sel._draw_ui(self)


func _two_players() -> bool:
	return Game.mode == Game.Mode.VS_PLAYER


func _process(delta: float) -> void:
	t += delta
	for i in 2:
		flash[i] = maxf(0.0, flash[i] - delta * 3.0)
	if going:
		return
	for side in 2:
		var dev := side if _two_players() else 0
		if not _two_players() and side != active_side:
			continue
		var pre := "p%d_" % (dev + 1)
		if picked[side]:
			if Input.is_action_just_pressed(pre + "b") or (not _two_players() and Input.is_action_just_pressed("ui_cancel")):
				picked[side] = false
				if not _two_players() and side == 1:
					pass
				Audio.play("ui_back", -4.0)
			continue
		var moved := 0
		if Input.is_action_just_pressed(pre + "left"):
			moved = -1
		elif Input.is_action_just_pressed(pre + "right"):
			moved = 1
		if moved != 0:
			cursor[side] = posmod(cursor[side] + moved, Game.CHARACTERS.size())
			_refresh(side)
			Audio.play("ui_move", -5.0)
		if Input.is_action_just_pressed(pre + "a") or (not _two_players() and Input.is_action_just_pressed("ui_accept") and not Input.is_action_just_pressed(pre + "a")):
			picked[side] = true
			flash[side] = 1.0
			previews[side].play("intro")
			previews[side].flash = 1.0
			Audio.play("ui_confirm", -2.0)
			Audio.play("card_gain", -6.0)
			if not _two_players() and side == 0:
				active_side = 1
		elif Input.is_action_just_pressed(pre + "b") or (not _two_players() and Input.is_action_just_pressed("ui_cancel")):
			if not _two_players() and side == 1:
				active_side = 0
				picked[0] = false
				Audio.play("ui_back", -4.0)
			else:
				Audio.play("ui_back", -4.0)
				Game.goto("res://scenes/title.tscn")
				going = true
				return
	if picked[0] and picked[1] and not going:
		going = true
		Game.p_chars = [Game.CHARACTERS[cursor[0]], Game.CHARACTERS[cursor[1]]]
		Audio.play("fight_start", -2.0)
		await get_tree().create_timer(0.9).timeout
		Game.goto("res://scenes/battle.tscn", Color(1, 1, 1))


func _refresh(side: int) -> void:
	var alt = side == 1 and cursor[0] == cursor[1]
	previews[side].setup(Game.CHARACTERS[cursor[side]], alt)
	if side == 0 and cursor[0] == cursor[1]:
		previews[1].setup(Game.CHARACTERS[cursor[1]], true)
	elif side == 0:
		previews[1].setup(Game.CHARACTERS[cursor[1]], false)


func _draw_bg(c: Node2D) -> void:
	c.draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.035, 0.13))
	for side in 2:
		var info: Dictionary = Game.CHAR_INFO[Game.CHARACTERS[cursor[side]]]
		var col: Color = info["color"]
		var x0 := 0.0 if side == 0 else 320.0
		# listras diagonais animadas
		for i in 14:
			var off := fmod(t * 30.0 + i * 46.0, 644.0) - 120.0
			var px := x0 + (off if side == 0 else 320.0 - off)
			c.draw_colored_polygon(PackedVector2Array([Vector2(px, 0), Vector2(px + 18, 0), Vector2(px - 102, 360), Vector2(px - 120, 360)]),
				Color(col, 0.05 + 0.03 * sin(i)))
		c.draw_rect(Rect2(x0, 290, 320, 70), Color(col.darkened(0.6), 0.6))
		# chão com círculo mágico
		var ctr := Vector2(160 if side == 0 else 480, 294)
		c.draw_set_transform(ctr, 0.0, Vector2(1, 0.28))
		c.draw_arc(Vector2.ZERO, 70.0, 0, TAU, 48, Color(col, 0.6 + 0.4 * flash[side]), 2.0)
		c.draw_arc(Vector2.ZERO, 54.0, t * 0.5, t * 0.5 + TAU * 0.8, 40, Color(col, 0.5), 1.0)
		for i in 12:
			var a := t * (0.6 if side == 0 else -0.6) + i * TAU / 12.0
			c.draw_circle(Vector2.from_angle(a) * 62.0, 1.5, col)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_rect(Rect2(318, 0, 4, 360), Color(0.02, 0.01, 0.06))


func _draw_ui(c: Control) -> void:
	var font: Font = Game.font_main
	var tf: Font = Game.font_title
	_t(c, tf, "ESCOLHA SUA DUELISTA", Vector2(320, 26), 16, Color("ffd66b"), 1)
	for side in 2:
		var cid: String = Game.CHARACTERS[cursor[side]]
		var info: Dictionary = Game.CHAR_INFO[cid]
		var col: Color = info["color"]
		var x := 24.0 if side == 0 else 616.0
		var al := 0 if side == 0 else 2
		var who := "P%d" % (side + 1)
		if not _two_players() and side == 1:
			who = "CPU" if Game.mode != Game.Mode.TRAINING else "BONECO"
		_t(c, tf, who, Vector2(x, 50), 12, col.lerp(Color.WHITE, 0.3), al)
		_t(c, tf, info["name"].to_upper(), Vector2(x, 76), 24, Color(1, 1, 1), al)
		_t(c, font, info["title"], Vector2(x, 91), 11, col.lerp(Color.WHITE, 0.4), al)
		_t(c, font, "Estilo: %s" % info["style"], Vector2(x, 104), 9, Color(0.8, 0.82, 1.0), al)
		var bx := x if side == 0 else x - 250.0
		c.draw_multiline_string(font, Vector2(bx, 118), info["blurb"], HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT,
			250, 9, -1, Color(0.85, 0.85, 0.95))
		if picked[side]:
			var a := 0.7 + 0.3 * sin(t * 8.0)
			_t(c, tf, "PRONTA!", Vector2(160 if side == 0 else 480, 320), 16, Color(1, 1, 1, a), 1)
		elif not _two_players() and side != active_side:
			pass
		else:
			var s := "◀  %s  ▶" % info["name"]
			_t(c, font, s, Vector2(160 if side == 0 else 480, 322), 12, Color(1, 1, 1, 0.85), 1)
	# ícones no centro
	for i in Game.CHARACTERS.size():
		var cid2: String = Game.CHARACTERS[i]
		var d := CharData.get_data(cid2)
		var pos := Vector2(296 + i * 26 - 13 * (Game.CHARACTERS.size() - 1) + 13 - 13, 300)
		pos = Vector2(320 - 26 + i * 28, 296)
		c.draw_rect(Rect2(pos, Vector2(24, 24)), Color(0.04, 0.02, 0.1))
		c.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(22, 22)), Game.CHAR_INFO[cid2]["color"].darkened(0.5))
		var tex: Texture2D = d.portrait_a
		var src := Rect2(maxf(0, tex.get_width() * 0.5 - 11), 0, 22, 22)
		c.draw_texture_rect_region(tex, Rect2(pos + Vector2(1, 1), Vector2(22, 22)), src)
		for side in 2:
			if cursor[side] == i:
				var cc: Color = Color("ff6a5a") if side == 0 else Color("5ab8ff")
				var o := 2.0 + sin(t * 6.0 + side) * 1.0
				c.draw_rect(Rect2(pos - Vector2(o, o), Vector2(24 + o * 2, 24 + o * 2)), cc, false, 1.0)
				_t(c, Game.font_small, "P%d" % (side + 1) if (side == 0 or _two_players()) else "CPU", pos + Vector2(12, -4 - side * 0 if side == 0 else 34), 8, cc, 1)
	_t(c, font, "J confirmar  ·  K voltar  ·  A/D escolher", Vector2(320, 352), 9, Color(0.7, 0.7, 0.85), 1)


func _t(c: Control, font: Font, s: String, pos: Vector2, size: int, col: Color, align: int) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	c.draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.03, 0.02, 0.08, col.a))
	c.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
