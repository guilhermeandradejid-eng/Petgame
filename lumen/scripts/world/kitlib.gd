class_name KitLib
## Acesso aos kits de cenario/props exportados do Blender: cada kit e um .glb com uma
## malha por objeto e um manifesto (colisor, etiquetas, luz).

static var _meshes: Dictionary = {}

static func _load(kit: String) -> Dictionary:
	if _meshes.has(kit):
		return _meshes[kit]
	var out: Dictionary = {}
	var path := "res://assets/models/%s.glb" % kit
	if ResourceLoader.exists(path):
		var inst: Node = (load(path) as PackedScene).instantiate()
		_collect(inst, out)
		inst.free()
	_meshes[kit] = out
	return out

static func _collect(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out[String(n.name)] = (n as MeshInstance3D).mesh
	for c in n.get_children():
		_collect(c, out)

static func has(kit: String, piece: String) -> bool:
	return _load(kit).has(piece)

static func mesh(kit: String, piece: String) -> Mesh:
	return _load(kit).get(piece)

static func meta(kit: String, piece: String) -> Dictionary:
	return DB.kits.get(kit, {}).get(piece, {})

static func by_tag(kit: String, tag: String) -> Array:
	var out: Array = []
	var man: Dictionary = DB.kits.get(kit, {})
	var have := _load(kit)
	for nm in man:
		if have.has(nm) and (man[nm].get("tags", []) as Array).has(tag):
			out.append(nm)
	out.sort()
	return out

## Instancia uma peca com os materiais do jogo. Retorna null se o kit nao tiver a peca.
static func make(kit: String, piece: String) -> MeshInstance3D:
	var m := mesh(kit, piece)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.name = piece
	for si in m.get_surface_count():
		var src := m.surface_get_material(si)
		mi.set_surface_override_material(si, Mats.env(src.resource_name if src else "vcol"))
	return mi

## Cria a forma de colisao descrita no manifesto (ou null).
static func collider(kit: String, piece: String, scale: float = 1.0) -> CollisionShape3D:
	var c: Variant = meta(kit, piece).get("collider")
	if not (c is Dictionary):
		return null
	var cs := CollisionShape3D.new()
	if c["type"] == "cyl":
		var sh := CylinderShape3D.new()
		sh.radius = float(c["r"]) * scale
		sh.height = float(c["h"]) * scale
		cs.shape = sh
		cs.position.y = sh.height * 0.5
	else:
		var bx := BoxShape3D.new()
		bx.size = Vector3(float(c["w"]), float(c["h"]), float(c["d"])) * scale
		cs.shape = bx
		cs.position.y = bx.size.y * 0.5
	return cs

static func collider_radius(kit: String, piece: String) -> float:
	var c: Variant = meta(kit, piece).get("collider")
	if not (c is Dictionary):
		return 0.0
	if c["type"] == "cyl":
		return float(c["r"])
	return maxf(float(c["w"]), float(c["d"])) * 0.5

static func light_of(kit: String, piece: String) -> OmniLight3D:
	var l: Variant = meta(kit, piece).get("light")
	if not (l is Dictionary):
		return null
	var o := OmniLight3D.new()
	o.light_color = Color(str(l.get("color", "#ffffff")))
	o.light_energy = float(l.get("energy", 1.5))
	o.omni_range = float(l.get("range", 5.0))
	o.position.y = float(l.get("height", 1.0))
	o.shadow_enabled = false
	return o
