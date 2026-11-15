class_name Windows
extends CanvasLayer
## Janelas do jogo: recompensa, loja, guarda-roupa, melhorias, classes, partida, resumo e pausa.
## Enquanto uma janela esta aberta o heroi nao recebe comandos e o mouse fica livre.

var root: Control
var dim: ColorRect
var holder: CenterContainer
var current := ""
var _bot_actions: Array = []
var _spot: Spot
var _wd_slot := "hair"
var _wd_grid: GridContainer
var _wd_colors: VBoxContainer
var _wd_info: Label
var _wd_buy: Button
var _wd_try := ""
var _wd_look: Dictionary = {}
var _summary: Dictionary = {}

func _ready() -> void:
	layer = 10
	Game.ui = self
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = Ui.theme()
	root.visible = false
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	holder = CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	Game.run_ended.connect(open_summary)
	Game.phase_changed.connect(func() -> void:
		if current != "" and current != "summary":
			close())

func is_open() -> bool:
	return current != ""

func _open(nm: String, dim_alpha: float = 0.55) -> VBoxContainer:
	Ui.clear(holder)
	_bot_actions = []
	current = nm
	root.visible = true
	dim.color.a = dim_alpha
	Game.paused_ui = true
	var pc := Ui.panel()
	holder.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	return v

func close() -> void:
	if current == "wardrobe":
		_wardrobe_close()
	current = ""
	root.visible = false
	Ui.clear(holder)
	Game.paused_ui = false
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if current == "":
			if Game.phase != Game.Phase.MENU:
				open_pause()
		elif current != "summary":
			close()
		get_viewport().set_input_as_handled()

func bot_act() -> void:
	if _bot_actions.size() > 0:
		(_bot_actions[randi() % _bot_actions.size()] as Callable).call()
	else:
		close()

func _header(v: VBoxContainer, text: String, sub: String = "") -> void:
	var t := Ui.title(text, 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := Ui.label(sub, 18, Ui.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)

# ------------------------------------------------------------------ recompensa
func _card(c: Dictionary, p: Player, w: int = 300) -> VBoxContainer:
	var rar := Rewards.rarity(c)
	var col: Color = DB.RARITY_COLORS[rar]
	var pc := Ui.panel(Color("2a2350"), 18, col, 3, 18)
	pc.custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	pc.add_child(v)
	var tile := Ui.icon_tile(Rewards.icon(c), 96, col)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tile)
	var kind_names := {"boon": "Bênção", "relic": "Relíquia", "spell": "Magia", "heal": "Consumível", "flask": "Consumível"}
	var tag := Ui.label("%s  ·  %s" % [kind_names.get(c["type"], ""), DB.RARITY_NAMES[rar]], 15, col, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var nm := Ui.label(Rewards.title(c), 24, Color.WHITE, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var d := Ui.label(Rewards.desc(c, p), 17, Ui.TEXT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(w - 40, 96)
	v.add_child(d)
	holder_add(v, pc)
	return v

func holder_add(v: VBoxContainer, pc: PanelContainer) -> void:
	v.set_meta("panel", pc)

func open_reward(kind: String, spot: Spot) -> void:
	var p: Player = Game.me()
	if p == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(Game.room.get("seed", 0)), Net.my_id(), kind, p.boons.size() + p.relics.size()])
	var choices := Rewards.roll(kind, p, rng, 3)
	if choices.is_empty():
		Game.world.spawn_coins(p.global_position, 40)
		if spot:
			spot.consume()
		return
	var titles := {"boon": "Escolha uma bênção", "relic": "Escolha uma relíquia", "spell": "Escolha uma magia"}
	var v := _open("reward")
	_header(v, str(titles.get(kind, "Recompensa")), "Cada jogador escolhe a sua.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for c: Dictionary in choices:
		var card := _card(c, p)
		row.add_child(card.get_meta("panel"))
		if c["type"] == "spell":
			var hb := HBoxContainer.new()
			hb.alignment = BoxContainer.ALIGNMENT_CENTER
			card.add_child(hb)
			for slot in ["q", "r"]:
				var b := Ui.button("Pôr no %s" % slot.to_upper(), 19)
				b.tooltip_text = "Substitui: %s" % DB.skill_name(p.slots[slot])
				var act := _pick.bind(c, slot, spot)
				b.pressed.connect(act)
				hb.add_child(b)
				_bot_actions.append(act)
		else:
			var b2 := Ui.button("Escolher", 21)
			var act2 := _pick.bind(c, "q", spot)
			b2.pressed.connect(act2)
			card.add_child(b2)
			_bot_actions.append(act2)
	var skip := Ui.button("Pular (+20 de ouro)", 18)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void:
		Game.world.spawn_coins(p.global_position, 20)
		if spot:
			spot.consume()
		close())
	v.add_child(skip)

func _pick(c: Dictionary, slot: String, spot: Spot) -> void:
	var p: Player = Game.me()
	if p:
		Rewards.apply(c, p, slot)
		Sfx.ui("pick")
		Fx.burst(p.global_position + Vector3(0, 1.0, 0), DB.RARITY_COLORS[Rewards.rarity(c)], 2.0)
		Game.toast.emit("%s: %s" % ["Você recebeu", Rewards.title(c)], DB.RARITY_COLORS[Rewards.rarity(c)])
	if spot:
		spot.consume()
	close()

# ------------------------------------------------------------------ loja
func open_shop(spot: Spot) -> void:
	var p: Player = Game.me()
	if p == null:
		return
	_spot = spot
	if not spot.data.has("stock"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(Game.room.get("seed", 0)), Net.my_id(), "shop"])
		var stock: Array = Rewards.roll("relic", p, rng, 2)
		stock.append_array(Rewards.roll("spell", p, rng, 1))
		stock.append_array(Rewards.roll("boon", p, rng, 1))
		stock.append({"type": "heal", "name": "Poção de Vida", "desc": "Cura 40% da vida máxima.", "icon": "potion", "v": 0.4})
		stock.append({"type": "flask", "name": "Frasco de Cura", "desc": "+1 frasco para usar quando quiser (tecla V).", "icon": "potion"})
		spot.data["stock"] = stock
	_shop_build()

