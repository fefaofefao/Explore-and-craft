class_name GameState
extends RefCounted
## Estado completo de um save (história ou sandbox). Sem dependência de cena: testável headless.

const SAVE_VERSION := 1

var mode: String = "story"  # story | sandbox
var created_at: int = 0
var play_time: float = 0.0
var last_seen: int = 0

# jogador
var level: int = 1
var xp: int = 0
var hp: float = 100.0
var hunger: float = 100.0
var map_id: String = "m1"
var pos: Vector3 = Vector3.ZERO
var has_pos: bool = false
var spawn_point: Dictionary = {}  # {"map": "m1", "pos": [x, y, z]}
var coins: int = 0
var gems: int = 0

var inv: Inventory

# Ecos
var monsters: Dictionary = {}  # uid(String) -> dict
var party: Array = []  # uids (int)
var box: Array = []  # uids (int)
var active_uid: int = -1
var next_uid: int = 1
var box_capacity: int = 40
var dex: Dictionary = {}  # sp -> {"seen": bool, "caught": int}
var dex_claimed: Array = []  # marcos resgatados (índices)

# mundo
var buildings: Array = []  # {"uid", "id", "map", "cell": [x, z], "y", "rot", "data": {}}
var next_building_uid: int = 1
var world: Dictionary = {}  # map -> {"harvested": {key: until}, "barriers": [keys], "fragments": [ids], "visited": bool, "cages": [idx]}
var flags: Dictionary = {}
var day_time: float = 0.3  # 0..1 (0.25 = nascer do sol, 0.75 = pôr do sol)
var day_count: int = 1

# progressão
var quest_idx: int = 0
var quest_seen_dialog: bool = false
var stats: Dictionary = {"crafted": {}, "built": {}, "gathered": {}, "captures": 0, "defeats": 0, "deaths": 0,
	"bosses": [], "trainers": [], "harvested": 0, "pets": 0, "expeditions": 0}

# retenção / monetização
var daily: Dictionary = {}  # {"date", "quests": [{"id","p","claimed"}], "all_claimed"}
var login: Dictionary = {"last_date": "", "day": 0, "claimed_date": ""}
var pass_state: Dictionary = {"season": 1, "xp": 0, "free": [], "prem": [], "premium": false}
var ads_state: Dictionary = {"date": "", "inter_today": 0, "rew_today": 0, "last_inter": 0, "cooldowns": {}}
var iap_state: Dictionary = {"no_ads": false, "purchases": [], "first_open": 0}
var boosts: Dictionary = {"xp_until": 0}
var expeditions: Array = []  # {"slot", "uid", "start", "dur", "map"}
var expedition_slots: int = 2
var tutorial: Dictionary = {}
var peaceful: bool = false


func _init(p_mode: String = "story") -> void:
	mode = p_mode
	inv = Inventory.new(40)


static func new_game(p_mode: String, now: int) -> GameState:
	var s := GameState.new(p_mode)
	var db := GameData.db()
	s.created_at = now
	s.last_seen = now
	s.iap_state["first_open"] = now
	s.coins = int(db.economy["start"]["coins"])
	s.gems = int(db.economy["start"]["gems"])
	s.hp = s.max_hp()
	s.box_capacity = int(db.cfg("capture", "box_start", 40))
	s.expedition_slots = int(db.config["expedition"]["slots"])
	s.spawn_point = {"map": "m1", "pos": []}
	if p_mode == "sandbox":
		s.apply_sandbox()
	return s


func apply_sandbox() -> void:
	mode = "sandbox"
	inv.infinite = true
	flags["bridge_built"] = true
	flags["city1_free"] = true
	flags["gate2_open"] = true
	flags["starter_chosen"] = true
	level = 30
	hp = max_hp()
	quest_idx = GameData.db().quests.size()
	# kit inicial para ver os itens na mochila
	for id in ["machado_ferro", "picareta_obsidiana", "lamina_obsidiana", "tocha", "pe_de_cabra", "planador",
			"cantil", "casaco_pele", "mascara_filtro", "traje_ignifugo", "para_raios", "esfera_aurora", "tonico_forte", "reviver",
			"madeira", "pedra", "fibra", "lingote_ferro", "cristal", "tabua", "tijolo", "vidro", "carne_assada"]:
		inv.add(id, 1 if GameData.db().item(id).get("stack", 99) == 1 else 99)


