class_name World
extends Node3D
## The playable level: builds the stage, lighting, camera and HUD; the host spawns players and
## enemies and replicates them to clients with plain RPCs (identical node paths on every peer).

var actors: Node3D
var fx: Node3D
var cam: CameraRig
var info: Dictionary = {}
var _enemy_counter := 0
var battle: BattleManager
var battle_ui: Node


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
	fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # tweened/free-moving effects
	add_child(fx)
	Juice.fx_root = fx
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	add_child(preload("res://ui/postfx.gd").new())
	add_child(preload("res://ui/hud.gd").new())
	battle_ui = preload("res://ui/battle_ui.gd").new()
	add_child(battle_ui)
	if Game.touch_mode:
		add_child(preload("res://ui/touch_controls.gd").new())
	multiplayer.peer_disconnected.connect(_on_peer_left)
	Net.host_lost.connect(func(): get_tree().change_scene_to_file("res://ui/title.tscn"))
	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id(), info["player_spawn"], true)
		_spawn_enemy("dummy", info["dummy"])
	else:
		rpc_id(1, "rpc_client_ready")
	battle = BattleManager.new()
	battle.name = "BattleManager"      # fixed name: RPC paths must match on every peer
	add_child(battle)
	battle.setup(self, info["encounters"] if multiplayer.is_server() else [])
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
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.92)
	env.fog_density = 0.0035
	env.glow_enabled = true
	env.glow_intensity = 0.38
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
	sun.light_energy = 0.92
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
	Game.log_event("peer_left", {"peer": id})
	var n := actors.get_node_or_null("P_%d_0" % id)
	if n != null:
		n.queue_free()


# ------------------------------------------------------- spells & specials

func player_of(peer: int) -> Player:
	return actors.get_node_or_null("P_%d_0" % peer) as Player


func spawn_fx(kind: String, data_id: String, pos: Vector3, dir: Vector3, peer: int, target: Vector3) -> void:
	rpc("rpc_spawn_fx", kind, data_id, pos, dir, peer, target)


@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_fx(kind: String, data_id: String, pos: Vector3, dir: Vector3, peer: int, target: Vector3) -> void:
	match kind:
		"lance":
			var s := IceLance.new()
			s.spell = Registry.spell(data_id)
			s.dir = dir
			s.owner_peer = peer
			fx.add_child(s)
			s.global_position = pos
		"ring":
			var r := RingOfFire.new()
			r.spell = Registry.spell(data_id)
			r.owner_peer = peer
			fx.add_child(r)
			r.global_position = pos
		"comet":
			var c := Comet.new()
			c.spell = Registry.spell(data_id)
			c.owner_peer = peer
			c.target = target
			fx.add_child(c)
		"javelin":
			var j := Javelin.new()
			j.special = _special_by_id(data_id)
			j.dir = dir
			j.owner_peer = peer
			fx.add_child(j)
			j.global_position = pos
		"fissure":
			var f := Fissure.new()
			f.special = _special_by_id(data_id)
			f.dir = dir
			f.owner_peer = peer
			fx.add_child(f)
			f.global_position = Vector3(pos.x, 0, pos.z)


func _special_by_id(id: String) -> SpecialData:
	for w in Registry.weapons.values():
		for sp in w.specials:
			if sp.id == id:
				return sp
	return null
