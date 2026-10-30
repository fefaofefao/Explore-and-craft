extends TestCase


func test_damage_positive_and_type_effect() -> void:
	var r := rng(5)
	var neutral := 0
	var sup := 0
	for i in 200:
		neutral += CombatLogic.damage(20, 60, 40, 40, "volt", ["volt"], ["flora"], r)["dmg"]
		sup += CombatLogic.damage(20, 60, 40, 40, "brasa", ["volt"], ["flora"], r)["dmg"]
	check(neutral > 0, "dano positivo")
	check(float(sup) / neutral > 1.15 and float(sup) / neutral < 1.6, "super efetivo ~1.25x (sem STAB) %f" % (float(sup) / neutral))


func test_stab_bonus() -> void:
	var r1 := rng(9)
	var r2 := rng(9)
	var a: int = CombatLogic.damage(20, 60, 40, 40, "flora", ["flora"], ["volt"], r1)["dmg"]
	var b: int = CombatLogic.damage(20, 60, 40, 40, "flora", ["volt"], ["volt"], r2)["dmg"]
	check(a >= b, "STAB não reduz")


func test_fight_length_reasonable() -> void:
	## Eco equilibrado contra selvagem do mesmo nível deve cair em 4-12 golpes básicos.
	var r := rng(11)
	for lvl in [5, 15, 30]:
		var att := MonsterLogic.create("brasito", lvl, r)
		var def := MonsterLogic.create("pedrisco", lvl, r)
		var hp := MonsterLogic.max_hp(def)
		var hits := 0
		while hp > 0 and hits < 100:
			hp -= CombatLogic.damage(lvl, 25, MonsterLogic.stat(att, "atk"), MonsterLogic.stat(def, "def"), "", MonsterLogic.types_of(att), MonsterLogic.types_of(def), r)["dmg"]
			hits += 1
		check(hits >= 3 and hits <= 16, "nível %d: %d golpes" % [lvl, hits])


func test_capture_chance_rules() -> void:
	var full := CombatLogic.capture_chance("folhito", 5, 1.0, 1.0, 5)
	var low := CombatLogic.capture_chance("folhito", 5, 0.1, 1.0, 5)
	var great := CombatLogic.capture_chance("folhito", 5, 0.1, 1.6, 5)
	check(low > full * 2.5, "pouca vida ajuda")
	check(great > low, "esfera melhor ajuda")
	var boss := CombatLogic.capture_chance("anciao_musgoso", 11, 0.1, 1.0, 11)
	check(boss < 0.1, "chefe difícil")
	var high_lvl := CombatLogic.capture_chance("folhito", 30, 0.1, 1.0, 5)
	check(high_lvl < low, "nível alto dificulta")
	check(CombatLogic.capture_chance("folhito", 5, 0.0, 2.5, 5) <= 0.97, "teto")
	check(CombatLogic.capture_chance("anciao_musgoso", 40, 1.0, 1.0, 1) >= 0.03, "piso")
	var col := CombatLogic.capture_chance("ferrugente", 15, 0.3, 1.0, 15, true)
	check(col > CombatLogic.capture_chance("ferrugente", 15, 0.3, 1.0, 15, false), "acorrentado tem bônus")


func test_variant_rate() -> void:
	var r := rng(3)
	var n := 0
	for i in 40000:
		if CombatLogic.roll_variant(r):
			n += 1
	check(n > 50 and n < 160, "variante ~1/400 (%d em 40000)" % n)


func test_player_damage_scales() -> void:
	check(CombatLogic.player_damage(10, 16) > CombatLogic.player_damage(1, 0), "arma e nível")
	check(CombatLogic.player_damage(1, 0) >= 1, "mínimo")


func test_damage_to_player_easy_mode() -> void:
	## Um selvagem do mesmo nível não mata o jogador em menos de ~12 golpes (modo fácil).
	var r := rng(4)
	for lvl in [3, 12, 25]:
		var m := MonsterLogic.create("lupigelo", lvl, r)
		var d := CombatLogic.damage_to_player(lvl, MonsterLogic.stat(m, "atk"), lvl, 25, r)
		var st := GameState.new()
		st.level = lvl
		check(d * 12 < st.max_hp(), "nível %d dano %d vs pv %d" % [lvl, d, int(st.max_hp())])


func test_best_skill_prefers_effective() -> void:
	var s := CombatLogic.best_skill_vs(["fagulha", "jato_agua"], ["brasa"], func(_x): return true)
	eq(s, "jato_agua", "água contra fogo")
	eq(CombatLogic.best_skill_vs(["fotossintese"], ["brasa"], func(_x): return true), "", "ignora cura")
