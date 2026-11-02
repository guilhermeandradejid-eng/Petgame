class_name Shots
## Física dos golpes: bola com efeito (força de Magnus), arrasto do ar e
## super golpes. A mira é feita por simulação (tiro de correção): a bola
## curva de verdade, mas cai perto do alvo escolhido.

enum { DRIVE, LOB, DROP, SMASH, DEFENSE, SPECIAL }

const G := 9.0
const DRAG := 0.009          # a = -DRAG * |v| * v
const MAGNUS := 0.0042       # a = MAGNUS * (w x v)
const SPIN_DECAY := 0.25
const DT := 1.0 / 60.0
const RADIUS := 0.11
const NAMES := ["FORTE", "LOB", "CURTA", "SMASH", "DEFESA", "SUPER"]
const COLORS := [Color("ff7a2e"), Color("b06bff"), Color("4fc3ff"), Color("ff3b5c"), Color("ffffff"), Color("ffe14d")]

## Super golpes de cada personagem
const SPECIALS := {
	"tsunami": {"name": "TSUNAMI!", "color": Color("3fd0ff")},
	"raio": {"name": "RAIO!", "color": Color("fff04d")},
	"meteoro": {"name": "METEORO!", "color": Color("ff5a1f")},
	"bumerangue": {"name": "BUMERANGUE!", "color": Color("ff5fd2")},
}


## Um passo de integração, usado igualzinho pela bola e pela previsão.
static func integrate(pos: Vector3, vel: Vector3, w: Vector3, t: float, special: String) -> Array:
	var sp := vel.length()
	var acc := Vector3(0.0, -G, 0.0) - vel * (DRAG * sp) + w.cross(vel) * MAGNUS
	vel += acc * DT
	var np := pos + vel * DT
	if special == "raio":
		# zigue-zague: deslocamento lateral periódico (média zero)
		var k := TAU / 0.3
		np.x += 0.55 * (sin(k * (t + DT)) - sin(k * t))
	w *= exp(-SPIN_DECAY * DT)
	return [np, vel, w]


## Simula até a bola tocar a areia. Retorna {points, land, t, net_h}
static func simulate(from: Vector3, v: Vector3, w: Vector3, special: String, max_t := 6.0) -> Dictionary:
	var pts := PackedVector3Array()
	var p := from
	var t := 0.0
	var net_h := INF
	var steps := int(max_t / DT)
	for i in steps:
		var r := integrate(p, v, w, t, special)
		var np: Vector3 = r[0]
		v = r[1]
		w = r[2]
		if net_h == INF and signf(p.z) != signf(np.z) and p.z != 0.0:
			var f := p.z / (p.z - np.z)
			net_h = lerpf(p.y, np.y, f)
		p = np
		t += DT
		pts.append(p)
		if p.y <= RADIUS:
			break
	return {"points": pts, "land": p, "t": t, "net_h": net_h}


static func solve_time(from: Vector3, to: Vector3, t: float) -> Vector3:
	t = maxf(t, 0.05)
	var v := (to - from) / t
	v.y = (to.y - from.y + 0.5 * G * t * t) / t
	return v


static func solve_apex(from: Vector3, to: Vector3, apex: float) -> Vector3:
	apex = maxf(apex, maxf(from.y, to.y) + 0.05)
	var vy := sqrt(2.0 * G * (apex - from.y))
	var t := vy / G + sqrt(2.0 * (apex - to.y) / G)
	var v := (to - from) / t
	v.y = vy
	return v


static func _base(from: Vector3, a: Vector3, style: Dictionary) -> Vector3:
	if style.has("apex"):
		return solve_apex(from, a, float(style["apex"]))
	var dist := Vector2(a.x - from.x, a.z - from.z).length()
	return solve_time(from, a, dist / float(style["speed"]))


## Velocidade inicial para a bola (com efeito) cair em `target` passando a rede.
static func aim(from: Vector3, target: Vector3, style: Dictionary, top: float, sidespin: float,
		special: String, net_margin: float) -> Dictionary:
	var need := GameData.NET_H + maxf(net_margin, -0.3)
	var st := style.duplicate()
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var sim := {}
	for bump in 16:
		if bump == 10 and not st.has("apex"):
			# não deu chapado: vira uma bola em arco por cima da rede
			st = {"apex": maxf(need + 0.9, from.y + 0.6)}
			top *= 0.3
		var a := target
		for i in 4:
			v = _base(from, a, st)
			w = spin_vec(v, top, sidespin)
			sim = simulate(from, v, w, special)
			var land: Vector3 = sim["land"]
			var err := Vector3(target.x - land.x, 0.0, target.z - land.z)
			if err.length() < 0.08:
				break
			a += err
		if float(sim["net_h"]) >= need:
			break
		if st.has("apex"):
			st["apex"] = float(st["apex"]) + 0.35
		else:
			st["speed"] = float(st["speed"]) * 0.9
			top *= 0.85
	return {"velocity": v, "spin": w, "sim": sim}


## Vetor de efeito: top > 0 = topspin (bola mergulha), < 0 = slice (flutua);
## sidespin faz a bola fazer curva para o lado.
static func spin_vec(v: Vector3, top: float, sidespin: float) -> Vector3:
	var d := Vector3(v.x, 0.0, v.z)
	if d.length() < 0.01:
		return Vector3.ZERO
	d = d.normalized()
	return Vector3.UP.cross(d) * top + Vector3.UP * sidespin


