extends Node
## Cena raiz: tela de título (com cenário 3D vivo), consentimento de privacidade, carregamento de mapas,
## progresso offline e presente diário.

var title_root: Node3D
var title_ui: CanvasLayer
var world: World
var hud: Hud
var loading: CanvasLayer
var _title_cam: Camera3D
var _t := 0.0


func _ready() -> void:
	_register_inputs()
	get_tree().root.theme = UiTheme.theme()
	var args := OS.get_cmdline_user_args()
	if "--autopilot" in args:
		var ap: Node = load("res://src/debug/autopilot.gd").new()
		ap.main = self
		add_child(ap)
		return
	show_title()
	if not Game.settings.get("consent_asked", false):
		_ask_consent()
	else:
		Ads.start_after_consent()


static func _register_inputs() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "action": [KEY_E, KEY_F], "sphere": [KEY_Q],
		"skill1": [KEY_1], "skill2": [KEY_2], "switch": [KEY_R], "menu": [KEY_I, KEY_ESCAPE], "build": [KEY_B], "sprint": [KEY_SHIFT],
	}
	for a in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


# ------------------------------------------------------------------ título
func show_title() -> void:
	_clear_world()
	title_root = Node3D.new()
	add_child(title_root)
	var gen := WorldGen.new("m1")
	var sky := SkyEnv.new()
	title_root.add_child(sky)
	sky.setup(gen.biome, mini(Game.quality(), 1))
	sky.update_time(0.31)
	title_root.add_child(TerrainBuilder.build_terrain(gen))
	title_root.add_child(TerrainBuilder.build_water(gen))
	title_root.add_child(TerrainBuilder.build_grass(gen, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count := 0
	for pl in gen.node_placements():
		if Vector2(pl["pos"].x, pl["pos"].z).distance_to(Vector2(0, 70)) < 45.0 and count < 60:
			var n := ResourceNode.new().setup(pl["key"], pl["kind"], Color.WHITE, pl["scale"], pl["rot"])
			title_root.add_child(n)
			n.position = pl["pos"]
			count += 1
	for i in 6:
		var sp: String = ["folhito", "brasito", "marolo", "lumeflor", "lupigelo", "espinhoz"][i]
		var m := MonsterModel.new().build(sp, i == 3)
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * 7.0, 0, 62 + sin(a) * 5.0)
		p.y = gen.height(p.x, p.z)
		m.position = p
		m.rotation.y = a + PI
		m.move_speed = 0.3
		title_root.add_child(m)
	_title_cam = Camera3D.new()
	_title_cam.fov = 55
	title_root.add_child(_title_cam)
	_build_title_ui()
	Audio.play_music("title")


func _build_title_ui() -> void:
	title_ui = CanvasLayer.new()
	add_child(title_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	title_ui.add_child(root)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.02, 0.03, 0.06, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0, 0)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var v := VBoxContainer.new()
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = 70
	v.offset_top = -280
	v.offset_right = 600
	v.offset_bottom = 300
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var logo := UiTheme.outlined(UiTheme.label(Loc.t("game_title").to_upper(), 96, Color.WHITE, 1000), 18)
	logo.add_theme_color_override("font_color", Color("#eafff9"))
	v.add_child(logo)
	var sub := UiTheme.outlined(UiTheme.label(Loc.t("game_subtitle"), 40, UiTheme.GOLD, 900), 10)
	v.add_child(sub)
	var tag := UiTheme.outlined(UiTheme.label(Loc.t("story_desc"), 20, Color(1, 1, 1, 0.85), 700), 6)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag)
	v.add_child(Widgets.spacer(10))
	if Game.has_save("story"):
		var bc := UiTheme.button(Loc.t("continue"), UiTheme.ACCENT.darkened(0.35), 30, Vector2(420, 78))
		bc.pressed.connect(func(): _start("story", false))
		v.add_child(bc)
	var bn := UiTheme.button(Loc.t("new_story"), UiTheme.GOLD.darkened(0.45) if not Game.has_save("story") else UiTheme.BG2, 28, Vector2(420, 72))
	bn.pressed.connect(func():
		if Game.has_save("story"):
			_confirm_new()
		else:
			_start("story", true))
	v.add_child(bn)
	var bs := UiTheme.button(Loc.t("sandbox"), Color("#6a4aa0"), 28, Vector2(420, 72))
	bs.pressed.connect(func(): _start("sandbox", not Game.has_save("sandbox")))
	v.add_child(bs)
	var lh := HBoxContainer.new()
	v.add_child(lh)
	for l in [["pt", "PT"], ["en", "EN"]]:
		var b := UiTheme.button(l[1], UiTheme.ACCENT.darkened(0.4) if Loc.lang == l[0] else UiTheme.BG2, 20, Vector2(80, 52))
		var code: String = l[0]
		b.pressed.connect(func():
			Loc.lang = code
			Game.settings["lang"] = code
			Game.save_settings()
			title_ui.queue_free()
			_build_title_ui())
		lh.add_child(b)
	var ver := UiTheme.label(Loc.t("version", [ProjectSettings.get_setting("application/config/version", "1.0.0")]), 16, Color(1, 1, 1, 0.5), 700)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.offset_left = -200
	ver.offset_top = -40
	root.add_child(ver)


