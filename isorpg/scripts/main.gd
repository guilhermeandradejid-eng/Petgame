extends Node2D
## Test map, pathfinding, input and camera. Everything is built in code.

const MAP := [
	"######################",
	"#....................#",
	"#..S.S...............#",
	"#...##.........#..S..#",
	"#...##...........S...#",
	"#....S...............#",
	"#..........#.........#",
	"#..........##........#",
	"#....................#",
	"#..#.................#",
	"#..#........P....##..#",
	"#....................#",
	"#....................#",
	"#....................#",
	"#.......#.......S....#",
	"#................S.S.#",
	"#..S.S...............#",
	"######################",
]

var floor_cells: Array[Vector2i] = []
var solid := {}
var astar := AStarGrid2D.new()
var size := Vector2i.ZERO
var entities: Node2D
var floor_layer: Node2D
var fx_layer: Node2D
var hud: Control
var armed := -1
var player: Player
var enemies: Array = []
var cam: Camera2D
var light_texture: Texture2D
var holding := false
var hold_t := 0.0
var shake_amt := 0.0
## ?demo or #demo in the web URL (or --demo on the command line): the mage fights on its own, for testing.
var demo := false
## #slow runs the game at a quarter speed, for capturing effects frame by frame.
var time_base := 1.0
var demo_t := 0.0


func _ready() -> void:
	randomize()
	demo = "--demo" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var url := str(JavaScriptBridge.eval("location.search + location.hash"))
		demo = demo or url.contains("demo")
		if url.contains("slow"):
			time_base = 0.25
	Engine.time_scale = time_base
	light_texture = _make_light_texture()
	var cm := CanvasModulate.new()
	cm.color = Color(0.8, 0.8, 0.92)
	add_child(cm)

	floor_layer = preload("res://scripts/floor_layer.gd").new()
	floor_layer.world = self
	add_child(floor_layer)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	size = Vector2i(MAP[0].length(), MAP.size())
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var block_tex: Texture2D = preload("res://assets/gen/tiles/block.png")
	var player_cell := Vector2i(1, 1)
	var slime_cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var ch: String = MAP[y][x]
			var c := Vector2i(x, y)
			if ch == "#":
				solid[c] = true
				astar.set_point_solid(c, true)
				var b := Sprite2D.new()
				b.texture = block_tex
				b.centered = false
				b.offset = Vector2(-33, -49)
				b.position = Iso.to_screen(Vector2(c) + Vector2(0.5, 0.5))
				entities.add_child(b)
			else:
				floor_cells.append(c)
				if ch == "P":
					player_cell = c
				elif ch == "S":
					slime_cells.append(c)

	player = Player.new()
	player.world = self
	player.g = Vector2(player_cell) + Vector2(0.5, 0.5)
	player.spawn = player.g
	entities.add_child(player)
	for c in slime_cells:
		var s := Slime.new()
		s.world = self
		s.g = Vector2(c) + Vector2(0.5, 0.5)
		s.spawn = s.g
		entities.add_child(s)
		enemies.append(s)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	cam.position = player.position + Vector2(0, -24)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scripts/hud.gd").new()
	hud.world = self
	layer.add_child(hud)


func _make_light_texture() -> Texture2D:
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 192
	t.height = 192
	return t


# ---------------------------------------------------------------- map queries

func walkable(g: Vector2) -> bool:
	var c := Vector2i(floori(g.x), floori(g.y))
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return false
	return not solid.has(c)


func walkable_r(g: Vector2, r: float) -> bool:
	return walkable(g + Vector2(-r, -r)) and walkable(g + Vector2(r, -r)) \
		and walkable(g + Vector2(-r, r)) and walkable(g + Vector2(r, r))


func line_clear(a: Vector2, b: Vector2, r := 0.0) -> bool:
	var d := b - a
	var n := int(ceil(d.length() / 0.15))
	for i in range(1, n + 1):
		var p := a + d * (float(i) / n)
		if r > 0.0:
			if not walkable_r(p, r):
				return false
		elif not walkable(p):
			return false
	return true


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := Vector2i(floori(from.x), floori(from.y))
	var b := Vector2i(floori(to.x), floori(to.y))
	if not astar.region.has_point(b):
		return PackedVector2Array()
	var ids := astar.get_id_path(a, b, true)
	var pts: Array[Vector2] = []
	for i in range(1, ids.size()):
		pts.append(Vector2(ids[i]) + Vector2(0.5, 0.5))
	if walkable(to):
		if pts.is_empty():
			pts.append(to)
		else:
			pts[pts.size() - 1] = to
	# string pulling: skip waypoints we can walk to in a straight line
	var out := PackedVector2Array()
	var cur := from
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not line_clear(cur, pts[j], Player.RADIUS):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


# ---------------------------------------------------------------- input

