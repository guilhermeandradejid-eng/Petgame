extends CanvasLayer
## Party panel: HP / MP per player, kill counter, control hints.

var _c: Control


func _ready() -> void:
	layer = 60
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_hud)
	add_child(_c)


func _process(_d: float) -> void:
	_c.queue_redraw()


func _bar(pos: Vector2, size: Vector2, ratio: float, col: Color) -> void:
	_c.draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color(0.07, 0.04, 0.1, 0.85))
	_c.draw_rect(Rect2(pos, size), Color(0.2, 0.15, 0.25))
	_c.draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), col)
	_c.draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y * 0.35)), col.lightened(0.35))


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var ps := get_tree().get_nodes_in_group("players")
	ps.sort_custom(func(a, b): return a.peer_id < b.peer_id)
	var y := 18.0
	for p in ps:
		var local: bool = p.is_multiplayer_authority()
		_c.draw_string(font, Vector2(20, y + 12), ("YOU" if local else "ALLY") + "  P%d" % p.peer_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.75, 1, 0.9) if local else Color(0.9, 0.9, 1))
		_bar(Vector2(100, y), Vector2(190, 12), float(p.hp) / p.max_hp, Color(0.9, 0.3, 0.35))
		if local:
			_bar(Vector2(100, y + 18), Vector2(150, 8), p.mp / p.max_mp, Color(0.35, 0.7, 1.0))
			y += 16.0
		y += 30.0
	var vs := _c.get_viewport_rect().size
	_c.draw_string(font, Vector2(vs.x - 190, 30), "Defeated: %d" % Game.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.95, 0.7))
	var role := Net.mode.to_upper()
	_c.draw_string(font, Vector2(vs.x - 190, 52), "%s  (%d players)" % [role, ps.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.85, 1))
	_c.draw_string(font, Vector2(20, vs.y - 16),
		"Move WASD / stick   Attack J / X   Jump K / A   Dash L / B   Ice Lance I / Y",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
