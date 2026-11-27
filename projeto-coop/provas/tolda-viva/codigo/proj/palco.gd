extends Node3D
# Palco do Pomar das Luas: praticável, telão, bastidores recortados, luas de papel penduradas,
# contrapeso, coxias, e a tolda (bambinela e empanada) presa à câmera.
const Boneco = preload("res://boneco.gd")

var luas: Array = []        # Vector4(x, 0, z, raio) dos discos no chão
var mats_luz: Array = []    # materiais que recebem as luas
var cam: Camera3D

func sm(n: String, p := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Boneco.sh(n)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m

func quad(size: Vector2, pos: Vector3, mat: Material, flat := false, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if flat:
		var pm := PlaneMesh.new(); pm.size = size; mi.mesh = pm
	else:
		var q := QuadMesh.new(); q.size = size; mi.mesh = q
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi

func box(size: Vector3, pos: Vector3, col: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = size; mi.mesh = b
	mi.position = pos
	mi.material_override = sm("boneco", {})
	var st := mi.material_override as ShaderMaterial
	# cor sólida: boneco usa COLOR; aqui passamos por textura 1x1
	var img := Image.create(1, 1, false, Image.FORMAT_RGB8); img.fill(col)
	st.set_shader_parameter("use_tex", true)
	st.set_shader_parameter("tecido", ImageTexture.create_from_image(img))
	(parent if parent else self).add_child(mi)
	return mi

func corda(a: Vector3, b: Vector3, r := 0.018, col := Color("#5B4232")) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = a.distance_to(b); c.radial_segments = 6
	mi.mesh = c
	add_child(mi)
	mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	if abs(d.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, d))
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = col
	mi.material_override = m

func montar(camera: Camera3D, lua_spec: Array, opts := {}) -> void:
	cam = camera
	# praticável
	var chao := sm("chao", {"tabuas": Boneco.tex("tex/praticavel.png")})
	quad(Vector2(20, 14), Vector3(0, 0, 0), chao, true)
	mats_luz.append(chao)
	# frente do praticável (espessura de tábua) e fosso escuro
	box(Vector3(20, 0.5, 0.1), Vector3(0, -0.25, 7.0), Color("#3a2a22"))
	# telão ao fundo, alto, um pouco inclinado para a câmera
	# telão inclinado para trás (de frente para a câmera de camarote): é lona pintada, a inclinação não aparece
	var TH: float = opts.get("telao_h", 3.6)
	var lean := deg_to_rad(float(opts.get("lean", 62.0)))
	var tz: float = opts.get("telao_z", -3.9)
	var tel := quad(Vector2(26, TH), Vector3(0, TH * 0.5 * cos(lean), tz - TH * 0.5 * sin(lean)), sm("pintura", {"tex": Boneco.tex("tex/telao.png"), "brilho": 0.95}))
	tel.rotation.x = -lean
	# bastidores recortados de árvore em 2 planos
	var arv: Array = opts.get("arvores", [[-6.9, -3.3, 3.0, 0], [-3.9, -3.7, 3.3, 1], [3.6, -3.5, 3.2, 2], [6.8, -3.1, 2.9, 0], [0.4, -4.0, 2.6, 1]])
	for a in arv:
		var w: float = a[2] * 0.78
		var q := quad(Vector2(w, a[2]), Vector3(a[0], a[2] * 0.5 * cos(deg_to_rad(25)), a[1] - a[2] * 0.5 * sin(deg_to_rad(25))), sm("pintura", {"tex": Boneco.tex("tex/arvore%d.png" % a[3]), "recorte": true}))
		q.rotation.x = deg_to_rad(-25)
		# mão-francesa de sarrafo atrás e o saco de peso
		corda(Vector3(a[0], a[2] * 0.4, a[1] - a[2] * 0.25), Vector3(a[0], 0.0, a[1] - 1.3), 0.035, Color("#6b4a36"))
	# coxias: pernas de pano escuro nas laterais
	for s in [-1.0, 1.0]:
		for k in 3:
			var cx: float = s * (9.6 - k * 0.35)
			var cz: float = -5.0 + k * 4.2
			var c := quad(Vector2(1.8, 7.0), Vector3(cx, 3.5, cz), sm("tolda", {"tex": Boneco.tex("tex/lona_listrada.png"), "rep": Vector2(0.4, 1.0), "festao": -1.0, "n_festao": 1.0, "pregas": 0.12, "sombra": 0.55}))
			c.rotation.y = deg_to_rad(-s * 70)
			(c.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.4, 0.4, 0.5))
	# luas de papel penduradas, cada uma com um disco de luz no chão
	for L in lua_spec:
		var p: Vector3 = L[0]
		var r: float = L[1]
		var disco := quad(Vector2(r, r) * 2.0, p, sm("pintura", {"tex": Boneco.tex("tex/lua.png"), "recorte": true, "brilho": 1.08}))
		disco.basis = cam.global_basis
		corda(p + Vector3(0, r * 0.95, 0), p + Vector3(0, 12, 0), 0.012, Color("#1D1820"))
		luas.append(Vector4(p.x, 0, p.z, L[2]))
	for m in mats_luz:
		_luas_em(m)

func _luas_em(m: ShaderMaterial) -> void:
	var arr: Array = []
	for i in 4:
		arr.append(luas[i] if i < luas.size() else Vector4(0, 0, 0, 0))
	m.set_shader_parameter("luas", arr)

func luas_no_boneco(b) -> void:
	for mn in ["cor", "pano"]:
		if b.mats.has(mn):
			for m in b.mats[mn]:
				_luas_em(m)

func tolda_na_camera(alt_top := 0.09, alt_bot := 0.06) -> void:
	# bambinela fixa em cima e borda da empanada embaixo, presas à câmera (moldura de palco)
	var d := 1.2
	var h := 2.0 * d * tan(deg_to_rad(cam.fov * 0.5))
	var aspect := 16.0 / 9.0
	var w := h * aspect * 1.08
	var top := quad(Vector2(w, h * alt_top * 1.25), Vector3(0, h * 0.5 - h * alt_top * 0.62, -d), sm("tolda", {"tex": Boneco.tex("tex/lona_listrada.png"), "rep": Vector2(1.5, 0.2), "festao": 1.0, "n_festao": 7.0, "pregas": 0.004, "sombra": 0.78, "brilho": 0.34}), false, cam)
	var bot := quad(Vector2(w, h * alt_bot * 1.25), Vector3(0, -h * 0.5 + h * alt_bot * 0.62, -d), sm("tolda", {"tex": Boneco.tex("tex/lona_listrada.png"), "rep": Vector2(1.7, 0.18), "festao": -1.0, "n_festao": 5.0, "pregas": 0.004, "sombra": 0.7, "brilho": 0.26}), false, cam)
	top.sorting_offset = 10; bot.sorting_offset = 10
	for q in [top, bot]:
		(q.material_override as ShaderMaterial).render_priority = 10
	# v2: vinheta de palco presa à câmera (bordas escuras, centro iluminado)
	var vq := quad(Vector2(w, h), Vector3(0, 0, -d * 0.98), sm("vinheta", {"aspect": aspect}), false, cam)
	vq.sorting_offset = 9
	(vq.material_override as ShaderMaterial).render_priority = 9

# v2: canhão seguidor de verdade (SpotLight3D) vindo do balcão, atrás da câmera
func canhao(energia := 2.2, ang := 11.0) -> SpotLight3D:
	var sp := SpotLight3D.new()
	sp.light_energy = energia
	sp.light_color = Color(1.0, 0.96, 0.88)
	sp.spot_angle = ang
	sp.spot_angle_attenuation = 0.6
	sp.spot_attenuation = 0.0
	sp.spot_range = 30.0
	sp.shadow_enabled = false
	add_child(sp)
	return sp

func mira(sp: SpotLight3D, alvo: Vector3) -> void:
	sp.global_position = alvo + Vector3(0.6, 7.5, 6.0)
	sp.look_at(alvo + Vector3(0, 0.3, 0))

func contrapeso(pos: Vector3, altura: float, esc := 0.75) -> Node3D:
	var n := Node3D.new(); add_child(n); n.position = pos + Vector3(0, altura, 0)
	var saco := MeshInstance3D.new()
	var sp := SphereMesh.new(); sp.radius = 0.42; sp.height = 1.0; sp.radial_segments = 12; sp.rings = 8
	saco.mesh = sp
	var m := sm("boneco", {"use_tex": true, "tecido": Boneco.tex("tex/juta.png")})
	saco.material_override = m
	mats_luz.append(m)
	n.add_child(saco)
	saco.scale = Vector3(1.0, 1.15, 0.9) * esc
	n.set_meta("saco", saco)
	# amarração no topo
	var nk := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.06; cy.bottom_radius = 0.14; cy.height = 0.3; cy.radial_segments = 8
	nk.mesh = cy; nk.position = Vector3(0, 0.62 * esc, 0); nk.scale = Vector3.ONE * esc; nk.material_override = m; n.add_child(nk)
	corda(pos + Vector3(0, altura + 0.75 * esc, 0), pos + Vector3(0, 14, 0), 0.02)
	return n
