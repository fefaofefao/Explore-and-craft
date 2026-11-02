class_name SkillFX
extends RefCounted
## Efeitos dos ataques: cada habilidade tem um estilo ("fx" nos dados) com visual próprio —
## lâminas de folha, bolas de fogo, jatos d'água, estilhaços de gelo, raios do céu, pedras em arco,
## chicotes de vinha, investidas, presas, pancadas sísmicas, garras, nuvens de esporos, espinhos que
## brotam do chão, anéis de fogo, erupções, ondas, nevascas, tempestades, terremotos, pesadelos e
## pilares de luz. Tudo procedural (malhas simples + partículas + tweens) para rodar bem no celular.

const PROJECTILE_STYLES := ["leaf", "fire", "water", "shard", "spark", "rock", "shadow", "light"]
const INSTANT_STYLES := ["bolt", "prism"]
const MELEE_STYLES := ["whip", "rush", "fang", "slam", "claw"]
const AOE_STYLES := ["spores", "forest", "fire_ring", "eruption", "wave", "tidal", "blizzard", "storm", "quake", "nightmare", "judgement"]
const SUPPORT_STYLES := ["bloom", "bubble", "aurora", "charge", "shell"]


static func all_styles() -> Array:
	return PROJECTILE_STYLES + INSTANT_STYLES + MELEE_STYLES + AOE_STYLES + SUPPORT_STYLES


static func anim_for(sk: Dictionary) -> String:
	## Animação do corpo do Eco para cada estilo de ataque.
	var fx: String = sk.get("fx", "")
	match fx:
		"rush":
			return "charge"
		"fang":
			return "bite"
		"slam", "quake", "eruption":
			return "slam"
		"claw", "whip":
			return "spin"
		"bolt", "storm", "judgement", "nightmare", "blizzard", "wave", "tidal", "spores", "forest", "fire_ring":
			return "roar"
		"bloom", "bubble", "aurora", "charge", "shell":
			return "glow"
	return "cast"


static func windup(anim: String) -> float:
	## Tempo até o golpe "acertar" (antecipação da animação).
	match anim:
		"slam":
			return 0.32
		"roar", "glow":
			return 0.28
		"charge", "pounce", "dive":
			return 0.22
		"spin":
			return 0.2
	return 0.16


# ------------------------------------------------------------------ utilidades
static func glow_mat(col: Color, energy: float = 2.5, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


static func solid_mat(col: Color) -> Material:
	return MonsterModel.toon_mat(col, true, 0.0, 0.02)


static func _inst(parent: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	return mi


static func ground_y(w: Node, x: float, z: float, fallback: float) -> float:
	if w != null and "gen" in w and w.gen != null:
		return maxf(w.gen.height(x, z), WorldGen.WATER_Y)
	return fallback


static func _ok(parent: Node) -> bool:
	return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


static func _fade_free(mi: Node3D, mat: StandardMaterial3D, time: float, delay: float = 0.0) -> void:
	var tw := mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.tween_callback(mi.queue_free)


static func particles(parent: Node, pos: Vector3, col: Color, amount: int, life: float, vel: float, grav: Vector3, mesh: Mesh, spread: float = 180.0, dir: Vector3 = Vector3.UP, box: Vector3 = Vector3.ZERO, glow: bool = true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.9
	p.direction = dir
	p.spread = spread
	p.gravity = grav
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.angular_velocity_min = -300
	p.angular_velocity_max = 300
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.mesh = mesh
	p.local_coords = false
	if box != Vector3.ZERO:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = box
	p.material_override = glow_mat(col, 2.0) if glow else solid_mat(col)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.05))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)
	return p


