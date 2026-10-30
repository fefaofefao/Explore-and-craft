class_name Inventory
extends RefCounted
## Mochila em slots com empilhamento por item (limite "stack" do item).

signal changed

var slots: Array = []  # cada slot: {} vazio ou {"id": String, "n": int}
var infinite: bool = false  # modo sandbox: nunca consome


func _init(capacity: int = 40) -> void:
	resize(capacity)


func resize(capacity: int) -> void:
	while slots.size() < capacity:
		slots.append({})


func capacity() -> int:
	return slots.size()


static func stack_of(id: String) -> int:
	return int(GameData.db().item(id).get("stack", 99))


func count(id: String) -> int:
	var c := 0
	for s in slots:
		if not s.is_empty() and s["id"] == id:
			c += int(s["n"])
	return c


func has(id: String, n: int = 1) -> bool:
	return infinite or count(id) >= n


func has_all(req: Dictionary) -> bool:
	for k in req:
		if not has(k, int(req[k])):
			return false
	return true


func space_for(id: String) -> int:
	## Quantas unidades de id ainda cabem.
	var st := stack_of(id)
	var free := 0
	for s in slots:
		if s.is_empty():
			free += st
		elif s["id"] == id:
			free += st - int(s["n"])
	return free


func add(id: String, n: int = 1) -> int:
	## Adiciona e devolve a quantidade que NÃO coube.
	if n <= 0 or not GameData.db().items.has(id):
		return n
	var st := stack_of(id)
	var left := n
	for s in slots:
		if left <= 0:
			break
		if not s.is_empty() and s["id"] == id and int(s["n"]) < st:
			var put: int = min(st - int(s["n"]), left)
			s["n"] = int(s["n"]) + put
			left -= put
	for i in slots.size():
		if left <= 0:
			break
		if slots[i].is_empty():
			var put: int = min(st, left)
			slots[i] = {"id": id, "n": put}
			left -= put
	if left != n:
		changed.emit()
	return left


func remove(id: String, n: int = 1) -> bool:
	if infinite:
		return true
	if count(id) < n:
		return false
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		var s: Dictionary = slots[i]
		if left <= 0:
			break
		if not s.is_empty() and s["id"] == id:
			var take: int = min(int(s["n"]), left)
			s["n"] = int(s["n"]) - take
			left -= take
			if int(s["n"]) <= 0:
				slots[i] = {}
	changed.emit()
	return true


func remove_all(req: Dictionary) -> bool:
	if not has_all(req):
		return false
	for k in req:
		remove(k, int(req[k]))
	return true


func best_tool(kind: String) -> Dictionary:
	## Melhor ferramenta do tipo na mochila (uso automático). {} se nenhuma.
	var best := {}
	var best_tier := -1
	for s in slots:
		if s.is_empty():
			continue
		var it: Dictionary = GameData.db().item(s["id"])
		var tl: Dictionary = it.get("tool", {})
		if not tl.is_empty() and tl["kind"] == kind and int(tl["tier"]) > best_tier:
			best_tier = int(tl["tier"])
			best = {"id": s["id"], "tier": int(tl["tier"]), "power": float(tl["power"])}
	return best


func best_weapon_dmg() -> int:
	var best := 0
	for s in slots:
		if s.is_empty():
			continue
		var w: Dictionary = GameData.db().item(s["id"]).get("weapon", {})
		if not w.is_empty():
			best = max(best, int(w["dmg"]))
	return best


func best_weapon_id() -> String:
	var best := 0
	var id := ""
	for s in slots:
		if s.is_empty():
			continue
		var w: Dictionary = GameData.db().item(s["id"]).get("weapon", {})
		if not w.is_empty() and int(w["dmg"]) > best:
			best = int(w["dmg"])
			id = s["id"]
	return id


func has_protection(kind: String) -> bool:
	for s in slots:
		if s.is_empty():
			continue
		var g: Dictionary = GameData.db().item(s["id"]).get("gear", {})
		if g.get("protect", "") == kind:
			return true
	return false


func sort_slots() -> void:
	var cats := ["chave", "ferramenta", "arma", "equipamento", "esfera", "cuidado", "comida", "material", "recurso"]
	var filled: Array = []
	for s in slots:
		if not s.is_empty():
			filled.append(s)
	filled.sort_custom(func(a, b):
		var ca: int = cats.find(GameData.db().item(a["id"]).get("cat", "recurso"))
		var cb: int = cats.find(GameData.db().item(b["id"]).get("cat", "recurso"))
		if ca != cb:
			return ca < cb
		if a["id"] != b["id"]:
			return a["id"] < b["id"]
		return int(a["n"]) > int(b["n"]))
	# junta pilhas incompletas
	var merged: Array = []
	for s in filled:
		var st := stack_of(s["id"])
		var n := int(s["n"])
		for m in merged:
			if n <= 0:
				break
			if m["id"] == s["id"] and int(m["n"]) < st:
				var put: int = min(st - int(m["n"]), n)
				m["n"] = int(m["n"]) + put
				n -= put
		if n > 0:
			merged.append({"id": s["id"], "n": n})
	for i in slots.size():
		slots[i] = merged[i] if i < merged.size() else {}
	changed.emit()


func to_dict() -> Dictionary:
	var arr: Array = []
	for s in slots:
		arr.append(s.duplicate())
	return {"slots": arr}


func from_dict(d: Dictionary) -> void:
	slots = []
	for s in d.get("slots", []):
		if s is Dictionary and not s.is_empty() and GameData.db().items.has(s.get("id", "")):
			slots.append({"id": s["id"], "n": int(s["n"])})
		else:
			slots.append({})
	changed.emit()
