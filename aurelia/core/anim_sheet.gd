class_name AnimSheet
extends RefCounted
## Runtime view of a generated sprite sheet + its frozen contract.
## Gameplay only ever reasons about *logical* frames (ticks from the contract);
## sub-frames are picked here purely for smoothness.

static var _cache: Dictionary = {}

var id: String
var cell: int = 64
var cols: int = 16
var rows: int = 1
var ground := Vector2i(32, 59)       # feet position inside a cell (px)
var tex: Texture2D
var ntex: Texture2D
var anims: Dictionary = {}


static func get_sheet(char_id: String) -> AnimSheet:
	if _cache.has(char_id):
		return _cache[char_id]
	var s := AnimSheet.new()
	s._load(char_id)
	_cache[char_id] = s
	return s


static func _tex(path: String) -> Texture2D:
	var t = load(path)
	if t is Texture2D:
		return t
	# Not imported yet (fresh clone / headless): read the PNG straight from disk.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("AnimSheet: cannot load " + path)
		return null
	return ImageTexture.create_from_image(img)


func _load(char_id: String) -> void:
	id = char_id
	var base := "res://art/chars/%s/" % char_id
	var f := FileAccess.open(base + "sheet.json", FileAccess.READ)
	if f == null:
		push_error("AnimSheet: missing " + base + "sheet.json")
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	cell = int(d["cell"])
	cols = int(d["cols"])
	ground = Vector2i(cell / 2, cell - 5)
	if d.has("ground"):
		ground = Vector2i(int(d["ground"][0]), int(d["ground"][1]))
	rows = int(ceil(float(d["frames"]) / cols))
	tex = _tex(base + "sheet.png")
	ntex = _tex(base + "normal.png")
	for name in d["anims"]:
		var a: Dictionary = d["anims"][name]
		var ticks: Array = a["ticks"]
		var starts: Array = []
		var acc := 0
		for t in ticks:
			starts.append(acc)
			acc += int(t)
		# per logical frame: entries sorted by "at" (tick offset inside that frame). Old sheets (one
		# optional sub-frame) are converted: the sub-frame starts at the middle of the frame.
		var by_logical: Array = []
		for l in ticks.size():
			by_logical.append([])
		for fr in a["frames"]:
			var l := int(fr["logical"])
			var at := int(fr["at"]) if fr.has("at") else (int(ceil(int(ticks[l]) / 2.0)) if fr["sub"] else 0)
			by_logical[l].append({"i": int(fr["i"]), "at": at, "anchors": fr["anchors"]})
		for l in by_logical.size():
			(by_logical[l] as Array).sort_custom(func(x, y): return x["at"] < y["at"])
		anims[name] = {
			"loop": a["loop"], "ticks": ticks, "starts": starts, "total": acc,
			"contact": a["contact"], "hold": a["hold"], "frames": by_logical,
			"ref_speed": float(a.get("ref_speed_mps", 0.0)),
		}


func has_anim(name: String) -> bool:
	return anims.has(name)


func total_ticks(name: String) -> int:
	return anims[name]["total"] if anims.has(name) else 0


## Returns { "i": sheet index, "logical": int, "anchors": Dictionary } for a tick.
func at(name: String, tick: int) -> Dictionary:
	var a: Dictionary = anims[name]
	var total: int = a["total"]
	if a["loop"]:
		tick = posmod(tick, total)
	else:
		tick = clampi(tick, 0, total - 1)
	var starts: Array = a["starts"]
	var l := starts.size() - 1
	while l > 0 and starts[l] > tick:
		l -= 1
	var within: int = tick - int(starts[l])
	var list: Array = a["frames"][l]
	var fr: Dictionary = list[0]
	for e in list:
		if int(e["at"]) <= within:
			fr = e
		else:
			break
	return {"i": int(fr["i"]), "logical": l, "anchors": fr["anchors"]}


## Ground speed (m/s) at which a locomotion cycle's feet do not slide (0 = unknown).
func ref_speed(name: String, fallback: float) -> float:
	if anims.has(name) and anims[name]["ref_speed"] > 0.0:
		return anims[name]["ref_speed"]
	return fallback


## [start, end) ticks of the first contact run, or Vector2i(-1, -1).
func contact_range(name: String) -> Vector2i:
	var a: Dictionary = anims[name]
	var c: Array = a["contact"]
	if c.is_empty():
		return Vector2i(-1, -1)
	var l := int(c[0])
	var s: int = a["starts"][l]
	return Vector2i(s, s + int(a["ticks"][l]))


## Every contact window of an animation (multi-hit specials list several contact frames).
func contact_ranges(name: String) -> Array:
	var out: Array = []
	if not anims.has(name):
		return out
	var a: Dictionary = anims[name]
	for c in a["contact"]:
		var s: int = a["starts"][int(c)]
		out.append(Vector2i(s, s + int(a["ticks"][int(c)])))
	return out


## First tick of a logical frame.
func frame_start(name: String, logical: int) -> int:
	return int(anims[name]["starts"][logical]) if anims.has(name) else 0


func uv_rect(i: int) -> Vector4:
	var cx := i % cols
	var cy := i / cols
	return Vector4(float(cx) / cols, float(cy) / rows, 1.0 / cols, 1.0 / rows)
