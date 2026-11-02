class_name Player
extends CharacterBody3D
## Personagem jogável: movimento relativo à câmera, pulo, corrida, nado, planador e animação.

signal died

const GRAVITY := 22.0

var model: HumanoidModel
var rig: CameraRig
var controls: TouchControls
var gen: WorldGen
var lava := false
var swimming := false
var gliding := false
var jump_held := false
var sprint := false
var hurt_cd := 0.0
var _dead := false
var _step_t := 0.0
var _last_safe := Vector3.ZERO
var _coyote := 0.0  # tempo desde que saiu do chão (permite pular logo após descer um degrau)
var _jump_buffer := 0.0  # pulo pedido um pouco antes de tocar o chão


func setup(p_gen: WorldGen, p_rig: CameraRig, p_controls: TouchControls) -> void:
	gen = p_gen
	rig = p_rig
	controls = p_controls
	lava = gen.biome.get("lava", false)
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	model = HumanoidModel.new().configure({"outfit": Color("#2f8a8a"), "outfit2": Color("#f2c14e"), "hair": Color("#2a1d18")}).build()
	add_child(model)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(52)
	_last_safe = global_position


func is_dead() -> bool:
	return _dead


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector3.ZERO
		return
	var st: GameState = Game.state
	hurt_cd = maxf(0.0, hurt_cd - delta)
	var input := controls.move if controls != null else Vector2.ZERO
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if kb.length() > 0.1:
		input = kb
	var dir := Vector3.ZERO
	if rig != null:
		dir = rig.right_flat() * input.x + rig.forward_flat() * -input.y
	var speed := float(GameData.db().cfg("player", "move_speed", 6.5))
	if sprint or Input.is_action_pressed("sprint") or input.length() > 0.95:
		speed *= float(GameData.db().cfg("player", "sprint_mult", 1.5)) if input.length() > 0.95 else 1.0
	var water_y := WorldGen.WATER_Y
	swimming = global_position.y < water_y - 0.75
	if swimming:
		speed *= 0.55
	var hv := dir * speed * minf(input.length() * 1.15, 1.0)
	hv = _limit_sea(hv, delta)
	# aceleração com peso: arranca rápido, freia um pouco mais devagar, controle reduzido no ar
	var accel := 10.0 if hv.length() > Vector2(velocity.x, velocity.z).length() else 14.0
	if not is_on_floor() and not swimming:
		accel = 4.0
	velocity.x = lerpf(velocity.x, hv.x, clampf(delta * accel, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, hv.z, clampf(delta * accel, 0.0, 1.0))
	var was_floor := is_on_floor()
	var fall_v := velocity.y
	if swimming:
		# flutua na superfície
		velocity.y = lerpf(velocity.y, (water_y - 0.7 - global_position.y) * 4.0, clampf(delta * 6.0, 0.0, 1.0))
		if lava and hurt_cd <= 0.0 and not st.inv.has_protection("lava"):
			take_damage(8.0)
	elif not is_on_floor() and _coyote > 0.14:
		velocity.y -= GRAVITY * delta
		var has_glider := st.inv.best_tool("glider").size() > 0
		gliding = has_glider and (jump_held or Input.is_action_pressed("jump")) and velocity.y < 0.0
		if gliding:
			velocity.y = maxf(velocity.y, -1.8)
			velocity.x = hv.x * 1.6 if hv.length() > 0.1 else velocity.x
			velocity.z = hv.z * 1.6 if hv.length() > 0.1 else velocity.z
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		gliding = false
		if is_on_floor():
			_last_safe = global_position
	model.set_gliding(gliding)
	# tolerâncias de pulo
	_coyote = 0.0 if is_on_floor() else _coyote + delta
	if _jump_buffer > 0.0:
		_jump_buffer -= delta
		if _can_jump():
			_do_jump()
	move_and_slide()
	# aterrissagem: amassada, poeira e tremida proporcionais à queda
	if not was_floor and is_on_floor() and fall_v < -5.0:
		var k := clampf(-fall_v / 16.0, 0.2, 1.0)
		model.land(k)
		_dust(10 + int(k * 12), 2.0 + k * 2.0)
		Audio.play("step", 0.05)
		if rig:
			rig.shake = minf(1.0, rig.shake + 0.25 * k)
	# animação e orientação
	var hspeed := Vector2(velocity.x, velocity.z).length()
	model.move_speed = clampf(hspeed / 7.0, 0.0, 1.4)
	if hspeed > 0.3:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		var prev_yaw := model.rotation.y
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(delta * 14.0, 0.0, 1.0))
		# inclina o corpo para dentro da curva
		model.turn_lean = lerpf(model.turn_lean, clampf(angle_difference(prev_yaw, model.rotation.y) / maxf(delta, 0.001) * 0.04, -0.3, 0.3), 0.2)
		_step_t += delta * hspeed
		if _step_t > 1.9 and is_on_floor():
			_step_t = 0.0
			Audio.play("step", 0.15)
			if hspeed > 6.0:
				_dust(4, 1.2)
	else:
		model.turn_lean = lerpf(model.turn_lean, 0.0, 0.2)
	# câmera abre o campo de visão ao correr
	if rig and rig.cam:
		rig.cam.fov = lerpf(rig.cam.fov, 62.0 + clampf((hspeed - 6.5) * 1.6, 0.0, 7.0), clampf(delta * 4.0, 0.0, 1.0))
	# segurança: caiu para fora do mundo
	if global_position.y < -25.0:
		global_position = _last_safe + Vector3(0, 2, 0)
		velocity = Vector3.ZERO