func _shop_build() -> void:
	var p: Player = Game.me()
	var v := _open("shop")
	_header(v, "Mercador", "Seu ouro: %d" % p.gold)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	var stock: Array = _spot.data["stock"]
	for i in stock.size():
		var c: Dictionary = stock[i]
		var card := _card(c, p, 280)
		grid.add_child(card.get_meta("panel"))
		var price := Rewards.shop_price(c)
		if c.get("sold", false):
			var s := Ui.label("Vendido", 20, Ui.MUTED, true)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(s)
			continue
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(hb)
		var slots := ["q", "r"] if c["type"] == "spell" else ["q"]
		for slot in slots:
			var b := Ui.button(("%d ouro" % price) if slots.size() == 1 else "%s: %d" % [slot.to_upper(), price], 19)
			b.disabled = p.gold < price
			b.pressed.connect(_buy.bind(i, slot))
			hb.add_child(b)
	var cl := Ui.button("Fechar", 20)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(close)
	v.add_child(cl)

func _buy(i: int, slot: String) -> void:
	var p: Player = Game.me()
	var c: Dictionary = _spot.data["stock"][i]
	var price := Rewards.shop_price(c)
	if p.gold < price:
		Sfx.ui("ui_error")
		return
	p.gold -= price
	c["sold"] = true
	Rewards.apply(c, p, slot)
	Sfx.ui("ui_buy")
	_shop_build()

