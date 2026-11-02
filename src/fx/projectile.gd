class_name Projectile
extends Node3D
## Projétil de habilidade: voa até o alvo (que pode se mover) e chama on_hit ao chegar.
## O estilo define a aparência (folhas, fogo, água, gelo, faísca, pedra, sombra, luz) e a trajetória.

var target: Node3D
var on_hit: Callable
var speed := 20.0
var col := Color.WHITE
var style := "orb"
var _life := 3.0
var _t := 0.0
var _start := Vector3.ZERO
var _dist0 := 1.0
var _body: Node3D


func setup(from: Vector3, p_target: Node3D, p_col: Color, cb: Callable, p_style: String = "orb") -> Projectile:
	target = p_target
	col = p_col
	on_hit = cb
	style = p_style
	_body = Node3D.new()
	add_child(_body)
	SkillFX.projectile_body(_body, style, col)
	match style:
		"rock":
			speed = 14.0
		"water", "light":
			speed = 26.0
		"spark":
			speed = 24.0
		"shadow":
			speed = 15.0
	var trail := CPUParticles3D.new()
	trail.amount = 20 if style in ["fire", "water", "shadow"] else 12
	trail.lifetime = 0.35 if style != "fire" else 0.5
	trail.local_coords = false
	trail.mesh = MonsterModel._sph(0.1 if style != "fire" else 0.16, 6)
	var tcol := col
	if style == "shadow":
		tcol = Color("#6a2aa8")
	elif style == "rock":
		tcol = Color("#c8b48a")
	trail.material_override = SkillFX.glow_mat(tcol, 2.0, 0.8) if style != "rock" else SkillFX.solid_mat(tcol)
	trail.gravity = Vector3(0, 1.5, 0) if style == "fire" else (Vector3(0, -4, 0) if style == "water" else Vector3.ZERO)
	trail.initial_velocity_max = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	add_child(trail)
	position = from
	_start = from
	return self


func _ready() -> void:
	_start = global_position
	if target != null and is_instance_valid(target):
		_dist0 = maxf(1.0, _start.distance_to(_target_pos()))


func _target_pos() -> Vector3:
	return target.center() if target.has_method("center") else target.global_position + Vector3(0, 1, 0)


func _process(delta: float) -> void:
	_life -= delta
	_t += delta
	if target == null or not is_instance_valid(target) or _life <= 0.0:
		queue_free()
		return
	var tp := _target_pos()
	var d := tp - global_position
	if d.length() < 0.5:
		on_hit.call()
		SkillFX.projectile_hit(get_parent(), global_position, style, col)
		queue_free()
		return
	var step := d.normalized() * minf(speed * delta, d.length())
	# pedras fazem arco; faíscas tremem; folhas giram; sombra pulsa
	if style == "rock":
		var remain := clampf(d.length() / _dist0, 0.0, 1.0)
		step.y += (remain - 0.5) * 9.0 * delta
	global_position += step
	if d.length() > 0.05:
		_body.look_at(tp, Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT)
	match style:
		"spark":
			_body.position = Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), 0)
		"leaf":
			_body.rotate_object_local(Vector3.FORWARD, delta * 22.0)
		"rock":
			_body.rotate_object_local(Vector3.RIGHT, delta * 10.0)
		"shadow", "fire":
			_body.scale = Vector3.ONE * (1.0 + sin(_t * 25.0) * 0.12)
