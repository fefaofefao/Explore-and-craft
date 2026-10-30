class_name MeshLib
extends RefCounted
## Biblioteca de malhas procedurais (árvores, rochas, cristais, estruturas) e materiais compartilhados.
## Tudo é gerado em código: o APK fica leve e o estilo visual é consistente.

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func mat(kind: String = "vc") -> Material:
	if _mats.has(kind):
		return _mats[kind]
	if kind == "foliage" or kind == "foliage_ds":
		var sm := ShaderMaterial.new()
		var sh: Shader = load("res://assets/shaders/foliage.gdshader")
		if kind == "foliage_ds":
			var s2 := Shader.new()
			s2.code = sh.code.replace("cull_back", "cull_disabled")
			sh = s2
		sm.shader = sh
		_mats[kind] = sm
		return sm
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
		"glow_soft":
			m.emission_enabled = true
			m.emission = Color(0.25, 0.55, 0.6)
			m.emission_energy_multiplier = 0.5
			m.rim_enabled = true
			m.rim = 0.4
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
			var leaf := Color("#4f9a3a") * tint
			leaf.a = 1.0
			var hue := mb.rng.randf_range(-0.03, 0.03)
			leaf = Color.from_hsv(fmod(leaf.h + hue + 1.0, 1.0), leaf.s, leaf.v)
			var bark := Color("#6b4a2e")
			mb.sway = 0.0
			mb.tube([Vector3(0, -0.3, 0), Vector3(0, 0.6, 0), Vector3(0.08, 1.6, 0.05), Vector3(-0.05, 2.5, 0.0)], [0.42, 0.3, 0.24, 0.2], 8, bark.darkened(0.15), bark.lightened(0.05))
			mb.tube([Vector3(0, 1.6, 0), Vector3(0.6, 2.3, 0.2), Vector3(1.0, 2.9, 0.3)], [0.13, 0.09, 0.06], 6, bark, bark)
			mb.tube([Vector3(0, 1.9, 0), Vector3(-0.5, 2.6, -0.3), Vector3(-0.8, 3.1, -0.4)], [0.11, 0.08, 0.05], 6, bark, bark)
			mb.sway = 1.0
			var dark := leaf.darkened(0.42)
			var light := leaf.lightened(0.22)
			var lobes := [Vector3(0, 3.3, 0), Vector3(1.0, 3.0, 0.3), Vector3(-0.9, 3.1, -0.4), Vector3(0.2, 3.0, -1.0),
				Vector3(-0.2, 3.0, 1.0), Vector3(0.3, 4.1, 0.1), Vector3(-0.5, 3.8, 0.4)]
			for i in lobes.size():
				var rr := 1.25 if i == 0 else mb.rng.randf_range(0.8, 1.05)
				var lc := light.lerp(Color("#d8f08a"), 0.12) if i >= 5 else light
				mb.blob(lobes[i], Vector3(rr, rr * 0.85, rr), lc, dark, 5, 9, 0.12)
			if v % 3 == 0:
				mb.sway = 0.5
				for i in 7:
					var a := TAU * i / 7.0
					mb.blob(Vector3(cos(a) * 1.55, 2.9 + (i % 2) * 0.5, sin(a) * 1.55), Vector3(0.13, 0.13, 0.13), Color("#ff6a6a"), Color("#c8303a"), 3, 6)
		"pinheiro":
			var g := Color("#2f6e3a") * tint
			g.a = 1.0
			var snow: bool = tint.b > 0.95 and tint.r > 0.95 and tint.g > 0.95
			var bark := Color("#5a3e28")
			mb.sway = 0.0
			mb.tube([Vector3(0, -0.3, 0), Vector3(0, 1.5, 0), Vector3(0, 4.5, 0)], [0.32, 0.22, 0.08], 7, bark.darkened(0.1), bark)
			mb.sway = 0.7
			for i in 5:
				var y := 1.1 + i * 0.95
				var r := 1.9 - i * 0.34
				var top := g.lightened(0.12 + i * 0.04)
				mb.cone_smooth(Vector3(0, y, 0), r, 1.5 - i * 0.08, 10, g.darkened(0.25), top, 0.35)
				if snow:
					mb.cone_smooth(Vector3(0, y + 0.55, 0), r * 0.62, 0.95 - i * 0.05, 10, Color("#e8f2fa"), Color("#ffffff"), 0.15)
		"palmeira":
			var p := Vector3.ZERO
			var bend := Vector3(0.25, 0, 0.1)
			var pts: Array = [Vector3(0, -0.2, 0)]
			var rad: Array = [0.3]
			for i in 6:
				p += Vector3.UP * 0.85 + bend * (0.3 + i * 0.08)
				pts.append(p)
				rad.append(0.24 - i * 0.025)
			mb.sway = 0.0
			mb.tube(pts, rad, 7, Color("#9a7448"), Color("#b89060"))
			for i in 6:
				mb.box(pts[i + 1] - Vector3(0, 0.1, 0), Vector3(0.5 - i * 0.04, 0.08, 0.5 - i * 0.04), Color("#7a5a38"), i * 0.5)
			mb.sway = 1.0
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				var d := Vector3(cos(a), 0, sin(a))
				var side := d.cross(Vector3.UP).normalized()
				var prev := p
				for sgi in 4:
					var t := float(sgi + 1) / 4.0
					var q := p + d * (2.6 * t) + Vector3.DOWN * (1.4 * t * t) + Vector3.UP * 0.35 * sin(t * PI)
					var w := 0.42 * sin(t * PI * 0.9 + 0.3)
					var c0 := Color("#3f8f2e").lerp(Color("#7cc45a"), t)
					mb.quad(prev - side * w * 0.7, prev + side * w * 0.7, q + side * w, q - side * w, c0)
					prev = q
			mb.blob(p + Vector3(0.1, -0.25, 0), Vector3(0.24, 0.24, 0.24), Color("#7a5a3a"), Color("#4a3a2a"), 3, 6)
		"arvore_morta":
			var c := Color("#6a5a4a") * tint
			c.a = 1.0
			mb.sway = 0.0
			mb.tube([Vector3(0, -0.3, 0), Vector3(0.1, 1.2, 0), Vector3(-0.15, 2.4, 0.1), Vector3(0.1, 3.4, 0)], [0.34, 0.24, 0.16, 0.06], 7, c.darkened(0.15), c.lightened(0.1))
			mb.sway = 0.3
			mb.tube([Vector3(0.05, 1.5, 0), Vector3(0.7, 2.1, 0.2), Vector3(1.2, 2.3, 0.3)], [0.1, 0.06, 0.02], 5, c, c)
			mb.tube([Vector3(-0.1, 2.1, 0.05), Vector3(-0.7, 2.6, -0.3), Vector3(-1.0, 3.1, -0.4)], [0.08, 0.05, 0.02], 5, c, c)
			mb.tube([Vector3(0.0, 2.8, 0.05), Vector3(0.3, 3.3, 0.6), Vector3(0.4, 3.6, 0.9)], [0.06, 0.04, 0.02], 5, c, c)
		"decor_flor", "decor_flor_deserto":
			var cols := [Color("#ffe14a"), Color("#ff7ab0"), Color("#ffffff"), Color("#9ab0ff"), Color("#ff9a3a")]
			if key == "decor_flor_deserto":
				cols = [Color("#ff6a8a"), Color("#ffb84a"), Color("#e8e0ff")]
			mb.sway = 0.0
			for f in 3:
				var o := Vector3(mb.rng.randf_range(-0.25, 0.25), 0, mb.rng.randf_range(-0.25, 0.25))
				var hh := mb.rng.randf_range(0.22, 0.4)
				mb.sway = 0.6
				mb.cylinder(o, 0.015, 0.012, hh, 4, Color("#4a8a3a"), false)
				var pc: Color = cols[(v + f) % cols.size()]
				for k in 5:
					var a := TAU * k / 5.0
					var pp := o + Vector3(cos(a) * 0.06, hh, sin(a) * 0.06)
					mb.blob(pp, Vector3(0.055, 0.025, 0.055), pc.lightened(0.15), pc.darkened(0.1), 2, 5)
				mb.blob(o + Vector3(0, hh + 0.01, 0), Vector3(0.035, 0.03, 0.035), Color("#ffd040"), Color("#c89020"), 2, 5)
		"decor_pedrinha":
			mb.sway = 0.0
			var c := Color("#8a867e") * tint
			c.a = 1.0
			for k in 3:
				var o := Vector3(mb.rng.randf_range(-0.3, 0.3), 0.05, mb.rng.randf_range(-0.3, 0.3))
				var r := mb.rng.randf_range(0.08, 0.2)
				mb.sphere(o, Vector3(r, r * 0.6, r * 0.8), c.lightened(mb.rng.randf_range(-0.1, 0.1)), 2, 5, 0.2)
		"decor_samambaia":
			mb.sway = 0.9
			var g := Color("#3f8a3a")
			for k in 7:
				var a := TAU * k / 7.0 + v
				var d := Vector3(cos(a), 0, sin(a))
				var side := d.cross(Vector3.UP).normalized()
				var prev := Vector3.ZERO
				for sgi in 3:
					var t := float(sgi + 1) / 3.0
					var q := d * (0.55 * t) + Vector3.UP * (0.45 * sin(t * PI * 0.7))
					var w := 0.09 * sin(t * PI * 0.9 + 0.2)
					mb.quad(prev - side * w * 0.6, prev + side * w * 0.6, q + side * w, q - side * w, g.lerp(Color("#7cc45a"), t))
					prev = q
		"decor_cogumelo":
			mb.sway = 0.0
			for k in 2 + v % 2:
				var o := Vector3(mb.rng.randf_range(-0.2, 0.2), 0, mb.rng.randf_range(-0.2, 0.2))
				var hh := mb.rng.randf_range(0.12, 0.25)
				mb.cylinder(o, 0.03, 0.025, hh, 5, Color("#f0e6d0"))
				var cc: Color = [Color("#c84a5a"), Color("#e8a040"), Color("#a07ad8")][v]
				mb.blob(o + Vector3(0, hh, 0), Vector3(0.1, 0.06, 0.1), cc.lightened(0.2), cc.darkened(0.2), 3, 6)
		"decor_graveto":
			mb.sway = 0.0
			for k in 3:
				var a := mb.rng.randf() * TAU
				mb.tube([Vector3(0, 0.03, 0), Vector3(cos(a) * 0.4, 0.05, sin(a) * 0.4)], [0.03, 0.015], 4, Color("#8a6a48"), Color("#a08060"))
		"decor_concha":
			mb.sway = 0.0
			var cc: Color = [Color("#ffd8c8"), Color("#ffe8a0"), Color("#e8d8ff")][v]
			mb.sphere(Vector3(0, 0.03, 0), Vector3(0.1, 0.05, 0.12), cc, 2, 6, 0.1)
		"decor_gelinho":
			mb.sway = 0.0
			for k in 3:
				var o := Vector3(mb.rng.randf_range(-0.3, 0.3), 0, mb.rng.randf_range(-0.3, 0.3))
				mb.octa(o, 0.06, mb.rng.randf_range(0.2, 0.4), Color("#cff2ff"))
		"decor_brasinha":
			mb.sway = 0.0
			for k in 3:
				var o := Vector3(mb.rng.randf_range(-0.3, 0.3), 0.04, mb.rng.randf_range(-0.3, 0.3))
				mb.sphere(o, Vector3(0.1, 0.06, 0.1), Color("#2a1a18"), 2, 5, 0.2, null, Color("#ff6a1a"))
		"rocha":
			var c := Color("#8a8680") * tint
			c.a = 1.0
			var moss := Color("#6a9a48") if tint.g >= tint.r else c.lightened(0.15)
			mb.sphere(Vector3(0, 0.55, 0), Vector3(1.15, 0.85, 1.0), c, 4, 7, 0.22, c.darkened(0.2), moss)
			mb.sphere(Vector3(0.85, 0.3, 0.45), Vector3(0.55, 0.42, 0.5), c.lightened(0.06), 3, 6, 0.2, null, moss)
			mb.sphere(Vector3(-0.7, 0.2, -0.5), Vector3(0.35, 0.28, 0.35), c.darkened(0.05), 2, 5, 0.2)
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
			mb.sway = 0.8
			mb.blob(Vector3(0, 0.5, 0), Vector3(0.85, 0.6, 0.85), g.lightened(0.18), g.darkened(0.35), 4, 8, 0.12)
			mb.blob(Vector3(0.5, 0.42, 0.25), Vector3(0.55, 0.45, 0.55), g.lightened(0.25), g.darkened(0.3), 4, 8, 0.12)
			mb.blob(Vector3(-0.45, 0.38, -0.2), Vector3(0.5, 0.4, 0.5), g.lightened(0.1), g.darkened(0.35), 4, 8, 0.12)
			for i in 8:
				var a := TAU * i / 8.0
				mb.blob(Vector3(cos(a) * 0.68, 0.55 + (i % 3) * 0.16, sin(a) * 0.6), Vector3(0.11, 0.11, 0.11), Color("#ff4a5a"), Color("#b8202a"), 3, 6)
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
			# cápsula de sono lumariana: base metálica, casco arredondado, cúpula de vidro e luzes
			mb.box(Vector3(0, 0.18, 0), Vector3(2.1, 0.36, 3.6), Color("#5a6472"), 0.0, Color("#7a8494"))
			mb.blob(Vector3(0, 0.62, 0), Vector3(1.05, 0.5, 1.75), Color("#e8eef6"), Color("#9aa6b6"), 5, 12)
			mb.blob(Vector3(0, 0.98, -0.15), Vector3(0.78, 0.42, 1.3), Color("#bff8ff"), Color("#5fd0e8"), 5, 12)
			for side in [-1, 1]:
				for k in 3:
					mb.box(Vector3(side * 1.02, 0.5, -0.9 + k * 0.9), Vector3(0.08, 0.12, 0.3), Color("#7ff0ff"))
				mb.tube([Vector3(side * 0.9, 0.2, 1.6), Vector3(side * 1.4, 0.05, 2.1), Vector3(side * 1.9, 0.05, 2.0)], [0.08, 0.07, 0.06], 6, Color("#3a3f48"), Color("#4a505a"))
			mb.box(Vector3(0, 0.45, 1.75), Vector3(0.9, 0.5, 0.2), Color("#4a5260"), 0.0, Color("#6a7484"))
			mb.box(Vector3(0, 0.52, 1.86), Vector3(0.5, 0.2, 0.04), Color("#ffd04a"))
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