func is_sandbox() -> bool:
	return mode == "sandbox"


# ------------------------------------------------------------------ jogador
func max_hp() -> float:
	var p: Dictionary = GameData.db().config["player"]
	return float(p["base_hp"]) + float(p["hp_per_level"]) * (level - 1)


func xp_to_next() -> int:
	var c: Dictionary = GameData.db().config["xp"]
	return int(floor(float(c["player_base"]) * pow(level, float(c["player_exp"]))))


func add_player_xp(amount: int, now: int = 0) -> int:
	## Devolve quantos níveis subiu.
	if amount <= 0:
		return 0
	if boosts.get("xp_until", 0) > now and now > 0:
		amount *= 2
	var maxl := int(GameData.db().cfg("player", "max_level", 60))
	xp += amount
	var ups := 0
	while level < maxl and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		ups += 1
	if ups > 0:
		hp = max_hp()
	return ups


# ------------------------------------------------------------------ Ecos
func get_monster(uid: int) -> Dictionary:
	return monsters.get(str(uid), {})


func add_monster(m: Dictionary) -> String:
	## Coloca na equipe se houver vaga; senão na reserva. Devolve "party", "box" ou "" (cheio).
	m["uid"] = next_uid
	next_uid += 1
	monsters[str(m["uid"])] = m
	var sp: String = m["sp"]
	if not dex.has(sp):
		dex[sp] = {"seen": true, "caught": 0}
	dex[sp]["caught"] = int(dex[sp]["caught"]) + 1
	var max_party := int(GameData.db().cfg("capture", "max_party", 5))
	if party.size() < max_party:
		party.append(m["uid"])
		if active_uid < 0:
			active_uid = m["uid"]
		return "party"
	if box.size() < box_capacity:
		box.append(m["uid"])
		return "box"
	# sem espaço: vai pra reserva mesmo assim (nunca perder um Eco recrutado)
	box.append(m["uid"])
	return "box"


func mark_seen(sp: String) -> void:
	if not dex.has(sp):
		dex[sp] = {"seen": true, "caught": 0}


func species_caught_count() -> int:
	var c := 0
	for k in dex:
		if int(dex[k]["caught"]) > 0:
			c += 1
	return c


func active_monster() -> Dictionary:
	return get_monster(active_uid)


func party_monsters() -> Array:
	var out: Array = []
	for u in party:
		var m := get_monster(u)
		if not m.is_empty():
			out.append(m)
	return out


func party_types() -> Array:
	var out: Array = []
	for m in party_monsters():
		for t in MonsterLogic.types_of(m):
			out.append(t)
	return out


func first_healthy_in_party() -> int:
	for m in party_monsters():
		if not m["fainted"] and int(m.get("job", -1)) < 0:
			return int(m["uid"])
	return -1


func move_to_box(uid: int) -> bool:
	if not uid in party:
		return false
	party.erase(uid)
	box.append(uid)
	if active_uid == uid:
		active_uid = party[0] if party.size() > 0 else -1
	return true


func move_to_party(uid: int) -> bool:
	if not uid in box:
		return false
	if party.size() >= int(GameData.db().cfg("capture", "max_party", 5)):
		return false
	var m := get_monster(uid)
	if m.get("expedition", false):
		return false
	box.erase(uid)
	party.append(uid)
	if active_uid < 0:
		active_uid = uid
	return true


func release_monster(uid: int) -> bool:
	if not monsters.has(str(uid)):
		return false
	if party.size() + box.size() <= 1:
		return false  # nunca fica sem nenhum Eco
	var m := get_monster(uid)
	if m.get("expedition", false):
		return false
	unassign_worker(uid)
	party.erase(uid)
	box.erase(uid)
	monsters.erase(str(uid))
	if active_uid == uid:
		active_uid = party[0] if party.size() > 0 else -1
	return true


