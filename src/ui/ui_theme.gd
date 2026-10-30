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
	t.set_stylebox("panel", "PanelContainer", tex_box("panel", 30, Vector4(18, 12, 18, 12)))
	t.set_stylebox("panel", "Panel", tex_box("panel", 30))
	t.set_stylebox("normal", "Button", tex_box("btn", 24, Vector4(14, 8, 14, 8)))
	t.set_stylebox("hover", "Button", tex_box("btn", 24, Vector4(14, 8, 14, 8)))
	t.set_stylebox("pressed", "Button", tex_box("btn_accent", 24, Vector4(14, 8, 14, 8)))
	t.set_stylebox("disabled", "Button", panel_box(Color(0.18, 0.19, 0.23, 0.8), 18))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
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


static func tex_box(name: String, margin: int = 26, content: Vector4 = Vector4(16, 10, 16, 10)) -> StyleBox:
	## 9-patch com degradê, brilho interno e borda (assets/ui/*.png, gerados por tools/gen_textures.py).
	var key := "tb_%s_%d_%s" % [name, margin, str(content)]
	if _icons.has(key):
		return _icons[key]
	var path := "res://assets/ui/%s.png" % name
	if not ResourceLoader.exists(path):
		return panel_box(BG)
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	_icons[key] = sb
	return sb


static func variant_for(col: Color) -> String:
	## Escolhe a textura de botão mais próxima da cor pedida.
	if col.s < 0.18:
		return "btn"
	var h := col.h * 360.0
	if h < 20 or h >= 340:
		return "btn_red"
	if h < 65:
		return "btn_gold"
	if h < 150:
		return "btn_green"
	if h < 200:
		return "btn_accent"
	if h < 250:
		return "btn_accent"
	return "btn_purple"


static func ui_icon(name: String) -> Texture2D:
	return icon("ui/" + name)


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
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
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
		var v := variant_for(col)
		var cm := Vector4(14, 8, 14, 8)
		b.add_theme_stylebox_override("normal", tex_box(v, 24, cm))
		b.add_theme_stylebox_override("hover", tex_box(v, 24, cm))
		b.add_theme_stylebox_override("pressed", tex_box("btn", 24, cm))
		b.add_theme_stylebox_override("disabled", panel_box(Color(0.18, 0.19, 0.23, 0.8), 18))
		b.add_theme_constant_override("outline_size", 6)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		var au: Node = Engine.get_main_loop().root.get_node_or_null("Audio") if Engine.get_main_loop() is SceneTree else null
		if au:
			au.play("click", 0.05))
	return b


static func circle_button(text: String, col: Color, diameter: float = 110.0, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font(900))
	set_circle_color(b, col)
	b.add_theme_constant_override("outline_size", 7)
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.7))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


static func circle_variant(col: Color) -> String:
	if col.s < 0.2:
		return "cb_gray"
	var h := col.h * 360.0
	if h < 15 or h >= 345:
		return "cb_red"
	if h < 30:
		return "cb_red"
	if h < 65:
		return "cb_gold"
	if h < 160:
		return "cb_green"
	if h < 195:
		return "cb_teal"
	if h < 270:
		return "cb_blue"
	return "cb_pink"


static func set_circle_color(b: Button, col: Color) -> void:
	var v := circle_variant(col)
	var tb := tex_box(v, 0, Vector4(8, 8, 8, 8))
	b.add_theme_stylebox_override("normal", tb)
	b.add_theme_stylebox_override("hover", tb)
	var pressed := tex_box(v, 0, Vector4(8, 12, 8, 4))
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", tex_box("cb_gray", 0, Vector4(8, 8, 8, 8)))


static func icon_button(icon_name: String, col: Color, diameter: float, label_text: String = "", font_size: int = 16) -> Button:
	## Botão redondo com ícone grande e rótulo pequeno.
	var b := circle_button("", col, diameter, font_size)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tr := TextureRect.new()
	tr.texture = ui_icon(icon_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var isz := diameter * (0.42 if label_text != "" else 0.52)
	tr.custom_minimum_size = Vector2(isz, isz)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.name = "Icon"
	v.add_child(tr)
	var l := outlined(label(label_text, font_size, Color.WHITE, 900), 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "Label"
	l.visible = label_text != ""
	v.add_child(l)
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
