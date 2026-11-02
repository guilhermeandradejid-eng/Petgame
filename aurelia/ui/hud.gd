extends CanvasLayer
## Party panel: HP / MP / SP, current weapon + techniques, spell, kill counter, control hints.

var _c: Control
var _t := 0.0


func _ready() -> void:
	layer = 60
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_hud)
	add_child(_c)


func _process(delta: float) -> void:
	_t += delta
	_c.queue_redraw()


func _bar(pos: Vector2, size: Vector2, ratio: float, col: Color, ticks: Array = []) -> void:
	_c.draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color(0.07, 0.04, 0.1, 0.85))
	_c.draw_rect(Rect2(pos, size), Color(0.2, 0.15, 0.25))
	var w := size.x * clampf(ratio, 0.0, 1.0)
	_c.draw_rect(Rect2(pos, Vector2(w, size.y)), col)
	_c.draw_rect(Rect2(pos, Vector2(w, size.y * 0.4)), col.lightened(0.35))
	for t in ticks:
		var x := pos.x + size.x * float(t)
		_c.draw_line(Vector2(x, pos.y), Vector2(x, pos.y + size.y), Color(0.07, 0.04, 0.1, 0.9), 1.0)


func _txt(pos: Vector2, s: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	_c.draw_string(font, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.05, 0.02, 0.1, 0.8))
	_c.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_hud() -> void:
	var sc := 1.3 if Game.touch_mode else 1.15
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	var ps := get_tree().get_nodes_in_group("players")
	ps.sort_custom(func(a, b): return a.peer_id < b.peer_id)
	var y := 12.0
	for p in ps:
		var local: bool = p.is_multiplayer_authority()
		var col: Color = Color(0.75, 1, 0.9) if local else Color(0.9, 0.9, 1)
		_txt(Vector2(12, y + 10), ("P%d" % p.peer_id) + ("  Lv%d" % p.level if local else ""), 12, col)
		_bar(Vector2(72, y), Vector2(130, 9), float(p.hp) / p.max_hp, Color(0.9, 0.3, 0.35))
		if local:
			_bar(Vector2(72, y + 13), Vector2(100, 6), p.mp / p.max_mp, Color(0.35, 0.7, 1.0))
			var blink: bool = p.sp_denied > 0 and int(_t * 20) % 2 == 0
			var full: bool = p.sp >= 99.9
			var spc := Color(1, 0.85, 0.3) if not blink else Color(1, 0.3, 0.3)
			if full:
				spc = spc.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 10.0))
			_bar(Vector2(72, y + 24), Vector2(100, 6), p.sp / p.SP_MAX, spc, [0.4, 0.7])
			_txt(Vector2(176, y + 20), "MP", 8, Color(0.6, 0.85, 1))
			_txt(Vector2(176, y + 31), "SP", 8, Color(1, 0.9, 0.5))
			# techniques of the current weapon
			var ty := y + 46
			_txt(Vector2(12, ty), p.weapon.display_name, 10, p.weapon.color)
			var keys := ["U", "O"]
			if Game.touch_mode:
				keys = ["SP1", "SP2"]
			for i in p.weapon.specials.size():
				var sd: SpecialData = p.weapon.specials[i]
				var ok: bool = p.sp >= sd.sp_cost
				_txt(Vector2(12, ty + 12 + i * 11), "%s  %s  %d" % [keys[i], sd.display_name, sd.sp_cost], 9,
					Color(1, 0.95, 0.7) if ok else Color(0.6, 0.6, 0.7))
			var okm: bool = p.mp >= p.spell.mp_cost
			_txt(Vector2(12, ty + 12 + 2 * 11), "%s  %s  %d MP" % ["MAG" if Game.touch_mode else "I", p.spell.display_name, p.spell.mp_cost], 9,
				p.spell.color if okm else Color(0.6, 0.6, 0.7))
			y += 70.0
		y += 30.0
	var vs := _c.get_viewport_rect().size / sc
	_txt(Vector2(12, vs.y - 12 if Game.touch_mode else vs.y - 24), "Defeated: %d" % Game.kills, 10, Color(1, 0.95, 0.7))
	if not Game.touch_mode:
		_txt(Vector2(12, vs.y - 10),
			"Move WASD  Attack J  Jump K  Dash L  Specials U/O  Magic I  Weapon Q  Spell E", 8, Color(1, 1, 1, 0.7))
	if Net.mode != "offline":
		_txt(Vector2(vs.x - 110, vs.y - 10), "%s - %d players" % [Net.mode.to_upper(), ps.size()], 9, Color(0.8, 0.85, 1))
