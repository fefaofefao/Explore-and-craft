class_name Hud
extends CanvasLayer
## HUD do jogo: status, parceiro, objetivo com bússola, botões de ação, avisos, diálogos e popups.

var world: World
var controls: TouchControls
var root: Control

var hp_bar: ProgressBar
var hunger_bar: ProgressBar
var lvl_label: Label
var xp_bar: ProgressBar
var coins_label: Label
var gems_label: Label
var day_label: Label
var ally_box: PanelContainer
var ally_name: Label
var ally_hp: ProgressBar
var ally_portrait_holder: Control
var _ally_uid := -999
var party_dots: HBoxContainer
var obj_panel: PanelContainer
var obj_title: Label
var obj_desc: Label
var obj_arrow: Label
var obj_dist: Label
var action_btn: Button
var jump_btn: Button
var sphere_btn: Button
var sphere_cycle: Button
var skill_btns: Array = []
var auto_btn: Button
var build_btn: Button
var menu_btn: Button
var gift_btn: Button
var shop_btn: Button
var toasts: VBoxContainer
var lume_bubble: PanelContainer
var lume_label: Label
var hazard_rect: ColorRect
var banner: PanelContainer
var banner_label: Label
var build_bar: PanelContainer
var overlay: Control  # popups modais
var minimap: Minimap
var tut_panel: PanelContainer
var tut_label: Label
var tut_ring: TutorialRing
var _tut_t := 0.0
var _tut_step := ""

var menu: Node  # GameMenu
var _lume_t := 0.0
var _toast_queue: Array = []
var _flash: Label
var _dialog_queue: Array = []
var _ctx_kind := "attack"


func setup(p_world: World) -> void:
	world = p_world
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	controls = TouchControls.new()
	root.add_child(controls)
	controls.blocked = func(): return modal_open() or (menu != null and is_instance_valid(menu) and menu.visible)
	controls.look.connect(func(d): if world and world.rig: world.rig.rotate_by(d))
	controls.zoom.connect(func(f): if world and world.rig: world.rig.zoom_by(f))
	hazard_rect = ColorRect.new()
	hazard_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hazard_rect.color = Color(1, 0.3, 0.1, 0.0)
	hazard_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hazard_rect)
	var vig := TextureRect.new()
	vig.texture = load("res://assets/ui/vignette.png")
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	_build_status()
	_build_objective()
	minimap = Minimap.new()
	root.add_child(minimap)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -16 - Minimap.SIZE
	minimap.offset_right = -16
	minimap.offset_top = 104
	minimap.offset_bottom = 104 + Minimap.SIZE
	minimap.setup(world)
	_build_buttons()
	_build_toasts()
	_build_lume()
	_build_banner()
	_build_tutorial()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	Game.toast.connect(_on_toast)
	Game.hud_refresh.connect(refresh)
	Game.quest_changed.connect(refresh)
	Game.dialog_requested.connect(func(id): show_dialog(id, Callable()))
	Game.reward_popup.connect(_on_reward_popup)
	refresh()


# ------------------------------------------------------------------ montagem
func _icon_rect(name: String, px: float, tint: Color = Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = UiTheme.ui_icon(name)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _build_status() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.06, 0.08, 0.12, 0.72), 20))
	p.position = Vector2(16, 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	lvl_label = UiTheme.label("Nv 1", 22, UiTheme.ACCENT, 900)
	top.add_child(lvl_label)
	day_label = UiTheme.label("", 18, UiTheme.MUTED, 800)
	top.add_child(day_label)
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(_icon_rect("heart", 26, UiTheme.DANGER))
	hp_bar = Widgets.bar(UiTheme.DANGER, 16, 190)
	r1.add_child(hp_bar)
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	r2.add_child(_icon_rect("food", 24, Color("#f0a850")))
	hunger_bar = Widgets.bar(Color("#e8a040"), 12, 190)
	r2.add_child(hunger_bar)
	xp_bar = Widgets.bar(UiTheme.ACCENT, 6, 214)
	v.add_child(xp_bar)
	var cur := HBoxContainer.new()
	v.add_child(cur)
	coins_label = UiTheme.label("0", 20, UiTheme.GOLD, 900)
	gems_label = UiTheme.label("0", 20, UiTheme.GEM, 900)
	cur.add_child(_icon_rect("coin", 22, UiTheme.GOLD))
	cur.add_child(coins_label)
	cur.add_child(Widgets.spacer(4))
	cur.add_child(_icon_rect("gem", 22, UiTheme.GEM))
	cur.add_child(gems_label)
	# cartão do Eco parceiro (toque = trocar)
	ally_box = PanelContainer.new()
	ally_box.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.06, 0.08, 0.12, 0.72), 20))
	ally_box.position = Vector2(16, 196)
	root.add_child(ally_box)
	var ah := HBoxContainer.new()
	ally_box.add_child(ah)
	ally_portrait_holder = Control.new()
	ally_portrait_holder.custom_minimum_size = Vector2(72, 72)
	ah.add_child(ally_portrait_holder)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 2)
	ah.add_child(av)
	ally_name = UiTheme.label("", 20, Color.WHITE, 900)
	av.add_child(ally_name)
	ally_hp = Widgets.bar(UiTheme.GOOD, 12, 140)
	av.add_child(ally_hp)
	party_dots = HBoxContainer.new()
	party_dots.add_theme_constant_override("separation", 4)
	av.add_child(party_dots)
	ally_box.gui_input.connect(func(ev):
		if ev is InputEventScreenTouch and ev.pressed:
			world.cycle_ally())


