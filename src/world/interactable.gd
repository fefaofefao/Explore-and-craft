class_name Interactable
extends Node3D
## Ponto de interação genérico: portal, fragmento de memória, Berço, altar, quadro de missões etc.

var kind := ""
var data: Dictionary = {}
var label_text := ""
var range_m := 3.0
var _bob_node: Node3D
var _t := 0.0


func setup(p_kind: String, p_data: Dictionary, p_label: String, p_range: float = 3.0) -> Interactable:
	kind = p_kind
	data = p_data
	label_text = p_label
	range_m = p_range
	return self


func add_mesh(key: String, mat_kind: String = "vc", tint: Color = Color.WHITE, scl: float = 1.0, bob: bool = false, collide: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.get_mesh(key, 0, tint)
	mi.material_override = MeshLib.mat(mat_kind)
	mi.scale = Vector3.ONE * scl
	add_child(mi)
	if bob:
		_bob_node = mi
	if collide != Vector3.ZERO:
		var b := StaticBody3D.new()
		b.collision_layer = 2
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = collide
		cs.shape = bx
		cs.position.y = collide.y * 0.5
		b.add_child(cs)
		add_child(b)
	return mi


func add_light(c: Color, energy: float = 1.5, rng: float = 6.0, y: float = 1.5) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.position.y = y
	l.shadow_enabled = false
	add_child(l)
	return l


func interact_pos() -> Vector3:
	return global_position


func interact_range() -> float:
	return range_m


func _process(delta: float) -> void:
	if _bob_node != null:
		_t += delta
		_bob_node.position.y = 0.4 + sin(_t * 2.0) * 0.2
		_bob_node.rotation.y += delta * 1.2
