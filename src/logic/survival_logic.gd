class_name SurvivalLogic
extends RefCounted
## Fome, regeneração, perigos ambientais e ciclo dia/noite (modo fácil: fome nunca mata).


static func tick(state: GameState, dt: float, hazard: Variant) -> Dictionary:
	var p: Dictionary = GameData.db().config["player"]
	var ev := {"hazard_dmg": 0.0, "starving": false}
	if state.is_sandbox():
		state.hunger = float(p["hunger_max"])
		state.hp = min(state.max_hp(), state.hp + 5.0 * dt)
		return ev
	state.hunger = max(0.0, state.hunger - float(p["hunger_drain_per_min"]) * dt / 60.0)
	if state.hunger <= 0.0:
		ev["starving"] = true
		if state.hp > float(p["starve_min_hp"]):
			state.hp = max(float(p["starve_min_hp"]), state.hp - float(p["starve_dps"]) * dt)
	elif state.hunger >= float(p["fed_threshold"]):
		state.hp = min(state.max_hp(), state.hp + float(p["regen_per_sec_fed"]) * dt)
	if hazard != null and hazard is Dictionary and not state.inv.has_protection(hazard["kind"]):
		var d: float = float(hazard["dps"]) * dt
		state.hp = max(0.0, state.hp - d)
		ev["hazard_dmg"] = d
	return ev


static func eat(state: GameState, item_id: String) -> bool:
	var f: Dictionary = GameData.db().item(item_id).get("food", {})
	if f.is_empty() or not state.inv.has(item_id):
		return false
	state.inv.remove(item_id, 1)
	var p: Dictionary = GameData.db().config["player"]
	state.hunger = clampf(state.hunger + float(f["hunger"]), 0.0, float(p["hunger_max"]))
	state.hp = clampf(state.hp + float(f["hp"]), 1.0, state.max_hp())
	return true


static func advance_time(state: GameState, dt: float) -> bool:
	## Avança o relógio do mundo. Devolve true quando um novo dia começa.
	var c: Dictionary = GameData.db().config["world"]
	var day_len: float = float(c["day_seconds"]) + float(c["night_seconds"])
	var before := state.day_time
	state.day_time = fmod(state.day_time + dt / day_len, 1.0)
	if state.day_time < before:
		state.day_count += 1
		return true
	return false


static func sleep(state: GameState) -> bool:
	if not state.is_night():
		return false
	if state.day_time > 0.5:
		state.day_count += 1
	state.day_time = 0.25
	state.hp = state.max_hp()
	return true


static func sun_factor(day_time: float) -> float:
	## 0 = noite plena, 1 = meio-dia
	return clampf(sin((day_time - 0.25) * TAU) * 1.4 + 0.25, 0.0, 1.0)