static func shockwave(parent: Node, pos: Vector3, col: Color, radius: float, time: float = 0.45, thick: float = 0.12) -> void:
	if not _ok(parent):
		return
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0 - thick
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	var m := glow_mat(col, 2.2, 0.9)
	var mi := _inst(parent, tm, m, pos + Vector3(0, 0.12, 0))
	mi.scale = Vector3(0.2, 0.6, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.6, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static func flash(parent: Node, pos: Vector3, col: Color, size: float = 1.2, time: float = 0.18) -> void:
	if not _ok(parent):
		return
	var m := glow_mat(col.lightened(0.4), 4.0, 0.9)
	var mi := _inst(parent, MonsterModel._sph(0.5, 10), m, pos)
	mi.scale = Vector3.ONE * size * 0.4
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


static func lightning(parent: Node, from: Vector3, to: Vector3, col: Color, width: float = 0.07, time: float = 0.28) -> void:
	## Raio em zigue-zague (segmentos finos brilhantes) com ramificação.
	if not _ok(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	var m := glow_mat(col.lightened(0.5), 5.0, 1.0)
	var pts: Array = [from]
	var n := 7
	var side := (to - from).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for i in range(1, n):
		var t := float(i) / n
		var p := from.lerp(to, t)
		p += side * randf_range(-0.6, 0.6) * (1.0 - absf(t - 0.5)) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		pts.append(p)
	pts.append(to)
	for i in pts.size() - 1:
		_segment(root, pts[i], pts[i + 1], m, width)
	# galho
	var bi := 2 + randi() % 3
	_segment(root, pts[bi], pts[bi] + side * randf_range(-1.2, 1.2) + Vector3(0, -0.9, 0), m, width * 0.6)
	var tw := root.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_delay(0.06)
	tw.tween_callback(root.queue_free)


static func _segment(root: Node3D, a: Vector3, b: Vector3, m: Material, width: float) -> void:
	var len := a.distance_to(b)
	if len < 0.01:
		return
	var cm := CylinderMesh.new()
	cm.top_radius = width
	cm.bottom_radius = width
	cm.height = len
	cm.radial_segments = 4
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var d := (b - a).normalized()
	mi.look_at(mi.global_position + d, Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2)


static func spike(parent: Node, pos: Vector3, col: Color, h: float, delay: float, glow: bool = false, life: float = 0.9) -> void:
	## Espinho/pedra que brota do chão e afunda de volta.
	if not _ok(parent):
		return
	var mesh := MonsterModel._cone(0.22 * h, h, 5)
	var m: Material = glow_mat(col, 1.5, 1.0) if glow else solid_mat(col)
	var mi := _inst(parent, mesh, m, pos + Vector3(0, -h * 0.6, 0))
	mi.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
	mi.scale = Vector3(1, 0.05, 1)
	var tw := mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(mi, "global_position:y", pos.y + h * 0.35, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_property(mi, "global_position:y", pos.y - h, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func slash(parent: Node, pos: Vector3, facing: Vector3, col: Color, combo: int = 0) -> void:
	## Arco de corte da arma do jogador (varia com o golpe do combo).
	if not _ok(parent):
		return
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 20
	tm.ring_segments = 3
	var m := glow_mat(col, 2.5, 0.85)
	var mi := _inst(parent, tm, m, pos + facing * 0.45)
	var yaw := atan2(-facing.x, -facing.z)
	match combo:
		0:
			mi.rotation = Vector3(0.15, yaw, 0.0)
		1:
			mi.rotation = Vector3(-0.2, yaw, 0.5)
		_:
			mi.rotation = Vector3(0.0, yaw, PI / 2)
	mi.scale = Vector3(0.5, 0.3, 0.5)
	var big := 1.25 if combo < 2 else 1.6
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(big, 0.3, big), 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", yaw + (1.2 if combo != 1 else -1.2), 0.16)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2).set_delay(0.04)
	tw.chain().tween_callback(mi.queue_free)


# ------------------------------------------------------------------ projéteis
static func projectile_body(p: Node3D, style: String, col: Color) -> void:
	## Monta a aparência de um projétil (filho de Projectile) conforme o estilo.
	match style:
		"leaf":
			for i in 3:
				var q := QuadMesh.new()
				q.size = Vector2(0.42, 0.16)
				var mi := MeshInstance3D.new()
				mi.mesh = q
				mi.material_override = glow_mat(col.lightened(0.15), 1.2)
				mi.rotation = Vector3(PI / 2, TAU * i / 3.0, 0)
				mi.position = Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0)) * 0.12
				p.add_child(mi)
		"fire":
			var core := MeshInstance3D.new()
			core.mesh = MonsterModel._sph(0.24, 10)
			core.material_override = glow_mat(Color("#ffe08a"), 4.0)
			p.add_child(core)
			var shell := MeshInstance3D.new()
			shell.mesh = MonsterModel._sph(0.36, 10)
			shell.material_override = glow_mat(col, 2.5, 0.55)
			p.add_child(shell)
		"water":
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(0.2, 10)
			mi.scale = Vector3(1, 1, 2.2)
			mi.material_override = glow_mat(col.lightened(0.3), 1.6, 0.85)
			p.add_child(mi)
		"shard":
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._cone(0.13, 0.7, 4)
			mi.rotation.x = -PI / 2
			mi.material_override = glow_mat(col.lightened(0.45), 2.0, 0.9)
			p.add_child(mi)
		"spark":
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(0.16, 6)
			mi.material_override = glow_mat(Color("#fff6a0"), 5.0)
			p.add_child(mi)
		"rock":
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(0.3, 5)
			mi.scale = Vector3(1.1, 0.85, 1.0)
			mi.material_override = solid_mat(Color("#8a7458"))
			p.add_child(mi)
		"shadow":
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(0.3, 10)
			mi.material_override = glow_mat(Color("#1a0f2a"), 0.3, 0.95)
			p.add_child(mi)
			var halo := MeshInstance3D.new()
			halo.mesh = MonsterModel.ring_mesh(0.32, 0.4)
			halo.material_override = glow_mat(col, 3.0, 0.9)
			p.add_child(halo)
		"light":
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(0.1, 6)
			mi.scale = Vector3(1, 1, 5.0)
			mi.material_override = glow_mat(Color("#fffbe0"), 5.0)
			p.add_child(mi)
		_:
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(0.22, 8)
			mi.material_override = glow_mat(col, 3.0)
			p.add_child(mi)


static func projectile_hit(parent: Node, pos: Vector3, style: String, col: Color) -> void:
	if not _ok(parent):
		return
	match style:
		"leaf":
			particles(parent, pos, col, 14, 0.8, 4.0, Vector3(0, -3, 0), _leaf_mesh(), 180.0, Vector3.UP, Vector3.ZERO, false)
		"fire":
			flash(parent, pos, Color("#ffb02a"), 1.6)
			particles(parent, pos, col, 18, 0.6, 5.0, Vector3(0, 2, 0), MonsterModel._sph(0.12, 6))
			particles(parent, pos, Color("#3a3030"), 6, 1.0, 1.5, Vector3(0, 1.5, 0), MonsterModel._sph(0.2, 6), 60.0, Vector3.UP, Vector3.ZERO, false)
		"water":
			particles(parent, pos, col.lightened(0.3), 22, 0.7, 5.5, Vector3(0, -12, 0), MonsterModel._sph(0.09, 6), 60.0)
			shockwave(parent, pos - Vector3(0, 0.6, 0), col.lightened(0.4), 1.6, 0.35)
		"shard":
			particles(parent, pos, col.lightened(0.5), 16, 0.6, 5.0, Vector3(0, -9, 0), MonsterModel._box(Vector3(0.08, 0.16, 0.08)))
			flash(parent, pos, Color("#dff6ff"), 1.0)
		"spark":
			for i in 3:
				lightning(parent, pos, pos + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)), Color("#fff07a"), 0.03, 0.15)
			flash(parent, pos, Color("#fff6a0"), 1.2)
		"rock":
			particles(parent, pos, Color("#8a7458"), 14, 0.8, 4.5, Vector3(0, -14, 0), MonsterModel._box(Vector3(0.14, 0.14, 0.14)), 80.0, Vector3.UP, Vector3.ZERO, false)
			particles(parent, pos, Color("#c8b48a"), 8, 0.9, 2.0, Vector3(0, 0.5, 0), MonsterModel._sph(0.22, 6), 90.0, Vector3.UP, Vector3.ZERO, false)
		"shadow":
			var m := glow_mat(Color("#6a2aa8"), 2.0, 0.8)
			var mi := _inst(parent, MonsterModel._sph(0.5, 12), m, pos)
			var tw := mi.create_tween().set_parallel(true)
			tw.tween_property(mi, "scale", Vector3.ONE * 2.4, 0.15)
			tw.chain().tween_property(mi, "scale", Vector3.ONE * 0.1, 0.22).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.25)
			tw.chain().tween_callback(mi.queue_free)
		"light":
			flash(parent, pos, Color("#fffbe0"), 1.8, 0.22)
			particles(parent, pos, Color("#fff4b0"), 14, 0.6, 4.0, Vector3.ZERO, MonsterModel._sph(0.07, 6))
		_:
			FX.burst(parent, pos, col, 12, 4.0, false, true, 0.5)


