class_name GameData
extends RefCounted
## Acesso a todos os dados de balanceamento/conteúdo (data/*.json).
## Singleton estático: funciona em testes headless sem autoloads.

static var _inst: GameData

var types: Dictionary
var skills: Dictionary
var species: Dictionary
var items: Dictionary
var recipes: Dictionary
var nodes: Dictionary
var buildings: Dictionary
var maps: Dictionary
var future_acts: Array
var trainers: Dictionary
var quests: Array
var speakers: Dictionary
var dialogs: Dictionary
var fragments: Dictionary
var config: Dictionary
var economy: Dictionary
var iap: Dictionary
var daily_login: Array
var daily_quests: Array
var daily_quest_reward: Dictionary
var daily_all_bonus: Dictionary
var pass_data: Dictionary
var dex_milestones: Array
var ads: Dictionary
var ad_policy: Dictionary
var remote_defaults: Dictionary
var analytics_events: Array
var strings: Dictionary


static func db() -> GameData:
	if _inst == null:
		_inst = GameData.new()
		_inst.load_all()
	return _inst


static func read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: não abriu %s" % path)
		return null
	var txt := f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("GameData: JSON inválido em %s" % path)
	return parsed


func load_all() -> void:
	types = read_json("res://data/types.json")
	skills = read_json("res://data/skills.json")
	species = read_json("res://data/species.json")
	items = read_json("res://data/items.json")
	recipes = read_json("res://data/recipes.json")
	nodes = read_json("res://data/nodes.json")
	buildings = read_json("res://data/buildings.json")
	var m: Dictionary = read_json("res://data/maps.json")
	maps = m["maps"]
	future_acts = m["future_acts"]
	trainers = read_json("res://data/trainers.json")
	quests = read_json("res://data/quests.json")
	var d: Dictionary = read_json("res://data/dialogs.json")
	speakers = d["speakers"]
	dialogs = d["dialogs"]
	fragments = read_json("res://data/fragments.json")
	config = read_json("res://data/config.json")
	var e: Dictionary = read_json("res://data/economy.json")
	economy = e["economy"]
	iap = e["iap"]
	daily_login = e["daily_login"]
	daily_quests = e["daily_quests"]
	daily_quest_reward = e["daily_quest_reward"]
	daily_all_bonus = e["daily_all_bonus"]
	pass_data = e["pass"]
	dex_milestones = e["dex_milestones"]
	ads = read_json("res://data/ads.json")
	ad_policy = read_json("res://data/ad_policy.json")
	remote_defaults = read_json("res://data/remote_config_defaults.json")
	analytics_events = read_json("res://data/analytics_events.json")
	strings = read_json("res://data/strings.json")


func cfg(section: String, key: String, default: Variant = null) -> Variant:
	var s: Dictionary = config.get(section, {})
	return s.get(key, default)


func item(id: String) -> Dictionary:
	return items.get(id, {})


func sp(id: String) -> Dictionary:
	return species.get(id, {})


func regular_species() -> Array:
	var out: Array = []
	for k in species.keys():
		if not species[k]["boss"]:
			out.append(k)
	return out


func quest_index(qid: String) -> int:
	for i in quests.size():
		if quests[i]["id"] == qid:
			return i
	return -1
