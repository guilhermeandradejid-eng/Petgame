class_name Multi
extends Node
## Multijogador local (até 4 na mesma tela): tela de entrada dos jogadores e tela dividida.
## Cada quadro é um SubViewport que desenha o MESMO mundo 3D com a câmera do seu jogador; a câmera usa
## exatamente a lógica da câmera do jogo solo (loops, espirais, nitro), trocando o "estado" de câmera.

const RIG_FIELDS := ["cam_pos", "cam_yaw", "cam_pitch", "cam_mode", "cam_mode_t", "cam_loop", "cam_loop_u", "cam_kick",
	"view_h", "nitro_zoom", "zoom_kick", "trauma", "shake_t", "cam", "player", "cam_focus", "focus_t", "cam_size_mul"]
const CARS := Car.PLAYABLE
const CAR_NAMES := Car.CAR_NAME

var game: Node
var hud: Hud
var split := false
var layer: CanvasLayer
var cells: Array = []
var main_cam: Camera3D
# tela de entrada
var join_scr: Control
var slots: Array = []      # [{"dev", "car"}]
var slot_boxes: Array = []
var hint_l: Label


func setup(g: Node, h: Hud) -> void:
	game = g
	hud = h
	main_cam = g.cam
	layer = CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	_build_join()


# ------------------------------------------------------------------ tela de entrada
func _build_join() -> void:
	join_scr = hud._screen(0.78)
	var v := hud._vcenter(join_scr, 14)
	UI.title(v, "LOCAL", 50, UI.HOT, HORIZONTAL_ALIGNMENT_CENTER)
	# como entrar, em ícones de tecla/botão (sem parágrafo)
	var how := HBoxContainer.new()
	how.alignment = BoxContainer.ALIGNMENT_CENTER
	how.add_theme_constant_override("separation", 18)
	v.add_child(how)
	for k in ["A / START", "ESPAÇO", "ENTER"]:
		var chip := PanelContainer.new()
		var cs := UI.box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.2), 1, 0.12, 3, Color(0, 0, 0, 0.5), 6)
		cs.content_margin_left = 12
		cs.content_margin_right = 12
		cs.content_margin_top = 4
		chip.add_theme_stylebox_override("panel", cs)
		how.add_child(chip)
		var kl := UI.text(chip, k, 15, UI.TEXT)
		kl.add_theme_font_override("font", UI.display_it)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for i in 4:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(260, 250)
		var ps := UI.box(Color(0.08, 0.07, 0.15, 0.92), Color(game.HUMAN_COLORS[i]), 3, 0.06, 0, Color(0, 0, 0, 0), 12)
		ps.border_width_top = 10
		p.add_theme_stylebox_override("panel", ps)
		row.add_child(p)
		var c := Control.new()
		c.custom_minimum_size = Vector2(236, 226)
		p.add_child(c)
		var pl := UI.title(c, "P%d" % (i + 1), 34, Color(game.HUMAN_COLORS[i]))
		pl.position = Vector2(6, 0)
		var dev := UI.text(c, "", 14, UI.MUTED)
		dev.add_theme_font_override("font", UI.body_bold)
		dev.position = Vector2(84, 14)
		var th := TextureRect.new()
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.position = Vector2(0, 52)
		th.size = Vector2(236, 120)
		c.add_child(th)
		var nm := UI.title(c, "", 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		nm.position = Vector2(0, 178)
		nm.size = Vector2(236, 30)
		var la := Icon.make("back", 26, UI.HOT)
		la.position = Vector2(4, 180)
		c.add_child(la)
		var ra := Icon.make("play", 22, UI.HOT)
		ra.position = Vector2(208, 182)
		c.add_child(ra)
		var wait := Icon.make("play", 54, Color(1, 1, 1, 0.25))
		wait.position = Vector2(91, 86)
		c.add_child(wait)
		slot_boxes.append({"dev": dev, "thumb": th, "name": nm, "arrows": [la, ra], "wait": wait})
	hint_l = hud._label(18, Color("#2ee6ff"), Color(0, 0, 0, 0.6), v)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_theme_constant_override("separation", 16)
	v.add_child(bot)
	var back := UI.icon_button("VOLTAR", "back", false, 18, 200, 56)
	back.pressed.connect(func(): game.set_solo(); hud.show_screen("menu"))
	bot.add_child(back)
	var go := UI.icon_button("PISTA", "flag", true, 24, 280, 60)
	go.pressed.connect(_go)
	bot.add_child(go)
	hud.extra_screens["local"] = join_scr
	join_scr.visible = false
	_refresh_join()


func open_join() -> void:
	slots.clear()
	# quem já tem controle conectado não precisa apertar nada se for o único: entra o P1 no teclado WASD
	_refresh_join()
	hud.show_screen("local")


func _go() -> void:
	if slots.is_empty():
		hint_l.text = "Ninguém entrou ainda!"
		return
	var players: Array = []
	for i in slots.size():
		players.append({"dev": slots[i].dev, "car": slots[i].car, "name": "P%d" % (i + 1), "color": String(game.save.get("color", game.HUMAN_COLORS[0])) if i == 0 else game.HUMAN_COLORS[i], "local": true})
	game.session = {"kind": "local" if players.size() > 1 else "solo", "players": players}
	if players.size() == 1:
		game.session.players[0].name = "VOCÊ"
	hud.show_screen("tracks")


func _refresh_join() -> void:
	for i in 4:
		var sb: Dictionary = slot_boxes[i]
		var on := i < slots.size()
		(sb.wait as Control).visible = not on
		for ar in sb.arrows:
			(ar as Control).visible = on
		(sb.thumb as TextureRect).visible = on
		if on:
			var sl: Dictionary = slots[i]
			(sb.dev as Label).text = PInput.label(sl.dev)
			(sb.name as Label).text = String(CAR_NAMES[sl.car])
			if hud.show3d:
				hud.show3d.thumb("car:" + String(sl.car), sb.thumb)
		else:
			(sb.dev as Label).text = ""
			(sb.name as Label).text = ""
	if hint_l:
		hint_l.text = "%d PRONTO%s" % [slots.size(), "S" if slots.size() != 1 else ""] if slots.size() > 0 else ""


func _slot_of(dev: String) -> int:
	for i in slots.size():
		if slots[i].dev == dev:
			return i
	return -1


func _input(ev: InputEvent) -> void:
	if join_scr == null or not join_scr.visible:
		return
	var dev := PInput.join_device(ev)
	if dev != "":
		var i := _slot_of(dev)
		if i < 0 and slots.size() < 4:
			slots.append({"dev": dev, "car": CARS[slots.size() % CARS.size()]})
			game.sfx.play("coin", -6.0)
			_refresh_join()
		elif i >= 0 and (ev is InputEventKey or (ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_START)):
			_go()
		get_viewport().set_input_as_handled()
		return
	# troca de carro / sair
	var d := ""
	var step := 0
	var leave := false
	if ev is InputEventJoypadButton and ev.pressed:
		d = "joy%d" % ev.device
		if ev.button_index == JOY_BUTTON_DPAD_LEFT:
			step = -1
		elif ev.button_index == JOY_BUTTON_DPAD_RIGHT:
			step = 1
		elif ev.button_index == JOY_BUTTON_B:
			leave = true
	elif ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_LEFT_X and absf(ev.axis_value) > 0.7:
		d = "joy%d" % ev.device
		var k := "_ax_%s" % d
		if not get_meta(k, false):
			step = int(signf(ev.axis_value))
			set_meta(k, true)
	elif ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_LEFT_X and absf(ev.axis_value) < 0.3:
		set_meta("_ax_joy%d" % ev.device, false)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		for kd in PInput.KB:
			var m: Dictionary = PInput.KB[kd]
			if ev.physical_keycode == m.left:
				d = kd
				step = -1
			elif ev.physical_keycode == m.right:
				d = kd
				step = 1
			elif ev.physical_keycode == m.drop:
				d = kd
				leave = true
	if d == "":
		return
	var si := _slot_of(d)
	if si < 0:
		return
	if leave:
		slots.remove_at(si)
	elif step != 0:
		var ci := CARS.find(slots[si].car)
		slots[si].car = CARS[posmod(ci + step, CARS.size())]
	_refresh_join()
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ tela dividida
func setup_views() -> void:
	for c in cells:
		(c.root as Node).queue_free()
	cells.clear()
	var n: int = game.locals.size()
	if n <= 1:
		_set_split(false)
		return
	_set_split(true)
	var count := 2 if n == 2 else 4
	for i in count:
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(root)
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cont)
		var vp := SubViewport.new()
		vp.world_3d = game.get_viewport().world_3d
		vp.msaa_3d = Viewport.MSAA_2X
		vp.audio_listener_enable_3d = false
		vp.handle_input_locally = false
		cont.add_child(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.near = 1.0
		cam.far = 500.0
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		vp.add_child(cam)
		cam.current = true
		var idx := i if i < n else -1   # quadro extra (3 jogadores): câmera de "torcida" no líder
		var car: Car = game.locals[idx].car if idx >= 0 else game.player
		var rig := {"cam_pos": car.global_position, "cam_yaw": game.CAM_YAW, "cam_pitch": game.CAM_PITCH, "cam_mode": "",
			"cam_mode_t": 0.0, "cam_loop": {}, "cam_loop_u": 1.0, "cam_kick": Vector3.ZERO, "view_h": 28.0, "nitro_zoom": 0.0,
			"zoom_kick": 0.0, "trauma": 0.0, "shake_t": 0.0, "cam": cam, "player": car, "cam_focus": null, "focus_t": 0.0,
			"cam_size_mul": 0.82 if count == 4 else 1.0}
		var ui := _cell_ui(root, idx)
		cells.append({"root": root, "cont": cont, "vp": vp, "cam": cam, "rig": rig, "idx": idx, "ui": ui, "pop_t": 0.0})
	# P1 usa as variáveis de câmera do jogo; a câmera dele passa a ser a do 1º quadro
	game.cam = cells[0].cam
	game.cam_size_mul = cells[0].rig.cam_size_mul
	_layout()


func _set_split(on: bool) -> void:
	split = on
	game.get_viewport().disable_3d = on
	hud.post.visible = not on
	if not on:
		game.cam = main_cam
		game.cam_size_mul = 1.0
		main_cam.current = true
	for nd in hud.race_nodes:
		if nd != hud.feed:
			(nd as CanvasItem).set_meta("split_hide", on)
	hud.touch.set_meta("split_hide", on)


func _layout() -> void:
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var n := cells.size()
	for i in n:
		var r: Control = cells[i].root
		var sz := Vector2(vs.x / 2.0, vs.y) if n == 2 else vs / 2.0
		var pos := Vector2((i % 2) * sz.x, 0.0) if n == 2 else Vector2((i % 2) * sz.x, (i / 2) * sz.y)
		r.position = pos + Vector2(1, 1)
		r.size = sz - Vector2(2, 2)


func _cell_ui(root: Control, idx: int) -> Dictionary:
	var ui := {}
	var top := hud._label(22, Color.WHITE, Color(0, 0, 0, 0.7), root)
	top.position = Vector2(10, 6)
	ui.top = top
	var spd := hud._label(18, Color.WHITE, Color(0, 0, 0, 0.7), root)
	spd.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	spd.offset_left = -170
	spd.offset_right = -10
	spd.offset_top = 8
	spd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.spd = spd
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar_bg.offset_left = 10
	bar_bg.offset_top = -52
	bar_bg.offset_right = 230
	bar_bg.offset_bottom = -38
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Color("#7dff6a")
	bar.position = Vector2(2, 2)
	bar.size = Vector2(216, 10)
	bar_bg.add_child(bar)
	ui.bar = bar
	var ammo := hud._label(16, Color("#ffcf33"), Color(0, 0, 0, 0.7), root)
	ammo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ammo.offset_left = 10
	ammo.offset_top = -34
	ammo.offset_bottom = -8
	ui.ammo = ammo
	var msg := hud._label(30, Color.WHITE, Color("#ff2d55"), root)
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.offset_left = -300
	msg.offset_right = 300
	msg.offset_top = -90
	msg.offset_bottom = -40
	msg.modulate.a = 0.0
	ui.msg = msg
	# HUD do quadro desenhado no estilo da identidade (placa de posição, blindagem em segmentos e munição com ícones)
	var pan := Control.new()
	pan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pan.draw.connect(_draw_cell.bind(pan))
	root.add_child(pan)
	ui.pan = pan
	if idx < 0:
		top.text = "LÍDER"
		bar_bg.visible = false
	else:
		for nd in [top, spd, bar_bg, ammo]:
			nd.visible = false
	# remove do race_nodes do HUD (estes nós são do quadro, não da tela cheia)
	for nd in [top, spd, ammo, msg]:
		hud.race_nodes.erase(nd)
	return ui


func pop(idx: int, text: String, col: Color, big := false) -> void:
	for c in cells:
		if c.idx == idx:
			var l: Label = c.ui.msg
			l.text = text
			l.label_settings.font_color = col
			l.label_settings.font_size = 40 if big else 26
			l.modulate.a = 1.0
			c.pop_t = 1.6 if big else 1.1


func shake(idx: int, a: float) -> void:
	for c in cells:
		if c.idx == idx:
			c.rig.trauma = minf(1.0, float(c.rig.trauma) + a)


## câmeras dos quadros 2..4 (o 1º é a câmera do próprio jogo) e HUD de cada quadro
func update(rdt: float) -> void:
	if not split:
		return
	_layout()
	var order: Array = game.standings()
	for i in range(1, cells.size()):
		var c: Dictionary = cells[i]
		if c.idx < 0 and order.size() > 0:
			c.rig.player = order[0]
		var saved := {}
		for f in RIG_FIELDS:
			saved[f] = game.get(f)
			game.set(f, c.rig[f])
		game._camera(rdt)
		for f in RIG_FIELDS:
			c.rig[f] = game.get(f)
			game.set(f, saved[f])
	for c in cells:
		var ui: Dictionary = c.ui
		c.pop_t = maxf(0.0, float(c.pop_t) - rdt)
		(ui.msg as Label).modulate.a = clampf(float(c.pop_t) / 0.3, 0.0, 1.0)
		if c.idx < 0:
			continue
		var car: Car = game.locals[c.idx].car
		var pl: int = order.find(car) + 1
		(ui.pan as Control).set_meta("car", car)
		(ui.pan as Control).set_meta("pl", pl)
		(ui.pan as Control).queue_redraw()
		(ui.top as Label).text = "%s · %dº · VOLTA %d/%d" % [car.display_name, pl, clampi(car.lap + 1, 1, game.LAPS), game.LAPS]
		(ui.top as Label).label_settings.font_color = car.color.lightened(0.35)
		(ui.spd as Label).text = "%d km/h" % int(car.linear_velocity.length() * 3.6 * 1.25)
		var hp := clampf(car.health / car.max_health, 0.0, 1.0)
		(ui.bar as ColorRect).size.x = 216.0 * hp
		(ui.bar as ColorRect).color = Color("#7dff6a") if hp > 0.5 else (Color("#ffcf33") if hp > 0.25 else Color("#ff2d55"))
		var fr: String = Car.LBL_F.get(car.front_type, "TIRO")
		var rr: String = Car.LBL_R.get(car.rear_type, "MINA")
		var tx := "%s %d · %s %d · %s %d" % [fr, car.ammo_f, rr, car.ammo_r, String(Car.NITRO[car.nitro_type].label), car.nitro_ch]
		if car.special_type != "":
			tx += " · %s %d" % [String(Car.SPECIAL[car.special_type].label), car.spec_ch]
		(ui.ammo as Label).text = tx


func _draw_cell(pan: Control) -> void:
	if not pan.has_meta("car"):
		return
	var car: Car = pan.get_meta("car")
	if not is_instance_valid(car):
		return
	var pl := int(pan.get_meta("pl", 1))
	var sk := 10.0
	# placa: posição grande, faixa na cor do jogador, nome e volta
	pan.draw_colored_polygon(PackedVector2Array([Vector2(8 + sk, 8), Vector2(80 + sk, 8), Vector2(80, 56), Vector2(8, 56)]), Color(0.06, 0.05, 0.11, 0.8))
	pan.draw_colored_polygon(PackedVector2Array([Vector2(8 + sk, 8), Vector2(14 + sk, 8), Vector2(14, 56), Vector2(8, 56)]), car.color)
	var w := hud._outlined(pan, UI.display_it, Vector2(26, 50), str(pl), 38, Color.WHITE, 5)
	hud._outlined(pan, UI.display_it, Vector2(27 + w, 32), "º", 16, UI.HOT, 3)
	hud._outlined(pan, UI.display_it, Vector2(100, 28), car.display_name, 18, car.color.lightened(0.35), 4)
	Icon.paint(pan, "flag", Rect2(100, 34, 18, 18), UI.HOT)
	hud._outlined(pan, UI.display_it, Vector2(122, 51), "%d/%d" % [clampi(car.lap + 1, 1, game.LAPS), game.LAPS], 16, Color.WHITE, 4)
	# velocidade (canto direito)
	var sp := str(int(car.linear_velocity.length() * 3.6 * 1.25))
	var sw := UI.display_it.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	hud._outlined(pan, UI.body_bold, Vector2(pan.size.x - 46, 30), "KM/H", 11, UI.MUTED, 3)
	hud._outlined(pan, UI.display_it, Vector2(pan.size.x - 52 - sw, 32), sp, 22, Color.WHITE, 4)
	# embaixo: blindagem e munição
	var y := pan.size.y - 58
	var hr := clampf(car.health / car.max_health, 0.0, 1.0)
	var hc := Color("#ff3048").lerp(Color("#5dff6a"), hr)
	pan.draw_colored_polygon(PackedVector2Array([Vector2(6, y - 6), Vector2(270, y - 6), Vector2(262, y + 44), Vector2(0, y + 44)]), Color(0.03, 0.02, 0.07, 0.55))
	Icon.paint(pan, "arm", Rect2(10, y - 2, 22, 22), hc)
	hud._seg_bar(pan, Rect2(38, y, 220, 14), 16, hr, hc)
	var x := 12.0
	var items: Array = [["atk", car.ammo_f, Color("#ff6a3a")], ["rear", car.ammo_r, UI.HOT], [car.nitro_type, car.nitro_ch, UI.INFO]]
	if car.front_type == "none":
		items.pop_front()
	if car.special_type != "":
		items.append([car.special_type, car.spec_ch, UI.OK])
	for it in items:
		var col: Color = it[2] if int(it[1]) > 0 else Color(1, 1, 1, 0.35)
		Icon.paint(pan, String(it[0]), Rect2(x, y + 20, 20, 20), col)
		x += 24.0 + hud._outlined(pan, UI.display_it, Vector2(x + 24, y + 37), str(int(it[1])), 16, col, 4) + 14.0
