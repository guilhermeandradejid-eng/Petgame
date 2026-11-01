class_name InputFrame
extends RefCounted
## One tick of player intent. Pressed = edge this tick, held = level.

enum { ATTACK = 1, JUMP = 2, DASH = 4, CAST = 8 }

var move := Vector2.ZERO
var pressed := 0
var held := 0


func is_pressed(bit: int) -> bool:
	return (pressed & bit) != 0


func is_held(bit: int) -> bool:
	return (held & bit) != 0
