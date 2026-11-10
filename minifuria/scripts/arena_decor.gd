class_name ArenaDecor
## Camada de "arena" em volta da pista (referência: Motor Rock — beira de pista cheia de coisa para olhar):
## arquibancadas com a torcida pulando, faixas de anúncio, torres de holofote, cerca de proteção, pilhas de
## pneus, cones e tendas de box. Tudo é feito em código (malhas com cor por vértice) e vai para os lotes de
## MultiMesh do jogo: poucas chamadas de desenho, leve também no celular.

const INK := Color("#1b1730")
const CONCRETE := Color("#8d8a92")
const STEEL := Color("#5d6070")

static var _mesh := {}
static var _mat: StandardMaterial3D
static var _glow: StandardMaterial3D
static var _flatm: StandardMaterial3D   # manchas do chão (duas faces)
static var _crowd_mat: ShaderMaterial


# ------------------------------------------------------------------ montagem
static func build(game: Node, track: Track, theme: Dictionary, rng: RandomNumberGenerator) -> void:
	_materials()
	var gy: float = theme.gy
	if gy < -0.5:
		return   # Porto e Céu: a pista fica sobre água/nuvens (sem chão para arquibancada)
	var pal: Array = [Color(String(theme.curb[0])), Color(String(theme.rail[1])), Color(String(theme.curb[1])), Color("#ffb21a")]
	var used: Array = []   # pontos já ocupados (nada fica em cima de nada)
	var straights := _straights(track)
	# arquibancadas nas maiores retas (do lado de fora), com torcida
	var stands := 0
	for st in straights:
		if stands >= 3:
			break
		var mid := int(st[0] + st[1] / 2) % track.n
		for sg: float in [1.0, -1.0]:
			if _try(game, track, used, mid, sg, track.WALL + 9.0, 16.0, gy, "stand", pal, rng):
				stands += 1
				break
	# faixas de anúncio e cerca ao longo das retas
	for st in straights:
		var i0: int = st[0]
		var ln: int = st[1]
		var sg := 1.0 if rng.randf() < 0.5 else -1.0
		var step := int(9.0 / track.ds)
		for k in range(4, ln - 4, step):
			var i := (i0 + k) % track.n
			_try(game, track, used, i, sg, track.WALL + 2.6, 4.5, gy, "banner", pal, rng)
			_try(game, track, used, i, -sg, track.WALL + 1.4, 3.0, gy, "fence", pal, rng)
	# holofotes a cada ~45 m, alternando os lados
	var hs := int(45.0 / track.ds)
	var side := 1.0
	for i in range(hs / 2, track.n, hs):
		_try(game, track, used, i, side, track.WALL + 5.5, 4.0, gy, "light", pal, rng, theme.night or theme.get("dusk", false))
		side = -side
	# pneus e cones no lado de fora das curvas fortes
	for i in range(0, track.n, 3):
		if absf(track.curv[i]) > 1.0 / 30.0 and rng.randf() < 0.35:
			var out := signf(track.curv[i])
			_try(game, track, used, i, out, track.WALL + 2.0 + rng.randf() * 2.0, 2.2, gy, "tires", pal, rng)
	_clutter(game, track, theme, rng)
	# tendas de box perto da largada
	var tents := 0
	for k in range(int(20.0 / track.ds), int(90.0 / track.ds), int(11.0 / track.ds)):
		if tents >= 4:
			break
		var i := (track.n - k) % track.n
		if _try(game, track, used, i, -1.0, track.WALL + 8.0, 5.0, gy, "tent", pal, rng):
			tents += 1


## trechos retos e planos (início, comprimento em amostras), do maior para o menor
static func _straights(track: Track) -> Array:
	var out: Array = []
	var i := 0
	while i < track.n:
		if _flat(track, i):
			var j := i
			while j < track.n and _flat(track, j):
				j += 1
			if (j - i) * track.ds > 30.0:
				out.append([i, j - i])
			i = j
		i += 1
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out


static func _flat(track: Track, i: int) -> bool:
	return track.feat[i] == 0 and track.gap[i] == 0 and track.U[i].y > 0.97 and absf(track.curv[i]) < 1.0 / 70.0


