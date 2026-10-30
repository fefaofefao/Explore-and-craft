class_name MonsterModel
extends Node3D
## Modelo 3D procedural de um Eco a partir do "corpo" definido em data/species.json.
## Estilo: formas arredondadas, sombreamento toon, contorno escuro e olhos expressivos.
## Animação 100% procedural (idle, andar, voar, serpentear, atacar, dano, desmaio, alegria).

var sp_id: String
var body_def: Dictionary
var s: float = 1.0  # escala do corpo
var c1: Color
var c2: Color
var variant := false
var shape: String

var root_pivot: Node3D  # tudo pendura aqui (para quicar/inclinar)
var body: Node3D
var head: Node3D
var legs: Array = []  # [Node3D, fase]
var wings: Array = []
var segments: Array = []  # serpente
var tail: Node3D
var eyes: Array = []
var _mats: Array = []

var move_speed := 0.0  # 0..1 (definido pelo ator)
var flying := false
var _t := 0.0
var _attack_t := 0.0
var _hurt_t := 0.0
var _happy_t := 0.0
var fainted := false
var _faint_k := 0.0
var _flash_mat: StandardMaterial3D


func build(species_id: String, p_variant: bool = false) -> MonsterModel:
	sp_id = species_id
	var sp: Dictionary = GameData.db().sp(species_id)
	body_def = sp["body"]
	s = float(body_def["size"])
	shape = body_def["shape"]
	variant = p_variant
	c1 = Color(body_def["color"])
	c2 = Color(body_def["color2"])
	if variant:
		c1 = Color.from_hsv(fmod(c1.h + 0.45, 1.0), clampf(c1.s * 0.85, 0.2, 1.0), clampf(c1.v * 1.1, 0.5, 1.0))
		c2 = Color.from_hsv(fmod(c2.h + 0.45, 1.0), clampf(c2.s, 0.2, 1.0), clampf(c2.v * 1.1, 0.5, 1.0))
	_t = randf() * 10.0
	root_pivot = Node3D.new()
	add_child(root_pivot)
	match shape:
		"round":
			_build_round()
		"quad":
			_build_quad()
		"bird":
			_build_bird()
		"serpent":
			_build_serpent()
		"golem":
			_build_golem()
		"biped":
			_build_biped()
		_:
			_build_round()
	_add_extras()
	if variant:
		_add_sparkles()
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return self


# ------------------------------------------------------------------ helpers
func _mat(c: Color, outline: bool = true, emissive: float = 0.0) -> Material:
	var key := "mm_%s_%s_%.1f" % [c.to_html(), outline, emissive]
	if MeshLib._mats.has(key):
		return MeshLib._mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.45
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.5
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if outline:
		m.next_pass = MeshLib.outline_mat(0.025)
	MeshLib._mats[key] = m
	return m


func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, outline: bool = true, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, outline, emissive)
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	_mats.append(mi)
	return mi


static func _sph(r: float, segs: int = 16) -> SphereMesh:
	var key := "sph_%.3f_%d" % [r, segs]
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	MeshLib._meshes[key] = m
	return m


static func _cap(r: float, h: float) -> CapsuleMesh:
	var key := "cap_%.3f_%.3f" % [r, h]
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0 + 0.01)
	m.radial_segments = 12
	m.rings = 4
	MeshLib._meshes[key] = m
	return m


static func _cone(r: float, h: float, segs: int = 10) -> CylinderMesh:
	var key := "cone_%.3f_%.3f_%d" % [r, h, segs]
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	MeshLib._meshes[key] = m
	return m


static func _cyl(r0: float, r1: float, h: float) -> CylinderMesh:
	var key := "cyl_%.3f_%.3f_%.3f" % [r0, r1, h]
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = r1
	m.bottom_radius = r0
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	MeshLib._meshes[key] = m
	return m


static func _box(v: Vector3) -> BoxMesh:
	var key := "box_%s" % str(v)
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var m := BoxMesh.new()
	m.size = v
	MeshLib._meshes[key] = m
	return m


