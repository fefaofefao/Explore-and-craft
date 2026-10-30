class_name CameraRig
extends Node3D
## Câmera em terceira pessoa: segue o alvo com suavização, gira por toque/mouse, desvia do terreno.

var target: Node3D
var yaw := 0.0
var pitch := -0.38
var distance := 7.5
var min_dist := 3.5
var max_dist := 13.0
var sens := 1.0
var arm: SpringArm3D
var cam: Camera3D
var shake := 0.0
var _look_target := Vector3.ZERO


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.collision_mask = 1
	arm.margin = 0.4
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	arm.shape = sh
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 260.0
	cam.near = 0.1
	arm.add_child(cam)
	cam.current = true


func rotate_by(d: Vector2) -> void:
	yaw -= d.x * 0.006 * sens
	pitch = clampf(pitch - d.y * 0.004 * sens, -1.25, 0.35)


func zoom_by(f: float) -> void:
	distance = clampf(distance * f, min_dist, max_dist)


func snap() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 1.6, 0)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var want := target.global_position + Vector3(0, 1.6, 0)
	global_position = global_position.lerp(want, clampf(delta * 10.0, 0.0, 1.0))
	rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = lerpf(arm.spring_length, distance, clampf(delta * 6.0, 0.0, 1.0))
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
		cam.h_offset = randf_range(-1, 1) * shake * 0.25
		cam.v_offset = randf_range(-1, 1) * shake * 0.25
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))
