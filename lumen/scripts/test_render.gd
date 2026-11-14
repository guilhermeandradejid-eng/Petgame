extends Node3D

var frames := 0

func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2, 5)
	cam.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.shadow_enabled = true
	var mi := MeshInstance3D.new()
	mi.mesh = TorusMesh.new()
	add_child(mi)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.glow_enabled = true
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	env.environment = e
	add_child(env)

func _process(_d: float) -> void:
	frames += 1
	if frames == 10:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/claude-0/-home-user-Petgame/e02ceb96-d908-5674-8d0e-8d7b9a8764ca/scratchpad/test.png")
		print("saved ", Engine.get_frames_per_second())
		get_tree().quit()
