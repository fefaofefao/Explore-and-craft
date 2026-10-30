extends Node
## Autopiloto dentro do jogo real (com autoloads): screenshots e teste de integração (smoke).
## godot --path . -- --autopilot shots docs/screenshots
## godot --headless --path . -- --autopilot smoke

var main: Node
var fails: Array = []
var checks := 0
var out_dir := "res://docs/screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--autopilot")
	var scenario: String = args[i + 1] if args.size() > i + 1 else "smoke"
	if args.size() > i + 2:
		out_dir = args[i + 2]
	SaveSystem.base_dir = "user://autopilot_saves/"
	DirAccess.make_dir_recursive_absolute("user://autopilot_saves")
	Game.settings["consent_asked"] = true
	Game.settings["lang"] = "pt" if not "--en" in args else "en"
	Loc.lang = Game.settings["lang"]
	if "--quality" in args:
		Game.settings["quality"] = int(args[args.find("--quality") + 1])
	await get_tree().process_frame
	match scenario:
		"shots":
			await _shots()
		"smoke":
			await _smoke()
		"perf":
			await _perf()
	get_tree().quit(1 if fails.size() > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)
		print("  ✗ ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("SHOT ", path)


func _new_story(day: float = 0.42) -> GameState:
	Game.new_game("story")
	var st: GameState = Game.state
	st.day_time = day
	return st


func _setup_progress(st: GameState) -> void:
	st.flags["starter_chosen"] = true
	st.add_monster(MonsterLogic.create("brasito", 9, Game.rng))
	st.add_monster(MonsterLogic.create("folhito", 8, Game.rng))
	st.add_monster(MonsterLogic.create("marolo", 8, Game.rng))
	st.inv.add("esfera", 12)
	st.inv.add("machado_pedra", 1)
	st.inv.add("picareta_pedra", 1)
	st.inv.add("lanca_pedra", 1)
	st.inv.add("madeira", 40)
	st.inv.add("pedra", 30)
	st.inv.add("fibra", 20)
	st.quest_idx = 5
	st.level = 6


func _place(st: GameState, id: String, cell: Vector2i, rot: int = 0) -> void:
	var gen: WorldGen = main.world.gen if main.world != null else WorldGen.new(st.map_id)
	var c := BuildLogic.cell_center(cell)
	var y := BuildLogic.base_height(st, st.map_id, cell, gen.height(c.x, c.z))
	st.inv.infinite = true
	BuildLogic.place(st, id, st.map_id, cell, rot, y, {}, Game.now())
	st.inv.infinite = false


# ================================================================== screenshots
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	# título
	main.show_title()
	await _frames(60)
	await _shot("01_titulo")
	# começo da história (Berço + 3 Ecos acorrentados)
	var st := _new_story(0.36)
	await main._load_map("m1")
	await _frames(30)
	var w: World = main.world
	_aim(w, Vector3(6, 0, 66), 3.0, 0.5)
	await _frames(40)
	await _shot("02_berco_inicio")
	w.hud.show_starter_choice(func(_s): pass)
	await _frames(20)
	await _shot("03_escolha_parceiro")
	# base construída
	st = _new_story(0.45)
	_setup_progress(st)
	st.map_id = "m1"
	await main._load_map("m1")
	w = main.world
	var base := BuildLogic.cell_of(w.player.global_position + Vector3(5, 0, -8))
	for dx in 3:
		for dz in 3:
			_place(st, "fundacao", base + Vector2i(dx, dz))
	for dx in 3:
		_place(st, "parede", base + Vector2i(dx, 0), 0)
		if dx != 1:
			_place(st, "parede", base + Vector2i(dx, 2), 2)
		else:
			_place(st, "porta", base + Vector2i(dx, 2), 2)
		_place(st, "telhado", base + Vector2i(dx, 1))
	_place(st, "parede", base + Vector2i(0, 1), 3)
	_place(st, "janela", base + Vector2i(2, 1), 1)
	_place(st, "cama", base + Vector2i(0, 1))
	_place(st, "bau", base + Vector2i(2, 1))
	_place(st, "fogueira", base + Vector2i(1, 4))
	_place(st, "bancada", base + Vector2i(3, 4))
	_place(st, "horta", base + Vector2i(-2, 4))
	_place(st, "fonte_cura", base + Vector2i(5, 1))
	_place(st, "serraria", base + Vector2i(5, 4))
	for k in st.buildings:
		if k["id"] == "horta":
			WorkLogic.assign(st, int(k["uid"]), st.party[1], Game.now())
	await main._load_map("m1")
	w = main.world
	var bc := BuildLogic.cell_center(base + Vector2i(1, 2))
	_aim(w, bc, 0.9, 0.42, 13.0)
	await _frames(60)
	await _shot("04_base")
	# combate e habilidade
	_aim(w, w.player.global_position, 2.2, 0.35, 7.5)
	var m := MonsterLogic.create("espinhoz", 6, Game.rng)
	var foe := MonsterActor.new().setup(m, "wild", w, w.gen)
	w._actors.add_child(foe)
	foe.global_position = w.player.global_position + Vector3(0, 0.6, -4.0)
	foe.home = foe.global_position
	w.wilds.append(foe)
	w._focus = foe
	await _frames(50)
	w.ally_skill(1)
	await _frames(12)
	await _shot("05_combate")
	# outros biomas
	for e in [["m2", 0.55, "06_dunas"], ["m3", 0.5, "07_picos"], ["m5", 0.5, "09_pantano"], ["m6", 0.5, "10_canion"], ["m7", 0.5, "11_ilhas"]]:
		st.flags["city1_free"] = true
		st.day_time = e[1]
		st.has_pos = false
		await main._load_map(e[0])
		_aim(main.world, main.world.player.global_position, 2.6, 0.38, 9.0)
		await _frames(70)
		await _shot(e[2])
	# cidade
	st.flags["bridge_built"] = true
	st.has_pos = true
	st.map_id = "m4"
	st.pos = Vector3(18, 0, 44)
	st.day_time = 0.62
	await main._load_map("m4")
	w = main.world
	_aim(w, Vector3(0, 0, 10), 3.3, 0.33, 14.0)
	await _frames(70)
	await _shot("08_porto_ferrugem")
	# noite
	st.map_id = "m1"
	st.has_pos = false
	st.day_time = 0.9
	await main._load_map("m1")
	_aim(main.world, main.world.player.global_position, 1.0, 0.35, 8.0)
	await _frames(60)
	await _shot("12_noite")
	# menus
	st.day_time = 0.45
	await main._load_map("m1")
	w = main.world
	await _frames(20)
	for tab in [["inventory", "13_mochila"], ["craft", "14_criar"], ["echoes", "15_ecos"], ["quests", "16_missoes"], ["shop", "17_loja"], ["pass", "18_trilha"], ["dex", "19_bestiario"]]:
		w.hud.open_menu(tab[0])
		await _frames(25)
		await _shot(tab[1])
	w.hud.menu.close_menu()
	w.hud.show_daily_login()
	await _frames(20)
	await _shot("20_presente_diario")
	w.hud.overlay.get_child(0).queue_free()
	w.hud.show_dialog("d_vorn_meet", Callable())
	await _frames(60)
	await _shot("21_dialogo")
	w.hud.overlay.get_child(0).queue_free()
	w.hud.show_capture(MonsterLogic.create("lumeflor", 9, Game.rng, 0, true), "party")
	await _frames(30)
	await _shot("22_recrutamento")


func _aim(w: World, at: Vector3, yaw: float, pitch: float, dist: float = 7.5) -> void:
	w.rig.yaw = yaw
	w.rig.pitch = -pitch
	w.rig.distance = dist
	if at != w.player.global_position:
		var p := Vector3(at.x, w.gen.height(at.x, at.z) + 0.5, at.z)
		w.player.global_position = p
	w.rig.snap()


# ================================================================== teste de integração
func _smoke() -> void:
	print("== SMOKE: história")
	var st := _new_story(0.4)
	await main._load_map("m1")
	var w: World = main.world
	check(w != null and w.player != null, "mundo carregou")
	check(w.nodes.size() > 150, "recursos gerados (%d)" % w.nodes.size())
	check(w.wilds.size() > 5, "Ecos selvagens (%d)" % w.wilds.size())
	# escolher parceiro
	w._choose_starter("brasito")
	await _frames(5)
	check(st.party.size() == 1, "parceiro escolhido")
	check(w.ally_actor() != null, "parceiro em campo")
	check(QuestLogic.current(st)["id"] == "q02", "missão 2 ativa")
	# coletar: bater em nós até esgotar
	var gathered := 0
	for k in w.nodes.keys():
		var n: ResourceNode = w.nodes[k]
		var want_kind: String = ["arvore", "arbusto", "capim"][gathered % 3]
		if n.kind == want_kind and not n.harvested and gathered < 12:
			w.player.global_position = n.global_position + Vector3(1.5, 0.5, 0)
			for hit in 12:
				w._gather(n)
				if n.harvested:
					break
			gathered += 1
	check(st.inv.count("madeira") > 0 and st.inv.count("fibra") > 0, "coleta deu madeira e fibra (%d/%d, nós=%d, gs=%s)" % [st.inv.count("madeira"), st.inv.count("fibra"), gathered, str(st.stats["gathered"])])
	# criar ferramentas
	st.inv.add("pedra", 10)
	st.inv.add("madeira", 10)
	st.inv.add("fibra", 10)
	Game.check_quests()
	var r := CraftLogic.craft(st, "r_machado_pedra", [])
	check(r["ok"], "machado criado")
	Game.on_craft("machado_pedra", 1)
	CraftLogic.craft(st, "r_picareta_pedra", [])
	Game.on_craft("picareta_pedra", 1)
	check(st.quest_idx >= 3, "missão de ferramentas concluída (%d)" % st.quest_idx)
	# construir bancada pelo fantasma
	st.inv.add("madeira", 20)
	st.inv.add("pedra", 20)
	w.player.global_position = Vector3(10, w.gen.height(10, 60) + 0.5, 60)
	w.enter_build_mode("bancada")
	var placed := false
	for tries in 8:
		w.rotate_ghost()
		w._update_ghost()
		if w.ghost_ok:
			w.place_ghost()
			placed = true
			break
		w.player.global_position += Vector3(3, 0, 0)
		w.player.global_position.y = w.gen.height(w.player.global_position.x, w.player.global_position.z) + 0.5
	w.exit_build_mode()
	check(placed and st.count_buildings("bancada") == 1, "bancada construída")
	# combate: parceiro derrota um selvagem
	var foe: MonsterActor = null
	for a in w.wilds:
		if is_instance_valid(a):
			foe = a
			break
	check(foe != null, "há selvagem para lutar")
	if foe != null:
		foe.m["hp"] = 1
		w.player.global_position = foe.global_position + Vector3(2, 0.5, 0)
		var before := int(st.stats["defeats"])
		foe.take_hit(5, 1.0, false, w.player)
		await _frames(3)
		check(int(st.stats["defeats"]) == before + 1, "derrota registrada")
	# captura forçada
	var target: MonsterActor = null
	for a in w.wilds:
		if is_instance_valid(a) and not a.dead:
			target = a
			break
	if target != null:
		st.inv.add("esfera", 5)
		w._on_captured(target, target.global_position)
		await _frames(3)
		check(st.party.size() == 2, "captura adicionou à equipe")
		check(int(st.stats["captures"]) == 1, "captura contada")
		if w.hud.overlay.get_child_count() > 0:
			w.hud.overlay.get_child(0).queue_free()
	# habilidade do parceiro
	var ally := w.ally_actor()
	check(ally != null and ally.m["skills"].size() > 0, "parceiro com habilidade")
	# trabalho: horta + alocação
	st.level = 5
	st.inv.add("baga", 10)
	st.inv.add("fibra", 20)
	st.inv.add("madeira", 20)
	_place(st, "horta", BuildLogic.cell_of(w.player.global_position) + Vector2i(4, 4))
	await main._load_map("m1")
	w = main.world
	var garden: Dictionary = {}
	for b in st.buildings:
		if b["id"] == "horta":
			garden = b
	check(not garden.is_empty(), "horta existe")
	var worker := -1
	for uid in st.party:
		if WorkLogic.can_work(st.get_monster(uid), "horta"):
			worker = uid
	if worker < 0:
		var cact := MonsterLogic.create("cactuto", 6, Game.rng)
		st.add_monster(cact)
		worker = int(cact["uid"])
	check(WorkLogic.assign(st, int(garden["uid"]), worker, Game.now() - 3600)["ok"], "Eco alocado")
	w._tick_work()
	check(WorkLogic.stored_total(garden) > 0, "horta produziu")
	# viagem para as dunas
	st.has_pos = false
	await main._load_map("m2")
	check(main.world.map_id == "m2", "viajou para as Dunas")
	check(st.map_state("m2")["visited"], "Dunas visitadas")
	# perigo: sem cantil perde vida
	var hp0 := st.hp
	for i in 30:
		await get_tree().process_frame
	check(st.hp < hp0 or st.inv.has_protection("calor"), "calor causa dano sem cantil (%f -> %f)" % [hp0, st.hp])
	# cidade e capitão
	st.flags["bridge_built"] = true
	st.has_pos = false
	await main._load_map("m4")
	w = main.world
	check(w.npcs.size() >= 4, "capitães e ditador na cidade (%d)" % w.npcs.size())
	var rasha: Npc = null
	for n in w.npcs:
		if n.tid == "rasha":
			rasha = n
	check(rasha != null, "Capitã Rasha presente")
	if rasha != null:
		w._begin_battle(rasha)
		await _frames(3)
		check(w.trainer_enemy != null, "batalha começou")
		var guard := 0
		while not w.battle.is_empty() and guard < 10:
			guard += 1
			if w.trainer_enemy != null and is_instance_valid(w.trainer_enemy):
				w.trainer_enemy.take_hit(99999, 1.0, false, w.ally_actor())
			await get_tree().create_timer(1.4).timeout
		check("rasha" in st.stats["trainers"], "Rasha derrotada")
	# jaulas
	st.inv.add("pe_de_cabra", 1)
	var cages := 0
	for k in w.nodes.keys():
		var n: ResourceNode = w.nodes[k]
		if n.kind == "jaula":
			w._gather(n)
			cages += 1
			if w.hud.overlay.get_child_count() > 0:
				w.hud.overlay.get_child(0).queue_free()
	check(cages == 5 and st.flags.get("cages1_done", false), "5 jaulas abertas")
	# salvar e recarregar
	Game.save_now()
	var loaded := SaveSystem.load_state("story")
	check(loaded != null and loaded.party.size() == st.party.size(), "save/recarga consistente")
	# sandbox
	print("== SMOKE: sandbox")
	Game.new_game("sandbox")
	await main._load_map("m6")
	check(main.world.map_id == "m6", "sandbox abre mapa do Ato 2")
	check(Game.state.inv.infinite, "sandbox infinito")
	# eventos de analytics registrados
	var names: Array = Firebase.events_buffer.map(func(e): return e["name"])
	check("capture_success" in names and "map_enter" in names and "trainer_defeated" in names, "eventos de analytics")
	print("\nSMOKE: %d verificações, %d falhas" % [checks, fails.size()])
	for f in fails:
		print("  ✗ ", f)


func _perf() -> void:
	## Mede quadros por segundo em cada mapa (com renderização) — referência de desempenho.
	var st := _new_story(0.45)
	_setup_progress(st)
	for mid in ["m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8"]:
		st.flags["bridge_built"] = true
		st.flags["city1_free"] = true
		st.flags["gate2_open"] = true
		st.has_pos = false
		var t0 := Time.get_ticks_msec()
		await main._load_map(mid)
		var load_ms := Time.get_ticks_msec() - t0
		await _frames(30)
		var t1 := Time.get_ticks_msec()
		await _frames(120)
		var fps := 120000.0 / maxf(1.0, Time.get_ticks_msec() - t1)
		print("PERF %s carga=%dms fps=%.1f" % [mid, load_ms, fps])
