class_name SaveSystem
extends RefCounted
## Saves em JSON em user:// com escrita atômica (arquivo temporário + rename) e backup.

static var base_dir: String = "user://"


static func path_for(slot: String) -> String:
	return base_dir + "save_%s.json" % slot


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot)) or FileAccess.file_exists(path_for(slot) + ".bak")


static func save(state: GameState, slot: String) -> bool:
	var txt := JSON.stringify(state.to_dict())
	var p := path_for(slot)
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(txt)
	f.close()
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return false
	if FileAccess.file_exists(p):
		dir.copy(p, p + ".bak")
	return dir.rename(tmp, p) == OK


static func load_state(slot: String) -> GameState:
	for p in [path_for(slot), path_for(slot) + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.has("v"):
			return GameState.from_dict(d)
	return null


static func delete(slot: String) -> void:
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return
	for p in [path_for(slot), path_for(slot) + ".bak", path_for(slot) + ".tmp"]:
		if FileAccess.file_exists(p):
			dir.remove(p.get_file())
