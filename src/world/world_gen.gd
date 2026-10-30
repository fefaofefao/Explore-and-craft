class_name WorldGen
extends RefCounted
## Geração determinística de um mapa: relevo (ilha), áreas planas para pontos de interesse,
## posições de recursos, fragmentos, estruturas de cidade. Sem nós de cena: testável headless.

const WATER_Y := 0.0
const CELLS := 128  # resolução da malha do terreno (célula de ~1,9 m)

var map_id: String
var md: Dictionary
var half: float
var biome: Dictionary
var noise: FastNoiseLite
var ridge: FastNoiseLite
var detail: FastNoiseLite
var pads: Array = []  # {"pos": Vector2, "r": float, "h": float}
var _h_cache: PackedFloat32Array
var _cache_ready := false


func _init(p_map_id: String) -> void:
	map_id = p_map_id
	md = GameData.db().maps[map_id]
	half = float(md["half"])
	biome = md["biome"]
	noise = FastNoiseLite.new()
	noise.seed = int(md["seed"])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(biome["freq"])
	noise.fractal_octaves = 4
	ridge = FastNoiseLite.new()
	ridge.seed = int(md["seed"]) + 77
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.frequency = float(biome["freq"]) * 0.8
	ridge.fractal_octaves = 3
	detail = FastNoiseLite.new()
	detail.seed = int(md["seed"]) + 13
	detail.frequency = 0.08
	_build_pads()
	_build_cache()


func _build_pads() -> void:
	var add := func(p: Array, r: float) -> void:
		var v := Vector2(p[0], p[1])
		pads.append({"pos": v, "r": r, "h": max(raw_height(v.x, v.y), 1.6)})
	if md.get("city") != null:
		# cidades são quase planas: um grande platô
		pads.append({"pos": Vector2.ZERO, "r": half * 0.78, "h": 2.2})
	add.call(md["spawn"], 10.0)
	if md.has("cradle"):
		add.call(md["cradle"], 8.0)
	for p in md["portals"]:
		add.call(p["pos"], 7.0)
	var pois: Dictionary = md.get("pois", {})
	for k in pois:
		add.call(pois[k]["pos"], float(pois[k].get("r", 10.0)) + 4.0)


