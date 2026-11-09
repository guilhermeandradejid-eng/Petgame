extends SceneTree
## Cartões de texto do trailer (PNG com fundo transparente, 1920x1080), no visual do jogo (Bungee inclinada,
## âmbar com contorno escuro, faixa quadriculada). Usado por tools/make_trailer.py.
##   xvfb-run godot --path minifuria --resolution 1920x1080 -s tools/trailer_cards.gd -- en PASTA_DE_SAIDA

const CARDS := {
	"en": {
		"tracks": ["26 TRACKS", "6 WORLDS · LOOPS · JUMPS · SPIRALS"],
		"weapons": ["10 ARMED CARS", "ROCKETS · LASERS · MINES · HARPOONS"],
		"bosses": ["6 GIANT BOSSES", "BEAT THEM TO THE LINE... OR GET CRUSHED"],
		"multi": ["4 PLAYERS · 1 SCREEN", "+ ONLINE RACES FOR UP TO 8"],
		"garage": ["UPGRADE EVERYTHING", "ENGINE · ARMOR · WEAPONS · SPECIALS"],
		"logo": ["COMBAT RACING", "PC · ANDROID · WEB"],
	},
	"pt": {
		"tracks": ["26 PISTAS", "6 MUNDOS · LOOPINGS · SALTOS · ESPIRAIS"],
		"weapons": ["10 CARROS ARMADOS", "FOGUETES · LASER · MINAS · ARPÃO"],
		"bosses": ["6 CHEFES GIGANTES", "CHEGUE NA FRENTE... OU VIRE SUCATA"],
		"multi": ["4 JOGADORES · 1 TELA", "+ ONLINE ATÉ 8 PESSOAS"],
		"garage": ["TURBINE TUDO", "MOTOR · BLINDAGEM · ARMAS · ESPECIAIS"],
		"logo": ["CORRIDA DE COMBATE", "PC · ANDROID · WEB"],
	},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lang: String = args[0] if args.size() > 0 else "en"
	var out: String = args[1] if args.size() > 1 else "user://cards"
	DirAccess.make_dir_recursive_absolute(out)
	root.transparent_bg = true
	UI.load_fonts()
	var cards: Dictionary = CARDS[lang]
	var i := 0
	for k in cards:
		var c := Control.new()
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(c)
		if k == "logo":
			_logo(c, cards[k])
		else:
			_card(c, cards[k], i % 2 == 1)
		for f in 6:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("%s.png" % k))
		c.queue_free()
		await process_frame
		i += 1
	quit()


## faixa inclinada escura com borda âmbar, título grande e linha de apoio
func _card(c: Control, txt: Array, right: bool) -> void:
	var vs := c.get_viewport_rect().size
	var big := 74
	var f: Font = UI.display_it
	var tw := f.get_string_size(String(txt[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var sw := UI.display_it.get_string_size(String(txt[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var w := maxf(tw, sw) + 120.0
	var h := 170.0
	var x0 := vs.x - w - 30.0 if right else 30.0
	var y0 := vs.y * 0.66
	var band := Control.new()
	band.position = Vector2(x0, y0)
	band.size = Vector2(w, h)
	band.draw.connect(func():
		var sk := 34.0
		band.draw_colored_polygon(PackedVector2Array([Vector2(sk + 8, 8), Vector2(w + 8, 8), Vector2(w - sk + 8, h + 8), Vector2(8, h + 8)]), Color(0, 0, 0, 0.35))
		band.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(w, 0), Vector2(w - sk, h), Vector2(0, h)]), Color(UI.INK, 0.9))
		band.draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(sk + 14, 0), Vector2(14, h), Vector2(0, h)]), UI.HOT)
		band.draw_colored_polygon(PackedVector2Array([Vector2(w - 14, 0), Vector2(w, 0), Vector2(w - sk, h), Vector2(w - sk - 14, h)]), UI.BAD)
		# faixa quadriculada embaixo do título
		var q := 10.0
		for i in int((w - 140.0) / q):
			for j in 2:
				if (i + j) % 2 == 0:
					band.draw_rect(Rect2(60 + i * q, 112 + j * q * 0.5, q, q * 0.5), Color(1, 1, 1, 0.8)))
	c.add_child(band)
	var t := UI.title(band, String(txt[0]), big, UI.HOT)
	t.position = Vector2(56, 6)
	var s := UI.title(band, String(txt[1]), 24, UI.TEXT)
	s.position = Vector2(48, 124)


## logo final: WRECK 'N' / ROLL como no menu, centralizado, com a linha e as plataformas
func _logo(c: Control, txt: Array) -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	c.add_child(v)
	var l1 := UI.title(v, "WRECK 'N'", 96, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l1.label_settings.shadow_color = UI.BAD
	l1.label_settings.outline_size = 16
	var l2 := UI.title(v, "ROLL", 190, UI.HOT, HORIZONTAL_ALIGNMENT_CENTER)
	l2.label_settings.outline_size = 26
	l2.label_settings.shadow_offset = Vector2(9, 9)
	var ck := UI.checker(v, 520, 14)
	ck.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)
	UI.title(v, String(txt[0]), 34, UI.INFO, HORIZONTAL_ALIGNMENT_CENTER)
	UI.title(v, String(txt[1]), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
