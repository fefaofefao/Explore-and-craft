extends Node
## Autoload "Firebase": Analytics, Remote Config, Crashlytics e Cloud Messaging.
## Usa o plugin Android (singleton "GodotFirebaseAndroid") quando presente; senão registra localmente
## (user://analytics.log) para depuração e validação dos eventos em testes.

signal remote_config_updated

var plugin: Object = null
var events_buffer: Array = []  # últimos eventos (debug e testes)
const MAX_BUFFER := 200


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("GodotFirebaseAndroid"):
		plugin = Engine.get_singleton("GodotFirebaseAndroid")
	fetch_remote_config()


func enabled() -> bool:
	return plugin != null


func log_event(name: String, params: Dictionary = {}) -> void:
	if not name in GameData.db().analytics_events:
		push_warning("Evento de analytics fora do catálogo: %s" % name)
	var p := params.duplicate()
	if Game.state != null:
		p["mode"] = Game.state.mode
		p["player_level"] = Game.state.level
	events_buffer.append({"name": name, "params": p, "t": Time.get_unix_time_from_system()})
	if events_buffer.size() > MAX_BUFFER:
		events_buffer.pop_front()
	if plugin != null and plugin.has_method("analytics_log_event"):
		plugin.call("analytics_log_event", name, p)
	elif OS.is_debug_build() and not OS.has_feature("standalone"):
		pass  # no editor/testes: só o buffer


func set_user_property(key: String, value: String) -> void:
	if plugin != null and plugin.has_method("analytics_set_user_property"):
		plugin.call("analytics_set_user_property", key, value)


func record_error(msg: String) -> void:
	if plugin != null and plugin.has_method("crashlytics_log"):
		plugin.call("crashlytics_log", msg)


func fetch_remote_config() -> void:
	## Aplica os padrões e, se houver plugin, busca valores do servidor (sobrescrevendo só chaves conhecidas).
	var defaults: Dictionary = GameData.db().remote_defaults
	if plugin != null and plugin.has_method("remote_config_fetch_and_activate"):
		plugin.call("remote_config_set_defaults", defaults) if plugin.has_method("remote_config_set_defaults") else null
		plugin.call("remote_config_fetch_and_activate")
		if plugin.has_signal("remote_config_activated"):
			plugin.connect("remote_config_activated", _on_rc_activated, CONNECT_ONE_SHOT)


func _on_rc_activated(_a = null) -> void:
	var defaults: Dictionary = GameData.db().remote_defaults
	for k in defaults:
		if plugin.has_method("remote_config_get_string"):
			var v: String = plugin.call("remote_config_get_string", k)
			if v != "":
				Game.rc[k] = _coerce(v, defaults[k])
	emit_signal("remote_config_updated")


static func _coerce(v: String, like: Variant) -> Variant:
	match typeof(like):
		TYPE_BOOL:
			return v.to_lower() in ["true", "1", "yes"]
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
	return v


func messaging_token() -> String:
	if plugin != null and plugin.has_method("messaging_get_token"):
		return plugin.call("messaging_get_token")
	return ""
