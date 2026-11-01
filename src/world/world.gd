class_name World
extends Node3D
## Um mapa jogável: gera o cenário, controla Ecos, combate, captura, coleta, construção,
## interações, chefes, batalhas contra capitães/ditadores, jaulas, fragmentos e viagens.

signal travel_requested(map_id: String)
signal quit_to_title

var map_id: String
var md: Dictionary
var gen: WorldGen
var sky: SkyEnv
var player: Player
var rig: CameraRig
var hud: Node  # Hud
var ally: MonsterActor = null
var wilds: Array = []
var nodes: Dictionary = {}  # key -> ResourceNode
var structures: Dictionary = {}  # uid -> Structure
var interactables: Array = []
var npcs: Array = []
var boss: MonsterActor = null
var lair: Dictionary = {}
var trainer_enemy: MonsterActor = null
var battle := {}  # {"tid", "queue": [[sp,lvl]], "npc"}
var selected_orb := "esfera"
var auto_skill_on := true
var build_mode := false
var ghost: Node3D
var ghost_id := ""
var ghost_rot := 0
var ghost_ok := false
var current_target: Node = null
var _focus: MonsterActor = null
var _scan_t := 0.0
var _spawn_t := 0.0
var _work_t := 0.0
var _heal_t := 0.0
var _hazard_warned := false
var _night_warned := false
var _ally_respawn_t := -1.0
var _props: Node3D
var _actors: Node3D
var _structs: Node3D
var _particles: CPUParticles3D
var _boss_spawned := false
var _capturing := false
var rng := RandomNumberGenerator.new()


# ================================================================== construção do mapa
func build(p_map: String, p_hud: Node) -> void:
	map_id = p_map
	md = GameData.db().maps[map_id]
	hud = p_hud
	rng.randomize()
	var st: GameState = Game.state
	var q := Game.quality()
	gen = WorldGen.new(map_id)
	sky = SkyEnv.new()
	add_child(sky)
	sky.setup(md["biome"], q)
	sky.update_time(st.day_time)
	add_child(TerrainBuilder.build_terrain(gen))
	add_child(TerrainBuilder.build_water(gen))
	var grass := TerrainBuilder.build_grass(gen, q)
	add_child(grass)
	sky.grass_mat = grass.get_meta("mat") if grass.has_meta("mat") else null
	add_child(TerrainBuilder.build_decor(gen, q))
	sky.update_time(st.day_time)
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_structs = Node3D.new()
	_structs.name = "Structures"
	add_child(_structs)
	_actors = Node3D.new()
	_actors.name = "Actors"
	add_child(_actors)
	_build_nodes()
	_build_pois()
	if md.get("city") != null:
		_build_city()
	for b in st.buildings_on(map_id):
		_spawn_structure(b)
	_build_requirement_labels()
	# câmera, controles e jogador
	rig = CameraRig.new()
	add_child(rig)
	rig.sens = float(Game.settings.get("cam_sens", 1.0))
	player = Player.new()
	_actors.add_child(player)
	player.setup(gen, rig, hud.controls)
	player.died.connect(_on_player_died)
	player.deep_water.connect(func(): hud.lume_hint(Loc.t("deep_water"), 4.0))
	var p := _initial_player_pos()
	player.global_position = p
	rig.target = player
	rig.yaw = PI if p.z < 0 else 0.0
	rig.snap()
	_update_held()
	_spawn_ally()
	for i in int(md["spawn_count"]):
		_spawn_wild(true)
	_build_ambient_particles(q)
	st.map_id = map_id
	var ms := st.map_state(map_id)
	if not ms["visited"]:
		ms["visited"] = true
		Firebase.log_event("map_enter", {"map": map_id, "first": true})
	Game.current_world = self
	Game.check_quests()
	Audio.play_music(md["biome"]["music"])


func _initial_player_pos() -> Vector3:
	var st: GameState = Game.state
	if st.has_pos and st.map_id == map_id:
		var sp := st.pos
		return Vector3(sp.x, gen.height(sp.x, sp.z) + 0.6, sp.z)
	var s: Array = md["spawn"]
	return Vector3(s[0], gen.height(s[0], s[1]) + 0.6, s[1])


func _build_nodes() -> void:
	var st: GameState = Game.state
	var ms := st.map_state(map_id)
	var biome_tint := Color.WHITE
	if map_id == "m3":
		biome_tint = Color(1, 1, 1)
	var tints := {"m2": Color("#e8d8a0"), "m5": Color("#8a9a70"), "m6": Color("#6a5a50"), "m7": Color("#a0c8a0"), "m8": Color("#8a8090")}
	for pl in gen.node_placements():
		var tint: Color = tints.get(map_id, Color.WHITE)
		if pl["kind"] == "pinheiro" and map_id == "m3":
			tint = Color(1, 1, 1)
		elif pl["kind"] == "pinheiro":
			tint = Color(0.95, 1.0, 0.95)
		var n := ResourceNode.new().setup(pl["key"], pl["kind"], tint, pl["scale"], pl["rot"])
		_props.add_child(n)
		n.global_position = pl["pos"]
		nodes[pl["key"]] = n
		var until := int(ms["harvested"].get(pl["key"], 0))
		if until > Game.now():
			n.set_harvested(true)
		elif until > 0:
			ms["harvested"].erase(pl["key"])


func _build_pois() -> void:
	var st: GameState = Game.state
	var ms := st.map_state(map_id)
	# Berço (início)
	if md.has("cradle"):
		var c: Array = md["cradle"]
		var cr := Interactable.new().setup("cradle", {}, Loc.t("cradle"), 4.0)
		_props.add_child(cr)
		cr.global_position = Vector3(c[0], gen.height(c[0], c[1]), c[1])
		cr.add_mesh("berco", "glow_soft", Color.WHITE, 1.3, false, Vector3(2.4, 1.2, 4.6))
		cr.add_light(Color("#7ff0ff"), 1.2, 6.0, 1.0)
		interactables.append(cr)
		if not st.flags.get("starter_chosen", false):
			_spawn_starter_display(cr.global_position)
	# covil do chefe
	lair = gen.lair_layout()
	if not lair.is_empty():
		var rock_tint := Color(md["biome"]["rock"])
		for i in lair["pillars"].size():
			var pp: Vector3 = lair["pillars"][i]
			var pi := MeshInstance3D.new()
			var kind := "pilar" if not lair["temple"] else "pilar"
			pi.mesh = MeshLib.get_mesh(kind, i % 3, rock_tint if not lair["temple"] else Color("#d8b070"))
			pi.material_override = MeshLib.mat("vc")
			pi.position = pp
			pi.rotation.y = i * 1.3
			pi.scale = Vector3(1.0, 1.0 + (i % 3) * 0.25, 1.0)
			_props.add_child(pi)
			var b := StaticBody3D.new()
			b.collision_layer = 2
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 1.3
			cy.height = 5.0
			cs.shape = cy
			cs.position.y = 2.0
			b.add_child(cs)
			b.position = pp
			_props.add_child(b)
		for bar in lair["barriers"]:
			if bar["key"] in ms["barriers"]:
				continue
			var n := ResourceNode.new().setup(bar["key"], bar["kind"], Color.WHITE, 1.0, 0.0)
			_props.add_child(n)
			n.global_position = bar["pos"]
			var to_c: Vector3 = lair["center"] - bar["pos"]
			n.rotation.y = atan2(to_c.x, to_c.z)
			nodes[bar["key"]] = n
		# brilho no centro do covil
		var glow := OmniLight3D.new()
		glow.light_color = Color(md["biome"]["sky_horizon"])
		glow.light_energy = 1.0
		glow.omni_range = 12.0
		glow.position = lair["center"] + Vector3(0, 3, 0)
		_props.add_child(glow)
	# portais
	for p in md["portals"]:
		var pos := Vector3(p["pos"][0], 0, p["pos"][1])
		pos.y = maxf(gen.height(pos.x, pos.z), 0.6)
		var it := Interactable.new().setup("portal", p, Loc.t("travel_to", [Loc.tx(p["label"])]), 4.5)
		_props.add_child(it)
		it.global_position = pos
		var locked: bool = p.has("requires_flag") and not st.flags.get(p["requires_flag"], false) and not st.is_sandbox()
		if p.get("bridge", false) and map_id == "m1":
			if not locked:
				var br := MeshInstance3D.new()
				br.mesh = MeshLib.get_mesh("ponte")
				br.material_override = MeshLib.mat("vc")
				br.material_override = MeshLib.mat("vc")
				_props.add_child(br)
				br.global_position = Vector3(0, 1.0, -96)
				_add_bridge_collision(Vector3(0, 1.0, -96))
				it.add_mesh("portal", "vc", Color("#c8b8ff"), 1.0)
				it.add_light(Color("#c8b8ff"), 2.0, 8.0, 2.0)
				it.global_position = Vector3(0, 1.0, -116)
			interactables.append(it)
			continue
		if p.get("ferry", false):
			var boat := MeshInstance3D.new()
			boat.mesh = MeshLib.get_mesh("barco")
			boat.material_override = MeshLib.mat("vc_ds")
			_props.add_child(boat)
			var dir := Vector3(pos.x, 0, pos.z).normalized()
			boat.global_position = pos + dir * 4.0 + Vector3(0, -0.3 - pos.y, 0)
			boat.rotation.y = atan2(dir.x, dir.z)
		else:
			it.add_mesh("portal", "vc", Color("#9a96a6") if not locked else Color("#5a5660"), 1.0, false)
			if not locked:
				it.add_light(Color("#9ff0ff"), 1.6, 7.0, 2.0)
				_add_portal_swirl(it)
		interactables.append(it)
	# altar da ponte (m1)
	if map_id == "m1":
		var bp: Array = md["pois"]["bridge"]["pos"]
		var alt := Interactable.new().setup("altar", {"flag": "bridge_built", "item": "nucleo_ponte"}, Loc.t("bridge_altar"), 4.0)
		_props.add_child(alt)
		alt.global_position = Vector3(bp[0], gen.height(bp[0], bp[1]), bp[1] + 8)
		alt.add_mesh("altar", "vc", Color.WHITE, 1.0, false, Vector3(3.0, 1.4, 3.0))
		alt.add_light(Color("#ff9aff"), 1.5 if st.flags.get("bridge_built", false) else 0.6, 6.0, 2.0)
		interactables.append(alt)
	# fragmentos de memória
	var found: Array = ms["fragments"]
	for f in gen.fragment_positions():
		if f["id"] in found:
			continue
		var fr := Interactable.new().setup("fragment", {"id": f["id"]}, Loc.t("fragment_found"), 2.8)
		_props.add_child(fr)
		fr.global_position = f["pos"]
		fr.add_mesh("fragmento", "glow", Color.WHITE, 1.0, true)
		fr.add_light(Color("#ffb8ff"), 1.4, 5.0, 1.2)
		interactables.append(fr)


