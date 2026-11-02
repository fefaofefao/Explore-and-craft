class_name GameMenu
extends Control
## Menu principal em abas (tela cheia) + telas de estação, baú, construção e expedições.

var hud: Hud
var tab := "inventory"
var tabs_box: VBoxContainer
var content: VBoxContainer
var title: Label
var _sel_slot := -1
var _station: Structure
var _chest: Structure
var _echo_sel := -1
var _quest_tab := "story"

const TABS := [
	["inventory", "tab_inventory", "▣"], ["craft", "tab_craft", "⚒"], ["echoes", "tab_echoes", "✦"],
	["quests", "tab_quests", "!"], ["dex", "tab_dex", "◉"], ["memories", "tab_memories", "❖"],
	["map", "tab_map", "⌖"], ["shop", "tab_shop", "◆"], ["pass", "tab_pass", "★"], ["settings", "tab_settings", "⚙"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var main := HBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 18
	main.offset_top = 18
	main.offset_right = -18
	main.offset_bottom = -18
	main.add_theme_constant_override("separation", 16)
	add_child(main)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.07, 0.09, 0.13, 0.95), 22))
	left.custom_minimum_size = Vector2(210, 0)
	main.add_child(left)
	tabs_box = VBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 6)
	left.add_child(Widgets.scroll(tabs_box))
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.07, 0.09, 0.13, 0.95), 22))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	var top := HBoxContainer.new()
	rv.add_child(top)
	title = UiTheme.label("", 32, UiTheme.GOLD, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var money := UiTheme.label("", 22, UiTheme.GOLD, 900)
	money.name = "Money"
	top.add_child(money)
	var close := UiTheme.button("✕", UiTheme.DANGER.darkened(0.35), 26, Vector2(64, 56))
	close.pressed.connect(close_menu)
	top.add_child(close)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(content)
	visible = false


func open(p_tab: String) -> void:
	tab = p_tab
	_station = null
	_chest = null
	visible = true
	get_tree().paused = false
	refresh()


func open_station(s: Structure) -> void:
	_station = s
	tab = "station"
	visible = true
	refresh()


func open_chest(s: Structure) -> void:
	_chest = s
	tab = "chest"
	visible = true
	refresh()


func close_menu() -> void:
	visible = false
	Game.save_now()
	hud.refresh()


func refresh() -> void:
	if not visible:
		return
	var st: GameState = Game.state
	(find_child("Money", true, false) as Label).text = "● %d   ◆ %d" % [st.coins, st.gems]
	for c in tabs_box.get_children():
		c.queue_free()
	for t in TABS:
		if t[0] in ["pass", "shop"] and st.is_sandbox():
			continue
		var b := UiTheme.button("%s  %s" % [t[2], Loc.t(t[1])], UiTheme.ACCENT.darkened(0.45) if tab == t[0] else UiTheme.BG2, 21, Vector2(0, 58))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			_sel_slot = -1
			refresh())
		var badge := _badge(key)
		if badge > 0:
			b.text += "  (%d)" % badge
		tabs_box.add_child(b)
	for c in content.get_children():
		c.queue_free()
	match tab:
		"inventory":
			_tab_inventory()
		"craft":
			_tab_craft()
		"echoes":
			_tab_echoes()
		"quests":
			_tab_quests()
		"dex":
			_tab_dex()
		"memories":
			_tab_memories()
		"map":
			_tab_map()
		"shop":
			_tab_shop()
		"pass":
			_tab_pass()
		"settings":
			_tab_settings()
		"build":
			_tab_build()
		"station":
			_tab_station()
		"chest":
			_tab_chest()
		"expeditions":
			_tab_expeditions()


func _badge(key: String) -> int:
	var st: GameState = Game.state
	match key:
		"quests":
			var n := 0
			for dq in st.daily.get("quests", []):
				var d := RetentionLogic.daily_def(dq["id"])
				if not dq["claimed"] and int(dq["p"]) >= int(d.get("count", 1)):
					n += 1
			return n
		"pass":
			return RetentionLogic.pass_claimable(st)
		"dex":
			return RetentionLogic.dex_claimable(st).size()
	return 0


# ================================================================== Mochila
func _tab_inventory() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_inventory")
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var sc := Widgets.scroll(grid)
	sc.custom_minimum_size = Vector2(580, 0)
	sc.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(sc)
	for i in st.inv.slots.size():
		var s: Dictionary = st.inv.slots[i]
		var slot := Widgets.item_slot(s.get("id", ""), int(s.get("n", 0)), 76, i == _sel_slot, int(s.get("d", -1)))
		var idx := i
		slot.gui_input.connect(func(ev):
			if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
				_sel_slot = idx
				refresh())
		grid.add_child(slot)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(side)
	var sort := UiTheme.button("⇅", UiTheme.BG2, 22, Vector2(64, 54))
	sort.pressed.connect(func():
		st.inv.sort_slots()
		_sel_slot = -1
		refresh())
	side.add_child(sort)
	side.custom_minimum_size = Vector2(240, 0)
	if _sel_slot < 0 or _sel_slot >= st.inv.slots.size() or st.inv.slots[_sel_slot].is_empty():
		var tip := UiTheme.label(Loc.t("tip_gather"), 18, UiTheme.MUTED, 700)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(tip)
		return
	var s: Dictionary = st.inv.slots[_sel_slot]
	var it: Dictionary = GameData.db().item(s["id"])
	var nm := UiTheme.label(Loc.item_name(s["id"]), 28, Color.WHITE, 900)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(nm)
	side.add_child(UiTheme.label(Loc.t("cat_" + it["cat"]), 18, UiTheme.ACCENT, 800))
	var d := UiTheme.label(Loc.tx(it["desc"]), 19, UiTheme.TEXT, 700)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(d)
	if Inventory.max_dur(s["id"]) > 0:
		side.add_child(UiTheme.label(Loc.t("durability", [int(s.get("d", Inventory.max_dur(s["id"]))), Inventory.max_dur(s["id"])]), 18, UiTheme.GOLD, 800))
		var rep := CraftLogic.can_repair(st, s["id"])
		if rep["reason"] in ["", "missing"]:
			side.add_child(Widgets.cost_row(rep["cost"], st.inv, 16))
			var rb := UiTheme.button("🔧 " + Loc.t("repair"), UiTheme.GOLD.darkened(0.45) if rep["ok"] else UiTheme.BG2)
			rb.disabled = not rep["ok"]
			var rid0: String = s["id"]
			rb.pressed.connect(func(): _do_repair(rid0))
			side.add_child(rb)
	if it.has("food"):
		var b := UiTheme.button(Loc.t("eat"), UiTheme.GOOD.darkened(0.45))
		b.pressed.connect(func():
			if SurvivalLogic.eat(st, s["id"]):
				Audio.play("eat")
				hud.refresh()
			refresh())
		side.add_child(b)
	if it.has("heal_monster"):
		var b2 := UiTheme.button(Loc.t("use"), UiTheme.GOOD.darkened(0.45))
		b2.pressed.connect(func(): _use_heal_item(s["id"]))
		side.add_child(b2)
	if int(it.get("value", 0)) > 0 and it["cat"] != "chave" and _merchant_near():
		var b3 := UiTheme.button(Loc.t("sell_for", [int(it["value"]) * int(s["n"])]), UiTheme.GOLD.darkened(0.45))
		b3.pressed.connect(func():
			st.coins += int(it["value"]) * int(s["n"])
			st.inv.slots[_sel_slot] = {}
			Audio.play("coin")
			refresh())
		side.add_child(b3)
	if it["cat"] != "chave":
		var b4 := UiTheme.button(Loc.t("drop"), UiTheme.BG2)
		b4.pressed.connect(func():
			st.inv.slots[_sel_slot] = {}
			_sel_slot = -1
			refresh())
		side.add_child(b4)


