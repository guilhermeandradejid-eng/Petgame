extends SceneTree
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/render_sprites.gd
## Renderiza o carro Faísca de lado (sem rodas) e uma roda, com fundo transparente, para o carregamento.
var frames := 0
var vp: SubViewport
var car: Node3D
var stage := 0
var wheel: MeshInstance3D


func _init() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(900, 420)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.95)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -60, 0)
	sun.light_energy = 1.7
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 120, 0)
	fill.light_energy = 0.5
	vp.add_child(fill)
	var lib: Node3D = (load("res://assets/minicars.glb") as PackedScene).instantiate()
	car = lib.get_node("car_faisca").duplicate()
	car.transform = Transform3D.IDENTITY
	vp.add_child(car)
	var info := {}
	for ch in car.get_children():
		if ch is MeshInstance3D and String(ch.name).substr(7).begins_with("w") and String(ch.name).length() == 10:
			(ch as Node3D).visible = false
			info[String(ch.name).substr(7)] = [ch.position.z, ch.position.y]
	# câmera: de lado (lado -X), frente do carro para a direita; 900x420 px
	var S := 2.9
	var cz := 0.0
	var cy := 0.55
	var ppm := 420.0 / S
	var out := {"ppm": ppm, "w": []}
	for k in ["wFL", "wRL"]:
		var zy: Array = info[k]
		out.w.append([450.0 + (float(zy[0]) - cz) * ppm, 210.0 - (float(zy[1]) - cy) * ppm, float(zy[1]) * ppm])
	var f := FileAccess.open("res://ui/load_car.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	# pneu esportivo (o mesmo do jogo) para a roda
	var t: MeshInstance3D = lib.get_node("tire_sport").duplicate()
	wheel = t
	wheel.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.0)), Vector3(0, 0, 0))
	wheel.visible = false
	vp.add_child(wheel)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.9
	# vista de lado (lado esquerdo do carro), frente para a direita da tela
	cam.transform = Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), Vector3(-6, 0.55, 0.0))
	vp.add_child(cam)
	cam.current = true
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 10 and stage == 0:
		vp.get_texture().get_image().save_png("res://ui/load_car.png")
		car.visible = false
		wheel.visible = true
		var c := vp.get_camera_3d()
		c.size = 1.05
		c.transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), Vector3(6, 0, 0))
		vp.size = Vector2i(256, 256)
		stage = 1
		frames = 0
	elif frames == 10 and stage == 1:
		vp.get_texture().get_image().save_png("res://ui/load_wheel.png")
		print("sprites salvos")
		quit()
