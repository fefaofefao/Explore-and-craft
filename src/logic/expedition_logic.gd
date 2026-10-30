class_name ExpeditionLogic
extends RefCounted
## Expedições: Ecos da reserva exploram mapas já liberados e voltam com recursos (loop idle de retenção).


static func durations() -> Array:
	return GameData.db().config["expedition"]["durations"]


static func used_slots(state: GameState) -> Array:
	var out: Array = []
	for e in state.expeditions:
		out.append(int(e["slot"]))
	return out


static func free_slot(state: GameState) -> int:
	var used := used_slots(state)
	for i in state.expedition_slots:
		if not i in used:
			return i
	return -1


static func start(state: GameState, uid: int, dur_idx: int, map: String, now: int) -> Dictionary:
	var m := state.get_monster(uid)
	if m.is_empty() or m.get("expedition", false) or m.get("fainted", false):
		return {"ok": false, "reason": "monster"}
	if not uid in state.box:
		return {"ok": false, "reason": "not_in_box"}
	if int(m.get("job", -1)) >= 0:
		return {"ok": false, "reason": "working"}
	var slot := free_slot(state)
	if slot < 0:
		return {"ok": false, "reason": "slots"}
	if dur_idx < 0 or dur_idx >= durations().size():
		return {"ok": false, "reason": "dur"}
	if not state.map_unlocked(map):
		return {"ok": false, "reason": "map"}
	m["expedition"] = true
	state.expeditions.append({"slot": slot, "uid": uid, "start": now, "dur": int(durations()[dur_idx]), "idx": dur_idx, "map": map})
	return {"ok": true, "slot": slot}


static func time_left(e: Dictionary, now: int) -> int:
	return max(0, int(e["start"]) + int(e["dur"]) - now)


static func rush(e: Dictionary, now: int) -> void:
	e["start"] = now - int(e["dur"])


static func loot_pool(map: String) -> Array:
	var md: Dictionary = GameData.db().maps[map]
	var pool: Array = []
	for n in md["trees"].keys() + md["nodes"].keys():
		var nd: Dictionary = GameData.db().nodes[n]
		for it in nd["drops"]:
			if not it in pool:
				pool.append(it)
	return pool


static func complete(state: GameState, slot: int, now: int, rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = {}
	for x in state.expeditions:
		if int(x["slot"]) == slot:
			e = x
	if e.is_empty() or time_left(e, now) > 0:
		return {}
	var cfg: Dictionary = GameData.db().config["expedition"]
	var idx := int(e.get("idx", 0))
	var m := state.get_monster(int(e["uid"]))
	var rolls := int(cfg["base_rolls"][idx]) + int(m.get("lvl", 1)) / 10
	var pool := loot_pool(e["map"])
	var items := {}
	for i in rolls:
		var it: String = pool[rng.randi_range(0, pool.size() - 1)]
		items[it] = int(items.get(it, 0)) + rng.randi_range(1, 3)
	var reward := {"items": items, "coins": 20 * (idx + 1) * rolls / 3}
	if rng.randf() < float(cfg["gem_chance"][idx]):
		reward["gems"] = 3 + idx * 3
	# XP para o Eco expedicionário
	var lv := MonsterLogic.add_xp(m, 40 * (idx + 1) * max(1, int(m.get("lvl", 1)) / 3))
	if lv["evolve"] != "":
		MonsterLogic.evolve(m)
	m["expedition"] = false
	state.expeditions.erase(e)
	state.stats["expeditions"] = int(state.stats.get("expeditions", 0)) + 1
	var got := state.grant(reward, rng, now)
	got["uid"] = int(e["uid"])
	return got
