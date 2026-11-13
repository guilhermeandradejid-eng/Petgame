class_name Cards
extends RefCounted
## Banco de cartas. "spell" = cartão de feitiço (super com declaração), "system" = efeito imediato.

const DB := {
	"lumia_s1": {"kind": "spell", "cost": 2, "char": "lumia", "sign": "Sinal Vagalume",
				 "name": "Mil Vagalumes", "icon": "fireflies", "color": Color("ffd25a"),
				 "desc": "Uma espiral de vagalumes que perseguem o alvo."},
	"lumia_s2": {"kind": "spell", "cost": 3, "char": "lumia", "sign": "Carta Celeste",
				 "name": "Constelação Cartográfica", "icon": "constellation", "color": Color("8fd8ff"),
				 "desc": "Estrelas cercam o alvo e se ligam em feixes de luz."},
	"lumia_s3": {"kind": "spell", "cost": 4, "char": "lumia", "sign": "Crepúsculo",
				 "name": "Cortina de Aurora", "icon": "aurora", "color": Color("7affc8"),
				 "desc": "Uma aurora gigante varre a tela inteira."},
	"rubi_s1": {"kind": "spell", "cost": 2, "char": "rubi", "sign": "Punho Trovão",
				"name": "Martelo de Mil Volts", "icon": "fist", "color": Color("5fd8ff"),
				"desc": "Investida invencível que termina com um raio."},
	"rubi_s2": {"kind": "spell", "cost": 3, "char": "rubi", "sign": "Vendaval",
				"name": "Mil Golpes da Tormenta", "icon": "flurry", "color": Color("ff7a4a"),
				"desc": "Se acertar, uma rajada de socos e um gancho trovejante."},
	"rubi_s3": {"kind": "spell", "cost": 4, "char": "rubi", "sign": "Céu Partido",
				"name": "Julgamento do Trovão", "icon": "thunder", "color": Color("b8f4ff"),
				"desc": "Raios caem em sequência até o alvo."},
	"elixir": {"kind": "system", "cost": 1, "char": "", "sign": "Sistema", "name": "Elixir de Orvalho",
			   "icon": "elixir", "color": Color("9cffb0"), "desc": "Recupera um pouco de vida."},
	"vento": {"kind": "system", "cost": 1, "char": "", "sign": "Sistema", "name": "Vento Favorável",
			  "icon": "wind", "color": Color("c8f0ff"), "desc": "Espírito cheio e mais velocidade por 10 s."},
}


static func get_card(id: String) -> Dictionary:
	return DB.get(id, DB["elixir"])


static func full_name(id: String) -> String:
	var c := get_card(id)
	return "%s 「%s」" % [c["sign"], c["name"]]


static func apply_system(f: Fighter, id: String) -> void:
	match id:
		"elixir":
			f.heal_left += 900.0
			f.battle.fx.burst(f.center(), Color("9cffb0"), 26, 3.0)
			f.battle.fx.text(f.center() + Vector2(0, -56), "Elixir!", Color("9cffb0"), 0.9)
			Audio.play("heal", -2.0)
		"vento":
			f.spirit = Fighter.SPIRIT_MAX
			f.crushed = 0
			f.buffs["vento"] = 600
			f.battle.fx.burst(f.center(), Color("c8f0ff"), 30, 3.5)
			f.battle.fx.ring(f.center(), Color("c8f0ff"), 50.0, 20)
			f.battle.fx.text(f.center() + Vector2(0, -56), "Vento Favorável!", Color("c8f0ff"), 0.9)
			Audio.play("spirit_refill", -2.0)
