extends TestCase

const T0 := 1_800_000_000


func test_return_reminders_plan() -> void:
	var s := fresh()
	var plan := Notifications.plan(s, T0)
	eq(plan.size(), 1, "só o presente diário sem estações")
	s.level = 5
	s.inv.add("madeira", 20)
	s.inv.add("fibra", 20)
	s.inv.add("baga", 10)
	var b := BuildLogic.place(s, "horta", "m1", Vector2i(0, 0), 0, 1.0, {}, T0)
	s.add_monster(MonsterLogic.create("folhito", 10, rng()))
	WorkLogic.assign(s, b["entry"]["uid"], s.party[0], T0)
	plan = Notifications.plan(s, T0)
	eq(plan.size(), 2, "lembrete de estação cheia")
	check(int(plan[0]["in"]) >= 1800, "no mínimo 30 min")


func test_banner_policy() -> void:
	var s := fresh()
	var rc := GameData.db().remote_defaults.duplicate()
	check(not AdPolicy.banner_allowed(s, rc), "banner desligado por padrão")
	rc["banner_in_menus"] = true
	check(AdPolicy.banner_allowed(s, rc), "liga por remote config")
	s.iap_state["no_ads"] = true
	check(not AdPolicy.banner_allowed(s, rc), "sem anúncios desliga")


func test_loc_switch_and_format() -> void:
	var old := Loc.lang
	Loc.lang = "en"
	eq(Loc.t("continue"), "Continue", "inglês")
	eq(Loc.t("level_short", [7]), "Lv 7", "parâmetro")
	Loc.lang = "pt"
	eq(Loc.t("continue"), "Continuar", "português")
	eq(Loc.t("chave_inexistente_xyz"), "chave_inexistente_xyz", "fallback para a chave")
	eq(Loc.fmt_time(3725), "1h 02m", "tempo")
	Loc.lang = old


func test_every_map_reachable_by_portals() -> void:
	## Grafo de portais: a partir do m1, todos os mapas são alcançáveis.
	var db := GameData.db()
	var seen := {"m1": true}
	var queue := ["m1"]
	while queue.size() > 0:
		var m: String = queue.pop_front()
		for p in db.maps[m]["portals"]:
			if not seen.has(p["to"]):
				seen[p["to"]] = true
				queue.append(p["to"])
	eq(seen.size(), db.maps.size(), "todos os mapas alcançáveis")


func test_quest_markers_point_to_existing_maps() -> void:
	for q in GameData.db().quests:
		if q["marker"] != null:
			check(GameData.db().maps.has(q["marker"]["map"]), "marcador de %s" % q["id"])


func test_skill_slot_shows_strongest() -> void:
	eq(MonsterLogic.skill_slot(["a"], 0), 0, "1 habilidade")
	eq(MonsterLogic.skill_slot(["a"], 1), -1, "sem segunda")
	eq(MonsterLogic.skill_slot(["a", "b", "c", "d"], 0), 2, "penúltima")
	eq(MonsterLogic.skill_slot(["a", "b", "c", "d"], 1), 3, "última")
