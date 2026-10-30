class_name MeshLib
extends RefCounted
## Biblioteca de malhas procedurais (árvores, rochas, cristais, estruturas) e materiais compartilhados.
## Tudo é gerado em código: o APK fica leve e o estilo visual é consistente.

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func mat(kind: String = "vc") -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	match kind:
		"vc_ds":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED  # folhas e telhados são planos abertos
		"glow":
			m.emission_enabled = true
			m.emission = Color(0.5, 0.95, 1.0)
			m.emission_energy_multiplier = 1.6
			m.rim_enabled = true
			m.rim = 0.6
		"fire":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
		"water_dark":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"terrain":
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	_mats[kind] = m
	return m


static func color_mat(c: Color, emissive: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "c_%s_%.2f_%s" % [c.to_html(), emissive, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func outline_mat(thick: float = 0.035) -> StandardMaterial3D:
	var key := "outline_%.3f" % thick
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.08, 0.06, 0.1)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = thick
	_mats[key] = m
	return m


static func get_mesh(key: String, variant: int = 0, tint: Color = Color.WHITE) -> ArrayMesh:
	var k := "%s#%d#%s" % [key, variant, tint.to_html()]
	if _meshes.has(k):
		return _meshes[k]
	var mb := MeshBuilder.new(hash(k))
	mb.jitter = 1.0
	_build(mb, key, variant, tint)
	var m := mb.commit()
	_meshes[k] = m
	return m


static func _build(mb: MeshBuilder, key: String, v: int, tint: Color) -> void:
	var trunk := Color("#7a5232")
	match key:
		"arvore":
			mb.cylinder(Vector3.ZERO, 0.32, 0.22, 2.4, 6, trunk)
			var leaf := Color("#4f9a3a") * tint
			leaf.a = 1.0
			mb.sphere(Vector3(0, 3.0, 0), Vector3(1.6, 1.3, 1.6), leaf, 4, 7, 0.18)
			mb.sphere(Vector3(0.7, 3.7, 0.2), Vector3(1.0, 0.9, 1.0), leaf.lightened(0.12), 3, 6, 0.15)
			mb.sphere(Vector3(-0.6, 3.5, -0.4), Vector3(1.0, 0.8, 1.0), leaf.darkened(0.08), 3, 6, 0.15)
			if v % 3 == 0:
				for i in 4:
					var a := TAU * i / 4.0 + 0.3
					mb.sphere(Vector3(cos(a) * 1.3, 2.8, sin(a) * 1.3), Vector3(0.14, 0.14, 0.14), Color("#ff5a6a"), 2, 4)
		"pinheiro":
			mb.cylinder(Vector3.ZERO, 0.28, 0.18, 1.6, 6, trunk.darkened(0.1))
			var g := Color("#2f6e3a") * tint
			g.a = 1.0
			var snow: bool = tint.b > 0.95 and tint.r > 0.95
			for i in 3:
				var y := 1.2 + i * 1.05
				var r := 1.6 - i * 0.42
				mb.cone(Vector3(0, y, 0), r, 1.7, 7, g.lightened(0.05 * i))
				if snow:
					mb.cone(Vector3(0, y + 1.0, 0), r * 0.42, 0.7, 7, Color("#f4faff"))
		"palmeira":
			var p := Vector3.ZERO
			var bend := Vector3(0.25, 0, 0.1)
			for i in 5:
				mb.cylinder(p, 0.24 - i * 0.025, 0.22 - i * 0.025, 0.95, 6, Color("#a07848").darkened(0.06 * (i % 2)), false, bend * 0.4)
				p += Vector3.UP * 0.95 + bend * 0.4
			for i in 7:
				var a := TAU * i / 7.0
				var d := Vector3(cos(a), 0, sin(a))
				var tip := p + d * 2.4 + Vector3.DOWN * 0.9
				var side := d.cross(Vector3.UP).normalized() * 0.45
				mb.tri(p, p + d * 1.2 + side + Vector3.UP * 0.2, tip, Color("#4fa83a"))
				mb.tri(p, tip, p + d * 1.2 - side + Vector3.UP * 0.2, Color("#3f8f2e"))
			mb.sphere(p + Vector3(0.1, -0.2, 0), Vector3(0.22, 0.22, 0.22), Color("#6a4a2a"), 2, 5)
		"arvore_morta":
			var c := Color("#6a5a4a") * tint
			c.a = 1.0
			mb.cylinder(Vector3.ZERO, 0.3, 0.12, 3.2, 5, c)
			mb.cylinder(Vector3(0, 1.6, 0), 0.12, 0.04, 1.4, 4, c, true, Vector3(0.9, 0, 0.2))
			mb.cylinder(Vector3(0, 2.2, 0), 0.1, 0.03, 1.2, 4, c, true, Vector3(-0.7, 0.2, -0.4))
			mb.cylinder(Vector3(0, 2.7, 0), 0.08, 0.03, 0.9, 4, c, true, Vector3(0.2, 0.2, 0.7))
		"rocha":
			var c := Color("#8a8680") * tint
			c.a = 1.0
			mb.sphere(Vector3(0, 0.55, 0), Vector3(1.1, 0.8, 0.95), c, 3, 6, 0.22, c.darkened(0.15))
			mb.sphere(Vector3(0.8, 0.3, 0.4), Vector3(0.5, 0.4, 0.5), c.lightened(0.06), 2, 5, 0.2)
		"minerio", "carvao_veio", "obsidiana_veio":
			var c := Color("#7a746c")
			var gem := Color("#d07a4a") if key == "minerio" else (Color("#26242a") if key == "carvao_veio" else Color("#5a2a8a"))
			mb.sphere(Vector3(0, 0.6, 0), Vector3(1.1, 0.85, 1.0), c, 3, 6, 0.2, c.darkened(0.2))
			for i in 6:
				var a := TAU * i / 6.0 + v
				mb.box(Vector3(cos(a) * 0.75, 0.55 + (i % 3) * 0.22, sin(a) * 0.7), Vector3(0.32, 0.28, 0.32), gem, a)
		"cristal":
			for i in 5:
				var a := TAU * i / 5.0
				var b := Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.35 if i > 0 else 0.0)
				var off := Vector3(cos(a) * 0.4, 0, sin(a) * 0.4) if i > 0 else Vector3.ZERO
				mb.octa(off + Vector3(0, 0.6, 0), 0.28 if i > 0 else 0.4, 1.2 if i > 0 else 1.8, Color("#7ff0ff") * tint, b)
		"arbusto":
			var g := Color("#4a9a3a") * tint
			g.a = 1.0
			mb.sphere(Vector3(0, 0.45, 0), Vector3(0.8, 0.55, 0.8), g, 3, 6, 0.2)
			mb.sphere(Vector3(0.45, 0.4, 0.2), Vector3(0.5, 0.4, 0.5), g.lightened(0.1), 2, 5, 0.2)
			for i in 6:
				var a := TAU * i / 6.0
				mb.sphere(Vector3(cos(a) * 0.62, 0.55 + (i % 2) * 0.2, sin(a) * 0.55), Vector3(0.11, 0.11, 0.11), Color("#e8344a"), 2, 4)
		"capim":
			var g := Color("#8ac25a") * tint
			g.a = 1.0
			for i in 7:
				var a := TAU * i / 7.0
				var base := Vector3(cos(a) * 0.2, 0, sin(a) * 0.2)
				mb.cone(base, 0.09, 0.9 + (i % 3) * 0.25, 3, g.darkened(0.05 * (i % 3)), Vector3(cos(a) * 0.35, 0, sin(a) * 0.35))
		"cogumelos":
			for i in 3:
				var a := TAU * i / 3.0
				var p := Vector3(cos(a) * 0.35, 0, sin(a) * 0.35)
				var h := 0.35 + i * 0.15
				mb.cylinder(p, 0.07, 0.06, h, 5, Color("#f0e6d0"))
				mb.sphere(p + Vector3(0, h, 0), Vector3(0.28, 0.16, 0.28), Color("#c24d6b"), 2, 6)
		"cacto":
			var g := Color("#4fae5a")
			mb.cylinder(Vector3.ZERO, 0.35, 0.3, 2.2, 7, g)
			mb.sphere(Vector3(0, 2.2, 0), Vector3(0.3, 0.2, 0.3), g, 2, 7)
			mb.cylinder(Vector3(0.3, 0.9, 0), 0.16, 0.14, 0.4, 5, g, true, Vector3(0.35, 0, 0))
			mb.cylinder(Vector3(0.65, 1.2, 0), 0.15, 0.13, 0.6, 5, g)
			mb.cylinder(Vector3(-0.3, 1.3, 0), 0.15, 0.13, 0.35, 5, g, true, Vector3(-0.3, 0, 0))
			mb.cylinder(Vector3(-0.6, 1.55, 0), 0.14, 0.12, 0.5, 5, g)
			mb.sphere(Vector3(0, 2.4, 0), Vector3(0.12, 0.12, 0.12), Color("#ff7ab0"), 2, 5)
		"monte_areia":
			mb.sphere(Vector3(0, 0.1, 0), Vector3(1.2, 0.45, 1.0), Color("#ecd49a"), 3, 7, 0.1)
		"bloco_gelo":
			var c := Color("#bfeaff")
			mb.box(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 1.1), c, 0.3, c.lightened(0.3))
			mb.box(Vector3(0.6, 0.4, 0.5), Vector3(0.7, 0.8, 0.7), c.darkened(0.05), 0.8, c.lightened(0.3))
		"lodo_poca":
			mb.cylinder(Vector3.ZERO, 1.1, 1.0, 0.08, 9, Color("#4a5a2a"))
			mb.sphere(Vector3(0.3, 0.1, 0.2), Vector3(0.18, 0.1, 0.18), Color("#6a7a3a"), 2, 5)
		"ninho_pena":
			mb.cylinder(Vector3.ZERO, 0.7, 0.75, 0.3, 8, Color("#8a6a3a"))
			for i in 3:
				var a := TAU * i / 3.0
				mb.box(Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), Vector3(0.12, 0.5, 0.05), Color("#8fa0ff"), a)
		"espinhos":
			var c := Color("#3a4a2a")
			mb.sphere(Vector3(0, 0.9, 0), Vector3(1.0, 1.0, 0.9), c, 3, 6, 0.25)
			for i in 10:
				var a := TAU * i / 10.0
				var d := Vector3(cos(a), 0.3 * (i % 3) - 0.2, sin(a))
				mb.cone(Vector3(0, 0.9, 0) + d * 0.7, 0.12, 0.7, 3, Color("#6a3a2a"), d * 0.7)
		"muro_gelo":
			var c := Color("#9fdcff")
			mb.box(Vector3(0, 1.6, 0), Vector3(2.2, 3.2, 1.2), c, 0.0, c.lightened(0.3))
			mb.octa(Vector3(0.5, 2.8, 0.2), 0.4, 1.4, Color("#dff6ff"))
			mb.octa(Vector3(-0.6, 2.6, -0.1), 0.35, 1.2, Color("#dff6ff"))
		"porta_solar":
			var st := Color("#c9a060")
			mb.box(Vector3(0, 2.0, 0), Vector3(3.2, 4.0, 0.6), st)
			mb.cylinder(Vector3(0, 2.4, 0.35), 0.7, 0.7, 0.1, 10, Color("#ffd04a"), true)
		"jaula":
			var bar := Color("#5a5a62")
			mb.box(Vector3(0, 0.1, 0), Vector3(2.2, 0.2, 2.2), bar)
			mb.box(Vector3(0, 2.3, 0), Vector3(2.2, 0.2, 2.2), bar)
			for i in 12:
				var a := TAU * i / 12.0
				mb.cylinder(Vector3(cos(a) * 1.0, 0.2, sin(a) * 1.0), 0.05, 0.05, 2.0, 4, bar, false)
		"pilar":
			var c := tint
			mb.sphere(Vector3(0, 1.6, 0), Vector3(1.2, 2.2, 1.2), c, 3, 6, 0.2, c.darkened(0.15))
		"fragmento":
			mb.octa(Vector3(0, 0.8, 0), 0.25, 0.8, Color("#ffb8ff"))
		"berco":
			mb.box(Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 3.0), Color("#c8d0dc"), 0.0, Color("#e8eef6"))
			mb.sphere(Vector3(0, 0.75, 0), Vector3(0.75, 0.45, 1.4), Color("#7ff0ff"), 2, 8)
			mb.box(Vector3(0, 0.1, 1.6), Vector3(1.2, 0.2, 0.4), Color("#5a6a7a"))
		"portal":
			var st := Color("#8a8a96") * tint
			st.a = 1.0
			mb.box(Vector3(-1.6, 1.8, 0), Vector3(0.8, 3.6, 0.8), st)
			mb.box(Vector3(1.6, 1.8, 0), Vector3(0.8, 3.6, 0.8), st)
			mb.box(Vector3(0, 3.9, 0), Vector3(4.2, 0.6, 1.0), st.lightened(0.1))
		"altar":
			mb.cylinder(Vector3.ZERO, 1.6, 1.4, 0.5, 8, Color("#9a96a6"))
			mb.cylinder(Vector3(0, 0.5, 0), 0.6, 0.5, 1.0, 6, Color("#b0acbc"))
		"ponte":
			var w := Color("#b08a5a")
			for i in 12:
				mb.box(Vector3(0, 0, -i * 2.0), Vector3(4.0, 0.3, 1.8), w.darkened(0.05 * (i % 2)))
			for i in 7:
				mb.box(Vector3(-2.1, 0.7, -i * 4.0), Vector3(0.25, 1.4, 0.25), w.darkened(0.2))
				mb.box(Vector3(2.1, 0.7, -i * 4.0), Vector3(0.25, 1.4, 0.25), w.darkened(0.2))
			mb.box(Vector3(-2.1, 1.3, -11.0), Vector3(0.15, 0.15, 24.0), w.lightened(0.1))
			mb.box(Vector3(2.1, 1.3, -11.0), Vector3(0.15, 0.15, 24.0), w.lightened(0.1))
		"barco":
			mb.box(Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 5.0), Color("#8a5a3a"), 0.0, Color("#b08a5a"))
			mb.cylinder(Vector3(0, 0.8, 0), 0.08, 0.08, 3.2, 5, Color("#6a4a2a"))
			mb.tri(Vector3(0, 1.2, 0.1), Vector3(0, 3.8, 0.1), Vector3(0, 1.2, 1.8), Color("#f0e8d8"))
		"casa":
			_house(mb, v, tint)
		"muralha":
			mb.box(Vector3(0, 2.5, 0), Vector3(6.2, 5.0, 1.6), tint, 0.0, tint.lightened(0.1))
			for i in 3:
				mb.box(Vector3(-2.0 + i * 2.0, 5.4, 0), Vector3(1.0, 0.8, 1.6), tint.lightened(0.05))
		"poste":
			mb.cylinder(Vector3.ZERO, 0.1, 0.08, 3.4, 5, Color("#3a3a40"))
			mb.box(Vector3(0, 3.5, 0), Vector3(0.45, 0.5, 0.45), Color("#ffd88a"))
		"caixote":
			mb.box(Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), Color("#9a6a3a"), 0.2, Color("#b08050"))
		"chamine_fabrica":
			mb.cylinder(Vector3.ZERO, 1.2, 0.9, 12.0, 8, Color("#6a4a3a"))
			mb.cylinder(Vector3(0, 12, 0), 1.05, 1.05, 0.6, 8, Color("#3a2a2a"))
		"torre":
			mb.cylinder(Vector3.ZERO, 4.0, 3.0, 16.0, 8, tint)
			mb.cone(Vector3(0, 16, 0), 4.2, 5.0, 8, tint.darkened(0.3))
		"arena":
			for i in 16:
				var a := TAU * i / 16.0
				mb.box(Vector3(cos(a) * 15.0, 0.6, sin(a) * 15.0), Vector3(5.6, 1.2, 1.2), tint, -a + PI / 2)
		_:
			mb.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)


