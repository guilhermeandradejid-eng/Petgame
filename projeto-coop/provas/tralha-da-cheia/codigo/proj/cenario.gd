extends Node3D
# Monta o Trapiche Velho: grupos de cenário (GLB facetados e pintados), água em faixa pintada e marolas
# recortadas que sobem e descem em degrau.
const Boneco = preload("res://boneco.gd")
var agua_mat: ShaderMaterial
var marolas: Array = []
var grupos := {}

func montar(lista := ["trapiche", "objetos", "fundo", "frente", "marolas_f", "marolas_t"]) -> void:
	for g in lista:
		var b = Boneco.new()
		add_child(b)
		b.setup(g)
		grupos[g] = b
		if g in ["trapiche", "objetos"]:
			# v2: sombra do piso clara (tinta a ~80% de valor) e degrau do meio alto: o piso fica no meio-tom claro
			b.todos("shadow_tint", Color(0.8, 0.76, 0.86))
			b.todos("mid", 0.88)
		if g.begins_with("marolas"):
			marolas.append(b)
			b.todos("shadow_tint", Color(0.78, 0.8, 0.9))
			b.todos("mid", 0.92)
	# água: plano grande em faixa pintada
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(90, 70); pm.subdivide_width = 0; mi.mesh = pm
	mi.position = Vector3(0, -0.55, -8)
	agua_mat = ShaderMaterial.new(); agua_mat.shader = load("res://shaders/agua.gdshader")
	agua_mat.set_shader_parameter("shadow_tint", Color(0.74, 0.72, 0.86))
	mi.material_override = agua_mat
	add_child(mi)
	# vão escuro embaixo do piso (aparece onde falta tábua)
	var vao := MeshInstance3D.new(); var vp := PlaneMesh.new(); vp.size = Vector2(22, 5.5); vao.mesh = vp
	vao.position = Vector3(0, -0.12, 0.05)
	var vm := StandardMaterial3D.new(); vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; vm.albedo_color = Color("#2a2433")
	vao.material_override = vm
	add_child(vao)

func passo(t: float) -> void:
	# marolas em degrau: 3 poses por segundo, cada fileira com fase própria
	var tq := floorf(t * 3.0)
	agua_mat.set_shader_parameter("t_q", tq)
	for i in marolas.size():
		var m: Node3D = marolas[i]
		var k := int(tq) + i * 2
		m.position = Vector3(0.12 * float((k % 3) - 1), [0.0, 0.05, -0.03][k % 3], 0)
