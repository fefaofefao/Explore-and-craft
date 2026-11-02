extends TestCase


func test_wind_changes_direction_over_time() -> void:
	var w := Wind.new(7, 0.5)
	var a0 := w.dir()
	var changed := false
	for i in 60 * 90:
		w.update(1.0 / 60.0)
		if w.dir().dot(a0) < 0.8:
			changed = true
	check(changed, "a direção do vento muda ao longo de 90 s")


func test_wind_strength_bounded_and_gusty() -> void:
	var w := Wind.new(3, 0.5)
	var lo := 9.0
	var hi := -9.0
	for i in 60 * 60:
		w.update(1.0 / 60.0)
		lo = minf(lo, w.strength)
		hi = maxf(hi, w.strength)
	check(lo >= 0.05 and hi <= 1.4, "força dentro dos limites (%.2f..%.2f)" % [lo, hi])
	check(hi - lo > 0.15, "há rajadas (%.2f)" % (hi - lo))


func test_wind_offset_follows_direction_and_is_continuous() -> void:
	var w := Wind.new(11, 0.6)
	var prev := w.offset
	for i in 600:
		w.update(1.0 / 60.0)
		check((w.offset - prev).length() < 0.2, "deslocamento contínuo")
		prev = w.offset
	check(w.offset.length() > 5.0, "as ondas de vento andam (%.1f)" % w.offset.length())


func test_wind_deterministic() -> void:
	var a := Wind.new(5)
	var b := Wind.new(5)
	for i in 1000:
		a.update(0.02)
		b.update(0.02)
	near(a.angle, b.angle, 0.0001, "mesma semente, mesmo vento")
