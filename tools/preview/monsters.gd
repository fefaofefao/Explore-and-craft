extends SceneTree
## Grade com todos os Ecos (conferência visual). Salva em docs/screenshots/ecos.png


func _init() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var ids: Array = GameData.db().species.keys()
	var i := 0
	var cols := 8
	for id in ids:
		var m := MonsterModel.new().build(id, OS.get_cmdline_user_args().has("variant"))
		var sp: Dictionary = GameData.db().sp(id)
		var sc := 1.0 / maxf(1.0, float(sp["body"]["size"]))
		m.scale = Vector3.ONE * sc * 1.4
		m.position = Vector3((i % cols) * 2.6 - cols * 1.3 + 1.3, 0, (i / cols) * 3.0 - 6.0)
		m.rotation.y = PI + 0.5
		root3.add_child(m)
		var lbl := Label3D.new()
		lbl.text = Loc.species_name(id)
		lbl.font_size = 48
		lbl.pixel_size = 0.004
		lbl.position = m.position + Vector3(0, -0.15, 0.9)
		lbl.rotation.x = -0.6
		lbl.outline_size = 10
		root3.add_child(lbl)
		i += 1
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = MeshLib.color_mat(Color("#7aab5a"))
	root3.add_child(ground)
	var sky := SkyEnv.new()
	root3.add_child(sky)
	sky.setup(GameData.db().maps["m1"]["biome"], 2)
	sky.update_time(0.42)
	var cam := Camera3D.new()
	cam.fov = 50
	root3.add_child(cam)
	cam.look_at_from_position(Vector3(0, 13, 12), Vector3(0, 0, 0.5))
	for f in 8:
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
	root.get_texture().get_image().save_png("res://docs/screenshots/ecos%s.png" % ("_aurora" if OS.get_cmdline_user_args().has("variant") else ""))
	quit()
