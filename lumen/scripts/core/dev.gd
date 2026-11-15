extends Node
## Ferramentas de desenvolvimento e teste automatico, ligadas por argumentos depois de "--":
##   --host [--port=N]      hospeda direto, sem menu      --join=IP   entra numa sala
##   --autostart=S          o host inicia a run apos S segundos
##   --bot                  o heroi joga sozinho (ataca, pega recompensas, entra nos portais)
##   --shot=arquivo.png@S   salva uma captura de tela aos S segundos (pode repetir com virgulas)
##   --quit=S               fecha apos S segundos         --lowgfx   desliga nevoa volumetrica
##   --room=tipo:bioma      comeca a run direto numa sala (ex.: boss:boss, combat:crystal)
##   --easy                 menos inimigos                 --god   heroi imortal
##   --cls=classe  --profile=nome  --look=aleatorio

var args: Dictionary = {}
var bot := false
var bot_move := Vector2.ZERO
var low_gfx := false
var t := 0.0
var _shots: Array = []
var _quit := -1.0
var _autostart := -1.0
var _bot_think := 0.0
var _bot_goal := Vector3.ZERO
var _bot_attack := false
var _bot_skill_t := 2.0
var _bot_pick_t := 0.0
var log_t := 0.0

func _enter_tree() -> void:
	Controls.setup()
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	bot = args.has("bot")
	low_gfx = args.has("lowgfx") or DisplayServer.get_name() == "headless"
	if args.has("shot"):
		for part in str(args["shot"]).split(","):
			var pv := part.split("@")
			_shots.append([pv[0], float(pv[1]) if pv.size() > 1 else 3.0])
	if args.has("quit"):
		_quit = float(args["quit"])
	if args.has("autostart"):
		_autostart = float(args["autostart"])

func _ready() -> void:
	if args.has("cls") and DB.CLASSES.has(str(args["cls"])):
		Save.data["cls"] = str(args["cls"])
	if args.get("look", "") == "aleatorio":
		randomize_look()
	if args.has("host") or args.has("server"):
		_boot_host.call_deferred()
	elif args.has("join"):
		_boot_join.call_deferred()

func _boot_host() -> void:
	Game.host_game(int(args.get("port", Net.DEFAULT_PORT)), not args.has("server"))

func _boot_join() -> void:
	var ip := str(args["join"]) if str(args["join"]) != "" else "127.0.0.1"
	Game.join_game(ip, int(args.get("port", Net.DEFAULT_PORT)))

func randomize_look() -> void:
	var l: Dictionary = Save.data["look"]
	for slot in ["hair", "hat", "ears", "acc", "top", "bottom", "back", "eyes"]:
		var ids: Array = DB.by_slot.get(slot, [])
		if ids.is_empty():
			continue
		if slot in ["hat", "ears", "acc", "back"] and randf() < 0.35:
			l[slot] = ""
		else:
			l[slot] = ids[randi() % ids.size()]
	l["skin"] = DB.SKIN_TONES[randi() % DB.SKIN_TONES.size()]
	l["hair_c"] = DB.HAIR_COLORS[randi() % DB.HAIR_COLORS.size()]
	l["primary"] = DB.CLOTH_COLORS[randi() % DB.CLOTH_COLORS.size()]
	l["secondary"] = DB.CLOTH_COLORS[randi() % DB.CLOTH_COLORS.size()]
	l["accent"] = DB.CLOTH_COLORS[randi() % DB.CLOTH_COLORS.size()]
	l["iris"] = DB.IRIS_COLORS[randi() % DB.IRIS_COLORS.size()]
	for id in DB.cosmetics:
		if not Save.data["unlocked"].has(id):
			Save.data["unlocked"].append(id)

