class_name WorkLogic
extends RefCounted
## Estações de trabalho estilo "pals": aloque um Eco e ele produz recursos, inclusive offline.


static func can_work(m: Dictionary, build_id: String) -> bool:
	var b: Dictionary = GameData.db().buildings[build_id]
	if not b.has("work"):
		return false
	if b["work"] == "any":
		return true
	if MonsterLogic.work_level(m, b["work"]) > 0:
		return true
	return b.has("alt_work") and MonsterLogic.work_level(m, b["alt_work"]) > 0


static func skill_for(m: Dictionary, build_id: String) -> int:
	var b: Dictionary = GameData.db().buildings[build_id]
	var lv := MonsterLogic.work_level(m, b["work"])
	if b.has("alt_work"):
		lv = max(lv, MonsterLogic.work_level(m, b["alt_work"]))
	return lv


static func rate_per_hour(m: Dictionary, build_id: String, mult: float = 1.0) -> float:
	## Unidades base por hora (antes dos pesos de cada saída).
	var db := GameData.db()
	var b: Dictionary = db.buildings[build_id]
	var w: Dictionary = db.config["work"]
	var skill := skill_for(m, build_id)
	if skill <= 0:
		return 0.0
	return float(b["rate"]) * (1.0 + float(w["skill_mult"]) * (skill - 1)) * (1.0 + float(w["level_mult"]) * float(m["lvl"])) \
		* (1.0 + float(w["bond_mult"]) * float(m.get("bond", 0))) * mult


static func assign(state: GameState, building_uid: int, monster_uid: int, now: int) -> Dictionary:
	var b := state.get_building(building_uid)
	var m := state.get_monster(monster_uid)
	if b.is_empty() or m.is_empty():
		return {"ok": false, "reason": "missing"}
	if not can_work(m, b["id"]):
		return {"ok": false, "reason": "skill"}
	if m.get("expedition", false):
		return {"ok": false, "reason": "expedition"}
	# fecha a produção do trabalhador anterior antes de trocar
	tick(state, b, now)
	var prev := int(b["data"].get("worker", -1))
	if prev >= 0:
		state.unassign_worker(prev)
	state.unassign_worker(monster_uid)
	b["data"]["worker"] = monster_uid
	b["data"]["last"] = now
	m["job"] = building_uid
	if state.active_uid == monster_uid:
		state.active_uid = -1
		var nxt := state.first_healthy_in_party()
		state.active_uid = nxt
	return {"ok": true}


static func stored_total(b: Dictionary) -> int:
	var t := 0
	for k in b["data"].get("stored", {}):
		t += int(b["data"]["stored"][k])
	return t


static func tick(state: GameState, b: Dictionary, now: int, mult: float = 1.0) -> Dictionary:
	## Avança a produção até "now". Devolve itens produzidos neste tick.
	var produced := {}
	var data: Dictionary = b["data"]
	if not data.has("worker"):
		return produced
	var last := int(data.get("last", now))
	data["last"] = now
	var w := int(data["worker"])
	if w < 0 or now <= last:
		return produced
	var m := state.get_monster(w)
	if m.is_empty():
		data["worker"] = -1
		return produced
	var cfg: Dictionary = GameData.db().config["work"]
	var elapsed: float = min(float(now - last), float(cfg["offline_cap_hours"]) * 3600.0)
	var units: float = rate_per_hour(m, b["id"], mult) * elapsed / 3600.0
	var cap := int(cfg["station_capacity"])
	var outs: Dictionary = GameData.db().buildings[b["id"]]["output"]
	var acc: Dictionary = data.get("acc", {})
	var stored: Dictionary = data.get("stored", {})
	for k in outs:
		acc[k] = float(acc.get(k, 0.0)) + units * float(outs[k])
		var whole := int(floor(acc[k]))
		if whole > 0:
			var room: int = cap - stored_total(b)
			var put: int = clampi(whole, 0, max(room, 0))
			acc[k] = float(acc[k]) - whole  # o excedente é perdido quando o armazém está cheio
			if put > 0:
				stored[k] = int(stored.get(k, 0)) + put
				produced[k] = put
	data["acc"] = acc
	data["stored"] = stored
	return produced


static func tick_all(state: GameState, now: int, mult: float = 1.0) -> Dictionary:
	var total := {}
	for b in state.buildings:
		var p := tick(state, b, now, mult)
		for k in p:
			total[k] = int(total.get(k, 0)) + p[k]
	return total


static func collect(state: GameState, b: Dictionary) -> Dictionary:
	var got := {}
	var stored: Dictionary = b["data"].get("stored", {})
	for k in stored.keys():
		var n := int(stored[k])
		var left := state.inv.add(k, n)
		if n - left > 0:
			got[k] = n - left
		if left > 0:
			stored[k] = left
		else:
			stored.erase(k)
	var total := 0
	for k in got:
		total += got[k]
	state.stats["harvested"] = int(state.stats.get("harvested", 0)) + total
	return got


static func offline_preview(state: GameState, now: int, mult: float = 1.0) -> Dictionary:
	## Simula a produção offline sem alterar o estado (para o resumo "Enquanto você estava fora").
	var copy := GameState.from_dict(state.to_dict())
	return tick_all(copy, now, mult)
