class_name CharPreview
extends Node2D
## Mostra uma animação de personagem (atlas do pipeline) fora da luta: seleção, título, resultados.

var data: CharData
var spr: Sprite2D
var anim := "idle"
var at := 0
var facing := 1
var alt := false
var acc := 0.0
var flash := 0.0
var mat: ShaderMaterial


func setup(cid: String, alt_pal := false) -> void:
	data = CharData.get_data(cid)
	alt = alt_pal
	if spr == null:
		spr = Sprite2D.new()
		spr.region_enabled = true
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/fighter.gdshader")
		spr.material = mat
		add_child(spr)
	spr.texture = data.tex_b if alt else data.tex_a
	play("idle")


func play(a: String) -> void:
	anim = a if data.has_anim(a) else "idle"
	at = 0
	_apply()


func _process(delta: float) -> void:
	if data == null:
		return
	acc += delta * 60.0
	while acc >= 1.0:
		acc -= 1.0
		at += 1
		var A: Dictionary = data.anims[anim]
		if not A["loop"] and at >= int(A["total"]) and anim != "idle":
			if anim in ["intro", "declare"]:
				play("idle")
	flash = maxf(0.0, flash - delta * 4.0)
	_apply()


func _apply() -> void:
	var fr: Dictionary = data.anims[anim]["frames"][data.frame_at(anim, at)]
	spr.region_rect = fr["rect"]
	spr.offset = -fr["origin"]
	spr.scale = Vector2(facing, 1)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("flash_color", Color.WHITE)
	mat.set_shader_parameter("tint", Color.WHITE)
