class_name Loc
extends RefCounted
## Localização simples PT-BR / EN. Textos de UI em data/strings.json; dados trazem {"pt","en"}.

static var lang: String = "pt"
const LANGS := ["pt", "en"]


static func detect() -> void:
	var l := OS.get_locale_language()
	lang = "pt" if l == "pt" else "en"


static func t(key: String, args: Array = []) -> String:
	var s: Dictionary = GameData.db().strings.get(key, {})
	var txt: String = s.get(lang, s.get("pt", key)) if not s.is_empty() else key
	for i in args.size():
		txt = txt.replace("{%d}" % i, str(args[i]))
	return txt


static func tx(d: Variant) -> String:
	## Texto de dado localizado: {"pt": "...", "en": "..."}
	if d is Dictionary:
		return d.get(lang, d.get("pt", ""))
	return str(d)


static func item_name(id: String) -> String:
	return tx(GameData.db().item(id).get("name", id))


static func species_name(id: String) -> String:
	return tx(GameData.db().sp(id).get("name", id))


static func fmt_time(sec: float) -> String:
	var s := int(max(sec, 0))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s
