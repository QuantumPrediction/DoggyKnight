class_name PlatformIap
extends Node
## 內購(應用程式內購買)的介面(DEV_PLAN 4.8、11 D7)。
##
## 原型:空實作,不做任何購買(DEV_PLAN 第 1 節「不包含」內購)。只在除錯版印出記錄,不連網。
## 日後接 Google Play Billing / Apple StoreKit 的外掛時,只改這個檔案。

## 購買結果。原型一律 success = false。
signal purchase_finished(product_id: StringName, success: bool)
## 「恢復購買」完成(Apple 審查要求非消耗性商品要有這個按鈕)。
signal restore_finished(restored: Array)

const ENABLED: bool = false


func is_available() -> bool:
	return ENABLED


## 查詢商品資料(名稱、價格)。原型傳回空陣列。
func get_products(product_ids: Array[StringName]) -> Array[Dictionary]:
	PlatformLog.note("iap", "get_products(%s) — no-op" % [product_ids])
	return []


func purchase(product_id: StringName) -> void:
	PlatformLog.note("iap", "purchase(%s) — no-op" % product_id)
	purchase_finished.emit.call_deferred(product_id, false)


func restore_purchases() -> void:
	PlatformLog.note("iap", "restore_purchases() — no-op")
	restore_finished.emit.call_deferred([])
