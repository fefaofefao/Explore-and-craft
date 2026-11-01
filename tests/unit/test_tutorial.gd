extends TestCase


func test_order_and_completion() -> void:
	var s := fresh()
	eq(TutorialLogic.current(s), "partner", "começa pelo parceiro")
	s.flags["starter_chosen"] = true
	eq(TutorialLogic.current(s), "gather", "depois coleta")
	s.stats["gathered"]["madeira"] = 2
	eq(TutorialLogic.current(s), "fight", "construção só depois da missão de construir")
	s.quest_idx = GameData.db().quest_index("q04")
	eq(TutorialLogic.current(s), "build", "construção quando a missão chega")
	s.buildings.append({"uid": 1, "id": "bancada", "map": "m1", "cell": [0, 0], "y": 0, "rot": 0, "data": {}})
	eq(TutorialLogic.current(s), "fight", "luta")
	s.stats["defeats"] = 1
	eq(TutorialLogic.current(s), "", "tutorial completo")


func test_newly_completed_once() -> void:
	var s := fresh()
	s.flags["starter_chosen"] = true
	eq(TutorialLogic.newly_completed(s), ["partner"], "celebra parceiro")
	eq(TutorialLogic.newly_completed(s).size(), 0, "não repete")
	var l := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	eq(TutorialLogic.newly_completed(l).size(), 0, "salvo no save")


func test_sandbox_has_no_tutorial() -> void:
	eq(TutorialLogic.current(fresh("sandbox")), "", "sem tutorial no sandbox")


func test_capture_counts_as_fight() -> void:
	var s := fresh()
	s.flags["starter_chosen"] = true
	s.stats["captures"] = 1
	check(TutorialLogic.is_done(s, "fight"), "captura também ensina a lutar")