func _merchant_near() -> bool:
	if hud.world == null:
		return false
	for n in hud.world.npcs:
		if is_instance_valid(n) and n.kind == "merchant" and n.global_position.distance_to(hud.world.player.global_position) < 12.0:
			return true
	return false


func _use_heal_item(id: String) -> void:
	var st: GameState = Game.state
	var hm: Dictionary = GameData.db().item(id)["heal_monster"]
	var target: Dictionary = {}
	for m in st.party_monsters():
		if hm["revive"] and m["fainted"]:
			target = m
			break
		if not hm["revive"] and not m["fainted"] and int(m["hp"]) < MonsterLogic.max_hp(m) and (target.is_empty() or int(m["uid"]) == st.active_uid):
			target = m
	if target.is_empty():
		Game.notify(Loc.t("no_target"), "warn")
		return
	st.inv.remove(id, 1)
	MonsterLogic.heal(target, float(hm["hp"]), hm["revive"])
	if hud.world.ally != null and is_instance_valid(hud.world.ally) and hud.world.ally.m == target:
		hud.world.ally.heal_frac(0.0)
	elif hud.world.ally_actor() == null:
		hud.world._spawn_ally()
	Audio.play("heal")
	refresh()
	hud.refresh()


# ================================================================== Criar
func _tab_craft() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_craft")
	var near := BuildLogic.stations_near(st, hud.world.map_id, hud.world.player.global_position)
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	var shown := 0
	for station in ["mao", "bancada", "fogueira", "fornalha", "forja", "arcana"]:
		var rids := CraftLogic.recipes_for(station)
		var header := UiTheme.label(Loc.t("station_" + station) + ("" if station == "mao" or station in near or st.is_sandbox() else "  —  " + Loc.t("needs_station", [Loc.t("station_" + station)])),
			22, UiTheme.ACCENT if station == "mao" or station in near or st.is_sandbox() else UiTheme.MUTED, 900)
		list.add_child(header)
		for rid in rids:
			var r: Dictionary = GameData.db().recipes[rid]
			var unlocked := CraftLogic.recipe_unlocked(st, rid)
			if not unlocked and int(r["lvl"]) > st.level + 3:
				continue
			list.add_child(_recipe_row(rid, near))
			shown += 1


func _recipe_row(rid: String, near: Array) -> Control:
	var st: GameState = Game.state
	var r: Dictionary = GameData.db().recipes[rid]
	var chk := CraftLogic.check(st, rid, near)
	var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.9) if chk["ok"] else Color(0.1, 0.11, 0.14, 0.85), 16)
	var h := HBoxContainer.new()
	c.add_child(h)
	h.add_child(Widgets.item_slot(r["out"], int(r["n"]), 72))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiTheme.label("%s%s" % [Loc.item_name(r["out"]), (" ×%d" % r["n"]) if int(r["n"]) > 1 else ""], 22, Color.WHITE, 900))
	if not CraftLogic.recipe_unlocked(st, rid):
		v.add_child(UiTheme.label(Loc.t("needs_level", [r["lvl"]]), 17, UiTheme.DANGER, 800))
	elif chk["reason"] == "owned":
		var ol := UiTheme.label(Loc.t("already_owned", [Loc.item_name(r["out"])]) + "  " + Loc.t("durability", [st.inv.durability_of(r["out"]), Inventory.max_dur(r["out"])]) if Inventory.max_dur(r["out"]) > 0 else Loc.t("already_owned", [Loc.item_name(r["out"])]), 16, UiTheme.GOLD, 800)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ol)
	else:
		v.add_child(Widgets.cost_row(r["in"], st.inv, 16))
	if chk["reason"] == "owned":
		var rep := CraftLogic.can_repair(st, r["out"])
		if rep["reason"] in ["", "missing"]:
			v.add_child(Widgets.cost_row(rep["cost"], st.inv, 16))
			var rb := UiTheme.button(Loc.t("repair"), UiTheme.GOLD.darkened(0.45) if rep["ok"] else UiTheme.BG2, 20, Vector2(120, 58))
			rb.disabled = not rep["ok"]
			rb.pressed.connect(func(): _do_repair(r["out"]))
			h.add_child(rb)
			return c
	var b := UiTheme.button(Loc.t("craft"), UiTheme.GOOD.darkened(0.45) if chk["ok"] else UiTheme.BG2, 20, Vector2(120, 58))
	b.disabled = not chk["ok"]
	b.pressed.connect(func(): _do_craft(rid, near, 1))
	h.add_child(b)
	var mx := CraftLogic.max_times(st, rid)
	if chk["ok"] and mx >= 5 and GameData.db().item(r["out"]).get("stack", 99) > 1:
		var b5 := UiTheme.button("×5", UiTheme.GOOD.darkened(0.5), 20, Vector2(72, 58))
		b5.pressed.connect(func(): _do_craft(rid, near, 5))
		h.add_child(b5)
	return c


func _do_repair(item_id: String) -> void:
	var r := CraftLogic.repair(Game.state, item_id)
	if r["ok"]:
		Audio.play("build")
		Game.notify(Loc.t("repaired", [Loc.item_name(item_id)]), "item")
		Firebase.log_event("repair", {"item": item_id})
	else:
		Audio.play("error")
	hud.refresh()
	refresh()


func _do_craft(rid: String, near: Array, times: int) -> void:
	var st: GameState = Game.state
	var r := CraftLogic.craft(st, rid, near, times)
	if r["ok"]:
		Audio.play("craft")
		Game.notify(Loc.t("crafted", [Loc.item_name(r["out"])]) + (" ×%d" % r["n"] if int(r["n"]) > 1 else ""), "item")
		Game.add_xp(0)
		Game.on_craft(r["out"], int(r["n"]))
		hud.world._update_held()
	else:
		Audio.play("error")
	refresh()
	hud.refresh()


# ================================================================== Ecos
func _tab_echoes() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_echoes")
	var harmony := MonsterLogic.harmony_bonus(st.party_types())
	if harmony > 0.0:
		content.add_child(UiTheme.label("♫ " + Loc.t("harmony", [int(harmony * 100)]), 20, UiTheme.GOOD, 900))
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(h)
	var list := VBoxContainer.new()
	var sc := Widgets.scroll(list)
	sc.custom_minimum_size = Vector2(480, 0)
	h.add_child(sc)
	list.add_child(UiTheme.label("%s (%d/%d)" % [Loc.t("party"), st.party.size(), int(GameData.db().cfg("capture", "max_party", 5))], 22, UiTheme.ACCENT, 900))
	for uid in st.party:
		list.add_child(_echo_row(uid))
	list.add_child(UiTheme.label("%s (%d/%d)" % [Loc.t("box"), st.box.size(), st.box_capacity], 22, UiTheme.ACCENT, 900))
	for uid in st.box:
		list.add_child(_echo_row(uid))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(Widgets.scroll(detail))
	if _echo_sel < 0 or st.get_monster(_echo_sel).is_empty():
		_echo_sel = st.active_uid if st.active_uid >= 0 else (st.party[0] if st.party.size() > 0 else -1)
	if _echo_sel >= 0:
		_echo_detail(detail, st.get_monster(_echo_sel))


