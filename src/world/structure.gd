class_name Structure
extends Node3D
## Peça construída pelo jogador: estrutura (fundação, parede, telhado...), estação de criação,
## máquina de trabalho de Ecos, cama, baú ou Fonte de Cura.

var entry: Dictionary
var bd: Dictionary
var worker_model: MonsterModel
var _worker_uid := -1
var _stock_label: Label3D
var _fire: CPUParticles3D
var _t := 0.0

const WOOD := Color("#b08050")
const WOOD_D := Color("#7a5232")
const STONE := Color("#a8a49c")
const THATCH := Color("#d8b860")


func setup(p_entry: Dictionary) -> Structure:
	entry = p_entry
	bd = GameData.db().buildings[entry["id"]]
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh(entry["id"])
	mi.material_override = MeshLib.mat("vc_ds" if bd["shape"] == "roof" else "vc")
	add_child(mi)
	rotation.y = -float(entry["rot"]) * PI / 2.0
	_add_collision()
	if bd.get("light", false):
		var l := OmniLight3D.new()
		l.light_color = Color("#ffb060") if entry["id"] != "bancada_arcana" and entry["id"] != "fonte_cura" else Color("#7ff0ff")
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.position.y = 1.4
		add_child(l)
	if entry["id"] in ["fogueira", "fornalha", "forja", "tocha_poste"]:
		_fire = CPUParticles3D.new()
		_fire.amount = 18
		_fire.lifetime = 0.8
		_fire.mesh = MonsterModel._sph(0.12, 6)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color("#ffb02a")
		fm.emission_enabled = true
		fm.emission = Color("#ff6a1a")
		fm.emission_energy_multiplier = 2.5
		_fire.material_override = fm
		_fire.direction = Vector3.UP
		_fire.spread = 12
		_fire.gravity = Vector3(0, 2.0, 0)
		_fire.initial_velocity_min = 0.3
		_fire.initial_velocity_max = 0.8
		_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_fire.emission_sphere_radius = 0.25
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		_fire.scale_amount_curve = curve
		_fire.position.y = {"fogueira": 0.35, "fornalha": 0.9, "forja": 1.0, "tocha_poste": 2.4}[entry["id"]]
		add_child(_fire)
	if bd.has("work"):
		_stock_label = Label3D.new()
		_stock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_stock_label.font = UiTheme.font(800)
		_stock_label.font_size = 36
		_stock_label.pixel_size = 0.006
		_stock_label.outline_size = 10
		_stock_label.position.y = 2.7
		add_child(_stock_label)
		refresh_worker()
	return self


func _add_collision() -> void:
	var shape: String = bd["shape"]
	if shape in ["roof", "torchpost"]:
		return
	var b := StaticBody3D.new()
	b.collision_layer = 2
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	match shape:
		"foundation":
			bx.size = Vector3(2.0, 0.5, 2.0)
			cs.position.y = 0.25
		"wall", "window":
			bx.size = Vector3(2.0, 2.6, 0.25)
			cs.position = Vector3(0, 1.3, -0.95)
		"door":
			return  # porta não bloqueia (passagem)
		"fence":
			bx.size = Vector3(2.0, 1.0, 0.2)
			cs.position = Vector3(0, 0.5, -0.95)
		_:
			bx.size = Vector3(1.6, 1.2, 1.6)
			cs.position.y = 0.6
	cs.shape = bx
	b.add_child(cs)
	add_child(b)


func is_station() -> bool:
	return bd.has("station")


func interact_pos() -> Vector3:
	return global_position


func interact_range() -> float:
	return 3.0


func interactive() -> bool:
	return bd.has("station") or bd.has("work") or bd.has("special")


func refresh_worker() -> void:
	var w := int(entry["data"].get("worker", -1))
	if w == _worker_uid:
		return
	_worker_uid = w
	if worker_model != null:
		worker_model.queue_free()
		worker_model = null
	if w >= 0:
		var m := Game.state.get_monster(w)
		if not m.is_empty():
			worker_model = MonsterModel.new().build(m["sp"], m.get("variant", false))
			var s := 1.0 / maxf(1.0, float(GameData.db().sp(m["sp"])["body"]["size"]))
			worker_model.scale = Vector3.ONE * s * 0.9
			worker_model.position = Vector3(0.9, 0, 0.9)
			add_child(worker_model)


