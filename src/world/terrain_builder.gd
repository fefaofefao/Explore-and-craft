class_name TerrainBuilder
extends RefCounted
## Constrói terreno facetado (cores por altura/inclinação), colisão por heightmap, água e grama.


static func build_terrain(gen: WorldGen) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	var n := WorldGen.CELLS
	var step := gen.half * 2.0 / n
	var b: Dictionary = gen.biome
	var ground: Array = []
	for c in b["ground"]:
		ground.append(Color(c))
	var sand := Color(b["sand"])
	var rock := Color(b["rock"])
	var high := Color(b["high"])
	var hamp := float(b["height"])
	var tint_noise := FastNoiseLite.new()
	tint_noise.seed = int(gen.md["seed"]) + 5
	tint_noise.frequency = 0.03
	var mb := MeshBuilder.new(int(gen.md["seed"]))
	for j in n:
		for i in n:
			var x0 := -gen.half + i * step
			var z0 := -gen.half + j * step
			var p00 := Vector3(x0, gen.grid_height(i, j), z0)
			var p10 := Vector3(x0 + step, gen.grid_height(i + 1, j), z0)
			var p01 := Vector3(x0, gen.grid_height(i, j + 1), z0 + step)
			var p11 := Vector3(x0 + step, gen.grid_height(i + 1, j + 1), z0 + step)
			for t in 2:
				var a: Vector3 = p00
				var bb: Vector3 = p10 if t == 0 else p11
				var cc: Vector3 = p11 if t == 0 else p01
				var cy := (a.y + bb.y + cc.y) / 3.0
				var nrm := (bb - a).cross(cc - a).normalized()
				var slope := 1.0 - absf(nrm.y)
				var col: Color
				if cy < 1.3:
					col = sand.darkened(clampf(-cy * 0.08, 0.0, 0.4))
				elif slope > 0.42:
					col = rock.lerp(rock.darkened(0.15), tint_noise.get_noise_2d(a.x * 3.0, a.z * 3.0) * 0.5 + 0.5)
				elif cy > 1.5 + hamp * 1.25:
					col = high
				else:
					var tn := tint_noise.get_noise_2d(a.x, a.z) * 0.5 + 0.5
					var idx := clampi(int(tn * ground.size()), 0, ground.size() - 1)
					col = ground[idx].lerp(ground[min(idx + 1, ground.size() - 1)], fmod(tn * ground.size(), 1.0) * 0.6)
					if slope > 0.25:
						col = col.lerp(rock, (slope - 0.25) * 2.0)
				# leve variação por face
				col = col.lightened(fmod(absf(a.x * 12.9898 + a.z * 78.233), 1.0) * 0.045)
				# garante orientação para cima
				if nrm.y >= 0.0:
					mb.tri(a, bb, cc, col)
				else:
					mb.tri(a, cc, bb, col)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.commit()
	var tm := MeshLib.mat("terrain")
	mi.material_override = tm
	body.add_child(mi)
	# colisão
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


static func build_water(gen: WorldGen) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(gen.half * 4.0, gen.half * 4.0)
	pm.subdivide_width = 48
	pm.subdivide_depth = 48
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/water.gdshader")
	var wc := Color(gen.biome["water"])
	var lava: bool = gen.biome.get("lava", false)
	sm.set_shader_parameter("is_lava", lava)
	if lava:
		sm.set_shader_parameter("deep_color", Color("#c8300a"))
		sm.set_shader_parameter("shallow_color", Color("#ffb02a"))
		sm.set_shader_parameter("wave_height", 0.05)
	else:
		sm.set_shader_parameter("deep_color", wc.darkened(0.35))
		sm.set_shader_parameter("shallow_color", wc.lightened(0.3))
	mi.material_override = sm
	mi.position.y = WorldGen.WATER_Y - 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func blade_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new(3)
	var w := 0.13
	var h := 0.55
	for k in 3:
		var a := PI * k / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * w
		mb.tri(-d, d, Vector3(0, h, 0), Color.WHITE)
	return mb.commit()


static func build_grass(gen: WorldGen, quality: int) -> MultiMeshInstance3D:
	var density := float(gen.biome.get("grass_density", 1.0))
	var max_n: int = [2500, 6000, 11000][clampi(quality, 0, 2)]
	var want := int(max_n * density)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	if want <= 0:
		return mmi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.md["seed"]) + 3
	var xforms: Array = []
	var cols: Array = []
	var tries := 0
	var flower_cols := [Color("#ffe14a"), Color("#ff7ab0"), Color("#ffffff"), Color("#9ab0ff")]
	# grama em tufos: escolhe um centro e espalha várias lâminas em volta
	while xforms.size() < want and tries < want * 3:
		tries += 1
		var cx := rng.randf_range(-gen.half * 0.85, gen.half * 0.85)
		var cz := rng.randf_range(-gen.half * 0.85, gen.half * 0.85)
		var h0 := gen.height(cx, cz)
		if h0 < 1.5 or gen.slope_at(cx, cz) > 1.6 or h0 > 1.5 + float(gen.biome["height"]) * 1.2:
			continue
		for k in 9:
			var x := cx + rng.randf_range(-1.6, 1.6)
			var z := cz + rng.randf_range(-1.6, 1.6)
			var y := gen.height(x, z)
			if y < 1.4:
				continue
			var s := rng.randf_range(0.6, 1.4)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, y - 0.03, z))
			xforms.append(t)
			var flower := rng.randf() < 0.025
			cols.append(flower_cols[rng.randi_range(0, 3)] * 1.6 if flower else Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/grass.gdshader")
	var gc := Color(gen.biome["grass"])
	sm.set_shader_parameter("base_color", gc.darkened(0.2))
	sm.set_shader_parameter("tip_color", gc.lightened(0.25))
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
