class_name ResourceNode
extends Node3D
## Recurso coletável (árvore, rocha, minério, arbusto...) ou barreira de progressão (espinhos, gelo, jaula).

var key: String
var kind: String
var nd: Dictionary
var hp: float
var harvested := false
var mesh_i: MeshInstance3D
var body: StaticBody3D
var cage_index := -1
var _shake := 0.0
var _base_rot := 0.0

const SOLID := ["arvore", "pinheiro", "palmeira", "arvore_morta", "rocha", "minerio", "carvao_veio", "cristal", "cacto",
	"bloco_gelo", "obsidiana_veio", "espinhos", "muro_gelo", "porta_solar", "jaula"]


func setup(p_key: String, p_kind: String, tint: Color, scl: float, rot: float) -> ResourceNode:
	key = p_key
	kind = p_kind
	nd = GameData.db().nodes[kind]
	hp = float(nd["hp"])
	_base_rot = rot
	mesh_i = MeshInstance3D.new()
	mesh_i.mesh = MeshLib.get_mesh(kind, hash(key) % 3, tint)
	mesh_i.material_override = MeshLib.mat("glow" if kind == "cristal" else ("vc_ds" if kind == "palmeira" else "vc"))
	mesh_i.rotation.y = rot
	mesh_i.scale = Vector3.ONE * scl
	mesh_i.visibility_range_end = 95.0
	mesh_i.visibility_range_end_margin = 8.0
	mesh_i.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if kind in ["capim", "cogumelos", "lodo_poca", "monte_areia", "ninho_pena"]:
		mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_i.visibility_range_end = 55.0
	add_child(mesh_i)
	if kind in SOLID:
		body = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var r := 0.4 * scl
		var h := 3.0
		match kind:
			"rocha", "minerio", "carvao_veio", "obsidiana_veio", "bloco_gelo":
				r = 1.0 * scl
				h = 1.4 * scl
			"cristal":
				r = 0.6 * scl
				h = 1.8
			"espinhos":
				r = 1.0
				h = 2.0
			"muro_gelo", "porta_solar":
				var bx := BoxShape3D.new()
				bx.size = Vector3(3.2 if kind == "porta_solar" else 2.2, 4.0, 1.2)
				cs.shape = bx
				cs.position.y = 2.0
				cs.rotation.y = rot
			"jaula":
				r = 1.1
				h = 2.4
		if cs.shape == null:
			var cyl := CylinderShape3D.new()
			cyl.radius = r
			cyl.height = h
			cs.shape = cyl
			cs.position.y = h * 0.5
		body.add_child(cs)
		add_child(body)
	return self


func is_barrier() -> bool:
	return nd.get("barrier", false)


func interact_pos() -> Vector3:
	return global_position


func interact_range() -> float:
	match kind:
		"rocha", "minerio", "carvao_veio", "obsidiana_veio", "bloco_gelo", "espinhos", "jaula":
			return 3.4
		"muro_gelo", "porta_solar":
			return 4.0
	return 2.6


func required_tool() -> String:
	return nd["tool"]


func hit(power: float) -> bool:
	## Aplica dano; devolve true se esgotou.
	if harvested:
		return false
	hp -= power
	_shake = 0.25
	var col := Color("#a0703c")
	if kind in ["rocha", "minerio", "carvao_veio", "obsidiana_veio"]:
		col = Color("#9a948c")
	elif kind in ["cristal", "bloco_gelo", "muro_gelo"]:
		col = Color("#bff4ff")
	elif kind in ["arbusto", "capim", "cacto", "espinhos"]:
		col = Color("#6cbf4a")
	FX.burst(get_parent(), global_position + Vector3(0, 1.0, 0), col, 8, 3.5)
	return hp <= 0.0


func set_harvested(v: bool) -> void:
	harvested = v
	visible = not v
	if body != null:
		body.process_mode = Node.PROCESS_MODE_DISABLED if v else Node.PROCESS_MODE_INHERIT
		for c in body.get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", v)
	if not v:
		hp = float(nd["hp"])
		scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		mesh_i.rotation.z = sin(_shake * 60.0) * 0.08 * (_shake / 0.25)
		mesh_i.rotation.y = _base_rot
	elif mesh_i.rotation.z != 0.0:
		mesh_i.rotation.z = 0.0