func _enemy_at(screen: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 18.0
	for e in enemies:
		if not e.alive() or not e.visible:
			continue
		var d: float = (e.position + Vector2(0, -10)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = e
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for i in Spells.LIST.size():
			if event.keycode in Spells.LIST[i].keys:
				_cast(i, Iso.to_grid(get_global_mouse_position()))
				return
		if event.keycode == KEY_ESCAPE:
			armed = -1
	if event is InputEventMouseButton:
		var mp := get_global_mouse_position()
		var g := Iso.to_grid(mp)
		if event.button_index == MOUSE_BUTTON_LEFT:
			holding = event.pressed
			if not event.pressed:
				return
			var slot: int = hud.slot_at(event.position)
			if slot >= 0:
				holding = false
				_on_slot(slot)
				return
			var e := _enemy_at(mp)
			if armed >= 0:
				holding = false
				_cast(armed, e.g if e != null else g)
				armed = -1
			elif e != null:
				holding = false
				player.attack(e)
			elif walkable(g):
				floor_layer.show_marker(g)
				player.move_to(g)
				hold_t = 0.2
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var e := _enemy_at(mp)
			_cast(armed if armed >= 0 else 0, e.g if e != null else g)
			armed = -1


## Tapping a slot: spells that need a point are armed for the next tap, the rest go off now.
func _on_slot(i: int) -> void:
	if armed == i:
		armed = -1
	elif Spells.LIST[i].aim:
		armed = i
	else:
		_cast(i, player.g + Vector2(0.5, 0.5))


func _cast(i: int, g: Vector2) -> void:
	if not player.cast_spell(i, g):
		hud.deny(i)


func _process(delta: float) -> void:
	if holding:
		hold_t -= delta
		if hold_t <= 0.0:
			hold_t = 0.15
			var g := Iso.to_grid(get_global_mouse_position())
			if walkable(g) and g.distance_to(player.g) > 0.3:
				player.move_to(g)
	if demo:
		_demo_tick(delta)
	cam.position = player.position + Vector2(0, -24)
	shake_amt = move_toward(shake_amt, 0.0, 20.0 * delta)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt


func _demo_tick(delta: float) -> void:
	demo_t -= delta
	if demo_t > 0.0 or player.busy():
		return
	demo_t = 0.4
	var best: Node2D = null
	for e in enemies:
		if e.alive() and e.visible and (best == null or e.g.distance_to(player.g) < best.g.distance_to(player.g)):
			best = e
	if best == null:
		return
	var d: float = best.g.distance_to(player.g)
	var cd: Array[float] = player.cooldowns
	if d < 2.4 and cd[2] <= 0.0:
		player.cast_spell(2, best.g)
	elif d < 6.5 and cd[1] <= 0.0 and line_clear(player.g, best.g):
		player.cast_spell(1, best.g)
	elif d < 7.5 and cd[3] <= 0.0 and line_clear(player.g, best.g):
		player.cast_spell(3, best.g)
	elif player.target == null:
		player.attack(best)


# ---------------------------------------------------------------- effects

func spawn_bolt(_owner: Node2D, from_g: Vector2, tip_h: float, aim: Vector2, target: Node2D) -> void:
	var b := Bolt.new()
	b.world = self
	# start where the staff tip is drawn: lift the ground point by a fixed height
	var h: float = clamp(tip_h * 0.75, 20.0, 60.0)
	var tip_screen := player.position + player.spr.anchor("staff_tip")
	var ground := Iso.to_grid(tip_screen + Vector2(0, h))
	if not walkable(ground):
		ground = from_g
	b.launch(ground, h, aim, target)
	entities.add_child(b)


func spawn_comet(at: Vector2, marker: Node2D) -> void:
	var c := Comet.new()
	c.world = self
	c.g = at
	c.marker = marker
	add_child(c)


func spawn_fire_ring(at: Vector2) -> void:
	var f := FireRing.new()
	f.world = self
	f.center = at
	fx_layer.add_child(f)


func spawn_ice_lance(tip_screen: Vector2, aim: Vector2) -> void:
	var l := IceLance.new()
	l.world = self
	var ground := Iso.to_grid(tip_screen + Vector2(0, IceLance.HEIGHT))
	if not walkable(ground):
		ground = player.g
	l.g = ground
	var d := aim - player.g
	l.dir = d.normalized() if d.length() > 0.05 else Vector2(1, 1).normalized()
	entities.add_child(l)


func target_marker(at: Vector2, rune: String) -> Node2D:
	var m := FxAnim.spawn(fx_layer, Spells.rune_texture(rune), 8, Iso.to_screen(at), 12.0)
	m.loop = true
	m.life = 3.0
	m.scale = Vector2(1.4, 1.4)
	return m


func make_light(color: Color, energy: float, scale: float, height: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	l.height = height
	return l


func flash(at: Vector2, color: Color, energy: float, scale: float, life: float) -> void:
	var l := make_light(color, energy, scale, 30.0)
	l.position = at
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, life)
	tw.tween_callback(l.queue_free)


func hitstop(t: float) -> void:
	Engine.time_scale = 0.05 * time_base
	await get_tree().create_timer(t / time_base, true, false, true).timeout
	Engine.time_scale = time_base


func damage_number(at: Vector2, n: int, color: Color) -> void:
	var d := DamageNumber.new()
	d.text = str(n)
	d.color = color
	d.position = at
	add_child(d)


func burst(at: Vector2, color: Color, amount: int, speed := 80.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = color
	p.position = at
	p.z_index = 5
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func shake(amount: float) -> void:
	shake_amt = max(shake_amt, amount)
