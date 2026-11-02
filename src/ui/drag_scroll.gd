class_name DragScroll
extends ScrollContainer
## Rolagem por arrastar que funciona em celular mesmo começando o gesto em cima de botões e cartões.
## O arrasto é detectado em _input; ao passar da zona morta, o gesto vira rolagem e o soltar não aciona o botão.

const DEADZONE := 14.0
var _press := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _vel := Vector2.ZERO
var _faking := false


func _ready() -> void:
	scroll_deadzone = 1000  # desliga o arrasto nativo (nós cuidamos dele)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			if get_global_rect().has_point(mb.position) and _topmost_here(mb.position):
				_press = true
				_dragging = false
				_start = mb.position
				_last = mb.position
				_vel = Vector2.ZERO
		else:
			if _faking and mb.position.x < -5000.0:
				_faking = false  # é o nosso soltar falso: deixa o botão cancelar o clique e segue rolando
				return
			if _dragging:
				get_viewport().set_input_as_handled()  # não clica no botão onde o dedo soltou
			_press = false
			_dragging = false
	elif ev is InputEventMouseMotion and _press:
		var mm := ev as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_start) > DEADZONE:
			_dragging = true
			# cancela o toque no botão que estava embaixo do dedo: um "soltar" fora da tela
			_faking = true
			call_deferred("_fake_release")
		if _dragging:
			var d := mm.position - _last
			if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				scroll_vertical -= int(d.y)
			if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				scroll_horizontal -= int(d.x)
			_vel = d
			get_viewport().set_input_as_handled()
		_last = mm.position


func _process(delta: float) -> void:
	# inércia depois de soltar
	if not _press and _vel.length() > 0.5:
		if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll_vertical -= int(_vel.y)
		if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll_horizontal -= int(_vel.x)
		_vel *= 0.9


func _topmost_here(p: Vector2) -> bool:
	## Evita rolar dois contêineres aninhados ao mesmo tempo: só o mais interno responde.
	for c in find_children("*", "DragScroll", true, false):
		if c != self and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(p):
			return false
	return true


func _fake_release() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = Vector2(-9999, -9999)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
