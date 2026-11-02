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


func set_pulse(chroma: float, flash: float, speed: float = 0.0, hurt: float = 0.0) -> void:
	_mat.set_shader_parameter("chroma", chroma)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("speed", speed)
	_mat.set_shader_parameter("hurt", hurt)
	var low := 0.0
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority() and p.max_hp > 0:
			low = clampf((0.35 - float(p.hp) / p.max_hp) / 0.35, 0.0, 1.0) if p.hp > 0 else 0.0
	_mat.set_shader_parameter("lowhp", low)


func _exit_tree() -> void:
	if Juice.postfx == self:
		Juice.postfx = null
