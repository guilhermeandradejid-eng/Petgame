class_name GenSprite
extends Sprite2D
## Plays sheets produced by tools/spritegen. Gameplay only reasons about logical frames;
## sub-frames exist for smoothness and are invisible to the game.

signal logical_frame(anim: String, index: int)
signal event(anim: String, name: String)
signal finished(anim: String)

var meta: Dictionary = {}
var textures: Dictionary = {}
var anim := ""
var dir := 0
var frame_i := 0
var tick := 0.0
var playing := false
var speed_scale := 1.0


func setup(folder: String, char_name: String) -> void:
	var f := FileAccess.open(folder + "/" + char_name + ".json", FileAccess.READ)
	meta = JSON.parse_string(f.get_as_text())
	for a in meta.animations:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load(folder + "/" + meta.animations[a].sheet)
		ct.normal_texture = load(folder + "/" + meta.animations[a].normal)
		textures[a] = ct
	centered = false
	region_enabled = true
	offset = Vector2(-meta.origin[0], -meta.origin[1])
	play("idle")


func has_anim(name: String) -> bool:
	return meta.animations.has(name)


func play(name: String, restart := false) -> void:
	if name == anim and playing and not restart:
		return
	anim = name
	frame_i = 0
	tick = 0.0
	playing = true
	texture = textures[name]
	_apply()
	_enter_logical()


func set_dir(d: int) -> void:
	if d != dir:
		dir = d
		_apply()


func logical() -> int:
	return int(meta.animations[anim].frames[frame_i].logical)


func anchor(name: String) -> Vector2:
	var v = meta.animations[anim].anchors[dir][frame_i][name]
	return Vector2(v[0], v[1])


func root_speed(name: String) -> float:
	return float(meta.animations[name].get("root_speed", 0.0))


func _process(delta: float) -> void:
	if not playing:
		return
	var a: Dictionary = meta.animations[anim]
	var frames: Array = a.frames
	tick += delta * float(meta.tick_rate) * speed_scale
	while tick >= float(frames[frame_i].ticks):
		tick -= float(frames[frame_i].ticks)
		var prev := int(frames[frame_i].logical)
		if frame_i + 1 >= frames.size():
			if a.loop:
				frame_i = 0
			else:
				playing = false
				var done := anim
				finished.emit(done)
				return
		else:
			frame_i += 1
		_apply()
		if int(frames[frame_i].logical) != prev:
			var current := anim
			_enter_logical()
			if anim != current:
				return


func _enter_logical() -> void:
	var li := logical()
	var current := anim
	logical_frame.emit(anim, li)
	if anim != current:
		return
	var ev = meta.animations[anim].logical[li].event
	if ev != null:
		event.emit(anim, ev)


func _apply() -> void:
	var fw: float = meta.frame_size[0]
	var fh: float = meta.frame_size[1]
	region_rect = Rect2(frame_i * fw, dir * fh, fw, fh)