# ------------------------------------------------------------------ guarda-roupa
func open_wardrobe() -> void:
	var p: Player = Game.me()
	if p == null:
		return
	_wd_look = Save.data["look"].duplicate()
	_wd_try = ""
	Ui.clear(holder)
	_bot_actions = []
	current = "wardrobe"
	root.visible = true
	dim.color.a = 0.0
	Game.paused_ui = true
	Game.world.rig.orbit_mode = true
	Game.world.rig.orbit_angle = p.rotation.y + PI + 0.35
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(margin)
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pc := Ui.panel()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END
	pc.custom_minimum_size = Vector2(760, 0)
	margin.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(Ui.title("Guarda-roupa", 32))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(Ui.icon_rect("shard", 26, Ui.CYAN))
	_wd_info = Ui.label("", 22, Ui.CYAN, true)
	head.add_child(_wd_info)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var tab_icons := {"hair": "hair", "hat": "hat", "ears": "ears", "acc": "acc", "eyes": "eyes", "top": "top", "bottom": "bottom", "back": "back", "weapon": "weapon", "dye": "dye"}
	for s in DB.SLOT_ORDER + ["dye"]:
		var b := Button.new()
		b.icon = Ui.icon(str(tab_icons[s]))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(66, 60)
		b.tooltip_text = str(DB.SLOT_NAMES.get(s, "Cores"))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Sfx.ui("ui_click")
			_wd_slot = s
			_wardrobe_fill())
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	_wd_grid = GridContainer.new()
	_wd_grid.columns = 3
	_wd_grid.add_theme_constant_override("h_separation", 10)
	_wd_grid.add_theme_constant_override("v_separation", 10)
	inner.add_child(_wd_grid)
	_wd_colors = VBoxContainer.new()
	inner.add_child(_wd_colors)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	var rot := Ui.label("Arraste com o botão direito para girar", 15, Ui.MUTED)
	rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(rot)
	_wd_buy = Ui.button("Comprar", 21)
	_wd_buy.visible = false
	_wd_buy.pressed.connect(_wardrobe_buy)
	foot.add_child(_wd_buy)
	var done := Ui.button("Pronto", 21)
	done.pressed.connect(close)
	foot.add_child(done)
	_wardrobe_fill()

func _input(event: InputEvent) -> void:
	if current == "wardrobe" and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		Game.world.rig.orbit_angle -= event.relative.x * 0.01