## coloca uma peça ao lado da pista, de frente para ela, se houver espaço livre (longe de outros trechos)
static func _try(game: Node, track: Track, used: Array, i: int, sg: float, off: float, radius: float, gy: float,
		kind: String, pal: Array, rng: RandomNumberGenerator, night := false) -> bool:
	i = track.idx(i)
	if track.feat[i] == 1 or track.gap[i] == 1 or track.P[i].y - gy > 1.6:
		return false
	var L: Vector3 = track.L[i]
	var p: Vector3 = track.P[i] + L * sg * off
	p.y = gy
	if track.clearance_xz(p) < off - 0.5 or track.clearance_xz(p) < track.WALL + radius * 0.6:
		return false
	for u in used:
		if Vector2(p.x - u[0].x, p.z - u[0].z).length() < radius + float(u[1]):
			return false
	used.append([p, radius])
	var face := -L * sg   # olha para a pista
	var b := Basis(Vector3.UP, atan2(face.x, face.z))
	var xf := Transform3D(b, p)
	match kind:
		"stand":
			game._batch_mesh("ad_stand", _mesh_of("stand", pal), xf, _mat)
			game._batch_mesh("ad_crowd%d" % (rng.randi() % 2), _mesh_of("crowd%d" % (rng.randi() % 2), pal), xf, _crowd_mat, false)
		"banner":
			var v := rng.randi() % 3
			game._batch_mesh("ad_banner%d" % v, _mesh_of("banner%d" % v, pal), xf, _mat)
		"fence":
			game._batch_mesh("ad_fence", _mesh_of("fence", pal), xf, _mat, false)
		"light":
			game._batch_mesh("ad_light", _mesh_of("light", pal), xf, _mat)
			game._batch_mesh("ad_lamp", _mesh_of("lamp", pal), xf, _glow, false)
			if night:
				var ol := OmniLight3D.new()
				ol.light_color = Color(1.0, 0.95, 0.85)
				ol.light_energy = 1.4
				ol.omni_range = 16.0
				ol.position = p + face * 2.0 + Vector3.UP * 10.0
				game.world.add_child(ol)
		"tires":
			game._batch_mesh("ad_tires", _mesh_of("tires", pal), Transform3D(b.rotated(Vector3.UP, rng.randf() * 0.6 - 0.3), p), _mat)
		"tent":
			game._batch_mesh("ad_tent%d" % (rng.randi() % 2), _mesh_of("tent%d" % (rng.randi() % 2), pal), xf, _mat)
	return true


# ------------------------------------------------------------------ materiais
static func _materials() -> void:
	if _mat:
		return
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.75
	_flatm = _mat.duplicate()
	_flatm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow = StandardMaterial3D.new()
	_glow.vertex_color_use_as_albedo = true
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = Color(2.2, 2.1, 1.8)
	var sh := Shader.new()
	# torcida: cada pessoa (UV.x = fase) pula e balança sozinha
	sh.code = """
shader_type spatial;
render_mode cull_back;
void vertex() {
	float ph = UV.x * 37.0;
	float j = max(0.0, sin(TIME * (6.0 + fract(UV.x * 13.0) * 4.0) + ph));
	VERTEX.y += j * j * 0.35 * UV.y;
	VERTEX.x += sin(TIME * 3.0 + ph) * 0.05 * UV.y;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
"""
	_crowd_mat = ShaderMaterial.new()
	_crowd_mat.shader = sh


static func _mesh_of(name_: String, pal: Array) -> Mesh:
	var key := name_ + str(pal[0].to_html()) + str(pal[1].to_html())
	if _mesh.has(key):
		return _mesh[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match name_:
		"stand":
			_stand(st, pal)
		"crowd0", "crowd1":
			_crowd(st, int(name_.right(1)))
		"banner0", "banner1", "banner2":
			_banner(st, pal, int(name_.right(1)))
		"fence":
			_fence(st)
		"light":
			_light(st)
		"lamp":
			_box(st, Vector3(0, 10.6, -0.9), Vector3(2.6, 0.9, 0.35), Color(1, 1, 0.9))
		"tires":
			_tires(st, pal)
		"tent0", "tent1":
			_tent(st, pal[int(name_.right(1))])
	st.generate_normals()
	var m := st.commit()
	_mesh[key] = m
	return m


# ------------------------------------------------------------------ peças (z+ = para a pista)
static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, uv := Vector2.ZERO) -> void:
	var h := s * 0.5
	var v := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var f := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
	for q in f:
		for t in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for ix in t:
				st.set_color(col)
				var p: Vector3 = v[ix]
				st.set_uv(uv)   # x = fase da torcida, y = quanto pula (0 = parado)
				st.add_vertex(c + p)