static func _house(mb: MeshBuilder, v: int, tint: Color) -> void:
	var wall: Color = [Color("#c9b18a"), Color("#a8a0a0"), Color("#b88a6a")][v % 3] * tint
	wall.a = 1.0
	var roof: Color = [Color("#8a3a2a"), Color("#4a5a6a"), Color("#6a4a3a")][v % 3]
	mb.box(Vector3(0, 1.75, 0), Vector3(1.0, 3.5, 1.0), wall)
	# telhado em duas águas
	var h := 3.5
	var p := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z)
	mb.quad(p.call(-0.6, h, -0.6), p.call(-0.6, h, 0.6), p.call(0.0, h + 1.2, 0.6), p.call(0.0, h + 1.2, -0.6), roof)
	mb.quad(p.call(0.6, h, 0.6), p.call(0.6, h, -0.6), p.call(0.0, h + 1.2, -0.6), p.call(0.0, h + 1.2, 0.6), roof.darkened(0.1))
	mb.tri(p.call(-0.5, h, 0.5), p.call(0.5, h, 0.5), p.call(0.0, h + 1.1, 0.5), wall.darkened(0.05))
	mb.tri(p.call(0.5, h, -0.5), p.call(-0.5, h, -0.5), p.call(0.0, h + 1.1, -0.5), wall.darkened(0.1))
	# porta e janelas
	mb.box(Vector3(0, 0.6, 0.51), Vector3(0.25, 1.2, 0.02), Color("#5a3a2a"))
	mb.box(Vector3(-0.3, 2.2, 0.51), Vector3(0.18, 0.3, 0.02), Color("#ffe8a0"))
	mb.box(Vector3(0.3, 2.2, 0.51), Vector3(0.18, 0.3, 0.02), Color("#ffe8a0"))
