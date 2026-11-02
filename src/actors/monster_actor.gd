class_name MonsterActor
extends CharacterBody3D
## Eco em cena: selvagem, aliado (parceiro do jogador), de treinador ou chefe (Alfa).
## IA simples e legível: vagar, perseguir, atacar, fugir, seguir o jogador, usar habilidades.

signal died(actor: MonsterActor)

const GRAVITY := 22.0

var m: Dictionary
var role := "wild"  # wild | ally | trainer | boss | display
var world: Node  # World
var model: MonsterModel
var hp_mult := 1.0
var max_hp := 1
var target: Node3D = null
var home := Vector3.ZERO
var leash := 32.0
var aggressive := false
var state := "idle"
var dead := false
var capturing := false
var collared := false
var skill_cd: Dictionary = {}
var buff_t := 0.0
var enraged := false
var radius := 0.5
var speed := 4.0

var _think := 0.0
var _wander_to := Vector3.ZERO
var _basic_cd := 0.0
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _bar_show := 0.0
var _name_label: Label3D
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _contact_cd := 0.0
var _gen: WorldGen


func setup(p_m: Dictionary, p_role: String, p_world: Node, p_gen: WorldGen) -> MonsterActor:
	m = p_m
	role = p_role
	world = p_world
	_gen = p_gen
	var sp: Dictionary = GameData.db().sp(m["sp"])
	var cfgc: Dictionary = GameData.db().config["combat"]
	if role == "boss":
		hp_mult = float(cfgc["boss_hp_mult"])
	elif role == "trainer":
		hp_mult = float(cfgc["trainer_hp_mult"])
	max_hp = int(MonsterLogic.max_hp(m) * hp_mult)
	if role != "ally":
		m["hp"] = max_hp
	var temper: String = sp.get("temper", "")
	aggressive = temper in ["agressivo", "valente", "agitado", "alfa", "orgulhoso"] or role in ["boss", "trainer"] or collared
	collision_layer = 8
	collision_mask = 1 | 2
	model = MonsterModel.new().build(m["sp"], m.get("variant", false))
	add_child(model)
	radius = clampf(0.35 * float(sp["body"]["size"]) + 0.15, 0.25, 1.3)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(radius * 2.0 + 0.05, model.height() * 0.8)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	speed = clampf(2.6 + MonsterLogic.stat(m, "spd") / 25.0, 2.6, 6.5)
	if role == "boss":
		speed *= 0.85
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(55)
	_build_bar()
	return self


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position.y = model.height() + 0.35
	add_child(_bar_root)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.13)
	bg.mesh = q
	var mbg := StandardMaterial3D.new()
	mbg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mbg.albedo_color = Color(0, 0, 0, 0.6)
	mbg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mbg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mbg.no_depth_test = true
	mbg.render_priority = 1
	bg.material_override = mbg
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.96, 0.09)
	q2.center_offset = Vector3(0.48, 0, 0.001)
	_bar_fill.mesh = q2
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = UiTheme.GOOD if role == "ally" else (UiTheme.GOLD if role == "boss" else UiTheme.DANGER)
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mf.no_depth_test = true
	mf.render_priority = 2
	_bar_fill.material_override = mf
	_bar_fill.position.x = -0.48
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(_bar_fill)
	_name_label = Label3D.new()
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.fixed_size = false
	_name_label.pixel_size = 0.006
	_name_label.font_size = 40
	_name_label.outline_size = 10
	_name_label.font = UiTheme.font(800)
	_name_label.position.y = 0.22
	var tag := ""
	if role == "boss":
		tag = "★ " + Loc.t("boss_tag") + " "
	elif m.get("variant", false):
		tag = "✦ "
	_name_label.text = "%s%s  %s" % [tag, MonsterLogic.display_name(m), Loc.t("level_short", [m["lvl"]])]
	_name_label.modulate = UiTheme.GOLD if role == "boss" else (Color("#fff6b0") if m.get("variant", false) else Color.WHITE)
	_bar_root.add_child(_name_label)
	_bar_root.visible = role in ["boss", "trainer", "ally"]
	_update_bar()


func _update_bar() -> void:
	var f := clampf(float(m["hp"]) / maxf(1.0, max_hp), 0.0, 1.0)
	_bar_fill.scale = Vector3(maxf(f, 0.001), 1, 1)


