class_name FX
extends RefCounted
## Efeitos visuais curtos: partículas, números de dano, anéis, brilhos. Tudo procedural.

static var _quad_mesh: Mesh
static var _cube_mesh: Mesh


static func _particle_mesh(cube: bool) -> Mesh:
	if cube:
		if _cube_mesh == null:
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.12, 0.12)
			_cube_mesh = b
		return _cube_mesh
	if _quad_mesh == null:
		var s := SphereMesh.new()
		s.radius = 0.08
		s.height = 0.16
		s.radial_segments = 6
		s.rings = 3
		_quad_mesh = s
	return _quad_mesh


static func burst(parent: Node, pos: Vector3, col: Color, amount: int = 14, speed: float = 4.0, cube: bool = true, glow: bool = false, life: float = 0.7) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -12.0 if cube else -2.0, 0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.mesh = _particle_mesh(cube)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.5
	p.material_override = m
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


static func number(parent: Node, pos: Vector3, text: String, col: Color, big: bool = false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0018 if big else 0.0014
	l.font_size = 64
	l.outline_size = 18
	l.modulate = col
	l.outline_modulate = Color(0.05, 0.03, 0.08)
	l.font = UiTheme.font(900)
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4, 0), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)


static func ring(parent: Node, pos: Vector3, col: Color, radius: float = 3.0, time: float = 0.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


static func beam(parent: Node, from: Vector3, to: Vector3, col: Color, time: float = 0.25) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var len := from.distance_to(to)
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = len
	cm.radial_segments = 6
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.tween_callback(mi.queue_free)


static func type_color(t: String) -> Color:
	return Color(GameData.db().types["colors"].get(t, "#ffffff"))