static func _stand(st: SurfaceTool, pal: Array) -> void:
	# 5 degraus de concreto subindo para trás, cobertura na cor do tema sobre colunas
	for k in 5:
		_box(st, Vector3(0, 0.45 + k * 0.7, -k * 1.3), Vector3(22, 0.9 + k * 1.4 * 0.0 + 0.0, 1.3), CONCRETE.darkened(0.05 * k))
		_box(st, Vector3(0, 0.2 + k * 0.35, -k * 1.3), Vector3(22, 0.4 + k * 0.7, 1.3), CONCRETE.darkened(0.25))
	_box(st, Vector3(0, 2.0, -6.9), Vector3(22, 4.6, 0.6), STEEL)
	for x in [-10.5, -3.5, 3.5, 10.5]:
		_box(st, Vector3(x, 3.4, -6.4), Vector3(0.35, 6.8, 0.35), STEEL.darkened(0.2))
		_box(st, Vector3(x, 3.4, 0.6), Vector3(0.25, 6.8, 0.25), STEEL.darkened(0.2))
	_box(st, Vector3(0, 7.0, -2.9), Vector3(23.5, 0.35, 8.6), pal[0])
	_box(st, Vector3(0, 7.35, -2.9), Vector3(23.5, 0.35, 0.5), pal[3])
	# placa na frente da cobertura
	_box(st, Vector3(0, 6.45, 1.2), Vector3(23.5, 0.9, 0.2), pal[1])


