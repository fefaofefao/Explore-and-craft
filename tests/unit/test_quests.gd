extends TestCase


func test_first_quest_is_starter() -> void:
	var s := fresh()
	eq(QuestLogic.current(s)["id"], "q01", "q01")
	check(not QuestLogic.is_complete(s, QuestLogic.current(s)), "não concluída")
	s.flags["starter_chosen"] = true
	var done := QuestLogic.try_advance(s)
	eq(done.size(), 1, "concluiu 1")
	eq(QuestLogic.current(s)["id"], "q02", "avançou")
	eq(s.inv.count("esfera"), 3, "recompensa")


func test_collect_progress() -> void:
	var s := fresh()
	s.quest_idx = 1
	s.inv.add("madeira", 6)
	s.inv.add("pedra", 2)
	eq(QuestLogic.progress(s, QuestLogic.current(s)), [8, 18], "parcial")
	s.inv.add("pedra", 10)
	s.inv.add("fibra", 6)
	check(QuestLogic.is_complete(s, QuestLogic.current(s)), "completa")


func test_chain_advances_multiple() -> void:
	var s := fresh()
	s.flags["starter_chosen"] = true
	s.inv.add("madeira", 6)
	s.inv.add("pedra", 6)
	s.inv.add("fibra", 6)
	var done := QuestLogic.try_advance(s)
	eq(done.size(), 2, "q01 e q02 de uma vez")


func test_trainer_marker_points_to_next() -> void:
	var s := fresh()
	s.quest_idx = GameData.db().quest_index("q23")
	var m := QuestLogic.marker(s)
	eq(m["map"], "m4", "mapa")
	eq(m["pos"], Vector2(62, 30), "Rasha primeiro")
	s.stats["trainers"].append("rasha")
	eq(QuestLogic.marker(s)["pos"], Vector2(-62, 20), "depois Brutus")


func test_cage_marker() -> void:
	var s := fresh()
	s.quest_idx = GameData.db().quest_index("q22")
	eq(QuestLogic.marker(s)["pos"], Vector2(30, 40), "primeira jaula")
	s.map_state("m4")["cages"].append(0)
	eq(QuestLogic.marker(s)["pos"], Vector2(-34, 36), "segunda jaula")


func test_full_story_simulation() -> void:
	## Simula o cumprimento de cada objetivo da história e verifica que a cadeia termina sem travar.
	var s := fresh()
	var db := GameData.db()
	var guard := 0
	while not QuestLogic.current(s).is_empty() and guard < 100:
		guard += 1
		var q := QuestLogic.current(s)
		var t: Variant = q["target"]
		match q["type"]:
			"starter":
				s.flags["starter_chosen"] = true
			"collect":
				for k in t:
					s.inv.add(k, int(t[k]))
			"craft":
				for k in t:
					s.stats["crafted"][k] = int(t[k])
			"build":
				for k in t:
					s.buildings.append({"uid": 900 + guard, "id": k, "map": "m1", "cell": [guard, 0], "y": 0, "rot": 0, "data": {}})
			"assign":
				s.buildings.append({"uid": 950 + guard, "id": t[0] if t is Array else t.keys()[0], "map": "m1", "cell": [guard, 1], "y": 0, "rot": 0, "data": {"worker": 1}})
			"capture":
				s.stats["captures"] = int(q["count"])
			"boss":
				s.stats["bosses"].append(t)
			"trainer":
				for tid in t:
					s.stats["trainers"].append(tid)
			"flag":
				s.flags[t] = true
			"visit":
				s.map_state(t)["visited"] = true
		var before := s.quest_idx
		QuestLogic.try_advance(s)
		check(s.quest_idx > before, "missão %s não avançou" % q["id"])
		if s.quest_idx == before:
			break
	eq(s.quest_idx, db.quests.size(), "história completa")
	check(s.level >= 18, "XP só das missões já leva a nível alto (%d)" % s.level)


func test_every_quest_has_text() -> void:
	for q in GameData.db().quests:
		check(q["title"]["pt"] != "" and q["desc"]["en"] != "", q["id"])