func _add_eyes(parent: Node3D, center: Vector3, spread: float, r: float, forward: float = -1.0) -> void:
	var style: String = body_def.get("eyes", "round")
	for side in [-1, 1]:
		var e := Node3D.new()
		e.position = center + Vector3(side * spread, 0, 0)
		parent.add_child(e)
		eyes.append(e)
		match style:
			"glow":
				_part(e, _sph(r * 0.9), c2.lightened(0.4), Vector3.ZERO, Vector3(1, 1.15, 0.6), Vector3.ZERO, false, 2.5)
			"visor":
				if side == -1:
					_part(e, _box(Vector3(spread * 2.6, r * 0.9, r * 0.6)), Color("#5fd0ff"), Vector3(spread, 0, 0), Vector3.ONE, Vector3.ZERO, false, 2.5)
			_:
				_part(e, _sph(r), Color("#ffffff"), Vector3.ZERO, Vector3(1, 1.15, 0.55), Vector3.ZERO, false)
				var pr := r * (0.72 if style == "happy" else 0.58)
				_part(e, _sph(pr), Color("#1a1420"), Vector3(0, -r * 0.05, forward * r * 0.32), Vector3(1, 1.15, 0.5), Vector3.ZERO, false)
				_part(e, _sph(r * 0.22), Color("#ffffff"), Vector3(r * 0.25, r * 0.3, forward * r * 0.55), Vector3.ONE, Vector3.ZERO, false, 1.0)
				if style == "angry":
					_part(e, _box(Vector3(r * 2.2, r * 0.35, r * 0.4)), c1.darkened(0.5), Vector3(0, r * 1.05, forward * r * 0.2), Vector3.ONE, Vector3(0, 0, side * -0.45), false)
				elif style == "sleepy":
					_part(e, _sph(r * 1.05), c1, Vector3(0, r * 0.35, forward * r * 0.05), Vector3(1.05, 0.7, 0.62), Vector3.ZERO, false)


func _add_ears(parent: Node3D, top: Vector3, spread: float, k: float) -> void:
	var ears: String = body_def.get("ears", "none")
	for side in [-1, 1]:
		var p := top + Vector3(side * spread, 0, 0)
		var rz: float = side * -0.35
		match ears:
			"leaf":
				_part(parent, _sph(0.22 * k), c2.lerp(Color("#5fbf4a"), 0.6), p + Vector3(side * 0.08 * k, 0.12 * k, 0), Vector3(0.5, 1.3, 0.25), Vector3(0, 0, rz * 1.6))
			"small":
				_part(parent, _sph(0.12 * k), c1.darkened(0.1), p, Vector3(1, 1, 0.7))
			"big":
				_part(parent, _cone(0.2 * k, 0.5 * k), c1, p + Vector3(side * 0.05 * k, 0.2 * k, 0), Vector3(1, 1, 0.45), Vector3(0, 0, rz))
				_part(parent, _cone(0.12 * k, 0.32 * k), c2, p + Vector3(side * 0.05 * k, 0.17 * k, -0.04 * k), Vector3(1, 1, 0.3), Vector3(0, 0, rz), false)
			"pointy":
				_part(parent, _cone(0.13 * k, 0.36 * k), c1, p + Vector3(0, 0.16 * k, 0), Vector3(1, 1, 0.6), Vector3(0, 0, rz * 0.6))
			"bunny":
				_part(parent, _cap(0.08 * k, 0.6 * k), c1, p + Vector3(side * 0.04 * k, 0.32 * k, 0.05 * k), Vector3(1, 1, 0.6), Vector3(0.2, 0, rz * 0.4))
				_part(parent, _cap(0.045 * k, 0.4 * k), c2, p + Vector3(side * 0.04 * k, 0.32 * k, 0.0), Vector3(1, 1, 0.4), Vector3(0.2, 0, rz * 0.4), false)
			"fin":
				_part(parent, _sph(0.2 * k), c2, p + Vector3(side * 0.12 * k, 0, 0.05 * k), Vector3(0.25, 0.9, 1.1), Vector3(0, 0, rz * 1.5))
			"horn":
				_part(parent, _cone(0.08 * k, 0.32 * k), c2, p + Vector3(0, 0.12 * k, 0), Vector3.ONE, Vector3(0, 0, rz))


