class_name Hud
extends CanvasLayer
## Interface em jogo: vida, habilidades com recarga, grupo, titulo da sala, chefe, avisos.

var root: Control
var hp_bar: ProgressBar
var shield_bar: ProgressBar
var hp_text: Label
var dodge_box: HBoxContainer
var flask_label: Label
var skill_tiles: Dictionary = {}
var gold_label: Label
var shard_label: Label
var party_box: VBoxContainer
var room_label: Label
var wave_label: Label
var boss_panel: Control
var boss_bar: ProgressBar
var boss_name: Label
var boss_eid := -1
var prompt_label: Label
var toast_box: VBoxContainer
var vignette: ColorRect
var crosshair: Control
var revive_bar: ProgressBar
var inv_panel: PanelContainer
var inv_text: RichTextLabel
var host_label: Label
var help_panel: PanelContainer
var down_label: Label
var _vig := 0.0
var _party_t := 0.0

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Ui.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	Game.toast.connect(_toast)
	Game.room_changed.connect(_room_changed)
	Game.phase_changed.connect(_room_changed)
	Net.upnp_result.connect(func(_ok: bool, _ip: String) -> void: _update_host_label())

func bind_world(w: World) -> void:
	w.prompt_changed.connect(func(t: String) -> void: prompt_label.text = t)
	w.hurt.connect(func(f: float) -> void: _vig = minf(1.0, _vig + 0.35 + f * 2.0))
	w.revive_bar.connect(func(_t: Player, f: float) -> void:
		revive_bar.visible = f > 0.0 and f < 1.0
		revive_bar.value = f)
	w.room_event.connect(_room_event)

func _anchor(c: Control, preset: int, off: Vector2 = Vector2.ZERO) -> void:
	root.add_child(c)
	# cresce a partir da borda ancorada, para continuar no lugar quando o conteudo muda de tamanho
	c.set_anchors_preset(preset)
	var gh := Control.GROW_DIRECTION_BOTH
	var gv := Control.GROW_DIRECTION_BOTH
	if preset in [Control.PRESET_TOP_LEFT, Control.PRESET_BOTTOM_LEFT, Control.PRESET_CENTER_LEFT]:
		gh = Control.GROW_DIRECTION_END
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT]:
		gh = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_CENTER_TOP]:
		gv = Control.GROW_DIRECTION_END
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		gv = Control.GROW_DIRECTION_BEGIN
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y

