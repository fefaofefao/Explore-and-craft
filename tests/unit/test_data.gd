extends TestCase
## Integridade dos dados: referências cruzadas, textos traduzidos, balanceamento sensato.


func test_all_files_load() -> void:
	var db := GameData.db()
	check(db.items.size() > 40, "itens")
	check(db.species.size() >= 30, "espécies")
	check(db.maps.size() == 8, "8 mapas")
	check(db.quests.size() >= 30, "missões")
	check(db.strings.size() > 200, "textos")


func test_every_text_has_pt_and_en() -> void:
	var db := GameData.db()
	for k in db.strings:
		check(db.strings[k].get("pt", "") != "" and db.strings[k].get("en", "") != "", "texto %s sem tradução" % k)
	for id in db.items:
		check(db.items[id]["name"]["en"] != "", "item %s sem nome EN" % id)
	for id in db.dialogs:
		for line in db.dialogs[id]:
			check(line["text"]["pt"] != "" and line["text"]["en"] != "", "diálogo %s" % id)
	for id in db.fragments:
		check(db.fragments[id]["pt"].length() > 20, "fragmento %s curto" % id)


func test_recipes_reference_valid_items() -> void:
	var db := GameData.db()
	for rid in db.recipes:
		var r: Dictionary = db.recipes[rid]
		check(db.items.has(r["out"]), "%s saída" % rid)
		for k in r["in"]:
			check(db.items.has(k), "%s entrada %s" % [rid, k])
		check(r["station"] in ["mao", "bancada", "fornalha", "fogueira", "arcana", "forja"], "%s estação" % rid)


func test_every_story_item_is_obtainable() -> void:
	## Todo item usado em receitas precisa vir de um nó, drop, receita, chefe ou estação.
	var db := GameData.db()
	var sources := {}
	for n in db.nodes.values():
		for k in n["drops"]:
			sources[k] = true
		for k in n["bonus"]:
			sources[k] = true
	for r in db.recipes.values():
		sources[r["out"]] = true
	for b in db.buildings.values():
		for k in b.get("output", {}):
			sources[k] = true
	for m in db.maps.values():
		var lair: Dictionary = m["pois"].get("lair", {})
		if not lair.is_empty():
			sources[lair["drop"]] = true
	for k in ["pele", "carne_crua", "po_eco"]:
		sources[k] = true  # drops de Ecos derrotados
	for r in db.recipes.values():
		for k in r["in"]:
			check(sources.has(k), "item %s não tem fonte" % k)
	for b in db.buildings.values():
		for k in b["cost"]:
			check(sources.has(k), "custo %s sem fonte" % k)


func test_recipe_levels_progress_with_story() -> void:
	## Os itens exigidos por cada missão devem estar liberados antes do nível esperado do chefe daquela etapa.
	var db := GameData.db()
	check(int(db.recipes["r_cantil"]["lvl"]) <= 6, "cantil cedo")
	check(int(db.recipes["r_nucleo_ponte"]["lvl"]) <= 15, "núcleo antes do Ato 1 acabar")
	check(int(db.recipes["r_pe_de_cabra"]["lvl"]) <= 15, "pé de cabra")


func test_species_have_learnsets_and_bodies() -> void:
	var db := GameData.db()
	for id in db.species:
		var s: Dictionary = db.species[id]
		check(s["learnset"].size() >= 3, "%s learnset" % id)
		check(int(s["learnset"][0][0]) == 1, "%s precisa de habilidade no nível 1" % id)
		check(s["body"]["shape"] in ["round", "quad", "bird", "serpent", "golem", "biped"], "%s forma" % id)
		check(Color.html_is_valid(s["body"]["color"]), "%s cor" % id)
		for t in s["types"]:
			check(t in db.types["order"], "%s tipo" % id)


func test_type_chart_is_balanced() -> void:
	var db := GameData.db()
	var strong_count := {}
	var weak_count := {}
	for t in db.types["order"]:
		strong_count[t] = db.types["strong"][t].size()
		weak_count[t] = 0
	for t in db.types["order"]:
		for v in db.types["strong"][t]:
			weak_count[v] += 1
	for t in db.types["order"]:
		eq(strong_count[t], 2, "%s forte contra 2" % t)
		check(weak_count[t] >= 1 and weak_count[t] <= 3, "%s fraco contra 1..3 (%d)" % [t, weak_count[t]])