func _build_objective() -> void:
	obj_panel = PanelContainer.new()
	obj_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.06, 0.08, 0.12, 0.72), 20))
	obj_panel.anchor_left = 0.5
	obj_panel.anchor_right = 0.5
	obj_panel.offset_left = -230
	obj_panel.offset_right = 230
	obj_panel.offset_top = 12
	obj_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(obj_panel)
	var h := HBoxContainer.new()
	obj_panel.add_child(h)
	obj_arrow = UiTheme.label("▲", 34, UiTheme.GOLD, 900)
	obj_arrow.pivot_offset = Vector2(14, 22)
	obj_arrow.custom_minimum_size = Vector2(34, 44)
	obj_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(obj_arrow)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	obj_title = UiTheme.label("", 20, UiTheme.GOLD, 900)
	v.add_child(obj_title)
	obj_desc = UiTheme.label("", 17, UiTheme.TEXT, 700)
	obj_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_desc.custom_minimum_size = Vector2(360, 0)
	v.add_child(obj_desc)
	obj_dist = UiTheme.label("", 18, UiTheme.MUTED, 800)
	h.add_child(obj_dist)
	obj_panel.gui_input.connect(func(ev):
		if ev is InputEventScreenTouch and ev.pressed:
			open_menu("quests"))


func _anchor_br(c: Control, x: float, y: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = -x
	c.offset_top = -y
	c.offset_right = -x + c.custom_minimum_size.x
	c.offset_bottom = -y + c.custom_minimum_size.y


func _build_buttons() -> void:
	action_btn = UiTheme.icon_button("sword", Color("#e0663a"), 150, Loc.t("attack"), 19)
	_anchor_br(action_btn, 190, 196)
	root.add_child(action_btn)
	controls.register_button(action_btn, func(): world.on_action())
	jump_btn = UiTheme.icon_button("jump", Color("#3a7ae0"), 96)
	_anchor_br(jump_btn, 300, 118)
	root.add_child(jump_btn)
	controls.register_button(jump_btn, func():
		world.player.jump_held = true
		world.player.jump(), func(): world.player.jump_held = false)
	sphere_btn = UiTheme.icon_button("sphere", Color("#d83a4a"), 100, "0", 18)
	_anchor_br(sphere_btn, 128, 318)
	root.add_child(sphere_btn)
	controls.register_button(sphere_btn, func(): world.throw_sphere())
	sphere_cycle = UiTheme.circle_button("⟳", Color("#5a5a6a"), 46, 20)
	_anchor_br(sphere_cycle, 52, 300)
	root.add_child(sphere_cycle)
	controls.register_button(sphere_cycle, func(): world.cycle_orb())
	for i in 2:
		var b := UiTheme.circle_button("", Color("#5a8a4a"), 96, 13)
		b.clip_text = true
		_anchor_br(b, 318 - i * 0, 300 + i * 0)
		root.add_child(b)
		skill_btns.append(b)
		var idx := i
		controls.register_button(b, func(): world.ally_skill(idx))
	_anchor_br(skill_btns[0], 330, 258)
	_anchor_br(skill_btns[1], 236, 340)
	auto_btn = UiTheme.circle_button(Loc.t("auto_skills"), UiTheme.ACCENT.darkened(0.3), 60, 15)
	_anchor_br(auto_btn, 380, 360)
	auto_btn.toggle_mode = true
	auto_btn.button_pressed = true
	auto_btn.toggled.connect(func(on):
		world.auto_skill_on = on
		auto_btn.modulate = Color.WHITE if on else Color(1, 1, 1, 0.5))
	root.add_child(auto_btn)
	# canto superior direito
	var tr := HBoxContainer.new()
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -470
	tr.offset_right = -16
	tr.offset_top = 14
	tr.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(tr)
	gift_btn = _top_button("gift", UiTheme.GOLD)
	gift_btn.tooltip_text = Loc.t("daily_login")
	gift_btn.pressed.connect(show_daily_login)
	tr.add_child(gift_btn)
	shop_btn = _top_button("gem", UiTheme.GEM)
	shop_btn.pressed.connect(func(): open_menu("shop"))
	tr.add_child(shop_btn)
	build_btn = _top_button("hammer", Color("#4aa85a"))
	build_btn.pressed.connect(open_build)
	tr.add_child(build_btn)
	menu_btn = _top_button("bag", Color("#3fd6c6"))
	menu_btn.pressed.connect(func(): open_menu("inventory"))
	tr.add_child(menu_btn)


func _top_button(icon_name: String, col: Color) -> Button:
	var b := UiTheme.button("", col, 20, Vector2(76, 76))
	b.icon = UiTheme.ui_icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 46)
	return b


