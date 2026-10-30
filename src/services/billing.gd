extends Node
## Autoload "Billing": Google Play Billing (plugin oficial "GodotGooglePlayBilling").
## Sem o plugin: em builds de depuração simula a compra (para testar o fluxo); em release informa indisponível.

signal purchase_done(product_id: String, ok: bool)

var plugin: Object = null
var connected := false
var prices: Dictionary = {}  # product_id -> preço local formatado


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("GodotGooglePlayBilling"):
		plugin = Engine.get_singleton("GodotGooglePlayBilling")
		for sig in ["connected", "purchases_updated", "purchase_error", "product_details_query_completed", "purchase_acknowledged", "purchase_consumed"]:
			if plugin.has_signal(sig):
				plugin.connect(sig, Callable(self, "_on_" + sig))
		plugin.call("startConnection")


func product(id: String) -> Dictionary:
	for p in GameData.db().iap["products"]:
		if p["id"] == id:
			return p
	return {}


func price_text(id: String) -> String:
	if prices.has(id):
		return prices[id]
	return "US$ %.2f" % float(product(id).get("price_usd", 0.0))


func available() -> bool:
	return (plugin != null and connected) or OS.is_debug_build()


func buy(id: String) -> void:
	Firebase.log_event("iap_view", {"product": id})
	if plugin != null and connected:
		plugin.call("purchase", id)
		return
	if OS.is_debug_build():
		_grant(id)  # simulação para testes
		return
	Game.notify(Loc.t("iap_unavailable"), "warn")
	emit_signal("purchase_done", id, false)


func restore() -> void:
	if plugin != null and connected and plugin.has_method("queryPurchases"):
		plugin.call("queryPurchases", "inapp")


func _grant(id: String) -> void:
	var p := product(id)
	if p.is_empty():
		return
	var st: GameState = Game.state
	if p["type"] == "nonconsumable" and id in st.iap_state["purchases"]:
		emit_signal("purchase_done", id, false)
		return
	st.iap_state["purchases"].append(id)
	Game.grant_and_toast(p["grants"], Loc.tx(p["name"]))
	Firebase.log_event("iap_purchase", {"product": id, "value": p["price_usd"], "currency": "USD"})
	Game.save_now()
	emit_signal("purchase_done", id, true)


# ------------------------------------------------------------------ callbacks do plugin
func _on_connected() -> void:
	connected = true
	var ids: Array = []
	for p in GameData.db().iap["products"]:
		ids.append(p["id"])
	if plugin.has_method("queryProductDetails"):
		plugin.call("queryProductDetails", ids, "inapp")
	elif plugin.has_method("querySkuDetails"):
		plugin.call("querySkuDetails", ids, "inapp")


func _on_product_details_query_completed(details: Array) -> void:
	for d in details:
		if d is Dictionary and d.has("product_id"):
			prices[d["product_id"]] = d.get("one_time_purchase_offer_details", {}).get("formatted_price", "")


func _on_purchases_updated(purchases: Array) -> void:
	for pu in purchases:
		if not pu is Dictionary:
			continue
		var ids: Array = pu.get("product_ids", pu.get("skus", []))
		for id in ids:
			var p := product(id)
			if p.is_empty():
				continue
			if not id in Game.state.iap_state["purchases"] or p["type"] == "consumable":
				_grant(id)
			if p["type"] == "consumable":
				plugin.call("consumePurchase", pu.get("purchase_token", ""))
			elif not pu.get("is_acknowledged", false):
				plugin.call("acknowledgePurchase", pu.get("purchase_token", ""))


func _on_purchase_error(_code = 0, _msg = "") -> void:
	emit_signal("purchase_done", "", false)


func _on_purchase_acknowledged(_t = "") -> void:
	pass


func _on_purchase_consumed(_t = "") -> void:
	pass
