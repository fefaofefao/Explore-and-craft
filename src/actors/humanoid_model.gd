class_name HumanoidModel
extends Node3D
## Personagem humanoide estilizado (jogador, capitães, ditadores, moradores). Proporções de aventureiro
## (cabeça menor, pernas longas), membros articulados (joelho/cotovelo), túnica com saia, braçadeiras,
## botas altas, cachecol e rabo de cavalo que balançam. Animação procedural: andar/correr com joelhos,
## contrapeso de quadril e tronco, respiração, combo de 3 golpes, coleta, arremesso e planador.

var skin := Color("#e2a678")
var outfit := Color("#3a7ac8")
var outfit2 := Color("#f0e0c0")
var hair := Color("#3a2a20")
var hat := ""  # "" | crown | cap | hood | helmet
var cape := false
var backpack := true
var leather := Color("#6a4630")
var pants := Color("#5a4a3a")

var pivot: Node3D
var hips: Node3D
var torso: Node3D
var chest: MeshInstance3D
var head_n: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var held: Node3D  # ferramenta/arma na mão
var ponytail: Node3D
var pony2: Node3D
var scarf_tail: Node3D
var scarf2: Node3D
var skirt: Node3D
var move_speed := 0.0
var _t := 0.0
var _swing := 0.0
var _swing_dur := 0.36
var _swing_kind := "attack"
var _combo := 0
var _gliding := false
var _wave := 0.0
var eyes: Array = []
var turn_lean := 0.0
var _squash := 0.0  # >0 amassado (aterrissagem), <0 esticado (pulo)
var _blink := 2.0
var _phase := 0.0

const HR := 0.21  # raio da cabeça


func configure(p: Dictionary) -> HumanoidModel:
	for k in p:
		set(k, p[k])
	return self


