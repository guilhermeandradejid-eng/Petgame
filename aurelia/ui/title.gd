extends Control
## Title / connection screen: Solo, Host, Join(IP). Also honours --solo / --host / --join=IP.

var _addr: LineEdit
var _status: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420 if Game.touch_mode else 360, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var t := Label.new()
	t.text = "AURELIA"
	t.add_theme_font_size_override("font_size", 64)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.modulate = Color(0.75, 1.0, 0.9)
	box.add_child(t)
	var sub := Label.new()
	sub.text = "co-op action RPG  -  test glade"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.7)
	box.add_child(sub)
	box.add_child(_button("Solo", _on_solo))
	_addr = LineEdit.new()
	if OS.has_feature("web"):
		# browsers cannot open UDP sockets: ENet host/join needs the desktop build
		var note := Label.new()
		note.text = "Online co-op needs the desktop build.\nThis web build is solo-only (great for testing touch controls)."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.modulate = Color(1, 1, 1, 0.65)
		box.add_child(note)
		_status = Label.new()
		box.add_child(_status)
		return
	box.add_child(_button("Host co-op game", _on_host))
	_addr.text = "127.0.0.1"
	_addr.placeholder_text = "host address"
	box.add_child(_addr)
	box.add_child(_button("Join", _on_join))
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	Net.joined.connect(_enter_world)
	Net.join_failed.connect(func(): _status.text = "Could not connect.")
	# command-line shortcuts (used by the automated tests)
	if Game.args.has("solo"):
		_on_solo.call_deferred()
	elif Game.args.has("host"):
		_on_host.call_deferred()
	elif Game.args.has("join"):
		_addr.text = Game.args["join"] if Game.args["join"] != "1" else "127.0.0.1"
		_on_join.call_deferred()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64 if Game.touch_mode else 40)
	b.add_theme_font_size_override("font_size", 26 if Game.touch_mode else 16)
	b.pressed.connect(cb)
	return b


func _on_solo() -> void:
	Net.go_offline()
	_enter_world()


func _on_host() -> void:
	if Net.host() != OK:
		_status.text = "Could not host (port busy?)."
		return
	_enter_world()


func _on_join() -> void:
	_status.text = "Connecting..."
	if Net.join(_addr.text.strip_edges()) != OK:
		_status.text = "Invalid address."


func _enter_world() -> void:
	get_tree().change_scene_to_file("res://world/world.tscn")