func _confirm_new() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.theme = UiTheme.theme()
	layer.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var p := Widgets.card(Color(0.08, 0.1, 0.15, 0.98), 24)
	p.custom_minimum_size = Vector2(560, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := UiTheme.label(Loc.t("new_game_confirm"), 22, Color.WHITE, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var by := UiTheme.button(Loc.t("yes"), UiTheme.DANGER.darkened(0.3), 22, Vector2(160, 60))
	by.pressed.connect(func():
		layer.queue_free()
		SaveSystem.delete("story")
		_start("story", true))
	h.add_child(by)
	var bno := UiTheme.button(Loc.t("no"), UiTheme.BG2, 22, Vector2(160, 60))
	bno.pressed.connect(func(): layer.queue_free())
	h.add_child(bno)


func _ask_consent() -> void:
	## Diálogo de privacidade (o formulário UMP do AdMob é exibido pelo plugin quando presente).
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.theme = UiTheme.theme()
	layer.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var p := Widgets.card(Color(0.08, 0.1, 0.15, 0.98), 24)
	p.custom_minimum_size = Vector2(620, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UiTheme.label(Loc.t("privacy"), 28, UiTheme.GOLD, 900))
	var l := UiTheme.label(Loc.t("privacy_text"), 20, Color.WHITE, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var b := UiTheme.button(Loc.t("ok"), UiTheme.ACCENT.darkened(0.35), 24, Vector2(0, 64))
	b.pressed.connect(func():
		Game.settings["consent_asked"] = true
		Game.settings["consent"] = true
		Game.save_settings()
		Ads.start_after_consent()
		layer.queue_free())
	v.add_child(b)


func _process(delta: float) -> void:
	if _title_cam != null and is_instance_valid(_title_cam):
		_t += delta * 0.05
		var c := Vector3(0, 2.0, 62)
		_title_cam.look_at_from_position(c + Vector3(sin(_t * 2.0) * 8.0 + 4.0, 6.0, 20.0), c + Vector3(-5, 0, -4))


# ------------------------------------------------------------------ mundo
func _start(mode: String, fresh: bool) -> void:
	if fresh or not Game.load_game(mode):
		Game.new_game(mode)
	Firebase.log_event("session_start", {"mode": mode})
	Firebase.set_user_property("mode", mode)
	var st: GameState = Game.state
	var offline := Game.now() - st.last_seen
	var target_map := st.map_id if st.map_unlocked(st.map_id) else "m1"
	await _load_map(target_map)
	if fresh and mode == "story":
		hud.show_dialog("d_intro", Callable())
	elif fresh and mode == "sandbox":
		hud.show_dialog("d_sandbox", Callable())
	else:
		_offline_and_daily(offline)


func _offline_and_daily(offline: int) -> void:
	var st: GameState = Game.state
	var mult := float(Game.rc.get("work_mult", 1.0))
	if offline > 300:
		var prev := WorkLogic.offline_preview(st, Game.now(), mult)
		if not prev.is_empty():
			hud.show_offline(prev, offline, func(doubled: bool):
				WorkLogic.tick_all(st, Game.now(), mult * (2.0 if doubled else 1.0))
				world._tick_work()
				_daily_popup())
			return
	_daily_popup()


func _daily_popup() -> void:
	if Game.state.is_sandbox():
		return
	if RetentionLogic.login_available(Game.state, Game.now()) and Game.state.flags.get("starter_chosen", false):
		hud.show_daily_login()


func _show_loading(text: String) -> void:
	loading = CanvasLayer.new()
	loading.layer = 90
	add_child(loading)
	var bg := ColorRect.new()
	bg.color = Color("#0a0f16")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var l := UiTheme.outlined(UiTheme.label(text, 40, UiTheme.GOLD, 900), 8)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -400
	l.offset_right = 400
	loading.add_child(l)
	var tip := UiTheme.label(Loc.t(["tip_move", "tip_gather", "tip_capture", "tip_build", "tip_skills"][randi() % 5]), 20, UiTheme.MUTED, 700)
	tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tip.offset_top = -90
	tip.offset_left = -500
	tip.offset_right = 500
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading.add_child(tip)


func _load_map(map_id: String) -> void:
	var name := Loc.tx(GameData.db().maps[map_id]["name"])
	_show_loading(name)
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_world()
	hud = Hud.new()
	add_child(hud)
	world = World.new()
	add_child(world)
	hud.setup(world)
	world.build(map_id, hud)
	world.travel_requested.connect(_on_travel)
	world.quit_to_title.connect(func():
		Game.save_now()
		show_title())
	hud.refresh()
	await get_tree().process_frame
	if loading != null:
		var tw := loading.create_tween()
		var bg: ColorRect = loading.get_child(0)
		tw.tween_property(bg, "modulate:a", 0.0, 0.4)
		var lyr := loading
		tw.tween_callback(lyr.queue_free)
		loading = null
	Game.save_now()


func _on_travel(map_id: String) -> void:
	Game.save_now()
	var same := world != null and world.map_id == map_id
	await _load_map(map_id)
	if not same:
		Ads.maybe_interstitial("travel")
	Game.check_quests()


func _clear_world() -> void:
	Game.current_world = null
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if title_root != null and is_instance_valid(title_root):
		title_root.queue_free()
	title_root = null
	_title_cam = null
	if title_ui != null and is_instance_valid(title_ui):
		title_ui.queue_free()
	title_ui = null