func _add_horns(parent: Node3D, top: Vector3, k: float) -> void:
	var horns: String = body_def.get("horns", "none")
	match horns:
		"twin":
			for side in [-1, 1]:
				_part(parent, _cone(0.08 * k, 0.4 * k), Color("#f0e0c0"), top + Vector3(side * 0.16 * k, 0.12 * k, 0.02 * k), Vector3.ONE, Vector3(-0.3, 0, side * -0.35))
		"single":
			_part(parent, _cone(0.09 * k, 0.45 * k), Color("#f0e0c0"), top + Vector3(0, 0.15 * k, -0.08 * k), Vector3.ONE, Vector3(-0.4, 0, 0))
		"tusk":
			for side in [-1, 1]:
				_part(parent, _cone(0.06 * k, 0.4 * k), Color("#fff8e8"), top + Vector3(side * 0.18 * k, -0.45 * k, -0.25 * k), Vector3.ONE, Vector3(-2.3, 0, side * 0.3))
		"antenna":
			_part(parent, _cyl(0.02 * k, 0.02 * k, 0.35 * k), Color("#3a3a40"), top + Vector3(0, 0.17 * k, 0), Vector3.ONE, Vector3.ZERO, false)
			_part(parent, _sph(0.06 * k), Color("#ff4a3a"), top + Vector3(0, 0.36 * k, 0), Vector3.ONE, Vector3.ZERO, false, 3.0)
		"crest":
			_part(parent, _cone(0.16 * k, 0.5 * k), c2, top + Vector3(0, 0.08 * k, 0.12 * k), Vector3(0.35, 1, 1), Vector3(0.7, 0, 0))


func _add_tail(parent: Node3D, at: Vector3, k: float) -> void:
	var t: String = body_def.get("tail", "none")
	if t == "none":
		return
	tail = Node3D.new()
	tail.position = at
	parent.add_child(tail)
	match t:
		"leaf":
			_part(tail, _sph(0.2 * k), Color("#5fbf4a"), Vector3(0, 0.15 * k, 0.15 * k), Vector3(0.3, 1.0, 1.4), Vector3(0.6, 0, 0))
		"flame":
			_part(tail, _cone(0.1 * k, 0.35 * k), c1, Vector3(0, 0.05 * k, 0.12 * k), Vector3.ONE, Vector3(1.2, 0, 0))
			var fl := _part(tail, _cone(0.16 * k, 0.4 * k), Color("#ffb02a"), Vector3(0, 0.25 * k, 0.3 * k), Vector3.ONE, Vector3(0.3, 0, 0), false, 3.0)
			_add_fire_particles(fl, 0.15 * k)
		"fish":
			_part(tail, _cyl(0.12 * k, 0.05 * k, 0.3 * k), c1, Vector3(0, 0, 0.12 * k), Vector3.ONE, Vector3(PI / 2, 0, 0))
			_part(tail, _sph(0.18 * k), c2, Vector3(0, 0.05 * k, 0.32 * k), Vector3(0.2, 1.0, 0.7))
		"fluffy":
			_part(tail, _sph(0.2 * k), c2.lerp(Color.WHITE, 0.4), Vector3(0, 0.08 * k, 0.12 * k))
		"bolt":
			for i in 3:
				_part(tail, _box(Vector3(0.06, 0.22, 0.06) * k), Color("#ffe14a"), Vector3((0.06 if i % 2 == 0 else -0.06) * k, 0.12 * k * i, 0.12 * k + 0.08 * k * i), Vector3.ONE, Vector3(0.5, 0, 0.6 * (1 if i % 2 == 0 else -1)), true, 1.2)
		"small":
			_part(tail, _sph(0.1 * k), c1, Vector3(0, 0, 0.06 * k))
		"long":
			_part(tail, _cyl(0.14 * k, 0.03 * k, 0.9 * k), c1, Vector3(0, -0.05 * k, 0.4 * k), Vector3.ONE, Vector3(PI / 2 + 0.25, 0, 0))
		"stinger":
			for i in 3:
				_part(tail, _sph(0.12 * k * (1.0 - i * 0.15)), c1, Vector3(0, 0.15 * k * i + 0.1 * k, 0.18 * k - 0.04 * k * i))
			_part(tail, _cone(0.08 * k, 0.3 * k), c2, Vector3(0, 0.55 * k, 0.05 * k), Vector3.ONE, Vector3(-2.2, 0, 0), true, 1.2)
		"wisp":
			_part(tail, _cone(0.14 * k, 0.5 * k), c2, Vector3(0, 0.05 * k, 0.25 * k), Vector3.ONE, Vector3(1.4, 0, 0), false, 1.8)


