extends TestCase


func test_create_has_valid_stats() -> void:
	var m := MonsterLogic.create("folhito", 5, rng())
	eq(m["lvl"], 5, "nível")
	check(MonsterLogic.max_hp(m) > 15, "pv razoável")
	eq(m["hp"], MonsterLogic.max_hp(m), "começa cheio")
	check(m["skills"].size() >= 1, "tem habilidade")
	check(m["talent"] >= 0.0 and m["talent"] <= 1.0, "talento 0..1")


func test_stats_grow_with_level() -> void:
	var a := MonsterLogic.create("brasito", 5, rng(1))
	var b := a.duplicate(true)
	b["lvl"] = 30
	check(MonsterLogic.stat(b, "atk") > MonsterLogic.stat(a, "atk") * 3, "ataque escala")
	check(MonsterLogic.max_hp(b) > MonsterLogic.max_hp(a) * 3, "pv escala")


func test_bond_and_variant_boost_stats() -> void:
	var a := MonsterLogic.create("marolo", 20, rng(2))
	var base := MonsterLogic.stat(a, "def")
	a["bond"] = 10
	check(MonsterLogic.stat(a, "def") > base, "vínculo aumenta")
	a["variant"] = true
	check(MonsterLogic.stat(a, "def") > base * 1.25, "variante + vínculo")


func test_level_up_learns_and_evolves() -> void:
	var m := MonsterLogic.create("folhito", 1, rng(3))
	var total := 0
	for l in range(1, 16):
		total += MonsterLogic.xp_to_next(l)
	var res := MonsterLogic.add_xp(m, total)
	eq(m["lvl"], 16, "chegou ao 16")
	check(res["learned"].size() >= 1, "aprendeu algo")
	eq(res["evolve"], "folhagrao", "pode evoluir")
	check(MonsterLogic.evolve(m), "evoluiu")
	eq(m["sp"], "folhagrao", "nova espécie")
	check(m["hp"] > 0 and m["hp"] <= MonsterLogic.max_hp(m), "pv coerente")


func test_skills_capped_at_four() -> void:
	var m := MonsterLogic.create("folhagrao", 60, rng())
	check(m["skills"].size() <= 4, "no máx 4")


func test_xp_curve_increasing() -> void:
	for l in range(1, 60):
		check(MonsterLogic.xp_to_next(l + 1) > MonsterLogic.xp_to_next(l), "curva crescente %d" % l)


func test_heal_and_revive() -> void:
	var m := MonsterLogic.create("pedrisco", 10, rng())
	m["hp"] = 1
	m["fainted"] = true
	eq(MonsterLogic.heal(m, 50), 0, "não cura desmaiado sem reviver")
	check(MonsterLogic.heal(m, 0.5, true) > 0, "revive")
	check(not m["fainted"], "acordou")
	MonsterLogic.full_heal(m)
	eq(m["hp"], MonsterLogic.max_hp(m), "cura total")


func test_type_multipliers() -> void:
	near(MonsterLogic.type_mult("brasa", ["flora"]), 1.5, 0.001, "fogo > planta")
	near(MonsterLogic.type_mult("flora", ["brasa"]), 0.67, 0.001, "planta < fogo")
	near(MonsterLogic.type_mult("mare", ["brasa", "terra"]), 2.25, 0.001, "duplo super")
	near(MonsterLogic.type_mult("volt", ["flora"]), 1.0, 0.001, "neutro")


func test_bond_levels() -> void:
	var m := MonsterLogic.create("cactuto", 5, rng())
	check(not MonsterLogic.add_bond(m, 50), "ainda não")
	check(MonsterLogic.add_bond(m, 60), "subiu")
	eq(m["bond"], 1, "vínculo 1")
	MonsterLogic.add_bond(m, 99999)
	eq(m["bond"], 10, "teto")


func test_work_levels() -> void:
	var m := MonsterLogic.create("brasito", 5, rng())
	eq(MonsterLogic.work_level(m, "chama"), 2, "chama")
	eq(MonsterLogic.work_level(m, "corte"), 0, "sem corte")
	eq(MonsterLogic.work_level(m, "any"), 2, "qualquer = melhor")


func test_harmony() -> void:
	near(MonsterLogic.harmony_bonus(["flora", "brasa"]), 0.0, 0.001, "2 tipos")
	near(MonsterLogic.harmony_bonus(["flora", "brasa", "mare"]), 0.10, 0.001, "3 tipos")
	near(MonsterLogic.harmony_bonus(["flora", "flora", "flora"]), 0.0, 0.001, "repetidos")


func test_kill_xp_boss_bigger() -> void:
	var a := MonsterLogic.create("folhito", 10, rng())
	var b := MonsterLogic.create("anciao_musgoso", 10, rng())
	check(MonsterLogic.kill_xp(b) > MonsterLogic.kill_xp(a) * 3, "chefe dá mais xp")