func island_mask(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / half
	# costa irregular
	d += detail.get_noise_2d(x * 0.5, z * 0.5) * 0.06
	return clampf(smoothstep(1.0, 0.74, d), 0.0, 1.0)


func raw_height(x: float, z: float) -> float:
	var hamp := float(biome["height"])
	var n := (noise.get_noise_2d(x, z) * 0.5 + 0.5)
	var r := ridge.get_noise_2d(x, z) * 0.5 + 0.5
	var mtn := float(biome["mountains"])
	var h := 1.5 + n * hamp + pow(r, 2.0) * hamp * 1.6 * mtn
	h += detail.get_noise_2d(x, z) * 0.35
	var mask := island_mask(x, z)
	return lerpf(-5.0, h, mask)


func pad_blend(x: float, z: float, h: float) -> float:
	var out := h
	for p in pads:
		var d: float = Vector2(x, z).distance_to(p["pos"])
		var r: float = p["r"]
		if d < r * 1.7:
			var t := 1.0 - smoothstep(r, r * 1.7, d)
			out = lerpf(out, p["h"], t)
	return out


func height(x: float, z: float) -> float:
	## Altura do terreno (com áreas planas). Usa cache em grade + interpolação bilinear.
	if _cache_ready:
		return _cached_height(x, z)
	return pad_blend(x, z, raw_height(x, z))


func _build_cache() -> void:
	var n := CELLS + 1
	_h_cache.resize(n * n)
	var step := half * 2.0 / CELLS
	for j in n:
		for i in n:
			var x := -half + i * step
			var z := -half + j * step
			_h_cache[j * n + i] = pad_blend(x, z, raw_height(x, z))
	_cache_ready = true


func grid_height(i: int, j: int) -> float:
	var n := CELLS + 1
	return _h_cache[clampi(j, 0, CELLS) * n + clampi(i, 0, CELLS)]


func _cached_height(x: float, z: float) -> float:
	## Interpolação idêntica à triangulação da malha (diagonal i,j -> i+1,j+1),
	## assim personagens pisam exatamente na superfície visível.
	var step := half * 2.0 / CELLS
	var fx := clampf((x + half) / step, 0.0, CELLS - 0.0001)
	var fz := clampf((z + half) / step, 0.0, CELLS - 0.0001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := grid_height(i, j)
	var h10 := grid_height(i + 1, j)
	var h01 := grid_height(i, j + 1)
	var h11 := grid_height(i + 1, j + 1)
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func slope_at(x: float, z: float, r: float = 1.0) -> float:
	var hs := [height(x - r, z - r), height(x + r, z - r), height(x - r, z + r), height(x + r, z + r)]
	return hs.max() - hs.min()


func is_land(x: float, z: float, margin: float = 0.8) -> bool:
	return height(x, z) > WATER_Y + margin


func near_pad(x: float, z: float, extra: float = 3.0) -> bool:
	for p in pads:
		if p["r"] > half * 0.5:
			continue  # platô da cidade não bloqueia
		if Vector2(x, z).distance_to(p["pos"]) < p["r"] + extra:
			return true
	return false


func in_bounds(x: float, z: float) -> bool:
	return absf(x) < half - 2.0 and absf(z) < half - 2.0


# ------------------------------------------------------------------ recursos
func node_placements() -> Array:
	## [{"key", "kind", "pos": Vector3, "rot", "scale"}] determinístico por mapa.
	var out: Array = []
	var taken := {}
	var all_kinds: Dictionary = {}
	for k in md["trees"]:
		all_kinds[k] = int(md["trees"][k])
	for k in md["nodes"]:
		all_kinds[k] = int(md["nodes"][k])
	var keys := all_kinds.keys()
	keys.sort()
	var is_city: bool = md.get("city") != null
	for kind in keys:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(map_id + kind) ^ int(md["seed"])
		var want: int = all_kinds[kind]
		var placed := 0
		var tries := 0
		while placed < want and tries < want * 40:
			tries += 1
			var rr := half * (0.82 if not is_city else 0.95)
			var x := rng.randf_range(-rr, rr)
			var z := rng.randf_range(-rr, rr)
			var h := height(x, z)
			var beach_ok: bool = kind in ["palmeira", "monte_areia", "lodo_poca"]
			if h < (0.9 if beach_ok else 1.8):
				continue
			if slope_at(x, z) > (3.5 if kind in ["rocha", "minerio", "carvao_veio", "cristal", "obsidiana_veio", "bloco_gelo"] else 2.2):
				continue
			if near_pad(x, z, 4.0):
				continue
			if is_city and Vector2(x, z).length() < half * 0.85:
				continue  # na cidade, recursos só na periferia
			var cell := Vector2i(int(x / 3.0), int(z / 3.0))
			if taken.has(cell):
				continue
			taken[cell] = true
			out.append({"key": "%s_%d" % [kind, placed], "kind": kind, "pos": Vector3(x, h, z),
				"rot": rng.randf() * TAU, "scale": rng.randf_range(0.8, 1.25)})
			placed += 1
	return out


func fragment_positions() -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(md["seed"]) * 31 + 7
	var ids: Array = md["fragments"]
	var tries := 0
	while out.size() < ids.size() and tries < 500:
		tries += 1
		var x := rng.randf_range(-half * 0.7, half * 0.7)
		var z := rng.randf_range(-half * 0.7, half * 0.7)
		if not is_land(x, z, 1.5) or near_pad(x, z, 6.0) or slope_at(x, z) > 2.5:
			continue
		var ok := true
		for o in out:
			if Vector2(x, z).distance_to(Vector2(o["pos"].x, o["pos"].z)) < 40.0:
				ok = false
		if ok:
			out.append({"id": ids[out.size()], "pos": Vector3(x, height(x, z), z)})
	return out


func random_spawn_point(rng: RandomNumberGenerator, avoid: Vector3 = Vector3.INF, min_dist: float = 18.0) -> Vector3:
	for i in 60:
		var x := rng.randf_range(-half * 0.78, half * 0.78)
		var z := rng.randf_range(-half * 0.78, half * 0.78)
		if not is_land(x, z, 1.5) or slope_at(x, z) > 3.0:
			continue
		if near_pad(x, z, 2.0):
			continue
		if avoid != Vector3.INF and Vector2(x, z).distance_to(Vector2(avoid.x, avoid.z)) < min_dist:
			continue
		return Vector3(x, height(x, z), z)
	return Vector3(0, height(0, 0), 0)


func lair_layout() -> Dictionary:
	## Anel de rochas com entrada voltada para o centro do mapa; barreiras na entrada.
	var lair: Dictionary = md.get("pois", {}).get("lair", {})
	if lair.is_empty():
		return {}
	var c := Vector2(lair["pos"][0], lair["pos"][1])
	var r: float = float(lair["r"])
	var to_center := (-c).normalized() if c.length() > 0.1 else Vector2(0, 1)
	var entrance_ang := atan2(to_center.y, to_center.x)
	var pillars: Array = []
	var n := int(TAU * r / 2.4)
	for i in n:
		var a := TAU * i / n
		if absf(angle_difference(a, entrance_ang)) < 0.22:
			continue
		var p := c + Vector2(cos(a), sin(a)) * r
		pillars.append(Vector3(p.x, height(p.x, p.y), p.y))
	var barriers: Array = []
	var bkind: String = lair.get("barrier", "")
	if bkind != "":
		var cnt := int(lair.get("barrier_count", 1))
		var perp := Vector2(-to_center.y, to_center.x)
		for i in cnt:
			var off := (i - (cnt - 1) / 2.0) * 1.8
			var p := c + to_center * r + perp * off
			barriers.append({"key": "barrier_%d" % i, "kind": bkind, "pos": Vector3(p.x, height(p.x, p.y), p.y)})
	return {"center": Vector3(c.x, height(c.x, c.y), c.y), "r": r, "pillars": pillars, "barriers": barriers,
		"entrance": Vector3((c + to_center * r).x, 0, (c + to_center * r).y), "boss": lair["boss"], "lvl": int(lair["lvl"]),
		"drop": lair["drop"], "temple": lair.get("temple", false)}


func city_layout() -> Dictionary:
	## Casas em quarteirões ao redor da praça/arena central, muralha e distritos.
	var city: Variant = md.get("city")
	if city == null:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(md["seed"]) + 999
	var houses: Array = []
	var keep_clear: Array = [Vector2.ZERO]
	for d in city["districts"]:
		keep_clear.append(Vector2(d["pos"][0], d["pos"][1]))
	for cg in city["cages"]:
		keep_clear.append(Vector2(cg[0], cg[1]))
	for p in md["portals"]:
		keep_clear.append(Vector2(p["pos"][0], p["pos"][1]))
	keep_clear.append(Vector2(md["spawn"][0], md["spawn"][1]))
	var wall_r := half * 0.8
	var step := 13.0
	var x := -wall_r
	while x <= wall_r:
		var z := -wall_r
		while z <= wall_r:
			var p := Vector2(x + rng.randf_range(-2, 2), z + rng.randf_range(-2, 2))
			z += step
			if p.length() > wall_r - 8.0 or p.length() < 22.0:
				continue
			# ruas em cruz
			if absf(p.x) < 7.0 or absf(p.y) < 7.0:
				continue
			var ok := true
			for k in keep_clear:
				if p.distance_to(k) < 12.0:
					ok = false
					break
			if not ok:
				continue
			houses.append({"pos": Vector3(p.x, height(p.x, p.y), p.y), "w": rng.randf_range(5, 8), "d": rng.randf_range(5, 7),
				"h": rng.randf_range(4, 8), "rot": [0.0, PI / 2][rng.randi_range(0, 1)], "style": rng.randi_range(0, 2)})
		x += step
	return {"houses": houses, "wall_r": wall_r, "arena": Vector3(0, height(0, 0), 0), "gate_dirs": _gate_dirs()}


func _gate_dirs() -> Array:
	var out: Array = []
	for p in md["portals"]:
		out.append(atan2(float(p["pos"][1]), float(p["pos"][0])))
	return out