func _add_fire_particles(parent: Node3D, r: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := _sph(r * 0.5, 6)
	p.mesh = m
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color("#ffcf4a")
	cm.emission_enabled = true
	cm.emission = Color("#ff8a2a")
	cm.emission_energy_multiplier = 2.0
	p.material_override = cm
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)


func _add_sparkles() -> void:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 * s
	p.direction = Vector3.UP
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.mesh = _sph(0.04 * s + 0.02, 4)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color("#fff6b0")
	cm.emission_enabled = true
	cm.emission = Color("#ffe14a")
	cm.emission_energy_multiplier = 3.0
	p.material_override = cm
	p.position = Vector3(0, 0.6 * s, 0)
	add_child(p)


# ------------------------------------------------------------------ formas
func _build_round() -> void:
	var r := 0.5 * s
	body = Node3D.new()
	body.position = Vector3(0, r * 0.95, 0)
	root_pivot.add_child(body)
	head = body
	_part(body, _sph(r), c1, Vector3.ZERO, Vector3(1, 0.92, 1))
	_part(body, _sph(r * 0.62), c2, Vector3(0, -r * 0.18, -r * 0.48), Vector3(1, 0.9, 0.55), Vector3.ZERO, false)
	_add_eyes(body, Vector3(0, r * 0.15, -r * 0.84), r * 0.34, r * 0.2)
	_add_ears(body, Vector3(0, r * 0.82, 0), r * 0.48, s * 1.0)
	_add_horns(body, Vector3(0, r * 0.85, -r * 0.1), s)
	_add_tail(body, Vector3(0, -r * 0.3, r * 0.9), s)
	for side in [-1, 1]:
		var f := _part(root_pivot, _sph(r * 0.24), c1.darkened(0.15), Vector3(side * r * 0.45, r * 0.12, -r * 0.3), Vector3(1, 0.7, 1.3))
		legs.append([f, 0.0 if side < 0 else PI])


func _build_quad() -> void:
	var r := 0.32 * s
	var leg_h := 0.36 * s
	body = Node3D.new()
	body.position = Vector3(0, leg_h + r * 0.75, 0)
	root_pivot.add_child(body)
	_part(body, _cap(r, 1.15 * s), c1, Vector3.ZERO, Vector3(1, 0.95, 1), Vector3(PI / 2, 0, 0))
	_part(body, _cap(r * 0.7, 0.8 * s), c2, Vector3(0, -r * 0.35, 0), Vector3(1, 0.6, 1), Vector3(PI / 2, 0, 0), false)
	head = Node3D.new()
	head.position = Vector3(0, r * 0.75, -0.52 * s)
	body.add_child(head)
	var hr := 0.3 * s
	_part(head, _sph(hr), c1, Vector3.ZERO, Vector3(1, 0.95, 1.05))
	_part(head, _sph(hr * 0.55), c2, Vector3(0, -hr * 0.35, -hr * 0.7), Vector3(1, 0.7, 0.8), Vector3.ZERO, false)
	_part(head, _sph(hr * 0.12), Color("#2a1a20"), Vector3(0, -hr * 0.12, -hr * 1.08), Vector3.ONE, Vector3.ZERO, false)
	_add_eyes(head, Vector3(0, hr * 0.2, -hr * 0.78), hr * 0.42, hr * 0.24)
	_add_ears(head, Vector3(0, hr * 0.75, 0.05 * s), hr * 0.55, s * 0.9)
	_add_horns(head, Vector3(0, hr * 0.8, 0), s * 0.9)
	_add_tail(body, Vector3(0, r * 0.2, 0.58 * s), s)
	for i in 4:
		var side := -1 if i % 2 == 0 else 1
		var front := i < 2
		var pivot := Node3D.new()
		pivot.position = Vector3(side * r * 0.62, -r * 0.4, (-0.32 if front else 0.32) * s)
		body.add_child(pivot)
		_part(pivot, _cap(0.1 * s, leg_h + 0.12 * s), c1.darkened(0.12), Vector3(0, -leg_h * 0.5, 0))
		legs.append([pivot, (0.0 if (i == 0 or i == 3) else PI)])


