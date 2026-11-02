extends Node
## Autoload "Game": estado do save atual, configurações, autosave, eventos de jogo,
## missões (história/diárias) e integração com Analytics.

signal toast(text: String, kind: String)
signal hud_refresh
signal quest_changed
signal player_leveled(level: int)
signal dialog_requested(dialog_id: String)
signal reward_popup(title: String, reward: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"

var state: GameState
var slot: String = "story"
var session_start: int = 0
var rng := RandomNumberGenerator.new()
var settings := {"lang": "", "music": 0.7, "sfx": 0.9, "quality": -1, "cam_sens": 1.0, "vibration": true,
	"consent": false, "consent_asked": false, "auto_gather": true}
var rc: Dictionary = {}  # Remote Config efetivo
var _autosave_t := 0.0
var _tick_t := 0.0
var paused_world := false
var current_world: Node = null


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	rc = GameData.db().remote_defaults.duplicate()
	var tz: Dictionary = Time.get_time_zone_from_system()
	RetentionLogic.tz_offset_sec = int(tz.get("bias", 0)) * 60
	load_settings()
	session_start = now()


func now() -> int:
	return int(Time.get_unix_time_from_system())


# ------------------------------------------------------------------ configurações
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cf.get_value("s", k, settings[k])
	if settings["lang"] == "":
		Loc.detect()
		settings["lang"] = Loc.lang
	Loc.lang = settings["lang"]
	if int(settings["quality"]) < 0:
		settings["quality"] = detect_quality()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("s", k, settings[k])
	cf.save(SETTINGS_PATH)


func detect_quality() -> int:
	## 0 desempenho, 1 equilibrado, 2 máximo. Celulares começam no equilibrado.
	if OS.has_feature("mobile"):
		var cores := OS.get_processor_count()
		return 0 if cores <= 4 else 1
	return 2


func quality() -> int:
	return int(settings["quality"])


# ------------------------------------------------------------------ saves
func has_save(mode: String) -> bool:
	return SaveSystem.exists(mode)


func new_game(mode: String) -> void:
	slot = mode
	state = GameState.new_game(mode, now())
	RetentionLogic.ensure_daily(state, now())
	Firebase.log_event("sandbox_start" if mode == "sandbox" else "tutorial_begin", {})
	save_now()


func load_game(mode: String) -> bool:
	var s := SaveSystem.load_state(mode)
	if s == null:
		return false
	slot = mode
	state = s
	return true


func save_now() -> void:
	if state == null:
		return
	state.last_seen = now()
	if current_world != null and current_world.has_method("sync_to_state"):
		current_world.sync_to_state()
	SaveSystem.save(state, slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()
		if state != null:
			Notifications.schedule_return_reminders(state, now())


func _process(delta: float) -> void:
	if state == null:
		return
	if not get_tree().paused:
		state.play_time += delta
	_autosave_t += delta
	if _autosave_t >= float(GameData.db().cfg("save", "autosave_sec", 30)):
		_autosave_t = 0.0
		save_now()
	_tick_t += delta
	if _tick_t >= 1.0:
		_tick_t = 0.0
		state.tick_monster_rest(now())
		if RetentionLogic.ensure_daily(state, now()):
			emit_signal("hud_refresh")


# ------------------------------------------------------------------ eventos de jogo
func notify(text: String, kind: String = "info") -> void:
	emit_signal("toast", text, kind)


func on_gather(item_id: String, n: int) -> void:
	var g: Dictionary = state.stats["gathered"]
	g[item_id] = int(g.get(item_id, 0)) + n
	_daily("gather", item_id, n)
	check_quests()


func on_capture(m: Dictionary) -> void:
	state.stats["captures"] = int(state.stats["captures"]) + 1
	_daily("capture", "", 1)
	Firebase.log_event("capture_success", {"species": m["sp"], "level": m["lvl"], "variant": m.get("variant", false)})
	if m.get("variant", false):
		Firebase.log_event("aurora_variant", {"species": m["sp"]})
	check_quests()


func on_defeat(m: Dictionary) -> void:
	state.stats["defeats"] = int(state.stats["defeats"]) + 1
	_daily("defeat", "", 1)
	if GameData.db().sp(m["sp"]).get("boss", false) and not m["sp"] in state.stats["bosses"]:
		state.stats["bosses"].append(m["sp"])
		Firebase.log_event("boss_defeated", {"boss": m["sp"]})
	check_quests()


func on_craft(item_id: String, n: int) -> void:
	_daily("craft", "", n)
	var cat: String = GameData.db().item(item_id).get("cat", "")
	_daily("craft_cat", cat, n)
	Firebase.log_event("craft", {"item": item_id, "n": n})
	check_quests()


func on_build(build_id: String) -> void:
	_daily("build", "", 1)
	Firebase.log_event("build", {"id": build_id})
	check_quests()


func on_harvest(n: int) -> void:
	_daily("harvest", "", n)
	Firebase.log_event("harvest", {"n": n})


func on_pet() -> void:
	state.stats["pets"] = int(state.stats.get("pets", 0)) + 1
	_daily("pet", "", 1)


func on_expedition_done() -> void:
	_daily("expedition", "", 1)
	Firebase.log_event("expedition_complete", {})


func on_trainer_defeated(tid: String) -> void:
	if not tid in state.stats["trainers"]:
		state.stats["trainers"].append(tid)
	Firebase.log_event("trainer_defeated", {"trainer": tid})
	check_quests()


func _daily(ev: String, target: String, n: int) -> void:
	var done := RetentionLogic.on_event(state, ev, target, n)
	for id in done:
		var d := RetentionLogic.daily_def(id)
		notify("%s ✓" % Loc.tx(d["title"]), "daily")
		Firebase.log_event("daily_quest_complete", {"id": id})


func add_xp(amount: int) -> void:
	var before := state.level
	var mult := float(rc.get("xp_mult", 1.0)) * float(rc.get("event_xp_mult", 1.0))
	var ups := state.add_player_xp(int(round(amount * mult)), now())
	if ups > 0:
		_on_level_up(before)


func _on_level_up(before: int) -> void:
	emit_signal("player_leveled", state.level)
	notify(Loc.t("player_level_up", [state.level]), "level")
	Firebase.log_event("level_up", {"level": state.level})
	Audio.play("level_up")
	var unlocked := false
	for l in range(before + 1, state.level + 1):
		if CraftLogic.recipes_unlocked_at(l).size() > 0:
			unlocked = true
	if unlocked:
		notify(Loc.t("new_recipes"), "info")


func check_quests() -> void:
	if state == null or state.is_sandbox():
		return
	var before_lvl := state.level
	var done := QuestLogic.try_advance(state, now())
	for d in done:
		var q: Dictionary = d["quest"]
		notify(Loc.t("quest_done", [Loc.tx(q["title"])]), "quest")
		Firebase.log_event("quest_complete", {"id": q["id"]})
		Audio.play("quest")
		if q["id"] == "q09":
			Firebase.log_event("tutorial_complete", {})
		if q.get("done_dialog") != null:
			emit_signal("dialog_requested", q["done_dialog"])
		emit_signal("reward_popup", Loc.tx(q["title"]), d["reward"])
	if done.size() > 0:
		if state.level > before_lvl:
			_on_level_up(before_lvl)
		var cur := QuestLogic.current(state)
		if not cur.is_empty():
			notify(Loc.t("new_quest", [Loc.tx(cur["title"])]), "quest")
		emit_signal("quest_changed")
		save_now()
	emit_signal("hud_refresh")


func grant_and_toast(reward: Dictionary, title: String = "") -> Dictionary:
	var before := state.level
	var r := state.grant(reward, rng, now())
	for k in r["items"]:
		if int(r["items"][k]) > 0:
			notify(Loc.t("got_item", [r["items"][k], Loc.item_name(k)]), "item")
	if int(r["coins"]) > 0:
		notify("+%d %s" % [r["coins"], Loc.t("coins")], "coin")
	if int(r["gems"]) > 0:
		notify("+%d %s" % [r["gems"], Loc.t("gems")], "gem")
	if r["monster"] != "":
		notify(Loc.t("capture_success", [Loc.species_name(r["monster"])]), "capture")
	if state.level > before:
		_on_level_up(before)
	if title != "":
		emit_signal("reward_popup", title, r)
	emit_signal("hud_refresh")
	return r


func is_peaceful() -> bool:
	return state != null and state.is_sandbox() and state.peaceful