## Calcula um golpe.
## side: -1 se o alvo está em z < 0. aim_in: x lateral (-1..1), y profundidade (-1..1).
## extra: {charge, chance, special}
static func compute(type: int, from: Vector3, side: float, aim_in: Vector2, quality: float,
		power: float, control: float, err_scale: float, rng: RandomNumberGenerator,
		extra: Dictionary = {}) -> Dictionary:
	var charge: float = extra.get("charge", 0.0)
	var chance: bool = extra.get("chance", false)
	var special: String = extra.get("special", "")
	var boost := 1.0 + charge * 0.18 + (0.15 if chance else 0.0)
	var spin_boost := 1.0 + charge * 0.5 + (0.4 if chance else 0.0)
	if chance:
		quality = maxf(quality, 0.95)
	var target := Vector3(clampf(aim_in.x, -1.0, 1.0) * 3.4, 0.0, 0.0)
	var depth := clampf(aim_in.y, -1.0, 1.0)
	var net_err := maxf(0.0, 0.85 - quality) * 0.45 * err_scale + rng.randf() * 0.1 * err_scale
	var label: String = NAMES[type]
	var style := {}
	var top := 0.0
	var sidespin := 0.0
	var margin := 0.25
	var err := 0.8
	var sp_id := ""
	# efeito lateral: a bola sai "por fora" e curva de volta para o alvo
	var dx := target.x - from.x
	var curve := signf(dx) if absf(dx) > 0.6 else (1.0 if rng.randf() < 0.5 else -1.0)
	curve *= side   # o eixo lateral do efeito depende do sentido da bola
	match type:
		DRIVE:
			target.z = side * (5.2 + depth * 1.6)
			var dspeed := (14.0 + quality * 3.5) * power * boost
			top = 55.0 * spin_boost
			margin = 0.3 - net_err
			if absf(from.z) < 3.2 and from.y > GameData.NET_H + 0.1:
				# voleio na rede: bola de cima, mais rápida e com ângulo aberto
				label = "VOLEIO!"
				dspeed *= 1.12
				target.z = side * (3.6 + depth * 1.8)
				target.x = clampf(aim_in.x, -1.0, 1.0) * 3.8
			elif from.y < 0.7:
				# bola baixa: tem que subir para passar a rede, sai mais fraca
				dspeed *= 0.85
				top *= 1.3
				margin += 0.15
			style = {"speed": dspeed}
			sidespin = 14.0 * curve * spin_boost
			err = 0.85
		LOB:
			target.z = side * (6.6 + depth * 0.9)
			style = {"apex": 6.2 + quality * 0.8}
			top = 35.0 * spin_boost
			margin = 0.4
			err = 0.95
		DROP:
			target.z = side * (1.5 + depth * 0.6)
			target.x *= 0.9
			style = {"apex": maxf(from.y + 0.35, 2.25)}
			top = -45.0 * spin_boost
			sidespin = 22.0 * curve * spin_boost
			margin = 0.24 - net_err
			err = 0.6
		SMASH:
			target.z = side * (4.2 + depth * 2.2)
			var speed := (21.0 + quality * 6.0) * power * boost
			if from.y < 0.7:
				speed *= 0.6
				top = 30.0
				margin += 0.15
				label = "PANCADA"
			elif from.y < 1.9:
				speed *= 0.72
				label = "PANCADA"
			style = {"speed": speed}
			top = 20.0
			margin = 0.26 - net_err
			err = 1.0
		DEFENSE:
			# defesa: bola alta, funda e segura no meio da quadra
			target.z = side * (5.8 + depth * 0.6 + rng.randf_range(-0.6, 0.6))
			target.x = clampf(target.x * 0.6 + rng.randf_range(-1.0, 1.0), -2.6, 2.6)
			style = {"apex": 4.8 + quality * 1.3}
			top = -18.0
			margin = 0.5
			err = 0.9
		SPECIAL:
			sp_id = special
			label = SPECIALS.get(special, {"name": "SUPER!"})["name"]
			quality = 1.0
			match special:
				"tsunami":
					target.z = side * 6.0
					style = {"speed": 23.0}
					top = 150.0
				"raio":
					target.z = side * 6.4
					style = {"speed": 26.0}
					top = 10.0
				"meteoro":
					target.z = side * 4.4
					style = {"speed": 30.0 if from.y > 1.9 else 22.0}
					top = 60.0
				"bumerangue":
					target.z = side * 5.4
					target.x = clampf(target.x, -2.6, 2.6)
					style = {"speed": 17.0}
					sidespin = 110.0 * curve
					top = 20.0
				_:
					target.z = side * 5.5
					style = {"speed": 22.0}
			margin = 0.3
			err = 0.15
	target = _apply_error(target, err, quality, control, err_scale, rng)
	var res := aim(from, target, style, top, sidespin, sp_id, margin)
	res["target"] = target
	res["label"] = label
	res["special"] = sp_id
	return res


static func _apply_error(target: Vector3, base: float, quality: float, control: float,
		err_scale: float, rng: RandomNumberGenerator) -> Vector3:
	var radius := base * pow(1.4 - quality, 1.5) * 1.35 * err_scale / maxf(control, 0.5)
	var a := rng.randf() * TAU
	var r := radius * sqrt(rng.randf())
	if rng.randf() < 0.07 * err_scale:
		r *= 2.4
	return target + Vector3(cos(a) * r, 0.0, sin(a) * r * 1.2)
