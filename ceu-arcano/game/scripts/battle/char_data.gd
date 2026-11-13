class_name CharData
extends RefCounted
## Atlas + animações geradas pelo pipeline Python (assets/characters/<id>/<id>.json).

static var _cache := {}

var id := ""
var tex_a: Texture2D
var tex_b: Texture2D
var portrait_a: Texture2D
var portrait_b: Texture2D
var anims := {}   # nome -> {loop, length, loop_start, hold_last, events, frames:[...], starts:[...]}


static func get_data(cid: String) -> CharData:
	if _cache.has(cid):
		return _cache[cid]
	var d := CharData.new()
	d._load(cid)
	_cache[cid] = d
	return d


func _load(cid: String) -> void:
	id = cid
	var base := "res://assets/characters/%s/" % cid
	tex_a = load(base + cid + "_a.png")
	tex_b = load(base + cid + "_b.png")
	portrait_a = load(base + "portrait_a.png")
	portrait_b = load(base + "portrait_b.png")
	var txt := FileAccess.get_file_as_string(base + cid + ".json")
	var j = JSON.parse_string(txt)
	if typeof(j) != TYPE_DICTIONARY:
		push_error("CharData: json inválido para " + cid)
		return
	for name in j["anims"]:
		var a: Dictionary = j["anims"][name]
		var starts := []
		var t := 0
		var frames: Array = a["frames"]
		for fr in frames:
			starts.append(t)
			t += int(fr["d"])
			fr["rect"] = Rect2(fr["r"][0], fr["r"][1], fr["r"][2], fr["r"][3])
			fr["origin"] = Vector2(fr["o"][0], fr["o"][1])
			var hurt := []
			for h in fr["hurt"]:
				hurt.append(Rect2(h[0], h[1], h[2], h[3]))
			fr["hurt_r"] = hurt
			var hit := []
			for h in fr["hit"]:
				hit.append(Rect2(h[0], h[1], h[2], h[3]))
			fr["hit_r"] = hit
			var pts := {}
			for k in fr["pts"]:
				pts[k] = Vector2(fr["pts"][k][0], fr["pts"][k][1])
			fr["pts_v"] = pts
		a["starts"] = starts
		a["total"] = t
		anims[name] = a


func frame_at(anim: String, t: int) -> int:
	## índice do quadro para o tempo t (frames de jogo desde o início da animação)
	var a: Dictionary = anims[anim]
	var total: int = a["total"]
	if t >= total:
		if a["loop"]:
			var ls: int = int(a.get("loop_start", 0))
			var span := maxi(1, total - ls)
			t = ls + (t - ls) % span
		else:
			return a["frames"].size() - 1
	var starts: Array = a["starts"]
	var lo := 0
	var hi := starts.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if starts[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


func has_anim(anim: String) -> bool:
	return anims.has(anim)


func length(anim: String) -> int:
	return int(anims[anim]["total"]) if anims.has(anim) else 1
