extends SceneTree
func _init() -> void:
	for ti in TrackData.TRACKS.size():
		var d: Dictionary = TrackData.TRACKS[ti]
		var t := Track.new()
		t.setup(d, TrackData.THEMES[d.theme])
		var out := []
		var i := 0
		while i < t.n:
			if t.feat[i] == 1 and t.feat[t.idx(i - 1)] == 0:
				var j := i
				while t.feat[t.idx(j)] == 1 and j < i + t.n:
					j += 1
				out.append("%s %d-%d" % [t.ftype[i], int(i * t.ds), int(j * t.ds)])
				i = j
			i += 1
		print(ti, " ", ", ".join(out))
		t.free()
	quit()