func _add_bridge_collision(at: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4.0, 0.3, 26.0)
	cs.shape = bx
	cs.position = Vector3(0, 0, -11.0)
	b.add_child(cs)
	b.position = at
	_props.add_child(b)


func _add_portal_swirl(it: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.2, 1.6, 0.2)
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_max = 0.2
	p.mesh = MonsterModel._sph(0.06, 4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#9ff0ff")
	m.emission_enabled = true
	m.emission = Color("#5fd0ff")
	m.emission_energy_multiplier = 3.0
	p.material_override = m
	p.position.y = 1.8
	it.add_child(p)


func _spawn_starter_display(at: Vector3) -> void:
	var ids := ["folhito", "brasito", "marolo"]
	for i in 3:
		var m := MonsterLogic.create(ids[i], 5, rng)
		var a := MonsterActor.new().setup(m, "display", self, gen)
		_actors.add_child(a)
		a.global_position = at + Vector3(-3.0 + i * 3.0, 0.5, -5.5)
		a.model.rotation.y = 0.0
		a.add_to_group("starter_display")
		# coleira
		var col := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.18
		tor.outer_radius = 0.26
		col.mesh = tor
		col.material_override = MeshLib.color_mat(Color("#3a3438"))
		col.position.y = 0.45
		a.add_child(col)


func _build_city() -> void:
	var st: GameState = Game.state
	var city: Dictionary = md["city"]
	var lay := gen.city_layout()
	var freed: bool = st.flags.get(city["liberated_flag"], false) or st.is_sandbox()
	var wall_tint := Color(md["biome"]["rock"]).lightened(0.15)
	for h in lay["houses"]:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.get_mesh("casa", int(h["style"]), Color.WHITE if map_id == "m4" else Color("#9a96aa"))
		mi.material_override = MeshLib.mat("vc_ds")
		mi.position = h["pos"]
		mi.rotation.y = h["rot"]
		mi.scale = Vector3(h["w"], h["h"] / 3.5, h["d"])
		mi.visibility_range_end = 140.0
		_props.add_child(mi)
		var b := StaticBody3D.new()
		b.collision_layer = 2
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(h["w"], h["h"], h["d"])
		cs.shape = bx
		cs.position = Vector3(0, h["h"] * 0.5, 0)
		b.add_child(cs)
		b.position = h["pos"]
		b.rotation.y = h["rot"]
		_props.add_child(b)
	# muralha com portões nas direções dos portais
	var wr: float = lay["wall_r"]
	var segs := int(TAU * wr / 6.0)
	for i in segs:
		var a := TAU * i / segs
		var gate := false
		for gd in lay["gate_dirs"]:
			if absf(angle_difference(a, gd)) < 0.12:
				gate = true
		if gate:
			continue
		var p := Vector3(cos(a) * wr, 0, sin(a) * wr)
		p.y = gen.height(p.x, p.z)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshLib.get_mesh("muralha", 0, wall_tint)
		mi.material_override = MeshLib.mat("vc")
		mi.position = p
		mi.rotation.y = -a + PI / 2
		_props.add_child(mi)
		var b := StaticBody3D.new()
		b.collision_layer = 2
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(6.2, 5.0, 1.6)
		cs.shape = bx
		cs.position.y = 2.5
		b.add_child(cs)
		b.position = p
		b.rotation.y = -a + PI / 2
		_props.add_child(b)
	# arena central e torre do ditador
	var arena := MeshInstance3D.new()
	arena.mesh = MeshLib.get_mesh("arena", 0, wall_tint.darkened(0.1))
	arena.material_override = MeshLib.mat("vc")
	arena.position = lay["arena"]
	_props.add_child(arena)
	var tower := MeshInstance3D.new()
	tower.mesh = MeshLib.get_mesh("torre", 0, Color("#5a4a44") if map_id == "m4" else Color("#3a3448"))
	tower.material_override = MeshLib.mat("vc")
	var tp: Array = city["districts"][2]["pos"]
	tower.position = Vector3(tp[0], gen.height(tp[0], tp[1] - 14), tp[1] - 14)
	_props.add_child(tower)
	if map_id == "m4":
		for k in 3:
			var ch := MeshInstance3D.new()
			ch.mesh = MeshLib.get_mesh("chamine_fabrica")
			ch.material_override = MeshLib.mat("vc")
			var cp := Vector3(-62 + k * 6, 0, 20 + 14)
			cp.y = gen.height(cp.x, cp.z)
			ch.position = cp
			_props.add_child(ch)
			_add_smoke(cp + Vector3(0, 12.5, 0))
	# postes de luz
	for i in 16:
		var a := TAU * i / 16.0
		var pp := Vector3(cos(a) * 20.0, 0, sin(a) * 20.0)
		pp.y = gen.height(pp.x, pp.z)
		var lamp := MeshInstance3D.new()
		lamp.mesh = MeshLib.get_mesh("poste")
		lamp.material_override = MeshLib.mat("vc")
		lamp.position = pp
		_props.add_child(lamp)
		if i % 4 == 0:
			var ol := OmniLight3D.new()
			ol.light_color = Color("#ffd88a")
			ol.light_energy = 1.2
			ol.omni_range = 9.0
			ol.position = pp + Vector3(0, 3.4, 0)
			_props.add_child(ol)
	# jaulas
	var ms := st.map_state(map_id)
	var opened: Array = ms["cages"]
	for i in city["cages"].size():
		if i in opened or float(i) in opened:
			continue
		var c: Array = city["cages"][i]
		var key := "cage_%d" % i
		var n := ResourceNode.new().setup(key, "jaula", Color.WHITE, 1.0, 0.0)
		n.cage_index = i
		_props.add_child(n)
		n.global_position = Vector3(c[0], gen.height(c[0], c[1]), c[1])
		nodes[key] = n
		var caged := _cage_species(i)
		var mm := MonsterModel.new().build(caged)
		var s := 1.0 / maxf(1.0, float(GameData.db().sp(caged)["body"]["size"]))
		mm.scale = Vector3.ONE * s * 0.9
		mm.position.y = 0.2
		mm.set_fainted(false)
		n.add_child(mm)
	# treinadores (capitães e ditador)
	for tid in city["trainers"]:
		var t: Dictionary = GameData.db().trainers[tid]
		var beaten: bool = tid in st.stats["trainers"]
		if beaten and t.get("ruler", false):
			continue
		var npc := Npc.new().setup("trainer", Loc.tx(t["name"]), Color(t["outfit"]),
			{"hat": "crown" if t.get("ruler", false) else "helmet", "cape": t.get("ruler", false), "backpack": false})
		npc.tid = tid
		_actors.add_child(npc)
		var tp2 := Vector3(t["pos"][0], 0, t["pos"][1])
		if t.get("ruler", false):
			tp2 += Vector3(0, 0, -8)
		tp2.y = gen.height(tp2.x, tp2.z)
		npc.global_position = tp2
		npc.face(Vector3(0, tp2.y, 30))
		if beaten:
			npc.set_label("%s ✓" % Loc.tx(t["name"]))
		npcs.append(npc)
	# moradores e serviços (mais gente depois da libertação)
	var n_vil := 14 if freed else 4
	var vrng := RandomNumberGenerator.new()
	vrng.seed = int(md["seed"]) + 77
	for i in n_vil:
		var a := vrng.randf() * TAU
		var r := vrng.randf_range(24.0, 60.0)
		var vp := Vector3(cos(a) * r, 0, sin(a) * r)
		vp.y = gen.height(vp.x, vp.z)
		var cols := [Color("#c84a4a"), Color("#4a8ac8"), Color("#c8a04a"), Color("#6ac84a"), Color("#a04ac8"), Color("#4ac8b0")]
		var v := Npc.new().setup("villager", "v%d" % i, cols[i % cols.size()].darkened(0.0 if freed else 0.45), {"hat": "cap" if i % 3 == 0 else ""})
		_actors.add_child(v)
		v.global_position = vp
		v.enable_wander(gen)
	if freed:
		_add_service_npc("merchant", Loc.t("merchant"), Color("#c8a04a"), Vector3(14, 0, 14))
		_add_service_npc("board", Loc.t("quest_board"), Color("#4a8ac8"), Vector3(-14, 0, 14))
		_add_service_npc("expedition", Loc.t("expeditions"), Color("#4ac88a"), Vector3(14, 0, -14))
		if map_id == "m4":
			var fp: Array = md["portals"][1]["pos"]
			_add_service_npc("ferry", Loc.tx(GameData.db().speakers["iara"]["name"]), Color("#e0a050"), Vector3(fp[0] - 6, 0, fp[1] - 4))


func _cage_species(i: int) -> String:
	var pool := ["ferrugente", "faiscaro", "lupigelo", "escarabrilho", "brasito"] if map_id == "m4" else ["nevoeiro", "sombrino", "coralume", "lumeflor", "vulcanix"]
	return pool[i % pool.size()]


func _add_service_npc(kind: String, name: String, col: Color, at: Vector3) -> void:
	var n := Npc.new().setup(kind, name, col, {"hat": "cap" if kind == "merchant" else "hood"})
	_actors.add_child(n)
	at.y = gen.height(at.x, at.z)
	n.global_position = at
	n.face(Vector3.ZERO)
	npcs.append(n)


func _add_smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 20
	p.lifetime = 4.0
	p.mesh = MonsterModel._sph(0.8, 6)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.33, 0.33, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 15
	p.gravity = Vector3(0.6, 0.8, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = curve
	p.position = at
	_props.add_child(p)


func _build_ambient_particles(q: int) -> void:
	var kind: String = md["biome"].get("particles", "")
	if kind == "" or q == 0:
		return
	_particles = CPUParticles3D.new()
	_particles.amount = 70 if q >= 2 else 40
	_particles.lifetime = 6.0
	_particles.preprocess = 4.0
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(22, 8, 22)
	var col := Color.WHITE
	var grav := Vector3(0, -0.6, 0)
	var sz := 0.06
	match kind:
		"leaves":
			col = Color("#9ad05a")
			grav = Vector3(0.3, -0.5, 0.1)
			sz = 0.09
		"sand":
			col = Color("#f0d8a0")
			grav = Vector3(2.0, -0.1, 0.4)
			sz = 0.04
		"snow":
			col = Color("#ffffff")
			grav = Vector3(0.2, -1.0, 0)
			sz = 0.07
		"spores":
			col = Color("#c8ff8a")
			grav = Vector3(0, 0.15, 0)
			sz = 0.05
		"embers":
			col = Color("#ff9a3a")
			grav = Vector3(0.1, 0.6, 0)
			sz = 0.05
		"rain":
			col = Color("#a8c8ff")
			grav = Vector3(0.5, -14.0, 0)
			sz = 0.035
			_particles.amount = 160 if q >= 2 else 90
			_particles.lifetime = 1.2
		"ash":
			col = Color("#8a8090")
			grav = Vector3(0.2, -0.3, 0)
			sz = 0.06
	_particles.gravity = grav
	_particles.initial_velocity_max = 0.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sz, sz * (8.0 if kind == "rain" else 1.0), sz)
	_particles.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if kind in ["embers", "spores"]:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
	_particles.material_override = m
	add_child(_particles)


# ================================================================== estruturas
func _spawn_structure(b: Dictionary) -> Structure:
	var s := Structure.new().setup(b)
	_structs.add_child(s)
	var c := BuildLogic.cell_center(Vector2i(int(b["cell"][0]), int(b["cell"][1])))
	s.global_position = Vector3(c.x, float(b["y"]), c.z)
	structures[int(b["uid"])] = s
	if s.bd.has("work"):
		s.update_stock()
	return s


func enter_build_mode(id: String) -> void:
	exit_build_mode()
	build_mode = true
	ghost_id = id
	ghost = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = Structure.build_mesh(id)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.4, 1.0, 0.6, 0.45)
	mi.material_override = gm
	mi.name = "M"
	ghost.add_child(mi)
	add_child(ghost)
	_update_ghost()