func _build_bird() -> void:
	var r := 0.36 * s
	flying = body_def.get("wings", false)
	body = Node3D.new()
	body.position = Vector3(0, 0.55 * s + (0.5 if flying else 0.0), 0)
	root_pivot.add_child(body)
	_part(body, _sph(r), c1, Vector3.ZERO, Vector3(1, 0.95, 1.15))
	_part(body, _sph(r * 0.7), c2, Vector3(0, -r * 0.2, -r * 0.45), Vector3(1, 0.9, 0.6), Vector3.ZERO, false)
	head = Node3D.new()
	head.position = Vector3(0, r * 0.95, -r * 0.4)
	body.add_child(head)
	var hr := 0.27 * s
	_part(head, _sph(hr), c1, Vector3.ZERO)
	_part(head, _cone(hr * 0.35, hr * 0.8, 6), Color("#ffb03a"), Vector3(0, -hr * 0.1, -hr * 1.1), Vector3(1, 1, 1), Vector3(-PI / 2, 0, 0))
	_add_eyes(head, Vector3(0, hr * 0.2, -hr * 0.75), hr * 0.45, hr * 0.26)
	_add_horns(head, Vector3(0, hr * 0.8, 0), s * 0.8)
	_add_tail(body, Vector3(0, 0, r * 1.0), s)
	for side in [-1, 1]:
		var w := Node3D.new()
		w.position = Vector3(side * r * 0.85, r * 0.2, 0)
		body.add_child(w)
		_part(w, _sph(r * 0.9), c2.lerp(c1, 0.4), Vector3(side * r * 0.75, 0, 0.05 * s), Vector3(1.0, 0.18, 0.6))
		wings.append([w, side])
	for side in [-1, 1]:
		var lg := _part(root_pivot if not flying else body, _cyl(0.03 * s, 0.03 * s, 0.3 * s), Color("#ffb03a"), Vector3(side * r * 0.35, (0.15 * s) if not flying else -r * 0.95, 0), Vector3.ONE, Vector3.ZERO, false)
		legs.append([lg, 0.0 if side < 0 else PI])


func _build_serpent() -> void:
	var n := 6
	body = Node3D.new()
	root_pivot.add_child(body)
	for i in n:
		var rr := (0.3 - i * 0.032) * s
		var seg := _part(body, _sph(rr), c1 if i % 2 == 0 else c1.darkened(0.08), Vector3(0, rr * 0.9, 0.38 * s * i), Vector3(1, 0.85, 1.1))
		segments.append(seg)
		if i % 2 == 1:
			_part(seg, _sph(rr * 0.55), c2, Vector3(0, -rr * 0.3, 0), Vector3(1.2, 0.5, 1.2), Vector3.ZERO, false)
	head = Node3D.new()
	head.position = Vector3(0, 0.62 * s, -0.25 * s)
	body.add_child(head)
	var hr := 0.34 * s
	_part(head, _sph(hr), c1, Vector3.ZERO, Vector3(1, 0.85, 1.2))
	_part(head, _sph(hr * 0.6), c2, Vector3(0, -hr * 0.35, -hr * 0.55), Vector3(1.1, 0.5, 0.9), Vector3.ZERO, false)
	_add_eyes(head, Vector3(0, hr * 0.3, -hr * 0.82), hr * 0.45, hr * 0.24)
	_add_horns(head, Vector3(0, hr * 0.65, 0), s * 0.9)
	tail = segments[n - 1]


