class_name Wind
extends RefCounted
## Vento global do mapa: direção que gira aos poucos e muda de tempos em tempos, rajadas e
## um deslocamento acumulado (as "ondas" de vento que correm pela grama seguem esse deslocamento).

var angle := 0.6  # radianos (direção para onde o vento sopra, no plano XZ)
var target_angle := 0.6
var strength := 0.5  # 0..1.4
var base := 0.45
var offset := Vector2.ZERO
var _t := 0.0
var _change_in := 18.0
var rng := RandomNumberGenerator.new()


func _init(seed_v: int = 1, p_base: float = 0.45) -> void:
	rng.seed = seed_v
	base = p_base
	angle = rng.randf() * TAU
	target_angle = angle
	_change_in = rng.randf_range(10.0, 22.0)


func dir() -> Vector2:
	return Vector2(cos(angle), sin(angle))


func dir3() -> Vector3:
	var d := dir()
	return Vector3(d.x, 0.0, d.y)


func update(delta: float) -> void:
	_t += delta
	_change_in -= delta
	if _change_in <= 0.0:
		# virada: às vezes leve, às vezes o vento muda totalmente de lado
		_change_in = rng.randf_range(12.0, 30.0)
		var turn := rng.randf_range(0.5, 1.6) * (1.0 if rng.randf() < 0.5 else -1.0)
		if rng.randf() < 0.2:
			turn = PI * rng.randf_range(0.7, 1.0)
		target_angle = angle + turn
	angle = lerp_angle(angle, target_angle, clampf(delta * 0.35, 0.0, 1.0))
	# rajadas: soma de senoides lentas (sem ruído para ficar determinístico e barato)
	var gust := 0.5 + 0.5 * sin(_t * 0.37) * sin(_t * 0.11 + 1.7) + 0.25 * sin(_t * 1.3 + 0.4)
	strength = clampf(base * (0.55 + gust * 0.9), 0.05, 1.4)
	offset += dir() * (0.8 + strength * 3.2) * delta


func apply(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("wind_dir", dir())
	mat.set_shader_parameter("wind_str", strength)
	mat.set_shader_parameter("wind_offset", offset)
