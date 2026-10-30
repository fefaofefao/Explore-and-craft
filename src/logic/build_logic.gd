class_name BuildLogic
extends RefCounted
## Grade de construção (células de 2 m). Cada peça ocupa um "encaixe" da célula:
##  floor (fundação) | obj (estações, máquinas, móveis) | edge0..3 (paredes/portas/cercas) | roof


static func slot_for(build_id: String, rot: int) -> String:
	var b: Dictionary = GameData.db().buildings[build_id]
	match b["shape"]:
		"foundation":
			return "floor"
		"wall", "door", "window", "fence":
			return "edge%d" % (posmod(rot, 4))
		"roof":
			return "roof"
	return "obj"


static func cell_of(world_pos: Vector3) -> Vector2i:
	var c := float(GameData.db().cfg("build", "cell", 2.0))
	return Vector2i(int(floor(world_pos.x / c)), int(floor(world_pos.z / c)))


static func cell_center(cell: Vector2i) -> Vector3:
	var c := float(GameData.db().cfg("build", "cell", 2.0))
	return Vector3((cell.x + 0.5) * c, 0.0, (cell.y + 0.5) * c)


static func occupied(state: GameState, map: String, cell: Vector2i, slot: String) -> bool:
	for b in state.buildings:
		if b["map"] != map or int(b["cell"][0]) != cell.x or int(b["cell"][1]) != cell.y:
			continue
		if slot_for(b["id"], int(b["rot"])) == slot:
			return true
	return false


static func has_foundation(state: GameState, map: String, cell: Vector2i) -> bool:
	return occupied(state, map, cell, "floor")


static func check(state: GameState, build_id: String, map: String, cell: Vector2i, rot: int, terrain: Dictionary) -> Dictionary:
	## terrain: {"slope": diferença de altura nos cantos, "water": bool, "blocked": bool (zona protegida)}
	var db := GameData.db()
	if not db.buildings.has(build_id):
		return {"ok": false, "reason": "unknown"}
	var b: Dictionary = db.buildings[build_id]
	if not state.is_sandbox() and state.level < int(b.get("lvl", 1)):
		return {"ok": false, "reason": "level"}
	if terrain.get("blocked", false):
		return {"ok": false, "reason": "blocked"}
	if terrain.get("water", false):
		return {"ok": false, "reason": "water"}
	var slot := slot_for(build_id, rot)
	if occupied(state, map, cell, slot):
		return {"ok": false, "reason": "occupied"}
	var on_found := has_foundation(state, map, cell)
	if not on_found and slot in ["floor", "obj"] and float(terrain.get("slope", 0.0)) > float(db.cfg("build", "max_slope", 1.4)):
		return {"ok": false, "reason": "slope"}
	if state.buildings.size() >= int(db.cfg("build", "max_pieces", 400)):
		return {"ok": false, "reason": "limit"}
	if not state.inv.has_all(b["cost"]):
		return {"ok": false, "reason": "items"}
	return {"ok": true, "reason": ""}


static func place(state: GameState, build_id: String, map: String, cell: Vector2i, rot: int, y: float, terrain: Dictionary, now: int = 0) -> Dictionary:
	var chk := check(state, build_id, map, cell, rot, terrain)
	if not chk["ok"]:
		return chk
	var b: Dictionary = GameData.db().buildings[build_id]
	state.inv.remove_all(b["cost"])
	var data := {}
	if b.has("work"):
		data = {"worker": -1, "stored": {}, "acc": {}, "last": now}
	elif b.get("special", "") == "chest":
		data = {"inv": Inventory.new(20).to_dict()}
	var entry := {"uid": state.next_building_uid, "id": build_id, "map": map, "cell": [cell.x, cell.y], "y": y, "rot": posmod(rot, 4), "data": data}
	state.next_building_uid += 1
	state.buildings.append(entry)
	var built: Dictionary = state.stats["built"]
	built[build_id] = int(built.get(build_id, 0)) + 1
	state.add_player_xp(2)
	if b.get("special", "") == "bed":
		state.spawn_point = {"map": map, "pos": [cell_center(cell).x, y, cell_center(cell).z]}
	return {"ok": true, "reason": "", "entry": entry}


static func base_height(state: GameState, map: String, cell: Vector2i, ground_y: float) -> float:
	## Altura onde a peça repousa: topo da fundação ou o terreno.
	for b in state.buildings:
		if b["map"] == map and int(b["cell"][0]) == cell.x and int(b["cell"][1]) == cell.y and slot_for(b["id"], int(b["rot"])) == "floor":
			return float(b["y"]) + 0.5
	return ground_y


static func demolish(state: GameState, uid: int) -> Dictionary:
	var b := state.get_building(uid)
	if b.is_empty():
		return {"ok": false}
	# não demolir fundação com coisas em cima
	if slot_for(b["id"], int(b["rot"])) == "floor":
		for o in state.buildings:
			if o != b and o["map"] == b["map"] and o["cell"] == b["cell"]:
				return {"ok": false, "reason": "supporting"}
	var w := int(b["data"].get("worker", -1))
	if w >= 0:
		state.unassign_worker(w)
	# devolve metade do custo e o que estiver armazenado
	var refund := float(GameData.db().cfg("build", "refund", 0.5))
	var cost: Dictionary = GameData.db().buildings[b["id"]]["cost"]
	var back := {}
	for k in cost:
		var n := int(floor(int(cost[k]) * refund))
		if n > 0:
			back[k] = n
	for k in b["data"].get("stored", {}):
		back[k] = int(back.get(k, 0)) + int(b["data"]["stored"][k])
	if b["data"].has("inv"):
		for s in b["data"]["inv"]["slots"]:
			if not s.is_empty():
				back[s["id"]] = int(back.get(s["id"], 0)) + int(s["n"])
	state.buildings.erase(b)
	if not state.inv.infinite:
		for k in back:
			state.inv.add(k, back[k])
	return {"ok": true, "refund": back}


static func stations_near(state: GameState, map: String, p: Vector3, radius: float = 6.0) -> Array:
	var out: Array = []
	var db := GameData.db()
	for b in state.buildings:
		if b["map"] != map:
			continue
		var bd: Dictionary = db.buildings[b["id"]]
		if not bd.has("station"):
			continue
		var c := cell_center(Vector2i(int(b["cell"][0]), int(b["cell"][1])))
		if Vector2(c.x, c.z).distance_to(Vector2(p.x, p.z)) <= radius:
			out.append(bd["station"])
	return out