signal deep_water

const DEEP := -2.2  # profundidade do fundo a partir da qual não dá mais para nadar
var _deep_warn := 0.0


func _limit_sea(hv: Vector3, delta: float) -> Vector3:
	## Mar aberto é intransponível: na água, o jogador não avança para onde o fundo fica fundo demais
	## nem passa da borda do mapa. Em cima de pontes (fora da água) nada é bloqueado.
	_deep_warn = maxf(0.0, _deep_warn - delta)
	var p := global_position
	var r := Vector2(p.x, p.z).length()
	var limit := gen.half * 0.9
	if r > limit:
		# empurra de volta para dentro (segurança extra, mesmo fora da água)
		var back := -Vector3(p.x, 0, p.z).normalized()
		global_position += back * (r - limit)
		if hv.dot(back) < 0.0:
			hv -= back * hv.dot(back)
	if not swimming or hv.length() < 0.01:
		return hv
	var h_here := gen.height(p.x, p.z)
	if h_here < DEEP:
		# já está no fundo (ex.: caiu de uma ponte): só deixa nadar em direção à ilha
		var to_center := -Vector3(p.x, 0, p.z).normalized()
		var away := hv.dot(to_center)
		if away < 0.0:
			hv -= to_center * away
		return hv
	var ahead := p + hv.normalized() * 1.5
	var h_ahead := gen.height(ahead.x, ahead.z)
	if h_ahead < DEEP and h_ahead <= h_here:
		# bloqueia só a componente que leva ao fundo; deixa nadar ao longo da costa ou voltar
		var grad := Vector3(gen.height(p.x + 1.0, p.z) - gen.height(p.x - 1.0, p.z), 0, gen.height(p.x, p.z + 1.0) - gen.height(p.x, p.z - 1.0))
		var deeper := -grad.normalized() if grad.length() > 0.001 else hv.normalized()
		var into := hv.dot(deeper)
		if into > 0.0:
			hv -= deeper * into
		if _deep_warn <= 0.0:
			_deep_warn = 6.0
			emit_signal("deep_water")
	return hv


func _can_jump() -> bool:
	return (is_on_floor() or _coyote < 0.15 or swimming) and velocity.y <= 0.5


func _do_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 1.0
	velocity.y = float(GameData.db().cfg("player", "jump", 7.0))
	model.jump_stretch()
	_dust(6, 1.5)
	floor_snap_length = 0.0
	get_tree().create_timer(0.2).timeout.connect(func(): floor_snap_length = 0.6)
	Audio.play("jump")


func _dust(n: int, spd: float) -> void:
	var col := Color(gen.biome.get("dirt", "#9a7a58")).lightened(0.25)
	if global_position.y < 1.5:
		col = Color(gen.biome["sand"])
	FX.burst(get_parent(), global_position + Vector3(0, 0.1, 0), col, n, spd, false, false, 0.5)


func jump() -> void:
	if _dead:
		return
	if _can_jump():
		_do_jump()
	else:
		_jump_buffer = 0.18


func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		model.rotation.y = atan2(-d.x, -d.z)


func facing() -> Vector3:
	return Vector3(-sin(model.rotation.y), 0, -cos(model.rotation.y))


func take_damage(amount: float) -> void:
	if _dead or Game.state.is_sandbox():
		return
	var st: GameState = Game.state
	st.hp = maxf(0.0, st.hp - amount)
	hurt_cd = 0.6
	if rig:
		rig.shake = minf(1.0, rig.shake + 0.35)
	Audio.play("hurt")
	Audio.vibrate(40)
	if st.hp <= 0.0:
		_dead = true
		model.rotation.x = -PI / 2
		model.position.y = 0.3
		emit_signal("died")


func revive(at: Vector3) -> void:
	_dead = false
	model.rotation.x = 0
	model.position.y = 0
	global_position = at
	velocity = Vector3.ZERO
	Game.state.hp = Game.state.max_hp()