func _build() -> void:
	# vinheta de dano
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nvoid fragment() {\n\tvec2 p = UV * 2.0 - 1.0;\n\tfloat v = smoothstep(0.45, 1.25, length(p));\n\tCOLOR = vec4(0.9, 0.12, 0.16, v * amount);\n}"
	sm.shader = sh
	vignette.material = sm
	root.add_child(vignette)
	# mira
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.draw.connect(func() -> void:
		crosshair.draw_circle(Vector2.ZERO, 5.0, Color(0.1, 0.08, 0.16, 0.6))
		crosshair.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.9)))
	root.add_child(crosshair)
	# --- vida (baixo, esquerda)
	var hp_panel := Ui.panel(Color("231e3fd8"), 18, Color("5a4f96"), 2, 14)
	hp_panel.custom_minimum_size = Vector2(380, 0)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hp_panel.add_child(hv)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(350, 28)
	hv.add_child(stack)
	hp_bar = Ui.bar(Color("ef5a6a"), Color("16122b"), 28)
	hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(hp_bar)
	shield_bar = Ui.bar(Color("7df9ffcc"), Color(0, 0, 0, 0), 28)
	shield_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(shield_bar)
	hp_text = Ui.label("100 / 100", 18, Color.WHITE, true)
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_color_override("font_outline_color", Ui.INK)
	hp_text.add_theme_constant_override("outline_size", 6)
	stack.add_child(hp_text)
	var row := HBoxContainer.new()
	hv.add_child(row)
	row.add_child(Ui.label("Esquiva", 15, Ui.MUTED))
	dodge_box = HBoxContainer.new()
	dodge_box.add_theme_constant_override("separation", 4)
	row.add_child(dodge_box)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(Ui.icon_rect("potion", 22, Color("8dffb0")))
	flask_label = Ui.label("0  [V]", 16, Ui.TEXT, true)
	row.add_child(flask_label)
	_anchor(hp_panel, Control.PRESET_BOTTOM_LEFT, Vector2(24, -24))
	# --- habilidades (baixo, centro)
	var sk := HBoxContainer.new()
	sk.add_theme_constant_override("separation", 12)
	for s in Player.SLOTS:
		var tile := _skill_tile(s)
		sk.add_child(tile["root"])
		skill_tiles[s] = tile
	_anchor(sk, Control.PRESET_CENTER_BOTTOM, Vector2(0, -22))
	# --- aviso de interacao
	prompt_label = Ui.title("", 26, Color.WHITE)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size = Vector2(900, 0)
	_anchor(prompt_label, Control.PRESET_CENTER_BOTTOM, Vector2(0, -150))
	revive_bar = Ui.bar(Ui.GOLD, Color("16122b"), 16)
	revive_bar.custom_minimum_size = Vector2(260, 16)
	revive_bar.visible = false
	_anchor(revive_bar, Control.PRESET_CENTER_BOTTOM, Vector2(0, -200))
	down_label = Ui.title("", 40, Color("ff7a7a"))
	down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_label.custom_minimum_size = Vector2(900, 0)
	_anchor(down_label, Control.PRESET_CENTER, Vector2(0, -120))
	# --- ouro e fragmentos (cima, direita)
	var money := Ui.panel(Color("231e3fd8"), 16, Color("5a4f96"), 2, 10)
	var mh := HBoxContainer.new()
	money.add_child(mh)
	mh.add_child(Ui.icon_rect("coins", 26, Ui.GOLD))
	gold_label = Ui.label("0", 22, Ui.GOLD, true)
	mh.add_child(gold_label)
	mh.add_child(Ui.icon_rect("shard", 26, Ui.CYAN))
	shard_label = Ui.label("0", 22, Ui.CYAN, true)
	mh.add_child(shard_label)
	_anchor(money, Control.PRESET_TOP_RIGHT, Vector2(-24, 20))
	money.z_index = 1
	# --- grupo (cima, esquerda)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 8)
	_anchor(party_box, Control.PRESET_TOP_LEFT, Vector2(24, 20))
	# --- sala / onda (cima, centro)
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.custom_minimum_size = Vector2(900, 0)
	room_label = Ui.title("", 28, Color("f4efe6"))
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(room_label)
	wave_label = Ui.label("", 18, Ui.MUTED, true)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(wave_label)
	boss_panel = VBoxContainer.new()
	boss_name = Ui.title("Guardião Cristalino", 24, Ui.CYAN)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_name)
	boss_bar = Ui.bar(Color("c86bff"), Color("16122b"), 22)
	boss_bar.custom_minimum_size = Vector2(700, 22)
	boss_panel.add_child(boss_bar)
	boss_panel.visible = false
	top.add_child(boss_panel)
	toast_box = VBoxContainer.new()
	toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(toast_box)
	_anchor(top, Control.PRESET_CENTER_TOP, Vector2(0, 16))
	# --- info do host (vila)
	host_label = Ui.label("", 16, Ui.MUTED)
	host_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host_label.custom_minimum_size = Vector2(520, 0)
	_anchor(host_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-24, -24))
	# --- inventario (Tab)
	inv_panel = Ui.panel()
	inv_panel.custom_minimum_size = Vector2(560, 300)
	inv_text = RichTextLabel.new()
	inv_text.bbcode_enabled = true
	inv_text.fit_content = true
	inv_text.custom_minimum_size = Vector2(520, 0)
	inv_text.add_theme_font_override("bold_font", Ui.font_bold())
	inv_panel.add_child(inv_text)
	inv_panel.visible = false
	_anchor(inv_panel, Control.PRESET_CENTER_RIGHT, Vector2(-24, 0))
	# --- ajuda de controles
	help_panel = Ui.panel(Color("231e3fd8"), 16, Color("5a4f96"), 2, 14)
	var help := Ui.label("WASD mover  ·  Mouse mirar  ·  Espaço pular  ·  Shift esquivar\nMouse Esq. atacar  ·  Mouse Dir. especial  ·  Q / R habilidades  ·  F suprema\nE interagir  ·  V frasco  ·  1-4 emotes  ·  Tab itens  ·  Esc menu", 16, Ui.MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_panel.add_child(help)
	_anchor(help_panel, Control.PRESET_CENTER_TOP, Vector2(0, 64))

func _skill_tile(slot: String) -> Dictionary:
	var size := 76 if slot != "ult" else 86
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size + 22)
	var tile := Ui.icon_tile("star", size, Color("5a4f96"))
	tile.position = Vector2.ZERO
	holder.add_child(tile)
	var cd := ColorRect.new()
	cd.color = Color(0.05, 0.04, 0.12, 0.72)
	cd.size = Vector2(size, size)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cd)
	var cd_text := Ui.title("", 26, Color.WHITE)
	cd_text.size = Vector2(size, size)
	cd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(cd_text)
	var key := Ui.title(str(Controls.LABELS.get(Player.SLOT_ACTIONS[slot], "")), 15, Color.WHITE)
	key.position = Vector2(0, size + 1)
	key.size = Vector2(size, 20)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(key)
	return {"root": holder, "tile": tile, "cd": cd, "cd_text": cd_text, "size": size, "id": ""}

