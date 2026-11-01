class_name World
extends Node3D
## The playable level: builds the stage, lighting, camera and HUD; the host spawns players and
## enemies and replicates them to clients with plain RPCs (identical node paths on every peer).

var actors: Node3D
var fx: Node3D
var cam: CameraRig
var info: Dictionary = {}
var _enemy_counter := 0
var _respawn_cd := 0
var _spawn_i := 0


func _ready() -> void:
	name = "World"
	Game.world = self
	_environment()
	info = StageBuilder.new().build(self, 1337)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	fx = Node3D.new()
	fx.name = "FX"
	add_child(fx)
	Juice.fx_root = fx
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	add_child(preload("res://ui/postfx.gd").new())
	add_child(preload("res://ui/hud.gd").new())
	if Game.touch_mode:
		add_child(preload("res://ui/touch_controls.gd").new())
	multiplayer.peer_disconnected.connect(_on_peer_left)
	Net.host_lost.connect(func(): get_tree().change_scene_to_file("res://ui/title.tscn"))
	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id(), info["player_spawn"], true)
		_spawn_enemy("dummy", info["dummy"])
		for i in 3:
			_spawn_enemy("capmook", info["enemy_spawns"][i])
		_spawn_i = 3
	else:
		rpc_id(1, "rpc_client_ready")
	if Game.args.has("autotest") and ResourceLoader.exists("res://tests/autotest.gd"):
		var at: Node = load("res://tests/autotest.gd").new()   # not preloaded: tests/ is excluded from exports
		at.name = "AutoTest"
		add_child(at)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.8)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.92)
	env.fog_density = 0.0035
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 28.0 if Game.low_quality else 45.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.0
	add_child(sun)


# ------------------------------------------------------------ spawning

func _spawn_player(peer: int, pos: Vector3, local: bool) -> Player:
	var p := Player.new()
	p.peer_id = peer
	p.position = pos
	if local:
		p.source = InputSource.Local.new()
	actors.add_child(p)
	return p


func _spawn_enemy(kind: String, pos: Vector3) -> Enemy:
	_enemy_counter += 1
	var nm := "E_%d" % _enemy_counter
	var e := _make_enemy(nm, kind, pos)
	for pid in multiplayer.get_peers():
		rpc_id(pid, "rpc_spawn_enemy", nm, kind, pos)
	return e


func _make_enemy(nm: String, kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.name = nm
	e.data = Registry.enemy(kind)
	e.position = pos
	actors.add_child(e)
	return e


@rpc("any_peer", "call_remote", "reliable")
func rpc_client_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	# tell the newcomer about everyone already here
	for p in get_tree().get_nodes_in_group("players"):
		rpc_id(id, "rpc_spawn_player", p.peer_id, p.global_position)
	for e in get_tree().get_nodes_in_group("enemies"):
		rpc_id(id, "rpc_spawn_enemy", e.name, e.data.id, e.global_position)
	var pos: Vector3 = info["player_spawn"] + Vector3(2.0 * (multiplayer.get_peers().size()), 0, 0)
	_spawn_player(id, pos, false)
	for pid in multiplayer.get_peers():
		rpc_id(pid, "rpc_spawn_player", id, pos)
	Game.log_event("peer_joined", {"peer": id})


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_player(peer: int, pos: Vector3) -> void:
	if actors.has_node("P_%d_0" % peer):
		return
	_spawn_player(peer, pos, peer == multiplayer.get_unique_id())


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_enemy(nm: String, kind: String, pos: Vector3) -> void:
	if actors.has_node(nm):
		return
	_make_enemy(nm, kind, pos)


func _on_peer_left(id: int) -> void:
	var n := actors.get_node_or_null("P_%d_0" % id)
	if n != null:
		n.queue_free()


# ------------------------------------------------------------- spells

func spawn_spell(spell_id: String, pos: Vector3, dir: Vector3, peer: int) -> void:
	rpc("rpc_spawn_spell", spell_id, pos, dir, peer)


@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_spell(spell_id: String, pos: Vector3, dir: Vector3, peer: int) -> void:
	var s := IceLance.new()
	s.spell = Registry.spell(spell_id)
	s.dir = dir
	s.owner_peer = peer
	fx.add_child(s)
	s.global_position = pos


# ----------------------------------------------------- enemy director

func _physics_process(_d: float) -> void:
	if not multiplayer.is_server():
		return
	_respawn_cd -= 1
	if _respawn_cd > 0:
		return
	_respawn_cd = 180
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.data.dummy and not e.is_dead():
			alive += 1
	if alive < 3 and get_tree().get_nodes_in_group("players").size() > 0:
		var spots: Array = info["enemy_spawns"]
		_spawn_i = (_spawn_i + 1) % spots.size()
		_spawn_enemy("capmook", spots[_spawn_i])
