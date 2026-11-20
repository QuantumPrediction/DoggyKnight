class_name GemStore
extends RefCounted
## Draft products: provider must supply actual localized price and a platform purchase UI.
## This interface NEVER grants gems. Production grants require verified, idempotent transactions.
static func packs() -> Array[Dictionary]:
	return EquipmentInventory.RULES.gem_packs.duplicate(true)

static func request(product_id: StringName, provider: Object) -> Dictionary:
	var known := false
	for pack in packs():
		known = known or StringName(pack.id) == product_id
	if not known:
		return {"status": "invalid_product"}
	if provider == null or not provider.has_method("is_available") or not provider.call("is_available"):
		return {"status": "unavailable", "message": "真實付款尚未開放。"}
	# No price is fabricated and no unverified callback may alter GameState.equipment.
	var offers: Array = provider.call("get_products", [product_id] as Array[StringName])
	for offer: Dictionary in offers:
		if str(offer.get("id", "")) == String(product_id) and not str(offer.get("localized_price", "")).is_empty():
			provider.call("purchase", product_id)
			return {"status": "pending_platform_confirmation"}
	return {"status": "unavailable", "message": "未能取得平台商品與價格。"}
