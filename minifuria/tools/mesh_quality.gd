extends SceneTree
## godot --headless -s res://tools/mesh_quality.gd
## quão "amassado" está o asfalto: distância do 4º vértice de cada quad ao plano dos outros três (m)
## e o salto de inclinação entre amostras vizinhas (graus)
func _init():
	for ti in [3, 5, 6, 7, 9]:
		var t := Track.new()
		t.setup(TrackData.TRACKS[ti], TrackData.THEMES[TrackData.TRACKS[ti].theme])
		t.build(null, null)
		var sh: ConcavePolygonShape3D = (t.get_node("Road").get_child(0) as CollisionShape3D).shape
		var f := sh.get_faces()
		var worst := 0.0
		var c5 := 0
		for k in range(0, f.size() - 5, 6):
			var pl := Plane(f[k], f[k + 1], f[k + 2])
			if pl.normal.length() < 0.5:
				continue
			var dev := absf(pl.distance_to(f[k + 5]))
			worst = maxf(worst, dev)
			if dev > 0.05:
				c5 += 1
		var jerk := 0.0
		for i in t.n:
			var j := (i + 1) % t.n
			var k2 := (i + 2) % t.n
			# variação da taxa de giro (o "tranco" visual na inclinação)
			var b0 := asin(clampf(t.L[i].y, -1.0, 1.0))
			var b1 := asin(clampf(t.L[j].y, -1.0, 1.0))
			var b2 := asin(clampf(t.L[k2].y, -1.0, 1.0))
			var r1 := b1 - b0
			var r2 := b2 - b1
			jerk = maxf(jerk, rad_to_deg(absf(r2 - r1)))
		print("%d %-16s max_desvio=%.3fm quads>5cm=%d max_tranco_giro=%.1f°" % [ti, TrackData.TRACKS[ti].name, worst, c5, jerk])
		t.free()
	quit()
