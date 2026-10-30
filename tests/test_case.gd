class_name TestCase
extends RefCounted
## Base mínima de testes: métodos test_* são executados por tests/run_tests.gd.

var failures: Array = []
var asserts: int = 0
var current: String = ""


func check(cond: bool, msg: String = "") -> void:
	asserts += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg: String = "") -> void:
	asserts += 1
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		if absf(float(a) - float(b)) > 0.0001:
			failures.append("%s: %s (esperado %s, obtido %s)" % [current, msg, str(b), str(a)])
		return
	if a != b:
		failures.append("%s: %s (esperado %s, obtido %s)" % [current, msg, str(b), str(a)])


func near(a: float, b: float, tol: float, msg: String = "") -> void:
	asserts += 1
	if absf(a - b) > tol:
		failures.append("%s: %s (esperado %s±%s, obtido %s)" % [current, msg, str(b), str(tol), str(a)])


func rng(seed_v: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


func fresh(mode: String = "story") -> GameState:
	return GameState.new_game(mode, 1_800_000_000)


func setup() -> void:
	pass
