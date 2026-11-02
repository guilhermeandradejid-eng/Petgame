class_name SpriteActor
extends Node3D
## A pixel-sprite billboard in the 3D stage. Owns animation playback (tick based),
## squash/stretch springs, flash and afterimages. Origin = feet on the ground.

const SHADER := preload("res://vfx/shaders/billboard_sprite.gdshader")
const GHOST := preload("res://vfx/shaders/sprite_ghost.gdshader")
const BLOB := preload("res://vfx/shaders/blob_shadow.gdshader")

var sheet: AnimSheet
var anim: String = ""
var tick: int = 0
var facing: float = 1.0           # +1 right, -1 left
var mat: ShaderMaterial
var mesh_inst: MeshInstance3D
var blob: MeshInstance3D
var _frame: Dictionary = {}
var logical := 0                  # logical frame index (gameplay-facing); sub-frames never change it
var _rate_acc := 0.0
var _skew := 0.0
var skew_target := 0.0            # horizontal lean from velocity (set by the owner)
var _flash: float = 0.0
var _squash := Vector2.ONE
var _squash_vel := Vector2.ZERO
var shake_px: float = 0.0         # hitstop jitter (screen-space-ish, metres)
var shadow_scale: float = 1.0


func setup(char_id: String, shadow_width: float = 1.1) -> void:
	sheet = AnimSheet.get_sheet(char_id)
	var q := QuadMesh.new()
	var size := sheet.cell * Game.PX
	q.size = Vector2(size, size)
	# feet are 5 sprite px above the cell bottom (ground row 59 of 64)
	q.center_offset = Vector3(0, size * 0.5 - 5.0 * Game.PX, 0)
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = q
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("sheet", sheet.tex)
	mat.set_shader_parameter("nsheet", sheet.ntex)
	mat.set_shader_parameter("cell_px", float(sheet.cell))
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)
	var bq := QuadMesh.new()
	bq.size = Vector2(shadow_width, shadow_width * 0.8)
	blob = MeshInstance3D.new()
	blob.mesh = bq
	var bm := ShaderMaterial.new()
	bm.shader = BLOB
	blob.material_override = bm
	blob.rotation_degrees = Vector3(-90, 0, 0)
	blob.position = Vector3(0, 0.02, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func play(name: String, restart: bool = false) -> void:
	if name == anim and not restart:
		return
	anim = name
	tick = 0
	_refresh()


func set_pose(name: String, t: int) -> void:
	## Used for remote copies: play whatever the owner says.
	anim = name
	tick = t
	_refresh()


func advance(n: int = 1) -> void:
	tick += n
	_refresh()


## Playback at a fractional rate (locomotion cycles follow the ground speed so feet do not slide).
func advance_rate(rate: float) -> void:
	_rate_acc += rate
	var n := int(_rate_acc)
	if n > 0:
		_rate_acc -= n
		advance(n)


func finished() -> bool:
	return sheet.has_anim(anim) and not sheet.anims[anim]["loop"] and tick >= sheet.total_ticks(anim)


func _refresh() -> void:
	if not sheet.has_anim(anim):
		return
	_frame = sheet.at(anim, tick)
	logical = _frame["logical"]
	mat.set_shader_parameter("frame_rect", sheet.uv_rect(_frame["i"]))


func set_facing(f: float) -> void:
	if f != 0.0:
		facing = signf(f)
		mat.set_shader_parameter("flip", facing)


func flash(strength: float = 1.0, color: Color = Color.WHITE) -> void:
	_flash = strength
	mat.set_shader_parameter("flash_color", color)


func squash(v: Vector2) -> void:
	## v = (x scale, y scale); springs back to 1.
	_squash = v


func set_param(p: String, v) -> void:
	mat.set_shader_parameter(p, v)


func _process(delta: float) -> void:
	# critically-damped-ish spring for squash & stretch
	var k := 260.0
	var c := 16.0
	var steps := clampi(int(ceil(delta / 0.008)), 1, 8)
	var h := minf(delta, 0.05) / steps          # stable even when the frame rate tanks
	for i in steps:
		var acc := (Vector2.ONE - _squash) * k - _squash_vel * c
		_squash_vel += acc * h
		_squash += _squash_vel * h
	_squash = _squash.clamp(Vector2(0.4, 0.4), Vector2(1.8, 1.8))
	_skew = lerpf(_skew, skew_target, clampf(delta * 14.0, 0.0, 1.0))
	mat.set_shader_parameter("skew", _skew)
	mat.set_shader_parameter("squash", _squash)
	# the blob shadow stays on the floor and shrinks with height
	var height := maxf(global_position.y, 0.0)
	blob.position.y = 0.02 - global_position.y
	shadow_scale = clampf(1.0 - height * 0.22, 0.45, 1.0)
	_flash = maxf(0.0, _flash - delta * 9.0)
	mat.set_shader_parameter("flash", clampf(_flash, 0.0, 1.0))
	mesh_inst.position.x = (randf() - 0.5) * shake_px if shake_px > 0.0 else 0.0
	blob.scale = Vector3.ONE * shadow_scale


## World position of a named anchor (hand, weapon_tip, head, chest, off_hand).
func anchor_world(name: String) -> Vector3:
	if _frame.is_empty():
		return global_position
	var a: Array = _frame["anchors"][name]
	var dx := (float(a[0]) - sheet.cell * 0.5) * Game.PX * facing
	var dy := (59.0 - float(a[1])) * Game.PX
	return global_position + Vector3(dx, dy + position.y * 0.0, 0.02)


func afterimage(color: Color, life: float = 0.22) -> void:
	if not is_inside_tree():
		return
	var g := MeshInstance3D.new()
	g.mesh = mesh_inst.mesh
	var m := ShaderMaterial.new()
	m.shader = GHOST
	m.set_shader_parameter("sheet", sheet.tex)
	m.set_shader_parameter("frame_rect", sheet.uv_rect(_frame.get("i", 0)))
	m.set_shader_parameter("flip", facing)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("squash", _squash)
	m.set_shader_parameter("skew", _skew)
	g.material_override = m
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(g)
	g.global_position = global_position
	var tw := g.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("alpha", v), 0.7, 0.0, life)
	tw.tween_callback(g.queue_free)
