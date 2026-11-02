class_name PartyBar
extends VBoxContainer
## Barra lateral com todos os Ecos da equipe. Toque = trocar o companheiro na hora.
## Toque num desmaiado = usar Flor Aurora/Semente Reviver (se tiver). Funciona com multitoque.

var hud: Hud
var _key := ""
var slots: Array = []  # [{"uid", "card", "hp", "lvl", "shade", "mark"}]
const SIZE := 66.0


func setup(p_hud: Hud) -> void:
	hud = p_hud
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	var st: GameState = Game.state
	var key := ""
	for uid in st.party:
		var m := st.get_monster(uid)
		key += "%d:%s:%s:%d|" % [uid, m.get("sp", ""), m.get("variant", false), st.active_uid]
	if key != _key:
		_key = key
		_rebuild()
	update_bars()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	slots.clear()
	var st: GameState = Game.state
	for uid in st.party:
		var m := st.get_monster(uid)
		if m.is_empty():
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(SIZE, SIZE + 14)
		card.focus_mode = Control.FOCUS_NONE
		var active := int(uid) == st.active_uid
		var sb := UiTheme.tex_box("panel_gold" if active else "panel", 20, Vector4(4, 4, 4, 4))
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", sb)
		card.add_theme_stylebox_override("pressed", sb)
		add_child(card)
		var pt := Portrait.make(m["sp"], m.get("variant", false), int(SIZE - 8))
		pt.position = Vector2(4, 2)
		card.add_child(pt)
		var shade := ColorRect.new()
		shade.color = Color(0.05, 0.05, 0.08, 0.65)
		shade.position = Vector2(4, 2)
		shade.size = Vector2(SIZE - 8, SIZE - 8)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(shade)
		var mark := UiTheme.outlined(UiTheme.label("", 30, UiTheme.DANGER, 900), 6)
		mark.position = Vector2(0, 14)
		mark.size = Vector2(SIZE, 40)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(mark)
		var lvl := UiTheme.outlined(UiTheme.label(str(m["lvl"]), 15, Color.WHITE, 900), 5)
		lvl.position = Vector2(6, 0)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lvl)
		var hp := Widgets.bar(UiTheme.GOOD, 8, SIZE - 12)
		hp.position = Vector2(6, SIZE)
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hp)
		var u: int = uid
		hud.controls.register_button(card, func(): _tap(u))
		slots.append({"uid": u, "card": card, "hp": hp, "shade": shade, "mark": mark, "lvl": lvl})


func update_bars() -> void:
	var st: GameState = Game.state
	var a := hud.world.ally_actor()
	for sl in slots:
		var m := st.get_monster(int(sl["uid"]))
		if m.is_empty():
			continue
		var mx := float(MonsterLogic.max_hp(m))
		var hpv := float(m["hp"])
		if a != null and int(a.m["uid"]) == int(sl["uid"]):
			mx = float(a.max_hp)
			hpv = float(a.m["hp"])
		(sl["hp"] as ProgressBar).value = hpv / maxf(1.0, mx) * 100.0
		var fainted: bool = m["fainted"]
		var working: bool = int(m.get("job", -1)) >= 0 or m.get("expedition", false)
		(sl["shade"] as ColorRect).visible = fainted or working
		(sl["mark"] as Label).text = "✕" if fainted else ("⚒" if working else "")
		(sl["mark"] as Label).add_theme_color_override("font_color", UiTheme.DANGER if fainted else UiTheme.GOLD)
		(sl["lvl"] as Label).text = str(m["lvl"])


func _tap(uid: int) -> void:
	var st: GameState = Game.state
	var m := st.get_monster(uid)
	if m.is_empty():
		return
	if m["fainted"]:
		for it in ["flor_aurora", "reviver"]:
			if st.inv.has(it):
				st.inv.remove(it, 1)
				MonsterLogic.heal(m, float(GameData.db().item(it)["heal_monster"]["hp"]), true)
				Audio.play("heal")
				Game.notify("%s: %s" % [Loc.item_name(it), MonsterLogic.display_name(m)], "item")
				if hud.world.ally_actor() == null:
					hud.world.switch_ally(uid)
				refresh()
				return
		Game.notify(Loc.t("echo_fainted", [MonsterLogic.display_name(m)]), "warn")
		return
	if int(m.get("job", -1)) >= 0:
		Game.notify(Loc.t("working_at", [""]).strip_edges(), "warn")
		return
	if uid == st.active_uid and hud.world.ally_actor() != null:
		return
	hud.world.switch_ally(uid)
	refresh()