static var _leaf: Mesh


static func _leaf_mesh() -> Mesh:
	if _leaf == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.1)
		_leaf = q
	return _leaf


# ------------------------------------------------------------------ disparos instantâneos
static func bolt_strike(parent: Node, at: Vector3, col: Color) -> void:
	## Raio que cai do céu no alvo.
	lightning(parent, at + Vector3(randf_range(-1.5, 1.5), 14.0, randf_range(-1.5, 1.5)), at, Color("#fff6a0"), 0.1, 0.32)
	flash(parent, at, Color("#fff6a0"), 2.4, 0.22)
	shockwave(parent, at - Vector3(0, 0.8, 0), col, 2.2, 0.35)
	particles(parent, at, Color("#fff07a"), 16, 0.5, 6.0, Vector3(0, -8, 0), MonsterModel._box(Vector3(0.05, 0.05, 0.2)))


static func prism_beam(parent: Node, from: Vector3, to: Vector3) -> void:
	## Feixe prismático: núcleo branco e camadas coloridas que se abrem e somem.
	if not _ok(parent):
		return
	var cols := [Color("#ff6a8a"), Color("#ffe06a"), Color("#6affc8"), Color("#6ab0ff")]
	for i in cols.size():
		var off := Vector3(0, 0.08, 0).rotated((to - from).normalized() if (to - from).length() > 0.1 else Vector3.FORWARD, TAU * i / cols.size())
		FX.beam(parent, from + off, to + off, cols[i], 0.35)
	FX.beam(parent, from, to, Color.WHITE, 0.25)
	flash(parent, to, Color("#fffbe0"), 1.8)