func exit_build_mode() -> void:
	build_mode = false
	if ghost != null:
		ghost.queue_free()
		ghost = null


func rotate_ghost() -> void:
	ghost_rot = (ghost_rot + 1) % 4
	_update_ghost()


func _ghost_cell() -> Vector2i:
	var p := player.global_position + player.facing() * 3.2
	return BuildLogic.cell_of(p)


func _terrain_info(cell: Vector2i) -> Dictionary:
	var c := BuildLogic.cell_center(cell)
	var hs := [gen.height(c.x - 1, c.z - 1), gen.height(c.x + 1, c.z - 1), gen.height(c.x - 1, c.z + 1), gen.height(c.x + 1, c.z + 1)]
	var blocked := false
	for p in gen.pads:
		if p["r"] < gen.half * 0.5 and Vector2(c.x, c.z).distance_to(p["pos"]) < float(p["r"]) * 0.6:
			blocked = true
	if md.get("city") != null and Vector2(c.x, c.z).length() < gen.half * 0.82:
		blocked = true  # não construir dentro da cidade
	return {"slope": hs.max() - hs.min(), "water": hs.min() < 0.6, "blocked": blocked, "ground": hs.max()}


func _update_ghost() -> void:
	if ghost == null:
		return
	var cell := _ghost_cell()
	var ti := _terrain_info(cell)
	var y := BuildLogic.base_height(Game.state, map_id, cell, float(ti["ground"]))
	var c := BuildLogic.cell_center(cell)
	ghost.global_position = Vector3(c.x, y, c.z)
	ghost.rotation.y = -ghost_rot * PI / 2.0
	var chk := BuildLogic.check(Game.state, ghost_id, map_id, cell, ghost_rot, ti)
	ghost_ok = chk["ok"]
	var mi: MeshInstance3D = ghost.get_node("M")
	(mi.material_override as StandardMaterial3D).albedo_color = Color(0.4, 1.0, 0.6, 0.45) if ghost_ok else Color(1.0, 0.35, 0.35, 0.45)


func place_ghost() -> void:
	if ghost == null:
		return
	var cell := _ghost_cell()
	var ti := _terrain_info(cell)
	var y := BuildLogic.base_height(Game.state, map_id, cell, float(ti["ground"]))
	var r := BuildLogic.place(Game.state, ghost_id, map_id, cell, ghost_rot, y, ti, Game.now())
	if not r["ok"]:
		Game.notify(Loc.t("cant_place") + " (%s)" % _reason_text(r["reason"]), "warn")
		Audio.play("error")
		return
	var s := _spawn_structure(r["entry"])
	s.scale = Vector3.ONE * 0.3
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.burst(self, s.global_position + Vector3(0, 0.5, 0), Color("#d8c08a"), 16, 3.0)
	Audio.play("build")
	Game.notify(Loc.t("built", [Loc.tx(GameData.db().buildings[ghost_id]["name"])]), "build")
	Game.on_build(ghost_id)
	hud.refresh()
	_update_ghost()


func _reason_text(r: String) -> String:
	match r:
		"items":
			return Loc.t("missing_items")
		"level":
			return Loc.t("needs_level", [GameData.db().buildings[ghost_id]["lvl"]])
		"occupied", "slope", "water", "blocked", "limit":
			return r
	return r


func demolish(s: Structure) -> void:
	var r := BuildLogic.demolish(Game.state, int(s.entry["uid"]))
	if r["ok"]:
		structures.erase(int(s.entry["uid"]))
		FX.burst(self, s.global_position + Vector3(0, 0.5, 0), Color("#a0703c"), 14, 3.0)
		s.queue_free()
		hud.refresh()


# ================================================================== Eco parceiro
func ally_actor() -> MonsterActor:
	return ally if ally != null and is_instance_valid(ally) and not ally.dead else null


func focus_target() -> MonsterActor:
	if _focus != null and is_instance_valid(_focus) and not _focus.dead and not _focus.capturing:
		return _focus
	if trainer_enemy != null and is_instance_valid(trainer_enemy) and not trainer_enemy.dead:
		return trainer_enemy
	# defesa automática: quem estiver atacando o jogador ou o parceiro
	for w in wilds:
		if is_instance_valid(w) and not w.dead and w.state == "chase" and w.target != null and (w.target == player or w.target == ally):
			if w.global_position.distance_to(player.global_position) < 14.0:
				return w
	if boss != null and is_instance_valid(boss) and not boss.dead and boss.state == "chase":
		return boss
	return null


func auto_skills() -> bool:
	return auto_skill_on


func lair_radius() -> float:
	return float(lair.get("r", 14.0))


func _spawn_ally() -> void:
	if ally != null and is_instance_valid(ally):
		ally.queue_free()
	ally = null
	var st: GameState = Game.state
	var uid := st.active_uid
	var m := st.get_monster(uid)
	if m.is_empty() or m["fainted"] or int(m.get("job", -1)) >= 0:
		uid = st.first_healthy_in_party()
		st.active_uid = uid
		m = st.get_monster(uid)
	if m.is_empty():
		hud.refresh()
		return
	ally = MonsterActor.new().setup(m, "ally", self, gen)
	_actors.add_child(ally)
	ally.global_position = player.global_position + Vector3(1.5, 0.8, 1.5)
	ally.died.connect(_on_ally_died)
	FX.burst(self, ally.global_position + Vector3(0, 0.5, 0), Color("#ff5a5a"), 10, 2.5, false, true)
	hud.refresh()


func switch_ally(uid: int) -> void:
	var st: GameState = Game.state
	if st.set_active(uid):
		_spawn_ally()
		Audio.play("summon")


func cycle_ally() -> void:
	var st: GameState = Game.state
	var ids: Array = st.party.duplicate()
	if ids.is_empty():
		return
	var i := ids.find(st.active_uid)
	for k in ids.size():
		var cand: int = ids[(i + 1 + k) % ids.size()]
		var m := st.get_monster(cand)
		if not m["fainted"] and int(m.get("job", -1)) < 0 and cand != st.active_uid:
			switch_ally(cand)
			return


func _on_ally_died(a: MonsterActor) -> void:
	var st: GameState = Game.state
	var m := a.m
	m["fainted"] = true
	m["hp"] = 0
	m["faint_until"] = Game.now() + int(GameData.db().cfg("combat", "faint_rest_sec", 120))
	Game.notify(Loc.t("echo_fainted", [MonsterLogic.display_name(m)]), "warn")
	Audio.play("faint")
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(a):
			a.queue_free()
		if ally == a:
			ally = null
		var nxt := st.first_healthy_in_party()
		if nxt >= 0:
			st.active_uid = nxt
			_spawn_ally()
		else:
			Game.notify(Loc.t("all_fainted"), "warn")
			if not battle.is_empty():
				_end_battle(false)
		hud.refresh())


# ================================================================== Ecos selvagens
func _spawn_wild(initial: bool = false) -> void:
	var table: Array = md["spawns"]
	var night := Game.state.is_night()
	var total := 0.0
	var cands: Array = []
	for e in table:
		if e.size() > 4 and e[4] == "night" and not night:
			continue
		cands.append(e)
		total += float(e[3])
	if cands.is_empty():
		return
	var r := rng.randf() * total
	var pick: Array = cands[0]
	for e in cands:
		r -= float(e[3])
		if r <= 0.0:
			pick = e
			break
	var lvl := rng.randi_range(int(pick[1]), int(pick[2]))
	if night:
		lvl += int(GameData.db().cfg("world", "night_level_bonus", 2))
	var variant := CombatLogic.roll_variant(rng)
	var m := MonsterLogic.create(pick[0], lvl, rng, 0, variant)
	var pos := gen.random_spawn_point(rng, player.global_position if not initial else Vector3.INF, 25.0)
	if md.get("city") != null and not Game.state.is_sandbox():
		pos = _city_guard_point()
	var a := MonsterActor.new()
	if md.get("city") != null and pick[0] == "ferrugente" and not Game.state.flags.get(md["city"]["liberated_flag"], false):
		a.collared = true
	a.setup(m, "wild", self, gen)
	_actors.add_child(a)
	a.global_position = pos + Vector3(0, 0.8, 0)
	a.home = pos
	a.died.connect(_on_wild_died)
	wilds.append(a)
	Game.state.mark_seen(pick[0])


func _city_guard_point() -> Vector3:
	for i in 30:
		var a := rng.randf() * TAU
		var r := rng.randf_range(25.0, gen.half * 0.7)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if gen.is_land(p.x, p.z, 1.0):
			p.y = gen.height(p.x, p.z)
			return p
	return Vector3(0, gen.height(0, 30), 30)


