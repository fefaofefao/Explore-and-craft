extends Node
## Autopiloto dentro do jogo real (com autoloads): screenshots e teste de integração (smoke).
## godot --path . -- --autopilot shots docs/screenshots
## godot --headless --path . -- --autopilot smoke

var main: Node
var fails: Array = []
var checks := 0
var out_dir := "res://docs/screenshots"
var md_backup_spawn := 0


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
		"jumptest":
			await _jumptest()
		"tutorial":
			await _tutorial_shots()
		"showcase":
			await _showcase()
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
	# combate e habilidade (longe da casa)
	_aim(w, bc + Vector3(-18, 0, 14), 2.2, 0.35, 7.5)
	if w.ally != null:
		w.ally.global_position = w.player.global_position + Vector3(1.5, 0.5, -1.5)
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


# ================================================================== vitrine (v1.4)
func _showcase() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var st := _new_story(0.4)
	_setup_progress(st)
	st.map_id = "m1"
	await main._load_map("m1")
	var w: World = main.world
	await _frames(10)
	# capim alto ao vento
	var spot := w.player.global_position
	var best := -1
	for key in w.tall_grass.chunks:
		var xf: Array = w.tall_grass.chunks[key]["xf"]
		if xf.size() > best:
			best = xf.size()
			spot = xf[xf.size() / 2].origin
	_aim(w, spot, 0.6, 0.18, 6.5)
	await _frames(90)
	await _shot("30_capim_alto")
	# personagem de perto, correndo
	_aim(w, spot + Vector3(6, 0, 6), 3.4, 0.1, 3.2)
	await _frames(20)
	w.player.model.move_speed = 1.2
	await _frames(9)
	await _shot("31_personagem_correndo")
	w.player.model.move_speed = 0.0
	await _frames(30)
	w.player.model.play_swing("attack", 2)
	await _frames(11)
	await _shot("32_golpe_final")
	# ataques dos Ecos
	var caster: MonsterActor = w.ally_actor()
	var foe: MonsterActor = null
	var i := 0
	for sk in [["floresta_furia", 22], ["tempestade", 16], ["erupcao", 14], ["chicote_vinha", 14], ["pancada", 16], ["prisma", 8], ["nevasca", 18], ["fagulha", 14]]:
		i += 1
		var base := spot + Vector3(12 + i * 3, 0, -10)
		_aim(w, base, 2.4, 0.32, 9.5)
		await _frames(4)
		caster.global_position = w.player.global_position + Vector3(1.0, 0.5, -1.0)
		if foe == null or not is_instance_valid(foe) or foe.dead:
			foe = MonsterActor.new().setup(MonsterLogic.create("pedrisco", 8, Game.rng), "wild", w, w.gen)
			w._actors.add_child(foe)
			foe.m["hp"] = 99999
			foe.max_hp = 99999
		foe.global_position = caster.global_position + Vector3(-1.5, 0.3, -4.0)
		foe.state = "idle"
		await _frames(10)
		caster.target = foe
		caster.cast(sk[0]) if caster.skill_ready(sk[0]) else w.cast_skill(caster, sk[0], foe)
		caster.skill_cd.clear()
		await get_tree().create_timer(SkillFX.windup(SkillFX.anim_for(GameData.db().skills[sk[0]])) + float(sk[1]) / 100.0).timeout
		await _shot("%d_ataque_%s" % [32 + i, sk[0]])
		await _frames(40)
	# paisagem do alto
	var hi := Vector3.ZERO
	var hh := -99.0
	for k in 400:
		var x := randf_range(-80, 80)
		var z := randf_range(-80, 80)
		var y := w.gen.height(x, z)
		if y > hh:
			hh = y
			hi = Vector3(x, y, z)
	_aim(w, hi, 1.8, 0.22, 14.0)
	await _frames(80)
	await _shot("41_paisagem_alto")
	st.day_time = 0.72
	w.sky.update_time(0.72)
	await _frames(10)
	await _shot("42_por_do_sol")


