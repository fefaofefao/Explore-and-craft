class_name TutorialRing
extends Control
## Anel pulsante desenhado em volta de um botão para guiar o jogador no tutorial.

var target: Control
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50


func _process(delta: float) -> void:
	_t += delta
	visible = target != null and is_instance_valid(target) and target.is_visible_in_tree()
	if visible:
		var r := target.get_global_rect()
		global_position = r.position - Vector2(30, 30)
		size = r.size + Vector2(60, 60)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c := size * 0.5
	var base := minf(size.x, size.y) * 0.5 - 30.0
	for k in 2:
		var f := fmod(_t * 0.9 + k * 0.5, 1.0)
		var rad := base + 6.0 + f * 26.0
		draw_arc(c, rad, 0, TAU, 48, Color(1.0, 0.86, 0.3, 1.0 - f), 5.0 - f * 3.0, true)
	draw_arc(c, base + 4.0, 0, TAU, 48, Color(1.0, 0.9, 0.4, 0.6 + 0.4 * sin(_t * 6.0)), 3.0, true)
