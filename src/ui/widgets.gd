class_name Widgets
extends RefCounted
## Componentes reutilizáveis da interface.


static func bar(col: Color, h: float = 14.0, w: float = 200.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.max_value = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(h / 2))
	b.add_theme_stylebox_override("fill", sb)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(int(h / 2))
	bg.border_color = Color(1, 1, 1, 0.15)
	bg.set_border_width_all(1)
	b.add_theme_stylebox_override("background", bg)
	return b


static func item_slot(id: String, n: int, size: float = 84.0, selected: bool = false, dur: int = -1) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	var it: Dictionary = GameData.db().item(id) if id != "" else {}
	var border := Color(1, 1, 1, 0.1)
	if selected:
		border = UiTheme.ACCENT
	elif it.get("cat", "") == "chave":
		border = UiTheme.GOLD
	var sb := UiTheme.panel_box(Color(0.12, 0.15, 0.2, 0.9), 14, border)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	if id == "":
		return p
	var tr := TextureRect.new()
	tr.texture = UiTheme.item_icon(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	var md := Inventory.max_dur(id)
	if md > 0:
		var cur := md if dur < 0 else dur
		var f := clampf(float(cur) / md, 0.0, 1.0)
		var bar := ColorRect.new()
		bar.color = UiTheme.GOOD if f > 0.5 else (UiTheme.GOLD if f > 0.2 else UiTheme.DANGER)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2((size - 16) * f, 6)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		p.add_child(bar)
	if n > 1 or GameData.db().item(id).get("stack", 99) > 1:
		var l := UiTheme.outlined(UiTheme.label(str(n), 20, Color.WHITE, 900), 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	return p


static func cost_row(cost: Dictionary, inv: Inventory, size: int = 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for k in cost:
		var have := inv.count(k) if not inv.infinite else 999
		var need := int(cost[k])
		var tr := TextureRect.new()
		tr.texture = UiTheme.item_icon(k)
		tr.custom_minimum_size = Vector2(size + 10, size + 10)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
		var l := UiTheme.label("%d/%d" % [min(have, 999), need], size, UiTheme.GOOD if have >= need else UiTheme.DANGER, 800)
		h.add_child(l)
	return h


static func reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if int(r.get("coins", 0)) > 0:
		parts.append("%d %s" % [r["coins"], Loc.t("coins")])
	if int(r.get("gems", 0)) > 0:
		parts.append("%d %s" % [r["gems"], Loc.t("gems")])
	if int(r.get("xp", 0)) > 0:
		parts.append("%d XP" % r["xp"])
	for k in r.get("items", {}):
		parts.append("%d× %s" % [r["items"][k], Loc.item_name(k)])
	if r.has("monster") and r["monster"] is Array:
		parts.append(Loc.species_name(r["monster"][0]) + (" ✦" if r["monster"].size() > 2 and r["monster"][2] else ""))
	if int(r.get("pass_xp", 0)) > 0:
		parts.append("%d XP %s" % [r["pass_xp"], Loc.t("tab_pass")])
	return ", ".join(parts)


static func scroll(child: Control) -> ScrollContainer:
	var sc := DragScroll.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	return sc


static func card(col: Color = UiTheme.BG2, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(col, radius))
	return p


static func spacer(h: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
