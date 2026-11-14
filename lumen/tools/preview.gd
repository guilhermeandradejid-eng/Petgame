# Ferramenta de preview: carrega um .glb em tempo de execucao, aplica o shader toon
# e salva uma folha de contato. Rode por tools/shot.sh:
#
#   tools/shot.sh glb=<arquivo> out=<png> [size=1600x700] [zoom=1.7] [cy=0.68] [pitch=8]
#
# Modos:
#   (padrao)      copias do modelo lado a lado.  yaws=0,35,90,180  spacing=1.0
#                 show=a,b*  hide=c*   (filtra MeshInstance por nome; * = prefixo)
#   anim=<clipe>  times=0,0.1,0.2      (uma copia por tempo, em segundos)
#   sets=a+b;c+d  uma copia por conjunto de pecas do heroi. Mostra base_*, eyes_round e as
#                 pecas listadas; slots sem peca usam a roupa de referencia (_ref_* ou as
#                 pecas iniciais). Le <glb>_manifest.json para saber se o chapeu esconde cabelo.
#   layout=row    para kits de cenario/props: espalha cada malha do glb numa fileira
#                 (filter=tree*,rock* opcional). O zoom se ajusta sozinho.
#   pal=skin:f6c9a4,primary:d94f4f     troca cores da paleta
#   bg=8f8aa8     cor de fundo
extends SceneTree

var args := {}
var frames := 0
var out := ""

const PAL := {
	"skin": Color("f6c9a4"), "hair": Color("7a4a2e"), "primary": Color("3f86d9"), "secondary": Color("f3ead6"),
	"accent": Color("f2b632"), "metal": Color("c3cede"), "leather": Color("7d5334"), "eye": Color("2b2238"),
	"iris": Color("5fb0e8"), "white": Color("ffffff"), "dark": Color("2f2a3d"), "mouth": Color("8c3b3b"),
	"glow": Color("ffffff"), "vcol": Color("ffffff"), "vcol_wind": Color("ffffff"), "water": Color("ffffff"),
}
const SLOT_PREFIX := {
	"hair_": "hair", "hat_": "hat", "ears_": "ears", "acc_": "acc", "top_": "top", "bottom_": "bottom",
	"back_": "back", "sword_": "weapon", "bow_": "weapon", "staff_": "weapon", "hammer_": "weapon",
	"eyes_": "eyes",
}
const DEFAULTS := {"hair": "hair_bagunca", "top": "top_tunica", "bottom": "bottom_botas"}

var pal := {}
var manifest := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	out = args.get("out", "/tmp/preview.png")
	var size := Vector2i(1600, 700)
	if args.has("size"):
		var s: PackedStringArray = args["size"].split("x")
		size = Vector2i(int(s[0]), int(s[1]))
	root.size = size
	DisplayServer.window_set_size(size)
	pal = PAL.duplicate()
	if args.has("pal"):
		for kv in args["pal"].split(","):
			var p: PackedStringArray = kv.split(":")
			pal[p[0]] = Color(p[1])
	var mpath: String = str(args["glb"]).get_basename() + "_manifest.json"
	if FileAccess.file_exists(mpath):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(mpath))

	var bg := Color(str(args.get("bg", "8f8aa8")))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9a8fd6")
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.ssao_radius = 0.4
	e.ssao_intensity = 1.2
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0 if args.get("layout", "") == "row" else 14.0
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = bg
	floor_mi.material_override = fm
	root.add_child(floor_mi)

	var zoom := float(args.get("zoom", "1.7"))
	var cy := float(args.get("cy", "0.68"))
	if args.get("layout", "") == "row":
		var info := _layout_row()
		zoom = info.x
		cy = info.y
	else:
		_layout_copies()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 200.0
	var pitch := deg_to_rad(float(args.get("pitch", "8")))
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, cy + sin(pitch) * 40.0, cos(pitch) * 40.0), Vector3(0, cy, 0))

func _load() -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(args["glb"], st) != OK:
		push_error("falha ao carregar glb")
		quit(1)
		return null
	return doc.generate_scene(st)

func _layout_copies() -> void:
	var yaws: Array = []
	for y in str(args.get("yaws", "0,35,90,180")).split(","):
		yaws.append(float(y))
	var times: Array = []
	if args.has("times"):
		for t in str(args["times"]).split(","):
			times.append(float(t))
	var sets: Array = []
	if args.has("sets"):
		for s in str(args["sets"]).split(";"):
			sets.append(Array(s.split("+")))
	var count: int = yaws.size()
	if times.size() > 0:
		count = max(count if args.has("yaws") and yaws.size() > 1 else 1, times.size())
	if sets.size() > 0:
		count = sets.size()
	var spacing := float(args.get("spacing", "1.0"))
	var shows: Array = Array(str(args["show"]).split(",")) if args.has("show") else []
	var hides: Array = Array(str(args["hide"]).split(",")) if args.has("hide") else []
	for i in count:
		var scene := _load()
		if scene == null:
			return
		var pivot := Node3D.new()
		root.add_child(pivot)
		pivot.add_child(scene)
		pivot.position.x = (i - (count - 1) * 0.5) * spacing
		pivot.rotation_degrees.y = yaws[min(i, yaws.size() - 1)]
		var visible_set := {}
		if sets.size() > 0:
			visible_set = _resolve_set(scene, sets[i])
		_apply(scene, shows, hides, visible_set, sets.size() > 0)
		if args.has("anim"):
			var ap: AnimationPlayer = _find(scene, "AnimationPlayer")
			if ap:
				var t: float = times[min(i, times.size() - 1)] if times.size() > 0 else 0.0
				if i == 0 and args.has("list"):
					print("anims: ", ap.get_animation_list())
				ap.play(args["anim"])
				ap.seek(t, true)
				ap.pause()

