extends Node2D
## Pré-carrega os dados das personagens e vai para o título.

func _ready() -> void:
	for cid in Game.CHARACTERS:
		CharData.get_data(cid)
	await get_tree().process_frame
	Game.goto("res://scenes/title.tscn")