func _on_wild_died(a: MonsterActor) -> void:
	wilds.erase(a)
	if a == _focus:
		_focus = null
	_reward_defeat(a)
	if a.role == "boss":
		_on_boss_defeated(a, false)


func _reward_defeat(a: MonsterActor) -> void:
	var st: GameState = Game.state
	var xp := MonsterLogic.kill_xp(a.m)
	var mult := float(Game.rc.get("xp_mult", 1.0))
	_give_party_xp(int(xp * mult))
	Game.add_xp(int(xp * float(GameData.db().cfg("xp", "player_kill_share", 0.35))))
	FX.number(self, a.center() + Vector3(0, 1.0, 0), "+%d XP" % xp, Color("#9ff0ff"))
	if a.role == "trainer":
		Game.on_defeat(a.m)
		return
	# espólios
	var drops := {}
	if rng.randf() < 0.6 * float(Game.rc.get("drop_mult", 1.0)):
		drops["pele"] = rng.randi_range(1, 2)
	if rng.randf() < 0.5:
		drops["carne_crua"] = 1
	if rng.randf() < 0.45:
		drops["po_eco"] = rng.randi_range(1, 2)
	for k in drops:
		var left := st.inv.add(k, drops[k])
		if drops[k] - left > 0:
			Game.notify(Loc.t("got_item", [drops[k] - left, Loc.item_name(k)]), "item")
	var coins := 1 + int(a.m["lvl"]) / 2
	st.coins += coins
	Game.on_defeat(a.m)


func _give_party_xp(xp: int) -> void:
	var st: GameState = Game.state
	var share := float(GameData.db().cfg("xp", "share_reserve", 0.5))
	for m in st.party_monsters():
		var amount := xp if int(m["uid"]) == st.active_uid else int(xp * share)
		if m["fainted"]:
			amount = int(amount * 0.5)
		var res := MonsterLogic.add_xp(m, amount)
		if int(m["uid"]) == st.active_uid:
			MonsterLogic.add_bond(m, int(GameData.db().cfg("bond", "battle_xp", 4)))
		if res["levels"] > 0:
			Game.notify(Loc.t("lvl_up_echo", [MonsterLogic.display_name(m), m["lvl"]]), "level")
			if ally != null and is_instance_valid(ally) and ally.m == m:
				ally.max_hp = MonsterLogic.max_hp(m)
				FX.ring(self, ally.global_position, UiTheme.GOLD, 2.5)
				Audio.play("level_up")
		for s in res["learned"]:
			Game.notify(Loc.t("learned", [MonsterLogic.display_name(m), Loc.tx(GameData.db().skills[s]["name"])]), "info")
		if res["evolve"] != "":
			var old := MonsterLogic.display_name(m)
			MonsterLogic.evolve(m)
			st.mark_seen(m["sp"])
			if not st.dex.has(m["sp"]) or int(st.dex[m["sp"]]["caught"]) == 0:
				st.dex[m["sp"]] = {"seen": true, "caught": 1}
			Game.notify(Loc.t("evolved", [old, Loc.species_name(m["sp"])]), "level")
			if ally != null and is_instance_valid(ally) and ally.m == m:
				_spawn_ally()
	hud.refresh()


# ================================================================== combate
func resolve_hit(attacker: Node, target: Node, power: float, type: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	if attacker is MonsterActor:
		var a := attacker as MonsterActor
		if target is MonsterActor:
			var t := target as MonsterActor
			if t.dead or not a.is_enemy_of(t):
				return
			var bonus := 0.0
			if a.role == "ally":
				bonus = MonsterLogic.harmony_bonus(Game.state.party_types())
			var r := CombatLogic.damage(int(a.m["lvl"]), power, a.stat("atk"), t.stat("def"), type, a.types(), t.types(), rng, bonus)
			t.take_hit(r["dmg"], r["mult"], r["crit"], a)
			if r["mult"] > 1.05 and a.role == "ally":
				hud.flash_text(Loc.t("super_effective"), UiTheme.GOLD)
		elif target is Player:
			var p := target as Player
			if Game.is_peaceful():
				return
			var dmg := CombatLogic.damage_to_player(int(a.m["lvl"]), a.stat("atk"), Game.state.level, power, rng)
			if a.role == "boss":
				dmg = int(dmg * 1.4)
			p.take_damage(dmg)
			FX.number(self, p.global_position + Vector3(0, 2.0, 0), str(dmg), UiTheme.DANGER)
			hud.refresh()


func cast_skill(actor: MonsterActor, s: String, target: Node3D) -> void:
	var sk: Dictionary = GameData.db().skills[s]
	var col := FX.type_color(sk["type"])
	var power := float(sk["power"])
	if actor.role == "ally":
		FX.number(self, actor.center() + Vector3(0, 1.2, 0), Loc.tx(sk["name"]), col)
	match sk["kind"]:
		"projectile":
			if target == null:
				return
			var pr := Projectile.new().setup(actor.center(), target, col, func():
				if is_instance_valid(actor) and is_instance_valid(target):
					resolve_hit(actor, target, power, sk["type"]))
			add_child(pr)
			Audio.play("skill_shot", 0.15)
		"melee":
			if target == null:
				return
			FX.beam(self, actor.center(), target.global_position + Vector3(0, 0.8, 0), col, 0.2)
			resolve_hit(actor, target, power, sk["type"])
			FX.burst(self, target.global_position + Vector3(0, 0.8, 0), col, 14, 4.0, false, true)
			Audio.play("hit_hard", 0.15)
		"aoe":
			var rr := float(sk["range"])
			FX.ring(self, actor.global_position, col, rr, 0.5)
			FX.burst(self, actor.global_position + Vector3(0, 0.5, 0), col, 26, 6.0, false, true, 0.9)
			if rig:
				rig.shake = minf(1.0, rig.shake + 0.3)
			Audio.play("skill_aoe", 0.1)
			var victims: Array = []
			for w in wilds + [boss, trainer_enemy, ally, player]:
				if w != null and is_instance_valid(w) and w != actor and w.global_position.distance_to(actor.global_position) <= rr:
					if (w is MonsterActor and actor.is_enemy_of(w)) or (w is Player and actor.is_enemy_of(w)):
						victims.append(w)
			for v in victims:
				resolve_hit(actor, v, power * (0.7 if victims.size() > 1 else 1.0), sk["type"])
		"heal":
			actor.heal_frac(power / 100.0)
			Audio.play("heal")
		"buff":
			actor.buff_t = 8.0
			FX.ring(self, actor.global_position, col, 2.0, 0.5)
			Audio.play("buff")


func player_attack() -> void:
	## Golpe do jogador (arma) no Eco inimigo mais próximo à frente.
	var best: MonsterActor = null
	var best_d := 3.6
	for w in wilds + [boss]:
		if w == null or not is_instance_valid(w) or w.dead or w.capturing:
			continue
		var d: float = w.global_position.distance_to(player.global_position) - w.radius
		var to: Vector3 = (w.global_position - player.global_position).normalized()
		if d < best_d and (to.dot(player.facing()) > 0.2 or d < 1.2):
			best = w
			best_d = d
	player.model.play_swing("attack")
	Audio.play("swing", 0.1)
	if best == null:
		return
	player.face_towards(best.global_position)
	var dmg := CombatLogic.player_damage(Game.state.level, Game.state.inv.best_weapon_dmg())
	best.take_hit(dmg, 1.0, false, player)
	_focus = best
	Audio.play("hit_soft", 0.15)


func ally_skill(idx: int) -> void:
	var a := ally_actor()
	if a == null:
		return
	var skills: Array = a.m["skills"]
	var j := MonsterLogic.skill_slot(skills, idx)
	if j < 0:
		return
	var s: String = skills[j]
	var sk: Dictionary = GameData.db().skills[s]
	var tgt := focus_target()
	if tgt == null and sk["kind"] in ["projectile", "melee"]:
		# procura alvo perto
		var best_d := 16.0
		for w in wilds + [boss]:
			if w != null and is_instance_valid(w) and not w.dead:
				var d: float = w.global_position.distance_to(player.global_position)
				if d < best_d:
					best_d = d
					tgt = w
		if tgt == null:
			Game.notify(Loc.t("no_target"), "warn")
			return
		_focus = tgt
	a.target = tgt
	if a.cast(s):
		hud.refresh_skills()


# ================================================================== captura
func throw_sphere() -> void:
	if _capturing:
		return
	var st: GameState = Game.state
	var orb := _pick_orb()
	if orb == "":
		Game.notify(Loc.t("no_spheres"), "warn")
		return
	var tgt: MonsterActor = null
	var best := 16.0
	for w in wilds + [boss]:
		if w == null or not is_instance_valid(w) or w.dead or w.capturing:
			continue
		var d: float = w.global_position.distance_to(player.global_position)
		var to: Vector3 = (w.global_position - player.global_position).normalized()
		var score := d - to.dot(player.facing()) * 4.0
		if d < 16.0 and score < best:
			best = score
			tgt = w
	if _focus != null and is_instance_valid(_focus) and not _focus.dead and _focus.role in ["wild", "boss"] and _focus.global_position.distance_to(player.global_position) < 16.0:
		tgt = _focus
	if trainer_enemy != null and tgt == null:
		Game.notify(Loc.t("cant_capture_trainer"), "warn")
		return
	if tgt == null:
		Game.notify(Loc.t("no_target"), "warn")
		return
	st.inv.remove(orb, 1)
	_capturing = true
	player.face_towards(tgt.global_position)
	player.model.play_swing("throw")
	Audio.play("throw")
	var chance := CombatLogic.capture_chance(tgt.m["sp"], int(tgt.m["lvl"]), tgt.hp_frac(),
		float(GameData.db().item(orb)["orb"]["mult"]), st.level, tgt.collared)
	Firebase.log_event("capture_attempt", {"species": tgt.m["sp"], "chance": snappedf(chance, 0.01), "orb": orb})
	# esfera em arco
	var ball := MeshInstance3D.new()
	ball.mesh = MonsterModel._sph(0.18, 10)
	ball.material_override = MeshLib.color_mat(Color(GameData.db().item(orb)["color"]), 0.6)
	add_child(ball)
	var from := player.global_position + Vector3(0, 1.6, 0)
	var to_pos: Vector3 = tgt.center()
	ball.global_position = from
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(ball):
			ball.global_position = from.lerp(to_pos, t) + Vector3(0, sin(t * PI) * 2.5, 0), 0.0, 1.0, 0.45)
	await tw.finished
	if not is_instance_valid(tgt) or tgt.dead:
		ball.queue_free()
		_capturing = false
		return
	tgt.begin_capture()
	FX.burst(self, to_pos, Color.WHITE, 16, 3.0, false, true)
	Audio.play("capture_in")
	var ground_y := gen.height(to_pos.x, to_pos.z) + 0.2
	var t2 := create_tween()
	t2.tween_property(ball, "global_position", Vector3(to_pos.x, ground_y, to_pos.z), 0.25)
	await t2.finished
	var success := rng.randf() < chance
	var shakes := 3 if success else rng.randi_range(1, 3)
	for i in shakes:
		await get_tree().create_timer(0.45).timeout
		if not is_instance_valid(ball):
			break
		var t3 := create_tween()
		t3.tween_property(ball, "rotation:z", 0.5, 0.08)
		t3.tween_property(ball, "rotation:z", -0.5, 0.12)
		t3.tween_property(ball, "rotation:z", 0.0, 0.08)
		Audio.play("shake")
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(ball):
		ball.queue_free()
	_capturing = false
	if not is_instance_valid(tgt):
		return
	if success:
		_on_captured(tgt, ball.global_position if is_instance_valid(ball) else to_pos)
	else:
		Game.notify(Loc.t("capture_fail", [MonsterLogic.display_name(tgt.m)]), "warn")
		Audio.play("capture_fail")
		tgt.end_capture(false)
	hud.refresh()