func _build_toasts() -> void:
	toasts = VBoxContainer.new()
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.offset_left = -420
	toasts.offset_right = -16
	toasts.offset_top = 310
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 6)
	root.add_child(toasts)
	_flash = UiTheme.outlined(UiTheme.label("", 42, UiTheme.GOLD, 900), 10)
	_flash.anchor_left = 0.5
	_flash.anchor_right = 0.5
	_flash.anchor_top = 0.3
	_flash.offset_left = -300
	_flash.offset_right = 300
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)


func _build_lume() -> void:
	lume_bubble = PanelContainer.new()
	lume_bubble.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.05, 0.15, 0.2, 0.88), 22, Color("#9ff0ff")))
	lume_bubble.anchor_left = 0.5
	lume_bubble.anchor_right = 0.5
	lume_bubble.offset_left = -300
	lume_bubble.offset_right = 300
	lume_bubble.offset_top = 108
	lume_bubble.offset_bottom = 180
	lume_bubble.visible = false
	lume_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lume_bubble)
	var h := HBoxContainer.new()
	lume_bubble.add_child(h)
	h.add_child(UiTheme.label("✦", 34, Color("#9ff0ff"), 900))
	lume_label = UiTheme.label("", 20, Color.WHITE, 700)
	lume_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lume_label)


func _build_tutorial() -> void:
	tut_panel = PanelContainer.new()
	tut_panel.add_theme_stylebox_override("panel", UiTheme.tex_box("panel_gold", 24, Vector4(18, 10, 18, 10)))
	tut_panel.anchor_left = 0.5
	tut_panel.anchor_right = 0.5
	tut_panel.anchor_top = 1.0
	tut_panel.anchor_bottom = 1.0
	tut_panel.offset_left = -300
	tut_panel.offset_right = 230
	tut_panel.offset_top = -132
	tut_panel.offset_bottom = -18
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_panel.visible = false
	root.add_child(tut_panel)
	var h := HBoxContainer.new()
	tut_panel.add_child(h)
	var ic := _icon_rect("star", 40, UiTheme.GOLD)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiTheme.label(Loc.t("tutorial").to_upper(), 15, UiTheme.GOLD, 900))
	tut_label = UiTheme.label("", 19, Color.WHITE, 800)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tut_label)
	tut_ring = TutorialRing.new()
	root.add_child(tut_ring)


func _update_tutorial() -> void:
	var st: GameState = Game.state
	for done in TutorialLogic.newly_completed(st):
		_on_toast(Loc.t("tut_done", [Loc.t("tut_name_" + done)]), "quest")
		Audio.play("quest")
		flash_text("✓ " + Loc.t("tut_name_" + done), UiTheme.GOLD)
	var step := TutorialLogic.current(st)
	_tut_step = step
	var busy: bool = modal_open() or (menu != null and is_instance_valid(menu) and menu.visible and step != "build")
	tut_panel.visible = step != "" and not busy
	if step == "":
		tut_ring.target = null
		world.set_tutorial_arrow(null)
		return
	var key := "tut_" + step
	var ring: Control = action_btn
	var arrow: Node3D = null
	match step:
		"partner":
			var disp := get_tree().get_nodes_in_group("starter_display")
			if disp.size() > 0:
				arrow = disp[min(1, disp.size() - 1)]
		"gather":
			arrow = world.nearest_node(["arvore", "pinheiro", "palmeira", "arbusto", "capim"], 40.0)
		"build":
			if world.build_mode:
				key = "tut_build_place"
			elif menu == null or not is_instance_valid(menu) or not menu.visible:
				ring = build_btn
			else:
				ring = null
		"fight":
			arrow = world.nearest_wild(35.0)
	tut_label.text = Loc.t(key)
	tut_ring.target = ring if not busy else null
	world.set_tutorial_arrow(arrow)


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.3, 0.05, 0.08, 0.85), 18, UiTheme.DANGER))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -220
	banner.offset_right = 220
	banner.offset_top = 128
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	banner_label = UiTheme.label("", 22, Color.WHITE, 900)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_label)