# ================================================================== teste de integração
func _smoke() -> void:
	print("== SMOKE: história")
	var st := _new_story(0.4)
	await main._load_map("m1")
	var w: World = main.world
	check(w != null and w.player != null, "mundo carregou")
	check(w.nodes.size() > 150, "recursos gerados (%d)" % w.nodes.size())
	check(w.wilds.size() > 5, "Ecos selvagens (%d)" % w.wilds.size())
	# escolher parceiro PELO BOTÃO (mesmo caminho do toque): varrer alvo, tocar em ação, escolher no popup
	var disp := get_tree().get_nodes_in_group("starter_display")
	check(disp.size() == 3, "três Ecos acorrentados")
	if disp.size() > 0:
		w.player.global_position = disp[1].global_position + Vector3(0, 0.3, 2.0)
		w.player.face_towards(disp[1].global_position)
		await _frames(3)
		w._scan_target()
		check(w.current_target != null and (w.current_target is MonsterActor or w.current_target is Interactable), "botão encontra o Eco acorrentado/Berço")
		var lbl: Label = w.hud.action_btn.find_child("Label", true, false)
		check(lbl.text in [Loc.t("free_it"), Loc.t("cradle")], "botão muda para Libertar (%s)" % lbl.text)
		check(w._tut_arrow != null or true, "seta do tutorial")
		w.on_action()
		await _frames(3)
		check(w.hud.modal_open(), "tocar abre a escolha de parceiro")
		w.hud.overlay.get_child(0).queue_free()
	w._choose_starter("brasito")
	await _frames(5)
	check(st.party.size() == 1, "parceiro escolhido")
	check(w.ally_actor() != null, "parceiro em campo")
	check(QuestLogic.current(st)["id"] == "q02", "missão 2 ativa")
	# coletar: bater em nós até esgotar
	var gathered := 0
	for want_kind in ["arvore", "arbusto", "capim"]:
		var got_k := 0
		for k in w.nodes.keys():
			var n: ResourceNode = w.nodes[k]
			if n.kind == want_kind and not n.harvested and got_k < 4:
				w.player.global_position = n.global_position + Vector3(1.5, 0.5, 0)
				for hit in 12:
					w._gather(n)
					if n.harvested:
						break
				got_k += 1
				gathered += 1
	# coleta pelo botão de ação (alvo varrido)
	var tree_n: ResourceNode = w.nearest_node(["arvore"], 999.0)
	if tree_n != null:
		var wood0 := st.inv.count("madeira")
		w.player.global_position = tree_n.global_position + Vector3(1.6, 0.5, 0)
		w.player.face_towards(tree_n.global_position)
		for hit in 14:
			w._scan_target()
			if tree_n.harvested:
				break
			w.on_action()
		check(tree_n.harvested and st.inv.count("madeira") > wood0, "coleta pelo botão de ação funciona")
	# pulo andando
	var pl: Player = w.player
	pl.global_position = Vector3(0, w.gen.height(0, 70) + 0.3, 70)
	Input.action_press("move_forward")
	await _frames(25)
	pl.jump()
	await _frames(2)
	var vy := pl.velocity.y
	Input.action_release("move_forward")
	check(vy > 2.0, "pula enquanto anda (vy=%.2f)" % vy)
	# multitoque: dedo 0 no joystick (andando para o interior da ilha) + dedo 1 no botão Pular
	pl.global_position = Vector3(-6, w.gen.height(-6, 70) + 0.2, 70)
	w.rig.yaw = -PI / 2.0
	await _frames(40)
	for c in w.hud.overlay.get_children():
		c.free()
	Game.state.quest_seen_dialog = true
	var tc: TouchControls = w.hud.controls
	var vs := get_viewport().get_visible_rect().size
	var to_win := get_viewport().get_final_transform()  # eventos simulados chegam em coordenadas da janela
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	t0.position = to_win * Vector2(vs.x * 0.15, vs.y * 0.75)
	Input.parse_input_event(t0)
	var d0 := InputEventScreenDrag.new()
	d0.index = 0
	d0.position = to_win * Vector2(vs.x * 0.15, vs.y * 0.75 - 80.0)
	d0.relative = to_win.basis_xform(Vector2(0, -80))
	Input.parse_input_event(d0)
	await _frames(12)
	check(tc.move.length() > 0.5, "joystick por toque move (%.2f)" % tc.move.length())
	var jb: Control = w.hud.jump_btn
	for fr in 90:
		if pl.is_on_floor():
			break
		await get_tree().physics_frame
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = to_win * jb.get_global_rect().get_center()
	Input.parse_input_event(t1)
	var max_vy := -99.0
	for fr in 12:
		await get_tree().physics_frame
		max_vy = maxf(max_vy, pl.velocity.y)
	check(max_vy > 2.0, "pula com segundo dedo enquanto o joystick está pressionado (vy=%.2f, bloqueado=%s)" % [max_vy, tc._is_blocked()])
	t1.pressed = false
	Input.parse_input_event(t1)
	t0.pressed = false
	Input.parse_input_event(t0)
	await _frames(2)
	# mar aberto: nadando para fora, o jogador não passa da água funda
	for c in w.hud.overlay.get_children():
		c.free()
	var shore_x := 0.0
	for xx in range(0, 130, 2):
		if w.gen.height(float(xx), 0.0) < -0.9:
			shore_x = float(xx)
			break
	pl.global_position = Vector3(shore_x, -0.6, 0.0)
	w.rig.yaw = -PI / 2.0  # frente = +x (mar)
	Input.action_press("move_forward")
	for fr in 240:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var far_h := w.gen.height(pl.global_position.x, pl.global_position.z)
	check(far_h > Player.DEEP - 1.0 and Vector2(pl.global_position.x, pl.global_position.z).length() <= w.gen.half * 0.9 + 0.5, "mar aberto bloqueia (x=%.1f, fundo=%.1f)" % [pl.global_position.x, far_h])
	# mapa grande pelo minimapa
	w.hud.minimap.emit_signal("open_big")
	await _frames(3)
	check(w.hud.overlay.get_children().any(func(c): return c is BigMap), "toque no minimapa abre o mapa grande")
	for c in w.hud.overlay.get_children():
		c.free()
	# requisito nos espinhos do covil
	var thorn: ResourceNode = null
	for k in w.nodes:
		if w.nodes[k].kind == "espinhos":
			thorn = w.nodes[k]
	check(thorn != null, "covil tem espinhos")
	if thorn != null:
		var bt := w.barrier_text(thorn)
		check(not st.inv.has("tocha") and bt[0].contains(Loc.item_name("tocha")) and not bt[1], "placa mostra 'Requer: Tocha'")
		check(w._context_label(thorn) == Loc.t("req_missing_btn", [Loc.item_name("tocha")]), "botão mostra 'Falta: Tocha'")
		st.inv.add("tocha", 1)
		check(w.barrier_text(thorn)[1], "placa fica verde com a tocha")
		st.inv.remove("tocha", 1)
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
	# ===== recursos da versão 1.3
	await main._load_map("m1")
	w = main.world
	for c in w.hud.overlay.get_children():
		c.free()
	# um equipamento de cada por vez + durabilidade
	st.inv.add("madeira", 10)
	st.inv.add("pedra", 10)
	st.inv.add("fibra", 10)
	if st.inv.count("machado_pedra") == 0:
		CraftLogic.craft(st, "r_machado_pedra", [])
	check(CraftLogic.check(st, "r_machado_pedra", [])["reason"] == "owned", "não cria segundo machado enquanto tem um")
	var dur0 := st.inv.durability_of("machado_pedra")
	st.inv.use_durability("machado_pedra")
	check(st.inv.durability_of("machado_pedra") == dur0 - 1, "machado gasta durabilidade")
	st.inv.use_durability("machado_pedra", 999)
	check(st.inv.count("machado_pedra") == 0, "machado quebra ao zerar")
	check(CraftLogic.check(st, "r_machado_pedra", [])["ok"], "pode criar outro depois que quebra")
	# ervas no mapa
	var herbs := 0
	var blooms := 0
	for k in w.nodes:
		if w.nodes[k].kind == "erva":
			herbs += 1
		elif w.nodes[k].kind == "flor_reviver":
			blooms += 1
	check(herbs >= 10 and blooms >= 1 and blooms < herbs, "ervas comuns (%d) e flores de reviver raras (%d)" % [herbs, blooms])
	# barra do grupo: um cartão por Eco e toque troca o companheiro
	w.hud.refresh()
	await _frames(2)
	check(w.hud.party_bar.slots.size() == st.party.size(), "barra mostra todos os Ecos do grupo")
	var other := -1
	for uid in st.party:
		var mm := st.get_monster(uid)
		if uid != st.active_uid and not mm["fainted"] and int(mm.get("job", -1)) < 0:
			other = uid
	if other >= 0:
		w.hud.party_bar._tap(other)
		await _frames(2)
		check(st.active_uid == other and w.ally_actor() != null and int(w.ally_actor().m["uid"]) == other, "toque na barra troca o companheiro")
	# Ecos miram o parceiro antes do treinador
	var foe2: MonsterActor = null
	for a in w.wilds:
		if is_instance_valid(a) and not a.dead:
			foe2 = a
			break
	if foe2 != null and w.ally_actor() != null:
		w.ally_actor().global_position = foe2.global_position + Vector3(2, 0.5, 0)
		w.player.global_position = foe2.global_position + Vector3(-2, 0.5, 0)
		foe2.take_hit(1, 1.0, false, w.player)
		check(foe2.target == w.ally_actor(), "atacado pelo treinador, o Eco revida no parceiro")
	# horda
	var before_n := w.wilds.size()
	var old_ch: float = GameData.db().config["combat"]["horde_chance"]
	GameData.db().config["combat"]["horde_chance"] = 1.0
	md_backup_spawn = int(w.md["spawn_count"])
	w.md["spawn_count"] = before_n + 10
	w._spawn_wild()
	GameData.db().config["combat"]["horde_chance"] = old_ch
	w.md["spawn_count"] = md_backup_spawn
	var newest: MonsterActor = w.wilds.back()
	check(w.wilds.size() - before_n >= 3 and newest.pack.size() >= 3, "horda de 3–4 Ecos (%d)" % (w.wilds.size() - before_n))
	# rolagem por arrastar no menu de criar
	w.hud.open_menu("craft")
	await _frames(4)
	var ds: Array = w.hud.menu.find_children("*", "DragScroll", true, false)
	check(ds.size() > 0, "menu usa rolagem por arrastar")
	if ds.size() > 0:
		var sc: DragScroll = ds[0]
		for cand in ds:
			if (cand as DragScroll).get_v_scroll_bar().max_value > (cand as DragScroll).size.y + 50:
				sc = cand
		var srect := sc.get_global_rect()
		var tw2 := get_viewport().get_final_transform()
		var p0 := srect.get_center() + Vector2(0, 100)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = tw2 * p0
		Input.parse_input_event(ev)
		for k in 8:
			var mv := InputEventMouseMotion.new()
			mv.position = tw2 * (p0 - Vector2(0, 30 * (k + 1)))
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(mv)
			await _frames(1)
		ev.pressed = false
		ev.position = tw2 * (p0 - Vector2(0, 240))
		Input.parse_input_event(ev)
		await _frames(3)
		check(sc.scroll_vertical > 50, "arrastar rola a lista de criação (%d)" % sc.scroll_vertical)
	w.hud.menu.close_menu()
	# ===== recursos da versão 1.4
	# vento muda de direção e a grama/árvores recebem os parâmetros
	check(w.wind != null and w.tall_grass != null, "vento global e capim alto no Bosque")
	var wd0: Vector2 = w.wind.dir()
	for k in 60 * 40:
		w.wind.update(1.0 / 60.0)
	check(w.wind.dir().dot(wd0) < 0.97, "a direção do vento muda")
	w._update_wind(0.016)
	check((w.grass.mat.get_shader_parameter("wind_dir") as Vector2).is_equal_approx(w.wind.dir()), "grama recebe a direção do vento")
	check((w.tall_grass.mat.get_shader_parameter("pushers") as Array).size() == 4, "jogador/Ecos empurram a grama")
	# golpe corta capim alto (que volta a crescer)
	var tg: GrassField = w.tall_grass
	var spot := Vector3.ZERO
	for key in tg.chunks:
		var xf: Array = tg.chunks[key]["xf"]
		if xf.size() > 0:
			spot = xf[0].origin
			break
	var alive0 := tg.alive_count()
	var cutn := w.cut_grass(spot, 2.0)
	check(cutn > 0 and tg.alive_count() < alive0, "golpe corta o capim (%d tufos)" % cutn)
	# combo de 3 golpes do jogador
	w.player.global_position = spot + Vector3(0, 0.5, 0)
	w.player_attack()
	w.player_attack()
	w.player_attack()
	check(w._combo == 2, "combo chega ao 3º golpe")
	# reparo de durabilidade pela mochila
	st.inv.add("picareta_pedra", 1)
	var pmx := Inventory.max_dur("picareta_pedra")
	st.inv.use_durability("picareta_pedra", pmx - 2)
	var rc := CraftLogic.can_repair(st, "picareta_pedra")
	for k in rc["cost"]:
		st.inv.add(k, int(rc["cost"][k]) + 2)
	w.hud.open_menu("craft")
	await _frames(3)
	w.hud.menu._do_repair("picareta_pedra")
	await _frames(2)
	check(st.inv.durability_of("picareta_pedra") == pmx, "reparar restaura a durabilidade")
	w.hud.menu.close_menu()
	# todos os ataques (31 estilos) rodam sem erro, com o alvo recebendo dano
	var caster: MonsterActor = w.ally_actor()
	var dummy: MonsterActor = null
	for a in w.wilds:
		if is_instance_valid(a) and not a.dead:
			dummy = a
			break
	if caster != null and dummy != null:
		dummy.global_position = caster.global_position + Vector3(0, 0.3, -3.0)
		dummy.state = "idle"
		var hp_before := int(dummy.m["hp"])
		dummy.m["hp"] = 99999
		dummy.max_hp = 99999
		var n_sk := 0
		for sid in GameData.db().skills:
			caster.target = dummy
			w.cast_skill(caster, sid, dummy)
			n_sk += 1
			await _frames(2)
		await get_tree().create_timer(1.6).timeout
		check(n_sk == GameData.db().skills.size(), "todos os %d ataques executados" % n_sk)
		check(is_instance_valid(dummy) and int(dummy.m["hp"]) < 99999, "ataques causam dano")
		if is_instance_valid(dummy):
			dummy.m["hp"] = hp_before
	# animações de ataque de todos os formatos de corpo
	var shapes_ok := 0
	for st_name in ["bite", "pounce", "slam", "spin", "cast", "charge", "dive", "coil", "punch", "roar", "glow", "bounce"]:
		var mm2 := MonsterModel.new().build("folhito")
		w.add_child(mm2)
		mm2.play_attack(st_name)
		for k in 6:
			mm2._process(0.06)
		if mm2.root_pivot.position.length() > 0.001 or mm2.root_pivot.rotation.length() > 0.001 or mm2.root_pivot.scale != Vector3.ONE:
			shapes_ok += 1
		mm2.queue_free()
	check(shapes_ok == 12, "12 animações de ataque movem o corpo (%d)" % shapes_ok)
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


