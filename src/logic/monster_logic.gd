class_name MonsterLogic
extends RefCounted
## Criação de Ecos, atributos, XP, evolução, vínculo e tabela de tipos.


static func type_mult(atk_type: String, def_types: Array) -> float:
	var t: Dictionary = GameData.db().types
	var mult := 1.0
	for dt in def_types:
		if dt in t["strong"].get(atk_type, []):
			mult *= float(t["super"])
		elif atk_type in t["strong"].get(dt, []):
			mult *= float(t["weak"])
	return mult


static func xp_to_next(lvl: int) -> int:
	var c: Dictionary = GameData.db().config["xp"]
	return int(floor(float(c["monster_base"]) * pow(lvl, float(c["monster_exp"])))) + 10


static func create(species_id: String, lvl: int, rng: RandomNumberGenerator, uid: int = 0, variant: bool = false) -> Dictionary:
	var m := {
		"uid": uid, "sp": species_id, "lvl": clampi(lvl, 1, 100), "xp": 0,
		"talent": snappedf(rng.randf(), 0.01), "nick": "", "bond_xp": 0, "bond": 0,
		"variant": variant, "skills": [], "hp": 0, "fainted": false, "faint_until": 0,
		"pet_day": "", "job": -1, "expedition": false,
	}
	m["skills"] = skills_for_level(species_id, m["lvl"])
	m["hp"] = max_hp(m)
	return m


static func skills_for_level(species_id: String, lvl: int) -> Array:
	var ls: Array = GameData.db().sp(species_id).get("learnset", [])
	var out: Array = []
	for e in ls:
		if int(e[0]) <= lvl:
			out.append(e[1])
	# mantém as 4 mais recentes (a última costuma ser a mais forte)
	while out.size() > 4:
		out.pop_front()
	return out


static func base_stat(m: Dictionary, stat: String) -> int:
	return int(GameData.db().sp(m["sp"])["base"][stat])


static func bond_mult(m: Dictionary) -> float:
	return 1.0 + float(m.get("bond", 0)) * float(GameData.db().cfg("bond", "stat_bonus_per_level", 0.02))


static func variant_mult(m: Dictionary) -> float:
	return 1.1 if m.get("variant", false) else 1.0


static func stat(m: Dictionary, s: String) -> int:
	var b := base_stat(m, s)
	var v: float = (b * 2.0 + float(m["talent"]) * 31.0) * float(m["lvl"]) / 100.0 + 5.0
	return int(floor(v * bond_mult(m) * variant_mult(m)))


static func max_hp(m: Dictionary) -> int:
	var b := base_stat(m, "hp")
	var v: float = (b * 2.0 + float(m["talent"]) * 31.0) * float(m["lvl"]) / 100.0 + float(m["lvl"]) + 10.0
	return int(floor(v * bond_mult(m) * variant_mult(m)))


static func types_of(m: Dictionary) -> Array:
	return GameData.db().sp(m["sp"])["types"]


static func display_name(m: Dictionary) -> String:
	if str(m.get("nick", "")) != "":
		return m["nick"]
	return Loc.species_name(m["sp"])


static func power_score(m: Dictionary) -> int:
	return stat(m, "atk") + stat(m, "def") + stat(m, "spd") + max_hp(m) / 2


static func add_xp(m: Dictionary, amount: int) -> Dictionary:
	## Soma XP; devolve eventos {"levels": n, "learned": [...], "evolve": "id" ou ""}.
	var res := {"levels": 0, "learned": [], "evolve": ""}
	if amount <= 0 or int(m["lvl"]) >= 100:
		return res
	m["xp"] = int(m["xp"]) + amount
	var before: Array = m["skills"].duplicate()
	var old_max := max_hp(m)
	while int(m["lvl"]) < 100 and int(m["xp"]) >= xp_to_next(int(m["lvl"])):
		m["xp"] = int(m["xp"]) - xp_to_next(int(m["lvl"]))
		m["lvl"] = int(m["lvl"]) + 1
		res["levels"] += 1
	if res["levels"] > 0:
		m["skills"] = skills_for_level(m["sp"], int(m["lvl"]))
		for s in m["skills"]:
			if not s in before:
				res["learned"].append(s)
		# ganha a diferença de PV máximo
		m["hp"] = min(max_hp(m), int(m["hp"]) + max(0, max_hp(m) - old_max))
		var evo: Variant = GameData.db().sp(m["sp"]).get("evolves")
		if evo != null and int(m["lvl"]) >= int(evo["level"]):
			res["evolve"] = evo["to"]
	return res


static func evolve(m: Dictionary) -> bool:
	var evo: Variant = GameData.db().sp(m["sp"]).get("evolves")
	if evo == null or int(m["lvl"]) < int(evo["level"]):
		return false
	var frac: float = float(m["hp"]) / maxf(1.0, float(max_hp(m)))
	m["sp"] = evo["to"]
	m["skills"] = skills_for_level(m["sp"], int(m["lvl"]))
	m["hp"] = int(round(frac * max_hp(m)))
	return true


static func heal(m: Dictionary, amount: float, revive: bool = false) -> int:
	## amount <= 1.0 é fração do máximo. Devolve PV curados.
	if m.get("fainted", false) and not revive:
		return 0
	var mx := max_hp(m)
	var add := int(round(amount * mx)) if amount <= 1.0 else int(amount)
	var before := int(m["hp"]) if not m.get("fainted", false) else 0
	m["fainted"] = false
	m["hp"] = clampi(before + add, 1, mx)
	return int(m["hp"]) - before


static func full_heal(m: Dictionary) -> void:
	m["fainted"] = false
	m["faint_until"] = 0
	m["hp"] = max_hp(m)


static func add_bond(m: Dictionary, amount: int) -> bool:
	## Devolve true se subiu de nível de vínculo.
	var c: Dictionary = GameData.db().config["bond"]
	if int(m["bond"]) >= int(c["max_level"]):
		return false
	m["bond_xp"] = int(m["bond_xp"]) + amount
	var up := false
	while int(m["bond"]) < int(c["max_level"]) and int(m["bond_xp"]) >= int(c["xp_per_level"]):
		m["bond_xp"] = int(m["bond_xp"]) - int(c["xp_per_level"])
		m["bond"] = int(m["bond"]) + 1
		up = true
	return up


static func work_level(m: Dictionary, work: String) -> int:
	var w: Dictionary = GameData.db().sp(m["sp"]).get("work", {})
	if work == "any":
		var best := 1
		for k in w:
			best = max(best, int(w[k]))
		return best
	return int(w.get(work, 0))


static func kill_xp(defeated: Dictionary) -> int:
	var mult := float(GameData.db().cfg("xp", "kill_xp_mult", 6))
	var base: float = float(defeated["lvl"]) * mult + 5.0
	if GameData.db().sp(defeated["sp"]).get("boss", false):
		base *= 5.0
	return int(base)


static func harmony_bonus(party_types: Array) -> float:
	## Bônus de Harmonia: 3+ tipos diferentes na equipe.
	var c: Dictionary = GameData.db().config["combat"]
	var uniq := {}
	for t in party_types:
		uniq[t] = true
	return float(c["harmony_bonus"]) if uniq.size() >= int(c["harmony_min_types"]) else 0.0


static func skill_slot(skills: Array, idx: int) -> int:
	## Os dois botões do HUD mostram as habilidades mais fortes (as últimas aprendidas).
	var j := maxi(0, skills.size() - 2) + idx
	return j if j < skills.size() else -1