func _build_golem() -> void:
	var r := 0.5 * s
	body = Node3D.new()
	body.position = Vector3(0, r * 1.25, 0)
	root_pivot.add_child(body)
	_part(body, _sph(r, 10), c1, Vector3.ZERO, Vector3(1.05, 1.0, 0.85))
	_part(body, _sph(r * 0.6, 10), c2, Vector3(0, -r * 0.1, -r * 0.42), Vector3(1, 1, 0.5), Vector3.ZERO, false)
	head = Node3D.new()
	head.position = Vector3(0, r * 0.95, -r * 0.15)
	body.add_child(head)
	var hr := 0.3 * s
	_part(head, _sph(hr, 10), c1.lightened(0.05), Vector3.ZERO, Vector3(1.1, 0.9, 1))
	_add_eyes(head, Vector3(0, hr * 0.1, -hr * 0.82), hr * 0.42, hr * 0.22)
	_add_horns(head, Vector3(0, hr * 0.7, 0), s * 0.8)
	_add_ears(head, Vector3(0, hr * 0.6, 0), hr * 0.6, s * 0.8)
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * r * 1.0, r * 0.3, 0)
		body.add_child(arm)
		_part(arm, _cap(0.16 * s, 0.75 * s), c1.darkened(0.1), Vector3(side * 0.05 * s, -0.3 * s, 0), Vector3.ONE, Vector3(0, 0, side * 0.15))
		_part(arm, _sph(0.2 * s, 10), c2.darkened(0.1), Vector3(side * 0.1 * s, -0.68 * s, 0))
		wings.append([arm, side])
		var leg := Node3D.new()
		leg.position = Vector3(side * r * 0.45, -r * 0.8, 0)
		body.add_child(leg)
		_part(leg, _cap(0.18 * s, 0.45 * s), c1.darkened(0.18), Vector3(0, -0.15 * s, 0))
		legs.append([leg, 0.0 if side < 0 else PI])
	_add_tail(body, Vector3(0, -r * 0.4, r * 0.75), s)