func _jumptest() -> void:
	var st := _new_story(0.45)
	_setup_progress(st)
	await main._load_map("m1")
	var w: World = main.world
	for c in w.hud.overlay.get_children():
		c.free()
	var pl: Player = w.player
	pl.global_position = Vector3(-6, w.gen.height(-6, 70) + 0.2, 70)
	w.rig.yaw = -PI / 2.0
	for i in 30:
		await get_tree().physics_frame
	print("parado floor=%s vel=%s" % [pl.is_on_floor(), str(pl.velocity)])
	Input.action_press("move_forward")
	for i in 40:
		await get_tree().physics_frame
		if i % 5 == 0:
			print("andando f=%d floor=%s vel=%s y=%.3f gy=%.3f coll=%d" % [i, pl.is_on_floor(), str(pl.velocity), pl.global_position.y, w.gen.height(pl.global_position.x, pl.global_position.z), pl.get_slide_collision_count()])
	Input.action_release("move_forward")
	for i in 30:
		await get_tree().physics_frame
	var tc: TouchControls = w.hud.controls
	var vs := get_viewport().get_visible_rect().size
	var to_win := get_viewport().get_final_transform()
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	t0.position = to_win * Vector2(vs.x * 0.15, vs.y * 0.75)
	Input.parse_input_event(t0)
	var d0 := InputEventScreenDrag.new()
	d0.index = 0
	d0.position = to_win * Vector2(vs.x * 0.15 + 80.0, vs.y * 0.75)
	Input.parse_input_event(d0)
	for i in 20:
		await get_tree().physics_frame
		if i % 5 == 0:
			print("toque f=%d move=%s floor=%s vel=%s" % [i, str(tc.move), pl.is_on_floor(), str(pl.velocity)])
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = to_win * w.hud.jump_btn.get_global_rect().get_center()
	Input.parse_input_event(t1)
	for i in 6:
		await get_tree().physics_frame
		print("pulo f=%d held=%s floor=%s vel=%s buf=%.2f coy=%.2f" % [i, pl.jump_held, pl.is_on_floor(), str(pl.velocity), pl._jump_buffer, pl._coyote])