func build() -> HumanoidModel:
	pivot = Node3D.new()
	add_child(pivot)
	var sh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.1, 1.1)
	sh.mesh = pm
	sh.material_override = MonsterModel.blob_shadow_mat()
	sh.position.y = 0.03
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)
	hips = Node3D.new()
	hips.position = Vector3(0, 0.92, 0)
	pivot.add_child(hips)
	# pernas (coxa -> joelho -> canela/bota)
	var lr := _leg(Vector3(-0.1, -0.02, 0))
	leg_l = lr[0]
	shin_l = lr[1]
	lr = _leg(Vector3(0.1, -0.02, 0))
	leg_r = lr[0]
	shin_r = lr[1]
	# saia da túnica (presa ao quadril)
	skirt = Node3D.new()
	hips.add_child(skirt)
	_p(skirt, MonsterModel._cyl(0.2, 0.27, 0.34), outfit, Vector3(0, -0.12, 0), Vector3(1, 1, 0.82))
	_p(skirt, MonsterModel._cyl(0.272, 0.275, 0.045), outfit2, Vector3(0, -0.28, 0), Vector3(1, 1, 0.83), Vector3.ZERO, false)
	# tronco
	torso = Node3D.new()
	torso.position = Vector3(0, 0.04, 0)
	hips.add_child(torso)
	chest = _p(torso, MonsterModel._cap(0.2, 0.56), outfit, Vector3(0, 0.27, 0), Vector3(1.12, 1, 0.78))
	# gola em V e camisa por baixo
	_p(torso, MonsterModel._box(Vector3(0.12, 0.16, 0.03)), outfit2.lightened(0.2), Vector3(0, 0.44, -0.15), Vector3.ONE, Vector3(-0.2, 0, PI / 4), false)
	_p(torso, MonsterModel._box(Vector3(0.05, 0.36, 0.03)), outfit.darkened(0.22), Vector3(0, 0.26, -0.158), Vector3.ONE, Vector3.ZERO, false)  # costura central
	# cinto com fivela e bolsinha
	_p(torso, MonsterModel._cyl(0.212, 0.218, 0.07), leather, Vector3(0, 0.05, 0), Vector3(1.05, 1, 0.82), Vector3.ZERO, false)
	_p(torso, MonsterModel._box(Vector3(0.08, 0.07, 0.03)), Color("#d8b048"), Vector3(0, 0.05, -0.18), Vector3.ONE, Vector3.ZERO, false, 0.3)
	_p(torso, MonsterModel._box(Vector3(0.1, 0.11, 0.07)), leather.lightened(0.1), Vector3(0.2, 0.0, -0.06), Vector3.ONE, Vector3(0, 0.5, 0))
	# alça diagonal (bandoleira)
	_p(torso, MonsterModel._box(Vector3(0.05, 0.62, 0.03)), leather.darkened(0.1), Vector3(0.0, 0.3, -0.16), Vector3.ONE, Vector3(0, 0, 0.62), false)
	# ombreira de couro (esquerda)
	_p(torso, MonsterModel._sph(0.11, 10), leather, Vector3(-0.24, 0.47, 0), Vector3(1.1, 0.7, 1.0))
	_p(torso, MonsterModel._cyl(0.115, 0.12, 0.025), leather.lightened(0.25), Vector3(-0.24, 0.44, 0), Vector3(1.1, 1, 1.0), Vector3(0, 0, 0.3), false)
	# cachecol com duas pontas esvoaçantes
	_p(torso, MonsterModel.ring_mesh(0.1, 0.17), outfit2, Vector3(0, 0.53, 0), Vector3(1, 0.85, 0.95))
	scarf_tail = Node3D.new()
	scarf_tail.position = Vector3(0.08, 0.52, 0.14)
	torso.add_child(scarf_tail)
	_p(scarf_tail, MonsterModel._box(Vector3(0.11, 0.24, 0.03)), outfit2, Vector3(0, -0.11, 0.01))
	scarf2 = Node3D.new()
	scarf2.position = Vector3(0, -0.22, 0.01)
	scarf_tail.add_child(scarf2)
	_p(scarf2, MonsterModel._box(Vector3(0.1, 0.22, 0.03)), outfit2.darkened(0.08), Vector3(0, -0.1, 0))
	_p(scarf2, MonsterModel._box(Vector3(0.11, 0.035, 0.035)), outfit2.darkened(0.3), Vector3(0, -0.21, 0), Vector3.ONE, Vector3.ZERO, false)
	if backpack:
		_p(torso, MonsterModel._box(Vector3(0.32, 0.36, 0.16)), Color("#8a5a3a"), Vector3(0, 0.28, 0.2))
		_p(torso, MonsterModel._box(Vector3(0.26, 0.1, 0.04)), Color("#6a4028"), Vector3(0, 0.3, 0.29), Vector3.ONE, Vector3.ZERO, false)
		_p(torso, MonsterModel._cyl(0.075, 0.075, 0.38), Color("#4a7a5a"), Vector3(0, 0.5, 0.2), Vector3.ONE, Vector3(0, 0, PI / 2))  # saco de dormir
		for x in [-0.11, 0.11]:
			_p(torso, MonsterModel._box(Vector3(0.045, 0.38, 0.03)), leather.darkened(0.15), Vector3(x, 0.3, -0.155), Vector3.ONE, Vector3.ZERO, false)
	if cape:
		_p(torso, MonsterModel._box(Vector3(0.5, 0.95, 0.035)), outfit2.darkened(0.35), Vector3(0, 0.0, 0.2), Vector3.ONE, Vector3(0.1, 0, 0))
	# pescoço e cabeça
	_p(torso, MonsterModel._cyl(0.06, 0.07, 0.1), skin, Vector3(0, 0.58, 0), Vector3.ONE, Vector3.ZERO, false)
	head_n = Node3D.new()
	head_n.position = Vector3(0, 0.62, 0)
	torso.add_child(head_n)
	_p(head_n, MonsterModel._sph(HR), skin, Vector3(0, 0.13, 0), Vector3(0.94, 1.04, 0.97))
	# queixo levemente afinado
	_p(head_n, MonsterModel._sph(HR * 0.62), skin, Vector3(0, 0.0, -0.05), Vector3(1.0, 0.8, 1.0), Vector3.ZERO, false)
	for side in [-1, 1]:
		_p(head_n, MonsterModel._sph(0.045, 8), skin.darkened(0.06), Vector3(side * HR * 0.93, 0.11, 0.02), Vector3(0.5, 1, 0.8), Vector3(0, 0, side * -0.2), false)
	_build_face()
	_build_hair()
	match hat:
		"crown":
			_p(head_n, MonsterModel._cyl(0.17, 0.185, 0.11), Color("#ffd04a"), Vector3(0, 0.33, 0.02), Vector3.ONE, Vector3.ZERO, true, 0.3)
			for i in 6:
				var a := TAU * i / 6.0
				_p(head_n, MonsterModel._cone(0.035, 0.1, 4), Color("#ffd04a"), Vector3(cos(a) * 0.155, 0.43, sin(a) * 0.155 + 0.02), Vector3.ONE, Vector3.ZERO, true, 0.3)
				_p(head_n, MonsterModel._sph(0.022, 6), Color("#ff3a5a"), Vector3(cos(a) * 0.178, 0.33, sin(a) * 0.178 + 0.02), Vector3.ONE, Vector3.ZERO, false, 1.5)
		"cap":
			_p(head_n, MonsterModel._sph(0.23), outfit, Vector3(0, 0.2, 0.01), Vector3(1, 0.62, 1))
			_p(head_n, MonsterModel._box(Vector3(0.24, 0.025, 0.14)), outfit.darkened(0.25), Vector3(0, 0.2, -0.21), Vector3.ONE, Vector3(-0.15, 0, 0))
		"hood":
			_p(head_n, MonsterModel._sph(0.26), outfit.darkened(0.2), Vector3(0, 0.15, 0.05), Vector3(1, 1.05, 1))
		"helmet":
			_p(head_n, MonsterModel._sph(0.235), Color("#8a8a96"), Vector3(0, 0.17, 0.01), Vector3(1, 0.82, 1))
			_p(head_n, MonsterModel._box(Vector3(0.035, 0.15, 0.22)), Color("#ff3a2a"), Vector3(0, 0.38, 0.02), Vector3.ONE, Vector3.ZERO, false, 0.8)
	# braços (ombro -> cotovelo -> antebraço/luva)
	var ar := _arm(Vector3(-0.25, 0.44, 0))
	arm_l = ar[0]
	fore_l = ar[1]
	ar = _arm(Vector3(0.25, 0.44, 0))
	arm_r = ar[0]
	fore_r = ar[1]
	held = Node3D.new()
	held.position = Vector3(0, -0.3, -0.04)
	fore_r.add_child(held)
	return self