func _echo_row(uid: int) -> Control:
	var st: GameState = Game.state
	var m := st.get_monster(uid)
	var sel := uid == _echo_sel
	var c := Widgets.card(Color(0.16, 0.22, 0.28, 0.95) if sel else Color(0.12, 0.15, 0.2, 0.9), 16)
	var h := HBoxContainer.new()
	c.add_child(h)
	var pt := Portrait.make(m["sp"], m.get("variant", false), 64)
	h.add_child(pt)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := "%s%s  %s" % ["★ " if uid == st.active_uid else "", MonsterLogic.display_name(m), Loc.t("level_short", [m["lvl"]])]
	if m.get("variant", false):
		nm += "  ✦"
	v.add_child(UiTheme.label(nm, 20, Color.WHITE, 900))
	var status := ""
	if m["fainted"]:
		status = Loc.t("fainted")
	elif int(m.get("job", -1)) >= 0:
		var b := st.get_building(int(m["job"]))
		status = Loc.t("working_at", [Loc.tx(GameData.db().buildings[b["id"]]["name"])]) if not b.is_empty() else ""
	elif m.get("expedition", false):
		status = Loc.t("on_expedition")
	var hb := Widgets.bar(UiTheme.DANGER if m["fainted"] else UiTheme.GOOD, 10, 180)
	hb.value = float(m["hp"]) / maxf(1.0, MonsterLogic.max_hp(m)) * 100.0
	v.add_child(hb)
	if status != "":
		v.add_child(UiTheme.label(status, 15, UiTheme.MUTED, 800))
	c.gui_input.connect(func(ev):
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			_echo_sel = uid
			refresh())
	return c


func _echo_detail(v: VBoxContainer, m: Dictionary) -> void:
	var st: GameState = Game.state
	var sp: Dictionary = GameData.db().sp(m["sp"])
	var top := HBoxContainer.new()
	v.add_child(top)
	var pt := Portrait.make(m["sp"], m.get("variant", false), 190, true)
	top.add_child(pt)
	var info := VBoxContainer.new()
	top.add_child(info)
	info.add_child(UiTheme.label(MonsterLogic.display_name(m), 30, UiTheme.GOLD if m.get("variant", false) else Color.WHITE, 900))
	var chips := HBoxContainer.new()
	for t in sp["types"]:
		chips.add_child(UiTheme.type_chip(t))
	info.add_child(chips)
	info.add_child(UiTheme.label("%s  ·  %s  ·  %s" % [Loc.t("level_short", [m["lvl"]]), Loc.t("talent", [int(float(m["talent"]) * 100)]), Loc.t("bond", [m.get("bond", 0)])], 18, UiTheme.MUTED, 800))
	var xpb := Widgets.bar(UiTheme.ACCENT, 8, 260)
	xpb.value = float(m["xp"]) / maxf(1.0, MonsterLogic.xp_to_next(int(m["lvl"]))) * 100.0
	info.add_child(xpb)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 18)
	v.add_child(g)
	for s in [["st_hp", MonsterLogic.max_hp(m)], ["st_atk", MonsterLogic.stat(m, "atk")], ["st_def", MonsterLogic.stat(m, "def")], ["st_spd", MonsterLogic.stat(m, "spd")]]:
		g.add_child(UiTheme.label("%s %d" % [Loc.t(s[0]), s[1]], 19, Color.WHITE, 800))
	v.add_child(UiTheme.label(Loc.t("skills"), 20, UiTheme.ACCENT, 900))
	var sk_h := HBoxContainer.new()
	v.add_child(sk_h)
	for s in m["skills"]:
		var sk: Dictionary = GameData.db().skills[s]
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiTheme.panel_box(FX.type_color(sk["type"]).darkened(0.45), 12))
		chip.add_child(UiTheme.label("%s %d" % [Loc.tx(sk["name"]), int(sk["power"])], 16, Color.WHITE, 800))
		sk_h.add_child(chip)
	var works: Array = []
	for w in sp["work"]:
		works.append("%s %d" % [Loc.t("w_" + w), int(sp["work"][w])])
	v.add_child(UiTheme.label("%s: %s" % [Loc.t("work"), ", ".join(works)], 18, UiTheme.TEXT, 800))
	var lore := UiTheme.label(Loc.tx(sp["lore"]), 17, UiTheme.MUTED, 700)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lore)
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 8)
	v.add_child(acts)
	var uid := int(m["uid"])
	if uid in st.party:
		if uid != st.active_uid and not m["fainted"] and int(m.get("job", -1)) < 0:
			var b := UiTheme.button(Loc.t("set_active"), UiTheme.ACCENT.darkened(0.4), 20, Vector2(140, 56))
			b.pressed.connect(func():
				hud.world.switch_ally(uid)
				refresh())
			acts.add_child(b)
		var b2 := UiTheme.button(Loc.t("to_box"), UiTheme.BG2, 20, Vector2(160, 56))
		b2.disabled = st.party.size() <= 1
		b2.pressed.connect(func():
			st.move_to_box(uid)
			if hud.world.ally != null and is_instance_valid(hud.world.ally) and int(hud.world.ally.m["uid"]) == uid:
				hud.world._spawn_ally()
			refresh())
		acts.add_child(b2)
	else:
		var b3 := UiTheme.button(Loc.t("to_party"), UiTheme.ACCENT.darkened(0.4), 20, Vector2(160, 56))
		b3.pressed.connect(func():
			if not st.move_to_party(uid):
				Game.notify(Loc.t("party_full", [GameData.db().cfg("capture", "max_party", 5)]), "warn")
			elif hud.world.ally_actor() == null:
				hud.world._spawn_ally()
			refresh())
		acts.add_child(b3)
	var today := RetentionLogic.date_key(Game.now())
	var bp := UiTheme.button("♥ " + Loc.t("pet"), Color("#c84a7a"), 20, Vector2(140, 56))
	bp.disabled = m.get("pet_day", "") == today
	bp.pressed.connect(func():
		m["pet_day"] = today
		MonsterLogic.add_bond(m, int(GameData.db().cfg("bond", "pet_xp", 25)))
		Game.on_pet()
		Audio.play("happy")
		Game.notify(Loc.t("pet_done", [MonsterLogic.display_name(m)]), "info")
		if hud.world.ally != null and is_instance_valid(hud.world.ally) and hud.world.ally.m == m:
			hud.world.ally.model.play_happy()
		refresh())
	acts.add_child(bp)
	var food := ""
	for f in ["baga", "carne_assada", "suco_baga", "ensopado", "cogumelo"]:
		if st.inv.has(f):
			food = f
			break
	var bf := UiTheme.button(Loc.t("feed"), Color("#c8a04a").darkened(0.3), 20, Vector2(140, 56))
	bf.disabled = food == ""
	bf.pressed.connect(func():
		st.inv.remove(food, 1)
		MonsterLogic.add_bond(m, int(GameData.db().cfg("bond", "feed_xp", 15)))
		MonsterLogic.heal(m, 0.3)
		Audio.play("eat")
		refresh())
	acts.add_child(bf)
	var br := UiTheme.button(Loc.t("release"), UiTheme.DANGER.darkened(0.45), 20, Vector2(120, 56))
	br.pressed.connect(func():
		_confirm(Loc.t("release_confirm", [MonsterLogic.display_name(m)]), func():
			if st.release_monster(uid):
				_echo_sel = -1
				hud.world._spawn_ally()
			refresh()))
	acts.add_child(br)


