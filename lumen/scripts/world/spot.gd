class_name Spot
extends Node3D
## Ponto de interacao (tecla E): recompensa, mercador, fonte, bau e os servicos da vila.

const TITLES := {"reward": "", "shop": "Mercador", "fountain": "Fonte de Lúmen", "chest": "Tesouro",
	"wardrobe": "Guarda-roupa", "altar": "Altar de Lúmen", "classes": "Mestre de Armas", "start": "Portal das Ruínas"}
const PROMPTS := {"reward": "Escolher recompensa", "shop": "Ver mercadorias", "fountain": "Beber da fonte", "chest": "Abrir o baú",
	"wardrobe": "Trocar de roupa", "altar": "Melhorias permanentes", "classes": "Trocar de classe", "start": "Iniciar expedição"}
const COLORS := {"reward": "ffd36b", "shop": "ffb14a", "fountain": "7df9ff", "chest": "ffd36b", "wardrobe": "ff9ad5",
	"altar": "7df9ff", "classes": "ef6a5b", "start": "b48cff"}

var kind := "reward"
var reward_kind := "boon"
var interact_radius := 2.7
var used := false
var data: Dictionary = {}
var visual: Node3D
var lid: Node3D
var icon_node: Node3D

func _ready() -> void:
	var col := Color(str(COLORS.get(kind, "ffffff")))
	visual = Node3D.new()
	add_child(visual)
	match kind:
		"reward":
			_prop("reward_pedestal", Vector3(0.9, 0.9, 0.9), col, 0.5)
			var piece: String = {"boon": "relic_orb", "relic": "relic_orb", "spell": "tome", "gold": "coin"}.get(reward_kind, "relic_orb")
			icon_node = KitLib.make("props", piece)
			if icon_node == null:
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.24
				sm.height = 0.48
				mi.mesh = sm
				mi.material_override = Fx.glow_mat(col, 2.0, 1.0)
				icon_node = mi
			icon_node.position.y = 1.55
			icon_node.scale = Vector3.ONE * 1.5
			add_child(icon_node)
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 2.0
			l.omni_range = 6.0
			l.position.y = 1.6
			add_child(l)
			Fx.burst(global_position + Vector3(0, 1.2, 0), col, 2.0)
		"shop":
			_prop("shop_stall", Vector3(2.4, 2.2, 1.4), col, 1.3)
			interact_radius = 3.4
		"fountain":
			_fountain(col)
		"chest":
			_prop("chest_rare_base", Vector3(1.0, 0.7, 0.7), col, 0.6)
			lid = KitLib.make("props", "chest_rare_lid")
			if lid:
				var base_h := float(KitLib.meta("props", "chest_rare_base").get("size", [1, 1, 0.5])[2])
				lid.position = Vector3(0, base_h, 0.0)
				visual.add_child(lid)
		"wardrobe":
			_prop("wardrobe", Vector3(1.6, 2.0, 0.8), col, 0.9)
			interact_radius = 3.0
		"altar":
			_prop("altar", Vector3(1.4, 1.4, 1.0), col, 0.9)
			interact_radius = 3.0
		"classes":
			_prop("signpost", Vector3(0.5, 1.8, 0.5), col, 0.4)
			interact_radius = 3.0
		"start":
			interact_radius = 3.4
			_prop("portal_arch", Vector3(2.6, 3.2, 0.7), col, 0.0)
			var s := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(2.3, 2.9)
			s.mesh = qm
			var sm2 := ShaderMaterial.new()
			sm2.shader = load("res://shaders/portal.gdshader")
			s.material_override = sm2
			s.position.y = 1.5
			add_child(s)
			var l2 := OmniLight3D.new()
			l2.light_color = col
			l2.light_energy = 2.5
			l2.omni_range = 8.0
			l2.position = Vector3(0, 1.6, 1.0)
			add_child(l2)
	Fx.rune_circle(self, interact_radius * 0.62, Color(col, 0.7))
	var title := str(TITLES.get(kind, ""))
	if title != "":
		var lb := Label3D.new()
		lb.text = title
		lb.font = Ui.font_bold()
		lb.font_size = 56
		lb.pixel_size = 0.006
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = col.lightened(0.5)
		lb.outline_size = 14
		lb.outline_modulate = Color("1b1730")
		lb.visibility_range_begin = 4.0
		lb.position.y = 3.6 if kind == "start" else 2.7
		add_child(lb)
	Game.world.register_interactable(self)