func update_stock() -> void:
	if _stock_label == null:
		return
	var tot := WorkLogic.stored_total(entry)
	var cap := int(GameData.db().config["work"]["station_capacity"])
	_stock_label.text = "%s  %d/%d" % [Loc.tx(bd["name"]), tot, cap] if _worker_uid >= 0 or tot > 0 else Loc.tx(bd["name"])
	_stock_label.modulate = UiTheme.GOLD if tot >= cap else (UiTheme.GOOD if tot > 0 else Color.WHITE)


func _process(delta: float) -> void:
	_t += delta
	if worker_model != null:
		worker_model.move_speed = 0.5 + sin(_t * 2.0) * 0.3
		if fmod(_t, 2.5) < delta:
			worker_model.play_attack()


static func build_mesh(id: String) -> ArrayMesh:
	var key := "struct_" + id
	if MeshLib._meshes.has(key):
		return MeshLib._meshes[key]
	var b: Dictionary = GameData.db().buildings[id]
	var mb := MeshBuilder.new(hash(id))
	mb.jitter = 1.0
	var mat_kind: String = b.get("mat", "wood")
	var main := WOOD if mat_kind == "wood" else (STONE if mat_kind == "stone" else THATCH)
	match b["shape"]:
		"foundation":
			mb.box(Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 2.0), main.darkened(0.1), 0.0, main)
			for i in 4:
				mb.box(Vector3(-0.75 + i * 0.5, 0.505, 0), Vector3(0.04, 0.01, 1.96), main.darkened(0.25))
		"wall":
			mb.box(Vector3(0, 1.3, -0.95), Vector3(2.0, 2.6, 0.2), main)
			if mat_kind == "wood":
				for i in 5:
					mb.box(Vector3(0, 0.25 + i * 0.52, -0.84), Vector3(2.0, 0.06, 0.02), WOOD_D)
			mb.box(Vector3(-0.95, 1.3, -0.95), Vector3(0.14, 2.6, 0.28), WOOD_D)
			mb.box(Vector3(0.95, 1.3, -0.95), Vector3(0.14, 2.6, 0.28), WOOD_D)
		"window":
			mb.box(Vector3(0, 0.45, -0.95), Vector3(2.0, 0.9, 0.2), main)
			mb.box(Vector3(0, 2.3, -0.95), Vector3(2.0, 0.6, 0.2), main)
			mb.box(Vector3(-0.75, 1.45, -0.95), Vector3(0.5, 1.1, 0.2), main)
			mb.box(Vector3(0.75, 1.45, -0.95), Vector3(0.5, 1.1, 0.2), main)
			mb.box(Vector3(0, 1.45, -0.95), Vector3(1.0, 1.1, 0.06), Color("#bfefff"))
		"door":
			mb.box(Vector3(-0.8, 1.3, -0.95), Vector3(0.4, 2.6, 0.2), main)
			mb.box(Vector3(0.8, 1.3, -0.95), Vector3(0.4, 2.6, 0.2), main)
			mb.box(Vector3(0, 2.35, -0.95), Vector3(1.2, 0.5, 0.2), main)
			mb.box(Vector3(-0.3, 1.05, -0.85), Vector3(0.6, 2.1, 0.08), WOOD_D, 0.6)
		"roof":
			var y := 2.7
			mb.quad(Vector3(-1.1, y, 1.1), Vector3(1.1, y, 1.1), Vector3(1.1, y + 0.9, 0), Vector3(-1.1, y + 0.9, 0), main)
			mb.quad(Vector3(1.1, y, -1.1), Vector3(-1.1, y, -1.1), Vector3(-1.1, y + 0.9, 0), Vector3(1.1, y + 0.9, 0), main.darkened(0.12))
		"fence":
			for x in [-0.9, 0.0, 0.9]:
				mb.box(Vector3(x, 0.5, -0.95), Vector3(0.14, 1.0, 0.14), WOOD_D)
			mb.box(Vector3(0, 0.75, -0.95), Vector3(2.0, 0.1, 0.06), WOOD)
			mb.box(Vector3(0, 0.4, -0.95), Vector3(2.0, 0.1, 0.06), WOOD)
		"torchpost":
			mb.cylinder(Vector3.ZERO, 0.08, 0.07, 2.2, 5, WOOD_D)
			mb.box(Vector3(0, 2.25, 0), Vector3(0.22, 0.2, 0.22), Color("#3a3a3a"))
		"campfire":
			for i in 8:
				var a := TAU * i / 8.0
				mb.sphere(Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(0.18, 0.13, 0.18), STONE, 2, 5, 0.2)
			for i in 3:
				var a := TAU * i / 3.0
				mb.cylinder(Vector3(cos(a) * 0.35, 0.05, sin(a) * 0.35), 0.08, 0.06, 0.6, 5, WOOD_D, true, Vector3(-cos(a) * 0.4, 0, -sin(a) * 0.4))
		"bench":
			mb.box(Vector3(0, 0.85, 0), Vector3(1.8, 0.14, 1.0), WOOD, 0.0, WOOD.lightened(0.1))
			for p in [Vector3(-0.75, 0.4, -0.4), Vector3(0.75, 0.4, -0.4), Vector3(-0.75, 0.4, 0.4), Vector3(0.75, 0.4, 0.4)]:
				mb.box(p, Vector3(0.12, 0.8, 0.12), WOOD_D)
			mb.box(Vector3(-0.4, 1.0, 0.1), Vector3(0.5, 0.16, 0.3), STONE)
			mb.box(Vector3(0.45, 0.97, -0.1), Vector3(0.06, 0.08, 0.6), Color("#c8ccd4"))
		"furnace":
			mb.box(Vector3(0, 0.7, 0), Vector3(1.5, 1.4, 1.4), STONE, 0.0, STONE.lightened(0.1))
			mb.cone(Vector3(0, 1.4, 0), 0.75, 0.6, 6, STONE.darkened(0.1))
			mb.cylinder(Vector3(0, 1.9, 0), 0.22, 0.2, 0.7, 6, STONE.darkened(0.2))
			mb.box(Vector3(0, 0.55, -0.71), Vector3(0.6, 0.5, 0.04), Color("#ff8a2a"))
		"forge":
			mb.box(Vector3(-0.4, 0.6, 0), Vector3(1.0, 1.2, 1.2), STONE)
			mb.box(Vector3(-0.4, 0.55, -0.61), Vector3(0.5, 0.4, 0.04), Color("#ff6a1a"))
			mb.box(Vector3(0.65, 0.35, 0), Vector3(0.35, 0.7, 0.35), Color("#5a5a62"))
			mb.box(Vector3(0.65, 0.78, 0), Vector3(0.75, 0.22, 0.4), Color("#6a6a74"), 0.0, Color("#8a8a96"))
		"arcane":
			mb.box(Vector3(0, 0.85, 0), Vector3(1.8, 0.14, 1.0), Color("#5a4a7a"), 0.0, Color("#7a6aa0"))
			for p in [Vector3(-0.75, 0.4, -0.4), Vector3(0.75, 0.4, -0.4), Vector3(-0.75, 0.4, 0.4), Vector3(0.75, 0.4, 0.4)]:
				mb.box(p, Vector3(0.12, 0.8, 0.12), Color("#3a2a5a"))
			mb.octa(Vector3(0, 1.5, 0), 0.22, 0.6, Color("#7ff0ff"))
		"bed":
			mb.box(Vector3(0, 0.3, 0), Vector3(1.2, 0.4, 2.0), WOOD_D)
			mb.box(Vector3(0, 0.55, 0.2), Vector3(1.1, 0.15, 1.5), Color("#c84a4a"), 0.0, Color("#e86a6a"))
			mb.box(Vector3(0, 0.6, -0.7), Vector3(0.9, 0.18, 0.4), Color("#f0e8d8"))
			mb.box(Vector3(0, 0.75, -0.98), Vector3(1.2, 0.9, 0.1), WOOD_D)
		"chest":
			mb.box(Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 0.75), WOOD, 0.0, WOOD.lightened(0.1))
			mb.box(Vector3(0, 0.72, 0), Vector3(1.14, 0.08, 0.79), WOOD_D)
			mb.box(Vector3(0, 0.5, -0.38), Vector3(0.16, 0.2, 0.04), Color("#ffd04a"))
		"spring":
			mb.cylinder(Vector3.ZERO, 1.0, 0.95, 0.6, 10, STONE)
			mb.cylinder(Vector3(0, 0.55, 0), 0.8, 0.8, 0.06, 10, Color("#7ff0ff"))
			mb.cylinder(Vector3(0, 0.6, 0), 0.15, 0.12, 0.9, 6, STONE.lightened(0.1))
			mb.octa(Vector3(0, 1.55, 0), 0.18, 0.5, Color("#7ff0ff"))
		"sawmill":
			mb.box(Vector3(0, 0.5, 0), Vector3(1.8, 0.2, 1.0), WOOD)
			for p in [Vector3(-0.8, 0.2, -0.4), Vector3(0.8, 0.2, -0.4), Vector3(-0.8, 0.2, 0.4), Vector3(0.8, 0.2, 0.4)]:
				mb.box(p, Vector3(0.12, 0.4, 0.12), WOOD_D)
			mb.cylinder(Vector3(-0.2, 0.62, 0), 0.25, 0.25, 0.1, 10, Color("#c8ccd4"), true)
			mb.cylinder(Vector3(0.5, 0.6, 0.0), 0.18, 0.18, 0.9, 6, WOOD_D, true, Vector3(0, 0, 0))
			for i in 3:
				mb.cylinder(Vector3(-0.6 + i * 0.4, 0, 0.75), 0.15, 0.15, 0.8, 6, WOOD, true)
		"quarry":
			for i in 5:
				mb.sphere(Vector3(-0.5 + (i % 3) * 0.5, 0.25 + (i / 3) * 0.3, (i % 2) * 0.3 - 0.15), Vector3(0.3, 0.25, 0.3), STONE, 2, 5, 0.25)
			mb.box(Vector3(0.7, 0.9, 0), Vector3(0.12, 1.8, 0.12), WOOD_D)
			mb.box(Vector3(0.3, 1.75, 0), Vector3(0.9, 0.12, 0.12), WOOD_D)
		"garden":
			mb.box(Vector3(0, 0.1, 0), Vector3(1.8, 0.2, 1.8), Color("#6a4a2a"), 0.0, Color("#5a3a20"))
			for i in 9:
				var p := Vector3(-0.55 + (i % 3) * 0.55, 0.2, -0.55 + (i / 3) * 0.55)
				mb.sphere(p + Vector3(0, 0.15, 0), Vector3(0.18, 0.2, 0.18), Color("#5fbf4a"), 2, 5, 0.2)
				if i % 2 == 0:
					mb.sphere(p + Vector3(0.08, 0.3, 0), Vector3(0.06, 0.06, 0.06), Color("#e8344a"), 2, 4)
		"mine":
			mb.box(Vector3(-0.8, 1.0, 0), Vector3(0.2, 2.0, 0.2), WOOD_D)
			mb.box(Vector3(0.8, 1.0, 0), Vector3(0.2, 2.0, 0.2), WOOD_D)
			mb.box(Vector3(0, 2.05, 0), Vector3(1.9, 0.25, 0.3), WOOD_D)
			mb.sphere(Vector3(0, 0.6, 0.5), Vector3(1.0, 0.9, 0.7), STONE.darkened(0.15), 3, 6, 0.2)
			mb.box(Vector3(0, 0.75, -0.05), Vector3(1.2, 1.4, 0.05), Color("#1a1a20"))
		"smelter":
			mb.cylinder(Vector3.ZERO, 0.8, 0.6, 1.6, 8, Color("#b85a3a"))
			mb.cylinder(Vector3(0, 1.6, 0), 0.25, 0.2, 0.9, 6, STONE.darkened(0.2))
			mb.box(Vector3(0, 0.5, -0.72), Vector3(0.5, 0.4, 0.06), Color("#ff8a2a"))
		"ranch":
			for i in 8:
				var a := TAU * i / 8.0
				mb.box(Vector3(cos(a) * 0.9, 0.4, sin(a) * 0.9), Vector3(0.1, 0.8, 0.1), WOOD_D)
			mb.cylinder(Vector3(0, 0, 0), 0.35, 0.3, 0.5, 8, THATCH)
		_:
			mb.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var m := mb.commit()
	MeshLib._meshes[key] = m
	return m
