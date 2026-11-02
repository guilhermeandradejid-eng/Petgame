class_name Rig
extends RefCounted
## Controla o esqueleto exportado do Blender com poses descritas nos eixos do
## personagem (X = lado esquerdo, Y = cima, Z = frente), independentemente da
## orientação de cada osso. Cada rotação é relativa ao pai, como num boneco
## articulado: girar o braço leva junto antebraço, mão e raquete.

var sk: Skeleton3D
var bones := {}          # nome -> índice
var order: Array[int] = []
var parent := {}         # índice -> índice do pai (-1)
var rest_global := {}    # índice -> Basis de repouso no espaço do esqueleto
var rest_origin := {}    # índice -> origem local de repouso
var cur := {}            # nome -> Vector3 (euler atual, suavizado)
var hips := -1


func _init(skeleton: Skeleton3D) -> void:
	sk = skeleton
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i)] = i
		parent[i] = sk.get_bone_parent(i)
		rest_global[i] = sk.get_bone_global_rest(i).basis.orthonormalized()
		rest_origin[i] = sk.get_bone_rest(i).origin
	# ordem: pais antes dos filhos
	var pending: Array[int] = []
	for i in sk.get_bone_count():
		pending.append(i)
	var done := {}
	while pending.size() > 0:
		var keep: Array[int] = []
		for i in pending:
			var p: int = parent[i]
			if p < 0 or done.has(p):
				order.append(i)
				done[i] = true
			else:
				keep.append(i)
		pending = keep
	hips = bones.get("Hips", -1)


func has(name: String) -> bool:
	return bones.has(name)


## Aplica a pose. target: nome -> Vector3 euler (YXZ) nos eixos do personagem.
## k: fator de suavização (0..1) para misturar com a pose atual.
func apply(target: Dictionary, k: float, hips_offset := Vector3.ZERO) -> void:
	for n in target:
		var t: Vector3 = target[n]
		var c: Vector3 = cur.get(n, Vector3.ZERO)
		cur[n] = Vector3(lerp_angle(c.x, t.x, k), lerp_angle(c.y, t.y, k), lerp_angle(c.z, t.z, k))
	for n in cur.keys():
		if not target.has(n):
			var c2: Vector3 = cur[n]
			cur[n] = c2.lerp(Vector3.ZERO, k)
	var acc := {}
	var glob := {}
	for i in order:
		var name := sk.get_bone_name(i)
		var r := Basis.from_euler(cur.get(name, Vector3.ZERO))
		var p: int = parent[i]
		var q: Basis = (acc[p] as Basis) * r if p >= 0 else r
		acc[i] = q
		var g: Basis = q * (rest_global[i] as Basis)
		glob[i] = g
		var local: Basis = g if p < 0 else (glob[p] as Basis).inverse() * g
		sk.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	if hips >= 0:
		sk.set_bone_pose_position(hips, rest_origin[hips] + hips_offset)


## Transform de repouso de um ponto do modelo expresso no espaço do osso
## (para prender objetos rígidos, como a raquete, com BoneAttachment3D).
func local_to_bone(bone: String, model_xf: Transform3D) -> Transform3D:
	var i: int = bones[bone]
	return sk.get_bone_global_rest(i).affine_inverse() * model_xf