# ------------------------------------------------------------------ corpo a corpo
static func whip(parent: Node, from: Vector3, to: Vector3, col: Color) -> void:
	## Chicote de vinha: corrente de gomos que se estica em curva até o alvo e recolhe.
	if not _ok(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	var m := solid_mat(col.darkened(0.1))
	var n := 10
	var side := (to - from).cross(Vector3.UP).normalized()
	for i in n:
		var t := float(i + 1) / n
		var p := from.lerp(to, t) + side * sin(t * PI) * 0.9 + Vector3(0, sin(t * PI) * 0.6, 0)
		var mi := _inst(root, MonsterModel._sph(0.11 - t * 0.04, 6), m, from)
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", p, 0.08 + t * 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.12)
		tw.tween_property(mi, "global_position", from, 0.15).set_ease(Tween.EASE_IN)
	root.get_tree().create_timer(0.6).timeout.connect(root.queue_free)
	particles(parent, to, col, 10, 0.6, 3.5, Vector3(0, -6, 0), _leaf_mesh(), 180.0, Vector3.UP, Vector3.ZERO, false)


static func rush_trail(parent: Node, actor: Node3D, col: Color) -> void:
	## Rastro de investida: partículas presas ao corpo do Eco durante o avanço.
	if not _ok(parent) or actor == null:
		return
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.45
	p.local_coords = false
	p.mesh = MonsterModel._sph(0.16, 6)
	p.material_override = glow_mat(col, 2.5, 0.85)
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_max = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	actor.add_child(p)
	p.position = Vector3(0, 0.5, 0)
	p.get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false)
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