func _confirm(text: String, yes: Callable) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var p := Widgets.card(Color(0.08, 0.1, 0.15, 0.98), 24)
	p.custom_minimum_size = Vector2(520, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := UiTheme.label(text, 22, Color.WHITE, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var by := UiTheme.button(Loc.t("yes"), UiTheme.DANGER.darkened(0.3), 22, Vector2(160, 60))
	by.pressed.connect(func():
		bg.queue_free()
		yes.call())
	h.add_child(by)
	var bn := UiTheme.button(Loc.t("no"), UiTheme.BG2, 22, Vector2(160, 60))
	bn.pressed.connect(func(): bg.queue_free())
	h.add_child(bn)


# ================================================================== Missões
func _tab_quests() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_quests")
	var tb := HBoxContainer.new()
	content.add_child(tb)
	for k in ["story", "daily"]:
		var b := UiTheme.button(Loc.t(k), UiTheme.ACCENT.darkened(0.45) if _quest_tab == k else UiTheme.BG2, 22, Vector2(180, 56))
		var kk: String = k
		b.pressed.connect(func():
			_quest_tab = kk
			refresh())
		tb.add_child(b)
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	if _quest_tab == "story":
		var qs: Array = GameData.db().quests
		var cur := st.quest_idx
		if st.is_sandbox():
			list.add_child(UiTheme.label(Loc.t("sandbox_desc"), 20, UiTheme.MUTED))
			return
		for i in range(max(0, cur - 3), min(qs.size(), cur + 1)):
			var q: Dictionary = qs[i]
			var done := i < cur
			var c := Widgets.card(Color(0.1, 0.2, 0.14, 0.9) if done else Color(0.2, 0.17, 0.06, 0.95), 16)
			var v := VBoxContainer.new()
			c.add_child(v)
			v.add_child(UiTheme.label(("✓ " if done else "▸ ") + Loc.tx(q["title"]), 22, UiTheme.GOOD if done else UiTheme.GOLD, 900))
			var d := UiTheme.label(Loc.tx(q["desc"]), 18, UiTheme.TEXT, 700)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(d)
			if not done:
				var p := QuestLogic.progress(st, q)
				v.add_child(UiTheme.label(Loc.t("progress", [p[0], p[1]]) + "  ·  " + Loc.t("reward") + ": " + Widgets.reward_text(q["reward"]), 17, UiTheme.MUTED, 800))
			list.add_child(c)
		if cur >= qs.size():
			list.add_child(UiTheme.label(Loc.t("story_complete"), 22, UiTheme.GOLD, 900))
			for fa in GameData.db().future_acts:
				list.add_child(UiTheme.label(Loc.t("act_locked", [fa["act"], Loc.tx(fa["city"])]), 18, UiTheme.MUTED, 800))
	else:
		RetentionLogic.ensure_daily(st, Game.now())
		list.add_child(UiTheme.label(Loc.t("resets_in", [Loc.fmt_time(RetentionLogic.seconds_to_next_day(Game.now()))]), 18, UiTheme.MUTED, 800))
		for dq in st.daily.get("quests", []):
			var d := RetentionLogic.daily_def(dq["id"])
			var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.9), 16)
			var h := HBoxContainer.new()
			c.add_child(h)
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(UiTheme.label(Loc.tx(d["title"]), 22, Color.WHITE, 900))
			v.add_child(UiTheme.label("%s  (%d/%d)" % [Loc.tx(d["desc"]), dq["p"], d["count"]], 18, UiTheme.MUTED, 800))
			var pb := Widgets.bar(UiTheme.GOOD, 10, 300)
			pb.value = float(dq["p"]) / float(d["count"]) * 100.0
			v.add_child(pb)
			var b := UiTheme.button(Loc.t("claimed") if dq["claimed"] else Loc.t("claim"), UiTheme.GOOD.darkened(0.4), 20, Vector2(150, 58))
			b.disabled = dq["claimed"] or int(dq["p"]) < int(d["count"])
			var qid: String = dq["id"]
			b.pressed.connect(func():
				var got := RetentionLogic.claim_daily(st, qid, Game.now())
				if not got.is_empty():
					Audio.play("coin")
					hud._toast_reward(got)
				refresh()
				hud.refresh())
			h.add_child(b)
			list.add_child(c)
		var allb := UiTheme.button(Loc.t("all_daily_bonus", [Widgets.reward_text(GameData.db().daily_all_bonus)]), UiTheme.GOLD.darkened(0.4), 20, Vector2(0, 60))
		allb.disabled = not RetentionLogic.all_daily_claimed(st) or st.daily.get("all_claimed", false)
		allb.pressed.connect(func():
			hud._toast_reward(RetentionLogic.claim_all_bonus(st, Game.now()))
			refresh())
		list.add_child(allb)


# ================================================================== Bestiário
func _tab_dex() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_dex")
	var all := GameData.db().regular_species()
	var caught := st.species_caught_count()
	content.add_child(UiTheme.label(Loc.t("dex_caught", [caught, all.size()]), 22, UiTheme.ACCENT, 900))
	var mh := HFlowContainer.new()
	content.add_child(mh)
	for i in GameData.db().dex_milestones.size():
		var ms: Dictionary = GameData.db().dex_milestones[i]
		var claimable: bool = i in RetentionLogic.dex_claimable(st)
		var done: bool = i in st.dex_claimed
		var b := UiTheme.button("%d: %s" % [ms["count"], Widgets.reward_text(ms["reward"])], UiTheme.GOLD.darkened(0.4) if claimable else UiTheme.BG2, 16, Vector2(0, 48))
		b.disabled = not claimable
		if done:
			b.text = "✓ " + b.text
		var idx := i
		b.pressed.connect(func():
			hud._toast_reward(RetentionLogic.claim_dex(st, idx, Game.now()))
			refresh())
		mh.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 6
	content.add_child(Widgets.scroll(grid))
	for sid in all:
		var d: Dictionary = st.dex.get(sid, {})
		var known := not d.is_empty()
		var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.9), 14)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(v)
		if known:
			var pt := Portrait.make(sid, false, 110)
			if int(d.get("caught", 0)) == 0:
				pt.modulate = Color(0.1, 0.1, 0.15)
			v.add_child(pt)
		else:
			var q := UiTheme.label("?", 60, UiTheme.MUTED, 900)
			q.custom_minimum_size = Vector2(110, 110)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			v.add_child(q)
		var nm := UiTheme.label(Loc.species_name(sid) if known else Loc.t("dex_unknown"), 16, Color.WHITE if int(d.get("caught", 0)) > 0 else UiTheme.MUTED, 800)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		grid.add_child(c)