func _leg(at: Vector3) -> Array:
	var thigh := Node3D.new()
	thigh.position = at
	hips.add_child(thigh)
	_p(thigh, MonsterModel._cap(0.078, 0.46), pants, Vector3(0, -0.2, 0))
	var shin := Node3D.new()
	shin.position = Vector3(0, -0.43, 0)
	thigh.add_child(shin)
	_p(shin, MonsterModel._cap(0.066, 0.3), pants.darkened(0.05), Vector3(0, -0.1, 0))
	# bota alta com dobra
	var boot := leather.darkened(0.05)
	_p(shin, MonsterModel._cap(0.08, 0.3), boot, Vector3(0, -0.27, 0))
	_p(shin, MonsterModel._cyl(0.088, 0.092, 0.06), boot.lightened(0.18), Vector3(0, -0.13, 0), Vector3.ONE, Vector3.ZERO, false)
	_p(shin, MonsterModel._sph(0.085), boot.darkened(0.12), Vector3(0, -0.44, -0.06), Vector3(1, 0.6, 1.55))
	_p(shin, MonsterModel._box(Vector3(0.15, 0.03, 0.26)), Color("#3a2a20"), Vector3(0, -0.485, -0.05), Vector3.ONE, Vector3.ZERO, false)  # sola
	return [thigh, shin]