static func fang(parent: Node, at: Vector3, col: Color) -> void:
	## Duas mandíbulas de energia que se fecham no alvo.
	if not _ok(parent):
		return
	for side in [-1.0, 1.0]:
		var m := glow_mat(col.lightened(0.3), 2.5, 0.95)
		var mi := _inst(parent, MonsterModel._cone(0.12, 0.6, 4), m, at + Vector3(0, side * 0.7, 0))
		mi.rotation = Vector3(0, 0, PI if side > 0 else 0.0)
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", at + Vector3(0, side * 0.12, 0), 0.1).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
		tw.tween_callback(mi.queue_free)
	parent.get_tree().create_timer(0.1).timeout.connect(func():
		if _ok(parent):
			particles(parent, at, col.lightened(0.5), 14, 0.5, 4.0, Vector3(0, -8, 0), MonsterModel._box(Vector3(0.07, 0.14, 0.07))))


static func claw(parent: Node, at: Vector3, col: Color) -> void:
	## Três rasgos diagonais paralelos.
	if not _ok(parent):
		return
	for i in 3:
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 1.5)
		var m := glow_mat(col.lightened(0.25), 3.0, 0.95)
		var mi := _inst(parent, q, m, at + Vector3((i - 1) * 0.28, 0, 0))
		mi.rotation = Vector3(0, 0, 0.7)
		var cam := parent.get_viewport().get_camera_3d() if parent.get_viewport() != null else null
		if cam != null:
			mi.look_at(cam.global_position, Vector3.UP)
			mi.rotate_object_local(Vector3.FORWARD, 0.7)
			mi.global_position = at + mi.global_basis.x * (i - 1) * 0.26
		mi.scale = Vector3(1, 0.05, 1)
		var tw := mi.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.07)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
		tw.tween_callback(mi.queue_free)


static func slam(parent: Node, at: Vector3, col: Color, w: Node) -> void:
	## Pancada sísmica: onda de choque, pedras saltando e poeira.
	shockwave(parent, at, col.lightened(0.2), 3.2, 0.4, 0.2)
	for i in 6:
		var a := TAU * i / 6.0 + randf() * 0.4
		var p := at + Vector3(cos(a), 0, sin(a)) * randf_range(0.9, 1.8)
		p.y = ground_y(w, p.x, p.z, at.y)
		spike(parent, p, Color("#7a6a58"), randf_range(0.5, 0.9), randf() * 0.08, false, 0.4)
	particles(parent, at + Vector3(0, 0.3, 0), Color("#c8b48a"), 12, 0.9, 3.0, Vector3(0, 0.6, 0), MonsterModel._sph(0.25, 6), 80.0, Vector3.UP, Vector3(0.8, 0.1, 0.8), false)


