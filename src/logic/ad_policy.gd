class_name AdPolicy
extends RefCounted
## Regras de frequência de anúncios. Rewarded sempre opcional; intersticial com limites rígidos
## (nunca nos primeiros minutos, nunca para quem comprou "Sem Anúncios"/pagou, intervalo mínimo e teto diário).


static func _roll_day(state: GameState, now: int) -> void:
	var key := RetentionLogic.date_key(now)
	if state.ads_state.get("date", "") != key:
		state.ads_state["date"] = key
		state.ads_state["inter_today"] = 0
		state.ads_state["rew_today"] = 0


static func is_payer(state: GameState) -> bool:
	return state.iap_state.get("no_ads", false) or state.iap_state.get("purchases", []).size() > 0


static func can_interstitial(state: GameState, now: int, session_start: int, rc: Dictionary) -> bool:
	_roll_day(state, now)
	if not rc.get("interstitial_enabled", true):
		return false
	if state.iap_state.get("no_ads", false):
		return false
	if is_payer(state) and GameData.db().ad_policy.get("interstitial_skip_payers", true):
		return false
	# nunca antes de X segundos de jogo total e de sessão (primeira impressão importa para a retenção)
	var first := int(rc.get("interstitial_first_after_sec", 600))
	if state.play_time < first or now - session_start < first / 2:
		return false
	if now - int(state.ads_state.get("last_inter", 0)) < int(rc.get("interstitial_min_interval_sec", 300)):
		return false
	return int(state.ads_state["inter_today"]) < int(rc.get("interstitial_daily_cap", 6))


static func on_interstitial_shown(state: GameState, now: int) -> void:
	_roll_day(state, now)
	state.ads_state["inter_today"] = int(state.ads_state["inter_today"]) + 1
	state.ads_state["last_inter"] = now


static func rewarded_cooldown_left(state: GameState, placement: String, now: int) -> int:
	var until := int(state.ads_state.get("cooldowns", {}).get(placement, 0))
	return max(0, until - now)


static func can_rewarded(state: GameState, placement: String, now: int, rc: Dictionary) -> bool:
	_roll_day(state, now)
	if not GameData.db().ad_policy["rewarded"].has(placement):
		return false
	if rewarded_cooldown_left(state, placement, now) > 0:
		return false
	return int(state.ads_state["rew_today"]) < int(rc.get("rewarded_daily_cap", 25))


static func on_rewarded_done(state: GameState, placement: String, now: int) -> void:
	_roll_day(state, now)
	state.ads_state["rew_today"] = int(state.ads_state["rew_today"]) + 1
	var cd := int(GameData.db().ad_policy["rewarded"].get(placement, {}).get("cooldown", 0))
	if cd > 0:
		if not state.ads_state.has("cooldowns"):
			state.ads_state["cooldowns"] = {}
		state.ads_state["cooldowns"][placement] = now + cd


static func banner_allowed(state: GameState, rc: Dictionary) -> bool:
	return rc.get("banner_in_menus", false) and not state.iap_state.get("no_ads", false)
