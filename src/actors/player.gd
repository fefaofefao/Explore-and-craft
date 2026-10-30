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
	velocity.x = lerpf(velocity.x, hv.x, clampf(delta * 12.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, hv.z, clampf(delta * 12.0, 0.0, 1.0))
	if swimming:
		# flutua na superfície
		velocity.y = lerpf(velocity.y, (water_y - 0.7 - global_position.y) * 4.0, clampf(delta * 6.0, 0.0, 1.0))
		if lava and hurt_cd <= 0.0 and not st.inv.has_protection("lava"):
			take_damage(8.0)
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
		var has_glider := st.inv.best_tool("glider").size() > 0
		gliding = has_glider and (jump_held or Input.is_action_pressed("jump")) and velocity.y < 0.0
		if gliding:
			velocity.y = maxf(velocity.y, -1.8)
			velocity.x = hv.x * 1.6 if hv.length() > 0.1 else velocity.x
			velocity.z = hv.z * 1.6 if hv.length() > 0.1 else velocity.z
	else:
		gliding = false
		_last_safe = global_position
	model.set_gliding(gliding)
	move_and_slide()
	# animação e orientação
	var hspeed := Vector2(velocity.x, velocity.z).length()
	model.move_speed = clampf(hspeed / 7.0, 0.0, 1.0)
	if hspeed > 0.3:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))
		_step_t += delta * hspeed
		if _step_t > 2.2 and is_on_floor():
			_step_t = 0.0
			Audio.play("step", 0.15)
	# segurança: caiu para fora do mundo
	if global_position.y < -25.0:
		global_position = _last_safe + Vector3(0, 2, 0)
		velocity = Vector3.ZERO


func jump() -> void:
	if _dead:
		return
	if is_on_floor() or swimming:
		velocity.y = float(GameData.db().cfg("player", "jump", 7.0))
		Audio.play("jump")


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