# ================================================================== Memórias
func _tab_memories() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_memories")
	var found := st.fragments_found()
	var all: Dictionary = GameData.db().fragments
	content.add_child(UiTheme.label(Loc.t("fragments_n", [found.size(), all.size()]), 22, Color("#ffb8ff"), 900))
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	var ids := all.keys()
	ids.sort()
	for fid in ids:
		var c := Widgets.card(Color(0.16, 0.1, 0.2, 0.9) if fid in found else Color(0.1, 0.1, 0.12, 0.8), 14)
		var l := UiTheme.label(("“%s”" % Loc.tx(all[fid])) if fid in found else "· · ·", 19, UiTheme.TEXT if fid in found else UiTheme.MUTED, 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)
		list.add_child(c)


# ================================================================== Mapa
func _tab_map() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("tab_map")
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	var mb := UiTheme.button(Loc.t("open_map"), UiTheme.ACCENT, 22, Vector2(0, 60))
	mb.pressed.connect(func():
		visible = false
		hud.show_big_map())
	list.add_child(mb)
	var acts := {1: [], 2: []}
	for mid in GameData.db().maps:
		acts[int(GameData.db().maps[mid]["act"])].append(mid)
	for act in [1, 2]:
		list.add_child(UiTheme.label("%s %d" % [Loc.t("act"), act], 24, UiTheme.GOLD, 900))
		var h := HFlowContainer.new()
		h.add_theme_constant_override("h_separation", 10)
		h.add_theme_constant_override("v_separation", 10)
		list.add_child(h)
		for mid in acts[act]:
			var md: Dictionary = GameData.db().maps[mid]
			var unlocked := st.map_unlocked(mid)
			var visited: bool = st.map_state(mid).get("visited", false)
			var c := Widgets.card(Color(md["biome"]["ground"][1]).darkened(0.55) if unlocked else Color(0.1, 0.1, 0.12, 0.85), 16)
			c.custom_minimum_size = Vector2(250, 120)
			var v := VBoxContainer.new()
			c.add_child(v)
			v.add_child(UiTheme.label(Loc.tx(md["name"]), 22, Color.WHITE if unlocked else UiTheme.MUTED, 900))
			var frs := 0
			for f in md["fragments"]:
				if f in st.fragments_found():
					frs += 1
			v.add_child(UiTheme.label(("✓ " if visited else "") + Loc.t("fragments_n", [frs, md["fragments"].size()]), 16, UiTheme.MUTED, 800))
			if md.get("hazard") != null:
				var hz: Dictionary = md["hazard"]
				v.add_child(UiTheme.label(Loc.t("hazard_warn", [Loc.t("hz_" + hz["kind"]), Loc.item_name(hz["gear"])]), 15, Color("#ffb0a0"), 800))
			if mid == hud.world.map_id:
				v.add_child(UiTheme.label("● " + Loc.t("objective"), 16, UiTheme.ACCENT, 900))
			h.add_child(c)
	list.add_child(UiTheme.label(Loc.t("coming_soon"), 24, UiTheme.MUTED, 900))
	for fa in GameData.db().future_acts:
		list.add_child(UiTheme.label("%s %d — %s (%s)" % [Loc.t("act"), fa["act"], Loc.tx(fa["city"]), Loc.tx(fa["ruler"])], 18, UiTheme.MUTED, 800))


# ================================================================== Loja
func _tab_shop() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("shop")
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	# vídeos grátis
	var fh := HBoxContainer.new()
	list.add_child(fh)
	for pl in [["free_gems", "free_gems"], ["free_spheres", "free_spheres"], ["xp_boost", "boost_active"]]:
		var placement: String = pl[0]
		var cd := Ads.cooldown_left(placement)
		var label := Loc.t(pl[1], [""]) if placement != "xp_boost" else "XP ×2"
		var b := UiTheme.button("▶ %s\n%s" % [label, Loc.t("free_video") if cd <= 0 else Loc.t("video_cooldown", [Loc.fmt_time(cd)])], UiTheme.GOLD.darkened(0.45), 18, Vector2(220, 76))
		b.disabled = not Ads.rewarded_available(placement)
		b.pressed.connect(func():
			var on_done := func(p: String, ok: bool):
				if p != placement or not ok:
					return
				var cfg: Dictionary = GameData.db().ad_policy["rewarded"][placement]
				match placement:
					"free_gems":
						Game.grant_and_toast({"gems": int(cfg["gems"])})
					"free_spheres":
						Game.grant_and_toast({"items": cfg["items"]})
					"xp_boost":
						st.boosts["xp_until"] = maxi(int(st.boosts.get("xp_until", 0)), Game.now()) + int(cfg["seconds"])
						Game.notify(Loc.t("boost_active", [Loc.fmt_time(int(cfg["seconds"]))]), "level")
				refresh()
			Ads.rewarded_finished.connect(on_done, CONNECT_ONE_SHOT)
			Ads.show_rewarded(placement))
		fh.add_child(b)
	# oferta inicial
	var left := RetentionLogic.starter_offer_left(st, Game.now(), float(Game.rc.get("starter_pack_hours", 72)))
	if left > 0:
		list.add_child(_iap_card("starter_pack", Loc.t("offer_ends", [Loc.fmt_time(left)]), true))
	list.add_child(UiTheme.label(Loc.t("gems"), 24, UiTheme.GEM, 900))
	var gh := HFlowContainer.new()
	gh.add_theme_constant_override("h_separation", 10)
	gh.add_theme_constant_override("v_separation", 10)
	list.add_child(gh)
	for id in ["gems_80", "gems_500", "gems_1200", "gems_2600"]:
		gh.add_child(_iap_card(id, "", false))
	if not st.iap_state.get("no_ads", false):
		list.add_child(_iap_card("remove_ads", "", false))
	if not st.pass_state.get("premium", false):
		list.add_child(_iap_card("season_pass", "", false))
	# itens por moedas/gemas
	list.add_child(UiTheme.label(Loc.t("merchant"), 24, UiTheme.GOLD, 900))
	var ig := HFlowContainer.new()
	ig.add_theme_constant_override("h_separation", 10)
	ig.add_theme_constant_override("v_separation", 10)
	list.add_child(ig)
	for e in GameData.db().economy["shop"]:
		if int(e.get("lvl", 0)) > st.level:
			continue
		var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.9), 16)
		c.custom_minimum_size = Vector2(240, 0)
		var v := VBoxContainer.new()
		c.add_child(v)
		var name := ""
		if e.has("item"):
			v.add_child(Widgets.item_slot(e["item"], int(e["n"]), 70))
			name = "%s ×%d" % [Loc.item_name(e["item"]), e["n"]]
		else:
			name = {"box_slots": "+%d %s" % [e["n"], Loc.t("box")], "expedition_slot": "+1 " + Loc.t("expeditions"),
				"xp_boost": "XP ×2 (%s)" % Loc.fmt_time(int(e["n"])), "instant_harvest": Loc.t("collect_all") + " (2h)"}.get(e["special"], e["special"])
		var nl := UiTheme.label(name, 18, Color.WHITE, 800)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nl)
		var price: Dictionary = e["price"]
		var ptxt := ("● %d" % price["coins"]) if price.has("coins") else ("◆ %d" % price["gems"])
		var b := UiTheme.button(ptxt, UiTheme.GOLD.darkened(0.5) if price.has("coins") else UiTheme.GEM.darkened(0.5), 20, Vector2(0, 54))
		b.disabled = not st.can_afford(price)
		b.pressed.connect(func(): _buy_shop(e))
		v.add_child(b)
		ig.add_child(c)
	var rb := UiTheme.button(Loc.t("restore_purchases"), UiTheme.BG2, 18, Vector2(0, 50))
	rb.pressed.connect(func(): Billing.restore())
	list.add_child(rb)