func _arm(at: Vector3) -> Array:
	var sh := Node3D.new()
	sh.position = at
	torso.add_child(sh)
	_p(sh, MonsterModel._cap(0.062, 0.32), outfit, Vector3(0, -0.13, 0))
	var fore := Node3D.new()
	fore.position = Vector3(0, -0.28, 0)
	sh.add_child(fore)
	_p(fore, MonsterModel._cap(0.055, 0.26), skin, Vector3(0, -0.1, 0))
	# braçadeira de couro e luva
	_p(fore, MonsterModel._cyl(0.064, 0.06, 0.15), leather, Vector3(0, -0.15, 0), Vector3.ONE, Vector3.ZERO, false)
	_p(fore, MonsterModel._sph(0.058), leather.darkened(0.1), Vector3(0, -0.28, -0.01), Vector3(0.9, 1.05, 1.05))
	return [sh, fore]


func _build_face() -> void:
	var eye_c := hair.lightened(0.3) if hair.v < 0.5 else Color("#4a6ac8")
	if hair.v < 0.25:
		eye_c = Color("#3a6a8a")
	for side in [-1, 1]:
		var e := Node3D.new()
		e.position = Vector3(side * 0.078, 0.12, -HR * 0.9)
		head_n.add_child(e)
		eyes.append(e)
		# olho: íris grande e escura com pouco branco aparente (sem contorno, para não parecer óculos)
		_p(e, MonsterModel._sph(0.04, 10), Color("#f4f0ea"), Vector3(0, 0, 0), Vector3(1.0, 1.15, 0.3), Vector3.ZERO, false)
		_p(e, MonsterModel._sph(0.032, 10), eye_c, Vector3(side * -0.004, -0.003, -0.008), Vector3(0.95, 1.2, 0.3), Vector3.ZERO, false)
		_p(e, MonsterModel._sph(0.016, 8), Color("#120c18"), Vector3(side * -0.004, -0.002, -0.013), Vector3(1, 1.2, 0.3), Vector3.ZERO, false)
		# pálpebra superior (linha escura) dá expressão
		_p(e, MonsterModel._cap(0.008, 0.075), Color("#2a1a18"), Vector3(0, 0.036, -0.006), Vector3.ONE, Vector3(0, 0, PI / 2 + side * 0.08), false)
		var hl := MeshInstance3D.new()
		hl.mesh = MonsterModel._sph(0.012, 6)
		hl.material_override = MonsterModel.unlit(Color.WHITE)
		hl.position = Vector3(0.01, 0.014, -0.018)
		e.add_child(hl)
		# sobrancelha decidida
		_p(head_n, MonsterModel._cap(0.009, 0.085), hair.darkened(0.2), Vector3(side * 0.08, 0.2, -HR * 0.9), Vector3.ONE, Vector3(0, 0, PI / 2 + side * 0.22), false)
	# nariz e boca
	_p(head_n, MonsterModel._sph(0.018, 6), skin.darkened(0.1), Vector3(0, 0.06, -HR * 0.99), Vector3(0.8, 1.1, 0.9), Vector3.ZERO, false)
	_p(head_n, MonsterModel._cap(0.008, 0.05), Color("#7a3a32"), Vector3(0, -0.005, -HR * 0.86), Vector3.ONE, Vector3(0, 0, PI / 2), false)


func _build_hair() -> void:
	var hc := hair
	_p(head_n, MonsterModel._sph(HR * 1.06), hc, Vector3(0, 0.19, 0.03), Vector3(1.0, 0.82, 1.02))
	# franja repartida em mechas
	for i in 6:
		var x := -0.14 + i * 0.056
		_p(head_n, MonsterModel._cone(0.05, 0.12, 5), hc.lightened(0.05 * (i % 2)), Vector3(x, 0.27, -HR * 0.82), Vector3(1, 1, 0.55), Vector3(PI + 0.45, 0, x * 1.8))
	# mechas laterais longas (emolduram o rosto)
	for side in [-1, 1]:
		_p(head_n, MonsterModel._cone(0.055, 0.24, 5), hc, Vector3(side * HR * 0.86, 0.04, -0.06), Vector3(0.7, 1, 0.7), Vector3(PI - 0.05, 0, side * -0.12))
	# nuca
	for i in 3:
		var a := -0.5 + i * 0.5
		_p(head_n, MonsterModel._cone(0.07, 0.18, 5), hc.darkened(0.05), Vector3(sin(a) * 0.1, 0.08, HR * 0.84), Vector3(1, 1, 0.8), Vector3(PI - 0.4, a, 0))
	if hat in ["hood", "helmet"]:
		return
	# rabo de cavalo em dois segmentos (balança com o movimento)
	ponytail = Node3D.new()
	ponytail.position = Vector3(0, 0.2, HR * 0.95)
	head_n.add_child(ponytail)
	_p(ponytail, MonsterModel._cyl(0.035, 0.035, 0.04), Color("#c8a048"), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0), false)
	_p(ponytail, MonsterModel._cap(0.055, 0.2), hc, Vector3(0, -0.07, 0.03))
	pony2 = Node3D.new()
	pony2.position = Vector3(0, -0.16, 0.04)
	ponytail.add_child(pony2)
	_p(pony2, MonsterModel._cone(0.05, 0.2, 6), hc.darkened(0.05), Vector3(0, -0.08, 0), Vector3(1, 1, 0.8), Vector3(PI, 0, 0))