func test_maps_spawn_levels_rise_with_act() -> void:
	var db := GameData.db()
	var max1 := 0
	var min2 := 999
	for id in db.maps:
		var m: Dictionary = db.maps[id]
		for s in m["spawns"]:
			if int(m["act"]) == 1:
				max1 = max(max1, int(s[2]))
			else:
				min2 = min(min2, int(s[1]))
	check(min2 >= max1, "Ato 2 começa acima do Ato 1 (%d >= %d)" % [min2, max1])


func test_trainers_levels_escalate() -> void:
	var db := GameData.db()
	var vorn_max := 0
	for e in db.trainers["vorn"]["team"]:
		vorn_max = max(vorn_max, int(e[1]))
	for c in ["rasha", "brutus", "lin"]:
		for e in db.trainers[c]["team"]:
			check(int(e[1]) <= vorn_max, "capitão %s abaixo do Barão" % c)


func test_strings_used_in_code_exist() -> void:
	## Varre o código-fonte procurando Loc.t("chave") e confere que a chave existe.
	var db := GameData.db()
	var re := RegEx.new()
	re.compile("Loc\\.t\\(\"([a-z0-9_]+)\"[,)]")
	var missing: Array = []
	var stack: Array = ["res://src"]
	while stack.size() > 0:
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for sub in d.get_directories():
			stack.append(dir_path + "/" + sub)
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var txt := FileAccess.get_file_as_string(dir_path + "/" + f)
			for m in re.search_all(txt):
				var key := m.get_string(1)
				if not db.strings.has(key) and not key in missing:
					missing.append(key)
	eq(missing.size(), 0, "chaves de texto inexistentes: %s" % str(missing))
	# chaves montadas dinamicamente (prefixo + valor do dado)
	for id in db.items:
		check(db.strings.has("cat_" + db.items[id]["cat"]), "cat_" + db.items[id]["cat"])
	for rid in db.recipes:
		check(db.strings.has("station_" + db.recipes[rid]["station"]), "station_" + db.recipes[rid]["station"])
	for id in db.buildings:
		var b: Dictionary = db.buildings[id]
		check(db.strings.has("bk_" + b["kind"]), "bk_" + b["kind"])
		if b.has("work"):
			check(db.strings.has("w_" + b["work"]), "w_" + b["work"])
	for id in db.species:
		for w in db.species[id]["work"]:
			check(db.strings.has("w_" + w), "w_" + w)
	for id in db.maps:
		if db.maps[id]["hazard"] != null:
			check(db.strings.has("hz_" + db.maps[id]["hazard"]["kind"]), "hz_" + db.maps[id]["hazard"]["kind"])
			check(db.dialogs.has("d_hazard_" + db.maps[id]["hazard"]["kind"]), "diálogo de perigo")


func test_analytics_and_ads_config() -> void:
	var db := GameData.db()
	check(db.ads["app_id"].begins_with("ca-app-pub-"), "app id")
	for k in ["banner", "interstitial", "rewarded"]:
		check(db.ads["units"][k].begins_with("ca-app-pub-"), "unit " + k)
	check("tutorial_complete" in db.analytics_events, "evento tutorial")
	check(db.remote_defaults.has("interstitial_min_interval_sec"), "remote config")
	var ids: Array = []
	for p in db.iap["products"]:
		ids.append(p["id"])
		check(float(p["price_usd"]) > 0.0, "preço " + p["id"])
	check("remove_ads" in ids and "season_pass" in ids and "starter_pack" in ids, "produtos principais")


func test_every_skill_has_a_known_visual_style() -> void:
	var styles := SkillFX.all_styles()
	var used := {}
	for s in GameData.db().skills:
		var sk: Dictionary = GameData.db().skills[s]
		check(sk.has("fx") and sk["fx"] in styles, "%s tem estilo visual válido" % s)
		used[sk.get("fx", "")] = true
		check(SkillFX.windup(SkillFX.anim_for(sk)) > 0.05, "%s tem antecipação" % s)
	check(used.size() >= 25, "ataques variados (%d estilos)" % used.size())


func test_biomes_have_wind_and_landscape_params() -> void:
	for id in GameData.db().maps:
		var b: Dictionary = GameData.db().maps[id]["biome"]
		check(float(b.get("wind", 0)) > 0.0, "%s tem vento" % id)
		check(b.has("tall_grass") and b.has("boulders"), "%s tem capim alto e rochedos" % id)
