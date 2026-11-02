extends TestCase


func test_deterministic() -> void:
	var a := WorldGen.new("m1")
	var b := WorldGen.new("m1")
	near(a.height(10, 20), b.height(10, 20), 0.0001, "mesma altura")
	var na := a.node_placements()
	var nb := b.node_placements()
	eq(na.size(), nb.size(), "mesmos nós")
	eq(na[5]["pos"], nb[5]["pos"], "mesma posição")


func test_island_edges_are_water() -> void:
	for id in GameData.db().maps:
		var g := WorldGen.new(id)
		check(g.height(g.half - 1, g.half - 1) < 0.0, "%s canto é água" % id)


func test_points_of_interest_on_land() -> void:
	for id in GameData.db().maps:
		var g := WorldGen.new(id)
		var md: Dictionary = g.md
		check(g.is_land(md["spawn"][0], md["spawn"][1], 0.5), "%s spawn em terra" % id)
		for p in md["portals"]:
			check(g.is_land(p["pos"][0], p["pos"][1], 0.3) or p.get("bridge", false) or p.get("ferry", false), "%s portal %s em terra" % [id, p["to"]])
		var lair: Dictionary = md["pois"].get("lair", {})
		if not lair.is_empty():
			check(g.is_land(lair["pos"][0], lair["pos"][1], 0.5), "%s covil em terra" % id)
			check(g.slope_at(lair["pos"][0], lair["pos"][1], 2.0) < 1.5, "%s covil plano" % id)


func test_node_counts_reasonable() -> void:
	for id in GameData.db().maps:
		var g := WorldGen.new(id)
		var want := 0
		for k in g.md["trees"]:
			want += int(g.md["trees"][k])
		for k in g.md["nodes"]:
			want += int(g.md["nodes"][k])
		var got := g.node_placements().size()
		check(got >= want * 0.75, "%s: %d de %d nós" % [id, got, want])


func test_nodes_avoid_pads_and_water() -> void:
	var g := WorldGen.new("m1")
	for n in g.node_placements():
		check(n["pos"].y > 0.5, "nó %s acima da água" % n["key"])
		check(not g.near_pad(n["pos"].x, n["pos"].z, 3.0), "nó %s fora das áreas planas" % n["key"])


func test_unique_node_keys() -> void:
	var g := WorldGen.new("m2")
	var keys := {}
	for n in g.node_placements():
		check(not keys.has(n["key"]), "chave única " + n["key"])
		keys[n["key"]] = true


func test_fragments_placed() -> void:
	for id in GameData.db().maps:
		var g := WorldGen.new(id)
		eq(g.fragment_positions().size(), g.md["fragments"].size(), "%s fragmentos" % id)


func test_lair_layout_has_entrance_and_barriers() -> void:
	var g := WorldGen.new("m1")
	var l := g.lair_layout()
	check(l["pillars"].size() > 20, "anel de rochas")
	eq(l["barriers"].size(), 3, "3 espinhos")
	eq(l["boss"], "anciao_musgoso", "chefe")
	var g2 := WorldGen.new("m5")
	eq(g2.lair_layout()["barriers"].size(), 0, "covil aberto no ato 2")


func test_city_layout() -> void:
	var g := WorldGen.new("m4")
	var c := g.city_layout()
	check(c["houses"].size() > 15, "casas (%d)" % c["houses"].size())
	for h in c["houses"]:
		check(Vector2(h["pos"].x, h["pos"].z).length() > 20.0, "praça livre")
	eq(WorldGen.new("m1").city_layout().size(), 0, "mapa selvagem não tem cidade")


func test_cached_height_matches_raw() -> void:
	var g := WorldGen.new("m3")
	var step := g.half * 2.0 / WorldGen.CELLS
	for i in [0, 10, 48, 90]:
		var x: float = -g.half + i * step
		near(g.height(x, x), g.pad_blend(x, x, g.raw_height(x, x)), 0.01, "vértice %d" % i)


func _reachable(g: WorldGen) -> PackedByteArray:
	## Busca em largura pela grade do terreno a partir do spawn: sobe só encostas caminháveis,
	## desce qualquer altura (não há dano de queda).
	var n := WorldGen.CELLS + 1
	var step := g.half * 2.0 / WorldGen.CELLS
	var max_rise := step * tan(deg_to_rad(48.0))
	var seen := PackedByteArray()
	seen.resize(n * n)
	var sp: Array = g.md["spawn"]
	var si := clampi(int(round((float(sp[0]) + g.half) / step)), 0, WorldGen.CELLS)
	var sj := clampi(int(round((float(sp[1]) + g.half) / step)), 0, WorldGen.CELLS)
	var q: Array = [Vector2i(si, sj)]
	seen[sj * n + si] = 1
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var h0 := g.grid_height(c.x, c.y)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if nb.x < 0 or nb.y < 0 or nb.x > WorldGen.CELLS or nb.y > WorldGen.CELLS:
				continue
			if seen[nb.y * n + nb.x] == 1:
				continue
			var h1 := g.grid_height(nb.x, nb.y)
			if h1 < 0.2 or h1 - h0 > max_rise:
				continue
			seen[nb.y * n + nb.x] = 1
			q.append(nb)
	return seen


func _is_reached(g: WorldGen, seen: PackedByteArray, x: float, z: float) -> bool:
	var n := WorldGen.CELLS + 1
	var step := g.half * 2.0 / WorldGen.CELLS
	var ci := int(round((x + g.half) / step))
	var cj := int(round((z + g.half) / step))
	for dj in range(-2, 3):
		for di in range(-2, 3):
			var i := ci + di
			var j := cj + dj
			if i >= 0 and j >= 0 and i <= WorldGen.CELLS and j <= WorldGen.CELLS and seen[j * n + i] == 1:
				return true
	return false


func test_points_of_interest_reachable_on_foot() -> void:
	## Penhascos e platôs não podem isolar portais, covis e fragmentos do ponto de partida.
	for id in GameData.db().maps:
		var g := WorldGen.new(id)
		var seen := _reachable(g)
		for p in g.md["portals"]:
			if p.get("bridge", false) or p.get("ferry", false):
				continue
			check(_is_reached(g, seen, p["pos"][0], p["pos"][1]), "%s: portal para %s alcançável" % [id, p["to"]])
		var pois: Dictionary = g.md["pois"]
		for k in pois:
			check(_is_reached(g, seen, pois[k]["pos"][0], pois[k]["pos"][1]), "%s: %s alcançável" % [id, k])
		for f in g.fragment_positions():
			var fp: Vector3 = f["pos"] if f is Dictionary else f
			check(_is_reached(g, seen, fp.x, fp.z), "%s: fragmento alcançável" % id)
