class_name HumanoidModel
extends Node3D
## Personagem humanoide estilizado (jogador, capitães, ditadores, moradores). Animação procedural.

var skin := Color("#e8b890")
var outfit := Color("#3a7ac8")
var outfit2 := Color("#f0e0c0")
var hair := Color("#3a2a20")
var hat := ""  # "" | crown | cap | hood | helmet
var cape := false
var backpack := true

var pivot: Node3D
var torso: Node3D
var head_n: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var held: Node3D  # ferramenta/arma na mão
var move_speed := 0.0
var _t := 0.0
var _swing := 0.0
var _swing_kind := "attack"
var _gliding := false
var _wave := 0.0
var eyes: Array = []
var turn_lean := 0.0
var _squash := 0.0  # >0 amassado (aterrissagem), <0 esticado (pulo)
var scarf_tail: Node3D
var _blink := 2.0


func configure(p: Dictionary) -> HumanoidModel:
	for k in p:
		set(k, p[k])
	return self


func build() -> HumanoidModel:
	## Personagem chibi (cabeça grande), olhos anime, cabelo em camadas, jaqueta, cachecol, botas e mochila.
	pivot = Node3D.new()
	add_child(pivot)
	var sh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.2, 1.2)
	sh.mesh = pm
	sh.material_override = MonsterModel.blob_shadow_mat()
	sh.position.y = 0.03
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)
	torso = Node3D.new()
	torso.position = Vector3(0, 0.86, 0)
	pivot.add_child(torso)
	var jacket := outfit
	var trim := outfit2
	_p(torso, MonsterModel._cap(0.25, 0.62), jacket, Vector3(0, 0.1, 0), Vector3(1.08, 1, 0.82))
	_p(torso, MonsterModel._box(Vector3(0.16, 0.22, 0.04)), Color("#f4ecdc"), Vector3(0, 0.27, -0.2), Vector3.ONE, Vector3(-0.15, 0, 0), false)  # gola da camiseta
	for side in [-1, 1]:
		_p(torso, MonsterModel._box(Vector3(0.1, 0.3, 0.04)), jacket.lightened(0.15), Vector3(side * 0.11, 0.22, -0.21), Vector3.ONE, Vector3(-0.1, 0, side * 0.35), false)  # lapelas
	_p(torso, MonsterModel._box(Vector3(0.06, 0.5, 0.05)), jacket.darkened(0.25), Vector3(0.1, 0.1, -0.2), Vector3.ONE, Vector3(0, 0, 0.05), false)  # zíper
	_p(torso, MonsterModel._cyl(0.27, 0.28, 0.09), Color("#4a3426"), Vector3(0, -0.1, 0), Vector3(1.05, 1, 0.85), Vector3.ZERO, false)  # cinto
	_p(torso, MonsterModel._box(Vector3(0.1, 0.08, 0.04)), Color("#ffd04a"), Vector3(0, -0.1, -0.24), Vector3.ONE, Vector3.ZERO, false, 0.4)
	# cachecol com ponta esvoaçante
	_p(torso, MonsterModel.ring_mesh(0.17, 0.25), trim, Vector3(0, 0.4, 0), Vector3(1, 0.8, 0.95))
	scarf_tail = Node3D.new()
	scarf_tail.position = Vector3(0.12, 0.34, 0.22)
	torso.add_child(scarf_tail)
	_p(scarf_tail, MonsterModel._box(Vector3(0.12, 0.34, 0.04)), trim, Vector3(0, -0.15, 0.02), Vector3.ONE, Vector3(0.3, 0, 0))
	_p(scarf_tail, MonsterModel._box(Vector3(0.13, 0.05, 0.05)), trim.darkened(0.2), Vector3(0, -0.3, 0.07), Vector3.ONE, Vector3(0.3, 0, 0), false)
	if backpack:
		_p(torso, MonsterModel._box(Vector3(0.38, 0.44, 0.22)), Color("#8a5a3a"), Vector3(0, 0.14, 0.27))
		_p(torso, MonsterModel._box(Vector3(0.3, 0.12, 0.05)), Color("#6a4028"), Vector3(0, 0.18, 0.39), Vector3.ONE, Vector3.ZERO, false)
		_p(torso, MonsterModel._cyl(0.09, 0.09, 0.44), Color("#c84a4a"), Vector3(0, 0.42, 0.28), Vector3.ONE, Vector3(0, 0, PI / 2))  # saco de dormir
		for x in [-0.12, 0.12]:
			_p(torso, MonsterModel._box(Vector3(0.05, 0.42, 0.04)), Color("#5a3a26"), Vector3(x, 0.14, -0.22), Vector3.ONE, Vector3.ZERO, false)
	if cape:
		_p(torso, MonsterModel._box(Vector3(0.56, 0.95, 0.04)), trim.darkened(0.35), Vector3(0, -0.08, 0.26), Vector3.ONE, Vector3(0.12, 0, 0))
	head_n = Node3D.new()
	head_n.position = Vector3(0, 0.62, 0)
	torso.add_child(head_n)
	var hr := 0.31
	_p(head_n, MonsterModel._sph(hr), skin, Vector3(0, 0.14, 0), Vector3(1, 0.98, 0.96))
	for side in [-1, 1]:
		_p(head_n, MonsterModel._sph(0.06, 8), skin.darkened(0.06), Vector3(side * hr * 0.98, 0.12, 0.02), Vector3(0.6, 1, 0.8))
	_build_face(hr)
	_build_hair(hr)
	match hat:
		"crown":
			_p(head_n, MonsterModel._cyl(0.24, 0.26, 0.16), Color("#ffd04a"), Vector3(0, 0.48, 0.02), Vector3.ONE, Vector3.ZERO, true, 0.3)
			for i in 6:
				var a := TAU * i / 6.0
				_p(head_n, MonsterModel._cone(0.05, 0.14, 4), Color("#ffd04a"), Vector3(cos(a) * 0.22, 0.62, sin(a) * 0.22 + 0.02), Vector3.ONE, Vector3.ZERO, true, 0.3)
				_p(head_n, MonsterModel._sph(0.03, 6), Color("#ff3a5a"), Vector3(cos(a) * 0.25, 0.48, sin(a) * 0.25 + 0.02), Vector3.ONE, Vector3.ZERO, false, 1.5)
		"cap":
			_p(head_n, MonsterModel._sph(0.335), outfit, Vector3(0, 0.26, 0.01), Vector3(1, 0.62, 1))
			_p(head_n, MonsterModel._box(Vector3(0.34, 0.035, 0.2)), outfit.darkened(0.25), Vector3(0, 0.27, -0.3), Vector3.ONE, Vector3(-0.15, 0, 0))
		"hood":
			_p(head_n, MonsterModel._sph(0.38), outfit.darkened(0.2), Vector3(0, 0.16, 0.07), Vector3(1, 1.05, 1))
		"helmet":
			_p(head_n, MonsterModel._sph(0.345), Color("#8a8a96"), Vector3(0, 0.22, 0.01), Vector3(1, 0.8, 1))
			_p(head_n, MonsterModel._box(Vector3(0.05, 0.22, 0.32)), Color("#ff3a2a"), Vector3(0, 0.5, 0.02), Vector3.ONE, Vector3.ZERO, false, 0.8)
	arm_l = _limb(torso, Vector3(-0.3, 0.3, 0), jacket, skin, 0.075, 0.46)
	arm_r = _limb(torso, Vector3(0.3, 0.3, 0), jacket, skin, 0.075, 0.46)
	leg_l = _limb(pivot, Vector3(-0.12, 0.72, 0), Color("#3a4058"), Color("#5a3a26"), 0.095, 0.66, true)
	leg_r = _limb(pivot, Vector3(0.12, 0.72, 0), Color("#3a4058"), Color("#5a3a26"), 0.095, 0.66, true)
	held = Node3D.new()
	held.position = Vector3(0, -0.44, -0.08)
	arm_r.add_child(held)
	return self


