class_name MeshBuilder
extends RefCounted
## Construtor de malhas low-poly com cores por vértice e normais "flat" (visual facetado estilizado).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var xf := Transform3D.IDENTITY
var jitter := 0.0
var center_hint := Vector3.INF  # quando definido, a face é orientada para fora deste ponto
var sway := 0.0  # gravado no alfa da cor: peso do vento no shader de vegetação
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
	v.a = sway
	colors.append(v)
	colors.append(v)
	colors.append(v)


func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	## Triângulo com normais e cores por vértice (sombreamento suave). A ordem é corrigida pelas normais dadas.
	if (b - a).cross(c - a).dot(na + nb + nc) < 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
		var tc := cb
		cb = cc
		cc = tc
	var bs := xf.basis
	verts.append(xf * a)
	verts.append(xf * c)
	verts.append(xf * b)
	normals.append((bs * na).normalized())
	normals.append((bs * nc).normalized())
	normals.append((bs * nb).normalized())
	for col in [ca, cc, cb]:
		var v: Color = col
		v.a = sway
		colors.append(v)


func blob(center: Vector3, radius: Vector3, top_col: Color, bottom_col: Color, rings: int = 5, segs: int = 9, rough: float = 0.0) -> void:
	## Esfera suave (folhagem): normais radiais e degradê vertical de cor.
	var pts: Array = []
	var nrm: Array = []
	for r in rings + 1:
		var row: Array = []
		var nrow: Array = []
		var phi := PI * r / rings
		for sg in segs:
			var th := TAU * sg / segs + (0.5 * TAU / segs if r % 2 == 1 else 0.0)
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0 + (rng.randf_range(-rough, rough) if r > 0 and r < rings else 0.0)
			row.append(center + d * radius * k)
			nrow.append(Vector3(d.x / radius.x, d.y / radius.y, d.z / radius.z).normalized())
		pts.append(row)
		nrm.append(nrow)
	var colf := func(p: Vector3) -> Color:
		var t := clampf((p.y - (center.y - radius.y)) / (2.0 * radius.y), 0.0, 1.0)
		return bottom_col.lerp(top_col, smoothstep(0.1, 0.95, t))
	for r in rings:
		for sg in segs:
			var a: Vector3 = pts[r][sg]
			var b: Vector3 = pts[r][(sg + 1) % segs]
			var c: Vector3 = pts[r + 1][sg]
			var d: Vector3 = pts[r + 1][(sg + 1) % segs]
			var na: Vector3 = nrm[r][sg]
			var nb: Vector3 = nrm[r][(sg + 1) % segs]
			var nc: Vector3 = nrm[r + 1][sg]
			var nd: Vector3 = nrm[r + 1][(sg + 1) % segs]
			# anel r para baixo: (a, b, d) e (a, d, c) vistos de fora em ordem anti-horária
			if r > 0:
				tri_smooth(a, c, b, na, nc, nb, colf.call(a), colf.call(c), colf.call(b))
			if r < rings - 1:
				tri_smooth(b, c, d, nb, nc, nd, colf.call(b), colf.call(c), colf.call(d))


func cone_smooth(base: Vector3, r: float, h: float, segs: int, bottom_col: Color, top_col: Color, droop: float = 0.0) -> void:
	## Cone suave (camada de pinheiro) com borda caída e degradê.
	var top := base + Vector3(0, h, 0)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := base + Vector3(cos(a0) * r, -droop, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, -droop, sin(a1) * r)
		var n0 := Vector3(cos(a0) * h, r, sin(a0) * h).normalized()
		var n1 := Vector3(cos(a1) * h, r, sin(a1) * h).normalized()
		var nt := (n0 + n1).normalized()
		tri_smooth(p1, top, p0, n1, nt, n0, bottom_col, top_col, bottom_col)
		# fundo escuro
		tri_smooth(p0, base + Vector3(0, -droop * 0.3, 0), p1, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, bottom_col.darkened(0.45), bottom_col.darkened(0.45), bottom_col.darkened(0.45))


func tube(points: Array, radii: Array, segs: int, col: Color, col_top: Color) -> void:
	## Tronco/galho suave seguindo uma linha de pontos.
	var rings: Array = []
	for i in points.size():
		var p: Vector3 = points[i]
		var dir: Vector3 = (points[min(i + 1, points.size() - 1)] - points[max(i - 1, 0)]).normalized()
		var side := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var up2 := side.cross(dir).normalized()
		var ring: Array = []
		for sg in segs:
			var a := TAU * sg / segs
			var nn := (side * cos(a) + up2 * sin(a)).normalized()
			ring.append([p + nn * float(radii[i]), nn])
		rings.append(ring)
	for i in points.size() - 1:
		var t0 := float(i) / (points.size() - 1)
		var t1 := float(i + 1) / (points.size() - 1)
		var c0 := col.lerp(col_top, t0)
		var c1 := col.lerp(col_top, t1)
		for sg in segs:
			var a: Array = rings[i][sg]
			var b: Array = rings[i][(sg + 1) % segs]
			var c: Array = rings[i + 1][sg]
			var d: Array = rings[i + 1][(sg + 1) % segs]
			tri_smooth(a[0], c[0], b[0], a[1], c[1], b[1], c0, c1, c0)
			tri_smooth(b[0], c[0], d[0], b[1], c[1], d[1], c0, c1, c1)


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


func sphere(center: Vector3, radius: Vector3, col: Color, rings: int = 4, segs: int = 7, rough: float = 0.0, bottom_col: Variant = null, top_col: Variant = null) -> void:
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
			if top_col != null:
				var fd := ((a + b + cc + dd) * 0.25 - center).normalized()
				if fd.y > 0.5:
					c = (top_col as Color).lerp(c, clampf((0.8 - fd.y) * 2.0, 0.0, 0.6))
				elif r > 0:
					c = (bottom_col if bottom_col != null and r >= rings / 2 else col)
					c = c.darkened(0.06 * float(r) / rings)
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
	# cores são escritas em sRGB; o renderer de compatibilidade espera linear nos vértices
	var lin := PackedColorArray()
	lin.resize(colors.size())
	for i in colors.size():
		lin[i] = colors[i].srgb_to_linear()
	arr[Mesh.ARRAY_COLOR] = lin
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func clear() -> void:
	verts = PackedVector3Array()
	normals = PackedVector3Array()
	colors = PackedColorArray()
	xf = Transform3D.IDENTITY
