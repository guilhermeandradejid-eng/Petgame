extends Control
## Tela de resultado sobre a luta: retrato da vencedora, frase e opções.

var battle
var menu: MenuList
var t := 0.0
var win: Fighter
var tex: Texture2D

const QUOTES := {
	"lumia": ["As lanternas continuam acesas. Volte quando quiser.", "Toda constelação tem um caminho. O seu acabou aqui.",
		"Que a luz te guie de volta para casa."],
	"rubi": ["Foi divertido! Mas o trovão chega antes.", "De novo! Dessa vez não vou segurar nada!",
		"Treina mais um pouco e me chama de novo."],
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	win = battle.winner
	tex = win.data.portrait_b if win.alt_palette else win.data.portrait_a
	menu = MenuList.new()
	menu.position = Vector2(330, 230)
	menu.size = Vector2(280, 100)
	menu.set_items([{"text": "Revanche"}, {"text": "Escolher personagens"}, {"text": "Menu principal"}])
	menu.chosen.connect(_on_choose)
	menu.active = false
	add_child(menu)
	await get_tree().create_timer(0.6).timeout
	menu.active = true


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / 0.5, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.02, 0.09, 0.75 * e))
	var info: Dictionary = Game.CHAR_INFO[win.kit.id]
	var col: Color = info["color"]
	draw_colored_polygon(PackedVector2Array([Vector2(-40 + 400 * (1 - e) * -1, 360), Vector2(260 - 400 * (1 - e), 0),
		Vector2(330 - 400 * (1 - e), 0), Vector2(30 - 400 * (1 - e), 360)]), Color(col, 0.25))
	if tex:
		var s := 4.0
		var w := tex.get_width() * s
		var h := tex.get_height() * s
		draw_texture_rect(tex, Rect2(150 - w * 0.5 - 120 * (1 - e), 330 - h, w, h), false, Color(1, 1, 1, e))
	var font: Font = Game.font_title
	var title := "VITÓRIA!"
	draw_string_outline(font, Vector2(330, 110), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0.04, 0.02, 0.1, e))
	draw_string(font, Vector2(330, 110), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(col.lerp(Color.WHITE, 0.3), e))
	draw_string(Game.font_main, Vector2(332, 132), "%s, %s" % [info["name"], info["title"].to_lower()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, e))
	var q: Array = QUOTES.get(win.kit.id, [""])
	var quote: String = q[(battle.frame / 7) % q.size()]
	draw_multiline_string(Game.font_main, Vector2(332, 170), "“%s”" % quote, HORIZONTAL_ALIGNMENT_LEFT, 290, 11, -1, Color(0.85, 0.88, 1.0, e))


func _on_choose(i: int) -> void:
	match i:
		0:
			Game.goto("res://scenes/battle.tscn")
		1:
			Game.goto("res://scenes/select.tscn")
		2:
			Game.goto("res://scenes/title.tscn")