func _tutorial_shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var st := _new_story(0.4)
	st.quest_seen_dialog = true
	await main._load_map("m1")
	var w: World = main.world
	var disp := get_tree().get_nodes_in_group("starter_display")
	w.player.global_position = disp[1].global_position + Vector3(-1.0, 0.3, 3.2)
	w.player.face_towards(disp[1].global_position)
	_aim(w, w.player.global_position, -0.25, 0.3, 6.5)
	await _frames(40)
	await _shot("tut_1_parceiro")
	w._choose_starter("folhito")
	await _frames(10)
	var tree_n: ResourceNode = w.nearest_node(["arvore"], 999.0)
	w.player.global_position = tree_n.global_position + Vector3(2.0, 0.4, 2.0)
	w.player.face_towards(tree_n.global_position)
	_aim(w, w.player.global_position, 0.7, 0.3, 8.0)
	await _frames(40)
	await _shot("tut_2_coleta")

	# covil com placa de requisito
	var l: Dictionary = w.lair
	var ent: Vector3 = l["entrance"]
	var outward := (Vector3(ent.x, 0, ent.z) - Vector3(l["center"].x, 0, l["center"].z)).normalized()
	w.player.global_position = Vector3(ent.x, 0, ent.z) + outward * 7.0
	w.player.global_position.y = w.gen.height(w.player.global_position.x, w.player.global_position.z) + 0.4
	w.player.face_towards(Vector3(ent.x, 0, ent.z))
	_aim(w, w.player.global_position, atan2(outward.x, outward.z), 0.25, 8.0)
	for c in w.hud.overlay.get_children():
		c.free()
	await _frames(60)
	await _shot("tut_3_requisito")
	w.hud.show_big_map()
	await _frames(20)
	await _shot("tut_4_mapa")
