class_name Shots
## Balística dos golpes. A bola não tem arrasto, então tudo é resolvido de forma
## exata: dado o ponto de contato, o alvo e um "estilo" (tempo de voo ou altura
## máxima), calculamos a velocidade inicial.

enum { DRIVE, LOB, DROP, SMASH, DEFENSE }

const G := 9.0
const NAMES := ["FORTE", "LOB", "CURTA", "SMASH", "DEFESA"]
const COLORS := [Color("ffd23f"), Color("4fc3ff"), Color("7dff6b"), Color("ff4b3e"), Color("ffffff")]


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


## Altura da bola quando ela cruza z = 0 (rede). Retorna INF se não cruza.
static func height_at_net(from: Vector3, v: Vector3) -> float:
	if absf(v.z) < 0.001 or signf(from.z) == signf(v.z):
		return INF
	var t := -from.z / v.z
	return from.y + v.y * t - 0.5 * G * t * t


static func flight_time(from: Vector3, v: Vector3, h: float = 0.1) -> float:
	var disc := v.y * v.y + 2.0 * G * (from.y - h)
	if disc < 0.0:
		return 0.0
	return (v.y + sqrt(disc)) / G


## Garante que o golpe passa por cima da rede com folga, "levantando" a
## trajetória aos poucos (fica mais lento, como na vida real).
static func clear_net(from: Vector3, to: Vector3, v: Vector3, margin: float) -> Vector3:
	var need := GameData.NET_H + margin
	var horiz := Vector2(to.x - from.x, to.z - from.z).length()
	var t := horiz / maxf(Vector2(v.x, v.z).length(), 0.1)
	for i in 30:
		if height_at_net(from, v) >= need:
			return v
		t *= 1.07
		v = solve_time(from, to, t)
	return v


## Calcula a velocidade de um golpe.
## side: -1 se o alvo está em z < 0 (time da câmera atacando), +1 caso contrário.
## aim: x = lateral (-1..1), y = profundidade (-1 curta .. 1 funda).
## quality: 0..1 (1 = perfeito). power: atributo do personagem.
static func compute(type: int, from: Vector3, side: float, aim: Vector2, quality: float,
		power: float, control: float, err_scale: float, rng: RandomNumberGenerator) -> Dictionary:
	var target := Vector3(clampf(aim.x, -1.0, 1.0) * 3.4, 0.0, 0.0)
	var depth := clampf(aim.y, -1.0, 1.0)
	var err := 0.0
	var v := Vector3.ZERO
	var label: String = NAMES[type]
	# golpe mal batido pode morrer na rede
	var net_err := maxf(0.0, 0.85 - quality) * 0.45 * err_scale + rng.randf() * 0.1 * err_scale
	match type:
		DRIVE:
			target.z = side * (5.2 + depth * 1.6)
			err = 0.85
			var speed := (14.0 + quality * 3.5) * power
			target = _apply_error(target, err, quality, control, err_scale, rng)
			var dist := Vector2(target.x - from.x, target.z - from.z).length()
			v = solve_time(from, target, dist / speed)
			v = clear_net(from, target, v, 0.3 - net_err)
		LOB:
			target.z = side * (6.6 + depth * 0.9)
			err = 0.95
			target = _apply_error(target, err, quality, control, err_scale, rng)
			v = solve_apex(from, target, 6.2 + quality * 0.8)
		DROP:
			target.z = side * (1.5 + depth * 0.6)
			target.x *= 0.9
			err = 0.6
			target = _apply_error(target, err, quality, control, err_scale, rng)
			v = solve_apex(from, target, maxf(from.y + 0.35, 2.25))
			v = clear_net(from, target, v, 0.24 - net_err)
		SMASH:
			target.z = side * (4.2 + depth * 2.2)
			err = 1.0
			target = _apply_error(target, err, quality, control, err_scale, rng)
			var speed := (21.0 + quality * 6.0) * power
			if from.y < 1.9:
				speed *= 0.72
				label = "PANCADA"
			var dist := Vector2(target.x - from.x, target.z - from.z).length()
			v = solve_time(from, target, dist / speed)
			v = clear_net(from, target, v, 0.26 - net_err)
		DEFENSE:
			target.z = side * (5.0 + rng.randf_range(-1.2, 1.2))
			target.x = rng.randf_range(-2.4, 2.4)
			target = _apply_error(target, 0.9, quality, control, err_scale, rng)
			v = solve_apex(from, target, 4.6 + quality * 1.2)
	return {"velocity": v, "target": target, "label": label}


static func _apply_error(target: Vector3, base: float, quality: float, control: float,
		err_scale: float, rng: RandomNumberGenerator) -> Vector3:
	var radius := base * pow(1.4 - quality, 1.5) * 1.35 * err_scale / maxf(control, 0.5)
	var a := rng.randf() * TAU
	var r := radius * sqrt(rng.randf())
	if rng.randf() < 0.07 * err_scale:
		r *= 2.4   # bola "espirrada"
	return target + Vector3(cos(a) * r, 0.0, sin(a) * r * 1.2)
