class_name CraftLogic
extends RefCounted
## Receitas: requisitos de nível, estação por perto e materiais.


static func recipe_unlocked(state: GameState, rid: String) -> bool:
	var r: Dictionary = GameData.db().recipes[rid]
	return state.is_sandbox() or state.level >= int(r.get("lvl", 1))


static func check(state: GameState, rid: String, stations_near: Array, times: int = 1) -> Dictionary:
	## {"ok": bool, "reason": "level|station|items|space|"}
	var db := GameData.db()
	if not db.recipes.has(rid):
		return {"ok": false, "reason": "unknown"}
	var r: Dictionary = db.recipes[rid]
	if not recipe_unlocked(state, rid):
		return {"ok": false, "reason": "level"}
	var st: String = r["station"]
	if st != "mao" and not state.is_sandbox() and not st in stations_near:
		return {"ok": false, "reason": "station"}
	if is_unique_gear(r["out"]) and not state.inv.infinite:
		if state.inv.count(r["out"]) > 0:
			return {"ok": false, "reason": "owned"}
		if times > 1:
			return {"ok": false, "reason": "owned"}
	var req := scaled(r["in"], times)
	if not state.inv.has_all(req):
		return {"ok": false, "reason": "items"}
	if state.inv.space_for(r["out"]) < int(r["n"]) * times and not state.inv.infinite:
		# a saída pode ocupar o espaço liberado pelos ingredientes; aproximação conservadora
		var freed := 0
		for k in req:
			if state.inv.count(k) == int(req[k]):
				freed += 1
		if freed == 0:
			return {"ok": false, "reason": "space"}
	return {"ok": true, "reason": ""}


static func scaled(req: Dictionary, times: int) -> Dictionary:
	var out := {}
	for k in req:
		out[k] = int(req[k]) * times
	return out


static func is_unique_gear(item_id: String) -> bool:
	## Ferramentas, armas e equipamentos: um de cada por vez (usa até quebrar).
	var it: Dictionary = GameData.db().item(item_id)
	return int(it.get("stack", 99)) == 1 and (it.has("tool") or it.has("weapon") or it.has("gear"))


static func max_times(state: GameState, rid: String) -> int:
	var r: Dictionary = GameData.db().recipes[rid]
	if state.inv.infinite:
		return 10
	if is_unique_gear(r["out"]):
		return 0 if state.inv.count(r["out"]) > 0 else 1
	var best := 999
	for k in r["in"]:
		best = min(best, state.inv.count(k) / int(r["in"][k]))
	return best


static func craft(state: GameState, rid: String, stations_near: Array, times: int = 1) -> Dictionary:
	var chk := check(state, rid, stations_near, times)
	if not chk["ok"]:
		return chk
	var r: Dictionary = GameData.db().recipes[rid]
	state.inv.remove_all(scaled(r["in"], times))
	var n: int = int(r["n"]) * times
	var left := state.inv.add(r["out"], n)
	var crafted: Dictionary = state.stats["crafted"]
	crafted[r["out"]] = int(crafted.get(r["out"], 0)) + n
	state.add_player_xp(3 * times)
	return {"ok": true, "reason": "", "out": r["out"], "n": n, "overflow": left}


static func recipes_for(station: String) -> Array:
	var out: Array = []
	var db := GameData.db()
	for rid in db.recipes:
		if station == "" or db.recipes[rid]["station"] == station:
			out.append(rid)
	out.sort_custom(func(a, b): return int(db.recipes[a]["lvl"]) < int(db.recipes[b]["lvl"]))
	return out


static func recipes_unlocked_at(level: int) -> Array:
	var out: Array = []
	var db := GameData.db()
	for rid in db.recipes:
		if int(db.recipes[rid]["lvl"]) == level:
			out.append(rid)
	return out


# ------------------------------------------------------------------ reparo
static func recipe_of(item_id: String) -> String:
	for rid in GameData.db().recipes:
		if GameData.db().recipes[rid]["out"] == item_id:
			return rid
	return ""


static func repair_cost(state: GameState, item_id: String) -> Dictionary:
	## Metade dos materiais da receita, proporcional ao desgaste (mínimo 1 material).
	var mx := Inventory.max_dur(item_id)
	var rid := recipe_of(item_id)
	if mx <= 0 or rid == "":
		return {}
	var cur := state.inv.durability_of(item_id)
	var missing := clampf(1.0 - float(cur) / mx, 0.0, 1.0)
	var out := {}
	if missing <= 0.0:
		return out
	var req: Dictionary = GameData.db().recipes[rid]["in"]
	for k in req:
		var n := int(ceil(int(req[k]) * missing * 0.5))
		if n > 0:
			out[k] = n
	if out.is_empty():
		out[req.keys()[0]] = 1
	return out


static func can_repair(state: GameState, item_id: String) -> Dictionary:
	if state.inv.count(item_id) <= 0:
		return {"ok": false, "reason": "no_item", "cost": {}}
	var mx := Inventory.max_dur(item_id)
	if mx <= 0 or recipe_of(item_id) == "":
		return {"ok": false, "reason": "no_repair", "cost": {}}
	if state.inv.durability_of(item_id) >= mx:
		return {"ok": false, "reason": "full", "cost": {}}
	var cost := repair_cost(state, item_id)
	if not state.inv.infinite and not state.inv.has_all(cost):
		return {"ok": false, "reason": "missing", "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


static func repair(state: GameState, item_id: String) -> Dictionary:
	## Restaura a durabilidade toda gastando os materiais do reparo.
	var chk := can_repair(state, item_id)
	if not chk["ok"]:
		return chk
	if not state.inv.infinite:
		state.inv.remove_all(chk["cost"])
	state.inv.set_durability(item_id, Inventory.max_dur(item_id))
	state.stats["repairs"] = int(state.stats.get("repairs", 0)) + 1
	return chk
