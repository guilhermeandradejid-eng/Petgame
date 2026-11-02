class_name Hud
extends CanvasLayer
## In-level HUD: spark counter, star seeds, player cards, toasts, title card,
## pause menu and the level-complete screen.

signal resume_requested
signal restart_requested
signal menu_requested
signal next_requested

var level: Node
var _spark_label: Label
var _spark_box: Control
var _seed_dots: Array = []
var _toast: PanelContainer
var _toast_label: Label
var _toast_t := 0.0
var _solo_label: Label
var _pause: Control
var _complete: Control
var _cards: Array = []
var _shown_sparks := 0.0


func setup(lvl: Node) -> void:
	level = lvl
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)

	# --- spark counter (top center)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-150, 14)
	top.custom_minimum_size = Vector2(300, 0)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(row)
	var star := UiTheme.outlined("✦", 56, Color(1, 0.86, 0.3), 12)
	row.add_child(star)
	_spark_label = UiTheme.outlined("0", 52, Color.WHITE, 12)
	row.add_child(_spark_label)
	_spark_box = row
	var seeds := HBoxContainer.new()
	seeds.alignment = BoxContainer.ALIGNMENT_CENTER
	seeds.add_theme_constant_override("separation", 10)
	top.add_child(seeds)
	for i in 3:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(30, 30)
		d.add_theme_stylebox_override("panel", UiTheme.box(Color(0.3, 0.2, 0.4, 0.5), 15, 3, Color(1, 1, 1, 0.8), 0))
		seeds.add_child(d)
		_seed_dots.append(d)

	# --- player cards
	for i in 2:
		var c: Dictionary = Game.CHARACTERS[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box((c["color"] as Color).lerp(Color.WHITE, 0.15), 24, 4))
		card.position = Vector2(18, 18) if i == 0 else Vector2(0, 18)
		if i == 1:
			card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			card.position = Vector2(-18, 18)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		var name := UiTheme.outlined(c["name"], 34, Color.WHITE, 10)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(name)
		var dev := Label.new()
		dev.text = Game.device_label(i) if Game.coop else ("Ativo" if i == 0 else "Tab / Back: trocar")
		dev.add_theme_font_size_override("font_size", 18)
		dev.add_theme_color_override("font_color", UiTheme.INK)
		v.add_child(dev)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(card)
		_cards.append({"card": card, "dev": dev})

	_solo_label = UiTheme.outlined("", 24, Color.WHITE, 8)
	_solo_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_solo_label.position = Vector2(-300, -48)
	_solo_label.custom_minimum_size = Vector2(600, 30)
	root.add_child(_solo_label)

	# --- toast
	_toast = PanelContainer.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.position = Vector2(0, -110)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 28)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_build_pause(root)
	_build_complete(root)


func _process(delta: float) -> void:
	_toast_t -= delta
	if _toast_t <= 0.0 and _toast.modulate.a > 0.0:
		_toast.modulate.a = move_toward(_toast.modulate.a, 0.0, delta * 3.0)
	# rolling counter
	_shown_sparks = move_toward(_shown_sparks, level.sparks, delta * 30.0)
	_spark_label.text = str(int(round(_shown_sparks)))
	_toast.position.x = -_toast.size.x * 0.5
	if not Game.coop and level.players.size() == 2:
		_solo_label.text = "Controlando: %s  •  Tab / Back para trocar" % level.players[level.active].name
		for i in 2:
			_cards[i]["card"].modulate = Color(1, 1, 1, 1.0 if i == level.active else 0.55)


func bump_sparks() -> void:
	UiTheme.pop(_spark_box, 1.3)


func set_seed(i: int, on: bool) -> void:
	if i < 0 or i >= 3:
		return
	var d: Panel = _seed_dots[i]
	d.add_theme_stylebox_override("panel", UiTheme.box(Color(0.72, 0.5, 1.0) if on else Color(0.3, 0.2, 0.4, 0.5), 15, 3, Color.WHITE, 0))
	if on:
		UiTheme.pop(d, 1.6)


