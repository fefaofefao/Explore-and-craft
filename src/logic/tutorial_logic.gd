class_name TutorialLogic
extends RefCounted
## Tutorial guiado dos primeiros passos: libertar o parceiro, coletar, construir e lutar.
## O progresso é derivado do estado (robusto a saves antigos); state.tutorial guarda o que já foi celebrado.

const STEPS := ["partner", "gather", "build", "fight"]


static func is_done(state: GameState, step: String) -> bool:
	match step:
		"partner":
			return state.flags.get("starter_chosen", false)
		"gather":
			var tot := 0
			for k in state.stats.get("gathered", {}):
				tot += int(state.stats["gathered"][k])
			return tot > 0
		"build":
			return state.buildings.size() > 0
		"fight":
			return int(state.stats.get("defeats", 0)) > 0 or int(state.stats.get("captures", 0)) > 0
	return true


static func available(state: GameState, step: String) -> bool:
	match step:
		"gather", "fight":
			return is_done(state, "partner")
		"build":
			# só depois que a missão de construir aparece (o jogador já tem ferramentas e materiais por perto)
			return is_done(state, "gather") and state.quest_idx >= GameData.db().quest_index("q04")
	return true


static func current(state: GameState) -> String:
	if state.is_sandbox():
		return ""
	for s in STEPS:
		if not is_done(state, s) and available(state, s):
			return s
	return ""


static func newly_completed(state: GameState) -> Array:
	## Etapas concluídas que ainda não foram celebradas (marca como celebradas).
	var out: Array = []
	for s in STEPS:
		if is_done(state, s) and not state.tutorial.get(s, false):
			state.tutorial[s] = true
			out.append(s)
	return out
