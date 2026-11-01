extends Node
## Global constants and small shared helpers.

const PX := 1.0 / 32.0          # metres per sprite pixel
const TICK_RATE := 60
const GRAVITY := 24.0
const ARENA_HALF := 21.0        # walkable half-size of the test glade (metres)

var kills: int = 0
var args: Dictionary = {}       # parsed "--key=value" user args
var event_log: Array = []       # test hooks: [{ "t": tick, "e": name, ... }]
var tick: int = 0
var world: Node = null            # the active World (spawning spells, enemies)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	process_physics_priority = -100


func _physics_process(_d: float) -> void:
	tick += 1


func log_event(name: String, data: Dictionary = {}) -> void:
	var d := {"t": tick, "e": name}
	d.merge(data)
	event_log.append(d)
	if event_log.size() > 2000:
		event_log.pop_front()


func count_events(name: String) -> int:
	var n := 0
	for e in event_log:
		if e["e"] == name:
			n += 1
	return n


static func px_to_m(px: float) -> float:
	return px * PX