func _p(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, outline: bool = true, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MonsterModel.toon_mat(c, outline, emissive, 0.014)
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
	_p(held, MonsterModel._cyl(0.022, 0.022, 0.55), wood, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(PI / 2 - 0.3, 0, 0), false)
	match icon:
		"axe":
			_p(held, MonsterModel._box(Vector3(0.035, 0.15, 0.18)), c, Vector3(0, 0.09, -0.33), Vector3.ONE, Vector3(-0.3, 0, 0))
		"pick":
			_p(held, MonsterModel._box(Vector3(0.035, 0.045, 0.38)), c, Vector3(0, 0.11, -0.33), Vector3.ONE, Vector3(-0.3 + PI / 2, 0, 0))
		"sword":
			_p(held, MonsterModel._box(Vector3(0.12, 0.03, 0.04)), Color("#c8a048"), Vector3(0, 0.03, -0.3), Vector3.ONE, Vector3(-0.3, 0, 0), false)  # guarda
			_p(held, MonsterModel._box(Vector3(0.045, 0.07, 0.66)), c, Vector3(0, 0.13, -0.62), Vector3.ONE, Vector3(-0.3, 0, 0), true, 0.3)
		"spear":
			_p(held, MonsterModel._cone(0.045, 0.2, 4), c, Vector3(0, 0.11, -0.42), Vector3.ONE, Vector3(-PI / 2 - 0.3, 0, 0))
		"torch":
			_p(held, MonsterModel._sph(0.07, 6), Color("#ffb02a"), Vector3(0, 0.11, -0.36), Vector3.ONE, Vector3.ZERO, false, 3.0)


func play_swing(kind: String = "attack", combo: int = 0) -> void:
	_swing_kind = kind
	_combo = combo
	_swing_dur = 0.34 if kind == "attack" else 0.4
	if kind == "attack" and combo == 2:
		_swing_dur = 0.46
	_swing = _swing_dur


func wave() -> void:
	_wave = 1.6


func land(k: float) -> void:
	_squash = 0.35 * k


func jump_stretch() -> void:
	_squash = -0.18


func set_gliding(v: bool) -> void:
	_gliding = v


static func _ph(k: float, wind: float, strike: float) -> Vector3:
	## x = antecipação (0..1, segura até o golpe), y = golpe (0..1), z = recuperação (0..1)
	return Vector3(smoothstep(0.0, wind, k), clampf((k - wind) / maxf(strike - wind, 0.001), 0.0, 1.0), clampf((k - strike) / maxf(1.0 - strike, 0.001), 0.0, 1.0))


func _process(delta: float) -> void:
	if pivot == null:
		return
	_t += delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.5, 5.5)
	for e in eyes:
		e.scale.y = 0.12 if _blink < 0.12 else 1.0
	var spd := minf(move_speed, 1.4)
	var walk := minf(spd, 1.0)
	var run := clampf((spd - 0.6) / 0.6, 0.0, 1.0)
	# fase da passada avança com a velocidade (passos mais longos e rápidos ao correr)
	_phase += delta * (5.5 + spd * 6.5)
	var ph := _phase
	var amp := (0.55 + run * 0.4) * walk
	var sw := sin(ph)
	# pernas: coxa balança; joelho dobra na fase de recuperação (perna indo para frente)
	leg_l.rotation.x = sw * amp
	leg_r.rotation.x = -sw * amp
	shin_l.rotation.x = -maxf(0.0, cos(ph)) * (0.35 + run * 0.95) * walk - 0.04
	shin_r.rotation.x = -maxf(0.0, -cos(ph)) * (0.35 + run * 0.95) * walk - 0.04
	# braços opostos às pernas, cotovelos dobram mais ao correr
	arm_l.rotation.x = -sw * amp * (0.9 + run * 0.4)
	arm_r.rotation.x = sw * amp * (0.9 + run * 0.4)
	arm_l.rotation.z = -0.1 - run * 0.12
	arm_r.rotation.z = 0.1 + run * 0.12
	fore_l.rotation.x = 0.2 + run * 0.9 + maxf(0.0, -sw) * 0.3 * walk
	fore_r.rotation.x = 0.2 + run * 0.9 + maxf(0.0, sw) * 0.3 * walk
	# quadril sobe/desce 2x por ciclo, gira e balança; tronco faz contrapeso
	var breathe := sin(_t * 1.9)
	hips.position.y = 0.92 - absf(cos(ph)) * 0.02 * walk + absf(sin(ph)) * (0.035 + run * 0.06) * walk - run * 0.04
	hips.rotation.y = sw * 0.14 * walk
	hips.rotation.z = sw * 0.04 * walk
	torso.rotation.y = -sw * 0.2 * walk
	torso.rotation.x = 0.05 * walk + run * 0.26
	torso.rotation.z = 0.0
	chest.scale = Vector3(1.12, 1.0 + breathe * 0.012 * (1.0 - walk), 0.78 + breathe * 0.01 * (1.0 - walk))
	if walk < 0.1:
		# parado: peso apoiado, braços relaxados
		arm_l.rotation.z = -0.1 - breathe * 0.015
		arm_r.rotation.z = 0.1 + breathe * 0.015
		fore_l.rotation.x = 0.15
		fore_r.rotation.x = 0.15
	head_n.rotation.y = sin(_t * 0.7) * 0.15 * (1.0 - walk) + sw * 0.08 * walk
	head_n.rotation.x = -torso.rotation.x * 0.6
	pivot.position.y = 0.0
	pivot.rotation.z = -turn_lean
	skirt.rotation.x = -walk * 0.12 - run * 0.15
	skirt.rotation.z = sw * 0.06 * walk
	# cachecol e rabo de cavalo seguem o movimento com atraso
	if scarf_tail != null:
		scarf_tail.rotation.x = 0.25 + spd * 1.0 + sin(_t * 9.0) * 0.12 * (0.3 + spd)
		scarf_tail.rotation.z = sin(_t * 5.0) * 0.15
		scarf2.rotation.x = 0.2 + spd * 0.4 + sin(_t * 9.0 - 1.0) * 0.2 * (0.3 + spd)
	if ponytail != null:
		ponytail.rotation.x = 0.35 + spd * 0.5 + sin(ph * 2.0) * 0.08 * walk
		ponytail.rotation.z = sin(ph) * 0.18 * walk + sin(_t * 1.3) * 0.05
		pony2.rotation.x = 0.2 + spd * 0.3 + sin(ph * 2.0 - 0.8) * 0.12 * walk
	# amassa/estica (pulo e aterrissagem)
	_squash = move_toward(_squash, 0.0, delta * 1.6)
	pivot.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)
	if _squash > 0.05:
		# aterrissagem: dobra os joelhos
		shin_l.rotation.x -= _squash * 1.6
		shin_r.rotation.x -= _squash * 1.6
		leg_l.rotation.x += _squash * 0.8
		leg_r.rotation.x += _squash * 0.8
	if _gliding:
		arm_l.rotation = Vector3(0, 0, -2.6)
		arm_r.rotation = Vector3(0, 0, 2.6)
		fore_l.rotation.x = 0.1
		fore_r.rotation.x = 0.1
		leg_l.rotation.x = 0.25
		leg_r.rotation.x = -0.1
		shin_l.rotation.x = -0.6
		shin_r.rotation.x = -0.3
		torso.rotation.x = 0.35
	if _swing > 0.0:
		_swing -= delta
		_anim_swing(clampf(1.0 - _swing / _swing_dur, 0.0, 1.0))
	if _wave > 0.0:
		_wave -= delta
		arm_r.rotation = Vector3(0.0, 0.0, 2.6 + sin(_wave * 12.0) * 0.3)
		fore_r.rotation.x = 0.4