func _wardrobe_fill() -> void:
	Ui.clear(_wd_grid)
	Ui.clear(_wd_colors)
	_wd_info.text = str(int(Save.data["shards"]))
	var p: Player = Game.me()
	if _wd_slot == "dye":
		_wd_grid.visible = false
		var rows := [["Pele", "skin", DB.SKIN_TONES], ["Cabelo", "hair_c", DB.HAIR_COLORS], ["Cor principal", "primary", DB.CLOTH_COLORS],
			["Cor secundária", "secondary", DB.CLOTH_COLORS], ["Detalhes", "accent", DB.CLOTH_COLORS], ["Olhos", "iris", DB.IRIS_COLORS]]
		for r in rows:
			_wd_colors.add_child(Ui.label(r[0], 19, Ui.GOLD, true))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			_wd_colors.add_child(flow)
			for hex: String in r[2]:
				var b := Button.new()
				b.custom_minimum_size = Vector2(46, 46)
				b.focus_mode = Control.FOCUS_NONE
				var sel: bool = str(_wd_look.get(r[1], "")) == hex
				for st in ["normal", "hover", "pressed"]:
					b.add_theme_stylebox_override(st, Ui.box(Color(hex), 23, Color.WHITE if sel else Ui.INK, 4 if sel else 2, 0))
				b.pressed.connect(func() -> void:
					Sfx.ui("ui_click")
					_wd_look[r[1]] = hex
					_wardrobe_apply()
					_wardrobe_fill())
				flow.add_child(b)
		return
	_wd_grid.visible = true
	var ids: Array = []
	if _wd_slot == "weapon":
		ids = DB.weapons_of(p.wt)
	else:
		ids = (DB.by_slot.get(_wd_slot, []) as Array).duplicate()
		if _wd_slot in ["hat", "ears", "acc", "back"]:
			ids.push_front("")
	var cur := _wardrobe_current()
	for id: String in ids:
		var c: Dictionary = DB.cosmetics.get(id, {"rarity": 0, "cost": 0})
		var owned := Save.is_unlocked(id)
		var col: Color = DB.RARITY_COLORS[int(c.get("rarity", 0))]
		var b := Button.new()
		b.custom_minimum_size = Vector2(228, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.text = DB.cosmetic_label(id) + ("" if owned else "\n%d fragmentos" % int(c.get("cost", 0)))
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		var sel := id == cur or id == _wd_try
		for st in ["normal", "hover", "pressed"]:
			var bg := Color("3a3168") if sel else (Color("2a2350") if owned else Color("201a3c"))
			b.add_theme_stylebox_override(st, Ui.box(bg.lightened(0.08) if st == "hover" else bg, 12, col if sel else col.darkened(0.45), 3 if sel else 2, 8))
		if not owned:
			b.add_theme_color_override("font_color", Ui.MUTED)
		b.pressed.connect(func() -> void:
			Sfx.ui("ui_click")
			_wardrobe_select(id))
		_wd_grid.add_child(b)

func _wardrobe_current() -> String:
	if _wd_slot == "weapon":
		return Save.weapon_skin(Game.me().wt)
	return str(_wd_look.get(_wd_slot, ""))

func _wardrobe_select(id: String) -> void:
	var p: Player = Game.me()
	if Save.is_unlocked(id):
		_wd_try = ""
		if _wd_slot == "weapon":
			Save.data["weapons"][p.wt] = id
		else:
			_wd_look[_wd_slot] = id
	else:
		_wd_try = id
	_wardrobe_apply()
	_wardrobe_fill()

func _wardrobe_apply() -> void:
	var p: Player = Game.me()
	var l := _wd_look.duplicate()
	l["weapon"] = Save.weapon_skin(p.wt)
	if _wd_try != "":
		l["weapon" if _wd_slot == "weapon" else _wd_slot] = _wd_try
		var cost := DB.cosmetic_cost(_wd_try)
		_wd_buy.visible = true
		_wd_buy.text = "Comprar por %d" % cost
		_wd_buy.disabled = int(Save.data["shards"]) < cost
	else:
		_wd_buy.visible = false
	p.visual.apply_look(l)
	p.visual.play_once("cheer" if randf() < 0.3 else "wave", 0.15)

func _wardrobe_buy() -> void:
	if _wd_try == "":
		return
	if Save.unlock(_wd_try):
		Sfx.ui("ui_buy")
		var id := _wd_try
		_wd_try = ""
		_wardrobe_select(id)
	else:
		Sfx.ui("ui_error")

func _wardrobe_close() -> void:
	Save.data["look"] = _wd_look
	Save.save()
	Game.world.rig.orbit_mode = false
	var p: Player = Game.me()
	if p:
		p.visual.apply_look(Save.net_look())
	Game.push_my_info()

# ------------------------------------------------------------------ melhorias
func open_upgrades() -> void:
	var v := _open("upgrades")
	_header(v, "Altar de Lúmen", "Melhorias permanentes. Fragmentos: %d" % int(Save.data["shards"]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for id: String in DB.UPGRADES:
		var d: Dictionary = DB.UPGRADES[id]
		var lvl := Save.upgrade_level(id)
		var pc := Ui.panel(Color("2a2350"), 14, Color("5a4f96"), 2, 12)
		pc.custom_minimum_size = Vector2(470, 0)
		var h := HBoxContainer.new()
		pc.add_child(h)
		h.add_child(Ui.icon_tile(str(d["icon"]), 60, Ui.CYAN.darkened(0.2)))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(Ui.label("%s   %d/%d" % [d["name"], lvl, int(d["max"])], 20, Color.WHITE, true))
		var ds := Ui.label(str(d["desc"]), 16, Ui.MUTED)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(ds)
		var b := Ui.button("Máx." if lvl >= int(d["max"]) else str(DB.upgrade_cost(id, lvl)), 19)
		b.custom_minimum_size = Vector2(90, 0)
		b.disabled = lvl >= int(d["max"]) or int(Save.data["shards"]) < DB.upgrade_cost(id, lvl)
		b.pressed.connect(func() -> void:
			if Save.buy_upgrade(id):
				Sfx.ui("ui_buy")
				var p: Player = Game.me()
				if p:
					p.recalc()
				open_upgrades())
		h.add_child(b)
		grid.add_child(pc)
	var cl := Ui.button("Fechar", 20)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(close)
	v.add_child(cl)

# ------------------------------------------------------------------ classes
func open_classes() -> void:
	var v := _open("classes")
	_header(v, "Escolha sua classe", "Cada classe tem ataque básico, especial, duas habilidades e uma suprema.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for id: String in DB.CLASS_ORDER:
		var c: Dictionary = DB.CLASSES[id]
		var col := Color(str(c["color"]))
		var sel: bool = Save.data["cls"] == id
		var pc := Ui.panel(Color("2a2350"), 18, col if sel else col.darkened(0.45), 4 if sel else 2, 16)
		pc.custom_minimum_size = Vector2(300, 0)
		var cv := VBoxContainer.new()
		pc.add_child(cv)
		var wicon: String = {"sword": "sword", "bow": "bow", "staff": "staff", "hammer": "hammer"}[c["wt"]]
		var tile := Ui.icon_tile(wicon, 90, col)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(tile)
		var nm := Ui.label(str(c["name"]), 26, col.lightened(0.4), true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nm)
		var ds := Ui.label(str(c["desc"]), 16, Ui.TEXT)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.custom_minimum_size = Vector2(260, 70)
		cv.add_child(ds)
		cv.add_child(Ui.label("Vida %d" % int(c["hp"]), 16, Color("ef8a96"), true))
		for sid: String in [c["primary"], c["secondary"], c["skills"][0], c["skills"][1], c["ult"]]:
			var sd: Dictionary = DB.SKILLS[sid]
			var sh := HBoxContainer.new()
			sh.add_child(Ui.icon_rect(str(sd["icon"]), 22, col.lightened(0.3)))
			var sl := Ui.label(str(sd["name"]), 16, Ui.TEXT)
			sl.tooltip_text = str(sd["desc"])
			sl.mouse_filter = Control.MOUSE_FILTER_STOP
			sh.add_child(sl)
			cv.add_child(sh)
		var b := Ui.button("Selecionada" if sel else "Escolher", 20)
		b.disabled = sel
		b.pressed.connect(func() -> void:
			Save.data["cls"] = id
			Save.save()
			var p: Player = Game.me()
			if p:
				var info := Game.my_info()
				p.apply_info(info)
				p.reset_run()
				Fx.burst(p.global_position + Vector3(0, 1, 0), col, 2.5)
			Game.push_my_info()
			open_classes())
		cv.add_child(b)
		row.add_child(pc)
	var cl := Ui.button("Fechar", 20)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cl.pressed.connect(close)
	v.add_child(cl)

# ------------------------------------------------------------------ iniciar run
func open_start() -> void:
	var v := _open("start")
	_header(v, "Portal das Ruínas", "%d jogador(es) na sala. A dificuldade se ajusta ao grupo." % Game.player_count())
	var maxh := int(Save.data.get("max_heat", 0))
	var heat := clampi(int(Save.data.get("heat", 0)), 0, maxh)
	var hl := Ui.label("", 20, Ui.TEXT, true)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var upd := func() -> void:
		var h := int(Save.data.get("heat", 0))
		hl.text = "Dificuldade: %s   (inimigos +%d%%, fragmentos +%d%%)" % ["Normal" if h == 0 else "Fúria %d" % h, h * 28, h * 30]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var minus := Ui.button("  -  ", 24)
	var plus := Ui.button("  +  ", 24)
	minus.pressed.connect(func() -> void:
		Save.data["heat"] = maxi(0, int(Save.data.get("heat", 0)) - 1)
		upd.call())
	plus.pressed.connect(func() -> void:
		Save.data["heat"] = mini(maxh, int(Save.data.get("heat", 0)) + 1)
		upd.call())
	row.add_child(minus)
	row.add_child(hl)
	row.add_child(plus)
	v.add_child(row)
	Save.data["heat"] = heat
	upd.call()
	if maxh == 0:
		var tip := Ui.label("Vença o Guardião para liberar dificuldades maiores.", 16, Ui.MUTED)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tip)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	var go := Ui.button("Partir!", 26)
	go.custom_minimum_size = Vector2(220, 60)
	go.pressed.connect(func() -> void:
		Save.save()
		close()
		Game.start_run())
	hb.add_child(go)
	var cl := Ui.button("Ainda não", 20)
	cl.pressed.connect(close)
	hb.add_child(cl)

# ------------------------------------------------------------------ resumo
func open_summary(s: Dictionary) -> void:
	_summary = s
	var p: Player = Game.me()
	var heat := int(s.get("heat", 0))
	var rooms := int(s.get("rooms", 0))
	var kills := p.kills if p else 0
	var shards := int((rooms * 7 + kills * 0.6 + (70 if s.get("victory", false) else 0)) * (1.0 + 0.3 * heat)
		* (1.0 + Save.upgrade_level("fragmentos") * float(DB.UPGRADES["fragmentos"]["shard_bonus"])))
	Save.data["stats"]["runs"] = int(Save.data["stats"]["runs"]) + 1
	Save.data["stats"]["kills"] = int(Save.data["stats"]["kills"]) + kills
	Save.data["stats"]["best_room"] = maxi(int(Save.data["stats"]["best_room"]), rooms)
	if s.get("victory", false):
		Save.data["stats"]["wins"] = int(Save.data["stats"]["wins"]) + 1
		Save.data["max_heat"] = clampi(maxi(int(Save.data.get("max_heat", 0)), heat + 1), 0, 5)
	Save.add_shards(shards)
	var v := _open("summary", 0.7)
	var win: bool = s.get("victory", false)
	_header(v, "Vitória!" if win else "A expedição acabou", "O Guardião Cristalino foi derrotado." if win else "As ruínas venceram desta vez. Fique mais forte e volte.")
	Sfx.ui("clear" if win else "down")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	v.add_child(grid)
	var t: float = s.get("time", 0.0)
	var rows := [["Salas vencidas", str(rooms)], ["Inimigos derrotados", str(kills)], ["Dano causado", str(int(p.dmg_done) if p else 0)],
		["Quedas", str(p.downs if p else 0)], ["Tempo", "%d:%02d" % [int(t) / 60, int(t) % 60]], ["Fragmentos de lúmen", "+%d" % shards]]
	for r in rows:
		grid.add_child(Ui.label(r[0], 20, Ui.MUTED))
		var val := Ui.label(r[1], 22, Ui.CYAN if r[0].begins_with("Fragmentos") else Color.WHITE, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
	if p and p.relics.size() + p.boons.size() > 0:
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(520, 0)
		for id in p.relics:
			flow.add_child(Ui.icon_tile(str(DB.RELICS[id]["icon"]), 44, DB.RARITY_COLORS[int(DB.RELICS[id]["rarity"])]))
		for id in p.boons:
			flow.add_child(Ui.icon_tile(str(DB.BOONS[id]["icon"]), 44, Color("5a4f96")))
		v.add_child(flow)
	if Net.is_host():
		var b := Ui.button("Voltar para a vila", 24)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var act := func() -> void:
			close()
			Game.return_to_hub()
		b.pressed.connect(act)
		_bot_actions.append(act)
		v.add_child(b)
	else:
		var w := Ui.label("Aguardando o host voltar para a vila...", 18, Ui.MUTED)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(w)

# ------------------------------------------------------------------ pausa
func open_pause() -> void:
	var v := _open("pause")
	_header(v, "Pausa", "O jogo continua rodando para o grupo.")
	var rows := [["Sensibilidade do mouse", "sens", 0.3, 2.5], ["Volume geral", "volume", 0.0, 1.0], ["Volume da música", "music", 0.0, 1.0], ["Tremor de câmera", "shake", 0.0, 1.5]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	v.add_child(grid)
	for r in rows:
		grid.add_child(Ui.label(r[0], 19))
		var sl := HSlider.new()
		sl.min_value = r[2]
		sl.max_value = r[3]
		sl.step = 0.05
		sl.value = float(Save.setting(r[1]))
		sl.custom_minimum_size = Vector2(260, 28)
		sl.value_changed.connect(func(val: float) -> void:
			Save.data["settings"][r[1]] = val
			Sfx.apply_volume())
		grid.add_child(sl)
	var fs := Ui.button("Tela cheia: %s" % ("sim" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "não"), 20)
	fs.pressed.connect(func() -> void:
		var full := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
		Save.data["settings"]["fullscreen"] = full
		open_pause())
	v.add_child(fs)
	var res := Ui.button("Continuar", 22)
	res.pressed.connect(func() -> void:
		Save.save()
		close())
	v.add_child(res)
	if Game.phase == Game.Phase.RUN and Net.is_host():
		var ab := Ui.button("Abandonar a expedição", 20)
		ab.pressed.connect(func() -> void:
			close()
			Game.finish_run(false))
		v.add_child(ab)
	var lv := Ui.button("Sair da sala", 20)
	lv.pressed.connect(func() -> void:
		Save.save()
		close()
		Game.leave_game())
	v.add_child(lv)
	var q := Ui.button("Fechar o jogo", 20)
	q.pressed.connect(func() -> void:
		Save.save()
		get_tree().quit())
	v.add_child(q)
