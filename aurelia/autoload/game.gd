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
var touch_mode := false           # on-screen controls (tablet/phone or --touch)
var low_quality := false          # web / mobile: fewer props, lighter shadows
var world: Node = null            # the active World (spawning spells, enemies)

# --- battle arena (set by BattleManager on every peer) ---
var arena_active := false
var arena_center := Vector3.ZERO
var arena_radius := 8.5

# --- combo counter (local player) ---
signal combo_changed(hits: int, damage: int)
var combo_hits := 0
var combo_damage := 0
var combo_max := 0
var combo_timer := 0
var battle_damage := 0
var freeze_ticks := 0              # global hit-freeze (killing blow)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	process_physics_priority = -100
	var web := OS.has_feature("web")
	touch_mode = DisplayServer.is_touchscreen_available() or args.has("touch")
	if web and not touch_mode:
		touch_mode = bool(JavaScriptBridge.eval("(navigator.maxTouchPoints || 0) > 0 || ('ontouchstart' in window)"))
	low_quality = web or OS.has_feature("mobile") or args.has("lowq")


func _physics_process(_d: float) -> void:
	tick += 1
	if freeze_ticks > 0:
		freeze_ticks -= 1
	if combo_timer > 0:
		combo_timer -= 1
		if combo_timer == 0:
			combo_hits = 0
			combo_damage = 0
			combo_changed.emit(0, 0)


func register_hit(dmg: int) -> void:
	combo_hits += 1
	combo_damage += dmg
	combo_max = maxi(combo_max, combo_hits)
	battle_damage += dmg
	combo_timer = 110
	combo_changed.emit(combo_hits, combo_damage)


## Keep a body inside the active arena ring (players and enemies both call this).
func clamp_to_arena(p: Vector3, margin: float = 0.6) -> Vector3:
	if not arena_active:
		return p
	var d := Vector2(p.x - arena_center.x, p.z - arena_center.z)
	var r := arena_radius - margin
	if d.length() > r:
		d = d.normalized() * r
		return Vector3(arena_center.x + d.x, p.y, arena_center.z + d.y)
	return p


func log_event(name: String, data: Dictionary = {}) -> void:
	var d := {"t": tick, "e": name}
	d.merge(data)
	event_log.append(d)
	if event_log.size() > 2000:
		event_log.pop_front()


func count_events_where(name: String, key: String, value) -> int:
	var n := 0
	for e in event_log:
		if e["e"] == name and e.get(key) == value:
			n += 1
	return n


func count_events(name: String) -> int:
	var n := 0
	for e in event_log:
		if e["e"] == name:
			n += 1
	return n


static func px_to_m(px: float) -> float:
	return px * PX
