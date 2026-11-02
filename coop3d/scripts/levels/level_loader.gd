extends Node
## Root of level.tscn. First warms up every shader one per frame while
## recording progress with Game.trace() (so a GPU-driver crash can be
## pinpointed and worked around on the next launch), then builds the level.

const WARM := ["sky", "toon", "outline", "terrain", "glow", "grass", "cloud_sea", "ghost", "portal", "shockwave", "beam", "bubble", "water"]

var _label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.1, 0.28)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	_label = UiTheme.outlined("Preparando...", 48, Color(1, 0.9, 0.6), 12)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_label)
	await _warmup()
	Game.trace("level:build")
	var info: Dictionary = Game.LEVELS[Game.current_level]
	var lvl: Node = load(info["script"]).new()
	lvl.name = "Level"
	add_child(lvl)
	layer.queue_free()
	Game.trace("level:play")
	await get_tree().create_timer(6.0).timeout
	Game.trace("ok")


func _warmup() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 1, -2)
	root.add_child(omni)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	root.add_child(we)
	var i := 0
	for name in WARM:
		i += 1
		_label.text = "Preparando shaders... %d/%d" % [i, WARM.size()]
		Game.trace("shader:" + name)
		var n: Node3D
		if name == "sky":
			var env := Environment.new()
			env.background_mode = Environment.BG_SKY
			env.sky = Sky.new()
			env.sky.sky_material = ShaderLib.material("sky")
			we.environment = env
		elif name == "grass":
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = QuadMesh.new()
			mm.instance_count = 4
			for k in 4:
				mm.set_instance_transform(k, Transform3D(Basis(), Vector3(k * 0.3, 0, 0)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = ShaderLib.material("grass")
			n = mmi
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = SphereMesh.new()
			if name == "outline":
				var base := ShaderLib.material("toon")
				base.next_pass = ShaderLib.material("outline")
				mi.material_override = base
			else:
				mi.material_override = ShaderLib.material(name)
			n = mi
		if n:
			n.position = Vector3(0, 0, -3)
			root.add_child(n)
		for f in 3:
			await get_tree().process_frame
		if n:
			n.queue_free()
	# standard-material effects (particles, 3D text)
	Game.trace("std:particles")
	Vfx.burst(Vector3(0, 0, -3), Color.WHITE, 4, 1.0)
	var l := Label3D.new()
	l.text = "ok"
	l.position = Vector3(0, 0, -3)
	root.add_child(l)
	for f in 3:
		await get_tree().process_frame
	root.queue_free()
	await get_tree().process_frame
