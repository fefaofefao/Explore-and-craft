class_name TerrainBuilder
extends RefCounted
## Constrói terreno facetado (cores por altura/inclinação), colisão por heightmap, água e grama.


static var _noise_tex: Texture2D


static func noise_texture() -> Texture2D:
	if _noise_tex == null:
		_noise_tex = load("res://assets/textures/noise.png")
	return _noise_tex


static func build_terrain(gen: WorldGen) -> StaticBody3D:
	## Malha indexada com normais suaves; a cor vem do shader (mistura de materiais por altura/inclinação/ruído).
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	var n := WorldGen.CELLS
	var step := gen.half * 2.0 / n
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	norms.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			verts[k] = Vector3(-gen.half + i * step, gen.grid_height(i, j), -gen.half + j * step)
			var hl := gen.grid_height(i - 1, j)
			var hr := gen.grid_height(i + 1, j)
			var hd := gen.grid_height(i, j - 1)
			var hu := gen.grid_height(i, j + 1)
			norms[k] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			# mesma diagonal usada em WorldGen._cached_height (a-d); ordem horária vista de cima
			idx.append_array([a, b, d, a, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = terrain_material(gen)
	body.add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = n + 1
	shape.map_depth = n + 1
	var data := PackedFloat32Array()
	data.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			data[j * (n + 1) + i] = gen.grid_height(i, j)
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)
	return body


static func terrain_material(gen: WorldGen) -> ShaderMaterial:
	var b: Dictionary = gen.biome
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/terrain.gdshader")
	sm.set_shader_parameter("noise_tex", noise_texture())
	var g: Array = b["ground"]
	sm.set_shader_parameter("grass_a", Color(g[0]))
	sm.set_shader_parameter("grass_b", Color(g[2]))
	sm.set_shader_parameter("grass_c", Color(g[1]))
	sm.set_shader_parameter("dirt", Color(b.get("dirt", "#8a6a48")))
	sm.set_shader_parameter("sand", Color(b["sand"]))
	sm.set_shader_parameter("rock", Color(b["rock"]))
	sm.set_shader_parameter("high", Color(b["high"]))
	sm.set_shader_parameter("high_line", 1.5 + float(b["height"]) * 1.15)
	sm.set_shader_parameter("dirt_amount", float(b.get("dirt_amount", 0.35)))
	sm.set_shader_parameter("height_tex", height_texture(gen))
	sm.set_shader_parameter("map_half", gen.half)
	sm.set_shader_parameter("deep_tint", Color(b["water"]).darkened(0.35))
	return sm


static var _htex_cache: Dictionary = {}


static func height_texture(gen: WorldGen) -> ImageTexture:
	## Altura do terreno em 8 bits para a água calcular profundidade, espuma e transparência.
	if _htex_cache.has(gen.map_id):
		return _htex_cache[gen.map_id]
	var n := WorldGen.CELLS + 1
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	for j in n:
		for i in n:
			var h := gen.grid_height(i, j)
			img.set_pixel(i, j, Color(clampf((h + 8.0) / 16.0, 0.0, 1.0), 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_htex_cache[gen.map_id] = tex
	return tex


static func build_water(gen: WorldGen) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(gen.half * 4.0, gen.half * 4.0)
	pm.subdivide_width = 64
	pm.subdivide_depth = 64
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/water.gdshader")
	sm.set_shader_parameter("height_tex", height_texture(gen))
	sm.set_shader_parameter("noise_tex", noise_texture())
	sm.set_shader_parameter("map_half", gen.half)
	sm.set_shader_parameter("sky_color", Color(gen.biome["sky_horizon"]))
	var wc := Color(gen.biome["water"])
	var lava: bool = gen.biome.get("lava", false)
	sm.set_shader_parameter("is_lava", lava)
	if lava:
		sm.set_shader_parameter("deep_color", Color("#9a1a06"))
		sm.set_shader_parameter("shallow_color", Color("#ffb02a"))
		sm.set_shader_parameter("wave_height", 0.05)
	else:
		sm.set_shader_parameter("deep_color", wc.darkened(0.45))
		sm.set_shader_parameter("shallow_color", wc.lightened(0.45))
	mi.material_override = sm
	mi.position.y = WorldGen.WATER_Y - 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func blade_mesh() -> ArrayMesh:
	## Tufo com 5 lâminas curvas e afinadas.
	var mb := MeshBuilder.new(3)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		var side := d.cross(Vector3.UP).normalized()
		var h := 0.42 + (k % 3) * 0.08
		var base := d * 0.07
		var prev_l := base - side * 0.05
		var prev_r := base + side * 0.05
		for sgi in 3:
			var t := float(sgi + 1) / 3.0
			var c := base + d * (0.22 * t * t) + Vector3.UP * h * t
			var w := 0.05 * (1.0 - t) + 0.004
			var l := c - side * w
			var r := c + side * w
			mb.quad(prev_l, prev_r, r, l, Color.WHITE)
			prev_l = l
			prev_r = r
	return mb.commit()


static var _noise_img: Image


static func _noise_at(x: float, z: float, scale: float, ch: int) -> float:
	if _noise_img == null:
		_noise_img = noise_texture().get_image()
		if _noise_img.is_compressed():
			_noise_img.decompress()
	var s := _noise_img.get_width()
	var u := posmod(int(x * scale * s), s)
	var v := posmod(int(z * scale * s), s)
	var c := _noise_img.get_pixel(u, v)
	match ch:
		0:
			return c.r
		1:
			return c.g
		2:
			return c.b
	return c.a


static func ground_color(gen: WorldGen, x: float, z: float) -> Color:
	## Reproduz a cor de grama do shader do terreno para a grama/decoração combinarem com o chão.
	var g: Array = gen.biome["ground"]
	var n1 := _noise_at(x, z, 0.006, 0)
	var n2 := _noise_at(x, z, 0.03, 1)
	var c := Color(g[0]).lerp(Color(g[2]), smoothstep(0.3, 0.7, n1))
	c = c.lerp(Color(g[1]), smoothstep(0.45, 0.75, n2) * 0.6)
	return c


static func is_dirt(gen: WorldGen, x: float, z: float) -> bool:
	var amt := float(gen.biome.get("dirt_amount", 0.35))
	var v := _noise_at(x, z, 0.03, 0) * 0.55 + _noise_at(x, z, 0.006, 1) * 0.45 + amt * 0.2 - 0.05
	return v > 0.66 and amt > 0.05


static func chunked(name: String, mesh: Mesh, xforms: Array, cols: Array, mat: Material, half: float, vis_end: float, chunk: float = 30.0) -> Node3D:
	## Divide instâncias em blocos com alcance de visibilidade (só o que está perto é desenhado).
	var root := Node3D.new()
	root.name = name
	var buckets := {}
	for i in xforms.size():
		var o: Vector3 = xforms[i].origin
		var key := Vector2i(int(floor((o.x + half) / chunk)), int(floor((o.z + half) / chunk)))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(i)
	for key in buckets:
		var ids: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = cols.size() > 0
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			mm.set_instance_transform(j, xforms[ids[j]])
			if cols.size() > 0:
				mm.set_instance_color(j, cols[ids[j]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 6.0
		root.add_child(mmi)
	return root


static func build_grass(gen: WorldGen, quality: int) -> Node3D:
	var density := float(gen.biome.get("grass_density", 1.0))
	var max_n: int = [5000, 12000, 20000][clampi(quality, 0, 2)]
	var want := int(max_n * density)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/grass.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.md["seed"]) + 3
	var xforms: Array = []
	var cols: Array = []
	var tries := 0
	var hl := 1.5 + float(gen.biome["height"]) * 1.1
	while xforms.size() < want and tries < want * 4:
		tries += 1
		var cx := rng.randf_range(-gen.half * 0.86, gen.half * 0.86)
		var cz := rng.randf_range(-gen.half * 0.86, gen.half * 0.86)
		var h0 := gen.height(cx, cz)
		if h0 < 1.9 or h0 > hl or gen.slope_at(cx, cz, 1.0) > 1.3 or is_dirt(gen, cx, cz):
			continue
		var base := ground_color(gen, cx, cz)
		for k in 6:
			var x := cx + rng.randf_range(-1.4, 1.4)
			var z := cz + rng.randf_range(-1.4, 1.4)
			var y := gen.height(x, z)
			if y < 1.8:
				continue
			var sc := rng.randf_range(0.5, 0.95)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.25), sc)), Vector3(x, y - 0.04, z)))
			cols.append(base.lightened(rng.randf_range(-0.06, 0.08)).srgb_to_linear())
	var node := chunked("Grass", blade_mesh(), xforms, cols, sm, gen.half, [32.0, 44.0, 58.0][clampi(quality, 0, 2)])
	node.set_meta("mat", sm)
	return node


