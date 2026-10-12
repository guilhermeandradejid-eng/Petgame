class_name FxAnim
extends Sprite2D
## A one-shot strip animation that frees itself when done.

var fps := 16.0
var t := 0.0
var loop := false
var life := -1.0


static func spawn(parent: Node, tex: Texture2D, frames: int, at: Vector2, rate := 16.0, z := 0) -> FxAnim:
	var a := FxAnim.new()
	a.texture = tex
	a.hframes = frames
	a.fps = rate
	a.position = at
	a.z_index = z
	parent.add_child(a)
	return a


func _process(delta: float) -> void:
	t += delta
	var f := int(t * fps)
	if f >= hframes:
		if loop:
			f %= hframes
		else:
			queue_free()
			return
	frame = f
	if life > 0.0 and t >= life:
		queue_free()
