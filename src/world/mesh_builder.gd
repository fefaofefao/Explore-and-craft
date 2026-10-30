class_name MeshBuilder
extends RefCounted
## Construtor de malhas low-poly com cores por vértice e normais "flat" (visual facetado estilizado).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var xf := Transform3D.IDENTITY
var jitter := 0.0
var center_hint := Vector3.INF  # quando definido, a face é orientada para fora deste ponto
var rng := RandomNumberGenerator.new()


func _init(seed_v: int = 1) -> void:
	rng.seed = seed_v


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	if center_hint != Vector3.INF:
		var n0 := (b - a).cross(c - a)
		if n0.dot((a + b + c) / 3.0 - center_hint) < 0.0:
			var t := b
			b = c
			c = t
	a = xf * a
	b = xf * b
	c = xf * c
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Godot usa ordem horária para a face frontal
	verts.append(a)
	verts.append(c)
	verts.append(b)
	for i in 3:
		normals.append(n)
	# leve variação de cor por face para dar textura
	var v := col.lightened(rng.randf_range(-0.04, 0.04)) if jitter > 0.0 else col
	colors.append(v)
	colors.append(v)
	colors.append(v)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)


func box(center: Vector3, size: Vector3, col: Color, rot_y: float = 0.0, top_col: Variant = null) -> void:
	var h := size * 0.5
	var b := Basis(Vector3.UP, rot_y)
	var p := func(x: float, y: float, z: float) -> Vector3: return center + b * Vector3(x * h.x, y * h.y, z * h.z)
	var tc: Color = top_col if top_col != null else col
	var s := col.darkened(0.08)
	center_hint = center
	quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), tc)  # topo
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, -1, -1), p.call(-1, -1, -1), col.darkened(0.3))  # base
	quad(p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, -1, 1), col)  # +z
	quad(p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), p.call(-1, -1, -1), s)  # -z
	quad(p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(1, -1, -1), s)  # +x
	quad(p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, -1, 1), col)  # -x
	center_hint = Vector3.INF


func cylinder(base: Vector3, r0: float, r1: float, height: float, segs: int, col: Color, cap: bool = true, tilt: Vector3 = Vector3.ZERO) -> void:
	var top := base + Vector3.UP * height + tilt
	center_hint = (base + top) * 0.5
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var c := col.darkened(0.05 * (i % 2))
		if r1 <= 0.001:
			tri(base + d0 * r0, top, base + d1 * r0, c)
		else:
			quad(base + d0 * r0, top + d0 * r1, top + d1 * r1, base + d1 * r0, c)
			if cap:
				tri(top, top + d1 * r1, top + d0 * r1, col.lightened(0.05))
		if cap:
			tri(base, base + d0 * r0, base + d1 * r0, col.darkened(0.3))
	center_hint = Vector3.INF


func cone(base: Vector3, r: float, height: float, segs: int, col: Color, tilt: Vector3 = Vector3.ZERO) -> void:
	cylinder(base, r, 0.0, height, segs, col, true, tilt)


func sphere(center: Vector3, radius: Vector3, col: Color, rings: int = 4, segs: int = 7, rough: float = 0.0, bottom_col: Variant = null) -> void:
	## Esfera low-poly (lat/long). rough desloca vértices para parecer rocha/folhagem.
	var pts: Array = []
	for r in rings + 1:
		var row: Array = []
		var phi := PI * r / rings
		for s in segs:
			var th := TAU * s / segs + (0.5 * TAU / segs if r % 2 == 1 else 0.0)
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			if rough > 0.0 and r > 0 and r < rings:
				d *= 1.0 + rng.randf_range(-rough, rough)
			row.append(center + d * radius)
		pts.append(row)
	center_hint = center
	for r in rings:
		var c: Color = col
		if bottom_col != null and r >= rings / 2:
			c = bottom_col
		c = c.darkened(0.06 * float(r) / rings)
		for s in segs:
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][(s + 1) % segs]
			var cc: Vector3 = pts[r + 1][s]
			var dd: Vector3 = pts[r + 1][(s + 1) % segs]
			if r == 0:
				tri(a, dd, cc, c)
			elif r == rings - 1:
				tri(a, b, cc, c)
			else:
				quad(a, b, dd, cc, c)
	center_hint = Vector3.INF


func octa(center: Vector3, w: float, h: float, col: Color, rot: Basis = Basis.IDENTITY) -> void:
	## Cristal: bipirâmide hexagonal.
	var top := center + rot * Vector3(0, h, 0)
	var bot := center + rot * Vector3(0, -h * 0.25, 0)
	center_hint = center + rot * Vector3(0, h * 0.3, 0)
	for i in 6:
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		var p0 := center + rot * Vector3(cos(a0) * w, h * 0.45, sin(a0) * w)
		var p1 := center + rot * Vector3(cos(a1) * w, h * 0.45, sin(a1) * w)
		var c := col.lightened(0.12) if i % 2 == 0 else col
		tri(p0, top, p1, c)
		tri(p1, bot, p0, col.darkened(0.2))
	center_hint = Vector3.INF


func commit(existing: ArrayMesh = null) -> ArrayMesh:
	var mesh := existing if existing != null else ArrayMesh.new()
	if verts.size() == 0:
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func clear() -> void:
	verts = PackedVector3Array()
	normals = PackedVector3Array()
	colors = PackedColorArray()
	xf = Transform3D.IDENTITY
