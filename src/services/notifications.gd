class_name Notifications
extends RefCounted
## Notificações locais de retorno (retenção): produção cheia, presente diário, expedições.
## Usa um plugin de notificações locais se existir (singleton "LocalNotification"); senão não faz nada.


static func plan(state: GameState, now: int) -> Array:
	## Lista de lembretes [{"in": segundos, "title", "body"}] — testável sem plugin.
	var out: Array = []
	if state == null:
		return out
	# quando a primeira estação encher
	var soonest := -1
	for b in state.buildings:
		if int(b["data"].get("worker", -1)) < 0:
			continue
		var m := state.get_monster(int(b["data"]["worker"]))
		if m.is_empty():
			continue
		var rate := WorkLogic.rate_per_hour(m, b["id"])
		if rate <= 0.0:
			continue
		var cap := float(GameData.db().config["work"]["station_capacity"]) - WorkLogic.stored_total(b)
		var secs := int(cap / rate * 3600.0)
		if soonest < 0 or secs < soonest:
			soonest = secs
	if soonest > 0:
		out.append({"in": max(soonest, 1800), "title": Loc.t("game_title"), "body": Loc.t("offline_title")})
	for e in state.expeditions:
		out.append({"in": max(60, ExpeditionLogic.time_left(e, now)), "title": Loc.t("expeditions"), "body": Loc.t("exp_ready")})
	out.append({"in": RetentionLogic.seconds_to_next_day(now) + 9 * 3600, "title": Loc.t("daily_login"), "body": Loc.t("come_back_tomorrow")})
	return out


static func schedule_return_reminders(state: GameState, now: int) -> void:
	if not Engine.has_singleton("LocalNotification"):
		return
	var ln := Engine.get_singleton("LocalNotification")
	var id := 1
	for n in plan(state, now):
		if ln.has_method("show"):
			ln.call("show", n["body"], n["title"], int(n["in"]), id)
		id += 1