func _pick_orb() -> String:
	var inv := Game.state.inv
	if inv.has(selected_orb):
		return selected_orb
	for o in ["esfera", "esfera_grande", "esfera_aurora"]:
		if inv.has(o):
			selected_orb = o
			return o
	return ""


func cycle_orb() -> void:
	var order := ["esfera", "esfera_grande", "esfera_aurora"]
	var i := order.find(selected_orb)
	for k in 3:
		var o: String = order[(i + 1 + k) % 3]
		if Game.state.inv.has(o):
			selected_orb = o
			break
	hud.refresh()


func _on_captured(tgt: MonsterActor, at: Vector3) -> void:
	var st: GameState = Game.state
	var m := tgt.m.duplicate(true)
	MonsterLogic.full_heal(m)
	m["job"] = -1
	m["expedition"] = false
	var where := st.add_monster(m)
	wilds.erase(tgt)
	FX.burst(self, at + Vector3(0, 0.5, 0), UiTheme.GOLD, 24, 4.0, false, true, 1.0)
	FX.ring(self, at, UiTheme.GOLD, 3.0, 0.6)
	Audio.play("capture_ok")
	Audio.vibrate(60)
	Game.notify(Loc.t("capture_success", [MonsterLogic.display_name(m)]), "capture")
	_give_party_xp(int(MonsterLogic.kill_xp(m) * 0.5))
	Game.add_xp(int(m["lvl"]) * int(GameData.db().cfg("xp", "capture_xp_mult", 4)))
	Game.on_capture(m)
	if tgt.role == "boss":
		_on_boss_defeated(tgt, true)
	tgt.end_capture(true)
	hud.show_capture(m, where)
	if ally == null:
		_spawn_ally()


# ================================================================== chefes
func _check_boss() -> void:
	if lair.is_empty():
		return
	var st: GameState = Game.state
	var defeated: bool = lair["boss"] in st.stats["bosses"]
	var d := player.global_position.distance_to(lair["center"])
	if not _boss_spawned and not defeated and d < lair_radius() + 18.0:
		_boss_spawned = true
		var m := MonsterLogic.create(lair["boss"], int(lair["lvl"]), rng)
		boss = MonsterActor.new().setup(m, "boss", self, gen)
		_actors.add_child(boss)
		boss.global_position = lair["center"] + Vector3(0, 1.0, 0)
		boss.home = lair["center"]
		boss.died.connect(_on_wild_died)
	elif _boss_spawned and boss != null and is_instance_valid(boss) and d > lair_radius() + 60.0 and not boss.dead:
		boss.queue_free()
		boss = null
		_boss_spawned = false


func _on_boss_defeated(b: MonsterActor, captured: bool) -> void:
	var st: GameState = Game.state
	var drop: String = lair.get("drop", "")
	if not b.m["sp"] in st.stats["bosses"]:
		st.stats["bosses"].append(b.m["sp"])
	if drop != "" and st.inv.count(drop) == 0 and int(st.stats["crafted"].get("nucleo_ponte" if drop in ["seiva_ancestral", "olho_ambar", "lagrima_glacial"] else "chave_sombria", 0)) == 0:
		st.inv.add(drop, 1)
		Game.notify(Loc.t("got_item", [1, Loc.item_name(drop)]), "relic")
		hud.show_relic(drop)
	Game.grant_and_toast({"coins": 150, "items": {"esfera_grande": 2}})
	if rig:
		rig.shake = 1.0
	FX.burst(self, b.global_position + Vector3(0, 1, 0), UiTheme.GOLD, 40, 7.0, false, true, 1.2)
	Game.check_quests()
	Game.save_now()


# ================================================================== treinadores
func start_trainer(npc: Npc) -> void:
	var st: GameState = Game.state
	var tid := npc.tid
	var t: Dictionary = GameData.db().trainers[tid]
	if tid in st.stats["trainers"]:
		Game.notify(Loc.t("already_beaten", [Loc.tx(t["name"])]), "info")
		return
	for req in t.get("requires", []):
		if not req in st.stats["trainers"]:
			Game.notify(Loc.t("trainer_locked"), "warn")
			return
	if t.has("requires_flag") and not st.flags.get(t["requires_flag"], false):
		Game.notify(Loc.t("trainer_locked"), "warn")
		return
	if st.first_healthy_in_party() < 0 and ally_actor() == null:
		Game.notify(Loc.t("all_fainted"), "warn")
		return
	npc.face(player.global_position)
	hud.show_dialog(t["intro"], func(): _begin_battle(npc))


func _begin_battle(npc: Npc) -> void:
	var t: Dictionary = GameData.db().trainers[npc.tid]
	battle = {"tid": npc.tid, "queue": t["team"].duplicate(true), "npc": npc, "total": t["team"].size()}
	if ally_actor() == null:
		_spawn_ally()
	Audio.play_music("battle")
	_next_trainer_monster()


func _next_trainer_monster() -> void:
	if battle.is_empty():
		return
	var q: Array = battle["queue"]
	if q.is_empty():
		_end_battle(true)
		return
	var e: Array = q.pop_front()
	var m := MonsterLogic.create(e[0], int(e[1]), rng)
	trainer_enemy = MonsterActor.new().setup(m, "trainer", self, gen)
	_actors.add_child(trainer_enemy)
	var npc: Npc = battle["npc"]
	var to_p := (player.global_position - npc.global_position).normalized()
	var p := npc.global_position + to_p * 3.5
	p.y = gen.height(p.x, p.z) + 0.8
	trainer_enemy.global_position = p
	trainer_enemy.home = p
	trainer_enemy.died.connect(_on_trainer_monster_died)
	FX.burst(self, p, Color("#ff5a5a"), 14, 3.0, false, true)
	Game.notify(Loc.t("trainer_next", [npc.display_name, Loc.species_name(e[0])]), "warn")
	hud.trainer_banner(battle)


func _on_trainer_monster_died(a: MonsterActor) -> void:
	_reward_defeat(a)
	trainer_enemy = null
	get_tree().create_timer(1.2).timeout.connect(_next_trainer_monster)
	hud.trainer_banner(battle)


func _end_battle(won: bool) -> void:
	if battle.is_empty():
		return
	var tid: String = battle["tid"]
	var npc: Npc = battle["npc"]
	var t: Dictionary = GameData.db().trainers[tid]
	battle = {}
	if trainer_enemy != null and is_instance_valid(trainer_enemy):
		trainer_enemy.queue_free()
	trainer_enemy = null
	hud.trainer_banner({})
	Audio.play_music(md["biome"]["music"])
	if not won:
		Game.notify(Loc.t("trainer_lost"), "warn")
		return
	Game.on_trainer_defeated(tid)
	Game.notify(Loc.t("trainer_won", [Loc.tx(t["name"])]), "quest")
	var rw: Dictionary = t["reward"].duplicate(true)
	var gift: Variant = rw.get("gift_monster")
	rw.erase("gift_monster")
	Game.grant_and_toast(rw, Loc.t("trainer_won", [Loc.tx(t["name"])]))
	npc.set_label("%s ✓" % Loc.tx(t["name"]))
	hud.show_dialog(t["defeat"], func():
		if gift != null:
			var m := MonsterLogic.create(gift[0], int(gift[1]), rng)
			Game.state.add_monster(m)
			Game.on_capture(m)
			hud.show_capture(m, "party")
		if t.get("ruler", false):
			_liberate_city()
		else:
			Ads.maybe_interstitial("trainer"))
	Game.save_now()


func _liberate_city() -> void:
	var st: GameState = Game.state
	var flag: String = md["city"]["liberated_flag"]
	st.flags[flag] = true
	Firebase.log_event("city_liberated", {"map": map_id})
	Game.notify(Loc.t("city_liberated", [Loc.tx(md["name"])]), "quest")
	Game.check_quests()
	Game.save_now()
	# recarrega o mapa para mostrar a cidade livre (moradores, mercado, balsa)
	get_tree().create_timer(2.5).timeout.connect(func(): emit_signal("travel_requested", map_id))


# ================================================================== coleta e interação
func _scan_target() -> void:
	## Escolhe o alvo de interação mais próximo (com bônus para o que está à frente).
	## Atenção: lambdas do GDScript capturam variáveis locais por cópia; por isso o melhor alvo
	## é guardado num Dictionary (referência), não em variáveis simples.
	var best := {"node": null, "score": 999.0}
	var pp := player.global_position
	var fw := player.facing()
	var check := func(n: Node3D, rng_m: float) -> void:
		var d := Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length()
		if d > rng_m:
			return
		var to := (n.global_position - pp)
		to.y = 0
		var facing_bonus := to.normalized().dot(fw) if to.length() > 0.1 else 1.0
		var score := d - facing_bonus * 1.2
		if score < float(best["score"]):
			best["score"] = score
			best["node"] = n
	for k in nodes:
		var n: ResourceNode = nodes[k]
		if not n.harvested:
			check.call(n, n.interact_range())
	for it in interactables:
		if is_instance_valid(it):
			check.call(it, it.interact_range())
	for s in structures.values():
		if s.interactive():
			check.call(s, s.interact_range())
	for n in npcs:
		if is_instance_valid(n):
			check.call(n, n.interact_range())
	for a in get_tree().get_nodes_in_group("starter_display"):
		check.call(a, 4.0)
	_set_target(best["node"])
	hud.set_context(_context_label(current_target), _context_kind(current_target))


