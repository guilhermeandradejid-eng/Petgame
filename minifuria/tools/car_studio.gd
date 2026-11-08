extends SceneTree
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/car_studio.gd -- <saida.png> <ângulo> <nível> [arma|none] [carro]
## com [carro] mostra só ele, de perto
## Estúdio com os carros REAIS do jogo (classe Car: kit por nível, armas do LOADOUT, pneus), para revisar o visual.
var frames := 0
var out := "user://car_studio.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var ang := float(args[1]) if args.size() > 1 else -35.0
	var lv := int(args[2]) if args.size() > 2 else 0
	var armed := not (args.size() > 3 and args[3] == "none")
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.86, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	root3.add_child(sun)
	var floor_ := StaticBody3D.new()
	var fmi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	fmi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.5, 0.52, 0.56)
	fmi.material_override = fm
	floor_.add_child(fmi)
	root3.add_child(floor_)
	var lib: Node3D = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	root3.add_child(lib)
	lib.visible = false
	var kinds := ["faisca", "vespa", "trovao", "monstro"]
	var cols := [Color("#e8352b"), Color("#2f6fd6"), Color("#ffd23a"), Color("#33c46b")]
	var solo := args[4] if args.size() > 4 else ""
	if solo != "":
		cols = [cols[kinds.find(solo)]]
		kinds = [solo]
	for i in kinds.size():
		var c := Car.new()
		root3.add_child(c)
		c.setup(lib, kinds[i], "rival", cols[i])
		var lo: Array = Car.LOADOUT[kinds[i]]
		c.configure(lib, lo[0] if armed else "none", lo[1], lo[2], {"engine": lv, "armor": lv, "ammo": lv, "nitro": lv, "tires": lv, "dmg": lv, "rate": lv})
		c.freeze = true
		var at := Vector3.ZERO if solo != "" else Vector3((i % 2) * 6.5 - 3.25, 0.0, (i / 2) * 7.0 - 3.5)
		c.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(ang)), at)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 13.0 if solo == "" else 5.6
	root3.add_child(cam)
	var look := Vector3(0, 0.6, 0)
	var cp := look + Vector3(14, float(args[5]) if args.size() > 5 else 11.0, 14)
	cam.transform = Transform3D(Basis.looking_at(look - cp, Vector3.UP), cp)
	cam.make_current()
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 10:
		get_root().get_texture().get_image().save_png(out)
		print("salvo ", out)
		quit()
