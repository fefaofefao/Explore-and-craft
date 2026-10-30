extends SceneTree
## Personagens humanoides lado a lado (conferência visual).


func _init() -> void:
	var r := Node3D.new()
	root.add_child(r)
	var cfgs := [
		{"outfit": Color("#2f8a8a"), "outfit2": Color("#f2c14e"), "hair": Color("#2a1d18")},
		{"outfit": Color("#2a2a30"), "outfit2": Color("#c8a040"), "hair": Color("#d8d0c0"), "hat": "crown", "cape": true, "backpack": false},
		{"outfit": Color("#3a6a8a"), "outfit2": Color("#d0e8ff"), "hair": Color("#a83a2a"), "hat": "helmet", "backpack": false},
		{"outfit": Color("#c84a7a"), "outfit2": Color("#ffe0ec"), "hair": Color("#d8b060"), "hat": "cap", "backpack": false},
	]
	for i in cfgs.size():
		var h := HumanoidModel.new().configure(cfgs[i]).build()
		h.position = Vector3(i * 1.4 - 2.1, 0, 0)
		h.rotation.y = PI + 0.3
		r.add_child(h)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	ground.material_override = MeshLib.color_mat(Color("#7aab5a"))
	r.add_child(ground)
	var sky := SkyEnv.new()
	r.add_child(sky)
	sky.setup(GameData.db().maps["m1"]["biome"], 2)
	sky.update_time(0.42)
	var cam := Camera3D.new()
	cam.fov = 40
	r.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 5.2), Vector3(0, 0.95, 0))
	for f in 8:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/humans.png")
	quit()