static func _crowd(st: SurfaceTool, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + seed_
	var shirts := [Color("#e8352b"), Color("#ffb21a"), Color("#2e6fe0"), Color("#f4f2ff"), Color("#33c46b"), Color("#9b4dff"), Color("#ff7a1a"), Color("#1b1730")]
	var skin := [Color("#f1c7a5"), Color("#c68c5f"), Color("#8a5636"), Color("#5a3622")]
	for k in 5:
		var y := 0.9 + k * 0.7
		var z := -k * 1.3 - 0.1
		var x := -10.4
		while x < 10.4:
			if rng.randf() < 0.82:
				var ph := rng.randf()
				var sc := rng.randf_range(0.85, 1.1)
				_box(st, Vector3(x, y + 0.45 * sc, z), Vector3(0.5, 0.9, 0.38) * sc, shirts[rng.randi() % shirts.size()], Vector2(ph, 1.0))
				_box(st, Vector3(x, y + 1.08 * sc, z), Vector3(0.34, 0.34, 0.34) * sc, skin[rng.randi() % skin.size()], Vector2(ph, 1.0))
				if rng.randf() < 0.3:
					# braço levantado (bandeirinha ou punho)
					_box(st, Vector3(x + 0.28, y + 1.25 * sc, z), Vector3(0.13, 0.6, 0.13), shirts[rng.randi() % shirts.size()], Vector2(ph, 1.4))
			x += rng.randf_range(0.62, 0.8)


static func _banner(st: SurfaceTool, pal: Array, v: int) -> void:
	# painel de anúncio em dois postes: fundo da cor do tema, faixa diagonal e "logo" em blocos
	var bg: Color = [pal[0], INK, pal[1]][v]
	var fg: Color = [Color.WHITE, pal[3], INK][v]
	_box(st, Vector3(-3.6, 1.3, -0.1), Vector3(0.22, 2.6, 0.22), STEEL)
	_box(st, Vector3(3.6, 1.3, -0.1), Vector3(0.22, 2.6, 0.22), STEEL)
	_box(st, Vector3(0, 1.85, 0), Vector3(8.0, 1.5, 0.18), bg)
	_box(st, Vector3(0, 1.85, 0.1), Vector3(8.0, 0.22, 0.04), fg)
	for k in 4:
		_box(st, Vector3(-2.4 + k * 1.1, 2.2, 0.12), Vector3(0.75, 0.45, 0.04), fg)
	_box(st, Vector3(2.6, 1.5, 0.12), Vector3(1.6, 0.4, 0.04), pal[3] if v != 1 else Color.WHITE)


static func _fence(st: SurfaceTool) -> void:
	# cerca de proteção: postes e três cabos (lê como tela de alambrado de longe)
	for x in [-4.0, 0.0, 4.0]:
		_box(st, Vector3(x, 1.6, 0), Vector3(0.14, 3.2, 0.14), STEEL.lightened(0.2))
	for y in [0.9, 1.9, 2.9]:
		_box(st, Vector3(0, y, 0), Vector3(8.2, 0.06, 0.06), STEEL.lightened(0.35))
	for x in range(-8, 9):
		_box(st, Vector3(x * 0.5, 1.9, 0), Vector3(0.025, 2.1, 0.025), Color(0.75, 0.77, 0.82))


static func _light(st: SurfaceTool) -> void:
	# torre de holofote em treliça com plataforma
	_box(st, Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 1.6), CONCRETE)
	for c in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
		_box(st, Vector3(c.x, 5.4, c.y), Vector3(0.14, 10.0, 0.14), STEEL)
	for y in range(1, 10, 2):
		_box(st, Vector3(0, y, -0.4), Vector3(0.8, 0.08, 0.08), STEEL)
		_box(st, Vector3(0, y + 1, 0.4), Vector3(0.8, 0.08, 0.08), STEEL)
	_box(st, Vector3(0, 10.4, -0.6), Vector3(3.0, 0.2, 1.4), STEEL.darkened(0.3))
	_box(st, Vector3(0, 10.6, -1.0), Vector3(3.0, 1.1, 0.25), INK)


static func _tires(st: SurfaceTool, pal: Array) -> void:
	# pilhas de pneus (alguns pintados), em duas fileiras
	var col := [Color("#202024"), Color("#202024"), pal[0], Color.WHITE]
	var i := 0
	for x in [-1.3, 0.0, 1.3]:
		for z in [0.0, -1.2]:
			var hgt := 3 if (i % 3) != 1 else 2
			for k in hgt:
				_box(st, Vector3(x + z * 0.3, 0.22 + k * 0.42, z), Vector3(1.1, 0.4, 1.1), col[(i + k) % col.size()])
			i += 1


static func _tent(st: SurfaceTool, c: Color) -> void:
	# tenda de box: telhado listrado, mesa e caixas de ferramenta
	for x in [-2.3, 2.3]:
		for z in [-2.3, 2.3]:
			_box(st, Vector3(x, 1.4, z), Vector3(0.12, 2.8, 0.12), STEEL.lightened(0.3))
	for k in 6:
		_box(st, Vector3(-2.1 + k * 0.84, 2.95, 0), Vector3(0.84, 0.18, 5.0), c if k % 2 == 0 else Color.WHITE)
	_box(st, Vector3(0, 0.45, -1.5), Vector3(3.0, 0.9, 1.0), Color("#c43d1f"))
	_box(st, Vector3(1.6, 0.35, 1.2), Vector3(0.9, 0.7, 0.6), Color("#2f6fd6"))
	_box(st, Vector3(-1.5, 0.3, 1.0), Vector3(0.6, 0.6, 0.6), Color("#ffcc1f"))


