extends SceneTree
func _init() -> void:
	var r := Node3D.new()
	root.add_child(r)
	var gen := WorldGen.new("m1")
	var sky := SkyEnv.new()
	r.add_child(sky)
	sky.setup(gen.biome, 2)
	sky.update_time(0.42)
	r.add_child(TerrainBuilder.build_terrain(gen))
	var g := TerrainBuilder.build_grass(gen, 2)
	r.add_child(g)
	sky.grass_mat = g.material_override
	sky.update_time(0.42)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.get_mesh("arvore")
	mi.material_override = MeshLib.mat("vc")
	r.add_child(mi)
	mi.position = Vector3(3, gen.height(3, 52), 52)
	var cam := Camera3D.new()
	r.add_child(cam)
	var p := Vector3(0, gen.height(0, 60) + 2.0, 60)
	cam.look_at_from_position(p + Vector3(0, 4, 8), p + Vector3(4, -1.5, -6))
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/grass.png")
	quit()