# ------------------------------------------------------------------ atualização
func refresh() -> void:
	var st: GameState = Game.state
	if st == null or world == null:
		return
	hp_bar.value = st.hp / st.max_hp() * 100.0
	hunger_bar.value = st.hunger
	lvl_label.text = Loc.t("level_short", [st.level])
	xp_bar.value = float(st.xp) / maxf(1.0, st.xp_to_next()) * 100.0
	coins_label.text = str(st.coins)
	gems_label.text = str(st.gems)
	day_label.text = "  %s%s" % [Loc.t("day_n", [st.day_count]), (" · " + Loc.t("night")) if st.is_night() else ""]
	# parceiro
	var m := st.active_monster()
	var a := world.ally_actor()
	ally_box.visible = not m.is_empty() or st.party.size() > 0
	if not m.is_empty():
		ally_name.text = "%s  %s" % [MonsterLogic.display_name(m), Loc.t("level_short", [m["lvl"]])]
		var mx := float(a.max_hp) if a != null else float(MonsterLogic.max_hp(m))
		ally_hp.value = float(m["hp"]) / maxf(1.0, mx) * 100.0
		if _ally_uid != int(m["uid"]):
			_ally_uid = int(m["uid"])
			for c in ally_portrait_holder.get_children():
				c.queue_free()
			var pt := Portrait.make(m["sp"], m.get("variant", false), 72)
			ally_portrait_holder.add_child(pt)
	else:
		ally_name.text = Loc.t("no_echo")
		ally_hp.value = 0
	for c in party_dots.get_children():
		c.queue_free()
	for pm in st.party_monsters():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.color = UiTheme.DANGER if pm["fainted"] else (UiTheme.ACCENT if int(pm["uid"]) == st.active_uid else (UiTheme.MUTED if int(pm.get("job", -1)) >= 0 else UiTheme.GOOD))
		party_dots.add_child(dot)
	# esferas
	var orb := world.selected_orb
	var cnt := st.inv.count(orb) if not st.inv.infinite else 99
	(sphere_btn.find_child("Label", true, false) as Label).text = "×%d" % cnt
	UiTheme.set_circle_color(sphere_btn, Color(GameData.db().item(orb)["color"]))
	refresh_skills()
	_refresh_objective()
	gift_btn.visible = RetentionLogic.login_available(st, Game.now()) and not st.is_sandbox()
	if menu != null and is_instance_valid(menu) and menu.visible:
		menu.refresh()


func refresh_skills() -> void:
	var a := world.ally_actor()
	for i in skill_btns.size():
		var b: Button = skill_btns[i]
		var j := MonsterLogic.skill_slot(a.m["skills"], i) if a != null else -1
		if a == null or j < 0:
			b.visible = false
			continue
		b.visible = true
		var s: String = a.m["skills"][j]
		var sk: Dictionary = GameData.db().skills[s]
		var cd := float(a.skill_cd.get(s, 0.0))
		var nm := Loc.tx(sk["name"])
		var parts := nm.split(" ", false, 1)
		b.text = ("\n".join(parts) if nm.length() > 9 else nm) if cd <= 0.0 else "%d" % ceili(cd)
		var col := FX.type_color(sk["type"])
		UiTheme.set_circle_color(b, col if cd <= 0.0 else Color(0.3, 0.3, 0.32))
		b.disabled = cd > 0.0


func _refresh_objective() -> void:
	var st: GameState = Game.state
	if st.is_sandbox():
		obj_title.text = Loc.t("sandbox")
		obj_desc.text = Loc.t("sandbox_desc")
		obj_arrow.visible = false
		obj_dist.text = ""
		return
	var q := QuestLogic.current(st)
	if q.is_empty():
		obj_title.text = Loc.t("story")
		obj_desc.text = Loc.t("story_complete")
		obj_arrow.visible = false
		obj_dist.text = ""
		return
	var p := QuestLogic.progress(st, q)
	obj_title.text = "%s  %s" % [Loc.tx(q["title"]), ("(%d/%d)" % [p[0], p[1]]) if int(p[1]) > 1 else ""]
	obj_desc.text = Loc.tx(q["desc"])


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	# bússola do objetivo
	var st: GameState = Game.state
	var mk := QuestLogic.marker(st) if not st.is_sandbox() else {}
	if mk.is_empty():
		obj_arrow.visible = false
		obj_dist.text = ""
	elif mk["map"] != world.map_id:
		obj_arrow.visible = false
		obj_dist.text = Loc.t("other_map", [Loc.tx(GameData.db().maps[mk["map"]]["name"])])
	else:
		obj_arrow.visible = true
		var pp := world.player.global_position
		var to := Vector2(mk["pos"].x - pp.x, mk["pos"].y - pp.z)
		var cam_yaw := world.rig.yaw
		var ang := atan2(to.x, -to.y) + cam_yaw
		obj_arrow.rotation = ang
		obj_dist.text = Loc.t("distance_m", [int(to.length())])
	# barras ao vivo
	hp_bar.value = st.hp / st.max_hp() * 100.0
	hunger_bar.value = st.hunger
	var a := world.ally_actor()
	if a != null:
		ally_hp.value = a.hp_frac() * 100.0
	if _lume_t > 0.0:
		_lume_t -= delta
		if _lume_t <= 0.0:
			lume_bubble.visible = false
	if world.ally_actor() != null and Engine.get_process_frames() % 10 == 0:
		refresh_skills()
	_tut_t -= delta
	if _tut_t <= 0.0:
		_tut_t = 0.25
		_update_tutorial()