# ------------------------------------------------------------------ detalhes do chão
## o chão liso em volta da pista parecia vazio: manchas de cor, tufos, pedras e entulho conforme o tema,
## mais densos perto da pista (é onde a câmera olha)
static func _clutter(game: Node, track: Track, theme: Dictionary, rng: RandomNumberGenerator) -> void:
	var g: int = theme.ground
	var gy: float = theme.gy
	var ga := Color(String(theme.ga))
	var gb := Color(String(theme.gb))
	var kinds: Array = []   # [nome, quantidade, escala mín, escala máx, sombra]
	match g:
		0:
			kinds = [["tuft", 520, 0.8, 1.5, false], ["flowers", 160, 0.8, 1.3, false], ["rocks", 70, 0.6, 1.6, true]]
		1:
			kinds = [["shrub", 220, 0.7, 1.5, false], ["rocks_red", 140, 0.6, 2.2, true], ["tuft_dry", 260, 0.8, 1.4, false]]
		2:
			kinds = [["drift", 220, 0.8, 2.2, false], ["rocks_ice", 90, 0.6, 1.8, true]]
		6:
			kinds = [["debris", 140, 0.8, 1.3, true], ["jersey", 70, 1.0, 1.0, true]]
		9:
			kinds = [["tuft_swamp", 300, 0.8, 1.5, false], ["rocks", 50, 0.6, 1.4, true]]
		5:
			kinds = [["rocks_moon", 160, 0.6, 2.0, true]]
		7:
			kinds = [["blocks", 160, 0.8, 1.6, true]]
		_:
			return
	var pts: Array = []
	for i in range(0, track.n, 2):
		if track.gap[i] == 1:
			continue
		pts.append(i)
	if pts.is_empty():
		return
	# manchas no chão (quebram a cor lisa)
	# manchas sutis: só um tom acima/abaixo do chão (antes ficavam escuras demais)
	var patch_cols := [ga.lerp(gb, 0.5).darkened(0.07), gb.lightened(0.05), ga.lerp(Color("#7a6a4a"), 0.12)]
	if g == 6:
		patch_cols = [ga.darkened(0.08), gb.darkened(0.05), ga.lightened(0.05)]
	for k in 160:
		var p: Variant = _spot(track, pts, rng, 4.0, 60.0, gy)
		if p == null:
			continue
		var sc := rng.randf_range(3.0, 11.0)
		var key := "patch%d" % (k % 3)
		game._batch_mesh("ad_" + key + str(g), _clutter_mesh(key, patch_cols[k % 3]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, 1, sc * rng.randf_range(0.5, 1.0))), p + Vector3.UP * 0.02), _flatm, false)
	for kd in kinds:
		for k in int(kd[1]):
			var p: Variant = _spot(track, pts, rng, 1.6, 45.0, gy)
			if p == null:
				continue
			var sc := rng.randf_range(float(kd[2]), float(kd[3]))
			game._batch_mesh("ad_" + String(kd[0]), _clutter_mesh(String(kd[0]), ga), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p), _mat, bool(kd[4]))


## ponto do chão perto da pista (distância da mureta entre near e far), livre de qualquer trecho
static func _spot(track: Track, pts: Array, rng: RandomNumberGenerator, near: float, far: float, gy: float) -> Variant:
	for t in 4:
		var i: int = pts[rng.randi() % pts.size()]
		var d := track.WALL + near + pow(rng.randf(), 1.6) * (far - near)
		var sg := 1.0 if rng.randf() < 0.5 else -1.0
		var p: Vector3 = track.P[i] + track.L[i] * sg * d + track.T[i] * rng.randf_range(-3.0, 3.0)
		p.y = gy
		if track.clearance_xz(p) > track.WALL + near * 0.8:
			return p
	return null


