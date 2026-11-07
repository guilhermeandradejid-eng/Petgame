extends SceneTree
## godot --headless -s res://tools/validate_tracks.gd


func _init() -> void:
	for i in TrackData.TRACKS.size():
		var d: Dictionary = TrackData.TRACKS[i]
		var t := Track.new()
		t.setup(d, TrackData.THEMES[d.theme])
		var v := t.validate()
		print("%d %-22s %s pads=%d picks=%d" % [i, d.name, str(v), t.pads.size(), t.pickup_spots.size()])
		t.free()
	quit()
