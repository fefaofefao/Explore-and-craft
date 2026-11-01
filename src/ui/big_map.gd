class_name BigMap
extends Control
## Mapa grande da ilha atual (norte para cima): você, objetivo, portais com destino, Alfa, capitães e construções.

var world: World
var tex: Texture2D
var map_rect := Rect2()
var _t := 0.0


static func open(p_world: World, parent: Control) -> BigMap:
	var m := BigMap.new()
	m.world = p_world
	parent.add_child(m)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not world.has_meta("big_map_tex"):
		world.set_meta("big_map_tex", Minimap.build_texture(world.gen, 256))
	tex = world.get_meta("big_map_tex")
	var title := UiTheme.outlined(UiTheme.label("%s — %s" % [Loc.t("big_map"), Loc.tx(world.md["name"])], 30, UiTheme.GOLD, 900), 8)
	title.position = Vector2(30, 18)
	add_child(title)
	var close := UiTheme.button("", UiTheme.DANGER, 20, Vector2(72, 72))
	close.icon = UiTheme.ui_icon("close")
	close.expand_icon = true
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -96
	close.offset_right = -24
	close.offset_top = 18
	close.offset_bottom = 90
	close.pressed.connect(queue_free)
	add_child(close)
	# legenda
	var leg := VBoxContainer.new()
	leg.anchor_left = 1.0
	leg.anchor_right = 1.0
	leg.offset_left = -300
	leg.offset_right = -24
	leg.offset_top = 120
	leg.add_theme_constant_override("separation", 6)
	add_child(leg)
	for e in [["map_you", Color.WHITE], ["map_objective", UiTheme.GOLD], ["map_portal", Color("#9ff0ff")], ["map_boss", Color("#ff5a5a")],
			["map_trainer", Color("#ff9a3a")], ["map_base", Color("#e8c890")], ["map_fragment", Color("#ffb8ff")]]:
		var h := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.color = e[1]
		h.add_child(dot)
		h.add_child(UiTheme.outlined(UiTheme.label(Loc.t(e[0]), 20, Color.WHITE, 800), 6))
		leg.add_child(h)
	var frs := 0
	for f in world.md["fragments"]:
		if f in Game.state.fragments_found():
			frs += 1
	leg.add_child(UiTheme.outlined(UiTheme.label(Loc.t("fragments_n", [frs, world.md["fragments"].size()]), 19, Color("#ffb8ff"), 800), 6))
	if world.md.get("hazard") != null:
		var hz: Dictionary = world.md["hazard"]
		var hl := UiTheme.outlined(UiTheme.label(Loc.t("req_hazard", [Loc.t("hz_" + hz["kind"]), Loc.item_name(hz["gear"])]), 18, Color("#ffb36a"), 800), 6)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(270, 0)
		leg.add_child(hl)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _w2m(p: Vector3) -> Vector2:
	var half := world.gen.half
	return map_rect.position + Vector2((p.x + half) / (2.0 * half), (p.z + half) / (2.0 * half)) * map_rect.size


func _pin(p: Vector3, col: Color, r: float, label: String = "") -> void:
	var sp := _w2m(p)
	draw_circle(sp, r + 3.0, Color(0.05, 0.05, 0.1, 0.95))
	draw_circle(sp, r, col)
	if label != "":
		var f := UiTheme.font(900)
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var lp := sp + Vector2(-w * 0.5, -r - 8.0)
		draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 6, Color(0.03, 0.03, 0.06))
		draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col.lightened(0.3))


func _draw() -> void:
	var avail := size - Vector2(400, 140)
	var side := minf(avail.x, avail.y)
	map_rect = Rect2(Vector2(40 + (avail.x - side) * 0.5, 100), Vector2(side, side))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.92))
	# sombra e moldura
	draw_rect(map_rect.grow(10), Color(0, 0, 0, 0.5))
	draw_texture_rect(tex, map_rect, false)
	draw_rect(map_rect, Color(1, 1, 1, 0.5), false, 3.0)
	# construções
	for s in world.structures.values():
		if is_instance_valid(s):
			var sp := _w2m(s.global_position)
			draw_rect(Rect2(sp - Vector2(4, 4), Vector2(8, 8)), Color("#e8c890"))
	# portais
	for it in world.interactables:
		if not is_instance_valid(it):
			continue
		if it.kind == "portal":
			var p: Dictionary = it.data
			var unlocked: bool = Game.state.map_unlocked(p["to"]) and (not p.has("requires_flag") or Game.state.flags.get(p["requires_flag"], false))
			_pin(it.global_position, Color("#9ff0ff") if unlocked else Color("#7a8a94"), 9.0, ("" if unlocked else "⚠ ") + Loc.tx(p["label"]))
		elif it.kind == "altar":
			_pin(it.global_position, Color("#ff9aff"), 7.0, Loc.t("bridge_altar"))
		elif it.kind == "cradle":
			_pin(it.global_position, Color("#7ff0ff"), 6.0, Loc.t("cradle"))
	# Alfa
	if not world.lair.is_empty() and not world.lair["boss"] in Game.state.stats["bosses"]:
		_pin(world.lair["center"], Color("#ff5a5a"), 11.0, "★ " + Loc.species_name(world.lair["boss"]) + "  " + Loc.t("level_short", [world.lair["lvl"]]))
	for n in world.npcs:
		if is_instance_valid(n) and n.kind == "trainer":
			_pin(n.global_position, Color("#ff9a3a"), 8.0, n.display_name)
		elif is_instance_valid(n) and n.kind in ["merchant", "board", "expedition", "ferry"]:
			_pin(n.global_position, Color("#c8e0ff"), 6.0, n.display_name)
	# objetivo
	var mk := QuestLogic.marker(Game.state) if not Game.state.is_sandbox() else {}
	if not mk.is_empty() and mk["map"] == world.map_id:
		var op := Vector3(mk["pos"].x, 0, mk["pos"].y)
		var sp := _w2m(op)
		var pr := 14.0 + sin(_t * 5.0) * 4.0
		draw_arc(sp, pr + 8.0, 0, TAU, 32, Color(1, 0.85, 0.3, 0.6), 3.0, true)
		_pin(op, UiTheme.GOLD, 10.0, Loc.t("map_objective"))
	# jogador
	var pp := _w2m(world.player.global_position)
	var f := world.player.facing()
	var ang := atan2(f.x, -f.z)
	var pts := PackedVector2Array([Vector2(0, -14), Vector2(10, 10), Vector2(0, 4), Vector2(-10, 10)])
	var xf := Transform2D(ang, pp)
	var poly := PackedVector2Array()
	for pt in pts:
		poly.append(xf * pt)
	draw_colored_polygon(poly, Color.WHITE)
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.05, 0.05, 0.1), 3.0, true)
	# norte
	var np := map_rect.position + Vector2(map_rect.size.x - 30, 30)
	draw_circle(np, 18, Color(0.05, 0.07, 0.12, 0.9))
	draw_string(UiTheme.font(900), np + Vector2(-8, 8), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ff7a6a"))