# ------------------------------------------------------------------ área
static func aoe(parent: Node, style: String, center: Vector3, radius: float, col: Color, w: Node, victims: Array) -> void:
	if not _ok(parent):
		return
	match style:
		"spores":
			for i in 14:
				var a := randf() * TAU
				var d := randf() * radius * 0.8
				var p := center + Vector3(cos(a) * d, randf_range(0.3, 1.6), sin(a) * d)
				var m := glow_mat(col.lerp(Color("#d8a8ff"), randf() * 0.5), 1.0, 0.55)
				var mi := _inst(parent, MonsterModel._sph(0.5, 8), m, center + Vector3(0, 0.6, 0))
				mi.scale = Vector3.ONE * 0.2
				var tw := mi.create_tween().set_parallel(true)
				tw.tween_property(mi, "global_position", p, 0.6).set_ease(Tween.EASE_OUT)
				tw.tween_property(mi, "scale", Vector3.ONE * randf_range(1.2, 2.2), 0.8)
				tw.tween_property(m, "albedo_color:a", 0.0, 0.7).set_delay(0.6)
				tw.chain().tween_callback(mi.queue_free)
		"forest":
			# espinhos/raízes brotam em anéis, de dentro para fora
			for ring in 3:
				var rr := radius * (0.35 + ring * 0.3)
				var n := 6 + ring * 4
				for i in n:
					var a := TAU * i / n + ring * 0.3
					var p := center + Vector3(cos(a), 0, sin(a)) * rr
					p.y = ground_y(w, p.x, p.z, center.y)
					spike(parent, p, col.darkened(0.2) if i % 2 == 0 else Color("#6a4a2a"), randf_range(0.8, 1.4), ring * 0.12, false, 0.5)
			particles(parent, center + Vector3(0, 0.5, 0), col, 24, 1.2, 6.0, Vector3(0, -3, 0), _leaf_mesh(), 70.0, Vector3.UP, Vector3.ZERO, false)
		"fire_ring":
			shockwave(parent, center, Color("#ffb02a"), radius, 0.55, 0.25)
			for i in 12:
				var a := TAU * i / 12.0
				var p := center + Vector3(cos(a), 0, sin(a)) * radius * 0.75
				p.y = ground_y(w, p.x, p.z, center.y)
				particles(parent, p, col, 6, 0.7, 3.0, Vector3(0, 3, 0), MonsterModel._sph(0.16, 6), 20.0)
		"eruption":
			for i in 6:
				var a := randf() * TAU
				var d := randf_range(0.3, 1.0) * radius
				var p := center + Vector3(cos(a), 0, sin(a)) * d
				p.y = ground_y(w, p.x, p.z, center.y)
				_geyser(parent, p, col, i * 0.08)
			for v in victims:
				if is_instance_valid(v):
					_geyser(parent, (v as Node3D).global_position, col, 0.05)
		"wave", "tidal":
			var m := glow_mat(col.lightened(0.35), 1.2, 0.75)
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 1.05
			cm.height = 1.0
			cm.radial_segments = 24
			cm.cap_top = false
			cm.cap_bottom = false
			var mi := _inst(parent, cm, m, center + Vector3(0, 0.4, 0))
			mi.scale = Vector3(0.3, 0.2, 0.3)
			var tw := mi.create_tween().set_parallel(true)
			tw.tween_property(mi, "scale", Vector3(radius, 1.4, radius), 0.55).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "scale:y", 0.1, 0.3).set_delay(0.4)
			tw.tween_property(m, "albedo_color:a", 0.0, 0.3).set_delay(0.45)
			tw.chain().tween_callback(mi.queue_free)
			particles(parent, center + Vector3(0, 0.6, 0), col.lightened(0.5), 30, 0.9, 7.0, Vector3(0, -10, 0), MonsterModel._sph(0.1, 6), 80.0)
		"blizzard":
			var p := CPUParticles3D.new()
			p.amount = 70
			p.lifetime = 1.4
			p.one_shot = true
			p.explosiveness = 0.5
			p.local_coords = false
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = radius * 0.8
			p.gravity = Vector3(0, -2, 0)
			p.tangential_accel_min = 14.0
			p.tangential_accel_max = 22.0
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.mesh = MonsterModel._sph(0.09, 4)
			p.material_override = glow_mat(Color("#eaf8ff"), 1.5)
			parent.add_child(p)
			p.global_position = center + Vector3(0, 1.0, 0)
			p.emitting = true
			p.get_tree().create_timer(2.0).timeout.connect(p.queue_free)
			for v in victims:
				if is_instance_valid(v):
					projectile_hit(parent, (v as Node3D).global_position + Vector3(0, 0.8, 0), "shard", col)
			shockwave(parent, center, Color("#cfefff"), radius, 0.7, 0.08)
		"storm":
			var targets: Array = []
			for v in victims:
				if is_instance_valid(v):
					targets.append((v as Node3D).global_position + Vector3(0, 0.6, 0))
			for i in 4:
				var a := randf() * TAU
				var p := center + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, radius)
				p.y = ground_y(w, p.x, p.z, center.y)
				targets.append(p)
			for i in targets.size():
				var at: Vector3 = targets[i]
				parent.get_tree().create_timer(i * 0.09).timeout.connect(func():
					if _ok(parent):
						bolt_strike(parent, at, col))
		"quake":
			shockwave(parent, center, Color("#c8a878"), radius, 0.6, 0.3)
			for i in 10:
				var a := TAU * i / 10.0
				var d := randf_range(0.4, 1.0) * radius
				var p := center + Vector3(cos(a), 0, sin(a)) * d
				p.y = ground_y(w, p.x, p.z, center.y)
				spike(parent, p, Color("#7a6a58"), randf_range(0.9, 1.6), d / radius * 0.25, false, 0.6)
			particles(parent, center + Vector3(0, 0.3, 0), Color("#c8b48a"), 26, 1.2, 3.0, Vector3(0, 0.4, 0), MonsterModel._sph(0.3, 6), 90.0, Vector3.UP, Vector3(radius * 0.6, 0.1, radius * 0.6), false)
		"nightmare":
			var m := glow_mat(Color("#1a0f2a"), 0.2, 0.75)
			var mi := _inst(parent, MonsterModel._sph(1.0, 16), m, center + Vector3(0, 0.5, 0))
			mi.scale = Vector3.ONE * 0.3
			var tw := mi.create_tween()
			tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.45).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.25).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.25)
			tw.tween_callback(mi.queue_free)
			shockwave(parent, center, Color("#a05aff"), radius, 0.5, 0.15)
			for v in victims:
				if is_instance_valid(v):
					projectile_hit(parent, (v as Node3D).global_position + Vector3(0, 0.8, 0), "shadow", col)
		"judgement":
			flash(parent, center + Vector3(0, 1.0, 0), Color("#fffbe0"), 3.0, 0.3)
			var spots: Array = []
			for v in victims:
				if is_instance_valid(v):
					spots.append((v as Node3D).global_position)
			for i in 3:
				var a := TAU * i / 3.0
				spots.append(center + Vector3(cos(a), 0, sin(a)) * radius * 0.6)
			for p in spots:
				_pillar(parent, p, Color("#fff4b0"))
		_:
			FX.ring(parent, center, col, radius, 0.5)
			FX.burst(parent, center + Vector3(0, 0.5, 0), col, 26, 6.0, false, true, 0.9)