func hp_frac() -> float:
	return clampf(float(m["hp"]) / maxf(1.0, max_hp), 0.0, 1.0)


func is_enemy_of(other: Node) -> bool:
	if other == null or not is_instance_valid(other):
		return false
	if other is MonsterActor:
		var o := other as MonsterActor
		if role == "ally":
			return o.role != "ally"
		return o.role == "ally"
	if other is Player:
		return role in ["wild", "boss"]
	return false


func types() -> Array:
	return MonsterLogic.types_of(m)


func stat(s: String) -> float:
	var v := float(MonsterLogic.stat(m, s))
	if buff_t > 0.0 and s in ["atk", "def"]:
		v *= 1.3
	if enraged and s == "atk":
		v *= 1.25
	return v


func center() -> Vector3:
	return global_position + Vector3(0, model.height() * 0.5, 0)


# ------------------------------------------------------------------ dano
func take_hit(dmg: int, mult: float, crit: bool, from: Node3D = null) -> void:
	if dead or capturing:
		return
	m["hp"] = maxi(0, int(m["hp"]) - dmg)
	model.play_hurt()
	_bar_show = 4.0
	_bar_root.visible = true
	_update_bar()
	var col := Color.WHITE
	if mult > 1.05:
		col = UiTheme.GOLD
	elif mult < 0.95:
		col = Color("#9aa0b0")
	FX.number(world, center() + Vector3(0, 0.6, 0), str(dmg) + ("!" if crit else ""), col, crit or mult > 1.05)
	if from != null and role != "ally":
		var al: Node3D = world.ally_actor()
		if from is Player and al != null and al.global_position.distance_to(global_position) < 20.0:
			target = al  # o treinador bateu, mas o revide vai no Eco dele
		elif target == null or not is_instance_valid(target):
			target = from
		state = "chase"
		for mate in pack:
			if is_instance_valid(mate) and mate != self and not mate.dead:
				mate.alert(target)
	if role == "wild" and not aggressive and from != null and hp_frac() < 0.35 and randf() < 0.5:
		state = "flee"
	if role == "boss" and not enraged and hp_frac() < 0.5:
		enraged = true
		speed *= 1.3
		FX.ring(world, global_position, UiTheme.DANGER, 6.0, 0.6)
		Game.notify(Loc.t("boss_appears", [MonsterLogic.display_name(m)]), "warn")
	if int(m["hp"]) <= 0:
		_die()


var _kb := Vector3.ZERO
var pack: Array = []  # horda: companheiros que atacam juntos


func set_horde_tag() -> void:
	## Nome da horda em vermelho para o jogador perceber o perigo.
	_name_label.text = "⚠ " + _name_label.text
	_name_label.modulate = Color("#ff8a7a")
	_bar_root.visible = true


func alert(t: Node3D) -> void:
	if dead or role == "ally" or t == null:
		return
	target = t
	state = "chase"

func knockback(v: Vector3) -> void:
	## Empurrão ao ser atingido (chefes quase não se movem).
	_kb = v * (0.25 if role == "boss" else 1.0)
	_kb.y = 0.0


func heal_frac(f: float) -> void:
	m["hp"] = mini(max_hp, int(m["hp"]) + int(max_hp * f))
	_update_bar()
	FX.burst(world, center(), UiTheme.GOOD, 10, 2.0, false, true)


func _die() -> void:
	dead = true
	model.set_fainted(true)
	velocity = Vector3.ZERO
	emit_signal("died", self)
	if role != "ally":
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
		tw.tween_callback(func():
			FX.burst(world, global_position + Vector3(0, 0.4, 0), Color("#d8b8ff"), 14, 3.0, false, true)
			queue_free())