func _prop(piece: String, fallback_size: Vector3, col: Color, collide_r: float) -> void:
	var m := KitLib.make("props", piece)
	if m == null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = fallback_size
		mi.mesh = bm
		mi.position.y = fallback_size.y * 0.5
		mi.material_override = Mats.toon(col.darkened(0.25))
		m = mi
	visual.add_child(m)
	if collide_r > 0.0:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := KitLib.collider("props", piece)
		if cs == null:
			cs = CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = collide_r
			cyl.height = 1.6
			cs.shape = cyl
			cs.position.y = 0.8
		body.add_child(cs)
		add_child(body)

func _fountain(col: Color) -> void:
	var stone := Mats.toon(Color("9a98bc"))
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.25
	cm.bottom_radius = 1.4
	cm.height = 0.5
	cm.radial_segments = 10
	base.mesh = cm
	base.position.y = 0.25
	base.material_override = stone
	visual.add_child(base)
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 1.08
	wm.bottom_radius = 1.08
	wm.height = 0.06
	wm.radial_segments = 10
	water.mesh = wm
	water.position.y = 0.5
	water.material_override = Fx.glow_mat(col, 1.4, 0.6)
	visual.add_child(water)
	var pillar := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.16
	pmesh.bottom_radius = 0.28
	pmesh.height = 1.3
	pmesh.radial_segments = 6
	pillar.mesh = pmesh
	pillar.position.y = 1.0
	pillar.material_override = stone
	visual.add_child(pillar)
	var orb := KitLib.make("props", "shard")
	if orb == null:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		mi.mesh = sm
		mi.material_override = Fx.glow_mat(col, 2.0, 1.0)
		orb = mi
	orb.position.y = 1.95
	orb.scale = Vector3.ONE * 1.6
	add_child(orb)
	icon_node = orb
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.2
	l.omni_range = 8.0
	l.position.y = 2.0
	add_child(l)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.35
	cyl.height = 1.0
	cs.shape = cyl
	cs.position.y = 0.5
	body.add_child(cs)
	add_child(body)
	interact_radius = 3.2

func _process(delta: float) -> void:
	if icon_node and is_instance_valid(icon_node):
		icon_node.rotate_y(delta * 1.4)
		icon_node.position.y += sin(Time.get_ticks_msec() * 0.003) * delta * 0.12

func can_interact() -> bool:
	return not used

func prompt() -> String:
	if kind == "reward":
		var names := {"boon": "Escolher uma bênção", "relic": "Escolher uma relíquia", "spell": "Escolher uma magia", "gold": "Pegar o ouro"}
		return str(names.get(reward_kind, "Escolher recompensa"))
	return str(PROMPTS.get(kind, "Interagir"))

func interact(p: Player) -> void:
	match kind:
		"reward":
			if reward_kind == "gold":
				Game.world.spawn_coins(global_position + Vector3(0, 1.2, 0), 45 + int(Game.room.get("depth", 0)) * 6)
				consume()
			else:
				Game.ui.open_reward(reward_kind, self)
		"shop":
			Game.ui.open_shop(self)
		"fountain":
			p.heal(p.max_hp * 0.6)
			p.flasks += 1
			Fx.heal_ring(global_position, 3.0, Color("7df9ff"))
			Sfx.play("heal", global_position)
			Game.toast.emit("Vida restaurada e +1 frasco de cura.", Color("7dff9a"))
			used = true
		"chest":
			used = true
			Sfx.play("chest", global_position)
			if lid:
				create_tween().tween_property(lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Fx.burst(global_position + Vector3(0, 0.8, 0), Color("ffd36b"), 2.5)
			Game.world.spawn_coins(global_position + Vector3(0, 0.8, 0), 35)
			Game.ui.open_reward("relic", null)
		"wardrobe":
			Game.ui.open_wardrobe()
		"altar":
			Game.ui.open_upgrades()
		"classes":
			Game.ui.open_classes()
		"start":
			if Net.is_host():
				Game.ui.open_start()
			else:
				Game.toast.emit("Aguarde: só o host abre o portal.", Color("ffd36b"))

func consume() -> void:
	used = true
	if icon_node:
		icon_node.queue_free()
		icon_node = null
	Fx.burst(global_position + Vector3(0, 1.3, 0), Color("ffd36b"), 1.6)
