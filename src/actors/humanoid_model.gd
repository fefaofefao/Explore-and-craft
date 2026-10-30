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


func configure(p: Dictionary) -> HumanoidModel:
	for k in p:
		set(k, p[k])
	return self


func build() -> HumanoidModel:
	pivot = Node3D.new()
	add_child(pivot)
	torso = Node3D.new()
	torso.position = Vector3(0, 1.0, 0)
	pivot.add_child(torso)
	_p(torso, MonsterModel._cap(0.24, 0.72), outfit, Vector3(0, 0.12, 0), Vector3(1.1, 1, 0.8))
	_p(torso, MonsterModel._cap(0.2, 0.3), outfit2, Vector3(0, 0.3, -0.12), Vector3(1.15, 1, 0.5), Vector3.ZERO, false)  # gola/cachecol
	_p(torso, MonsterModel._cyl(0.25, 0.26, 0.08), Color("#5a3a2a"), Vector3(0, -0.12, 0), Vector3(1.1, 1, 0.85), Vector3.ZERO, false)  # cinto
	if backpack:
		_p(torso, MonsterModel._box(Vector3(0.36, 0.42, 0.2)), Color("#8a5a3a"), Vector3(0, 0.18, 0.24))
		_p(torso, MonsterModel._cyl(0.08, 0.08, 0.4), Color("#c8a070"), Vector3(0, 0.44, 0.26), Vector3.ONE, Vector3(0, 0, PI / 2), false)
	if cape:
		_p(torso, MonsterModel._box(Vector3(0.5, 0.9, 0.04)), outfit2.darkened(0.3), Vector3(0, -0.05, 0.2), Vector3.ONE, Vector3(0.12, 0, 0))
	head_n = Node3D.new()
	head_n.position = Vector3(0, 0.62, 0)
	torso.add_child(head_n)
	_p(head_n, MonsterModel._sph(0.24), skin, Vector3(0, 0.1, 0), Vector3(1, 1.05, 1))
	# cabelo
	_p(head_n, MonsterModel._sph(0.255), hair, Vector3(0, 0.17, 0.035), Vector3(1.02, 0.85, 1.0))
	_p(head_n, MonsterModel._sph(0.12), hair, Vector3(0.12, 0.27, -0.14), Vector3(1.2, 0.6, 0.8), Vector3.ZERO, false)
	# olhos e boca
	for side in [-1, 1]:
		_p(head_n, MonsterModel._sph(0.04, 8), Color("#1a1420"), Vector3(side * 0.085, 0.1, -0.215), Vector3(1, 1.3, 0.6), Vector3.ZERO, false)
		_p(head_n, MonsterModel._sph(0.012, 6), Color.WHITE, Vector3(side * 0.085 + 0.012, 0.115, -0.24), Vector3.ONE, Vector3.ZERO, false)
	_p(head_n, MonsterModel._sph(0.03, 6), skin.darkened(0.25), Vector3(0, 0.01, -0.225), Vector3(1.4, 0.5, 0.5), Vector3.ZERO, false)
	match hat:
		"crown":
			_p(head_n, MonsterModel._cyl(0.2, 0.22, 0.14), Color("#ffd04a"), Vector3(0, 0.36, 0), Vector3.ONE, Vector3.ZERO, true)
			for i in 5:
				var a := TAU * i / 5.0
				_p(head_n, MonsterModel._cone(0.04, 0.12, 4), Color("#ffd04a"), Vector3(cos(a) * 0.18, 0.47, sin(a) * 0.18))
		"cap":
			_p(head_n, MonsterModel._sph(0.26), outfit, Vector3(0, 0.22, 0), Vector3(1, 0.6, 1))
			_p(head_n, MonsterModel._box(Vector3(0.3, 0.03, 0.18)), outfit.darkened(0.2), Vector3(0, 0.22, -0.24), Vector3.ONE, Vector3.ZERO, false)
		"hood":
			_p(head_n, MonsterModel._sph(0.3), outfit.darkened(0.25), Vector3(0, 0.14, 0.06), Vector3(1, 1.05, 1))
		"helmet":
			_p(head_n, MonsterModel._sph(0.27), Color("#8a8a96"), Vector3(0, 0.18, 0), Vector3(1, 0.85, 1))
			_p(head_n, MonsterModel._box(Vector3(0.04, 0.25, 0.04)), Color("#ff3a2a"), Vector3(0, 0.42, 0), Vector3.ONE, Vector3.ZERO, false, 1.0)
	arm_l = _limb(torso, Vector3(-0.32, 0.36, 0), outfit, skin, 0.08, 0.52)
	arm_r = _limb(torso, Vector3(0.32, 0.36, 0), outfit, skin, 0.08, 0.52)
	leg_l = _limb(pivot, Vector3(-0.12, 0.82, 0), Color("#4a4a5a"), Color("#5a3a2a"), 0.1, 0.78)
	leg_r = _limb(pivot, Vector3(0.12, 0.82, 0), Color("#4a4a5a"), Color("#5a3a2a"), 0.1, 0.78)
	held = Node3D.new()
	held.position = Vector3(0, -0.5, -0.08)
	arm_r.add_child(held)
	return self


func _limb(parent: Node3D, at: Vector3, c: Color, end_c: Color, r: float, length: float) -> Node3D:
	var j := Node3D.new()
	j.position = at
	parent.add_child(j)
	_p(j, MonsterModel._cap(r, length), c, Vector3(0, -length * 0.45, 0))
	_p(j, MonsterModel._sph(r * 1.15), end_c, Vector3(0, -length * 0.9, -0.02), Vector3(1, 0.9, 1.25))
	return j


func _p(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, outline: bool = true, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	var key := "hm_%s_%s_%.1f" % [c.to_html(), outline, emissive]
	if MeshLib._mats.has(key):
		mi.material_override = MeshLib._mats[key]
	else:
		m.albedo_color = c
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
		m.roughness = 0.6
		m.rim_enabled = true
		m.rim = 0.3
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		if outline:
			m.next_pass = MeshLib.outline_mat(0.018)
		MeshLib._mats[key] = m
		mi.material_override = m
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


func set_gliding(v: bool) -> void:
	_gliding = v


func _process(delta: float) -> void:
	if pivot == null:
		return
	_t += delta
	var spd := move_speed
	var ph := _t * (6.0 + spd * 5.0)
	var sw := sin(ph) * 0.75 * spd
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	arm_l.rotation.x = -sw * 0.8
	arm_r.rotation.x = sw * 0.8
	arm_l.rotation.z = -0.08
	arm_r.rotation.z = 0.08
	pivot.position.y = absf(sin(ph)) * 0.06 * spd + sin(_t * 2.0) * 0.008
	torso.rotation.x = 0.08 * spd
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