func _iap_card(id: String, extra: String, highlight: bool) -> Control:
	var p := Billing.product(id)
	var c := Widgets.card(Color(0.3, 0.2, 0.05, 0.95) if highlight else Color(0.14, 0.12, 0.22, 0.95), 18)
	c.custom_minimum_size = Vector2(260, 0)
	var v := VBoxContainer.new()
	c.add_child(v)
	v.add_child(UiTheme.label(Loc.tx(p["name"]), 22, UiTheme.GOLD if highlight else UiTheme.GEM, 900))
	var d := UiTheme.label(Loc.tx(p["desc"]), 16, UiTheme.TEXT, 700)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	if extra != "":
		v.add_child(UiTheme.label(extra, 16, UiTheme.DANGER, 900))
	var b := UiTheme.button(Billing.price_text(id), UiTheme.GOOD.darkened(0.4), 22, Vector2(0, 58))
	b.pressed.connect(func():
		Billing.purchase_done.connect(func(_a, _b): refresh(), CONNECT_ONE_SHOT)
		Billing.buy(id))
	v.add_child(b)
	return c


func _buy_shop(e: Dictionary) -> void:
	var st: GameState = Game.state
	if not st.pay(e["price"]):
		Game.notify(Loc.t("not_enough"), "warn")
		return
	if e.has("item"):
		st.inv.add(e["item"], int(e["n"]))
	else:
		match e["special"]:
			"box_slots":
				st.box_capacity = mini(st.box_capacity + int(e["n"]), int(GameData.db().cfg("capture", "box_max", 200)))
			"expedition_slot":
				st.expedition_slots = mini(st.expedition_slots + 1, int(GameData.db().config["expedition"]["slots_max"]))
			"xp_boost":
				st.boosts["xp_until"] = maxi(int(st.boosts.get("xp_until", 0)), Game.now()) + int(e["n"])
			"instant_harvest":
				for b in st.buildings:
					if b["data"].has("worker") and int(b["data"]["worker"]) >= 0:
						b["data"]["last"] = int(b["data"].get("last", Game.now())) - int(e["n"])
				hud.world._tick_work()
	Audio.play("coin")
	Game.notify(Loc.t("purchased"), "item")
	refresh()
	hud.refresh()


