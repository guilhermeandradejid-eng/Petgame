extends Node
## Dev helper: logs player state changes (used with autoshot --dbg).
var _last := ["", ""]
func _physics_process(_d):
	var lvl = get_tree().current_scene.get_node_or_null("Level") if get_tree().current_scene else null
	if lvl == null or not ("players" in lvl) or lvl.players.size() < 2:
		return
	for i in 2:
		var p = lvl.players[i]
		if p.state != _last[i]:
			_last[i] = p.state
			print("f", Engine.get_physics_frames(), " ", p.name, " -> ", p.state, " at ", p.global_position, " v=", p.velocity)
