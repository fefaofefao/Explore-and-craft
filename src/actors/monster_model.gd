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
var _atk_dur := 0.45
var _atk_style := "bite"
var _basic_alt := false
var _hurt_dir := Vector3.ZERO
var in_combat := false
var _flash_req := 0.0
var _flash_tint := Color.WHITE
var _combat_k := 0.0
const ATTACK_DUR := {"bite": 0.42, "pounce": 0.6, "slam": 0.75, "spin": 0.55, "cast": 0.5, "charge": 0.6,
	"dive": 0.6, "coil": 0.55, "punch": 0.55, "roar": 0.7, "glow": 0.6, "bounce": 0.5}
var _hurt_t := 0.0
var _happy_t := 0.0
var fainted := false
var _blink := 3.0
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
	_add_ground_shadow()
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return self


# ------------------------------------------------------------------ helpers
static var _toon_shader: Shader


static func toon_mat(c: Color, outline: bool = true, emissive: float = 0.0, outline_w: float = 0.025) -> Material:
	## Material toon compartilhado (cache por cor). Usado por Ecos e personagens.
	var key := "toon_%s_%s_%.1f_%.3f" % [c.to_html(), outline, emissive, outline_w]
	if MeshLib._mats.has(key):
		return MeshLib._mats[key]
	if _toon_shader == null:
		_toon_shader = load("res://assets/shaders/toon.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _toon_shader
	m.set_shader_parameter("albedo", c)
	# sombra levemente fria e saturada, como em animação
	var sh := Color.from_hsv(fmod(c.h + 0.62, 1.0) if c.s > 0.08 else 0.66, 0.35, 0.95)
	m.set_shader_parameter("shade_tint", sh.lerp(Color(0.6, 0.6, 0.85), 0.5))
	if emissive > 0.0:
		m.set_shader_parameter("emission", c)
		m.set_shader_parameter("emission_energy", emissive)
	if outline:
		m.next_pass = MeshLib.outline_mat(outline_w)
	MeshLib._mats[key] = m
	return m


func _mat(c: Color, outline: bool = true, emissive: float = 0.0) -> Material:
	return toon_mat(c, outline, emissive, snappedf(0.01 + 0.012 * s, 0.002))


static func unlit(c: Color) -> Material:
	return MeshLib.color_mat(c, 0.0, true)


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


static func ring_mesh(inner: float, outer: float) -> TorusMesh:
	var key := "ring_%.3f_%.3f" % [inner, outer]
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 8
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


func _eye_color() -> Color:
	var t: String = GameData.db().sp(sp_id)["types"][0]
	var tc := Color(GameData.db().types["colors"][t])
	if variant:
		tc = Color.from_hsv(fmod(tc.h + 0.45, 1.0), tc.s, tc.v)
	return tc.darkened(0.15)


func _add_eyes(parent: Node3D, center: Vector3, spread: float, r: float, forward: float = -1.0) -> void:
	## Olhos grandes estilo anime: contorno, esclera, íris colorida, pupila, dois brilhos e cílios. Piscam.
	var style: String = body_def.get("eyes", "round")
	r *= 1.3
	var iris := _eye_color()
	for side in [-1, 1]:
		var e := Node3D.new()
		e.position = center + Vector3(side * spread * 1.05, 0, 0)
		parent.add_child(e)
		eyes.append(e)
		var f := forward
		match style:
			"glow":
				_part(e, _sph(r * 0.95), Color("#1a1028"), Vector3(0, 0, f * r * 0.05), Vector3(1.1, 1.2, 0.45), Vector3.ZERO, false)
				_part(e, _sph(r * 0.8), c2.lightened(0.5), Vector3(0, 0, f * r * 0.22), Vector3(1, 1.1, 0.4), Vector3.ZERO, false, 3.0)
			"visor":
				if side == -1:
					_part(e, _box(Vector3(spread * 2.8, r * 0.8, r * 0.5)), Color("#1a2a3a"), Vector3(spread, 0, 0), Vector3.ONE, Vector3.ZERO, false)
					_part(e, _box(Vector3(spread * 2.5, r * 0.45, r * 0.55)), Color("#5fe0ff"), Vector3(spread, 0, f * r * 0.05), Vector3.ONE, Vector3.ZERO, false, 3.0)
			_:
				var squint := 0.75 if style == "angry" else (0.62 if style == "sleepy" else 1.0)
				_part(e, _sph(r * 1.12), Color("#1a1420"), Vector3(0, 0, f * r * 0.02), Vector3(1, 1.22 * squint, 0.42), Vector3.ZERO, false)
				_part(e, _sph(r), Color("#ffffff"), Vector3(0, 0, f * r * 0.12), Vector3(1, 1.18 * squint, 0.45), Vector3.ZERO, false)
				var ir := r * (0.8 if style == "happy" else 0.68)
				_part(e, _sph(ir), iris, Vector3(side * -r * 0.06, -r * 0.06, f * r * 0.42), Vector3(1, 1.18 * squint, 0.3), Vector3.ZERO, false)
				_part(e, _sph(ir * 0.72), iris.lightened(0.4), Vector3(side * -r * 0.06, -r * 0.24, f * r * 0.47), Vector3(1, 0.6 * squint, 0.25), Vector3.ZERO, false)
				_part(e, _sph(ir * 0.5), Color("#120c18"), Vector3(side * -r * 0.06, -r * 0.02, f * r * 0.52), Vector3(1, 1.2 * squint, 0.25), Vector3.ZERO, false)
				var hl := MeshInstance3D.new()
				hl.mesh = _sph(r * 0.27, 8)
				hl.material_override = unlit(Color.WHITE)
				hl.position = Vector3(side * -r * 0.02 + r * 0.2, r * 0.28 * squint, f * r * 0.64)
				e.add_child(hl)
				var hl2 := MeshInstance3D.new()
				hl2.mesh = _sph(r * 0.12, 6)
				hl2.material_override = unlit(Color.WHITE)
				hl2.position = Vector3(-r * 0.24, -r * 0.3 * squint, f * r * 0.62)
				e.add_child(hl2)
				# cílios/pálpebra superior
				_part(e, _cap(r * 0.09, r * 1.9), Color("#120c18"), Vector3(0, r * 1.0 * squint, f * r * 0.36), Vector3(1, 1, 0.5), Vector3(0, 0, PI / 2 + side * (0.35 if style == "angry" else -0.12)), false)
				if style == "sleepy":
					_part(e, _sph(r * 1.08), c1, Vector3(0, r * 0.5, f * r * 0.12), Vector3(1.05, 0.62, 0.5), Vector3.ZERO, false)
	if style in ["glow", "visor"]:
		return
	# boca e bochechas
	var mouth_y := -r * 1.25
	_part(parent, _sph(r * 0.32, 8), Color("#3a1420"), center + Vector3(0, mouth_y, forward * r * 0.32), Vector3(1.3, 0.75, 0.4), Vector3.ZERO, false)
	_part(parent, _sph(r * 0.18, 8), Color("#ff7a8a"), center + Vector3(0, mouth_y - r * 0.08, forward * r * 0.42), Vector3(1.3, 0.6, 0.4), Vector3.ZERO, false)
	if GameData.db().sp(sp_id).get("temper", "") != "alfa":
		for side in [-1, 1]:
			var ch := MeshInstance3D.new()
			ch.mesh = _sph(r * 0.36, 8)
			ch.material_override = MeshLib.color_mat(Color(1.0, 0.45, 0.55, 0.45), 0.0, true)
			ch.position = center + Vector3(side * spread * 1.75, -r * 0.85, forward * r * 0.05)
			ch.scale = Vector3(1.2, 0.6, 0.35)
			parent.add_child(ch)


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


func _add_ground_shadow() -> void:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.5, 1.5) * maxf(s, 0.5)
	q.mesh = pm
	q.material_override = blob_shadow_mat()
	q.position.y = 0.03
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)


