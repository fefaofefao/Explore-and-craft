extends TestCase


func test_hand_recipe() -> void:
	var s := fresh()
	s.inv.add("madeira", 3)
	s.inv.add("pedra", 3)
	s.inv.add("fibra", 2)
	var r := CraftLogic.craft(s, "r_machado_pedra", [])
	check(r["ok"], "criou")
	eq(s.inv.count("machado_pedra"), 1, "machado")
	eq(s.inv.count("madeira"), 0, "consumiu")
	eq(s.stats["crafted"]["machado_pedra"], 1, "estatística")


func test_station_required() -> void:
	var s := fresh()
	s.level = 10
	s.inv.add("minerio_ferro", 2)
	s.inv.add("carvao", 1)
	eq(CraftLogic.check(s, "r_lingote", [])["reason"], "station", "precisa fornalha")
	check(CraftLogic.craft(s, "r_lingote", ["fornalha"])["ok"], "com fornalha")


func test_level_required() -> void:
	var s := fresh()
	s.inv.add("pele", 10)
	s.inv.add("corda", 10)
	s.inv.add("fibra", 10)
	eq(CraftLogic.check(s, "r_casaco", ["bancada"])["reason"], "level", "nível baixo")
	s.level = 5
	check(CraftLogic.check(s, "r_casaco", ["bancada"])["ok"], "nível ok")


func test_missing_items() -> void:
	var s := fresh()
	eq(CraftLogic.check(s, "r_tocha", [])["reason"], "items", "faltam itens")


func test_craft_multiple_times() -> void:
	var s := fresh()
	s.inv.add("fibra", 9)
	eq(CraftLogic.max_times(s, "r_corda"), 3, "3 vezes")
	check(CraftLogic.craft(s, "r_corda", [], 3)["ok"], "x3")
	eq(s.inv.count("corda"), 3, "3 cordas")


func test_sandbox_crafts_anything() -> void:
	var s := fresh("sandbox")
	check(CraftLogic.craft(s, "r_nucleo_ponte", [])["ok"], "sandbox cria relíquia sem estação")


func test_build_place_and_slots() -> void:
	var s := fresh()
	s.inv.add("madeira", 50)
	s.inv.add("pedra", 50)
	s.inv.add("fibra", 20)
	var c := Vector2i(5, 5)
	check(BuildLogic.place(s, "fundacao", "m1", c, 0, 3.0, {})["ok"], "fundação")
	eq(BuildLogic.check(s, "fundacao", "m1", c, 0, {})["reason"], "occupied", "célula ocupada")
	check(BuildLogic.place(s, "parede", "m1", c, 0, 3.5, {})["ok"], "parede norte")
	check(BuildLogic.place(s, "parede", "m1", c, 1, 3.5, {})["ok"], "parede leste no mesmo piso")
	eq(BuildLogic.check(s, "parede", "m1", c, 4, {})["reason"], "occupied", "rotação 4 = 0")
	check(BuildLogic.place(s, "bancada", "m1", c, 0, 3.5, {})["ok"], "bancada sobre fundação")
	near(BuildLogic.base_height(s, "m1", c, 1.0), 3.5, 0.001, "apoia na fundação")
	eq(s.count_buildings("parede"), 2, "contagem")


func test_build_terrain_rules() -> void:
	var s := fresh()
	s.inv.add("madeira", 50)
	s.inv.add("pedra", 50)
	eq(BuildLogic.check(s, "fogueira", "m1", Vector2i(0, 0), 0, {"water": true})["reason"], "water", "água")
	eq(BuildLogic.check(s, "fogueira", "m1", Vector2i(0, 0), 0, {"slope": 5.0})["reason"], "slope", "inclinação")
	eq(BuildLogic.check(s, "fogueira", "m1", Vector2i(0, 0), 0, {"blocked": true})["reason"], "blocked", "zona protegida")
	eq(BuildLogic.check(s, "forja", "m1", Vector2i(0, 0), 0, {})["reason"], "level", "nível")


func test_bed_sets_spawn() -> void:
	var s := fresh()
	s.level = 3
	s.inv.add("madeira", 10)
	s.inv.add("fibra", 10)
	s.inv.add("pele", 5)
	var r := BuildLogic.place(s, "cama", "m2", Vector2i(10, -4), 0, 5.0, {})
	check(r["ok"], "cama")
	eq(s.spawn_point["map"], "m2", "spawn mapa")


