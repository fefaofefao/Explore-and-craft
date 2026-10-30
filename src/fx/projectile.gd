class_name Projectile
extends Node3D
## Projétil de habilidade: voa até o alvo (que pode se mover) e chama on_hit ao chegar.

var target: Node3D
var on_hit: Callable
var speed := 20.0
var col := Color.WHITE
var _life := 3.0


func setup(from: Vector3, p_target: Node3D, p_col: Color, cb: Callable) -> Projectile:
	target = p_target
	col = p_col
	on_hit = cb
	var mi := MeshInstance3D.new()
	mi.mesh = MonsterModel._sph(0.22, 8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lightened(0.3)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var trail := CPUParticles3D.new()
	trail.amount = 16
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.mesh = MonsterModel._sph(0.1, 6)
	trail.material_override = m
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	add_child(trail)
	position = from
	return self


func _process(delta: float) -> void:
	_life -= delta
	if target == null or not is_instance_valid(target) or _life <= 0.0:
		queue_free()
		return
	var tp: Vector3 = target.center() if target.has_method("center") else target.global_position + Vector3(0, 1, 0)
	var d := tp - global_position
	if d.length() < 0.5:
		on_hit.call()
		FX.burst(get_parent(), global_position, col, 12, 4.0, false, true, 0.5)
		queue_free()
		return
	global_position += d.normalized() * minf(speed * delta, d.length())