static func _geyser(parent: Node, at: Vector3, col: Color, delay: float) -> void:
	if not _ok(parent):
		return
	parent.get_tree().create_timer(delay).timeout.connect(func():
		if not _ok(parent):
			return
		var m := glow_mat(Color("#ffb02a"), 3.0, 0.9)
		var mi := _inst(parent, MonsterModel._cyl(0.35, 0.55, 1.0), m, at)
		mi.scale = Vector3(1, 0.05, 1)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1, 3.2, 1), 0.15).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "global_position:y", at.y + 1.6, 0.15)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
		tw.tween_callback(mi.queue_free)
		particles(parent, at + Vector3(0, 0.5, 0), col, 12, 1.0, 8.0, Vector3(0, -14, 0), MonsterModel._box(Vector3(0.15, 0.15, 0.15)), 25.0))


static func _pillar(parent: Node, at: Vector3, col: Color) -> void:
	if not _ok(parent):
		return
	var m := glow_mat(col, 3.5, 0.85)
	var mi := _inst(parent, MonsterModel._cyl(0.6, 0.6, 16.0), m, at + Vector3(0, 8.0, 0))
	mi.scale = Vector3(0.05, 1, 0.05)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.05, 1, 0.05), 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mi.queue_free)
	shockwave(parent, at, col, 1.8, 0.4)


