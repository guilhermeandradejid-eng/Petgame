extends Node
## Game-feel helpers: hitstop, trauma screen shake, slow motion and
## camera punches. The restore logic lives here (an autoload is never freed)
## so overlapping hitstops can never leave time_scale stuck.

var camera: Node = null  # CoopCamera registers itself
var _stop_until := 0.0
var _slowmo_until := 0.0
var _slowmo_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var target := 1.0
	if now < _slowmo_until:
		target = _slowmo_scale
	if now < _stop_until:
		target = 0.02
	if get_tree().paused:
		return
	Engine.time_scale = target


## Freeze the action for a few frames so impacts read as heavy.
func hitstop(duration := 0.06) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_stop_until = maxf(_stop_until, now + duration)


func slowmo(scale := 0.35, duration := 0.6) -> void:
	_slowmo_scale = scale
	_slowmo_until = Time.get_ticks_msec() / 1000.0 + duration


func shake(trauma: float) -> void:
	if camera and is_instance_valid(camera):
		camera.add_trauma(trauma * Game.settings["shake"])


func punch(dir: Vector3, strength := 0.3) -> void:
	if camera and is_instance_valid(camera):
		camera.punch(dir, strength * Game.settings["shake"])


func fov_kick(amount := 8.0) -> void:
	if camera and is_instance_valid(camera):
		camera.fov_kick(amount)


func reset() -> void:
	_stop_until = 0.0
	_slowmo_until = 0.0
	Engine.time_scale = 1.0
