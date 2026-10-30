class_name Portrait
extends SubViewportContainer
## Retrato 3D de um Eco renderizado uma única vez num SubViewport próprio (barato para listas).

var vp: SubViewport


static func make(species_id: String, variant: bool = false, px: int = 128, live: bool = false) -> Portrait:
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(px, px)
	p.stretch = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.vp = SubViewport.new()
	p.vp.size = Vector2i(px, px)
	p.vp.own_world_3d = true
	p.vp.transparent_bg = true
	p.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
	p.add_child(p.vp)
	var root := Node3D.new()
	p.vp.add_child(root)
	var m := MonsterModel.new().build(species_id, variant)
	var sp: Dictionary = GameData.db().sp(species_id)
	var s := float(sp["body"]["size"])
	m.scale = Vector3.ONE / maxf(s, 0.5) * 0.9
	m.rotation.y = PI + 0.55
	root.add_child(m)
	if not live:
		m.set_process(false)
	var cam := Camera3D.new()
	cam.fov = 32
	root.add_child(cam)
	var h := m.height() / maxf(s, 0.5) * 0.9
	cam.look_at_from_position(Vector3(0, h * 0.75 + 0.4, 3.4), Vector3(0, h * 0.42, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	l.light_energy = 1.2
	root.add_child(l)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.9)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	return p
