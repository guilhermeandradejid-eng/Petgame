class_name InputSource
extends RefCounted
## Base class: produces an InputFrame each tick. Subclass for pad/replay/AI.

func poll(_tick: int) -> InputFrame:
	return InputFrame.new()


class Local extends InputSource:
	var _prev := 0
	var device := -1   # -1 = keyboard + any pad

	func poll(_tick: int) -> InputFrame:
		var f := InputFrame.new()
		f.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var h := 0
		if Input.is_action_pressed("attack"): h |= InputFrame.ATTACK
		if Input.is_action_pressed("jump"): h |= InputFrame.JUMP
		if Input.is_action_pressed("dash"): h |= InputFrame.DASH
		if Input.is_action_pressed("cast"): h |= InputFrame.CAST
		if Input.is_action_pressed("special1"): h |= InputFrame.SP1
		if Input.is_action_pressed("special2"): h |= InputFrame.SP2
		if Input.is_action_pressed("weapon_next"): h |= InputFrame.WEAPON
		if Input.is_action_pressed("spell_next"): h |= InputFrame.SPELL
		f.held = h
		f.pressed = h & ~_prev
		_prev = h
		return f


class Scripted extends InputSource:
	## Drives a player from a Callable(tick) -> { "move": Vector2, "press": int }.
	var fn: Callable
	var _prev := 0

	func _init(c: Callable) -> void:
		fn = c

	func poll(tick: int) -> InputFrame:
		var d: Dictionary = fn.call(tick)
		var f := InputFrame.new()
		f.move = d.get("move", Vector2.ZERO)
		f.held = d.get("hold", 0)
		f.pressed = d.get("press", 0)
		return f
