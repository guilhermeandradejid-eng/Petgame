class_name Projectile
extends Node3D
## Projetil em linha reta. Os do jogador sao resolvidos por quem atirou (local = true);
## nos outros clientes e so visual. Os de inimigo ferem o heroi local de cada cliente.

var vel := Vector3.ZERO
var life := 2.4
var radius := 0.3
var local := false
var enemy_shot := false
var owner_p: Player
var d: Dictionary = {}
var color := Color.WHITE
var dmg := 0.0
var eid := -1
var hit_ids: Array = []
var pierce := 0
var done := false

func setup_player(p_d: Dictionary) -> void:
	d = p_d
	owner_p = d["owner"]
	local = bool(d["local"])
	position = d["pos"]
	vel = (d["dir"] as Vector3).normalized() * float(d["speed"])
	color = d.get("color", Color.WHITE)
	pierce = int(d.get("pierce", 0))
	radius = 0.45 if str(d["kind"]) in ["fireball", "arrow_big"] else 0.3

func setup_enemy(pos: Vector3, p_vel: Vector3, p_dmg: float, r: float, col: Color, p_eid: int) -> void:
	enemy_shot = true
	position = pos
	vel = p_vel
	dmg = p_dmg
	radius = r
	color = col
	eid = p_eid
	life = 4.0
	d = {"kind": "enemy_orb"}

func _ready() -> void:
	var kind := str(d.get("kind", "orb"))
	if vel.length() > 0.01:
		look_at(global_position + vel.normalized(), Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT)
	match kind:
		"arrow", "arrow_big", "thorn":
			var m := KitLib.make("props", "arrow")
			if m:
				m.rotation.y = 0.0
				m.scale = Vector3.ONE * (1.5 if kind == "arrow_big" else (0.7 if kind == "thorn" else 1.0))
				add_child(m)
			else:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.05, 0.05, 0.7 if kind != "thorn" else 0.4)
				mi.mesh = bm
				mi.material_override = Mats.toon(Color("f3ead6") if kind != "thorn" else Color("8fd16a"))
				add_child(mi)
			_streak(color if kind != "arrow" else Color("fff2c8"), 0.1 if kind == "arrow" else 0.2)
		"icicle":
			var mi2 := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.22, 0.9, 0.22)
			mi2.mesh = pm
			mi2.rotation.x = -PI * 0.5
			mi2.material_override = Fx.glow_mat(color, 1.4, 1.0)
			add_child(mi2)
			_streak(color, 0.22)
		_:
			var mi3 := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = radius
			sm.height = radius * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			mi3.mesh = sm
			mi3.material_override = Fx.glow_mat(color, 2.2, 1.0)
			add_child(mi3)
			_streak(color, radius * 0.9)
			if kind in ["fireball", "enemy_orb"]:
				var l := OmniLight3D.new()
				l.light_color = color
				l.light_energy = 1.8
				l.omni_range = 4.5
				add_child(l)

func _streak(col: Color, w: float) -> void:
	var cp := CPUParticles3D.new()
	cp.amount = 14
	cp.lifetime = 0.28
	cp.local_coords = false
	cp.gravity = Vector3.ZERO
	cp.initial_velocity_max = 0.3
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	cp.scale_amount_curve = c
	var qm := QuadMesh.new()
	qm.size = Vector2(w * 2.2, w * 2.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Fx.soft_dot()
	qm.material = m
	cp.mesh = qm
	add_child(cp)

func _physics_process(delta: float) -> void:
	if done:
		return
	var from := global_position
	var to := from + vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		_impact(hit["position"])
		return
	if to.y <= 0.08:
		_impact(Vector3(to.x, 0.05, to.z))
		return
	if enemy_shot:
		var me: Player = Game.me()
		if me and me.alive():
			var c := me.global_position + Vector3(0, 0.65, 0)
			if _seg_dist(from, to, c) < radius + 0.42:
				me.take_damage(dmg, from, 3.0, eid)
				_impact(c)
				return
	else:
		for e: Enemy in Game.world.enemy_list():
			if e.dead or hit_ids.has(e.eid):
				continue
			var ec := e.global_position
			var mid := (from + to) * 0.5
			if mid.y < ec.y - 0.3 or mid.y > ec.y + e.height + 0.6:
				continue
			var f2 := Vector3(from.x, 0, from.z)
			var t2 := Vector3(to.x, 0, to.z)
			if _seg_dist(f2, t2, Vector3(ec.x, 0, ec.z)) < e.radius + radius:
				hit_ids.append(e.eid)
				var splash := float(d.get("splash", 0.0))
				if local and is_instance_valid(owner_p) and splash <= 0.0:
					owner_p.skills.hit(e, float(d["mult"]), str(d["dkind"]), {"kb": float(d.get("kb", 1.5)), "status": str(d.get("status", "")), "from": from})
				if pierce > 0 and splash <= 0.0:
					pierce -= 1
					Fx.spark(Vector3(ec.x, mid.y, ec.z), color)
				else:
					_impact(Vector3(mid.x, maxf(mid.y, 0.3), mid.z))
					return
	global_position = to

func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.000001 else 0.0
	return (a + ab * t).distance_to(p)

func _impact(pos: Vector3) -> void:
	done = true
	var splash := float(d.get("splash", 0.0))
	if splash > 0.0:
		var g := Vector3(pos.x, 0.0, pos.z)
		Fx.explosion(g if pos.y < 1.2 else pos, splash, color)
		Sfx.play("explode", pos, 0.7)
		if local and is_instance_valid(owner_p):
			owner_p.skills.hit_circle(pos, splash, float(d["mult"]), str(d["dkind"]), {"kb": float(d.get("kb", 3.0)), "status": str(d.get("status", "")), "from": pos})
			Game.world.shake_near(pos, 0.3, 14.0)
	else:
		Fx.spark(pos, color)
		if enemy_shot:
			Sfx.play("hit", pos, 0.5)
	queue_free()