func _resolve_set(scene: Node, names: Array) -> Dictionary:
	var all := {}
	_collect(scene, all)
	var vis := {}
	var used_slots := {}
	var hide_hair := "keep"
	for n in names:
		n = str(n).replace(".", "_")
		if not all.has(n):
			push_warning("peca nao encontrada: " + n)
			continue
		vis[n] = true
		for pre in SLOT_PREFIX:
			if n.begins_with(pre):
				used_slots[SLOT_PREFIX[pre]] = n
		if manifest.has(n) and manifest[n].has("hair"):
			hide_hair = manifest[n]["hair"]
	for nm in all:
		if nm.begins_with("base_"):
			vis[nm] = true
	if not used_slots.has("eyes"):
		vis["eyes_round"] = true
	for slot in ["hair", "top", "bottom"]:
		if not used_slots.has(slot):
			var ref: String = "_ref_" + str(slot)
			if all.has(ref):
				vis[ref] = true
				used_slots[slot] = ref
			elif all.has(DEFAULTS[slot]):
				vis[DEFAULTS[slot]] = true
				used_slots[slot] = DEFAULTS[slot]
	if used_slots.has("hair"):
		var h: String = used_slots["hair"]
		if hide_hair == "hide":
			vis.erase(h)
		elif hide_hair == "keep" and all.has(h + "__top"):
			vis[h + "__top"] = true
	return vis

func _collect(n: Node, into: Dictionary) -> void:
	if n is MeshInstance3D:
		into[String(n.name)] = n
	for c in n.get_children():
		_collect(c, into)

func _layout_row() -> Vector2:
	var scene := _load()
	if scene == null:
		return Vector2(2, 1)
	root.add_child(scene)
	var all := {}
	_collect(scene, all)
	var names := all.keys()
	names.sort()
	var filt: Array = Array(str(args["filter"]).split(",")) if args.has("filter") else []
	var gap := float(args.get("gap", "0.5"))
	var x := 0.0
	var max_h := 0.5
	var placed: Array = []
	for nm in names:
		var mi: MeshInstance3D = all[nm]
		var ok := filt.is_empty()
		for f in filt:
			if nm == f or (f.ends_with("*") and nm.begins_with(f.trim_suffix("*"))):
				ok = true
		mi.visible = ok
		if not ok:
			continue
		_materials(mi)
		var bb: AABB = mi.get_aabb()
		var w: float = max(bb.size.x, 0.2)
		mi.position = Vector3(x - bb.position.x, 0, 0)
		mi.rotation = Vector3.ZERO
		x += w + gap
		max_h = max(max_h, bb.end.y)
		placed.append(mi)
		var lbl := Label3D.new()
		lbl.text = nm
		lbl.font_size = 48
		lbl.pixel_size = 0.004
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color("2a2233")
		lbl.outline_size = 0
		lbl.position = Vector3(mi.position.x + bb.position.x + w * 0.5, -0.25, bb.end.z + 0.4)
		root.add_child(lbl)
	var total := x - gap
	for mi in placed:
		mi.position.x -= total * 0.5
	for c in root.get_children():
		if c is Label3D:
			c.position.x -= total * 0.5
	var aspect := float(root.size.x) / float(root.size.y)
	var need: float = max(total / aspect * 1.06, max_h * 1.35 + 0.6)
	return Vector2(need, max_h * 0.5 - 0.1)

func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null

func _match(nm: String, pats: Array) -> bool:
	for s in pats:
		if nm == s or (s.ends_with("*") and nm.begins_with(s.trim_suffix("*"))):
			return true
	return false

func _apply(n: Node, shows: Array, hides: Array, vis: Dictionary, use_vis: bool) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var nm := String(mi.name)
		if use_vis:
			mi.visible = vis.has(nm)
		elif shows.size() > 0:
			mi.visible = _match(nm, shows)
		if _match(nm, hides):
			mi.visible = false
		_materials(mi)
	for c in n.get_children():
		_apply(c, shows, hides, vis, use_vis)

func _materials(mi: MeshInstance3D) -> void:
	for si in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(si)
		var mname := m.resource_name if m else "vcol"
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/toon.gdshader")
		sm.set_shader_parameter("tint", pal.get(mname, Color.WHITE))
		if mname == "metal":
			sm.set_shader_parameter("gloss", 0.9)
		if mname == "glow":
			sm.set_shader_parameter("shade_boost", 2.2)
		mi.set_surface_override_material(si, sm)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 6:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	return false
