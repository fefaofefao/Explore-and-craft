class_name Npc
extends Node3D
## Personagem não jogável: capitães/ditadores (treinadores), moradores, mercador, barqueira, quadro de missões.

var kind := "villager"  # trainer | villager | merchant | board | expedition | ferry
var tid := ""
var display_name := ""
var model: HumanoidModel
var _t := 0.0
var _wander_center := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _walk := false
var gen: WorldGen
var _label: Label3D


func setup(p_kind: String, p_name: String, outfit: Color, extra: Dictionary = {}) -> Npc:
	kind = p_kind
	display_name = p_name
	var cfg := {"outfit": outfit, "outfit2": outfit.lightened(0.4), "backpack": false}
	var hair_cols := [Color("#2a1d18"), Color("#6a3a1a"), Color("#d8b060"), Color("#1a1a2a"), Color("#a83a2a"), Color("#e8e8f0")]
	var skins := [Color("#f0c8a0"), Color("#d8a070"), Color("#a86a40"), Color("#6a4028"), Color("#f8dcc0")]
	var h := hash(p_name)
	cfg["hair"] = hair_cols[h % hair_cols.size()]
	cfg["skin"] = skins[(h / 7) % skins.size()]
	for k in extra:
		cfg[k] = extra[k]
	model = HumanoidModel.new().configure(cfg).build()
	if kind == "trainer" and extra.get("hat", "") == "crown":
		model.scale = Vector3.ONE * 1.15
	add_child(model)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	add_child(body)
	_label = Label3D.new()
	_label.text = p_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UiTheme.font(800)
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.position.y = 2.35
	_label.modulate = UiTheme.GOLD if kind == "trainer" else Color.WHITE
	_label.visible = kind != "villager"
	add_child(_label)
	return self


func set_label(t: String) -> void:
	_label.text = t


func enable_wander(p_gen: WorldGen) -> void:
	gen = p_gen
	_walk = true
	_wander_center = global_position
	_wander_to = global_position


func interact_pos() -> Vector3:
	return global_position


func interact_range() -> float:
	return 3.2


func face(p: Vector3) -> void:
	var d := p - global_position
	model.rotation.y = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	_t += delta
	if not _walk or gen == null:
		model.move_speed = 0.0
		return
	var d := _wander_to - global_position
	d.y = 0
	if d.length() < 0.4:
		model.move_speed = 0.0
		if randf() < delta * 0.4:
			var a := randf() * TAU
			_wander_to = _wander_center + Vector3(cos(a), 0, sin(a)) * randf_range(2, 9)
	else:
		var step := d.normalized() * 1.6 * delta
		global_position += step
		global_position.y = gen.height(global_position.x, global_position.z)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), 0.15)
		model.move_speed = 0.35