func set_context(label: String, kind: String) -> void:
	_ctx_kind = kind
	var lbl: Label = action_btn.find_child("Label", true, false)
	var ico: TextureRect = action_btn.find_child("Icon", true, false)
	if world.build_mode:
		lbl.text = Loc.t("place")
		ico.texture = UiTheme.ui_icon("hammer")
		UiTheme.set_circle_color(action_btn, Color("#4aa85a"))
		return
	if label == "":
		lbl.text = Loc.t("attack")
		ico.texture = UiTheme.ui_icon("sword")
		UiTheme.set_circle_color(action_btn, Color("#e0663a"))
	else:
		lbl.text = label if label.length() < 13 else label.substr(0, 12) + "…"
		ico.texture = UiTheme.ui_icon("hand" if kind == "gather" else "star")
		UiTheme.set_circle_color(action_btn, Color("#4aa85a") if kind == "gather" else Color("#3a8ae0"))


func hazard_tint(on: bool) -> void:
	var target := 0.12 + sin(Time.get_ticks_msec() * 0.006) * 0.05 if on else 0.0
	hazard_rect.color.a = lerpf(hazard_rect.color.a, target, 0.1)


func flash_text(t: String, col: Color) -> void:
	_flash.text = t
	_flash.add_theme_color_override("font_color", col)
	_flash.modulate.a = 1.0
	_flash.scale = Vector2(1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, 0.9).set_delay(0.4)


func lume_hint(text: String, secs: float = 6.0) -> void:
	lume_label.text = text
	lume_bubble.visible = true
	_lume_t = secs


func trainer_banner(b: Dictionary) -> void:
	if b.is_empty():
		banner.visible = false
		return
	banner.visible = true
	var t: Dictionary = GameData.db().trainers[b["tid"]]
	var left: int = b["queue"].size() + (1 if world.trainer_enemy != null else 0)
	banner_label.text = "⚔ %s  ·  %s" % [Loc.tx(t["name"]), "●".repeat(left) + "○".repeat(max(0, int(b["total"]) - left))]


# ------------------------------------------------------------------ avisos
func _on_toast(text: String, kind: String) -> void:
	var col := Color(0.06, 0.08, 0.12, 0.85)
	var fc := Color.WHITE
	match kind:
		"warn":
			fc = Color("#ffb0a0")
		"quest":
			col = Color(0.25, 0.18, 0.02, 0.9)
			fc = UiTheme.GOLD
		"level":
			col = Color(0.02, 0.2, 0.22, 0.9)
			fc = UiTheme.ACCENT
		"capture", "relic":
			col = Color(0.25, 0.18, 0.02, 0.9)
			fc = UiTheme.GOLD
		"gem":
			fc = UiTheme.GEM
		"coin":
			fc = UiTheme.GOLD
		"item":
			fc = Color("#d8f0d0")
		"daily":
			fc = UiTheme.GOOD
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(col, 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 19, fc, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	p.add_child(l)
	toasts.add_child(p)
	if toasts.get_child_count() > 6:
		toasts.get_child(0).queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.6 if kind != "quest" else 4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ modais
func _modal(min_size: Vector2 = Vector2(620, 0), dim: float = 0.55) -> Array:
	## Cria um painel modal centralizado. Devolve [fundo, conteúdo VBox].
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.08, 0.1, 0.15, 0.97), 26, Color(1, 1, 1, 0.12)))
	p.custom_minimum_size = min_size
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	p.scale = Vector2(0.9, 0.9)
	p.pivot_offset = min_size / 2
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().paused = false
	return [bg, v]


func modal_open() -> bool:
	return overlay.get_child_count() > 0


