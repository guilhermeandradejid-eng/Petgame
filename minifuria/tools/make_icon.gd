extends SceneTree
## xvfb-run godot --path . --rendering-driver opengl3 --resolution 512x512 -s res://tools/make_icon.gd -- <saida.png>
## Ícone do app: a Faísca com a metralhadora no teto, fundo transparente (o fundo é composto depois).
var frames := 0
var out := "user://icon_car.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	get_root().transparent_bg = true
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_energy = 1.8
	root3.add_child(sun)
	var lib: Node3D = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	var car: Node3D = lib.get_node("car_faisca").duplicate()
	car.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-30)), Vector3.ZERO)
	root3.add_child(car)
	var mnt := car.get_node_or_null("faisca_mount") as Node3D
	if mnt:
		var w: Node3D = lib.get_node("wpn_gun").duplicate()
		w.position = mnt.position
		car.add_child(w)
	for ch in car.get_children():
		if ch is MeshInstance3D:
			for s in (ch as MeshInstance3D).mesh.get_surface_count():
				var m := (ch as MeshInstance3D).mesh.surface_get_material(s)
				if m and m.resource_name == "Paint":
					var pm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					pm.albedo_color = Color("#e8352b")
					(ch as MeshInstance3D).set_surface_override_material(s, pm)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.6
	root3.add_child(cam)
	var look := Vector3(0, 0.8, 0)
	var cp := look + Vector3(9, 6.5, 9)
	cam.transform = Transform3D(Basis.looking_at(look - cp, Vector3.UP), cp)
	cam.make_current()
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 8:
		get_root().get_texture().get_image().save_png(out)
		print("salvo ", out)
		quit()