static func blob_shadow_mat() -> Material:
	if MeshLib._mats.has("blob_shadow"):
		return MeshLib._mats["blob_shadow"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load("res://assets/textures/blob_shadow.png")
	m.albedo_color = Color(0.05, 0.05, 0.1, 0.55)
	m.disable_receive_shadows = true
	MeshLib._mats["blob_shadow"] = m
	return m


# ------------------------------------------------------------------ animação
func play_attack(style: String = "", tint: Color = Color.WHITE) -> void:
	## Estilos: bite, pounce, slam, spin, cast, charge, dive, coil, punch, roar, glow, bounce.
	## Sem estilo: golpe básico típico do formato do corpo (alternando entre dois).
	if style == "":
		_basic_alt = not _basic_alt
		match shape:
			"quad":
				style = "pounce" if _basic_alt else "bite"
			"round":
				style = "bounce" if _basic_alt else "bite"
			"bird":
				style = "dive" if _basic_alt else "bite"
			"serpent":
				style = "coil"
			"golem":
				style = "punch" if _basic_alt else "slam"
			"biped":
				style = "punch" if _basic_alt else "spin"
			_:
				style = "bite"
	_atk_style = style
	_flash_tint = tint
	_atk_dur = ATTACK_DUR.get(style, 0.45)
	_attack_t = _atk_dur


func basic_windup() -> float:
	## Antecipação do próximo golpe básico (para o dano coincidir com o impacto visual).
	match shape:
		"golem":
			return 0.26
		"quad", "bird":
			return 0.2
	return 0.16


func play_hurt(from_dir: Vector3 = Vector3.ZERO) -> void:
	_hurt_t = 0.32
	_hurt_dir = from_dir
	_flash_tint = Color.WHITE


func play_happy() -> void:
	_happy_t = 1.2


func set_fainted(v: bool) -> void:
	fainted = v


func _process(delta: float) -> void:
	if root_pivot == null:
		return
	_t += delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.2, 5.0)
	var lid := 0.12 if _blink < 0.13 else 1.0
	if fainted:
		lid = 0.1
	for e in eyes:
		e.scale.y = lerpf(e.scale.y, lid, 0.6)
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
	# postura de luta: inclina para frente e balança como quem espera a brecha
	_combat_k = move_toward(_combat_k, 1.0 if in_combat and not fainted else 0.0, delta * 3.0)
	if _combat_k > 0.0:
		rot.x += 0.12 * _combat_k
		pos.x += sin(_t * 3.4) * 0.05 * s * _combat_k
		pos.y += absf(sin(_t * 6.8)) * 0.03 * s * _combat_k
	# ataque: antecipação -> golpe -> recuperação, diferente para cada estilo
	if _attack_t > 0.0:
		_attack_t -= delta
		var k := clampf(1.0 - _attack_t / _atk_dur, 0.0, 1.0)
		var a := _anim_attack(k)
		pos += a[0]
		rot += a[1]
		scl *= a[2]
	# alegria: pulinhos
	if _happy_t > 0.0:
		_happy_t -= delta
		pos.y += absf(sin(_happy_t * 10.0)) * 0.35 * s
		rot.y += sin(_happy_t * 6.0) * 0.4
	# dano: tremida + flash
	if _hurt_t > 0.0:
		_hurt_t -= delta
		var hk := clampf(_hurt_t / 0.32, 0.0, 1.0)
		# recuo (inclina para trás), achata e treme
		pos.x += sin(_hurt_t * 80.0) * 0.05 * s * hk
		pos.z += 0.22 * s * hk * hk
		rot.x -= 0.35 * hk * hk
		scl *= Vector3(1.0 + 0.12 * hk, 1.0 - 0.15 * hk, 1.0 + 0.12 * hk)
		_set_flash(maxf(hk * 0.75, _flash_req))
	elif _flash_req > 0.0:
		_set_flash(_flash_req)
	elif _flash_mat != null and _flash_mat.albedo_color.a > 0.0:
		_set_flash(0.0)
	_flash_req = 0.0
	# desmaio: tomba de lado
	_faint_k = move_toward(_faint_k, 1.0 if fainted else 0.0, delta * 3.0)
	rot.z += _faint_k * PI * 0.5
	pos.y -= _faint_k * 0.2 * s
	root_pivot.position = pos
	root_pivot.rotation = rot
	root_pivot.scale = scl