func show_dialog(id: String, done: Callable) -> void:
	var lines: Array = GameData.db().dialogs.get(id, [])
	if lines.is_empty():
		if done.is_valid():
			done.call()
		return
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.25)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.06, 0.08, 0.12, 0.95), 24, Color(1, 1, 1, 0.15)))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -480
	p.offset_right = 480
	p.offset_top = -250
	p.offset_bottom = -24
	bg.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var who := UiTheme.label("", 26, Color.WHITE, 900)
	v.add_child(who)
	var txt := UiTheme.label("", 23, UiTheme.TEXT, 700)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(txt)
	var hint := UiTheme.label(Loc.t("tap_to_continue") + " ▸", 16, UiTheme.MUTED, 800)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	var idx := [0]
	var show_line := func() -> void:
		var ln: Dictionary = lines[idx[0]]
		var spk: Dictionary = GameData.db().speakers.get(ln["who"], {})
		who.text = Loc.tx(spk.get("name", ln["who"]))
		who.add_theme_color_override("font_color", Color(spk.get("color", "#ffffff")))
		txt.text = Loc.tx(ln["text"])
		txt.visible_ratio = 0.0
		var tw := txt.create_tween()
		tw.tween_property(txt, "visible_ratio", 1.0, clampf(txt.text.length() * 0.018, 0.3, 2.0))
	show_line.call()
	Audio.play("dialog")
	bg.gui_input.connect(func(ev):
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
			if txt.visible_ratio < 1.0:
				txt.visible_ratio = 1.0
				return
			idx[0] += 1
			if idx[0] >= lines.size():
				bg.queue_free()
				if done.is_valid():
					done.call()
			else:
				show_line.call()
				Audio.play("dialog"))


func show_starter_choice(cb: Callable) -> void:
	var mv := _modal(Vector2(900, 0))
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var t := UiTheme.label(Loc.t("choose_starter"), 34, UiTheme.GOLD, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	for sp in ["folhito", "brasito", "marolo"]:
		var spd: Dictionary = GameData.db().sp(sp)
		var c := Widgets.card(Color(0.12, 0.15, 0.2, 0.95))
		c.custom_minimum_size = Vector2(270, 0)
		h.add_child(c)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(cv)
		var pt := Portrait.make(sp, false, 200, true)
		pt.custom_minimum_size = Vector2(240, 200)
		cv.add_child(pt)
		var nm := UiTheme.label(Loc.species_name(sp), 28, Color.WHITE, 900)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nm)
		var chip := UiTheme.type_chip(spd["types"][0])
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(chip)
		var lore := UiTheme.label(Loc.tx(spd["lore"]), 16, UiTheme.MUTED, 700)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size = Vector2(240, 70)
		lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(lore)
		var b := UiTheme.button(Loc.t("free_it"), FX.type_color(spd["types"][0]).darkened(0.35))
		b.pressed.connect(func():
			bg.queue_free()
			cb.call(sp))
		cv.add_child(b)


func show_capture(m: Dictionary, where: String) -> void:
	var mv := _modal(Vector2(560, 0))
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var t := UiTheme.label(Loc.t("capture_success", [MonsterLogic.display_name(m)]), 30, UiTheme.GOLD, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var pt := Portrait.make(m["sp"], m.get("variant", false), 240, true)
	pt.custom_minimum_size = Vector2(520, 240)
	v.add_child(pt)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	for ty in MonsterLogic.types_of(m):
		chips.add_child(UiTheme.type_chip(ty))
	if m.get("variant", false):
		var vc := UiTheme.label("✦ " + Loc.t("variant_aurora"), 20, UiTheme.GOLD, 900)
		chips.add_child(vc)
	v.add_child(chips)
	var info := UiTheme.label("%s  ·  %s  ·  %s" % [Loc.t("level_short", [m["lvl"]]), Loc.t("talent", [int(float(m["talent"]) * 100)]),
		Loc.t("party") if where == "party" else Loc.t("box")], 20, UiTheme.MUTED, 800)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var lore := UiTheme.label(Loc.tx(GameData.db().sp(m["sp"])["lore"]), 18, UiTheme.TEXT, 700)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lore)
	var b := UiTheme.button(Loc.t("ok"), UiTheme.ACCENT.darkened(0.3))
	b.pressed.connect(func(): bg.queue_free())
	v.add_child(b)
	refresh()