func _process(delta: float) -> void:
	t += delta
	if _autostart >= 0.0 and t >= _autostart and Game.phase == Game.Phase.HUB and Net.is_host():
		_autostart = -1.0
		if args.has("room"):
			var rv := str(args["room"]).split(":")
			Game.start_run()
			var r := {"type": rv[0], "biome": rv[1] if rv.size() > 1 else "forest", "seed": randi(), "depth": int(args.get("depth", 3)), "reward": "boon"}
			if rv[0] == "boss":
				Game.run["step"] = Game.run["plan"].size() - 1
			Game._go_room(r)
		else:
			Game.start_run()
	for s in _shots:
		if s[1] >= 0.0 and t >= s[1]:
			s[1] = -1.0
			var img := get_viewport().get_texture().get_image()
			img.save_png(s[0])
			print("[dev] captura salva: ", s[0])
	if _quit >= 0.0 and t >= _quit:
		_quit = -1.0
		print("[dev] fim. fase=%d sala=%s jogadores=%d" % [Game.phase, str(Game.room.get("type", "-")), Game.players.size()])
		get_tree().quit()
	if args.has("log"):
		log_t -= delta
		if log_t <= 0.0:
			log_t = 2.0
			var me: Player = Game.me()
			print("[dev %.0fs] fase=%d passo=%s sala=%s inimigos=%d hp=%s ouro=%s" % [t, Game.phase, str(Game.run.get("step", "-")),
				str(Game.room.get("type", "-")), Game.world.enemy_count() if Game.world else 0, str(int(me.hp)) if me else "-", str(me.gold) if me else "-"])
	if bot:
		_bot_update(delta)
	if args.has("god"):
		var me2: Player = Game.me()
		if me2 and not me2.in_hub:
			me2.hp = me2.max_hp

# ------------------------------------------------------------------ bot
func _bot_update(delta: float) -> void:
	var me: Player = Game.me()
	bot_move = Vector2.ZERO
	_bot_attack = false
	if me == null or Game.world == null or Game.world.level == null or not me.alive():
		return
	if Game.ui and Game.ui.is_open():
		_bot_pick_t += delta
		if _bot_pick_t > 0.6:
			_bot_pick_t = 0.0
			Game.ui.bot_act()
		return
	var target := Vector3.ZERO
	var has_target := false
	var stop_at := 1.0
	var e: Enemy = Game.world.nearest_enemy(me.global_position, 60.0)
	if e and e.is_dummy and Game.phase != Game.Phase.HUB:
		e = null
	if e and not me.in_hub:
		target = e.global_position
		has_target = true
		stop_at = 1.6 if me.wt in ["sword", "hammer"] else 9.0
		var d := me.global_position.distance_to(target)
		_bot_attack = d < stop_at + 1.0
	else:
		var it: Node3D = null
		var bd := 1e9
		for n in Game.world.interactables:
			if is_instance_valid(n) and n is Spot and n.can_interact() and (n as Spot).kind in ["reward", "chest", "fountain"]:
				var dd: float = n.global_position.distance_to(me.global_position)
				if dd < bd:
					bd = dd
					it = n
		if it:
			target = it.global_position
			has_target = true
			stop_at = 1.8
			if bd < 2.2:
				it.call("interact", me)
		elif Game.world.level is Room and (Game.world.level as Room).portals.size() > 0:
			var po: Portal = (Game.world.level as Room).portals[0]
			target = po.center()
			has_target = true
			stop_at = 0.4
	if has_target:
		var to := target - me.global_position
		to.y = 0.0
		if to.length() > stop_at:
			var dir := to.normalized()
			bot_move = Vector2(dir.x, dir.z)
		elif e and me.wt in ["bow", "staff"] and to.length() < 5.0:
			var dir2 := -to.normalized()
			bot_move = Vector2(dir2.x, dir2.z)

func bot_aim(p: Player) -> Vector3:
	var e: Enemy = Game.world.nearest_enemy(p.global_position, 60.0)
	if e:
		var d := e.global_position - p.global_position
		d.y = 0.0
		if d.length() > 0.05:
			return d.normalized()
	return p.forward()

func bot_inputs(p: Player) -> void:
	if not _bot_attack:
		return
	_bot_skill_t -= get_physics_process_delta_time()
	if _bot_skill_t <= 0.0:
		_bot_skill_t = randf_range(1.0, 2.5)
		for s in ["ult", "q", "r", "secondary"]:
			if p._can_use(s):
				p.skills.use(s)
				return
		if randf() < 0.3:
			p.do_dodge()
			return
	if p._can_use("primary"):
		p.skills.use("primary")
