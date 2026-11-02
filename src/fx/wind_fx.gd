class_name WindFX
extends Node3D
## Sinais visuais do vento perto da câmera: rastros brancos finos (como riscos de ar) e folhas/pétalas
## voando na direção do vento. A direção e a velocidade acompanham o Wind global.

var streaks: CPUParticles3D
var leaves: CPUParticles3D
var _wind: Wind


func setup(p_wind: Wind, quality: int, leaf_color: Color, with_leaves: bool) -> WindFX:
	_wind = p_wind
	name = "WindFX"
	streaks = CPUParticles3D.new()
	streaks.amount = [6, 12, 18][clampi(quality, 0, 2)]
	streaks.lifetime = 1.6
	streaks.local_coords = false
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(16, 2.5, 16)
	streaks.gravity = Vector3.ZERO
	streaks.spread = 4.0
	streaks.initial_velocity_min = 7.0
	streaks.initial_velocity_max = 11.0
	streaks.particle_flag_align_y = true
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 2.2)
	streaks.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 0.55)
	m.disable_receive_shadows = true
	streaks.material_override = m
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.3, Color(1, 1, 1, 0.75))
	grad.add_point(0.7, Color(1, 1, 1, 0.6))
	streaks.color_ramp = grad
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(0.5, 1.0))
	sc.add_point(Vector2(1, 0.4))
	streaks.scale_amount_curve = sc
	streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streaks)
	if with_leaves:
		leaves = CPUParticles3D.new()
		leaves.amount = [10, 22, 34][clampi(quality, 0, 2)]
		leaves.lifetime = 5.0
		leaves.local_coords = false
		leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		leaves.emission_box_extents = Vector3(18, 4, 18)
		leaves.spread = 25.0
		leaves.initial_velocity_min = 1.5
		leaves.initial_velocity_max = 3.5
		leaves.angular_velocity_min = -280
		leaves.angular_velocity_max = 280
		leaves.scale_amount_min = 0.6
		leaves.scale_amount_max = 1.2
		var lq := QuadMesh.new()
		lq.size = Vector2(0.14, 0.09)
		leaves.mesh = lq
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.cull_mode = BaseMaterial3D.CULL_DISABLED
		lm.vertex_color_use_as_albedo = true
		leaves.material_override = lm
		leaves.color = leaf_color
		leaves.color_initial_ramp = _leaf_ramp(leaf_color)
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(leaves)
	return self


static func _leaf_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c.darkened(0.15))
	g.set_color(1, c.lightened(0.25).lerp(Color("#e8d070"), 0.4))
	return g


func follow(cam_pos: Vector3, look_dir: Vector3) -> void:
	if _wind == null:
		return
	# emite um pouco à frente da câmera para os rastros passarem pela tela
	global_position = cam_pos + Vector3(look_dir.x, 0, look_dir.z).normalized() * 9.0 + Vector3(0, -1.5, 0)
	var d := _wind.dir3()
	var s := _wind.strength
	streaks.direction = d
	streaks.initial_velocity_min = 5.0 + s * 6.0
	streaks.initial_velocity_max = 8.0 + s * 8.0
	# rastros só aparecem com vento razoável
	(streaks.material_override as StandardMaterial3D).albedo_color.a = clampf((s - 0.25) * 1.1, 0.0, 0.6)
	if leaves != null:
		leaves.direction = (d + Vector3(0, 0.25, 0)).normalized()
		leaves.gravity = d * (1.5 + s * 3.0) + Vector3(0, -0.7, 0)