# ------------------------------------------------------------------ IA
func _physics_process(delta: float) -> void:
	if dead or capturing or role == "display":
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
			move_and_slide()
		return
	_basic_cd = maxf(0.0, _basic_cd - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	buff_t = maxf(0.0, buff_t - delta)
	for k in skill_cd.keys():
		skill_cd[k] = maxf(0.0, float(skill_cd[k]) - delta)
	if _bar_show > 0.0:
		_bar_show -= delta
		if _bar_show <= 0.0 and not role in ["boss", "trainer", "ally"]:
			_bar_root.visible = false
	_think -= delta
	if _think <= 0.0:
		_think = 0.25 + randf() * 0.1
		_decide()
	var want := Vector3.ZERO
	var spd := speed
	match state:
		"wander":
			want = _wander_to - global_position
			spd *= 0.45
			if Vector2(want.x, want.z).length() < 1.0:
				state = "idle"
		"chase":
			if target != null and is_instance_valid(target):
				var tp := target.global_position
				var d := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
				var reach := _reach()
				if d > reach:
					want = tp - global_position
				else:
					_face(tp)
					_try_attack()
		"flee":
			if target != null and is_instance_valid(target):
				want = global_position - target.global_position
				spd *= 1.15
		"return":
			want = home - global_position
			if Vector2(want.x, want.z).length() < 2.0:
				state = "idle"
				m["hp"] = max_hp
				_update_bar()
		"follow":
			var pl: Node3D = world.player
			var to: Vector3 = pl.global_position + pl.facing().rotated(Vector3.UP, 2.4) * 2.4
			want = to - global_position
			var dl := Vector2(want.x, want.z).length()
			if dl > 28.0:
				global_position = pl.global_position + Vector3(1.5, 1.0, 1.5)
				velocity = Vector3.ZERO
				want = Vector3.ZERO
			elif dl < 1.2:
				want = Vector3.ZERO
			spd = maxf(speed, 7.5) * (1.4 if dl > 8.0 else 1.0)
	want.y = 0
	var hv := Vector3.ZERO
	if want.length() > 0.2:
		hv = want.normalized() * spd
		_face(global_position + want)
	velocity.x = lerpf(velocity.x, hv.x, clampf(delta * 8.0, 0.0, 1.0)) + _kb.x
	velocity.z = lerpf(velocity.z, hv.z, clampf(delta * 8.0, 0.0, 1.0)) + _kb.z
	_kb = _kb.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	if model.flying:
		velocity.y = 0.0
		var gy := _gen.height(global_position.x, global_position.z) if _gen else 0.0
		global_position.y = lerpf(global_position.y, maxf(gy, WorldGen.WATER_Y) + 0.2, clampf(delta * 4.0, 0.0, 1.0))
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	# evita a água (Ecos não nadam, exceto os de Maré)
	if global_position.y < WorldGen.WATER_Y - 0.4 and not "mare" in types() and not model.flying:
		velocity.x = -velocity.x
		velocity.z = -velocity.z
		velocity.y = 4.0
	move_and_slide()
	model.move_speed = clampf(Vector2(velocity.x, velocity.z).length() / 5.0, 0.0, 1.0)
	# destrava
	if hv.length() > 0.5 and global_position.distance_to(_last_pos) < 0.02:
		_stuck_t += delta
		if _stuck_t > 0.8:
			_stuck_t = 0.0
			velocity.y = 5.0
			_wander_to = global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			if state == "wander":
				pass
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	if global_position.y < -20.0:
		global_position = home + Vector3(0, 2, 0)


func _reach() -> float:
	var r := radius + 1.0
	if target is MonsterActor:
		r += (target as MonsterActor).radius
	else:
		r += 0.4
	return r


func _face(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		var yaw := atan2(-d.x, -d.z)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, 0.35)


func _decide() -> void:
	match role:
		"ally":
			_decide_ally()
		"trainer":
			_decide_trainer()
		_:
			_decide_wild()


func _decide_wild() -> void:
	var pl: Node3D = world.player
	if pl == null:
		return
	var leash_r := leash if role != "boss" else float(world.lair_radius()) + 4.0
	if global_position.distance_to(home) > leash_r and state != "return":
		state = "return"
		target = null
		return
	if state == "return":
		return
	if target != null and (not is_instance_valid(target) or (target is MonsterActor and (target as MonsterActor).dead) or (target is Player and (target as Player).is_dead())):
		target = null
		state = "idle"
	if target is Player:
		var al2: Node3D = world.ally_actor()
		if al2 != null and al2.global_position.distance_to(global_position) < 16.0:
			target = al2
	if Game.is_peaceful():
		if state == "chase":
			state = "idle"
		target = null
	elif target == null:
		var night: bool = Game.state.is_night()
		var aggro := float(GameData.db().cfg("world", "aggro_range", 11)) * (1.5 if night else 1.0)
		if role == "boss":
			aggro = world.lair_radius() + 2.0
		var aggr: bool = aggressive or (night and m["sp"] == "sombrino")
		if aggr:
			var ally: Node3D = world.ally_actor()
			var dp := global_position.distance_to(pl.global_position)
			var da: float = global_position.distance_to(ally.global_position) if ally != null else 999.0
			if role == "boss" and pl.global_position.distance_to(home) > world.lair_radius():
				dp = 999.0
				da = 999.0
			if minf(dp, da) < aggro and not (pl as Player).is_dead():
				# os Ecos sempre miram primeiro o parceiro do treinador; o treinador só depois
				target = ally if ally != null and da < aggro * 1.8 else pl
				state = "chase"
				return
	if state == "idle" and randf() < 0.25:
		var a := randf() * TAU
		var r := randf_range(3.0, 9.0)
		_wander_to = home + Vector3(cos(a) * r, 0, sin(a) * r)
		state = "wander"
	elif state == "flee" and target != null and global_position.distance_to(target.global_position) > 16.0:
		state = "idle"
		target = null


func _decide_ally() -> void:
	var pl: Node3D = world.player
	var focus: Node3D = world.focus_target()
	if focus != null and is_instance_valid(focus) and not (focus as MonsterActor).dead and focus.global_position.distance_to(pl.global_position) < 22.0:
		target = focus
		state = "chase"
	else:
		target = null
		state = "follow"
	# habilidades automáticas
	if state == "chase" and world.auto_skills():
		var s := CombatLogic.best_skill_vs(m["skills"], (target as MonsterActor).types() if target is MonsterActor else [], func(x): return skill_ready(x))
		if s != "" and global_position.distance_to(target.global_position) <= float(GameData.db().skills[s]["range"]) + _reach():
			cast(s)
		elif hp_frac() < 0.4:
			for sk in m["skills"]:
				if GameData.db().skills[sk]["kind"] == "heal" and skill_ready(sk):
					cast(sk)


func _decide_trainer() -> void:
	var ally: Node3D = world.ally_actor()
	if ally != null and not (ally as MonsterActor).dead:
		target = ally
		state = "chase"
	else:
		target = null
		state = "idle"
	if target != null and randf() < 0.35:
		var s := CombatLogic.best_skill_vs(m["skills"], (target as MonsterActor).types(), func(x): return skill_ready(x))
		if s != "" and global_position.distance_to(target.global_position) <= float(GameData.db().skills[s]["range"]) + _reach():
			cast(s)


func _try_attack() -> void:
	if _basic_cd > 0.0 or target == null:
		return
	var cfgc: Dictionary = GameData.db().config["combat"]
	_basic_cd = float(cfgc["basic_cd"]) * clampf(80.0 / maxf(30.0, stat("spd") + 30.0), 0.6, 1.6)
	if role == "boss" and enraged:
		_basic_cd *= 0.75
	# Ecos selvagens usam habilidades de vez em quando
	var cc: Dictionary = GameData.db().config["combat"]
	if role in ["wild", "boss", "trainer"] and randf() < float(cc.get("boss_skill_chance", 0.45) if role == "boss" else cc.get("wild_skill_chance", 0.3)):
		var s := CombatLogic.best_skill_vs(m["skills"], (target as MonsterActor).types() if target is MonsterActor else [], func(x): return skill_ready(x))
		if s != "":
			cast(s)
			return
	model.play_attack()
	Audio.play("hit_soft", 0.2)
	var t1: String = types()[0]
	world.resolve_hit(self, target, float(cfgc["basic_power"]), t1)


func skill_ready(s: String) -> bool:
	return float(skill_cd.get(s, 0.0)) <= 0.0


func cast(s: String) -> bool:
	if dead or not skill_ready(s):
		return false
	var sk: Dictionary = GameData.db().skills[s]
	skill_cd[s] = float(sk["cd"])
	model.play_attack()
	world.cast_skill(self, s, target)
	return true


func begin_capture(keep_visible: bool = false) -> void:
	capturing = true
	model.visible = keep_visible
	_bar_root.visible = false
	velocity = Vector3.ZERO


func end_capture(success: bool) -> void:
	if success:
		queue_free()
		return
	capturing = false
	model.visible = true
	_bar_root.visible = true
	state = "chase"
	target = world.player
	FX.burst(world, center(), Color.WHITE, 10, 3.0, false, true)
