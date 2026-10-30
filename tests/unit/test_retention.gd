extends TestCase

const DAY := 86400
const T0 := 1_800_000_000


func test_daily_login_once_per_day() -> void:
	var s := fresh()
	check(RetentionLogic.login_available(s, T0), "disponível")
	var c := s.coins
	RetentionLogic.claim_login(s, T0)
	eq(s.coins, c + 100, "dia 1 = 100 moedas")
	check(not RetentionLogic.login_available(s, T0 + 60), "já resgatado")
	check(RetentionLogic.login_available(s, T0 + DAY), "dia seguinte")
	RetentionLogic.claim_login(s, T0 + DAY)
	eq(s.inv.count("esfera"), 5, "dia 2 = esferas")


func test_login_cycle_wraps() -> void:
	var s := fresh()
	for i in 8:
		RetentionLogic.claim_login(s, T0 + DAY * i)
	eq(RetentionLogic.login_day_index(s), 1, "volta ao início após 7")


func test_login_doubled() -> void:
	var s := fresh()
	var c := s.coins
	RetentionLogic.claim_login(s, T0, true)
	eq(s.coins, c + 200, "x2")


func test_daily_quests_rotate() -> void:
	var s := fresh()
	check(RetentionLogic.ensure_daily(s, T0), "gerou")
	eq(s.daily["quests"].size(), 3, "3 diárias")
	check(not RetentionLogic.ensure_daily(s, T0 + 100), "mesmo dia")
	var first: Array = s.daily["quests"].map(func(q): return q["id"])
	var changed := false
	for i in range(1, 6):
		RetentionLogic.ensure_daily(s, T0 + DAY * i)
		if s.daily["quests"].map(func(q): return q["id"]) != first:
			changed = true
	check(changed, "muda com os dias")


func test_daily_progress_and_claim() -> void:
	var s := fresh()
	s.daily = {"date": RetentionLogic.date_key(T0), "quests": [{"id": "dq_wood", "p": 0, "claimed": false},
		{"id": "dq_capture", "p": 0, "claimed": false}, {"id": "dq_pet", "p": 0, "claimed": false}], "all_claimed": false}
	RetentionLogic.on_event(s, "gather", "pedra", 50)
	eq(s.daily["quests"][0]["p"], 0, "alvo errado não conta")
	var done := RetentionLogic.on_event(s, "gather", "madeira", 45)
	eq(done, ["dq_wood"], "completou")
	eq(s.daily["quests"][0]["p"], 40, "limitado ao alvo")
	check(not RetentionLogic.claim_daily(s, "dq_capture").size() > 0, "incompleta não resgata")
	var c := s.coins
	RetentionLogic.claim_daily(s, "dq_wood")
	eq(s.coins, c + 60, "recompensa")
	eq(s.pass_state["xp"], 100, "xp de trilha")
	eq(RetentionLogic.claim_daily(s, "dq_wood").size(), 0, "não resgata 2x")
	RetentionLogic.on_event(s, "capture", "", 2)
	RetentionLogic.on_event(s, "pet", "", 3)
	RetentionLogic.claim_daily(s, "dq_capture")
	RetentionLogic.claim_daily(s, "dq_pet")
	var g := s.gems
	RetentionLogic.claim_all_bonus(s)
	eq(s.gems, g + 10, "bônus de todas")
	eq(RetentionLogic.claim_all_bonus(s).size(), 0, "bônus 1x")


func test_pass_tiers_and_claims() -> void:
	var s := fresh()
	eq(RetentionLogic.pass_tier(s), 0, "tier 0")
	s.pass_state["xp"] = 600
	eq(RetentionLogic.pass_tier(s), 2, "tier 2")
	eq(RetentionLogic.pass_claimable(s), 2, "2 grátis")
	check(RetentionLogic.claim_pass(s, 1, false).size() > 0, "resgata grátis")
	eq(RetentionLogic.claim_pass(s, 1, false).size(), 0, "não repete")
	eq(RetentionLogic.claim_pass(s, 3, false).size(), 0, "tier não alcançado")
	eq(RetentionLogic.claim_pass(s, 1, true).size(), 0, "premium bloqueado")
	s.pass_state["premium"] = true
	check(RetentionLogic.claim_pass(s, 1, true).size() > 0, "premium após compra")
	s.pass_state["xp"] = 999999
	eq(RetentionLogic.pass_tier(s), 30, "teto 30")


func test_dex_milestones() -> void:
	var s := fresh()
	eq(RetentionLogic.dex_claimable(s).size(), 0, "nada")
	for sp in ["folhito", "brasito", "marolo"]:
		s.add_monster(MonsterLogic.create(sp, 3, rng()))
	eq(RetentionLogic.dex_claimable(s), [0], "marco 3")
	var g := s.gems
	RetentionLogic.claim_dex(s, 0)
	eq(s.gems, g + 10, "recompensa")
	eq(RetentionLogic.dex_claimable(s).size(), 0, "resgatado")


func test_starter_offer_window() -> void:
	var s := fresh()
	check(RetentionLogic.starter_offer_left(s, s.created_at + 3600) > 0, "na janela")
	eq(RetentionLogic.starter_offer_left(s, s.created_at + 73 * 3600), 0, "expirou")
	s.iap_state["purchases"].append("starter_pack")
	eq(RetentionLogic.starter_offer_left(s, s.created_at + 3600), 0, "já comprado")