# ================================================================== Trilha (passe)
func _tab_pass() -> void:
	var st: GameState = Game.state
	var pd: Dictionary = GameData.db().pass_data
	title.text = Loc.t("pass_title")
	var tier := RetentionLogic.pass_tier(st)
	var head := HBoxContainer.new()
	content.add_child(head)
	head.add_child(UiTheme.label(Loc.tx(pd["name"]), 22, UiTheme.GOLD, 900))
	head.add_child(UiTheme.label("  " + Loc.t("pass_tier", [tier]), 22, UiTheme.ACCENT, 900))
	var pb := Widgets.bar(UiTheme.GOLD, 14, 300)
	pb.value = float(int(st.pass_state["xp"]) % int(pd["xp_per_tier"])) / float(pd["xp_per_tier"]) * 100.0 if tier < int(pd["tiers"]) else 100.0
	head.add_child(pb)
	if not st.pass_state.get("premium", false):
		var ub := UiTheme.button(Loc.t("pass_unlock") + "  " + Billing.price_text("season_pass"), UiTheme.GOLD.darkened(0.35), 20, Vector2(0, 54))
		ub.pressed.connect(func():
			Billing.purchase_done.connect(func(_a, _b): refresh(), CONNECT_ONE_SHOT)
			Billing.buy("season_pass"))
		head.add_child(ub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var sc := DragScroll.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(row)
	content.add_child(sc)
	for t in range(1, int(pd["tiers"]) + 1):
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(150, 0)
		row.add_child(col)
		var tl := UiTheme.label(Loc.t("pass_tier", [t]), 18, UiTheme.GOLD if t <= tier else UiTheme.MUTED, 900)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
		for prem in [false, true]:
			var key := "prem" if prem else "free"
			var claimed: bool = t in st.pass_state[key] or float(t) in st.pass_state[key]
			var r: Dictionary = pd["premium" if prem else "free"][t - 1]
			var c := Widgets.card(Color(0.3, 0.22, 0.05, 0.95) if prem else Color(0.12, 0.15, 0.2, 0.95), 14)
			c.custom_minimum_size = Vector2(150, 150)
			var v := VBoxContainer.new()
			c.add_child(v)
			v.add_child(UiTheme.label(Loc.t("pass_premium") if prem else Loc.t("pass_free"), 14, UiTheme.GOLD if prem else UiTheme.MUTED, 900))
			var rl := UiTheme.label(Widgets.reward_text(r), 15, Color.WHITE, 800)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			v.add_child(rl)
			var can: bool = t <= tier and not claimed and (not prem or st.pass_state.get("premium", false))
			var b := UiTheme.button("✓" if claimed else Loc.t("claim"), UiTheme.GOOD.darkened(0.4), 16, Vector2(0, 44))
			b.disabled = not can
			var tt := t
			var pp: bool = prem
			b.pressed.connect(func():
				var got := RetentionLogic.claim_pass(st, tt, pp, Game.now())
				hud._toast_reward(got)
				if got.get("monster", "") != "":
					Game.notify(Loc.t("capture_success", [Loc.species_name(got["monster"])]), "capture")
				Firebase.log_event("pass_tier", {"tier": tt, "premium": pp})
				refresh())
			v.add_child(b)
			col.add_child(c)


# ================================================================== Ajustes
func _tab_settings() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("settings")
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	var lh := HBoxContainer.new()
	list.add_child(lh)
	lh.add_child(UiTheme.label(Loc.t("language"), 22, Color.WHITE, 800))
	for l in [["pt", "Português"], ["en", "English"]]:
		var b := UiTheme.button(l[1], UiTheme.ACCENT.darkened(0.4) if Loc.lang == l[0] else UiTheme.BG2, 20, Vector2(170, 54))
		var code: String = l[0]
		b.pressed.connect(func():
			Loc.lang = code
			Game.settings["lang"] = code
			Game.save_settings()
			refresh()
			hud.refresh())
		lh.add_child(b)
	for s in [["music", "music"], ["sfx", "sfx"], ["cam_sens", "camera_sens"]]:
		var h := HBoxContainer.new()
		list.add_child(h)
		var l := UiTheme.label(Loc.t(s[1]), 22, Color.WHITE, 800)
		l.custom_minimum_size = Vector2(300, 0)
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0 if s[0] != "cam_sens" else 0.3
		sl.max_value = 1.0 if s[0] != "cam_sens" else 2.5
		sl.step = 0.05
		sl.value = float(Game.settings[s[0]])
		sl.custom_minimum_size = Vector2(320, 40)
		var key: String = s[0]
		sl.value_changed.connect(func(v):
			Game.settings[key] = v
			if key == "music":
				Audio.update_volume()
			if key == "cam_sens" and hud.world.rig:
				hud.world.rig.sens = v
			Game.save_settings())
		h.add_child(sl)
	var qh := HBoxContainer.new()
	list.add_child(qh)
	qh.add_child(UiTheme.label(Loc.t("quality"), 22, Color.WHITE, 800))
	for qi in 3:
		var b := UiTheme.button(Loc.t(["quality_low", "quality_mid", "quality_high"][qi]), UiTheme.ACCENT.darkened(0.4) if Game.quality() == qi else UiTheme.BG2, 18, Vector2(170, 54))
		var qq := qi
		b.pressed.connect(func():
			Game.settings["quality"] = qq
			Game.save_settings()
			refresh())
		qh.add_child(b)
	var ag := CheckButton.new()
	ag.text = Loc.t("auto_gather")
	ag.button_pressed = Game.settings.get("auto_gather", true)
	ag.toggled.connect(func(on):
		Game.settings["auto_gather"] = on
		Game.save_settings())
	list.add_child(ag)
	var vb := CheckButton.new()
	vb.text = Loc.t("vibration")
	vb.button_pressed = Game.settings["vibration"]
	vb.toggled.connect(func(on):
		Game.settings["vibration"] = on
		Game.save_settings())
	list.add_child(vb)
	if st.is_sandbox():
		var pc := CheckButton.new()
		pc.text = Loc.t("peaceful")
		pc.button_pressed = st.peaceful
		pc.toggled.connect(func(on): st.peaceful = on)
		list.add_child(pc)
	var pv := UiTheme.label(Loc.t("privacy_text"), 16, UiTheme.MUTED, 700)
	pv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(pv)
	var bs := UiTheme.button(Loc.t("save_and_exit"), UiTheme.DANGER.darkened(0.4), 22, Vector2(0, 60))
	bs.pressed.connect(func():
		Game.save_now()
		visible = false
		hud.world.emit_signal("quit_to_title"))
	list.add_child(bs)
	list.add_child(UiTheme.label(Loc.t("version", [ProjectSettings.get_setting("application/config/version", "1.0.0")]), 16, UiTheme.MUTED, 700))


# ================================================================== Construir
func _tab_build() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("build_mode")
	var list := VBoxContainer.new()
	content.add_child(Widgets.scroll(list))
	for kind in ["piece", "station", "machine", "special", "deco"]:
		list.add_child(UiTheme.label(Loc.t("bk_" + kind), 22, UiTheme.ACCENT, 900))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		list.add_child(flow)
		for id in GameData.db().buildings:
			var b: Dictionary = GameData.db().buildings[id]
			if b["kind"] != kind:
				continue
			var lvl_ok := st.is_sandbox() or st.level >= int(b["lvl"])
			var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.92) if lvl_ok else Color(0.09, 0.1, 0.12, 0.8), 16)
			c.custom_minimum_size = Vector2(250, 0)
			var v := VBoxContainer.new()
			c.add_child(v)
			v.add_child(UiTheme.label(Loc.tx(b["name"]), 20, Color.WHITE if lvl_ok else UiTheme.MUTED, 900))
			if b.has("work"):
				v.add_child(UiTheme.label(Loc.t("work_needs", [Loc.t("w_" + b["work"])]), 15, UiTheme.GOLD, 800))
			if lvl_ok:
				v.add_child(Widgets.cost_row(b["cost"], st.inv, 15))
			else:
				v.add_child(UiTheme.label(Loc.t("needs_level", [b["lvl"]]), 16, UiTheme.DANGER, 800))
			var bt := UiTheme.button(Loc.t("build"), UiTheme.GOOD.darkened(0.45), 18, Vector2(0, 50))
			bt.disabled = not lvl_ok or not st.inv.has_all(b["cost"])
			var bid: String = id
			bt.pressed.connect(func():
				visible = false
				hud.start_build(bid))
			v.add_child(bt)
			flow.add_child(c)
	# demolir a estrutura mais próxima
	var near: Structure = null
	var best := 4.0
	for s in hud.world.structures.values():
		var d: float = s.global_position.distance_to(hud.world.player.global_position)
		if d < best:
			best = d
			near = s
	if near != null:
		var db := UiTheme.button("%s: %s" % [Loc.t("demolish"), Loc.tx(near.bd["name"])], UiTheme.DANGER.darkened(0.45), 20, Vector2(0, 56))
		db.pressed.connect(func():
			hud.world.demolish(near)
			refresh())
		list.add_child(db)