func _build_face(hr: float) -> void:
	var eye_c := hair.lightened(0.25) if hair.v < 0.5 else Color("#4a6ac8")
	if hair.v < 0.25:
		eye_c = Color("#5a3a2a")
	for side in [-1, 1]:
		var e := Node3D.new()
		e.position = Vector3(side * 0.115, 0.1, -hr * 0.9)
		head_n.add_child(e)
		eyes.append(e)
		_p(e, MonsterModel._sph(0.075, 10), Color("#1a1420"), Vector3.ZERO, Vector3(0.95, 1.25, 0.35), Vector3.ZERO, false)
		_p(e, MonsterModel._sph(0.066, 10), Color.WHITE, Vector3(0, 0, -0.008), Vector3(0.95, 1.2, 0.35), Vector3.ZERO, false)
		_p(e, MonsterModel._sph(0.05, 10), eye_c, Vector3(side * -0.006, -0.008, -0.022), Vector3(0.95, 1.25, 0.3), Vector3.ZERO, false)
		_p(e, MonsterModel._sph(0.026, 8), Color("#120c18"), Vector3(side * -0.006, -0.004, -0.03), Vector3(1, 1.3, 0.3), Vector3.ZERO, false)
		var hl := MeshInstance3D.new()
		hl.mesh = MonsterModel._sph(0.018, 6)
		hl.material_override = MonsterModel.unlit(Color.WHITE)
		hl.position = Vector3(0.016, 0.026, -0.036)
		e.add_child(hl)
		# sobrancelha
		_p(head_n, MonsterModel._cap(0.012, 0.11), hair.darkened(0.2), Vector3(side * 0.115, 0.215, -hr * 0.88), Vector3.ONE, Vector3(0, 0, PI / 2 + side * 0.12), false)
		# bochecha
		var ch := MeshInstance3D.new()
		ch.mesh = MonsterModel._sph(0.04, 8)
		ch.material_override = MeshLib.color_mat(Color(1.0, 0.5, 0.55, 0.4), 0.0, true)
		ch.position = Vector3(side * 0.17, 0.0, -hr * 0.84)
		ch.scale = Vector3(1.3, 0.6, 0.4)
		head_n.add_child(ch)
	_p(head_n, MonsterModel._sph(0.022, 6), skin.darkened(0.12), Vector3(0, 0.03, -hr * 0.97), Vector3(1, 0.8, 0.8), Vector3.ZERO, false)
	_p(head_n, MonsterModel._cap(0.012, 0.07), Color("#6a2a2a"), Vector3(0, -0.04, -hr * 0.93), Vector3.ONE, Vector3(0, 0, PI / 2), false)


