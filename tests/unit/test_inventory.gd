extends TestCase


func test_add_and_stack() -> void:
	var inv := Inventory.new(3)
	eq(inv.add("madeira", 150), 0, "cabe tudo")
	eq(inv.count("madeira"), 150, "contagem")
	eq(inv.slots[0]["n"], 99, "pilha cheia")
	eq(inv.slots[1]["n"], 51, "resto")


func test_overflow_returns_leftover() -> void:
	var inv := Inventory.new(2)
	inv.add("madeira", 99)
	eq(inv.add("pedra", 150), 51, "sobra")
	eq(inv.count("pedra"), 99, "só uma pilha coube")


func test_tools_do_not_stack() -> void:
	var inv := Inventory.new(5)
	inv.add("machado_pedra", 2)
	eq(inv.slots[0]["n"], 1, "stack 1")
	eq(inv.slots[1]["n"], 1, "segundo slot")


func test_remove_and_has_all() -> void:
	var inv := Inventory.new(5)
	inv.add("madeira", 10)
	inv.add("pedra", 5)
	check(inv.has_all({"madeira": 10, "pedra": 5}), "has_all")
	check(not inv.has_all({"madeira": 11}), "falta madeira")
	check(inv.remove_all({"madeira": 4, "pedra": 5}), "remove")
	eq(inv.count("madeira"), 6, "sobrou")
	eq(inv.count("pedra"), 0, "zerou")
	check(not inv.remove("pedra", 1), "não remove o que não tem")


func test_unknown_item_rejected() -> void:
	var inv := Inventory.new(5)
	eq(inv.add("item_que_nao_existe", 3), 3, "rejeita")


func test_best_tool_and_weapon() -> void:
	var inv := Inventory.new(10)
	eq(inv.best_tool("axe").size(), 0, "sem machado")
	inv.add("machado_pedra")
	inv.add("machado_ferro")
	inv.add("lanca_pedra")
	inv.add("espada_ferro")
	eq(inv.best_tool("axe")["id"], "machado_ferro", "melhor machado")
	eq(inv.best_weapon_dmg(), 16, "espada")
	eq(inv.best_weapon_id(), "espada_ferro", "id arma")


func test_protection() -> void:
	var inv := Inventory.new(5)
	check(not inv.has_protection("calor"), "sem cantil")
	inv.add("cantil")
	check(inv.has_protection("calor"), "com cantil")
	check(not inv.has_protection("frio"), "cantil não protege do frio")


func test_infinite_mode() -> void:
	var inv := Inventory.new(5)
	inv.infinite = true
	check(inv.has("cristal", 500), "infinito tem tudo")
	check(inv.remove("cristal", 10), "remove sem ter")


func test_sort_merges_stacks() -> void:
	var inv := Inventory.new(6)
	inv.slots[0] = {"id": "madeira", "n": 30}
	inv.slots[2] = {"id": "machado_pedra", "n": 1}
	inv.slots[4] = {"id": "madeira", "n": 30}
	inv.sort_slots()
	eq(inv.slots[0]["id"], "machado_pedra", "ferramentas primeiro")
	eq(inv.slots[1]["n"], 60, "pilhas unidas")
	check(inv.slots[2].is_empty(), "resto vazio")


func test_serialization_roundtrip() -> void:
	var inv := Inventory.new(5)
	inv.add("madeira", 12)
	inv.add("esfera", 3)
	var inv2 := Inventory.new(1)
	inv2.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	eq(inv2.count("madeira"), 12, "madeira")
	eq(inv2.count("esfera"), 3, "esfera")
	eq(inv2.capacity(), 5, "capacidade")