# ================================================================== Estação de trabalho
func _tab_station() -> void:
	var st: GameState = Game.state
	var s := _station
	if s == null or not is_instance_valid(s):
		tab = "inventory"
		refresh()
		return
	WorkLogic.tick(st, s.entry, Game.now(), float(Game.rc.get("work_mult", 1.0)))
	var bd := s.bd
	title.text = Loc.tx(bd["name"])
	var data: Dictionary = s.entry["data"]
	var cap := int(GameData.db().config["work"]["station_capacity"])
	content.add_child(UiTheme.label(Loc.t("work_needs", [Loc.t("w_" + bd["work"])]) + "   ·   " + Loc.t("storage", [WorkLogic.stored_total(s.entry), cap]), 20, UiTheme.MUTED, 800))
	var h := HBoxContainer.new()
	content.add_child(h)
	var w := int(data.get("worker", -1))
	var wm := st.get_monster(w)
	if not wm.is_empty():
		h.add_child(Portrait.make(wm["sp"], wm.get("variant", false), 120, true))
		var v := VBoxContainer.new()
		h.add_child(v)
		v.add_child(UiTheme.label("%s  %s" % [MonsterLogic.display_name(wm), Loc.t("level_short", [wm["lvl"]])], 22, Color.WHITE, 900))
		v.add_child(UiTheme.label(Loc.t("rate_h", ["%.0f" % WorkLogic.rate_per_hour(wm, s.entry["id"])]), 20, UiTheme.GOOD, 800))
		var ub := UiTheme.button(Loc.t("unassign"), UiTheme.BG2, 18, Vector2(140, 50))
		ub.pressed.connect(func():
			WorkLogic.tick(st, s.entry, Game.now())
			st.unassign_worker(w)
			s.refresh_worker()
			if hud.world.ally_actor() == null:
				hud.world._spawn_ally()
			refresh())
		v.add_child(ub)
	else:
		h.add_child(UiTheme.label(Loc.t("assign"), 22, UiTheme.GOLD, 900))
	# armazenado
	var g := HFlowContainer.new()
	content.add_child(g)
	for k in data.get("stored", {}):
		g.add_child(Widgets.item_slot(k, int(data["stored"][k]), 76))
	var cb := UiTheme.button(Loc.t("collect_all"), UiTheme.GOOD.darkened(0.4), 22, Vector2(0, 60))
	cb.disabled = WorkLogic.stored_total(s.entry) == 0
	cb.pressed.connect(func():
		var got := WorkLogic.collect(st, s.entry)
		var n := 0
		for k in got:
			n += int(got[k])
			Game.notify(Loc.t("got_item", [got[k], Loc.item_name(k)]), "item")
		Game.on_harvest(n)
		Audio.play("coin")
		s.update_stock()
		refresh())
	content.add_child(cb)
	# escolher trabalhador
	content.add_child(UiTheme.label(Loc.t("assign"), 20, UiTheme.ACCENT, 900))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	content.add_child(Widgets.scroll(flow))
	var any := false
	for uid in st.party + st.box:
		var m := st.get_monster(uid)
		if m.is_empty() or uid == w or m.get("expedition", false) or not WorkLogic.can_work(m, s.entry["id"]):
			continue
		any = true
		var b := UiTheme.button("%s %s · %s %d" % [MonsterLogic.display_name(m), Loc.t("level_short", [m["lvl"]]), Loc.t("w_" + bd["work"]), WorkLogic.skill_for(m, s.entry["id"])], UiTheme.BG2, 17, Vector2(0, 54))
		var u: int = uid
		b.pressed.connect(func():
			var r := WorkLogic.assign(st, int(s.entry["uid"]), u, Game.now())
			if r["ok"]:
				Firebase.log_event("assign_worker", {"building": s.entry["id"]})
				s.refresh_worker()
				Game.check_quests()
				if hud.world.ally != null and is_instance_valid(hud.world.ally) and int(hud.world.ally.m["uid"]) == u:
					hud.world._spawn_ally()
			refresh())
		flow.add_child(b)
	if not any:
		flow.add_child(UiTheme.label(Loc.t("no_worker_fit"), 18, UiTheme.MUTED, 700))


# ================================================================== Baú
func _tab_chest() -> void:
	var st: GameState = Game.state
	var s := _chest
	title.text = Loc.t("chest")
	var cinv := Inventory.new(20)
	cinv.from_dict(s.entry["data"]["inv"])
	var h := HBoxContainer.new()
	content.add_child(h)
	for side in [["tab_inventory", st.inv, cinv], ["chest", cinv, st.inv]]:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiTheme.label(Loc.t(side[0]), 22, UiTheme.ACCENT, 900))
		var grid := GridContainer.new()
		grid.columns = 5
		v.add_child(Widgets.scroll(grid))
		var from: Inventory = side[1]
		var to: Inventory = side[2]
		for i in from.slots.size():
			var sl: Dictionary = from.slots[i]
			var w := Widgets.item_slot(sl.get("id", ""), int(sl.get("n", 0)), 76)
			var idx := i
			w.gui_input.connect(func(ev):
				if ((ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed)) and not from.slots[idx].is_empty():
					var it: Dictionary = from.slots[idx]
					if GameData.db().item(it["id"]).get("cat", "") == "chave" and from == st.inv:
						return
					var left := to.add(it["id"], int(it["n"]))
					if left == 0:
						from.slots[idx] = {}
					else:
						from.slots[idx]["n"] = left
					s.entry["data"]["inv"] = cinv.to_dict()
					refresh())
			grid.add_child(w)


# ================================================================== Expedições
func _tab_expeditions() -> void:
	var st: GameState = Game.state
	title.text = Loc.t("expeditions")
	for e in st.expeditions.duplicate():
		var c := Widgets.card(Color(0.12, 0.18, 0.15, 0.9), 16)
		var h := HBoxContainer.new()
		c.add_child(h)
		var m := st.get_monster(int(e["uid"]))
		if not m.is_empty():
			h.add_child(Portrait.make(m["sp"], m.get("variant", false), 80))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiTheme.label("%s → %s" % [MonsterLogic.display_name(m), Loc.tx(GameData.db().maps[e["map"]]["name"])], 20, Color.WHITE, 900))
		var left := ExpeditionLogic.time_left(e, Game.now())
		v.add_child(UiTheme.label(Loc.t("exp_ready") if left <= 0 else Loc.t("exp_running", [Loc.fmt_time(left)]), 18, UiTheme.GOOD if left <= 0 else UiTheme.MUTED, 800))
		var slot := int(e["slot"])
		if left <= 0:
			var b := UiTheme.button(Loc.t("collect"), UiTheme.GOOD.darkened(0.4), 20, Vector2(150, 56))
			b.pressed.connect(func():
				var got := ExpeditionLogic.complete(st, slot, Game.now(), Game.rng)
				hud._toast_reward(got)
				Game.on_expedition_done()
				refresh())
			h.add_child(b)
		else:
			var b2 := UiTheme.button(Loc.t("exp_rush"), UiTheme.GOLD.darkened(0.4), 18, Vector2(200, 56))
			b2.disabled = not Ads.rewarded_available("expedition_rush")
			var ee: Dictionary = e
			b2.pressed.connect(func():
				var on_done := func(p: String, ok: bool):
					if p == "expedition_rush" and ok:
						ExpeditionLogic.rush(ee, Game.now())
						refresh()
				Ads.rewarded_finished.connect(on_done, CONNECT_ONE_SHOT)
				Ads.show_rewarded("expedition_rush"))
			h.add_child(b2)
		content.add_child(c)
	if ExpeditionLogic.free_slot(st) < 0:
		content.add_child(UiTheme.label(Loc.t("exp_slot_locked"), 18, UiTheme.MUTED, 800))
		return
	content.add_child(UiTheme.label(Loc.t("exp_choose"), 20, UiTheme.ACCENT, 900))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	content.add_child(Widgets.scroll(flow))
	var durs := ExpeditionLogic.durations()
	var target_map := "m1"
	for mid in ["m7", "m6", "m5", "m3", "m2", "m1"]:
		if st.map_unlocked(mid) and st.map_state(mid).get("visited", false):
			target_map = mid
			break
	for uid in st.box:
		var m := st.get_monster(uid)
		if m.get("expedition", false) or int(m.get("job", -1)) >= 0 or m["fainted"]:
			continue
		var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.9), 14)
		var v := VBoxContainer.new()
		c.add_child(v)
		v.add_child(UiTheme.label("%s %s" % [MonsterLogic.display_name(m), Loc.t("level_short", [m["lvl"]])], 18, Color.WHITE, 900))
		var bh := HBoxContainer.new()
		v.add_child(bh)
		for di in durs.size():
			var b := UiTheme.button(Loc.t("exp_dur", [int(durs[di]) / 3600]), UiTheme.BG2, 17, Vector2(80, 48))
			var u: int = uid
			var d := di
			b.pressed.connect(func():
				var r := ExpeditionLogic.start(st, u, d, target_map, Game.now())
				if r["ok"]:
					Firebase.log_event("expedition_start", {"dur": d})
				refresh())
			bh.add_child(b)
		flow.add_child(c)