func toast(text: String, color := Color(1, 0.97, 0.9)) -> void:
	_toast_label.text = text
	_toast.add_theme_stylebox_override("panel", UiTheme.box(color.lerp(Color.WHITE, 0.55), 24, 4))
	_toast.modulate.a = 1.0
	_toast_t = 2.6
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.7, 0.7)
	_toast.create_tween().tween_property(_toast, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func title_card(title: String, sub: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(1000, 200)
	box.position = Vector2(-500, -170)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_child(0).add_child(box)
	var t := UiTheme.outlined(title, 96, Color(1, 0.92, 0.6), 20)
	var s := UiTheme.outlined(sub, 36, Color.WHITE, 10)
	box.add_child(t)
	box.add_child(s)
	box.pivot_offset = box.custom_minimum_size * 0.5
	box.scale = Vector2(0.3, 0.3)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(box, "position:y", box.position.y - 60.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


# ---------------------------------------------------------------- pause
func _build_pause(root: Control) -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.12, 0.05, 0.18, 0.55)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(460, 0)
	p.add_child(v)
	var t := UiTheme.outlined("Pausa", 64, UiTheme.ACCENT, 12)
	v.add_child(t)
	for item in [["Continuar", resume_requested], ["Reiniciar fase", restart_requested], ["Trocar controles P1/P2", null], ["Menu principal", menu_requested]]:
		var b := Button.new()
		b.text = item[0]
		v.add_child(b)
		if item[1] != null:
			var sig: Signal = item[1]
			b.pressed.connect(func(): sig.emit())
		else:
			b.pressed.connect(func():
				Game.swap_pads()
				for i in 2:
					_cards[i]["dev"].text = Game.device_label(i)
				toast("Controles trocados!"))
	UiTheme.juice_buttons(v)


func show_pause(on: bool) -> void:
	_pause.visible = on
	if on:
		var first: Button = _pause.find_children("*", "Button", true, false)[0]
		first.grab_focus()
		var p: Control = _pause.get_child(0)
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(0.8, 0.8)
		p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -------------------------------------------------------------- complete
func _build_complete(root: Control) -> void:
	_complete = ColorRect.new()
	(_complete as ColorRect).color = Color(0.12, 0.05, 0.18, 0.0)
	_complete.set_anchors_preset(Control.PRESET_FULL_RECT)
	_complete.visible = false
	root.add_child(_complete)


func show_complete(stats: Dictionary) -> void:
	_complete.visible = true
	_complete.create_tween().tween_property(_complete, "color:a", 0.5, 0.5)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_complete.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(620, 0)
	p.add_child(v)
	v.add_child(UiTheme.outlined("Fase completa!", 72, Color(1, 0.8, 0.35), 14))
	var lines := [
		"✦ Faíscas: %d / %d" % [stats["sparks"], stats["total"]],
		"Sementes Estelares: %d / 3" % stats["seeds"],
		"Tempo: %d:%02d" % [int(stats["time"]) / 60, int(stats["time"]) % 60],
	]
	var rows := []
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 34)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		v.add_child(l)
		rows.append(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	var has_next: bool = stats["has_next"]
	var bn := Button.new()
	bn.text = "Próxima fase" if has_next else "Créditos"
	bn.pressed.connect(func(): next_requested.emit())
	hb.add_child(bn)
	var bm := Button.new()
	bm.text = "Menu"
	bm.pressed.connect(func(): menu_requested.emit())
	hb.add_child(bm)
	UiTheme.juice_buttons(v)
	p.pivot_offset = Vector2(310, 200)
	p.scale = Vector2(0.4, 0.4)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i in rows.size():
		tw.tween_callback(func(): Sfx.play("pop", 1.0 + i * 0.15))
		tw.tween_property(rows[i], "modulate:a", 1.0, 0.18)
		tw.tween_interval(0.12)
	tw.tween_callback(func(): bn.grab_focus())
