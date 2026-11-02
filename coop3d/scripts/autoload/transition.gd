extends CanvasLayer
## Star iris wipe between scenes.

const SHADER := preload("res://shaders/transition.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial
var busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	_apply(0.0)


func _apply(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_rect.visible = v > 0.001


func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	Sfx.play("swish", 0.8)
	var tw := create_tween()
	tw.tween_method(_apply, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().paused = false
	Juice.reset()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_apply, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	busy = false