# ------------------------------------------------------------------ destaque e marcadores
var _hl_mat: ShaderMaterial
var _hl_meshes: Array = []
var _sparks: Array = []


func _highlight_material(col: Color) -> ShaderMaterial:
	if _hl_mat == null:
		_hl_mat = ShaderMaterial.new()
		_hl_mat.shader = load("res://assets/shaders/highlight.gdshader")
	_hl_mat.set_shader_parameter("glow_color", col)
	return _hl_mat


func _set_target(n: Node) -> void:
	if n == current_target and (n == null or _hl_meshes.size() > 0):
		return
	for mi in _hl_meshes:
		if is_instance_valid(mi):
			mi.material_overlay = null
	_hl_meshes.clear()
	current_target = n
	if n == null or not is_instance_valid(n):
		return
	var col := Color("#9dff8a") if (n is ResourceNode and not (n as ResourceNode).is_barrier()) else Color("#ffd95a")
	var mat := _highlight_material(col)
	var stack: Array = [n]
	while stack.size() > 0 and _hl_meshes.size() < 40:
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and c.visible and not (c.mesh is PlaneMesh) and not (c.mesh is QuadMesh):
			(c as MeshInstance3D).material_overlay = mat
			_hl_meshes.append(c)
		for ch in c.get_children():
			if not ch is CPUParticles3D and not ch is Label3D:
				stack.append(ch)


var _tut_arrow: Node3D
var _tut_target: Node3D


func set_tutorial_arrow(target: Node3D) -> void:
	_tut_target = target
	if _tut_arrow == null:
		_tut_arrow = Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = MonsterModel._cone(0.38, 0.7, 12)
		mi.rotation.x = PI
		mi.material_override = MeshLib.color_mat(Color("#ffd23a"), 1.8, false)
		mi.material_override.next_pass = MeshLib.outline_mat(0.03)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tut_arrow.add_child(mi)
		add_child(_tut_arrow)
	_tut_arrow.visible = target != null and is_instance_valid(target)


func _update_tut_arrow() -> void:
	if _tut_arrow == null or not _tut_arrow.visible or _tut_target == null or not is_instance_valid(_tut_target):
		if _tut_arrow != null:
			_tut_arrow.visible = false
		return
	var h := 2.4
	if _tut_target is ResourceNode:
		h = 6.2 if (_tut_target as ResourceNode).kind in ["arvore", "pinheiro", "palmeira"] else 2.6
	elif _tut_target is MonsterActor:
		h = (_tut_target as MonsterActor).model.height() + 1.0
	var t := Time.get_ticks_msec() / 1000.0
	_tut_arrow.global_position = _tut_target.global_position + Vector3(0, h + absf(sin(t * 3.5)) * 0.5, 0)
	_tut_arrow.rotation.y = t * 2.0


func nearest_node(kinds: Array, max_d: float) -> ResourceNode:
	var best: ResourceNode = null
	var bd := max_d
	for k in nodes:
		var n: ResourceNode = nodes[k]
		if n.harvested or not n.kind in kinds:
			continue
		var d := n.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = n
	return best


func nearest_wild(max_d: float) -> MonsterActor:
	var best: MonsterActor = null
	var bd := max_d
	for w in wilds:
		if not is_instance_valid(w) or w.dead:
			continue
		var d: float = w.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = w
	return best


func _build_sparks() -> void:
	## Faíscas flutuantes reutilizáveis sobre os coletáveis mais próximos.
	var mesh := MeshLib.get_mesh("fragmento")
	for i in 10:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MeshLib.color_mat(Color("#c8ff9a"), 2.2, true)
		mi.scale = Vector3(0.32, 0.32, 0.32)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_sparks.append(mi)


func _update_sparks() -> void:
	if _sparks.is_empty():
		_build_sparks()
	var pp := player.global_position
	var cands: Array = []
	if not Game.state.flags.get("starter_chosen", false):
		for a in get_tree().get_nodes_in_group("starter_display"):
			cands.append([a.global_position.distance_to(pp) - 100.0, a, 1.6, Color("#ffd95a")])
	for k in nodes:
		var n: ResourceNode = nodes[k]
		if n.harvested:
			continue
		var d := n.global_position.distance_to(pp)
		if d < 16.0:
			var h := 2.2
			match n.kind:
				"arvore", "pinheiro", "palmeira":
					h = 5.4
				"arvore_morta":
					h = 4.0
				"rocha", "minerio", "carvao_veio", "obsidiana_veio", "bloco_gelo", "cristal", "jaula", "espinhos":
					h = 2.4
				"muro_gelo", "porta_solar":
					h = 4.6
				_:
					h = 1.4
			cands.append([d, n, h, Color("#ffd95a") if n.is_barrier() else Color("#c8ff9a")])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var t := Time.get_ticks_msec() / 1000.0
	for i in _sparks.size():
		var mi: MeshInstance3D = _sparks[i]
		if i < cands.size():
			var c: Array = cands[i]
			var node: Node3D = c[1]
			mi.visible = true
			mi.global_position = node.global_position + Vector3(0, float(c[2]) + sin(t * 2.5 + i) * 0.15, 0)
			mi.rotation.y = t * 1.8 + i
			mi.material_override = MeshLib.color_mat(c[3], 2.2, true)
		else:
			mi.visible = false


# ------------------------------------------------------------------ requisitos de progressão
var _req_labels: Array = []  # [Label3D, Callable(texto)]
var _req_t := 0.0
var _req_warned := {}


func tool_item_for(n: ResourceNode) -> String:
	var t: String = n.required_tool()
	if t.begins_with("item:"):
		return t.substr(5)
	var tier := int(n.nd["min_tier"])
	match t:
		"torch":
			return "tocha"
		"crowbar":
			return "pe_de_cabra"
		"axe":
			return "machado_ferro" if tier >= 2 else "machado_pedra"
		"pick":
			return "picareta_obsidiana" if tier >= 3 else ("picareta_ferro" if tier >= 2 else "picareta_pedra")
	return ""


func has_requirement(n: ResourceNode) -> bool:
	var t: String = n.required_tool()
	var inv := Game.state.inv
	if t == "any":
		return true
	if t.begins_with("item:"):
		return inv.has(t.substr(5))
	var tl := inv.best_tool(t)
	if tl.is_empty():
		return int(n.nd["min_tier"]) == 0 and not t in ["torch", "crowbar"]
	return int(tl["tier"]) >= int(n.nd["min_tier"])


static func craft_station_of(item_id: String) -> String:
	for rid in GameData.db().recipes:
		if GameData.db().recipes[rid]["out"] == item_id:
			return Loc.t("station_" + GameData.db().recipes[rid]["station"])
	return ""


func _add_req_label(parent: Node3D, height: float, text_fn: Callable) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = UiTheme.font(900)
	l.font_size = 46
	l.pixel_size = 0.0085
	l.outline_size = 14
	l.outline_modulate = Color(0.03, 0.03, 0.06, 0.95)
	l.position.y = height
	l.no_depth_test = false
	l.visibility_range_end = 30.0
	l.width = 900
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	_req_labels.append([l, text_fn])
	_refresh_req_label(_req_labels.back())


func _refresh_req_label(e: Array) -> void:
	var l: Label3D = e[0]
	if not is_instance_valid(l):
		return
	var r: Array = (e[1] as Callable).call()  # [texto, ok]
	l.visible = r[0] != ""
	l.text = r[0]
	l.modulate = Color("#8dff8a") if r[1] else Color("#ffb36a")


func barrier_text(n: ResourceNode) -> Array:
	if n.harvested:
		return ["", true]
	var item := tool_item_for(n)
	var name := Loc.t("bar_" + n.kind)
	var have := has_requirement(n)
	if have:
		return ["%s\n%s" % [name, Loc.t("req_have", [Loc.item_name(item)])], true]
	var st_name := craft_station_of(item)
	var where := ("\n" + Loc.t("req_craft", [st_name])) if st_name != "" else ""
	return ["⚠ %s\n%s%s" % [name, Loc.t("req_title", [Loc.item_name(item)]), where], false]