func test_demolish_refund_and_support() -> void:
	var s := fresh()
	s.inv.add("madeira", 20)
	s.inv.add("pedra", 10)
	var f := BuildLogic.place(s, "fundacao", "m1", Vector2i(1, 1), 0, 2.0, {})
	var w := BuildLogic.place(s, "parede", "m1", Vector2i(1, 1), 0, 2.5, {})
	check(not BuildLogic.demolish(s, f["entry"]["uid"])["ok"], "fundação com parede em cima")
	var madeira := s.inv.count("madeira")
	check(BuildLogic.demolish(s, w["entry"]["uid"])["ok"], "demole parede")
	eq(s.inv.count("madeira"), madeira + 2, "reembolso 50%")
	check(BuildLogic.demolish(s, f["entry"]["uid"])["ok"], "agora a fundação")


func test_stations_near() -> void:
	var s := fresh()
	s.inv.add("madeira", 20)
	s.inv.add("pedra", 20)
	BuildLogic.place(s, "bancada", "m1", Vector2i(0, 0), 0, 1.0, {})
	var near_st := BuildLogic.stations_near(s, "m1", Vector3(2, 0, 2))
	check("bancada" in near_st, "bancada perto")
	check(not "bancada" in BuildLogic.stations_near(s, "m1", Vector3(40, 0, 40)), "longe")
	check(not "bancada" in BuildLogic.stations_near(s, "m2", Vector3(1, 0, 1)), "outro mapa")


func test_gear_wears_out_and_breaks() -> void:
	var s := fresh()
	s.inv.add("machado_pedra", 1)
	var mx := Inventory.max_dur("machado_pedra")
	check(mx > 0, "machado tem durabilidade")
	eq(s.inv.durability_of("machado_pedra"), mx, "começa cheio")
	check(not s.inv.use_durability("machado_pedra", mx - 1), "não quebra antes do fim")
	eq(s.inv.durability_of("machado_pedra"), 1, "resta 1 uso")
	check(s.inv.use_durability("machado_pedra"), "quebra no último uso")
	eq(s.inv.count("machado_pedra"), 0, "some da mochila")


func test_repair_cost_scales_with_wear() -> void:
	var s := fresh()
	s.inv.add("machado_pedra", 1)
	eq(CraftLogic.can_repair(s, "machado_pedra")["reason"], "full", "novo não precisa de reparo")
	var mx := Inventory.max_dur("machado_pedra")
	s.inv.use_durability("machado_pedra", mx / 5)
	var light := CraftLogic.repair_cost(s, "machado_pedra")
	s.inv.use_durability("machado_pedra", mx / 2)
	var heavy := CraftLogic.repair_cost(s, "machado_pedra")
	var tl := 0
	var th := 0
	for k in light:
		tl += int(light[k])
	for k in heavy:
		th += int(heavy[k])
	check(tl >= 1, "reparo leve custa algo")
	check(th > tl, "mais desgaste, reparo mais caro (%d > %d)" % [th, tl])
	# nunca mais que metade da receita
	var req: Dictionary = GameData.db().recipes["r_machado_pedra"]["in"]
	for k in heavy:
		check(int(heavy[k]) <= int(ceil(int(req[k]) * 0.5)), "no máximo metade de " + k)


func test_repair_restores_durability_and_spends_materials() -> void:
	var s := fresh()
	s.inv.add("picareta_pedra", 1)
	var mx := Inventory.max_dur("picareta_pedra")
	s.inv.use_durability("picareta_pedra", mx - 3)
	var chk := CraftLogic.can_repair(s, "picareta_pedra")
	eq(chk["reason"], "missing", "sem materiais")
	for k in chk["cost"]:
		s.inv.add(k, int(chk["cost"][k]))
	var r := CraftLogic.repair(s, "picareta_pedra")
	check(r["ok"], "reparou")
	eq(s.inv.durability_of("picareta_pedra"), mx, "durabilidade cheia")
	for k in chk["cost"]:
		eq(s.inv.count(k), 0, "gastou " + k)
	eq(s.stats["repairs"], 1, "estatística de reparos")


func test_non_wearing_items_cannot_be_repaired() -> void:
	var s := fresh()
	s.inv.add("corda", 2)
	eq(CraftLogic.can_repair(s, "corda")["reason"], "no_repair", "corda não se repara")
	eq(CraftLogic.can_repair(s, "machado_ferro")["reason"], "no_item", "sem o item")
