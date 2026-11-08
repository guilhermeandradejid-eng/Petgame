extends SceneTree
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/car_preview.gd -- <saida.png>
## Foto de estúdio dos carros do jogo (com arma no teto) para conferir montagem e acabamento.
var frames := 0
var out := "user://cars_preview.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.86, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	root3.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.57, 0.6)
	floor_.material_override = fm
	root3.add_child(floor_)
	var lib: Node3D = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	var kinds := ["faisca", "trovao", "vespa", "policia", "picape", "van"]
	var weps := ["wpn_gun", "wpn_pod", "wpn_gun", "", "", ""]
	for i in kinds.size():
		var car: Node3D = lib.get_node("car_" + kinds[i]).duplicate()
		car.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-35)), Vector3((i % 3) * 5.2 - 5.2, 0, (i / 3) * 6.0 - 3.0))
		root3.add_child(car)
		var mnt := car.get_node_or_null(kinds[i] + "_mount") as Node3D
		if weps[i] != "" and mnt:
			var w: Node3D = lib.get_node(weps[i]).duplicate()
			w.position = mnt.position
			car.add_child(w)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args[1]) if args.size() > 1 else 13.0
	root3.add_child(cam)
	var look := Vector3(float(args[2]), 0.6, float(args[3])) if args.size() > 3 else Vector3(0, 0.6, 0)
	var cp := look + Vector3(14, 11, 14)
	cam.transform = Transform3D(Basis.looking_at(look - cp, Vector3.UP), cp)
	cam.make_current()
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 8:
		get_root().get_texture().get_image().save_png(out)
		print("salvo ", out)
		quit()
