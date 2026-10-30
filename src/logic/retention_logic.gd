class_name RetentionLogic
extends RefCounted
## Presente diário (calendário de 7 dias), missões diárias, Trilha (passe de temporada) e marcos do Bestiário.

static var tz_offset_sec: int = 0  # preenchido pelo jogo com o fuso do aparelho


static func date_key(now: int) -> String:
	return Time.get_date_string_from_unix_time(now + tz_offset_sec)


static func seconds_to_next_day(now: int) -> int:
	var local := now + tz_offset_sec
	return 86400 - (local % 86400)


# ------------------------------------------------------------ presente diário
static func login_available(state: GameState, now: int) -> bool:
	return state.login.get("claimed_date", "") != date_key(now)


static func login_day_index(state: GameState) -> int:
	return int(state.login.get("day", 0)) % GameData.db().daily_login.size()


static func claim_login(state: GameState, now: int, doubled: bool = false) -> Dictionary:
	if not login_available(state, now):
		return {}
	var rewards: Array = GameData.db().daily_login
	var idx := login_day_index(state)
	var r: Dictionary = rewards[idx].duplicate(true)
	if doubled:
		r = double_reward(r)
	var got := state.grant(r, null, now)
	state.login["claimed_date"] = date_key(now)
	state.login["day"] = (idx + 1) % rewards.size()
	state.login["last_date"] = date_key(now)
	return got


static func double_reward(r: Dictionary) -> Dictionary:
	var out := r.duplicate(true)
	for k in ["coins", "gems"]:
		if out.has(k):
			out[k] = int(out[k]) * 2
	if out.has("items"):
		for k in out["items"]:
			out["items"][k] = int(out["items"][k]) * 2
	return out


# ------------------------------------------------------------ missões diárias
static func ensure_daily(state: GameState, now: int) -> bool:
	## Sorteia 3 missões diárias quando o dia muda. Devolve true se renovou.
	var key := date_key(now)
	if state.daily.get("date", "") == key:
		return false
	var pool: Array = GameData.db().daily_quests
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key + str(state.created_at))
	var ids: Array = []
	for q in pool:
		ids.append(q["id"])
	# missões que dependem de recursos ainda não liberados ficam de fora no começo
	if state.count_buildings("horta") + state.count_buildings("serraria") + state.count_buildings("pedreira") == 0:
		ids.erase("dq_collect")
	if state.flags.get("city1_free", false) == false:
		ids.erase("dq_expedition")
	var chosen: Array = []
	while chosen.size() < 3 and ids.size() > 0:
		var i := rng.randi_range(0, ids.size() - 1)
		chosen.append({"id": ids[i], "p": 0, "claimed": false})
		ids.remove_at(i)
	state.daily = {"date": key, "quests": chosen, "all_claimed": false}
	return true


static func daily_def(id: String) -> Dictionary:
	for q in GameData.db().daily_quests:
		if q["id"] == id:
			return q
	return {}


static func on_event(state: GameState, ev: String, target: String = "", n: int = 1) -> Array:
	## Registra um evento de jogo nas diárias. Devolve ids que acabaram de completar.
	var completed: Array = []
	for dq in state.daily.get("quests", []):
		var d := daily_def(dq["id"])
		if d.is_empty() or d["type"] != ev:
			continue
		if d["target"] != null and str(d["target"]) != target:
			continue
		var before := int(dq["p"])
		dq["p"] = min(int(d["count"]), before + n)
		if before < int(d["count"]) and int(dq["p"]) >= int(d["count"]):
			completed.append(dq["id"])
	return completed


static func claim_daily(state: GameState, id: String, now: int = 0) -> Dictionary:
	for dq in state.daily.get("quests", []):
		if dq["id"] != id or dq["claimed"]:
			continue
		var d := daily_def(id)
		if int(dq["p"]) < int(d["count"]):
			return {}
		dq["claimed"] = true
		return state.grant(GameData.db().daily_quest_reward, null, now)
	return {}


static func all_daily_claimed(state: GameState) -> bool:
	var qs: Array = state.daily.get("quests", [])
	if qs.is_empty():
		return false
	for dq in qs:
		if not dq["claimed"]:
			return false
	return true


static func claim_all_bonus(state: GameState, now: int = 0) -> Dictionary:
	if state.daily.get("all_claimed", false) or not all_daily_claimed(state):
		return {}
	state.daily["all_claimed"] = true
	return state.grant(GameData.db().daily_all_bonus, null, now)


# ------------------------------------------------------------ Trilha (passe)
static func pass_tier(state: GameState) -> int:
	var p: Dictionary = GameData.db().pass_data
	return min(int(p["tiers"]), int(state.pass_state["xp"]) / int(p["xp_per_tier"]))


static func claim_pass(state: GameState, tier: int, premium: bool, now: int = 0) -> Dictionary:
	if tier < 1 or tier > pass_tier(state):
		return {}
	var key := "prem" if premium else "free"
	if premium and not state.pass_state.get("premium", false):
		return {}
	if tier in state.pass_state[key] or float(tier) in state.pass_state[key]:
		return {}
	var list: Array = GameData.db().pass_data["premium" if premium else "free"]
	state.pass_state[key].append(tier)
	return state.grant(list[tier - 1], null, now)


static func pass_claimable(state: GameState) -> int:
	var n := 0
	for t in range(1, pass_tier(state) + 1):
		if not (t in state.pass_state["free"] or float(t) in state.pass_state["free"]):
			n += 1
		if state.pass_state.get("premium", false) and not (t in state.pass_state["prem"] or float(t) in state.pass_state["prem"]):
			n += 1
	return n


# ------------------------------------------------------------ Bestiário
static func dex_claimable(state: GameState) -> Array:
	var out: Array = []
	var ms: Array = GameData.db().dex_milestones
	var caught := state.species_caught_count()
	for i in ms.size():
		if caught >= int(ms[i]["count"]) and not i in state.dex_claimed:
			out.append(i)
	return out


static func claim_dex(state: GameState, idx: int, now: int = 0) -> Dictionary:
	if not idx in dex_claimable(state):
		return {}
	state.dex_claimed.append(idx)
	return state.grant(GameData.db().dex_milestones[idx]["reward"], null, now)


# ------------------------------------------------------------ oferta inicial
static func starter_offer_left(state: GameState, now: int, hours: float = 72.0) -> int:
	if "starter_pack" in state.iap_state.get("purchases", []):
		return 0
	var end := int(state.iap_state.get("first_open", now)) + int(hours * 3600.0)
	return max(0, end - now)
