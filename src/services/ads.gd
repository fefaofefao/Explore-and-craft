extends Node
## Autoload "Ads": AdMob (intersticial, rewarded, banner) com consentimento UMP e política de frequência.
## Com o plugin Android do AdMob instalado no build gradle (singleton "AdmobPlugin"), usa anúncios reais;
## sem ele (PC, testes, APK sem gradle), usa um anúncio SIMULADO para o fluxo do jogo continuar testável.

signal rewarded_finished(placement: String, ok: bool)
signal interstitial_closed

var plugin: Object = null
var simulated := true
var _pending_placement := ""
var _rewarded_ready := false
var _interstitial_ready := false
var _overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("AdmobPlugin"):
		plugin = Engine.get_singleton("AdmobPlugin")
		simulated = false
		_connect_plugin()


func _connect_plugin() -> void:
	var cfg: Dictionary = GameData.db().ads
	for sig in ["initialization_completed", "rewarded_ad_loaded", "rewarded_ad_user_earned_reward", "rewarded_ad_dismissed_full_screen_content",
			"rewarded_ad_failed_to_load", "interstitial_ad_loaded", "interstitial_ad_dismissed_full_screen_content", "interstitial_ad_failed_to_load"]:
		if plugin.has_signal(sig):
			plugin.connect(sig, Callable(self, "_on_" + sig))
	if plugin.has_method("initialize"):
		plugin.call("initialize")
	set_meta("app_id", cfg["app_id"])


func start_after_consent() -> void:
	## Chamado depois do diálogo de privacidade (UMP). Pré-carrega os formatos.
	if simulated:
		_rewarded_ready = true
		_interstitial_ready = true
		return
	_load_rewarded()
	_load_interstitial()


func _unit(kind: String) -> String:
	return GameData.db().ads["units"][kind]


func _load_rewarded() -> void:
	if plugin and plugin.has_method("load_rewarded_ad"):
		plugin.call("load_rewarded_ad", {"ad_unit_id": _unit("rewarded")})


func _load_interstitial() -> void:
	if plugin and plugin.has_method("load_interstitial_ad"):
		plugin.call("load_interstitial_ad", {"ad_unit_id": _unit("interstitial")})


# ------------------------------------------------------------------ API do jogo
func rewarded_available(placement: String) -> bool:
	var st: GameState = Game.state
	if st == null:
		return false
	return AdPolicy.can_rewarded(st, placement, Game.now(), Game.rc) and (_rewarded_ready or simulated)


func cooldown_left(placement: String) -> int:
	return AdPolicy.rewarded_cooldown_left(Game.state, placement, Game.now())


func show_rewarded(placement: String) -> void:
	## Quem chama ouve rewarded_finished(placement, ok). "Sem Anúncios" concede direto.
	var st: GameState = Game.state
	if not AdPolicy.can_rewarded(st, placement, Game.now(), Game.rc):
		Game.notify(Loc.t("video_unavailable"), "warn")
		emit_signal("rewarded_finished", placement, false)
		return
	Firebase.log_event("ad_rewarded_offer", {"placement": placement})
	if st.iap_state.get("no_ads", false):
		_finish_rewarded(placement, true)
		return
	_pending_placement = placement
	if simulated:
		_show_simulated(func(): _finish_rewarded(placement, true))
	elif plugin.has_method("show_rewarded_ad"):
		plugin.call("show_rewarded_ad")
	else:
		_finish_rewarded(placement, false)


func _finish_rewarded(placement: String, ok: bool) -> void:
	if ok:
		AdPolicy.on_rewarded_done(Game.state, placement, Game.now())
		Firebase.log_event("ad_rewarded_complete", {"placement": placement})
	_pending_placement = ""
	emit_signal("rewarded_finished", placement, ok)
	if not simulated:
		_rewarded_ready = false
		_load_rewarded()


func maybe_interstitial(where: String) -> bool:
	## Momentos naturais (pós-batalha de treinador, viagem entre mapas). Respeita todas as regras.
	var st: GameState = Game.state
	if st == null or not AdPolicy.can_interstitial(st, Game.now(), Game.session_start, Game.rc):
		return false
	if not (_interstitial_ready or simulated):
		return false
	AdPolicy.on_interstitial_shown(st, Game.now())
	Firebase.log_event("ad_interstitial_show", {"where": where})
	if simulated:
		_show_simulated(func(): emit_signal("interstitial_closed"), 1.2)
	elif plugin.has_method("show_interstitial_ad"):
		plugin.call("show_interstitial_ad")
	return true


func _show_simulated(done: Callable, secs: float = 1.6) -> void:
	## Tela de "anúncio de teste" para PC/APK sem SDK.
	if _overlay != null:
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var l := Label.new()
	l.text = Loc.t("ad_simulated")
	l.add_theme_font_size_override("font_size", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(l)
	get_tree().root.add_child(_overlay)
	await get_tree().create_timer(secs, true, false, true).timeout
	_overlay.queue_free()
	_overlay = null
	done.call()


# ------------------------------------------------------------------ callbacks do plugin
func _on_initialization_completed(_a = null) -> void:
	start_after_consent()


func _on_rewarded_ad_loaded(_a = null) -> void:
	_rewarded_ready = true


func _on_rewarded_ad_failed_to_load(_a = null, _b = null) -> void:
	_rewarded_ready = false
	get_tree().create_timer(30.0).timeout.connect(_load_rewarded)


func _on_rewarded_ad_user_earned_reward(_a = null, _b = null) -> void:
	if _pending_placement != "":
		_finish_rewarded(_pending_placement, true)


func _on_rewarded_ad_dismissed_full_screen_content(_a = null) -> void:
	if _pending_placement != "":
		_finish_rewarded(_pending_placement, false)


func _on_interstitial_ad_loaded(_a = null) -> void:
	_interstitial_ready = true


func _on_interstitial_ad_failed_to_load(_a = null, _b = null) -> void:
	_interstitial_ready = false


func _on_interstitial_ad_dismissed_full_screen_content(_a = null) -> void:
	_interstitial_ready = false
	emit_signal("interstitial_closed")
	_load_interstitial()