func _toast(text: String, color: Color) -> void:
	var l := Ui.title(text, 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	if toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()

func _room_changed() -> void:
	boss_panel.visible = false
	boss_eid = -1
	wave_label.text = ""
	if Game.phase == Game.Phase.HUB:
		room_label.text = "Vila do Farol"
		Sfx.set_music("hub")
	elif Game.phase == Game.Phase.RUN:
		var b: Dictionary = DB.BIOMES.get(str(Game.room.get("biome", "forest")), {})
		room_label.text = "%s  ·  %s  ·  Sala %d/%d" % [str(b.get("name", "")), str(DB.ROOM_NAMES.get(str(Game.room.get("type", "")), "")),
			int(Game.run.get("step", 0)) + 1, (Game.run.get("plan", []) as Array).size()]
		Sfx.set_music("boss" if Game.room.get("type", "") == "boss" else "combat")
	_update_host_label()
	help_panel.visible = Game.phase == Game.Phase.HUB

func _update_host_label() -> void:
	if Game.phase != Game.Phase.HUB or not Net.hosting:
		host_label.text = ""
		return
	var t := "Sala aberta na porta %d (UDP)\nRede local: %s" % [Net.port, ", ".join(Net.local_ips())]
	if Net.external_ip != "":
		t += "\nInternet: %s  %s" % [Net.external_ip, "(porta aberta por UPnP)" if Net.upnp_ok else "(abra a porta no roteador)"]
	host_label.text = t

func _room_event(kind: String, data: Dictionary) -> void:
	match kind:
		"wave":
			wave_label.text = "Onda %d de %d" % [int(data["i"]), int(data["n"])]
		"clear":
			wave_label.text = "Sala vencida! Escolha a recompensa e entre num portal."
		"boss":
			boss_eid = int(data.get("eid", -1))
			boss_panel.visible = true
		"boss_dead":
			boss_panel.visible = false
			wave_label.text = "O Guardião caiu!"
		"boss_phase":
			_toast("O Guardião se enfurece!", Color("ff7ad5"))

func _process(delta: float) -> void:
	visible = Game.phase != Game.Phase.MENU
	if not visible:
		return
	var me: Player = Game.me()
	if me == null:
		return
	hp_bar.value = clampf(me.hp / maxf(me.max_hp, 1.0), 0.0, 1.0)
	shield_bar.value = clampf(me.shield / maxf(me.max_hp, 1.0), 0.0, 1.0)
	hp_text.text = "%d / %d" % [int(ceil(me.hp)), int(me.max_hp)]
	gold_label.text = str(me.gold)
	shard_label.text = str(int(Save.data["shards"]))
	flask_label.text = "%d  [V]" % me.flasks
	var maxd := int(me.stats.get("dodges", 1))
	if dodge_box.get_child_count() != maxd:
		Ui.clear(dodge_box)
		for i in maxd:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(26, 12)
			dodge_box.add_child(pip)
	for i in dodge_box.get_child_count():
		var on := i < me.dodge_charges
		(dodge_box.get_child(i) as Panel).add_theme_stylebox_override("panel", Ui.box(Ui.CYAN if on else Color("3a3360"), 6, Ui.INK, 2, 0))
	for s in Player.SLOTS:
		var tile: Dictionary = skill_tiles[s]
		var id: String = me.slots.get(s, "")
		if tile["id"] != id and DB.SKILLS.has(id):
			tile["id"] = id
			var def: Dictionary = DB.SKILLS[id]
			var col: Color = Color(str(DB.CLASSES[me.cls]["color"])) if not def.get("spell", false) else DB.RARITY_COLORS[int(def.get("rarity", 0))]
			var pc: PanelContainer = tile["tile"]
			pc.add_theme_stylebox_override("panel", Ui.box(col.darkened(0.5), 16, col, 3, 8))
			(pc.get_child(0) as TextureRect).texture = Ui.icon(str(def["icon"]))
			pc.tooltip_text = "%s\n%s" % [def["name"], def["desc"]]
		var cd: float = me.cds.get(s, 0.0)
		var cdm: float = maxf(me.cd_max.get(s, 1.0), 0.01)
		var r: ColorRect = tile["cd"]
		var sz: float = tile["size"]
		var f := clampf(cd / cdm, 0.0, 1.0) if cd > 0.0 else 0.0
		r.size = Vector2(sz, sz * f)
		r.position = Vector2(0, sz * (1.0 - f))
		(tile["cd_text"] as Label).text = ("%.0f" % ceil(cd)) if cd > 0.5 else ""
	_vig = maxf(0.0, _vig - delta * 1.8)
	var low := 0.35 * (1.0 - smoothstep(0.0, 0.3, me.hp / maxf(me.max_hp, 1.0))) * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.006))
	(vignette.material as ShaderMaterial).set_shader_parameter("amount", clampf(_vig + (low if not me.in_hub else 0.0), 0.0, 1.0))
	crosshair.visible = not Game.paused_ui and me.alive()
	down_label.text = "Você caiu. Aguarde um aliado." if me.is_down() else ""
	if boss_panel.visible and Game.world.enemies.has(boss_eid):
		var b: Enemy = Game.world.enemies[boss_eid]
		boss_bar.value = clampf(b.hp / b.max_hp, 0.0, 1.0)
	_party_t -= delta
	if _party_t <= 0.0:
		_party_t = 0.25
		_update_party()
	inv_panel.visible = Input.is_action_pressed("inventory") and not Game.paused_ui
	if inv_panel.visible:
		_update_inventory(me)

