extends TestCase


func test_new_game_defaults() -> void:
	var s := fresh()
	eq(s.level, 1, "nível 1")
	eq(s.map_id, "m1", "começa no bosque")
	check(s.coins > 0 and s.gems > 0, "moedas iniciais")
	near(s.hp, s.max_hp(), 0.01, "vida cheia")
	eq(s.quest_idx, 0, "primeira missão")


func test_player_level_up() -> void:
	var s := fresh()
	var ups := s.add_player_xp(s.xp_to_next())
	eq(ups, 1, "subiu")
	eq(s.level, 2, "nível 2")
	check(s.max_hp() > 100, "mais vida")


func test_xp_boost_doubles() -> void:
	var s := fresh()
	s.boosts["xp_until"] = 2_000_000_000
	s.add_player_xp(10, 1_900_000_000)
	eq(s.xp, 20, "dobrou")


func test_party_and_box_flow() -> void:
	var s := fresh()
	for i in 7:
		s.add_monster(MonsterLogic.create("folhito", 3, rng(i)))
	eq(s.party.size(), 5, "equipe cheia")
	eq(s.box.size(), 2, "resto na reserva")
	eq(s.active_uid, s.party[0], "primeiro ativo")
	check(s.move_to_box(s.party[0]), "para reserva")
	eq(s.party.size(), 4, "4 na equipe")
	check(s.active_uid == s.party[0], "ativo trocou")
	check(s.move_to_party(s.box[0]), "volta")
	check(not s.move_to_party(s.box[0]), "equipe cheia de novo")
	eq(s.dex["folhito"]["caught"], 7, "bestiário conta")


func test_cannot_release_last() -> void:
	var s := fresh()
	s.add_monster(MonsterLogic.create("folhito", 3, rng()))
	check(not s.release_monster(s.party[0]), "não solta o único")
	s.add_monster(MonsterLogic.create("brasito", 3, rng()))
	check(s.release_monster(s.party[0]), "solta com 2")
	eq(s.monsters.size(), 1, "sobrou 1")


func test_grant_reward() -> void:
	var s := fresh()
	var c := s.coins
	var r := s.grant({"coins": 10, "gems": 5, "items": {"esfera": 3}, "monster": ["lumeflor", 8, true]}, rng())
	eq(s.coins, c + 10, "moedas")
	eq(s.inv.count("esfera"), 3, "itens")
	eq(r["monster"], "lumeflor", "eco")
	check(s.get_monster(s.party[0])["variant"], "variante")


func test_map_unlock_rules() -> void:
	var s := fresh()
	check(s.map_unlocked("m2") and s.map_unlocked("m3"), "3 mapas iniciais")
	check(not s.map_unlocked("m4"), "cidade trancada")
	s.flags["bridge_built"] = true
	check(s.map_unlocked("m4"), "ponte libera")
	check(not s.map_unlocked("m5"), "ato 2 trancado")
	s.flags["city1_free"] = true
	check(s.map_unlocked("m5") and s.map_unlocked("m7"), "ato 2")
	check(not s.map_unlocked("m8"), "cidade 2 trancada")


func test_sandbox_mode() -> void:
	var s := fresh("sandbox")
	check(s.is_sandbox(), "sandbox")
	check(s.inv.infinite, "infinito")
	check(s.map_unlocked("m8"), "tudo liberado")
	check(QuestLogic.current(s).is_empty(), "sem missões")


func test_save_roundtrip() -> void:
	var s := fresh()
	s.add_monster(MonsterLogic.create("brasito", 7, rng()))
	s.inv.add("madeira", 33)
	s.flags["bridge_built"] = true
	s.pos = Vector3(1, 2, 3)
	s.quest_idx = 4
	s.inv.add("pedra", 10)
	s.inv.add("madeira", 10)
	BuildLogic.place(s, "fogueira", "m1", Vector2i(2, 3), 0, 4.0, {}, 0)
	check(SaveSystem.save(s, "t1"), "salvou")
	var l := SaveSystem.load_state("t1")
	check(l != null, "carregou")
	eq(l.inv.count("madeira"), s.inv.count("madeira"), "inventário")
	eq(l.monsters.size(), 1, "eco")
	eq(l.get_monster(l.party[0])["lvl"], 7, "nível do eco como int")
	check(typeof(l.get_monster(l.party[0])["lvl"]) == TYPE_INT, "tipo int")
	check(l.flags["bridge_built"], "flag")
	eq(l.pos, Vector3(1, 2, 3), "posição")
	eq(l.quest_idx, 4, "missão")
	eq(l.buildings.size(), 1, "construção")
	SaveSystem.delete("t1")
	check(not SaveSystem.exists("t1"), "apagou")


func test_save_backup_recovers_corruption() -> void:
	var s := fresh()
	s.coins = 777
	SaveSystem.save(s, "t2")
	s.coins = 888
	SaveSystem.save(s, "t2")  # o anterior vira .bak
	var f := FileAccess.open(SaveSystem.path_for("t2"), FileAccess.WRITE)
	f.store_string("{corrompido")
	f.close()
	var l := SaveSystem.load_state("t2")
	check(l != null, "recuperou do backup")
	eq(l.coins, 777, "valor do backup")
	SaveSystem.delete("t2")


func test_night_detection() -> void:
	var s := fresh()
	s.day_time = 0.5
	check(not s.is_night(), "meio-dia")
	s.day_time = 0.9
	check(s.is_night(), "noite")


func test_monster_rest_recovery() -> void:
	var s := fresh()
	s.add_monster(MonsterLogic.create("folhito", 5, rng()))
	var m := s.active_monster()
	m["fainted"] = true
	m["hp"] = 0
	m["faint_until"] = 100
	s.tick_monster_rest(50)
	check(m["fainted"], "ainda descansando")
	s.tick_monster_rest(100)
	check(not m["fainted"] and m["hp"] > 0, "recuperou")
