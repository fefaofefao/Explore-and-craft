class_name CombatLogic
extends RefCounted
## Fórmulas de dano (inspiradas em RPGs de monstros clássicos) e captura.


static func damage(lvl: int, power: float, atk: float, def: float, skill_type: String, attacker_types: Array,
		defender_types: Array, rng: RandomNumberGenerator, bonus: float = 0.0) -> Dictionary:
	var c: Dictionary = GameData.db().config["combat"]
	var stab := float(c["stab"]) if skill_type in attacker_types else 1.0
	var tm := MonsterLogic.type_mult(skill_type, defender_types) if skill_type != "" else 1.0
	var crit := rng.randf() < float(c["crit_chance"])
	var base: float = ((2.0 * lvl / 5.0 + 2.0) * power * atk / max(def, 1.0)) / 50.0 + 2.0
	var dmg: float = base * stab * tm * rng.randf_range(0.85, 1.0) * (1.0 + bonus)
	if crit:
		dmg *= float(c["crit_mult"])
	return {"dmg": max(1, int(round(dmg))), "mult": tm, "crit": crit}


static func player_damage(player_lvl: int, weapon_dmg: int) -> int:
	var c: Dictionary = GameData.db().config
	return int(round((float(c["player"]["attack_base"]) + weapon_dmg + player_lvl * 0.5) * float(c["combat"]["player_vs_monster_mult"])))


static func player_defense(player_lvl: int) -> float:
	return 12.0 + player_lvl * 2.0


static func damage_to_player(monster_lvl: int, monster_atk: float, player_lvl: int, power: float, rng: RandomNumberGenerator) -> int:
	## O treinador é frágil de propósito: um Eco do mesmo nível derruba o jogador em ~4 golpes básicos
	## (habilidades fortes em ~3). Isso incentiva deixar a luta para os Ecos e ter cautela.
	var c: Dictionary = GameData.db().config["combat"]
	var p: Dictionary = GameData.db().config["player"]
	var max_hp := float(p["base_hp"]) + float(p["hp_per_level"]) * (player_lvl - 1)
	var lvl_ratio := clampf(float(monster_lvl) / maxf(1.0, float(player_lvl)), 0.5, 2.0)
	var pow_ratio := sqrt(maxf(power, 10.0) / float(c["basic_power"]))
	var frac := float(c.get("player_hit_frac", 0.25)) * lvl_ratio * pow_ratio
	return max(1, int(round(max_hp * frac * rng.randf_range(0.9, 1.1))))


static func capture_chance(species_id: String, lvl: int, hp_frac: float, orb_mult: float, player_lvl: int, collared: bool = false) -> float:
	var db := GameData.db()
	var c: Dictionary = db.config["capture"]
	var sp: Dictionary = db.sp(species_id)
	var rate := float(sp.get("capture", 0.3))
	var hp_term: float = 1.0 - float(c["hp_weight"]) * clampf(hp_frac, 0.0, 1.0)
	var lvl_term: float = clampf(1.0 - (lvl - player_lvl) * float(c["level_penalty"]), 0.4, 1.3)
	var chance: float = rate * orb_mult * hp_term * lvl_term
	if sp.get("boss", false):
		chance *= float(c["boss_mult"])
	if collared:
		chance *= float(c["collar_bonus"])
	return clampf(chance, float(c["min_chance"]), float(c["max_chance"]))


static func roll_variant(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < float(GameData.db().cfg("capture", "aurora_variant_chance", 0.0025))


static func skill_damage_power(skill_id: String) -> float:
	return float(GameData.db().skills.get(skill_id, {}).get("power", 0))


static func best_skill_vs(skills: Array, defender_types: Array, ready: Callable) -> String:
	## IA: escolhe a habilidade pronta com maior poder efetivo contra o alvo.
	var best := ""
	var best_val := 0.0
	for s in skills:
		if not ready.call(s):
			continue
		var sk: Dictionary = GameData.db().skills[s]
		if sk["kind"] in ["heal", "buff"]:
			continue
		var val: float = float(sk["power"]) * MonsterLogic.type_mult(sk["type"], defender_types)
		if val > best_val:
			best_val = val
			best = s
	return best