func _build_requirement_labels() -> void:
	# uma placa por grupo de barreiras iguais (ex.: os 3 espinhos da entrada)
	var groups: Array = []
	for k in nodes:
		var n: ResourceNode = nodes[k]
		if not n.is_barrier():
			continue
		var found := false
		for g in groups:
			if g[0].kind == n.kind and g[0].global_position.distance_to(n.global_position) < 6.0:
				g.append(n)
				found = true
				break
		if not found:
			groups.append([n])
	for g in groups:
		var grp: Array = g
		var mid: ResourceNode = grp[grp.size() / 2]
		var h := 3.6 if mid.kind in ["espinhos", "jaula"] else 4.8
		_add_req_label(mid, h, func():
			for x in grp:
				if not (x as ResourceNode).harvested:
					return barrier_text(x)
			return ["", true])
	for it in interactables:
		if it.kind == "portal":
			var p: Dictionary = it.data
			var itt: Interactable = it
			_add_req_label(it, 5.2, func():
				var st: GameState = Game.state
				var to: String = p["to"]
				if st.map_unlocked(to) and (not p.has("requires_flag") or st.flags.get(p["requires_flag"], false)):
					var md2: Dictionary = GameData.db().maps[to]
					if md2.get("hazard") != null and not st.inv.has_protection(md2["hazard"]["kind"]):
						return ["%s\n%s" % [Loc.tx(p["label"]), Loc.t("req_hazard", [Loc.t("hz_" + md2["hazard"]["kind"]), Loc.item_name(md2["hazard"]["gear"])])], false]
					return [Loc.tx(p["label"]), true]
				var why := Loc.t("travel_locked")
				match p.get("requires_flag", ""):
					"bridge_built":
						why = Loc.t("req_bridge")
					"city1_free":
						why = Loc.t("req_city1")
					"gate2_open":
						why = Loc.t("req_gate2")
				return ["⚠ %s\n%s" % [Loc.tx(p["label"]), why], false])
		elif it.kind == "altar":
			var d: Dictionary = it.data
			_add_req_label(it, 3.6, func():
				if Game.state.flags.get(d["flag"], false):
					return ["", true]
				var have: bool = Game.state.inv.has(d["item"])
				var line := Loc.t("req_have", [Loc.item_name(d["item"])]) if have else Loc.t("req_title", [Loc.item_name(d["item"])]) + "\n" + Loc.t("req_craft", [craft_station_of(d["item"])])
				return ["%s\n%s" % [Loc.t("bridge_altar"), line], have])
	if not lair.is_empty():
		var holder := Node3D.new()
		_props.add_child(holder)
		holder.global_position = lair["entrance"] + Vector3(0, gen.height(lair["entrance"].x, lair["entrance"].z), 0)
		var bid: String = lair["boss"]
		var blvl: int = int(lair["lvl"])
		_add_req_label(holder, 6.4, func():
			if bid in Game.state.stats["bosses"]:
				return ["", true]
			return ["★ %s  %s\n%s" % [Loc.species_name(bid), Loc.t("level_short", [blvl]), Loc.tx(GameData.db().items[lair["drop"]]["name"])], Game.state.level + 2 >= blvl])
	for npc in npcs:
		if is_instance_valid(npc) and npc.kind == "trainer":
			var t: Dictionary = GameData.db().trainers[npc.tid]
			if t.get("ruler", false):
				var tid: String = npc.tid
				_add_req_label(npc, 3.3, func():
					var st: GameState = Game.state
					if tid in st.stats["trainers"]:
						return ["", true]
					for rq in t.get("requires", []):
						if not rq in st.stats["trainers"]:
							return [Loc.t("req_captains"), false]
					if t.has("requires_flag") and not st.flags.get(t["requires_flag"], false):
						return [Loc.t("req_captains"), false]
					return ["", true])


func _update_requirements(delta: float) -> void:
	_req_t -= delta
	if _req_t > 0.0:
		return
	_req_t = 1.0
	for e in _req_labels:
		_refresh_req_label(e)
	# aviso da Lume ao se aproximar de um bloqueio sem o requisito
	for k in nodes:
		var n: ResourceNode = nodes[k]
		if not n.is_barrier() or n.harvested or n.kind == "jaula":
			continue
		if n.global_position.distance_to(player.global_position) < 14.0 and not has_requirement(n):
			var key: String = n.kind
			if Game.now() - int(_req_warned.get(key, 0)) > 45:
				_req_warned[key] = Game.now()
				var item := tool_item_for(n)
				hud.lume_hint(Loc.t("req_near", [Loc.t("bar_" + n.kind), Loc.item_name(item), Loc.t("req_craft", [craft_station_of(item)])]), 7.0)
			break


func _context_label(n: Node) -> String:
	if n == null:
		return ""
	if n is ResourceNode:
		var rn := n as ResourceNode
		if rn.kind == "jaula":
			return Loc.t("free_it")
		if rn.is_barrier():
			if not has_requirement(rn):
				return Loc.t("req_missing_btn", [Loc.item_name(tool_item_for(rn))])
			return Loc.t("interact")
		return Loc.t("gather")
	if n is Interactable:
		return (n as Interactable).label_text
	if n is Structure:
		return Loc.tx((n as Structure).bd["name"])
	if n is Npc:
		var npc := n as Npc
		return Loc.t("trainer_challenge", [npc.display_name]) if npc.kind == "trainer" else npc.display_name
	if n is MonsterActor:
		return Loc.t("free_it")
	return ""


func _context_kind(n: Node) -> String:
	if n == null:
		return "attack"
	if n is ResourceNode and not (n as ResourceNode).is_barrier():
		return "gather"
	return "use"


func on_action() -> void:
	## Botão principal: coleta/interage com o alvo de contexto; senão, ataca.
	if build_mode:
		place_ghost()
		return
	var near_enemy := false
	for w in wilds + [boss, trainer_enemy]:
		if w != null and is_instance_valid(w) and not w.dead and w.global_position.distance_to(player.global_position) < 3.0 + w.radius:
			near_enemy = true
	var t := current_target
	if t != null and is_instance_valid(t) and not (near_enemy and t is ResourceNode and not (t as ResourceNode).is_barrier()):
		_interact(t)
	else:
		player_attack()


func _interact(t: Node) -> void:
	if t is ResourceNode:
		_gather(t)
	elif t is Interactable:
		_use_interactable(t)
	elif t is Structure:
		_use_structure(t)
	elif t is Npc:
		_use_npc(t)
	elif t is MonsterActor and t.is_in_group("starter_display"):
		hud.show_starter_choice(func(sp: String): _choose_starter(sp))


func _gather(n: ResourceNode) -> void:
	var st: GameState = Game.state
	player.face_towards(n.global_position)
	var tool_need := n.required_tool()
	var power := float(GameData.db().cfg("player", "gather_base", 1.0))
	var held := ""
	if tool_need == "any":
		power = 1.0
	elif tool_need.begins_with("item:"):
		var need_item := tool_need.substr(5)
		if not st.inv.has(need_item):
			Game.notify(Loc.t("need_tool", [Loc.item_name(need_item)]), "warn")
			return
		power = 99.0
	else:
		var tl := st.inv.best_tool(tool_need)
		var min_tier := int(n.nd["min_tier"])
		if tl.is_empty():
			if min_tier > 0 or tool_need in ["torch", "crowbar"]:
				var names := {"axe": "machado_pedra", "pick": "picareta_pedra" if min_tier <= 1 else "picareta_ferro", "torch": "tocha", "crowbar": "pe_de_cabra"}
				Game.notify(Loc.t("need_tool", [Loc.item_name(names.get(tool_need, "machado_pedra"))]), "warn")
				return
		else:
			if int(tl["tier"]) < min_tier:
				Game.notify(Loc.t("need_tier"), "warn")
				return
			power = float(tl["power"])
			held = tl["id"]
	if held != "":
		player.model.set_held(held)
	player.model.play_swing("gather")
	Audio.play("chop" if tool_need == "axe" else ("mine" if tool_need == "pick" else "gather"), 0.12)
	# o parceiro ajuda na coleta (bônus de trabalho)
	var a := ally_actor()
	if a != null and a.global_position.distance_to(n.global_position) < 6.0 and tool_need in ["axe", "pick", "any"]:
		var wk: String = {"axe": "corte", "pick": "mineracao", "any": "coleta"}[tool_need]
		power += MonsterLogic.work_level(a.m, wk) * 0.5
	if not n.hit(power):
		return
	_on_node_depleted(n)


func _on_node_depleted(n: ResourceNode) -> void:
	var st: GameState = Game.state
	var ms := st.map_state(map_id)
	var nd := n.nd
	if n.is_barrier():
		n.set_harvested(true)
		ms["barriers"].append(n.key)
		Game.add_xp(int(nd["xp"]))
		if n.kind == "espinhos":
			# o fogo se espalha por todos os espinhos
			for k in nodes:
				var o: ResourceNode = nodes[k]
				if o.kind == "espinhos" and not o.harvested:
					o.set_harvested(true)
					ms["barriers"].append(o.key)
					FX.burst(self, o.global_position + Vector3(0, 1, 0), Color("#ff8a2a"), 20, 4.0, false, true)
			st.flags["thorns_burned"] = true
			Game.notify(Loc.t("thorns_burned"), "quest")
		elif n.kind == "jaula":
			_open_cage(n)
		FX.burst(self, n.global_position + Vector3(0, 1, 0), Color("#ffd04a"), 24, 5.0, false, true)
		Game.check_quests()
		return
	# recompensas
	var got := {}
	for k in nd["drops"]:
		var rr: Array = nd["drops"][k]
		got[k] = rng.randi_range(int(rr[0]), int(rr[1]))
	for k in nd["bonus"]:
		if rng.randf() < float(nd["bonus"][k]):
			got[k] = int(got.get(k, 0)) + 1
	var mult := float(Game.rc.get("drop_mult", 1.0))
	for k in got:
		var n_items := int(round(got[k] * mult))
		if n_items <= 0:
			continue
		var left := st.inv.add(k, n_items)
		if n_items - left > 0:
			Game.notify(Loc.t("got_item", [n_items - left, Loc.item_name(k)]), "item")
			Game.on_gather(k, n_items - left)
		if left > 0:
			Game.notify(Loc.t("inventory_full"), "warn")
	Game.add_xp(int(nd["xp"]))
	n.set_harvested(true)
	var resp := int(nd["respawn"])
	ms["harvested"][n.key] = Game.now() + resp
	hud.refresh()


func _open_cage(n: ResourceNode) -> void:
	var st: GameState = Game.state
	var ms := st.map_state(map_id)
	if not n.cage_index in ms["cages"]:
		ms["cages"].append(n.cage_index)
	var sp := _cage_species(n.cage_index)
	var m := MonsterLogic.create(sp, 12 if map_id == "m4" else 32, rng)
	var where := st.add_monster(m)
	Game.on_capture(m)
	Game.notify(Loc.t("cage_opened"), "quest")
	hud.show_capture(m, where)
	var city: Dictionary = md["city"]
	if ms["cages"].size() >= int(city["cages_needed"]):
		st.flags["cages1_done" if map_id == "m4" else "cages2_done"] = true
	Game.check_quests()


func _use_interactable(it: Interactable) -> void:
	var st: GameState = Game.state
	match it.kind:
		"cradle":
			if not st.flags.get("starter_chosen", false):
				hud.show_starter_choice(func(sp: String): _choose_starter(sp))
			else:
				hud.show_dialog("d_intro", Callable())
		"fragment":
			var fid: String = it.data["id"]
			var ms := st.map_state(map_id)
			if not fid in ms["fragments"]:
				ms["fragments"].append(fid)
			interactables.erase(it)
			FX.burst(self, it.global_position + Vector3(0, 1, 0), Color("#ffb8ff"), 30, 4.0, false, true, 1.0)
			it.queue_free()
			Audio.play("fragment")
			Firebase.log_event("fragment_found", {"id": fid})
			Game.grant_and_toast({"gems": 5, "xp": 40})
			hud.show_fragment(fid)
			Game.save_now()
		"portal":
			_use_portal(it)
		"altar":
			if st.flags.get(it.data["flag"], false):
				Game.notify(Loc.t("bridge_altar"), "info")
				return
			if st.inv.has(it.data["item"]):
				st.inv.remove(it.data["item"], 1)
				st.flags[it.data["flag"]] = true
				Audio.play("relic")
				Game.check_quests()
				Game.save_now()
				if rig:
					rig.shake = 1.0
				FX.burst(self, it.global_position + Vector3(0, 2, 0), Color("#ff9aff"), 50, 8.0, false, true, 1.5)
				get_tree().create_timer(1.8).timeout.connect(func(): emit_signal("travel_requested", map_id))
			else:
				Game.notify(Loc.t("need_core"), "info")


