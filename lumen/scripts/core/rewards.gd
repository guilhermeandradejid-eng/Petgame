class_name Rewards
## Sorteio e aplicacao das recompensas de sala. Cada jogador sorteia as suas.

static func rarity_roll(rng: RandomNumberGenerator, luck: float, min_r: int = 0) -> int:
	var w := [60.0, 28.0 + luck * 6.0, 9.0 + luck * 4.0, 3.0 + luck * 1.5]
	var total := 0.0
	for i in range(min_r, 4):
		total += w[i]
	var x := rng.randf() * total
	for i in range(min_r, 4):
		x -= w[i]
		if x <= 0.0:
			return i
	return min_r

static func roll(kind: String, p: Player, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var out: Array = []
	var luck := float(p.stats.get("luck", 0.0))
	match kind:
		"boon":
			var pool: Array = []
			for id in DB.BOONS:
				if int(p.boons.get(id, 0)) < int(DB.BOONS[id]["max"]):
					pool.append(id)
			_shuffle(pool, rng)
			# bencaos raras aparecem menos
			for id in pool:
				if out.size() >= count:
					break
				if int(DB.BOONS[id].get("rarity", 0)) >= 1 and rng.randf() > 0.55 + luck * 0.1:
					continue
				out.append({"type": "boon", "id": id})
			for id in pool:
				if out.size() >= count:
					break
				if not out.any(func(c: Dictionary) -> bool: return c["id"] == id):
					out.append({"type": "boon", "id": id})
		"relic":
			var have: Array = p.relics
			var guard := 0
			while out.size() < count and guard < 80:
				guard += 1
				var r := rarity_roll(rng, luck, 0)
				var pool2: Array = []
				for id in DB.RELICS:
					if int(DB.RELICS[id]["rarity"]) == r and not have.has(id) and not out.any(func(c: Dictionary) -> bool: return c["id"] == id):
						pool2.append(id)
				if pool2.size() > 0:
					out.append({"type": "relic", "id": pool2[rng.randi() % pool2.size()]})
		"spell":
			var pool3: Array = []
			for id in DB.SKILLS:
				if DB.SKILLS[id].get("spell", false) and not p.slots.values().has(id):
					pool3.append(id)
			_shuffle(pool3, rng)
			for id in pool3:
				if out.size() < count:
					out.append({"type": "spell", "id": id})
	return out

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t

static func apply(c: Dictionary, p: Player, slot: String = "q") -> void:
	match str(c["type"]):
		"boon":
			p.add_boon(c["id"])
		"relic":
			p.add_relic(c["id"])
		"spell":
			p.set_spell(slot, c["id"])
		"heal":
			p.heal(p.max_hp * float(c.get("v", 0.35)))
		"flask":
			p.flasks += 1

static func title(c: Dictionary) -> String:
	return str(DB.item_def(str(c.get("id", ""))).get("name", c.get("name", "")))

static func desc(c: Dictionary, p: Player) -> String:
	var def := DB.item_def(str(c.get("id", "")))
	var d := str(def.get("desc", c.get("desc", "")))
	if c["type"] == "boon":
		var lvl := int(p.boons.get(c["id"], 0))
		d += "\nNível %d de %d" % [lvl + 1, int(def["max"])]
	if c["type"] == "spell":
		d += "\nRecarga: %s s" % str(def["cd"])
	return d

static func rarity(c: Dictionary) -> int:
	return int(DB.item_def(str(c.get("id", ""))).get("rarity", c.get("rarity", 0)))

static func icon(c: Dictionary) -> String:
	return str(DB.item_def(str(c.get("id", ""))).get("icon", c.get("icon", "star")))

static func shop_price(c: Dictionary) -> int:
	match str(c["type"]):
		"relic":
			return [70, 110, 160, 240][rarity(c)]
		"spell":
			return 80 + rarity(c) * 30
		"boon":
			return 55
		"heal":
			return 35
		"flask":
			return 45
	return 50