func _build_hair(hr: float) -> void:
	var hc := hair
	# calota
	_p(head_n, MonsterModel._sph(hr * 1.06), hc, Vector3(0, 0.2, 0.03), Vector3(1.02, 0.86, 1.02))
	# franja: mechas inclinadas sobre a testa
	for i in 5:
		var x := -0.2 + i * 0.1
		_p(head_n, MonsterModel._cone(0.075, 0.2, 6), hc.lightened(0.05 * (i % 2)), Vector3(x, 0.27, -hr * 0.82), Vector3(1, 1, 0.6), Vector3(PI + 0.25, 0, x * 1.4))
	# mechas laterais e de trás
	for side in [-1, 1]:
		_p(head_n, MonsterModel._cone(0.08, 0.24, 6), hc, Vector3(side * hr * 0.9, 0.04, -0.04), Vector3(0.8, 1, 0.8), Vector3(PI, 0, side * -0.15))
	for i in 3:
		var a := -0.5 + i * 0.5
		_p(head_n, MonsterModel._cone(0.1, 0.26, 6), hc.darkened(0.05), Vector3(sin(a) * 0.15, 0.12, hr * 0.85), Vector3(1, 1, 0.8), Vector3(PI - 0.5, a, 0))
	if hat != "":
		return
	# topete (mecha rebelde)
	_p(head_n, MonsterModel._cone(0.05, 0.18, 5), hc.lightened(0.08), Vector3(0.05, 0.48, -0.05), Vector3.ONE, Vector3(-0.5, 0, -0.4))


func _limb(parent: Node3D, at: Vector3, c: Color, end_c: Color, r: float, length: float, boot: bool = false) -> Node3D:
	var j := Node3D.new()
	j.position = at
	parent.add_child(j)
	_p(j, MonsterModel._cap(r, length), c, Vector3(0, -length * 0.45, 0))
	if boot:
		_p(j, MonsterModel._cap(r * 1.15, length * 0.42), end_c, Vector3(0, -length * 0.78, 0))
		_p(j, MonsterModel._sph(r * 1.25), end_c.darkened(0.1), Vector3(0, -length * 0.98, -0.05), Vector3(1, 0.65, 1.4))
		_p(j, MonsterModel._cyl(r * 1.25, r * 1.25, 0.03), Color("#e8dcc0"), Vector3(0, -length * 0.58, 0), Vector3.ONE, Vector3.ZERO, false)
	else:
		_p(j, MonsterModel._cyl(r * 1.15, r * 1.1, 0.06), c.darkened(0.25), Vector3(0, -length * 0.78, 0), Vector3.ONE, Vector3.ZERO, false)
		_p(j, MonsterModel._sph(r * 1.05), end_c, Vector3(0, -length * 0.9, -0.01), Vector3(1, 0.95, 1.05))
	return j


