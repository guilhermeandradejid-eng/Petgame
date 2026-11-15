class_name Zone
extends Node3D
## Area temporaria no chao (chuva de flechas, santuario, totem, laminas orbitando):
## chama on_tick a cada 'tick' segundos e some quando a vida acaba.

var life := 1.0
var tick := 0.5
var age := 0.0
var on_tick: Callable
var on_end: Callable
var follow: Node3D
var _t := 0.0

static func make(pos: Vector3, p_life: float, p_tick: float) -> Zone:
	var z := Zone.new()
	z.position = pos
	z.life = p_life
	z.tick = p_tick
	return z

func _process(delta: float) -> void:
	if follow:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position
	age += delta
	_t -= delta
	if _t <= 0.0:
		_t += tick
		if on_tick.is_valid():
			on_tick.call()
	if age >= life:
		if on_end.is_valid():
			on_end.call()
		set_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
		tw.tween_callback(queue_free)
