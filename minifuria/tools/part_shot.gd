extends SceneTree
## xvfb-run godot --path . -s res://tools/part_shot.gd -- <saida.png> <peça> [ângulo] [tamanho] [altura do olhar]
## Foto de uma peça solta do minicars.glb (kit, props, armas) com os materiais do jogo, para revisar a modelagem.
var frames := 0
var out := "user://part.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else out
	var nm := args[1] if args.size() > 1 else "kit_wing3"
	var ang := float(args[2]) if args.size() > 2 else -35.0
	var sz := float(args[3]) if args.size() > 3 else 3.0
	var ly := float(args[4]) if args.size() > 4 else 0.3
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.27)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	root3.add_child(sun)
	var lib: Node3D = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	root3.add_child(lib)
	lib.visible = false
	var gm: Node = load("res://scripts/main.gd").new()
	gm._prep_materials(lib, {})
	var p := lib.get_node(nm).duplicate() as Node3D
	p.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(ang)), Vector3.ZERO)
	root3.add_child(p)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = sz
	root3.add_child(cam)
	var look := Vector3(0, ly, 0)
	var cp := look + Vector3(10, 6, 10)
	cam.transform = Transform3D(Basis.looking_at(look - cp, Vector3.UP), cp)
	cam.make_current()
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 8:
		get_root().get_texture().get_image().save_png(out)
		quit()