func _p(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, outline: bool = true, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MonsterModel.toon_mat(c, outline, emissive, 0.016)
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func set_held(item_id: String) -> void:
	for c in held.get_children():
		c.queue_free()
	if item_id == "":
		return
	var it: Dictionary = GameData.db().item(item_id)
	var c := Color(it.get("color", "#cccccc"))
	var wood := Color("#8a5a3a")
	var icon: String = it.get("icon", "")
	_p(held, MonsterModel._cyl(0.025, 0.025, 0.6), wood, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(PI / 2 - 0.3, 0, 0), false)
	match icon:
		"axe":
			_p(held, MonsterModel._box(Vector3(0.04, 0.16, 0.2)), c, Vector3(0, 0.1, -0.35), Vector3.ONE, Vector3(-0.3, 0, 0))
		"pick":
			_p(held, MonsterModel._box(Vector3(0.04, 0.05, 0.42)), c, Vector3(0, 0.12, -0.36), Vector3.ONE, Vector3(-0.3 + PI / 2, 0, 0))
		"sword":
			_p(held, MonsterModel._box(Vector3(0.05, 0.08, 0.7)), c, Vector3(0, 0.12, -0.55), Vector3.ONE, Vector3(-0.3, 0, 0), true, 0.3)
		"spear":
			_p(held, MonsterModel._cone(0.05, 0.22, 4), c, Vector3(0, 0.12, -0.45), Vector3.ONE, Vector3(-PI / 2 - 0.3, 0, 0))
		"torch":
			_p(held, MonsterModel._sph(0.08, 6), Color("#ffb02a"), Vector3(0, 0.12, -0.38), Vector3.ONE, Vector3.ZERO, false, 3.0)


func play_swing(kind: String = "attack") -> void:
	_swing = 0.4
	_swing_kind = kind


func wave() -> void:
	_wave = 1.6


func land(k: float) -> void:
	_squash = 0.35 * k


func jump_stretch() -> void:
	_squash = -0.18


func set_gliding(v: bool) -> void:
	_gliding = v


func _process(delta: float) -> void:
	if pivot == null:
		return
	_t += delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.5, 5.5)
	for e in eyes:
		e.scale.y = 0.12 if _blink < 0.12 else 1.0
	var spd := move_speed
	if scarf_tail != null:
		scarf_tail.rotation.x = 0.35 + spd * 0.9 + sin(_t * 9.0) * 0.12 * (0.3 + spd)
		scarf_tail.rotation.z = sin(_t * 5.0) * 0.15
	# andar x correr: passada, balanço dos braços, quique e inclinação aumentam com a velocidade
	var run := clampf((spd - 0.6) / 0.6, 0.0, 1.0)
	var ph := _t * (6.5 + spd * 6.0)
	var amp := 0.6 + run * 0.45
	var sw := sin(ph) * amp * minf(spd, 1.0)
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	arm_l.rotation.x = -sw * (0.8 + run * 0.5)
	arm_r.rotation.x = sw * (0.8 + run * 0.5)
	arm_l.rotation.z = -0.08 - run * 0.15
	arm_r.rotation.z = 0.08 + run * 0.15
	pivot.position.y = absf(sin(ph)) * (0.05 + run * 0.08) * minf(spd, 1.0) + sin(_t * 2.0) * 0.008
	torso.rotation.x = 0.08 * minf(spd, 1.0) + run * 0.22
	pivot.rotation.z = -turn_lean
	# amassa/estica (pulo e aterrissagem)
	_squash = move_toward(_squash, 0.0, delta * 1.6)
	pivot.scale = Vector3(1.0 + _squash * 0.6, 1.0 - _squash, 1.0 + _squash * 0.6)
	head_n.rotation.y = sin(_t * 0.7) * 0.15 * (1.0 - spd)
	if _gliding:
		arm_l.rotation.z = -1.4
		arm_r.rotation.z = 1.4
		leg_l.rotation.x = 0.3
		leg_r.rotation.x = 0.2
		torso.rotation.x = 0.4
	if _swing > 0.0:
		_swing -= delta
		var k := 1.0 - _swing / 0.4
		var a := sin(k * PI)
		if _swing_kind == "throw":
			arm_r.rotation.x = -2.6 + k * 3.2
		else:
			arm_r.rotation.x = -2.2 * a + 0.4 * k
			torso.rotation.y = -0.4 * a
	else:
		torso.rotation.y = move_toward(torso.rotation.y, 0.0, delta * 4.0)
	if _wave > 0.0:
		_wave -= delta
		arm_r.rotation.z = 2.6 + sin(_wave * 12.0) * 0.3
		arm_r.rotation.x = 0.0
