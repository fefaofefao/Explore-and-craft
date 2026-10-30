extends TestCase

const T0 := 1_800_000_000


func _setup_garden(s: GameState, sp: String = "folhito") -> Dictionary:
	s.level = 5
	s.inv.add("madeira", 20)
	s.inv.add("fibra", 20)
	s.inv.add("baga", 10)
	var r := BuildLogic.place(s, "horta", "m1", Vector2i(0, 0), 0, 1.0, {}, T0)
	s.add_monster(MonsterLogic.create(sp, 10, rng()))
	return r["entry"]


func test_assign_requires_skill() -> void:
	var s := fresh()
	var b := _setup_garden(s, "pedrisco")  # só mineração
	var uid: int = s.party[0]
	eq(WorkLogic.assign(s, b["uid"], uid, T0)["reason"], "skill", "pedrisco não colhe")


func test_assign_and_produce() -> void:
	var s := fresh()
	var b := _setup_garden(s)
	var uid: int = s.party[0]
	check(WorkLogic.assign(s, b["uid"], uid, T0)["ok"], "alocou")
	eq(s.get_monster(uid)["job"], b["uid"], "trabalho")
	eq(s.active_uid, -1, "trabalhador sai do combate")
	var p := WorkLogic.tick(s, b, T0 + 3600)
	check(int(p.get("baga", 0)) >= 20, "produziu bagas em 1h: %s" % str(p))
	var got := WorkLogic.collect(s, b)
	check(int(got.get("baga", 0)) >= 20, "recolheu")
	eq(WorkLogic.stored_total(b), 0, "esvaziou")


func test_skill_and_level_increase_rate() -> void:
	var a := MonsterLogic.create("folhito", 5, rng())
	var b := MonsterLogic.create("folhagrao", 5, rng())
	check(WorkLogic.rate_per_hour(b, "horta") > WorkLogic.rate_per_hour(a, "horta"), "habilidade maior produz mais")
	var c := a.duplicate(true)
	c["lvl"] = 40
	check(WorkLogic.rate_per_hour(c, "horta") > WorkLogic.rate_per_hour(a, "horta"), "nível maior produz mais")


func test_offline_cap_and_capacity() -> void:
	var s := fresh()
	var b := _setup_garden(s)
	WorkLogic.assign(s, b["uid"], s.party[0], T0)
	WorkLogic.tick(s, b, T0 + 86400 * 3)
	check(WorkLogic.stored_total(b) <= int(GameData.db().config["work"]["station_capacity"]), "respeita capacidade")


func test_offline_preview_does_not_mutate() -> void:
	var s := fresh()
	var b := _setup_garden(s)
	WorkLogic.assign(s, b["uid"], s.party[0], T0)
	var prev := WorkLogic.offline_preview(s, T0 + 7200)
	check(prev.size() > 0, "prévia produz")
	eq(WorkLogic.stored_total(b), 0, "estado intacto")


func test_reassign_moves_worker() -> void:
	var s := fresh()
	var b := _setup_garden(s)
	s.add_monster(MonsterLogic.create("cactuto", 10, rng(2)))
	var a: int = s.party[0]
	var c: int = s.party[1]
	WorkLogic.assign(s, b["uid"], a, T0)
	WorkLogic.assign(s, b["uid"], c, T0 + 60)
	eq(s.get_monster(a)["job"], -1, "anterior liberado")
	eq(b["data"]["worker"], c, "novo trabalhador")


func test_demolish_returns_stored() -> void:
	var s := fresh()
	var b := _setup_garden(s)
	WorkLogic.assign(s, b["uid"], s.party[0], T0)
	WorkLogic.tick(s, b, T0 + 3600)
	var before := s.inv.count("baga")
	BuildLogic.demolish(s, b["uid"])
	check(s.inv.count("baga") > before, "armazenado volta")
	eq(s.get_monster(s.party[0])["job"], -1, "trabalhador liberado")


func test_any_work_ranch() -> void:
	var m := MonsterLogic.create("pedrisco", 5, rng())
	check(WorkLogic.can_work(m, "rancho"), "rancho aceita qualquer")
	check(not WorkLogic.can_work(m, "serraria"), "serraria exige corte")
