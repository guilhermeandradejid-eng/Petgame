class_name UiTheme
## Rounded, chunky, colorful UI theme built in code.

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")
const INK := Color(0.2, 0.09, 0.27)
const CREAM := Color(1.0, 0.97, 0.9)
const ACCENT := Color(1.0, 0.55, 0.32)


static func box(bg: Color, radius := 22, border := 0, border_color := INK, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = Color(0.15, 0.05, 0.2, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	s.anti_aliasing = true
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 30
	t.set_stylebox("normal", "Button", box(CREAM, 26, 4))
	t.set_stylebox("hover", "Button", box(Color(1.0, 0.86, 0.6), 26, 4))
	t.set_stylebox("pressed", "Button", box(Color(1.0, 0.7, 0.45), 26, 4))
	t.set_stylebox("focus", "Button", box(Color(1, 1, 1, 0), 26, 6, ACCENT))
	t.set_stylebox("disabled", "Button", box(Color(0.8, 0.78, 0.82), 26, 4, Color(0.5, 0.45, 0.55)))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.4, 0.5))
	t.set_font_size("font_size", "Button", 32)
	t.set_stylebox("panel", "PanelContainer", box(Color(1.0, 0.97, 0.92, 0.94), 30, 5))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(1, 1, 1))
	return t


static func outlined(text: String, size: int, color := Color.WHITE, outline := 12, outline_color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", outline_color)
	l.add_theme_color_override("font_shadow_color", Color(0.1, 0.02, 0.15, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Elastic "pop" used on buttons and counters (anticipation + overshoot).
static func pop(c: Control, amount := 1.25) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 0.9, 0.05)
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Gives every button in `root` hover/focus wobble and click sounds.
static func juice_buttons(root: Node) -> void:
	for b in root.find_children("*", "Button", true, false):
		var btn := b as Button
		btn.focus_entered.connect(func():
			Sfx.play("tick", 1.4, -8.0)
			pop(btn, 1.08))
		btn.mouse_entered.connect(func(): btn.grab_focus())
		btn.pressed.connect(func(): Sfx.play("pop", 1.0, -4.0))
