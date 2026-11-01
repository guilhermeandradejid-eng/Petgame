extends CanvasLayer
## Full-screen HD-2D post pass (tilt-shift + vignette + chroma pulse).

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 50
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://vfx/shaders/tiltshift.gdshader")
	_rect.material = _mat
	add_child(_rect)
	Juice.postfx = self


func set_pulse(chroma: float, flash: float) -> void:
	_mat.set_shader_parameter("chroma", chroma)
	_mat.set_shader_parameter("flash", flash)


func _exit_tree() -> void:
	if Juice.postfx == self:
		Juice.postfx = null