func _build_biped() -> void:
	var r := 0.33 * s
	body = Node3D.new()
	body.position = Vector3(0, 0.62 * s, 0)
	root_pivot.add_child(body)
	_part(body, _cap(r, 1.2 * s), c1, Vector3.ZERO)
	_part(body, _cap(r * 0.75, 0.9 * s), c2, Vector3(0, -0.06 * s, -r * 0.35), Vector3(1, 1, 0.7), Vector3.ZERO, false)
	head = body
	_add_eyes(body, Vector3(0, 0.32 * s, -r * 0.82), r * 0.36, r * 0.22)
	_part(body, _cone(r * 0.25, r * 0.5, 6), Color("#ffb03a"), Vector3(0, 0.2 * s, -r * 1.05), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	for side in [-1, 1]:
		var w := Node3D.new()
		w.position = Vector3(side * r * 0.95, 0.05 * s, 0)
		body.add_child(w)
		_part(w, _sph(0.2 * s), c1.darkened(0.1), Vector3(side * 0.05 * s, -0.12 * s, 0), Vector3(0.3, 1.0, 0.6))
		wings.append([w, side])
		var f := _part(root_pivot, _sph(0.12 * s), Color("#ffb03a"), Vector3(side * r * 0.45, 0.04 * s, -0.08 * s), Vector3(1, 0.4, 1.5))
		legs.append([f, 0.0 if side < 0 else PI])
	_add_tail(body, Vector3(0, -0.45 * s, r * 0.9), s)


func _add_extras() -> void:
	var ex: String = body_def.get("extra", "none")
	var top := Vector3(0, 0.5 * s, 0)
	var host: Node3D = head if head != null else body
	if shape == "quad" or shape == "serpent":
		host = body
		top = Vector3(0, 0.3 * s, 0.05 * s)
	match ex:
		"sprout":
			var h := head if head != null else body
			var tp := Vector3(0, (0.45 if shape == "round" else 0.28) * s, 0)
			_part(h, _cyl(0.025 * s, 0.025 * s, 0.25 * s), Color("#3f8f2e"), tp + Vector3(0, 0.1 * s, 0), Vector3.ONE, Vector3.ZERO, false)
			for side in [-1, 1]:
				_part(h, _sph(0.12 * s), Color("#7cd65a"), tp + Vector3(side * 0.1 * s, 0.24 * s, 0), Vector3(1.4, 0.35, 0.8), Vector3(0, 0, side * 0.4))
		"mushroom":
			_part(body, _sph(0.42 * s), c1, Vector3(0, 0.38 * s, 0), Vector3(1.3, 0.55, 1.3))
			for i in 5:
				var a := TAU * i / 5.0
				_part(body, _sph(0.06 * s), c2, Vector3(cos(a) * 0.3 * s, 0.5 * s, sin(a) * 0.3 * s), Vector3(1, 0.5, 1), Vector3.ZERO, false)
		"rocks":
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_part(host, _sph(0.14 * s, 6), c2.darkened(0.1), top + Vector3(cos(a) * 0.18 * s, 0.05 * s, sin(a) * 0.18 * s), Vector3(1, 0.8, 1))
		"spikes":
			for i in 7:
				var a := -0.9 + i * 0.3
				_part(host, _cone(0.07 * s, 0.32 * s, 5), c1.darkened(0.25), top + Vector3(sin(a) * 0.22 * s, 0.02 * s, cos(a) * 0.12 * s + 0.1 * s), Vector3.ONE, Vector3(0.5 * cos(a) + 0.3, 0, -a * 0.8))
		"cactus":
			for side in [-1, 1]:
				_part(body, _cap(0.1 * s, 0.4 * s), c1, Vector3(side * 0.42 * s, 0.1 * s, 0), Vector3.ONE, Vector3(0, 0, side * -0.3))
			_part(body, _sph(0.1 * s), c2, Vector3(0, 0.52 * s, 0), Vector3.ONE, Vector3.ZERO, false, 0.5)
		"shell":
			_part(host, _sph(0.36 * s), c2, top + Vector3(0, -0.05 * s, 0.05 * s), Vector3(1.05, 0.6, 1.3))
		"petals":
			for i in 6:
				var a := TAU * i / 6.0
				_part(head, _sph(0.12 * s), c2, Vector3(cos(a) * 0.22 * s, 0.05 * s, sin(a) * 0.22 * s + 0.05 * s), Vector3(1, 0.3, 1.4), Vector3(0, -a, 0))
		"moss":
			for i in 5:
				var a := TAU * i / 5.0
				_part(host, _sph(0.16 * s, 8), Color("#4e8a3a"), top + Vector3(cos(a) * 0.22 * s, 0.02 * s, sin(a) * 0.25 * s), Vector3(1, 0.6, 1))
		"lava":
			for i in 6:
				var a := TAU * i / 6.0
				_part(body, _sph(0.08 * s, 6), Color("#ff6a1a"), Vector3(cos(a) * 0.42 * s, (i % 3) * 0.12 * s - 0.1 * s, sin(a) * 0.36 * s), Vector3(1, 0.5, 1), Vector3.ZERO, false, 3.0)
		"coral":
			for i in 4:
				var a := TAU * i / 4.0
				_part(body, _cyl(0.04 * s, 0.02 * s, 0.35 * s), c2, Vector3(cos(a) * 0.15 * s, 0.45 * s, sin(a) * 0.15 * s), Vector3.ONE, Vector3(sin(a) * 0.5, 0, cos(a) * 0.5), false, 1.0)
		"collar":
			var tor := TorusMesh.new()
			tor.inner_radius = 0.2 * s
			tor.outer_radius = 0.28 * s
			_part(body, tor, Color("#3a3438"), Vector3(0, 0.38 * s if shape != "quad" else 0.1 * s, -0.12 * s if shape != "quad" else -0.42 * s), Vector3.ONE, Vector3(0.3 if shape != "quad" else 1.2, 0, 0), false)
			_part(body, _sph(0.05 * s), Color("#ff2a2a"), Vector3(0, 0.33 * s if shape != "quad" else 0.0, -0.36 * s if shape != "quad" else -0.62 * s), Vector3.ONE, Vector3.ZERO, false, 3.0)


# ------------------------------------------------------------------ animação
func play_attack() -> void:
	_attack_t = 0.35


func play_hurt() -> void:
	_hurt_t = 0.3


func play_happy() -> void:
	_happy_t = 1.2


func set_fainted(v: bool) -> void:
	fainted = v


func _process(delta: float) -> void:
	if root_pivot == null:
		return
	_t += delta
	var spd := move_speed
	var bob := sin(_t * 2.2) * 0.025 * s
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var scl := Vector3.ONE
	match shape:
		"round":
			var hop := absf(sin(_t * 9.0)) * 0.22 * s * spd
			pos.y = hop + bob
			var sq := 1.0 + sin(_t * 18.0) * 0.06 * spd + sin(_t * 2.2) * 0.02
			scl = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
		"bird":
			pos.y = bob * (3.0 if flying else 1.0)
			for w in wings:
				var flap := sin(_t * (14.0 if flying else 4.0 + spd * 10.0)) * (0.9 if flying else 0.25 + spd * 0.5)
				w[0].rotation.z = w[1] * flap
		"serpent":
			for i in segments.size():
				var seg: Node3D = segments[i]
				seg.position.x = sin(_t * (3.0 + spd * 6.0) - i * 0.9) * 0.14 * s * (0.4 + spd)
			if head != null:
				head.position.x = sin(_t * (3.0 + spd * 6.0) + 0.9) * 0.08 * s
			pos.y = bob * 0.5
		"golem":
			pos.y = absf(sin(_t * 5.0)) * 0.05 * s * spd + bob * 0.5
			rot.z = sin(_t * 5.0) * 0.06 * spd
			for w in wings:
				w[0].rotation.x = sin(_t * 5.0 + (0.0 if w[1] < 0 else PI)) * 0.6 * spd + sin(_t * 1.5) * 0.05
		"biped":
			rot.z = sin(_t * 9.0) * 0.12 * spd
			pos.y = absf(sin(_t * 9.0)) * 0.05 * s * spd + bob
			for w in wings:
				w[0].rotation.z = w[1] * (0.3 + sin(_t * 9.0) * 0.3 * spd)
		_:
			pos.y = bob + absf(sin(_t * 10.0)) * 0.04 * s * spd
	for l in legs:
		var node: Node3D = l[0]
		if shape == "quad" or shape == "golem":
			node.rotation.x = sin(_t * 10.0 + l[1]) * 0.6 * spd
		elif shape == "round" or shape == "biped":
			node.position.z = (-0.15 * s) + sin(_t * 12.0 + l[1]) * 0.08 * s * spd
	if tail != null and shape != "serpent":
		tail.rotation.y = sin(_t * 3.0) * 0.35
	if head != null and head != body:
		head.rotation.x = sin(_t * 1.3) * 0.06
	# ataque: avanço rápido
	if _attack_t > 0.0:
		_attack_t -= delta
		var k := sin((0.35 - _attack_t) / 0.35 * PI)
		pos.z -= k * 0.35 * s
		scl *= Vector3(1.0 + k * 0.1, 1.0 - k * 0.1, 1.0 + k * 0.15)
	# alegria: pulinhos
	if _happy_t > 0.0:
		_happy_t -= delta
		pos.y += absf(sin(_happy_t * 10.0)) * 0.35 * s
		rot.y += sin(_happy_t * 6.0) * 0.4
	# dano: tremida + flash
	if _hurt_t > 0.0:
		_hurt_t -= delta
		pos.x += sin(_hurt_t * 80.0) * 0.06 * s
		_set_flash(clampf(_hurt_t / 0.3, 0.0, 1.0) * 0.7)
	elif _flash_mat != null and _flash_mat.albedo_color.a > 0.0:
		_set_flash(0.0)
	# desmaio: tomba de lado
	_faint_k = move_toward(_faint_k, 1.0 if fainted else 0.0, delta * 3.0)
	rot.z += _faint_k * PI * 0.5
	pos.y -= _faint_k * 0.2 * s
	root_pivot.position = pos
	root_pivot.rotation = rot
	root_pivot.scale = scl


func _set_flash(a: float) -> void:
	_flash_mat.albedo_color = Color(1, 1, 1, a)
	for mi in _mats:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat if a > 0.0 else null


func height() -> float:
	## Altura aproximada (para barras de vida e números de dano).
	match shape:
		"round":
			return 1.0 * s + 0.3
		"quad":
			return 1.15 * s + 0.2
		"bird":
			return 1.2 * s + (0.5 if flying else 0.0) + 0.2
		"serpent":
			return 1.0 * s + 0.2
		"golem":
			return 2.2 * s * 0.75 + 0.3
		"biped":
			return 1.3 * s + 0.2
	return 1.2 * s
