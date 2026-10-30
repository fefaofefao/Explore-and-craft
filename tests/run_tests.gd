extends SceneTree
## Executa todos os testes: godot --headless --path . -s tests/run_tests.gd
## Opcional: -- filtro  (só arquivos que contenham o texto)


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	SaveSystem.base_dir = "user://test_saves/"
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	var files: Array = []
	for dir_path in ["res://tests/unit", "res://tests/integration"]:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with("test_") and f.ends_with(".gd") and (filter == "" or f.contains(filter)):
				files.append(dir_path + "/" + f)
	files.sort()
	var total_asserts := 0
	var total_tests := 0
	var all_fail: Array = []
	var t0 := Time.get_ticks_msec()
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			all_fail.append("%s: falhou ao carregar" % path)
			continue
		var methods: Array = []
		for m in script.get_script_method_list():
			if str(m["name"]).begins_with("test_"):
				methods.append(m["name"])
		var n_fail_before := all_fail.size()
		for mname in methods:
			var tc: TestCase = script.new()
			tc.current = "%s::%s" % [path.get_file(), mname]
			tc.setup()
			if tc.has_method("setup_tree"):
				await tc.call("setup_tree", self)
			var r: Variant = tc.call(mname)
			if r is Signal or (r != null and typeof(r) == TYPE_OBJECT and r.get_class() == "GDScriptFunctionState"):
				await r
			total_asserts += tc.asserts
			total_tests += 1
			all_fail.append_array(tc.failures)
			if tc.has_method("teardown"):
				tc.call("teardown")
		var nf := all_fail.size() - n_fail_before
		print("%s %s (%d testes)" % ["OK  " if nf == 0 else "FALHA", path.get_file(), methods.size()])
	print("")
	for f in all_fail:
		print("  ✗ ", f)
	print("\n%d testes, %d asserções, %d falhas em %d ms" % [total_tests, total_asserts, all_fail.size(), Time.get_ticks_msec() - t0])
	quit(1 if all_fail.size() > 0 else 0)
