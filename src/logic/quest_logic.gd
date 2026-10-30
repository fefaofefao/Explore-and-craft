class_name QuestLogic
extends RefCounted
## Missões lineares da história. O progresso é derivado do estado (robusto a saves antigos).


static func current(state: GameState) -> Dictionary:
	var qs: Array = GameData.db().quests
	if state.quest_idx < 0 or state.quest_idx >= qs.size():
		return {}
	return qs[state.quest_idx]


static func progress(state: GameState, q: Dictionary) -> Array:
	## [atual, alvo]
	var t: Variant = q.get("target")
	match q["type"]:
		"starter":
			return [1 if state.flags.get("starter_chosen", false) else 0, 1]
		"collect":
			return _sum_min(t, func(k): return state.inv.count(k))
		"craft":
			return _sum_min(t, func(k): return int(state.stats["crafted"].get(k, 0)))
		"build":
			return _sum_min(t, func(k): return state.count_buildings(k))
		"assign":
			var c := 0
			for b in state.buildings:
				if b["id"] in t and int(b["data"].get("worker", -1)) >= 0:
					c = 1
			return [c, 1]
		"capture":
			return [min(int(state.stats["captures"]), int(q["count"])), int(q["count"])]
		"boss":
			return [1 if t in state.stats["bosses"] else 0, 1]
		"trainer":
			var n := 0
			for tid in t:
				if tid in state.stats["trainers"]:
					n += 1
			return [n, t.size()]
		"flag":
			return [1 if state.flags.get(t, false) else 0, 1]
		"visit":
			return [1 if state.map_state(t).get("visited", false) else 0, 1]
		"level":
			return [min(state.level, int(t)), int(t)]
		"talk":
			return [1 if state.flags.get("talk_" + str(t), false) else 0, 1]
	return [0, 1]


static func _sum_min(target: Dictionary, getter: Callable) -> Array:
	var cur := 0
	var tot := 0
	for k in target:
		var need := int(target[k])
		cur += min(int(getter.call(k)), need)
		tot += need
	return [cur, tot]


static func is_complete(state: GameState, q: Dictionary) -> bool:
	if q.is_empty():
		return false
	var p := progress(state, q)
	return p[0] >= p[1]


static func try_advance(state: GameState, now: int = 0) -> Array:
	## Conclui em cadeia as missões já satisfeitas. Devolve lista de {"quest", "reward"} concluídas.
	var done: Array = []
	var guard := 0
	while guard < 50:
		guard += 1
		var q := current(state)
		if q.is_empty() or not is_complete(state, q):
			break
		var r := state.grant(q.get("reward", {}), null, now)
		done.append({"quest": q, "reward": r})
		state.quest_idx += 1
		state.quest_seen_dialog = false
	return done


static func marker(state: GameState) -> Dictionary:
	## Para a bússola: {"map", "pos": Vector2} ou {} se a missão não tem local.
	var q := current(state)
	if q.is_empty():
		return {}
	var m: Variant = q.get("marker")
	if m == null:
		return {}
	var target_pos := Vector2(m["pos"][0], m["pos"][1])
	# missão de treinadores: aponta para o próximo ainda não derrotado
	if q["type"] == "trainer":
		for tid in q["target"]:
			if not tid in state.stats["trainers"]:
				var tr: Dictionary = GameData.db().trainers[tid]
				return {"map": tr["map"], "pos": Vector2(tr["pos"][0], tr["pos"][1])}
	# jaulas: aponta para a próxima fechada
	if q["type"] == "flag" and str(q["target"]).begins_with("cages"):
		var md: Dictionary = GameData.db().maps[m["map"]]
		var opened: Array = state.map_state(m["map"]).get("cages", [])
		var cages: Array = md["city"]["cages"]
		for i in cages.size():
			if not float(i) in opened and not i in opened:
				return {"map": m["map"], "pos": Vector2(cages[i][0], cages[i][1])}
	return {"map": m["map"], "pos": target_pos}