static func _phase(k: float, wind: float, strike: float) -> Array:
	## Divide 0..1 em antecipação (0..wind), golpe (wind..strike) e recuperação (strike..1).
	## Devolve [w, h, r]: quanto da antecipação (sobe e fica até o golpe), do golpe e da recuperação.
	var w := smoothstep(0.0, wind, k)
	var h := clampf((k - wind) / maxf(strike - wind, 0.001), 0.0, 1.0)
	var r := clampf((k - strike) / maxf(1.0 - strike, 0.001), 0.0, 1.0)
	return [w, h, r]


func _anim_attack(k: float) -> Array:
	## [deslocamento, rotação, escala] do corpo para o estilo atual. -Z é a frente.
	var p := Vector3.ZERO
	var r := Vector3.ZERO
	var sc := Vector3.ONE
	match _atk_style:
		"bite":
			var ph := _phase(k, 0.35, 0.55)
			var wind: float = ph[0] * (1.0 - ph[1])
			var hit: float = sin(float(ph[1]) * PI * 0.5) * (1.0 - ease(float(ph[2]), 0.6))
			p.z += 0.18 * s * wind - 0.5 * s * hit
			r.x += -0.3 * wind + 0.35 * hit
			sc = Vector3(1.0 - 0.06 * wind + 0.08 * hit, 1.0 + 0.08 * wind - 0.08 * hit, 1.0 + 0.2 * hit)
			if head != null and head != body:
				head.rotation.x += -0.5 * wind + 0.4 * hit
		"pounce":
			var ph := _phase(k, 0.3, 0.6)
			var wind: float = ph[0] * (1.0 - ph[1])
			var air: float = sin(float(ph[1]) * PI)
			var fwd: float = float(ph[1]) * (1.0 - float(ph[2]))
			p.y += air * 0.55 * s - 0.08 * s * wind
			p.z += 0.15 * s * wind - 0.8 * s * fwd
			r.x += 0.3 * wind - 0.35 * air + 0.25 * fwd * (1.0 - air)
			var land := maxf(0.0, 1.0 - absf(float(ph[2]) - 0.1) * 6.0)
			sc = Vector3(1.0 + 0.15 * wind + 0.15 * land, 1.0 - 0.22 * wind + 0.12 * air - 0.2 * land, 1.0 + 0.15 * wind)
		"bounce":
			var ph := _phase(k, 0.3, 0.6)
			var wind: float = ph[0] * (1.0 - ph[1])
			var air: float = sin(float(ph[1]) * PI)
			p.y += air * 0.6 * s
			p.z -= float(ph[1]) * (1.0 - float(ph[2])) * 0.6 * s
			var land := maxf(0.0, 1.0 - absf(float(ph[2]) - 0.1) * 5.0)
			sc = Vector3(1.0 + 0.25 * wind + 0.3 * land, 1.0 - 0.3 * wind + 0.2 * air - 0.35 * land, 1.0 + 0.25 * wind + 0.3 * land)
		"slam":
			var ph := _phase(k, 0.45, 0.58)
			var up: float = ph[0] * (1.0 - ph[1])
			var impact: float = ph[1] * (1.0 - ease(float(ph[2]), 0.5))
			p.y += 0.75 * s * up
			p.z += -0.25 * s * impact
			r.x += -0.45 * up + 0.3 * impact
			sc = Vector3(1.0 - 0.08 * up + 0.3 * impact, 1.0 + 0.12 * up - 0.32 * impact, 1.0 - 0.08 * up + 0.3 * impact)
			for w in wings:
				if shape == "golem":
					w[0].rotation.x += -2.6 * up + 0.5 * impact
		"spin":
			var ph := _phase(k, 0.3, 0.65)
			var wind: float = ph[0] * (1.0 - ph[1])
			r.y += -0.6 * wind + TAU * ease(float(ph[1]), -2.0) * (1.0 if float(ph[2]) < 1.0 else 1.0)
			r.z += sin(float(ph[1]) * PI) * 0.3
			p.y += sin(float(ph[1]) * PI) * 0.2 * s
			p.z -= sin(float(ph[1]) * PI) * 0.3 * s
		"cast":
			var ph := _phase(k, 0.4, 0.55)
			var wind: float = ph[0] * (1.0 - ph[1])
			var shot: float = ph[1] * (1.0 - ease(float(ph[2]), 0.7))
			p.z += 0.15 * s * wind - 0.2 * s * shot
			r.x += -0.35 * wind + 0.25 * shot
			sc = Vector3.ONE * (1.0 + 0.1 * wind) + Vector3(0, 0, 0.12 * shot)
			_flash_req = maxf(_flash_req, 0.35 * wind)
		"charge":
			var ph := _phase(k, 0.35, 0.6)
			var wind: float = ph[0] * (1.0 - ph[1])
			var go: float = ph[1] * (1.0 - float(ph[2]))
			p.z += 0.3 * s * wind - 0.9 * s * go
			p.y -= 0.08 * s * wind
			r.x += 0.3 * wind + 0.2 * go
			sc = Vector3(1.0 + 0.12 * wind, 1.0 - 0.15 * wind, 1.0 - 0.1 * wind + 0.3 * go)
		"dive":
			var ph := _phase(k, 0.4, 0.6)
			var up: float = ph[0] * (1.0 - ph[1])
			var dv: float = ph[1] * (1.0 - float(ph[2]))
			p.y += 0.7 * s * up - 0.25 * s * dv
			p.z += 0.2 * s * up - 0.9 * s * dv
			r.x += -0.45 * up + 0.7 * dv
			for w in wings:
				w[0].rotation.z += w[1] * (1.1 * up - 0.6 * dv)
		"coil":
			var ph := _phase(k, 0.4, 0.55)
			var wind: float = ph[0] * (1.0 - ph[1])
			var st: float = ph[1] * (1.0 - ease(float(ph[2]), 0.6))
			p.z += 0.35 * s * wind - 0.85 * s * st
			p.y += 0.25 * s * wind
			r.x += -0.4 * wind + 0.3 * st
			sc = Vector3(1.0 + 0.1 * wind, 1.0 + 0.1 * wind, 1.0 - 0.25 * wind + 0.35 * st)
		"punch":
			var ph := _phase(k, 0.4, 0.55)
			var wind: float = ph[0] * (1.0 - ph[1])
			var hit: float = ph[1] * (1.0 - ease(float(ph[2]), 0.6))
			r.y += 0.5 * wind - 0.4 * hit
			p.z += 0.1 * s * wind - 0.35 * s * hit
			r.x += 0.2 * hit
			for w in wings:
				if shape == "golem":
					var lead: bool = w[1] > 0
					w[0].rotation.x += (-2.2 * wind + 1.8 * hit) if lead else (0.4 * wind - 0.3 * hit)
				else:
					w[0].rotation.z += w[1] * (0.8 * wind - 0.5 * hit)
		"roar", "glow":
			var ph := _phase(k, 0.35, 0.5)
			var wind: float = ph[0] * (1.0 - ph[1])
			var peak: float = ph[1] * (1.0 - ease(float(ph[2]), 0.5))
			r.x += -0.5 * wind - 0.2 * peak
			p.y += 0.2 * s * wind + 0.1 * s * peak
			sc = Vector3.ONE * (1.0 + 0.08 * wind + 0.14 * peak)
			p.x += sin(k * 90.0) * 0.03 * s * peak
			if _atk_style == "glow" or peak > 0.0:
				_flash_req = maxf(_flash_req, 0.45 * maxf(wind * 0.6, peak))
			for w in wings:
				if shape == "bird" or shape == "biped":
					w[0].rotation.z += w[1] * 1.2 * (wind + peak)
				elif shape == "golem":
					w[0].rotation.x += -2.4 * (wind + peak) * 0.5
	return [p, r, sc]


func _set_flash(a: float) -> void:
	_flash_mat.albedo_color = Color(_flash_tint.r, _flash_tint.g, _flash_tint.b, a)
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
