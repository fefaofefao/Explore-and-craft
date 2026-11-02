class_name GrassField
extends Node3D
## Campo de grama em blocos (MultiMesh por bloco, com alcance de visibilidade).
## Guarda as posições de cada tufo para poder cortá-los (golpes) e fazê-los crescer de novo.

const CHUNK := 24.0
const REGROW_SEC := 150.0

var mat: ShaderMaterial
var half := 120.0
var chunks: Dictionary = {}  # Vector2i -> {"mm": MultiMesh, "xf": Array, "alive": PackedByteArray}
var _regrow: Array = []  # [key, idx, t]
var _clock := 0.0
var _regrow_check := 0.0
var total := 0


func setup(p_name: String, mesh: Mesh, xforms: Array, cols: Array, p_mat: ShaderMaterial, p_half: float, vis_end: float) -> GrassField:
	name = p_name
	mat = p_mat
	half = p_half
	total = xforms.size()
	mat.set_shader_parameter("fade_end", vis_end)
	var buckets := {}
	for i in xforms.size():
		var key := key_of(xforms[i].origin)
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(i)
	for key in buckets:
		var ids: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = cols.size() > 0
		mm.mesh = mesh
		mm.instance_count = ids.size()
		var xf: Array = []
		var alive := PackedByteArray()
		alive.resize(ids.size())
		alive.fill(1)
		for j in ids.size():
			var t: Transform3D = xforms[ids[j]]
			mm.set_instance_transform(j, t)
			xf.append(t)
			if cols.size() > 0:
				mm.set_instance_color(j, cols[ids[j]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 6.0
		# AABB generoso: o vento e os empurrões deslocam as lâminas
		mmi.extra_cull_margin = 2.0
		add_child(mmi)
		chunks[key] = {"mm": mm, "xf": xf, "alive": alive}
	return self


func key_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x + half) / CHUNK)), int(floor((p.z + half) / CHUNK)))


func cut(at: Vector3, r: float) -> Array:
	## Corta os tufos dentro do raio; devolve as posições cortadas.
	var out: Array = []
	var k0 := key_of(at - Vector3(r, 0, r))
	var k1 := key_of(at + Vector3(r, 0, r))
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			var key := Vector2i(kx, kz)
			if not chunks.has(key):
				continue
			var c: Dictionary = chunks[key]
			var xf: Array = c["xf"]
			var alive: PackedByteArray = c["alive"]
			for j in xf.size():
				if alive[j] == 0:
					continue
				var o: Vector3 = xf[j].origin
				if Vector2(o.x - at.x, o.z - at.z).length() <= r and absf(o.y - at.y) < 2.5:
					alive[j] = 0
					# toco baixinho no lugar do tufo
					var t: Transform3D = xf[j]
					(c["mm"] as MultiMesh).set_instance_transform(j, Transform3D(t.basis.scaled(Vector3(1.0, 0.18, 1.0)), t.origin))
					out.append(o)
					_regrow.append([key, j, _clock + REGROW_SEC])
			c["alive"] = alive
	return out


func alive_count() -> int:
	var n := 0
	for key in chunks:
		var alive: PackedByteArray = chunks[key]["alive"]
		for b in alive:
			n += b
	return n


func _process(delta: float) -> void:
	_clock += delta
	_regrow_check -= delta
	if _regrow_check > 0.0 or _regrow.is_empty():
		return
	_regrow_check = 1.0
	var keep: Array = []
	for e in _regrow:
		if _clock >= float(e[2]):
			var c: Dictionary = chunks[e[0]]
			var alive: PackedByteArray = c["alive"]
			alive[e[1]] = 1
			c["alive"] = alive
			(c["mm"] as MultiMesh).set_instance_transform(e[1], c["xf"][e[1]])
		else:
			keep.append(e)
	_regrow = keep