func _use_portal(it: Interactable) -> void:
	var st: GameState = Game.state
	var p: Dictionary = it.data
	var to: String = p["to"]
	if p.has("requires_flag") and not st.flags.get(p["requires_flag"], false) and not st.is_sandbox():
		# portão sombrio: usar a chave
		if p["requires_flag"] == "gate2_open":
			if st.inv.has("chave_sombria"):
				st.inv.remove("chave_sombria", 1)
				st.flags["gate2_open"] = true
				Audio.play("relic")
				Game.check_quests()
				Game.save_now()
				emit_signal("travel_requested", map_id)
			else:
				Game.notify(Loc.t("need_key"), "info")
			return
		Game.notify(Loc.t("travel_locked"), "warn")
		return
	if not st.map_unlocked(to):
		Game.notify(Loc.t("travel_locked"), "warn")
		return
	Audio.play("portal")
	st.has_pos = false
	emit_signal("travel_requested", to)


func _use_structure(s: Structure) -> void:
	var st: GameState = Game.state
	var bd := s.bd
	if bd.has("station"):
		hud.open_menu("craft")
		return
	if bd.has("work"):
		hud.open_station(s)
		return
	match bd.get("special", ""):
		"bed":
			var c := s.global_position
			st.spawn_point = {"map": map_id, "pos": [c.x, c.y, c.z]}
			if SurvivalLogic.sleep(st):
				hud.fade_sleep()
				Game.notify(Loc.t("sleep_done"), "info")
				sky.update_time(st.day_time)
			else:
				Game.notify(Loc.t("cant_sleep_day"), "info")
			Game.save_now()
		"chest":
			hud.open_chest(s)
		"heal":
			for m in st.party_monsters():
				MonsterLogic.full_heal(m)
			if ally == null:
				_spawn_ally()
			elif is_instance_valid(ally):
				ally.max_hp = MonsterLogic.max_hp(ally.m)
				ally.m["hp"] = ally.max_hp
				ally.heal_frac(0.0)
			FX.ring(self, s.global_position, Color("#7ff0ff"), 4.0, 0.7)
			Audio.play("heal")
			Game.notify(Loc.t("healing_spring"), "info")
			hud.refresh()


func _use_npc(n: Npc) -> void:
	match n.kind:
		"trainer":
			start_trainer(n)
		"merchant":
			hud.open_menu("shop")
		"board":
			hud.open_menu("quests")
		"expedition":
			hud.open_expeditions()
		"ferry":
			hud.show_dialog("d_q25", Callable())


func _choose_starter(sp: String) -> void:
	var st: GameState = Game.state
	if st.flags.get("starter_chosen", false):
		return
	var m := MonsterLogic.create(sp, 5, rng)
	st.add_monster(m)
	st.flags["starter_chosen"] = true
	Firebase.log_event("starter_chosen", {"species": sp})
	for a in get_tree().get_nodes_in_group("starter_display"):
		if a.m["sp"] == sp:
			FX.burst(self, a.global_position + Vector3(0, 0.5, 0), UiTheme.GOLD, 30, 4.0, false, true, 1.0)
			a.queue_free()
		else:
			var tw: Tween = a.create_tween()
			var away: Vector3 = a.global_position + (a.global_position - player.global_position).normalized() * 25.0
			tw.tween_property(a, "global_position", Vector3(away.x, a.global_position.y, away.z), 3.0)
			tw.tween_callback(a.queue_free)
	_spawn_ally()
	Audio.play("capture_ok")
	Game.check_quests()


# ================================================================== morte do jogador
func _on_player_died() -> void:
	Game.state.stats["deaths"] = int(Game.state.stats.get("deaths", 0)) + 1
	Firebase.log_event("player_death", {"map": map_id})
	if not battle.is_empty():
		_end_battle(false)
	hud.show_death(func(here: bool): _revive(here))


func _revive(here: bool) -> void:
	var st: GameState = Game.state
	if here:
		player.revive(player.global_position + Vector3(0, 0.5, 0))
		return
	var sp: Dictionary = st.spawn_point
	if sp.get("map", "") == map_id and sp.get("pos", []).size() == 3:
		player.revive(Vector3(sp["pos"][0], sp["pos"][1] + 1.0, sp["pos"][2]))
	elif sp.get("map", "") != "" and sp.get("map", "") != map_id and sp.get("pos", []).size() == 3:
		st.hp = st.max_hp()
		st.pos = Vector3(sp["pos"][0], sp["pos"][1], sp["pos"][2])
		st.has_pos = true
		emit_signal("travel_requested", sp["map"])
	else:
		player.revive(_initial_player_pos())


# ================================================================== laço principal
func _process(delta: float) -> void:
	if player == null:
		return
	var st: GameState = Game.state
	# tempo do mundo
	var new_day := SurvivalLogic.advance_time(st, delta)
	sky.update_time(st.day_time)
	if new_day:
		hud.refresh()
	if st.is_night() and not _night_warned and not st.is_sandbox():
		_night_warned = true
		if st.quest_idx >= 6 and st.count_buildings("cama") == 0:
			hud.lume_hint(Loc.tx(GameData.db().dialogs["d_night"][0]["text"]))
	elif not st.is_night():
		_night_warned = false
	# sobrevivência
	var ev := SurvivalLogic.tick(st, delta, md.get("hazard"))
	if ev["hazard_dmg"] > 0.0:
		if not _hazard_warned:
			_hazard_warned = true
			var hz: Dictionary = md["hazard"]
			hud.lume_hint(Loc.tx(GameData.db().dialogs["d_hazard_" + hz["kind"]][0]["text"]))
		hud.hazard_tint(true)
		if st.hp <= 0.0 and not player.is_dead():
			player.take_damage(1.0)
	else:
		hud.hazard_tint(false)
	# partículas ambientes seguem a câmera
	if _particles != null:
		_particles.global_position = player.global_position + Vector3(0, 6, 0)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.12
		_scan_target()
		if build_mode:
			_update_ghost()
	_update_sparks()
	_update_tut_arrow()
	_update_requirements(delta)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 4.0
		_maintain_spawns()
		_check_boss()
		_respawn_nodes()
	_work_t -= delta
	if _work_t <= 0.0:
		_work_t = 5.0
		_tick_work()
	_heal_t -= delta
	if _heal_t <= 0.0:
		_heal_t = 1.0
		_spring_heal()
	st.pos = player.global_position
	st.has_pos = true
	_quest_intro()


func _quest_intro() -> void:
	## Fala de abertura da missão atual (uma vez). Falas curtas da Lume viram dica em balão.
	var st: GameState = Game.state
	if st.quest_seen_dialog or st.is_sandbox() or hud.modal_open():
		return
	var q := QuestLogic.current(st)
	if q.is_empty():
		return
	st.quest_seen_dialog = true
	var did: Variant = q.get("dialog")
	if did == null or q["id"] == "q01":
		return
	var lines: Array = GameData.db().dialogs.get(did, [])
	if lines.size() == 1 and lines[0]["who"] == "lume":
		hud.lume_hint(Loc.tx(lines[0]["text"]), 9.0)
	else:
		hud.show_dialog(did, Callable())


func _maintain_spawns() -> void:
	var want := int(md["spawn_count"])
	if Game.is_peaceful():
		want = int(want * 0.6)
	# remove os muito distantes
	for w in wilds.duplicate():
		if not is_instance_valid(w):
			wilds.erase(w)
			continue
		if w.global_position.distance_to(player.global_position) > float(GameData.db().cfg("world", "despawn_range", 90)) and w.state != "chase":
			wilds.erase(w)
			w.queue_free()
	if wilds.size() < want:
		_spawn_wild()


func _respawn_nodes() -> void:
	var ms := Game.state.map_state(map_id)
	var now := Game.now()
	for k in ms["harvested"].keys():
		if int(ms["harvested"][k]) <= now:
			ms["harvested"].erase(k)
			if nodes.has(k):
				var n: ResourceNode = nodes[k]
				if n.global_position.distance_to(player.global_position) > 12.0:
					n.set_harvested(false)
				else:
					ms["harvested"][k] = now + 30


func _tick_work() -> void:
	var st: GameState = Game.state
	var mult := float(Game.rc.get("work_mult", 1.0))
	for uid in structures:
		var s: Structure = structures[uid]
		if s.bd.has("work"):
			WorkLogic.tick(st, s.entry, Game.now(), mult)
			s.refresh_worker()
			s.update_stock()


func _spring_heal() -> void:
	var st: GameState = Game.state
	for uid in structures:
		var s: Structure = structures[uid]
		if s.bd.get("special", "") != "heal":
			continue
		if s.global_position.distance_to(player.global_position) < 8.0:
			for m in st.party_monsters():
				if m["fainted"]:
					MonsterLogic.heal(m, 0.25, true)
				else:
					MonsterLogic.heal(m, 0.1)
			if ally != null and is_instance_valid(ally):
				ally.heal_frac(0.0)
			elif st.first_healthy_in_party() >= 0:
				_spawn_ally()


func sync_to_state() -> void:
	if player != null and is_instance_valid(player):
		Game.state.pos = player.global_position
		Game.state.has_pos = true
		Game.state.map_id = map_id


func _update_held() -> void:
	var w := Game.state.inv.best_weapon_id()
	player.model.set_held(w)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rig.rotate_by(ev.relative)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom_by(0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom_by(1.1)
	elif ev.is_action_pressed("action"):
		on_action()
	elif ev.is_action_pressed("jump"):
		player.jump()
	elif ev.is_action_pressed("sphere"):
		throw_sphere()
	elif ev.is_action_pressed("skill1"):
		ally_skill(0)
	elif ev.is_action_pressed("skill2"):
		ally_skill(1)
	elif ev.is_action_pressed("switch"):
		cycle_ally()
	elif ev.is_action_pressed("menu"):
		hud.open_menu("inventory")
	elif ev.is_action_pressed("build"):
		hud.open_build()
