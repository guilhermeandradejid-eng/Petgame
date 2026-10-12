class_name DamageNumber
extends Node2D
## Tiny pixel-font numbers that pop up and float away.

const GLYPHS := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}

var text := "1"
var color := Color.WHITE
var t := 0.0
var vx := 0.0


func _ready() -> void:
	z_index = 20
	vx = randf_range(-12, 12)


func _process(delta: float) -> void:
	t += delta
	position += Vector2(vx, -40.0 * (1.0 - t)) * delta
	modulate.a = clamp(1.6 - t * 2.0, 0.0, 1.0)
	if t > 0.8:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var s := 2.0 if t < 0.08 else 1.0
	var x := -text.length() * 2.0 * s
	for ch in text:
		var g: Array = GLYPHS.get(ch, GLYPHS["0"])
		for row in 5:
			for c in 3:
				if g[row][c] == "1":
					var r := Rect2(Vector2(x + c * s, row * s), Vector2(s, s))
					draw_rect(r.grow(1.0), Color(0.08, 0.05, 0.12, 1))
		for row in 5:
			for c in 3:
				if g[row][c] == "1":
					draw_rect(Rect2(Vector2(x + c * s, row * s), Vector2(s, s)), color)
		x += 4.0 * s