func show_relic(item_id: String) -> void:
	var mv := _modal(Vector2(520, 0))
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var t := UiTheme.label(Loc.item_name(item_id), 32, UiTheme.GOLD, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var slot := Widgets.item_slot(item_id, 1, 150)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(slot)
	var d := UiTheme.label(Loc.tx(GameData.db().item(item_id)["desc"]), 20, UiTheme.TEXT, 700)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var b := UiTheme.button(Loc.t("ok"), UiTheme.GOLD.darkened(0.4))
	b.pressed.connect(func(): bg.queue_free())
	v.add_child(b)


func show_fragment(fid: String) -> void:
	var mv := _modal(Vector2(680, 0))
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var found := Game.state.fragments_found().size()
	var t := UiTheme.label("✦ %s  (%d/%d)" % [Loc.t("fragment_found"), found, GameData.db().fragments.size()], 26, Color("#ffb8ff"), 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UiTheme.label("“%s”" % Loc.tx(GameData.db().fragments[fid]), 23, UiTheme.TEXT, 600)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var b := UiTheme.button(Loc.t("ok"), Color("#8a4aa0"))
	b.pressed.connect(func(): bg.queue_free())
	v.add_child(b)


func _on_reward_popup(title: String, r: Dictionary) -> void:
	var txt := Widgets.reward_text({"coins": r.get("coins", 0), "gems": r.get("gems", 0), "items": r.get("items", {})})
	if txt != "":
		_on_toast("%s: %s" % [Loc.t("reward"), txt], "quest")


func show_death(cb: Callable) -> void:
	var mv := _modal(Vector2(560, 0), 0.7)
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var t := UiTheme.label(Loc.t("you_fainted"), 34, UiTheme.DANGER, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := UiTheme.button(Loc.t("revive_watch"), UiTheme.GOLD.darkened(0.35))
	b1.disabled = not Ads.rewarded_available("revive_here")
	b1.pressed.connect(func():
		var on_done := func(pl: String, ok: bool):
			if pl == "revive_here" and ok:
				bg.queue_free()
				cb.call(true)
		Ads.rewarded_finished.connect(on_done, CONNECT_ONE_SHOT)
		Ads.show_rewarded("revive_here"))
	v.add_child(b1)
	var b2 := UiTheme.button(Loc.t("revive_at_bed"), UiTheme.BG2)
	b2.pressed.connect(func():
		bg.queue_free()
		cb.call(false))
	v.add_child(b2)


func fade_sleep() -> void:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.5)
	tw.tween_interval(0.6)
	tw.tween_property(r, "color:a", 0.0, 0.8)
	tw.tween_callback(r.queue_free)


# ------------------------------------------------------------------ menus
func _ensure_menu() -> void:
	if menu == null or not is_instance_valid(menu):
		menu = GameMenu.new()
		menu.hud = self
		root.add_child(menu)


func open_menu(tab: String) -> void:
	if world.build_mode:
		world.exit_build_mode()
		_show_build_bar(false)
	_ensure_menu()
	menu.open(tab)


func open_station(s: Structure) -> void:
	_ensure_menu()
	menu.open_station(s)


func open_chest(s: Structure) -> void:
	_ensure_menu()
	menu.open_chest(s)


func open_expeditions() -> void:
	_ensure_menu()
	menu.open("expeditions")


func open_build() -> void:
	if world.build_mode:
		world.exit_build_mode()
		_show_build_bar(false)
		return
	_ensure_menu()
	menu.open("build")


func start_build(id: String) -> void:
	world.enter_build_mode(id)
	_show_build_bar(true)


func _show_build_bar(on: bool) -> void:
	if build_bar != null:
		build_bar.queue_free()
		build_bar = null
	sphere_btn.visible = not on
	sphere_cycle.visible = not on
	for b in skill_btns:
		b.visible = not on and b.visible
	if not on:
		refresh()
		return
	build_bar = PanelContainer.new()
	build_bar.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.06, 0.08, 0.12, 0.85), 20))
	build_bar.anchor_left = 0.5
	build_bar.anchor_right = 0.5
	build_bar.anchor_top = 1.0
	build_bar.anchor_bottom = 1.0
	build_bar.offset_left = -330
	build_bar.offset_right = 200
	build_bar.offset_top = -110
	build_bar.offset_bottom = -20
	root.add_child(build_bar)
	var h := HBoxContainer.new()
	build_bar.add_child(h)
	var name := UiTheme.label(Loc.tx(GameData.db().buildings[world.ghost_id]["name"]), 20, UiTheme.GOLD, 900)
	h.add_child(name)
	h.add_child(Widgets.cost_row(GameData.db().buildings[world.ghost_id]["cost"], Game.state.inv, 16))
	var rb := UiTheme.button(Loc.t("rotate"), UiTheme.BG2, 20, Vector2(110, 60))
	rb.pressed.connect(func(): world.rotate_ghost())
	h.add_child(rb)
	var cb := UiTheme.button("✕", UiTheme.DANGER.darkened(0.3), 22, Vector2(60, 60))
	cb.pressed.connect(func():
		world.exit_build_mode()
		_show_build_bar(false))
	h.add_child(cb)


