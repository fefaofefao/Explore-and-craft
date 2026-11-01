class_name Minimap
extends Control
## Minimapa circular: textura do relevo gerada do WorldGen, gira com a câmera; marca objetivo, portais, chefe e parceiro.

signal open_big

var world: World
var tex_rect: TextureRect
var mat: ShaderMaterial
var zoom := 0.2
const SIZE := 190.0


func setup(p_world: World) -> void:
	world = p_world
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect = TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/minimap.gdshader")
	tex_rect.material = mat
	add_child(tex_rect)
	gui_input.connect(func(ev):
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			accept_event()
			emit_signal("open_big"))


static func build_texture(gen: WorldGen, n: int = 160) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var b: Dictionary = gen.biome
	var water := Color(b["water"])
	var sand := Color(b["sand"])
	var rock := Color(b["rock"])
	var high := Color(b["high"])
	var hl := 1.5 + float(b["height"]) * 1.15
	var light := Vector3(-0.6, 0.7, -0.4).normalized()
	for j in n:
		for i in n:
			var x := -gen.half + (i + 0.5) / n * gen.half * 2.0
			var z := -gen.half + (j + 0.5) / n * gen.half * 2.0
			var h := gen.height(x, z)
			var c: Color
			if h < 0.0:
				c = water.darkened(clampf(-h / 8.0, 0.0, 0.6)).lightened(0.15 if h > -0.6 else 0.0)
			elif h < 1.4:
				c = sand
			elif gen.slope_at(x, z, 1.5) > 2.6:
				c = rock
			elif h > hl:
				c = high
			else:
				c = TerrainBuilder.ground_color(gen, x, z)
			if h >= 0.0:
				var dx := gen.height(x + 1.5, z) - gen.height(x - 1.5, z)
				var dz := gen.height(x, z + 1.5) - gen.height(x, z - 1.5)
				var nn := Vector3(-dx, 3.0, -dz).normalized()
				c = c * (0.62 + 0.5 * clampf(nn.dot(light), 0.0, 1.0))
				c.a = 1.0
			img.set_pixel(i, j, c)
	if gen.md.get("city") != null:
		for hs in gen.city_layout()["houses"]:
			var u := int((hs["pos"].x + gen.half) / (gen.half * 2.0) * n)
			var v := int((hs["pos"].z + gen.half) / (gen.half * 2.0) * n)
			for dy in range(-1, 2):
				for dx2 in range(-1, 2):
					if u + dx2 >= 0 and u + dx2 < n and v + dy >= 0 and v + dy < n:
						img.set_pixel(u + dx2, v + dy, Color("#8a5a48"))
	return ImageTexture.create_from_image(img)


func _process(_d: float) -> void:
	if world == null or world.player == null or world.gen == null:
		return
	if tex_rect.texture == null:
		# o mapa só existe depois que o World termina de gerar o terreno
		tex_rect.texture = build_texture(world.gen)
		mat.set_shader_parameter("map_tex", tex_rect.texture)
	var p := world.player.global_position
	var half := world.gen.half
	mat.set_shader_parameter("center_uv", Vector2((p.x + half) / (2.0 * half), (p.z + half) / (2.0 * half)))
	mat.set_shader_parameter("zoom", zoom)
	mat.set_shader_parameter("angle", -world.rig.yaw)
	queue_redraw()


func _to_screen(wp: Vector3) -> Vector2:
	## Converte posição do mundo para o minimapa (mesma rotação do shader). Devolve fora do círculo se longe.
	var p := world.player.global_position
	var rel := Vector2(wp.x - p.x, wp.z - p.z) / (2.0 * world.gen.half) / (zoom * 2.0)
	var a := world.rig.yaw
	var r := Vector2(cos(a) * rel.x - sin(a) * rel.y, sin(a) * rel.x + cos(a) * rel.y)
	return size * 0.5 + r * size


func _marker(wp: Vector3, col: Color, rad: float, clamp_edge: bool = false) -> void:
	var sp := _to_screen(wp)
	var c := size * 0.5
	var d := sp - c
	var maxr := size.x * 0.5 - rad - 3.0
	if d.length() > maxr:
		if not clamp_edge:
			return
		sp = c + d.normalized() * maxr
	draw_circle(sp, rad + 2.0, Color(0.05, 0.05, 0.1, 0.9))
	draw_circle(sp, rad, col)


func _draw() -> void:
	if world == null or world.player == null or tex_rect.texture == null:
		return
	var c := size * 0.5
	# portais
	for it in world.interactables:
		if is_instance_valid(it) and it.kind == "portal":
			_marker(it.global_position, Color("#9ff0ff"), 5.0)
		elif is_instance_valid(it) and it.kind == "fragment":
			_marker(it.global_position, Color("#ffb8ff"), 3.5)
	for s in world.structures.values():
		_marker(s.global_position, Color("#e8c890"), 3.0)
	for w in world.wilds:
		if is_instance_valid(w) and not w.dead:
			_marker(w.global_position, Color("#ff6a5a") if w.aggressive else Color("#ffffff"), 2.5)
	if world.boss != null and is_instance_valid(world.boss):
		_marker(world.boss.global_position, UiTheme.GOLD, 6.0)
	for n in world.npcs:
		if is_instance_valid(n) and n.kind == "trainer":
			_marker(n.global_position, Color("#ff9a3a"), 5.0)
	var a := world.ally_actor()
	if a != null:
		_marker(a.global_position, UiTheme.GOOD, 4.0)
	# objetivo (preso à borda se longe)
	var mk := QuestLogic.marker(Game.state) if not Game.state.is_sandbox() else {}
	if not mk.is_empty() and mk["map"] == world.map_id:
		_marker(Vector3(mk["pos"].x, 0, mk["pos"].y), UiTheme.GOLD, 7.0, true)
	# jogador: seta apontando para onde o personagem olha
	var f := world.player.facing()
	var ang := atan2(f.x, -f.z) + world.rig.yaw
	var pts := PackedVector2Array([Vector2(0, -11), Vector2(8, 8), Vector2(0, 3), Vector2(-8, 8)])
	var xf := Transform2D(ang, c)
	var poly := PackedVector2Array()
	for pt in pts:
		poly.append(xf * pt)
	draw_colored_polygon(poly, Color.WHITE)
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.05, 0.05, 0.1), 2.0, true)
	draw_arc(c, size.x * 0.5 - 1.5, 0, TAU, 64, Color(1, 1, 1, 0.55), 3.0, true)
	# norte
	var north := c + Vector2(sin(world.rig.yaw), -cos(world.rig.yaw)) * (size.x * 0.5 - 12.0)
	draw_circle(north, 10.0, Color(0.1, 0.1, 0.15, 0.9))
	draw_string(UiTheme.font(900), north + Vector2(-6, 6), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#ff7a6a"))
