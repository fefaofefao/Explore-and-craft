class_name UiTheme
extends RefCounted
## Tema visual da interface: fonte Nunito, painéis arredondados translúcidos, botões com cor de destaque.

const BG := Color(0.07, 0.09, 0.13, 0.86)
const BG2 := Color(0.13, 0.16, 0.22, 0.95)
const ACCENT := Color("#3fd6c6")
const GOLD := Color("#ffc94a")
const GEM := Color("#c88aff")
const DANGER := Color("#ff5a5a")
const GOOD := Color("#6ee07a")
const TEXT := Color("#f4f1ea")
const MUTED := Color("#a6adbb")

static var _fonts: Dictionary = {}
static var _theme: Theme
static var _icons: Dictionary = {}


static func font(weight: int = 700) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base: FontFile = load("res://assets/fonts/Nunito.ttf")
	var sym: FontFile = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	if base.fallbacks.is_empty():
		base.fallbacks = [sym]
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = fv
	return fv


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 0)
	t.set_stylebox("panel", "PanelContainer", panel_box(BG))
	t.set_stylebox("panel", "Panel", panel_box(BG))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := BG2
		match st:
			"hover":
				c = BG2.lightened(0.08)
			"pressed":
				c = ACCENT.darkened(0.35)
			"disabled":
				c = Color(0.2, 0.2, 0.24, 0.7)
			"focus":
				c = Color(0, 0, 0, 0)
		var sb := panel_box(c, 16)
		if st == "focus":
			sb.draw_center = false
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.65))
	t.set_font_size("font_size", "Button", 24)
	t.set_constant("h_separation", "Button", 10)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(1, 1, 1, 0.08)
	sbg.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", sbg)
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = ACCENT
	sfill.set_corner_radius_all(6)
	t.set_stylebox("fill", "ProgressBar", sfill)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.25)
	grab.set_corner_radius_all(6)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var sb_scroll := StyleBoxFlat.new()
	sb_scroll.bg_color = Color(1, 1, 1, 0.04)
	sb_scroll.set_corner_radius_all(6)
	sb_scroll.content_margin_left = 6
	t.set_stylebox("scroll", "VScrollBar", sb_scroll)
	var le := panel_box(Color(0, 0, 0, 0.35), 10)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_font_size("font_size", "LineEdit", 24)
	_theme = t
	return t


static func panel_box(c: Color, radius: int = 22, border: Color = Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


static func label(text: String, size: int = 24, col: Color = TEXT, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if weight != 700:
		l.add_theme_font_override("font", font(weight))
	return l


static func outlined(l: Label, outline: int = 8) -> Label:
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06, 0.9))
	return l


static func button(text: String, col: Color = BG2, size: int = 24, min_size: Vector2 = Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(800))
	if col != BG2:
		b.add_theme_stylebox_override("normal", panel_box(col, 16, col.lightened(0.25)))
		b.add_theme_stylebox_override("hover", panel_box(col.lightened(0.1), 16, col.lightened(0.35)))
		b.add_theme_stylebox_override("pressed", panel_box(col.darkened(0.25), 16, col.lightened(0.2)))
		b.add_theme_stylebox_override("disabled", panel_box(Color(0.25, 0.25, 0.28, 0.8), 16))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click", 0.05))
	return b


static func circle_button(text: String, col: Color, diameter: float = 110.0, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font(900))
	var r := int(diameter / 2.0)
	b.add_theme_stylebox_override("normal", panel_box(Color(col, 0.78), r, Color(1, 1, 1, 0.35)))
	b.add_theme_stylebox_override("hover", panel_box(Color(col.lightened(0.1), 0.85), r, Color(1, 1, 1, 0.5)))
	b.add_theme_stylebox_override("pressed", panel_box(Color(col.darkened(0.3), 0.95), r, Color(1, 1, 1, 0.6)))
	b.add_theme_stylebox_override("disabled", panel_box(Color(0.25, 0.25, 0.3, 0.6), r))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


static func icon(name: String) -> Texture2D:
	## Ícones em assets/icons/*.png (gerados por tools/gen_icons.py). Fallback: círculo colorido.
	if _icons.has(name):
		return _icons[name]
	var path := "res://assets/icons/%s.png" % name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_icons[name] = tex
	return tex


static func item_icon(id: String) -> Texture2D:
	var it: Dictionary = GameData.db().item(id)
	var tex := icon("items/" + id)
	if tex == null:
		tex = icon("items/" + str(it.get("icon", "")))
	if tex == null:
		tex = dot_texture(Color(it.get("color", "#cccccc")))
	return tex


static func dot_texture(c: Color, size: int = 64) -> Texture2D:
	var key := "dot_" + c.to_html()
	if _icons.has(key):
		return _icons[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.42
	for y in size:
		for x in size:
			var d := Vector2(x - size / 2.0, y - size / 2.0).length()
			if d < r:
				var k := 1.0 - d / r * 0.35
				img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, 1.0))
			elif d < r + 2.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.6))
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func margin(c: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(c)
	return mc


static func type_chip(t: String) -> PanelContainer:
	var p := PanelContainer.new()
	var col := Color(GameData.db().types["colors"][t])
	var sb := panel_box(col.darkened(0.25), 12, col.lightened(0.2))
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	p.add_theme_stylebox_override("panel", sb)
	var l := label(Loc.tx(GameData.db().types["names"][t]), 18, Color.WHITE, 800)
	p.add_child(l)
	return p
