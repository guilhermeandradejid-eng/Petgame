extends Node
## Root of level.tscn: instantiates the level script chosen in Game.


func _ready() -> void:
	var info: Dictionary = Game.LEVELS[Game.current_level]
	var lvl: Node = load(info["script"]).new()
	lvl.name = "Level"
	add_child(lvl)