# ------------------------------------------------------------------ suporte (cura/bônus)
static func support(parent: Node, style: String, actor: Node3D, col: Color) -> void:
	if not _ok(parent) or actor == null or not is_instance_valid(actor):
		return
	var at := actor.global_position
	match style:
		"bloom":
			for i in 8:
				var a := TAU * i / 8.0
				var p := at + Vector3(cos(a) * 0.9, 0.05, sin(a) * 0.9)
				p.y = ground_y(parent, p.x, p.z, at.y) + 0.05
				var m := glow_mat(Color("#ffd0e8") if i % 2 == 0 else Color("#fff4a0"), 1.5, 1.0)
				var mi := _inst(parent, MonsterModel._sph(0.14, 6), m, p)
				mi.scale = Vector3(1, 0.4, 1) * 0.1
				var tw := mi.create_tween()
				tw.tween_property(mi, "scale", Vector3(1, 0.4, 1), 0.25).set_delay(i * 0.03)
				tw.tween_property(mi, "global_position:y", p.y + 1.6, 0.6)
				tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.6)
				tw.tween_callback(mi.queue_free)
			particles(parent, at + Vector3(0, 0.3, 0), Color("#a8ffa0"), 16, 1.2, 1.5, Vector3(0, 2.5, 0), MonsterModel._sph(0.07, 6), 30.0)
		"bubble":
			var m := glow_mat(col.lightened(0.5), 0.8, 0.4)
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(1.0, 16)
			mi.material_override = m
			actor.add_child(mi)
			mi.position = Vector3(0, 0.6, 0)
			mi.scale = Vector3.ONE * 0.2
			var tw := mi.create_tween()
			tw.tween_property(mi, "scale", Vector3.ONE * 1.1, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_interval(0.5)
			tw.tween_property(mi, "scale", Vector3.ONE * 1.4, 0.15)
			tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.15)
			tw.tween_callback(mi.queue_free)
			particles(parent, at + Vector3(0, 0.5, 0), col.lightened(0.5), 14, 1.0, 2.0, Vector3(0, 2, 0), MonsterModel._sph(0.08, 6))
		"aurora":
			_pillar(parent, at, Color("#fff4b0"))
			particles(parent, at + Vector3(0, 0.3, 0), Color("#b0fff0"), 24, 1.4, 2.0, Vector3(0, 2, 0), MonsterModel._sph(0.07, 6), 40.0, Vector3.UP, Vector3(0.8, 0.1, 0.8))
		"charge":
			for i in 4:
				parent.get_tree().create_timer(i * 0.1).timeout.connect(func():
					if _ok(parent) and is_instance_valid(actor):
						var c := actor.global_position + Vector3(0, 0.8, 0)
						lightning(parent, c + Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 1.0), randf_range(-0.8, 0.8)), c, Color("#fff07a"), 0.035, 0.12))
			shockwave(parent, at, Color("#fff07a"), 2.2, 0.4)
		"shell":
			var m := glow_mat(Color("#c8a878"), 1.0, 0.6)
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterModel._sph(1.0, 6)
			mi.material_override = m
			actor.add_child(mi)
			mi.position = Vector3(0, 0.5, 0)
			mi.scale = Vector3.ONE * 1.4
			var tw := mi.create_tween()
			tw.tween_property(mi, "scale", Vector3.ONE * 0.95, 0.2).set_ease(Tween.EASE_IN)
			tw.tween_property(m, "albedo_color:a", 0.0, 0.5).set_delay(0.3)
			tw.tween_callback(mi.queue_free)
			shockwave(parent, at, Color("#c8a878"), 1.6, 0.3)
		_:
			FX.ring(parent, at, col, 2.0, 0.5)