func _update_party() -> void:
	var others: Array = []
	for p: Player in Game.world.all_players():
		if not p.is_local:
			others.append(p)
	if party_box.get_child_count() != others.size():
		Ui.clear(party_box)
		for p: Player in others:
			var pc := Ui.panel(Color("231e3fd0"), 12, Color(DB.CLASSES[p.cls]["color"]), 2, 8)
			pc.custom_minimum_size = Vector2(230, 0)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 3)
			pc.add_child(v)
			v.add_child(Ui.label("", 17, Ui.TEXT, true))
			v.add_child(Ui.bar(Color("ef5a6a"), Color("16122b"), 12))
			party_box.add_child(pc)
		return
	for i in others.size():
		var p: Player = others[i]
		var v: VBoxContainer = party_box.get_child(i).get_child(0)
		(v.get_child(0) as Label).text = "%s  ·  %s%s" % [p.info.get("name", "?"), DB.CLASSES[p.cls]["name"], "  (caído)" if p.is_down() else ""]
		(v.get_child(1) as ProgressBar).value = clampf(p.hp / maxf(p.max_hp, 1.0), 0.0, 1.0)

func _update_inventory(me: Player) -> void:
	var t := "[b][color=#ffd36b]%s[/color][/b]   Ataque %d   Crítico %d%%   Abates %d\n\n" % [DB.CLASSES[me.cls]["name"],
		int(me.stats["atk"]), int(float(me.stats["crit"]) * 100.0), me.kills]
	t += "[b]Bênçãos[/b]\n"
	if me.boons.is_empty():
		t += "[color=#b0a8cc]Nenhuma ainda.[/color]\n"
	for id in me.boons:
		var d: Dictionary = DB.BOONS[id]
		t += "• %s %s  [color=#b0a8cc]%s[/color]\n" % [d["name"], "I".repeat(int(me.boons[id])), d["desc"]]
	t += "\n[b]Relíquias[/b]\n"
	if me.relics.is_empty():
		t += "[color=#b0a8cc]Nenhuma ainda.[/color]\n"
	for id in me.relics:
		var d2: Dictionary = DB.RELICS[id]
		t += "• [color=#%s]%s[/color]  [color=#b0a8cc]%s[/color]\n" % [DB.RARITY_COLORS[int(d2["rarity"])].to_html(false), d2["name"], d2["desc"]]
	inv_text.text = t
