extends Control
## Painel com os controles e golpes.

const ROWS := [
	["MOVIMENTO", ""],
	["Andar / pular / agachar", "A D / W / S   (P2: setas)"],
	["Dash · voo no ar", "Espaço (direção escolhe o rumo)"],
	["Pulo duplo", "W no ar"],
	["Defender", "segure para trás (agachado defende golpes baixos)"],
	["ATAQUES", ""],
	["Golpe (A)", "J — repita para a sequência de 4 golpes"],
	["Golpes especiais", "S+J baixo · D+J forte · J no ar · S+J no ar"],
	["Tiro (B)", "K — gasta espírito  (W+K para cima, S+K baixo)"],
	["Habilidade (C)", "L — neutra, para frente (D+L) ou para baixo (S+L)"],
	["CARTAS", ""],
	["Usar carta", "I — a carta da esquerda, se tiver cartas suficientes"],
	["Trocar carta", "O — gira a mão"],
	["Encher o medidor", "acertando, apanhando e raspando tiros (graze)"],
	["SISTEMA", ""],
	["Graze", "dash e voo atravessam tiros e enchem o medidor"],
	["Quebra de guarda", "defender gasta espírito; zerou, quebrou"],
	["Controle", "X golpe · Y tiro · B habilidade · A dash · LB carta"],
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(40, 34, 560, 292), Color(0.05, 0.03, 0.14, 0.95))
	draw_rect(Rect2(40, 34, 560, 292), Color("ffd66b"), false, 1.0)
	var font: Font = Game.font_main
	var y := 56.0
	for r in ROWS:
		if r[1] == "":
			draw_string(Game.font_title, Vector2(56, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("ffd66b"))
			y += 15.0
			continue
		draw_string(font, Vector2(64, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))
		draw_string(font, Vector2(230, y), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.82, 1.0))
		y += 14.0
	draw_string(font, Vector2(320 - 60, 318), "voltar: K / Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.7, 0.85))
