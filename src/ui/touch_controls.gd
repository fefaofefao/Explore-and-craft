class_name TouchControls
extends Control
## Joystick virtual dinâmico (metade esquerda) + arrastar para girar a câmera (metade direita) + pinça para zoom.
## Toques que começam sobre botões do HUD não chegam aqui (os botões consomem o evento).

signal look(delta: Vector2)
signal zoom(factor: float)

var move := Vector2.ZERO
var _move_idx := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _look_idx := -1
var _look_last := Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_d := 0.0
const RADIUS := 90.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if t.position.x < size.x * 0.45 and _move_idx < 0:
				_move_idx = t.index
				_move_origin = t.position
				_move_pos = t.position
			elif _look_idx < 0:
				_look_idx = t.index
				_look_last = t.position
		else:
			_touches.erase(t.index)
			if t.index == _move_idx:
				_move_idx = -1
				move = Vector2.ZERO
			if t.index == _look_idx:
				_look_idx = -1
			_pinch_d = 0.0
		queue_redraw()
		accept_event()
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		_touches[d.index] = d.position
		if d.index == _move_idx:
			_move_pos = d.position
			var v := (_move_pos - _move_origin)
			if v.length() > RADIUS:
				_move_origin = _move_pos - v.normalized() * RADIUS  # o joystick acompanha o dedo
				v = v.normalized() * RADIUS
			move = v / RADIUS
			queue_redraw()
		elif d.index == _look_idx:
			# pinça com dois dedos no lado direito
			var others: Array = []
			for k in _touches:
				if k != _move_idx:
					others.append(_touches[k])
			if others.size() >= 2:
				var dist: float = others[0].distance_to(others[1])
				if _pinch_d > 0.0:
					emit_signal("zoom", _pinch_d / maxf(dist, 1.0))
				_pinch_d = dist
			else:
				emit_signal("look", d.position - _look_last)
			_look_last = d.position
		accept_event()


func _draw() -> void:
	if _move_idx >= 0:
		draw_circle(_move_origin, RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(_move_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		draw_circle(_move_origin + move * RADIUS, 38, Color(1, 1, 1, 0.45))
	else:
		# dica do joystick em repouso
		var p := Vector2(size.x * 0.13, size.y * 0.72)
		draw_arc(p, 70, 0, TAU, 40, Color(1, 1, 1, 0.12), 3.0, true)
		draw_circle(p, 30, Color(1, 1, 1, 0.10))