func _anim_swing(k: float) -> void:
	match _swing_kind:
		"throw":
			var p := _ph(k, 0.45, 0.65)
			var wind := p.x * (1.0 - p.y)
			arm_r.rotation.x = -2.3 * wind + 1.4 * p.y * (1.0 - p.z * 0.6)
			arm_r.rotation.z = 0.25
			fore_r.rotation.x = 0.9 * wind + 0.1
			torso.rotation.y = 0.5 * wind - 0.4 * p.y * (1.0 - p.z)
			torso.rotation.x = -0.15 * wind + 0.2 * p.y * (1.0 - p.z)
			arm_l.rotation.x = 1.0 * wind
		"gather":
			var p := _ph(k, 0.4, 0.58)
			var wind := p.x * (1.0 - p.y)
			var hit := p.y * (1.0 - p.z)
			arm_r.rotation.x = 2.7 * wind + 0.5 * hit + 0.3 * p.z * (1.0 - p.z)
			arm_l.rotation.x = 2.2 * wind + 0.6 * hit
			fore_r.rotation.x = 0.5 * wind + 0.1
			fore_l.rotation.x = 0.6 * wind + 0.2
			torso.rotation.x = -0.2 * wind + 0.35 * hit
			torso.rotation.y = -0.3 * hit
		_:
			match _combo:
				0:
					# corte horizontal da direita para a esquerda
					var p := _ph(k, 0.3, 0.55)
					var wind := p.x * (1.0 - p.y)
					var sweep := ease(p.y, 0.4)
					torso.rotation.y = 0.75 * wind + lerpf(0.75, -0.95, sweep) * minf(1.0, p.y * 10.0) * (1.0 - p.z * 0.8)
					arm_r.rotation.x = 1.45 * maxf(wind, p.y * (1.0 - p.z))
					arm_r.rotation.z = 0.55 * wind + 0.1
					fore_r.rotation.x = 0.4 * wind + 0.05
					arm_l.rotation.x = 0.5 * maxf(wind, p.y * (1.0 - p.z))
					hips.rotation.y = 0.3 * wind - 0.3 * p.y * (1.0 - p.z)
				1:
					# revés: volta da esquerda para a direita
					var p := _ph(k, 0.25, 0.52)
					var wind := p.x * (1.0 - p.y)
					var sweep := ease(p.y, 0.4)
					torso.rotation.y = -0.85 * wind + lerpf(-0.85, 0.85, sweep) * minf(1.0, p.y * 10.0) * (1.0 - p.z * 0.8)
					arm_r.rotation.x = 1.3 * maxf(wind, p.y * (1.0 - p.z))
					arm_r.rotation.z = -0.35 * wind - 0.1
					fore_r.rotation.x = 0.7 * wind + 0.1
					hips.rotation.y = -0.25 * wind + 0.25 * p.y * (1.0 - p.z)
				_:
					# golpe final por cima, com as duas mãos e agachando no impacto
					var p := _ph(k, 0.42, 0.58)
					var wind := p.x * (1.0 - p.y)
					var hit := p.y * (1.0 - ease(p.z, 0.5))
					arm_r.rotation.x = 3.0 * wind + 0.7 * hit
					arm_l.rotation.x = 2.8 * wind + 0.7 * hit
					arm_l.rotation.z = 0.35 * maxf(wind, hit)
					fore_r.rotation.x = 0.6 * wind + 0.05
					fore_l.rotation.x = 0.6 * wind + 0.05
					torso.rotation.x = -0.3 * wind + 0.45 * hit
					hips.position.y -= 0.1 * hit
					shin_l.rotation.x -= 0.5 * hit
					shin_r.rotation.x -= 0.5 * hit
					leg_l.rotation.x += 0.3 * hit
					leg_r.rotation.x -= 0.15 * hit
