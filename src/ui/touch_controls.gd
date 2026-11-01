class_name TouchControls
extends Control
## Controles de toque com MULTITOQUE: joystick dinâmico (esquerda), arrastar para girar a câmera (direita),
## pinça para zoom e botões de ação (atacar, pular, esfera, habilidades) que funcionam com outro dedo
## no joystick. Os botões do Godot só respondem ao primeiro dedo; por isso os botões de ação são
## registrados aqui e acionados direto pelos eventos de toque.

signal look(delta: Vector2)
signal zoom(factor: float)

var move := Vector2.ZERO
var blocked: Callable  # devolve true quando há menu/diálogo aberto
var _move_idx := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _look_idx := -1
var _look_last := Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_d := 0.0
var _buttons: Array = []  # {"ctrl", "down", "up", "idx"}
const RADIUS := 90.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func register_button(ctrl: Control, down: Callable, up: Callable = Callable()) -> void:
	## O botão deixa de receber eventos do Godot; este controle cuida dele (com qualquer dedo).
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in ctrl.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.append({"ctrl": ctrl, "down": down, "up": up, "idx": -1})


func _is_blocked() -> bool:
	return blocked.is_valid() and blocked.call()


func _button_at(pos: Vector2) -> Dictionary:
	for b in _buttons:
		var c: Control = b["ctrl"]
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		# área de toque um pouco maior que o botão (dedos)
		if r.grow(10.0).has_point(pos):
			if c is Button and (c as Button).disabled:
				return {}
			return b
	return {}


func _release_all() -> void:
	for b in _buttons:
		if int(b["idx"]) >= 0:
			b["idx"] = -1
			(b["ctrl"] as Control).scale = Vector2.ONE
			if (b["up"] as Callable).is_valid():
				b["up"].call()
	_move_idx = -1
	_look_idx = -1
	move = Vector2.ZERO
	_touches.clear()
	queue_redraw()


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventScreenTouch or ev is InputEventScreenDrag):
		return
	if _is_blocked():
		if _move_idx >= 0 or _look_idx >= 0 or not _touches.is_empty():
			_release_all()
		return
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			var b := _button_at(t.position)
			if not b.is_empty():
				b["idx"] = t.index
				var c: Control = b["ctrl"]
				c.pivot_offset = c.size * 0.5
				c.scale = Vector2(0.9, 0.9)
				b["down"].call()
				get_viewport().set_input_as_handled()
				return
			if _over_other_ui(t.position):
				return
			_touches[t.index] = t.position
			if t.position.x < size.x * 0.45 and t.position.y > size.y * 0.3 and _move_idx < 0:
				_move_idx = t.index
				_move_origin = t.position
				_move_pos = t.position
			elif _look_idx < 0:
				_look_idx = t.index
				_look_last = t.position
		else:
			for b in _buttons:
				if int(b["idx"]) == t.index:
					b["idx"] = -1
					(b["ctrl"] as Control).scale = Vector2.ONE
					if (b["up"] as Callable).is_valid():
						b["up"].call()
			_touches.erase(t.index)
			if t.index == _move_idx:
				_move_idx = -1
				move = Vector2.ZERO
			if t.index == _look_idx:
				_look_idx = -1
			_pinch_d = 0.0
		queue_redraw()
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if not _touches.has(d.index):
			return
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


func _over_other_ui(pos: Vector2) -> bool:
	## Toques que começam sobre outros controles interativos (painéis, botões do topo) não movem a câmera.
	var root_ui := get_parent()
	if root_ui == null:
		return false
	var stack: Array = [root_ui]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		if c == self:
			continue
		if c is Control and c != root_ui:
			var cc := c as Control
			if cc.is_visible_in_tree() and cc.mouse_filter == Control.MOUSE_FILTER_STOP and cc.get_global_rect().has_point(pos):
				return true
		for ch in c.get_children():
			stack.append(ch)
	return false


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