func set_active(uid: int) -> bool:
	if not uid in party:
		return false
	var m := get_monster(uid)
	if m.get("fainted", false) or int(m.get("job", -1)) >= 0:
		return false
	active_uid = uid
	return true


func unassign_worker(uid: int) -> void:
	var m := get_monster(uid)
	if m.is_empty():
		return
	var b := get_building(int(m.get("job", -1)))
	if not b.is_empty():
		b["data"]["worker"] = -1
	m["job"] = -1


func tick_monster_rest(now: int) -> void:
	## Ecos desmaiados se recuperam sozinhos depois de um tempo (modo fácil).
	for k in monsters:
		var m: Dictionary = monsters[k]
		if m["fainted"] and int(m.get("faint_until", 0)) > 0 and now >= int(m["faint_until"]):
			m["fainted"] = false
			m["hp"] = max(1, MonsterLogic.max_hp(m) / 2)
			m["faint_until"] = 0


# ------------------------------------------------------------------ construções
func get_building(uid: int) -> Dictionary:
	if uid < 0:
		return {}
	for b in buildings:
		if int(b["uid"]) == uid:
			return b
	return {}


func buildings_on(map: String) -> Array:
	var out: Array = []
	for b in buildings:
		if b["map"] == map:
			out.append(b)
	return out


func count_buildings(id: String) -> int:
	var c := 0
	for b in buildings:
		if b["id"] == id:
			c += 1
	return c


# ------------------------------------------------------------------ mundo
func map_state(map: String) -> Dictionary:
	if not world.has(map):
		world[map] = {"harvested": {}, "barriers": [], "fragments": [], "visited": false, "cages": []}
	return world[map]


func fragments_found() -> Array:
	var out: Array = []
	for m in world:
		out.append_array(world[m].get("fragments", []))
	return out


func is_night() -> bool:
	return day_time < 0.22 or day_time > 0.78


func map_unlocked(map: String) -> bool:
	if is_sandbox():
		return true
	match map:
		"m1", "m2", "m3":
			return true
		"m4":
			return flags.get("bridge_built", false)
		"m5", "m6", "m7":
			return flags.get("city1_free", false)
		"m8":
			return flags.get("gate2_open", false)
	return false


# ------------------------------------------------------------------ moeda
func can_afford(price: Dictionary) -> bool:
	return coins >= int(price.get("coins", 0)) and gems >= int(price.get("gems", 0))


func pay(price: Dictionary) -> bool:
	if not can_afford(price):
		return false
	coins -= int(price.get("coins", 0))
	gems -= int(price.get("gems", 0))
	return true


func grant(reward: Dictionary, rng: RandomNumberGenerator = null, now: int = 0) -> Dictionary:
	## Aplica uma recompensa genérica {coins, gems, xp, items, pass_xp, monster:[sp,lvl,variant]}.
	## Devolve resumo do que foi dado (inclui itens que não couberam em "overflow").
	var out := {"coins": 0, "gems": 0, "items": {}, "overflow": {}, "monster": "", "levels": 0}
	coins += int(reward.get("coins", 0))
	out["coins"] = int(reward.get("coins", 0))
	gems += int(reward.get("gems", 0))
	out["gems"] = int(reward.get("gems", 0))
	if reward.has("xp"):
		out["levels"] = add_player_xp(int(reward["xp"]), now)
	if reward.has("pass_xp"):
		pass_state["xp"] = int(pass_state["xp"]) + int(reward["pass_xp"])
	var its: Dictionary = reward.get("items", {})
	for k in its:
		var left := inv.add(k, int(its[k]))
		out["items"][k] = int(its[k]) - left
		if left > 0:
			out["overflow"][k] = left
	if reward.has("monster"):
		var r := rng if rng != null else RandomNumberGenerator.new()
		var mm: Array = reward["monster"]
		var m := MonsterLogic.create(mm[0], int(mm[1]), r, 0, mm.size() > 2 and mm[2])
		add_monster(m)
		out["monster"] = mm[0]
	if reward.get("no_ads", false):
		iap_state["no_ads"] = true
	if reward.get("premium_pass", false):
		pass_state["premium"] = true
	return out


