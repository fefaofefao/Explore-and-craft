extends SceneTree
## Renderiza todas as malhas da MeshLib numa grade (conferência visual).
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/preview/props.gd


func _init() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var keys := ["arvore", "pinheiro", "palmeira", "arvore_morta", "rocha", "minerio", "carvao_veio", "cristal", "arbusto", "capim",
		"cogumelos", "cacto", "monte_areia", "bloco_gelo", "lodo_poca", "obsidiana_veio", "ninho_pena", "espinhos", "muro_gelo",
		"porta_solar", "jaula", "fragmento", "berco", "portal", "altar", "casa", "poste", "caixote"]
	var i := 0
	for k in keys:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.get_mesh(k)
		mi.material_override = MeshLib.mat("glow" if k in ["cristal", "fragmento"] else "vc")
		mi.position = Vector3((i % 7) * 5.0 - 15.0, 0, (i / 7) * 6.0 - 9.0)
		if k == "casa":
			mi.scale = Vector3(4, 1, 4)
		root3.add_child(mi)
		i += 1
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = MeshLib.color_mat(Color("#6aab45"))
	root3.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	root3.add_child(env)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.look_at_from_position(Vector3(0, 22, 26), Vector3(0, 0, 0))
	for f in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/props.png")
	quit()
