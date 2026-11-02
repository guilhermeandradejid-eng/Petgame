extends CanvasLayer
## Battle presentation: letterbox bars, BATTLE!/VICTORY banners, results card and the combo counter.

var _top: ColorRect
var _bot: ColorRect
var _banner: Label
var _sub: Label
var _combo_n: Label
var _combo_l: Label
var _combo_d: Label
var _combo_word: Label
var _combo_box: Control
var _result: VBoxContainer
var _vs := Vector2(640, 360)
var _last_milestone := 0
var _bar_h := 0.0
var _battle_t := 0.0
var _in_battle := false


func _ready() -> void:
	layer = 65
	_top = _bar()
	_bot = _bar()
	_banner = _label(46, Color(1, 0.9, 0.5))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.visible = false
	_sub = _label(14, Color(1, 1, 1, 0.9))
	_sub.visible = false
	_combo_box = Control.new()
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.visible = false
	add_child(_combo_box)
	_combo_n = _label(40, Color.WHITE, _combo_box)
	_combo_l = _label(13, Color(1, 0.9, 0.5), _combo_box)
	_combo_l.text = "HITS"
	_combo_d = _label(11, Color(1, 1, 1, 0.85), _combo_box)
	_combo_word = _label(20, Color(1, 0.9, 0.4), _combo_box)
	_result = VBoxContainer.new()
	_result.visible = false
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_result)
	Game.combo_changed.connect(_on_combo)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _bar() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.03, 0.02, 0.06, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1400, 0)
	add_child(c)
	return c


func _label(size: int, col: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.14))
	l.add_theme_constant_override("outline_size", maxi(size / 7, 3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(parent if parent != null else self).add_child(l)
	return l


func _layout() -> void:
	_vs = get_viewport().get_visible_rect().size
	_top.size = Vector2(_vs.x + 40, _bar_h)
	_top.position = Vector2(-20, 0)
	_bot.size = Vector2(_vs.x + 40, _bar_h)
	_bot.position = Vector2(-20, _vs.y - _bar_h)
	_banner.size = Vector2(_vs.x, 60)
	_banner.position = Vector2(0, _vs.y * 0.30)
	_banner.pivot_offset = Vector2(_vs.x * 0.5, 30)
	_sub.size = Vector2(_vs.x, 20)
	_sub.position = Vector2(0, _vs.y * 0.30 + 58)
	_combo_box.position = Vector2(_vs.x - 118, _vs.y * 0.30)
	_combo_n.size = Vector2(110, 48)
	_combo_n.position = Vector2(0, 0)
	_combo_n.pivot_offset = Vector2(55, 24)
	_combo_l.size = Vector2(110, 18)
	_combo_l.position = Vector2(0, 44)
	_combo_d.size = Vector2(110, 16)
	_combo_d.position = Vector2(0, 60)
	_combo_word.size = Vector2(110, 26)
	_combo_word.position = Vector2(0, 76)
	_result.position = Vector2(_vs.x * 0.5 - 100, _vs.y * 0.47)
	_result.custom_minimum_size = Vector2(200, 0)


func _set_bars(h: float, t: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float):
		_bar_h = v
		_layout(), _bar_h, h, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_banner(text: String, col: Color, sub: String, hold: float) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(3.0, 3.0)
	_sub.text = sub
	_sub.visible = sub != ""
	_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_sub, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_banner.visible = false
		_sub.visible = false)


func battle_start() -> void:
	_in_battle = true
	_battle_t = 0.0
	_last_milestone = 0
	_set_bars(_vs.y * 0.075, 0.45)
	_result.visible = false
	_show_banner("BATTLE!", Color(1, 0.88, 0.42), "Defeat every monster to leave the arena", 1.0)


func battle_end(win: bool, exp_value: int, level: int) -> void:
	_in_battle = false
	if win:
		_show_banner("VICTORY!", Color(0.6, 1, 0.8), "", 1.2)
		_show_results(exp_value, level)
	else:
		_show_banner("DEFEATED...", Color(1, 0.5, 0.5), "The monsters calm down. Try again!", 1.5)
		get_tree().create_timer(2.0).timeout.connect(func(): _set_bars(0.0, 0.5))


func _show_results(exp_value: int, level: int) -> void:
	for c in _result.get_children():
		c.queue_free()
	var rows := [
		["MAX COMBO", str(Game.combo_max)],
		["DAMAGE DEALT", str(Game.battle_damage)],
		["TIME", "%d:%02d" % [int(_battle_t) / 60, int(_battle_t) % 60]],
		["EXP", "+%d   (Lv %d)" % [exp_value, level]],
	]
	_result.modulate.a = 1.0
	_result.visible = true
	var i := 0
	for r in rows:
		var l := _label(14, Color(1, 1, 1, 0.95), _result)
		l.text = "%-14s %s" % [r[0], r[1]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		l.scale = Vector2(0.6, 0.6)
		var tw := l.create_tween()
		tw.tween_interval(1.1 + i * 0.28)
		tw.tween_callback(func(): Sfx.play("tick", -8.0, 1.0 + i * 0.12))
		tw.tween_property(l, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		i += 1
	var out := create_tween()
	out.tween_interval(4.6)
	out.tween_property(_result, "modulate:a", 0.0, 0.5)
	out.tween_callback(func():
		_result.visible = false
		_set_bars(0.0, 0.6))


func _process(delta: float) -> void:
	if _in_battle:
		_battle_t += delta


func _on_combo(hits: int, dmg: int) -> void:
	if hits <= 0:
		var tw := create_tween()
		tw.tween_property(_combo_box, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): _combo_box.visible = false)
		_last_milestone = 0
		return
	_combo_box.visible = true
	_combo_box.modulate.a = 1.0
	_combo_n.text = str(hits)
	_combo_d.text = "%d dmg" % dmg
	var col := Color.WHITE
	if hits >= 20:
		col = Color(1.0, 0.55, 0.3)
	elif hits >= 10:
		col = Color(1.0, 0.9, 0.35)
	_combo_n.add_theme_color_override("font_color", col)
	_combo_n.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(_combo_n, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var words := {5: "NICE!", 10: "GREAT!", 20: "EXCELLENT!", 40: "LEGENDARY!"}
	for m in words:
		if hits >= m and _last_milestone < m:
			_last_milestone = m
			_combo_word.text = words[m]
			_combo_word.scale = Vector2(1.8, 1.8)
			_combo_word.pivot_offset = Vector2(55, 13)
			_combo_word.modulate.a = 1.0
			var tw := create_tween()
			tw.tween_property(_combo_word, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
			tw.tween_interval(0.9)
			tw.tween_property(_combo_word, "modulate:a", 0.0, 0.3)
			Sfx.play("combo_up", -5.0, 0.9 + 0.1 * (m / 10))