func show_daily_login() -> void:
	var st: GameState = Game.state
	var mv := _modal(Vector2(900, 0))
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var t := UiTheme.label(Loc.t("daily_login"), 34, UiTheme.GOLD, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var rewards: Array = GameData.db().daily_login
	var cur := RetentionLogic.login_day_index(st)
	var avail := RetentionLogic.login_available(st, Game.now())
	for i in rewards.size():
		var col := Color(0.12, 0.15, 0.2, 0.95)
		if i < cur or (i == cur and not avail):
			col = Color(0.1, 0.25, 0.15, 0.95)
		elif i == cur:
			col = Color(0.35, 0.27, 0.05, 0.95)
		var c := Widgets.card(col, 16)
		c.custom_minimum_size = Vector2(112, 150)
		h.add_child(c)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(cv)
		var dl := UiTheme.label(Loc.t("day_x", [i + 1]), 18, UiTheme.GOLD if i == cur else UiTheme.MUTED, 900)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(dl)
		var r: Dictionary = rewards[i]
		var icon_id: String = r.get("items", {}).keys()[0] if r.has("items") else ("" if not r.has("gems") else "")
		if icon_id != "":
			var sl := Widgets.item_slot(icon_id, int(r["items"][icon_id]), 64)
			sl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cv.add_child(sl)
		var rl := UiTheme.label(Widgets.reward_text(r), 15, Color.WHITE, 800)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.custom_minimum_size = Vector2(100, 0)
		cv.add_child(rl)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	if avail:
		var b1 := UiTheme.button(Loc.t("claim"), UiTheme.GOOD.darkened(0.4), 24, Vector2(220, 64))
		b1.pressed.connect(func():
			var got := RetentionLogic.claim_login(st, Game.now())
			Firebase.log_event("daily_login", {"day": cur + 1})
			_toast_reward(got)
			bg.queue_free()
			refresh())
		bh.add_child(b1)
		var b2 := UiTheme.button(Loc.t("claim_x2"), UiTheme.GOLD.darkened(0.35), 24, Vector2(300, 64))
		b2.disabled = not Ads.rewarded_available("daily_bonus")
		b2.pressed.connect(func():
			var on_done := func(pl: String, ok: bool):
				if pl == "daily_bonus" and ok:
					var got := RetentionLogic.claim_login(st, Game.now(), true)
					Firebase.log_event("daily_login", {"day": cur + 1, "doubled": true})
					_toast_reward(got)
					bg.queue_free()
					refresh()
			Ads.rewarded_finished.connect(on_done, CONNECT_ONE_SHOT)
			Ads.show_rewarded("daily_bonus"))
		bh.add_child(b2)
	else:
		bh.add_child(UiTheme.label(Loc.t("come_back_tomorrow"), 20, UiTheme.MUTED, 800))
	var bc := UiTheme.button(Loc.t("close"), UiTheme.BG2, 22, Vector2(160, 60))
	bc.pressed.connect(func(): bg.queue_free())
	bh.add_child(bc)


func _toast_reward(got: Dictionary) -> void:
	for k in got.get("items", {}):
		_on_toast(Loc.t("got_item", [got["items"][k], Loc.item_name(k)]), "item")
	if int(got.get("coins", 0)) > 0:
		_on_toast("+%d %s" % [got["coins"], Loc.t("coins")], "coin")
	if int(got.get("gems", 0)) > 0:
		_on_toast("+%d %s" % [got["gems"], Loc.t("gems")], "gem")


func show_offline(produced: Dictionary, secs: int, apply_cb: Callable) -> void:
	var mv := _modal(Vector2(640, 0))
	var bg: Control = mv[0]
	var v: VBoxContainer = mv[1]
	var t := UiTheme.label(Loc.t("offline_title"), 32, UiTheme.GOLD, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UiTheme.label(Loc.t("offline_desc", [Loc.fmt_time(secs)]), 20, UiTheme.TEXT, 700))
	var g := GridContainer.new()
	g.columns = 6
	v.add_child(g)
	for k in produced:
		g.add_child(Widgets.item_slot(k, int(produced[k]), 80))
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	var b1 := UiTheme.button(Loc.t("collect_plain"), UiTheme.BG2, 22, Vector2(200, 64))
	b1.pressed.connect(func():
		apply_cb.call(false)
		bg.queue_free())
	bh.add_child(b1)
	var b2 := UiTheme.button(Loc.t("double_video"), UiTheme.GOLD.darkened(0.35), 22, Vector2(260, 64))
	b2.disabled = not Ads.rewarded_available("offline_double")
	b2.pressed.connect(func():
		var on_done := func(pl: String, ok: bool):
			if pl == "offline_double":
				apply_cb.call(ok)
				bg.queue_free()
		Ads.rewarded_finished.connect(on_done, CONNECT_ONE_SHOT)
		Ads.show_rewarded("offline_double"))
	bh.add_child(b2)
