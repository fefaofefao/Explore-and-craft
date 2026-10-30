extends TestCase

const T0 := 1_800_000_000


func _rc() -> Dictionary:
	return GameData.db().remote_defaults.duplicate()


func test_no_interstitial_early() -> void:
	var s := fresh()
	s.play_time = 60
	check(not AdPolicy.can_interstitial(s, T0, T0 - 60, _rc()), "não nos primeiros minutos")
	s.play_time = 4000
	check(AdPolicy.can_interstitial(s, T0, T0 - 2000, _rc()), "depois pode")


func test_interstitial_interval_and_cap() -> void:
	var s := fresh()
	s.play_time = 10000
	var start := T0 - 5000
	AdPolicy.on_interstitial_shown(s, T0)
	check(not AdPolicy.can_interstitial(s, T0 + 60, start, _rc()), "intervalo")
	check(AdPolicy.can_interstitial(s, T0 + 400, start, _rc()), "após intervalo")
	for i in 10:
		AdPolicy.on_interstitial_shown(s, T0 + 400 * (i + 1))
	check(not AdPolicy.can_interstitial(s, T0 + 9000, start, _rc()), "teto diário")


func test_no_ads_purchase_blocks_interstitial() -> void:
	var s := fresh()
	s.play_time = 10000
	s.iap_state["no_ads"] = true
	check(not AdPolicy.can_interstitial(s, T0, T0 - 5000, _rc()), "sem anúncios")
	s.iap_state["no_ads"] = false
	s.iap_state["purchases"] = ["gems_80"]
	check(not AdPolicy.can_interstitial(s, T0, T0 - 5000, _rc()), "pagantes não veem")


func test_remote_config_disables() -> void:
	var s := fresh()
	s.play_time = 10000
	var rc := _rc()
	rc["interstitial_enabled"] = false
	check(not AdPolicy.can_interstitial(s, T0, T0 - 5000, rc), "desligado remotamente")


func test_rewarded_cooldown() -> void:
	var s := fresh()
	check(AdPolicy.can_rewarded(s, "free_spheres", T0, _rc()), "disponível")
	AdPolicy.on_rewarded_done(s, "free_spheres", T0)
	check(not AdPolicy.can_rewarded(s, "free_spheres", T0 + 60, _rc()), "recarga")
	check(AdPolicy.can_rewarded(s, "free_spheres", T0 + 14401, _rc()), "volta")
	check(AdPolicy.can_rewarded(s, "revive_here", T0, _rc()), "reviver sem recarga")
	check(not AdPolicy.can_rewarded(s, "inexistente", T0, _rc()), "placement inválido")


func test_rewarded_daily_cap() -> void:
	var s := fresh()
	var rc := _rc()
	rc["rewarded_daily_cap"] = 3
	for i in 3:
		AdPolicy.on_rewarded_done(s, "revive_here", T0 + i)
	check(not AdPolicy.can_rewarded(s, "revive_here", T0 + 10, rc), "teto")
	check(AdPolicy.can_rewarded(s, "revive_here", T0 + 86400, rc), "zera no dia seguinte")


func test_expedition_flow() -> void:
	var s := fresh()
	for i in 7:
		s.add_monster(MonsterLogic.create("areiao", 10, rng(i)))
	var uid: int = s.box[0]
	eq(ExpeditionLogic.start(s, s.party[0], 0, "m1", T0)["reason"], "not_in_box", "só da reserva")
	check(ExpeditionLogic.start(s, uid, 0, "m1", T0)["ok"], "iniciou")
	check(s.get_monster(uid)["expedition"], "marcado")
	eq(ExpeditionLogic.start(s, uid, 0, "m1", T0)["reason"], "monster", "não duplica")
	eq(ExpeditionLogic.start(s, s.box[1], 0, "m5", T0)["reason"], "map", "mapa trancado")
	eq(ExpeditionLogic.complete(s, 0, T0 + 10, rng()).size(), 0, "ainda não")
	var r := ExpeditionLogic.complete(s, 0, T0 + 3601, rng())
	check(r["items"].size() > 0, "trouxe itens")
	check(not s.get_monster(uid)["expedition"], "voltou")
	eq(s.stats["expeditions"], 1, "contou")


func test_expedition_slots() -> void:
	var s := fresh()
	for i in 8:
		s.add_monster(MonsterLogic.create("areiao", 10, rng(i)))
	check(ExpeditionLogic.start(s, s.box[0], 0, "m1", T0)["ok"], "1")
	check(ExpeditionLogic.start(s, s.box[1], 0, "m1", T0)["ok"], "2")
	eq(ExpeditionLogic.start(s, s.box[2], 0, "m1", T0)["reason"], "slots", "sem vaga")


func test_hunger_never_kills_in_easy_mode() -> void:
	var s := fresh()
	for i in 20000:
		SurvivalLogic.tick(s, 1.0, null)
	near(s.hunger, 0.0, 0.01, "faminto")
	check(s.hp >= 10.0, "fome não mata (%f)" % s.hp)


func test_hazard_and_protection() -> void:
	var s := fresh()
	var hz := {"kind": "calor", "gear": "cantil", "dps": 1.0}
	var e := SurvivalLogic.tick(s, 1.0, hz)
	check(e["hazard_dmg"] > 0.0, "calor fere")
	s.inv.add("cantil")
	e = SurvivalLogic.tick(s, 1.0, hz)
	eq(e["hazard_dmg"], 0.0, "cantil protege")


func test_eat() -> void:
	var s := fresh()
	s.hunger = 10
	s.hp = 50
	s.inv.add("carne_assada")
	check(SurvivalLogic.eat(s, "carne_assada"), "comeu")
	near(s.hunger, 45, 0.01, "fome")
	near(s.hp, 65, 0.01, "vida")
	check(not SurvivalLogic.eat(s, "madeira"), "não come madeira")


func test_day_cycle_and_sleep() -> void:
	var s := fresh()
	s.day_time = 0.99
	check(SurvivalLogic.advance_time(s, 30.0), "virou o dia")
	eq(s.day_count, 2, "dia 2")
	s.day_time = 0.5
	check(not SurvivalLogic.sleep(s), "não dorme de dia")
	s.day_time = 0.9
	check(SurvivalLogic.sleep(s), "dorme à noite")
	near(s.day_time, 0.25, 0.001, "amanhece")
	eq(s.day_count, 3, "pulou para o próximo dia")


func test_sandbox_no_hunger() -> void:
	var s := fresh("sandbox")
	s.hunger = 5
	SurvivalLogic.tick(s, 10.0, {"kind": "frio", "gear": "casaco_pele", "dps": 50.0})
	near(s.hunger, 100.0, 0.01, "sem fome")
