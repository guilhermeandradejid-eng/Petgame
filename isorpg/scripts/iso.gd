class_name Iso
extends RefCounted
## 2:1 isometric helpers. Grid space: one unit per cell. Screen space: pixels.

const TW := 64.0
const TH := 32.0
## Side of one cell measured in sprite pixels on the ground (the sprite renderer's units).
const CELL_UNITS := 45.254834


static func to_screen(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * TW * 0.5, (g.x + g.y) * TH * 0.5)


static func to_grid(s: Vector2) -> Vector2:
	return Vector2(s.x / TW + s.y / TH, s.y / TH - s.x / TW)


## Sprite direction (0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW) for a movement in grid space.
static func dir_index(v: Vector2) -> int:
	var gx := v.x - v.y
	var gd := -(v.x + v.y)
	var a := atan2(gd, gx)
	return posmod(int(round((a + PI * 0.5) / (PI * 0.25))), 8)