static func build_decor(gen: WorldGen, quality: int) -> Node3D:
	## Decoração não interativa (flores, pedrinhas, samambaias, gravetos...) que dá densidade ao mundo.
	var root := Node3D.new()
	root.name = "Decor"
	var kinds: Dictionary = gen.biome.get("decor", {"flor": 1.0, "pedrinha": 0.6, "samambaia": 0.5})
	var mult: float = [0.4, 0.75, 1.0][clampi(quality, 0, 2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.md["seed"]) + 21
	var mat := MeshLib.mat("foliage")
	for kind in kinds:
		var want := int(1400 * float(kinds[kind]) * mult)
		var xf: Array = []
		var tries := 0
		var beach: bool = kind == "concha"
		while xf.size() < want and tries < want * 5:
			tries += 1
			var x := rng.randf_range(-gen.half * 0.86, gen.half * 0.86)
			var z := rng.randf_range(-gen.half * 0.86, gen.half * 0.86)
			var y := gen.height(x, z)
			if beach:
				if y < 0.3 or y > 1.6:
					continue
			elif y < 1.9 or gen.slope_at(x, z) > 2.0:
				continue
			if gen.near_pad(x, z, 1.0):
				continue
			var sc := rng.randf_range(0.7, 1.3)
			xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, y - 0.03, z)))
		for v in 3:
			var part: Array = []
			for i in xf.size():
				if i % 3 == v:
					part.append(xf[i])
			if part.size() > 0:
				root.add_child(chunked(kind, MeshLib.get_mesh("decor_" + kind, v), part, [], mat, gen.half, [40.0, 55.0, 70.0][clampi(quality, 0, 2)]))
	return root