static func _clutter_mesh(name_: String, ground: Color) -> Mesh:
	var key := "cl_" + name_ + ground.to_html()
	if _mesh.has(key):
		return _mesh[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name_)
	match name_:
		"patch0", "patch1", "patch2":
			# disco achatado de 8 lados (raio 0,5; a escala dá o tamanho)
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				# ordem dos vértices com a face para cima (a de baixo ficava escura com a luz invertida)
				for v in [Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * 0.5, Vector3(cos(a1), 0, sin(a1)) * 0.5]:
					st.set_color(ground)
					st.set_uv(Vector2.ZERO)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
		"tuft", "tuft_dry", "tuft_swamp":
			var base: Color = {"tuft": Color("#3f8f2a"), "tuft_dry": Color("#b8955a"), "tuft_swamp": Color("#55682c")}[name_]
			for k in 7:
				var a := rng.randf() * TAU
				var h := rng.randf_range(0.35, 0.75)
				var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
				_box_b(st, Vector3(cos(a), 0, sin(a)) * 0.12 + Vector3.UP * h * 0.5, Vector3(0.06, h, 0.02), base.lightened(rng.randf() * 0.25), b)
		"flowers":
			var cs := [Color("#ffd23a"), Color("#ff5a7a"), Color("#f4f2ff"), Color("#9b6dff")]
			for k in 5:
				var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
				_box(st, p + Vector3.UP * 0.15, Vector3(0.03, 0.3, 0.03), Color("#3a7a22"))
				_box(st, p + Vector3.UP * 0.32, Vector3(0.13, 0.08, 0.13), cs[k % cs.size()])
		"rocks", "rocks_red", "rocks_ice", "rocks_moon":
			var c: Color = {"rocks": Color("#8a8a86"), "rocks_red": Color("#b0613a"), "rocks_ice": Color("#a9bdd6"), "rocks_moon": Color("#77777f")}[name_]
			for k in 3:
				var s := rng.randf_range(0.3, 0.7)
				_box_b(st, Vector3(rng.randf_range(-0.5, 0.5), s * 0.35, rng.randf_range(-0.5, 0.5)), Vector3(s, s * 0.7, s * 0.85), c.darkened(rng.randf() * 0.2),
					Basis.from_euler(Vector3(rng.randf() * 0.5, rng.randf() * TAU, rng.randf() * 0.5)))
		"shrub":
			for k in 6:
				var a := rng.randf() * TAU
				_box_b(st, Vector3(cos(a), 0, sin(a)) * 0.2 + Vector3.UP * 0.25, Vector3(0.05, 0.55, 0.05), Color("#7a5a36"), Basis(Vector3(-sin(a), 0, cos(a)), 0.6))
			_box(st, Vector3(0, 0.45, 0), Vector3(0.6, 0.3, 0.6), Color("#8f8a4a"))
		"drift":
			_box_b(st, Vector3(0, 0.12, 0), Vector3(1.4, 0.25, 0.8), Color("#f4f8ff"), Basis(Vector3.UP, 0.3))
			_box_b(st, Vector3(0.4, 0.2, 0.1), Vector3(0.8, 0.35, 0.6), Color("#e6eefa"), Basis(Vector3.UP, -0.4))
		"debris":
			_box_b(st, Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9), Color("#8a6a40"), Basis(Vector3.UP, 0.2))
			_box_b(st, Vector3(0.9, 0.12, 0.3), Vector3(0.6, 0.24, 0.4), Color("#5d6070"), Basis(Vector3.UP, 0.9))
			_box_b(st, Vector3(-0.7, 0.4, 0.4), Vector3(0.5, 0.8, 0.5), Color("#c43d1f"), Basis.IDENTITY)
		"jersey":
			_box(st, Vector3(0, 0.25, 0), Vector3(2.6, 0.5, 0.7), Color("#c9c6cc"))
			_box(st, Vector3(0, 0.65, 0), Vector3(2.6, 0.4, 0.35), Color("#c9c6cc"))
			_box(st, Vector3(0, 0.45, 0.36), Vector3(2.6, 0.12, 0.02), Color("#ff2d95"))
		"blocks":
			var cs2 := [Color("#ff4a4a"), Color("#ffcc1f"), Color("#2f8cff"), Color("#33c46b")]
			for k in 3:
				_box_b(st, Vector3(k * 0.55 - 0.5, 0.25 + (0.5 if k == 1 else 0.0), 0), Vector3(0.5, 0.5, 0.5), cs2[k], Basis(Vector3.UP, rng.randf() * 0.4))
	if not name_.begins_with("patch"):
		st.generate_normals()
	var m := st.commit()
	_mesh[key] = m
	return m


static func _box_b(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, b: Basis) -> void:
	var h := s * 0.5
	var v := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var f := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
	for q in f:
		for t in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for ix in t:
				st.set_color(col)
				st.set_uv(Vector2.ZERO)
				st.add_vertex(c + b * (v[ix] as Vector3))