# ------------------------------------------------------------------ serialização
func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION, "mode": mode, "created_at": created_at, "play_time": play_time, "last_seen": last_seen,
		"level": level, "xp": xp, "hp": hp, "hunger": hunger, "map": map_id,
		"pos": [pos.x, pos.y, pos.z], "has_pos": has_pos, "spawn": spawn_point, "coins": coins, "gems": gems,
		"inv": inv.to_dict(), "monsters": monsters, "party": party, "box": box, "active": active_uid,
		"next_uid": next_uid, "box_cap": box_capacity, "dex": dex, "dex_claimed": dex_claimed,
		"buildings": buildings, "next_b": next_building_uid, "world": world, "flags": flags,
		"day_time": day_time, "day_count": day_count, "quest_idx": quest_idx, "quest_seen": quest_seen_dialog,
		"stats": stats, "daily": daily, "login": login, "pass": pass_state, "ads": ads_state, "iap": iap_state,
		"boosts": boosts, "expeditions": expeditions, "exp_slots": expedition_slots, "tutorial": tutorial,
		"peaceful": peaceful,
	}.duplicate(true)


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new(d.get("mode", "story"))
	s.created_at = int(d.get("created_at", 0))
	s.play_time = float(d.get("play_time", 0))
	s.last_seen = int(d.get("last_seen", 0))
	s.level = int(d.get("level", 1))
	s.xp = int(d.get("xp", 0))
	s.hunger = float(d.get("hunger", 100))
	s.map_id = d.get("map", "m1")
	var p: Array = d.get("pos", [0, 0, 0])
	s.pos = Vector3(p[0], p[1], p[2])
	s.has_pos = d.get("has_pos", false)
	s.spawn_point = d.get("spawn", {"map": "m1", "pos": []})
	s.coins = int(d.get("coins", 0))
	s.gems = int(d.get("gems", 0))
	s.inv.from_dict(d.get("inv", {}))
	s.inv.resize(40)
	s.monsters = d.get("monsters", {})
	# JSON devolve números como float: normaliza campos inteiros
	for k in s.monsters:
		var m: Dictionary = s.monsters[k]
		for f in ["uid", "lvl", "xp", "hp", "bond_xp", "bond", "faint_until", "job"]:
			m[f] = int(m.get(f, -1 if f == "job" else 0))
	s.party = _ints(d.get("party", []))
	s.box = _ints(d.get("box", []))
	s.active_uid = int(d.get("active", -1))
	s.next_uid = int(d.get("next_uid", 1))
	s.box_capacity = int(d.get("box_cap", 40))
	s.dex = d.get("dex", {})
	s.dex_claimed = _ints(d.get("dex_claimed", []))
	s.buildings = d.get("buildings", [])
	for b in s.buildings:
		b["uid"] = int(b["uid"])
		b["rot"] = int(b.get("rot", 0))
		b["cell"] = [int(b["cell"][0]), int(b["cell"][1])]
		if b["data"].has("worker"):
			b["data"]["worker"] = int(b["data"]["worker"])
	s.next_building_uid = int(d.get("next_b", 1))
	s.world = d.get("world", {})
	s.flags = d.get("flags", {})
	s.day_time = float(d.get("day_time", 0.3))
	s.day_count = int(d.get("day_count", 1))
	s.quest_idx = int(d.get("quest_idx", 0))
	s.quest_seen_dialog = d.get("quest_seen", false)
	var st: Dictionary = d.get("stats", {})
	for k in st:
		s.stats[k] = st[k]
	s.daily = d.get("daily", {})
	s.login = d.get("login", s.login)
	s.pass_state = d.get("pass", s.pass_state)
	s.ads_state = d.get("ads", s.ads_state)
	s.iap_state = d.get("iap", s.iap_state)
	s.boosts = d.get("boosts", s.boosts)
	s.expeditions = d.get("expeditions", [])
	s.expedition_slots = int(d.get("exp_slots", 2))
	s.tutorial = d.get("tutorial", {})
	s.peaceful = d.get("peaceful", false)
	s.hp = clampf(float(d.get("hp", 100)), 1.0, s.max_hp())
	if s.mode == "sandbox":
		s.inv.infinite = true
	return s


static func _ints(a: Array) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out
