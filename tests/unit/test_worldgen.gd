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
