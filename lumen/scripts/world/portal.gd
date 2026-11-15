class_name Portal
extends Node3D
## Porta para a proxima sala. Entrar no circulo vota; quando o grupo decide, o host avanca.

var idx := 0
var option: Dictionary = {}
var label: Label3D
var votes_label: Label3D
var inside := false

func _ready() -> void:
	var type := str(option.get("type", "combat"))
	var reward := str(option.get("reward", ""))
	var col := Color({"combat": "7df9ff", "elite": "ff7a5a", "shop": "ffd36b", "rest": "8dffb0", "boss": "ff5ad2", "treasure": "ffd36b"}.get(type, "7df9ff"))
	var arch := KitLib.make("props", "portal_arch")
	if arch == null:
		for sx in [-1.2, 1.2]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 3.2, 0.5)
			mi.mesh = bm
			mi.position = Vector3(sx, 1.6, 0)
			mi.material_override = Mats.toon(Color("8e8fb0"))
			add_child(mi)
	else:
		add_child(arch)
	var s := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.2, 2.8)
	s.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/portal.gdshader")
	sm.set_shader_parameter("color_a", col)
	sm.set_shader_parameter("color_b", col.darkened(0.45))
	s.material_override = sm
	s.position.y = 1.45
	add_child(s)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.2
	l.omni_range = 7.0
	l.position = Vector3(0, 1.6, 1.0)
	add_child(l)
	Fx.rune_circle(self, 1.9, Color(col, 0.8)).position = Vector3(0, 0.06, 1.6)
	var rnames := {"boon": "Bênção", "relic": "Relíquia", "spell": "Magia", "gold": "Ouro", "shop": "Loja", "rest": "Cura", "boss": "Chefe"}
	var title := str(DB.ROOM_NAMES.get(type, type))
	if rnames.has(reward) and type in ["combat", "elite", "treasure"]:
		title += "  ·  " + str(rnames[reward])
	label = _mk_label(title, col.lightened(0.5), 3.75, 60)
	votes_label = _mk_label("", Color.WHITE, 3.25, 44)
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("portal", global_position, 0.7)

func _mk_label(t: String, col: Color, y: float, size: int) -> Label3D:
	var lb := Label3D.new()
	lb.text = t
	lb.font = Ui.font_bold()
	lb.font_size = size
	lb.pixel_size = 0.006
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = col
	lb.outline_size = 14
	lb.outline_modulate = Color("1b1730")
	lb.position.y = y
	add_child(lb)
	return lb

func center() -> Vector3:
	return global_transform * Vector3(0, 0, 1.6)

func _process(_delta: float) -> void:
	var me: Player = Game.me()
	if me == null:
		return
	var d := me.global_position - center()
	d.y = 0.0
	var now_in := d.length() < 1.9 and me.alive()
	if now_in != inside:
		inside = now_in
		Game.world.vote_portal(idx if inside else -1)

func set_votes(v: Dictionary, t: float) -> void:
	var n := 0
	for id in v:
		if int(v[id]) == idx:
			n += 1
	var txt := ""
	if n > 0:
		txt = "%d/%d" % [n, Game.player_count()]
		if t >= 0.0:
			txt += "  (%d s)" % int(ceil(t))
	votes_label.text = txt
