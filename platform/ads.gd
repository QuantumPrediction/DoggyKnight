class_name PlatformAds
extends Node
## 廣告服務的介面(DEV_PLAN 4.8、11 D7)。
##
## 原型:空實作。所有方法只在除錯版印出記錄,不連網、不載入任何 SDK、不讀取廣告識別碼。
## 遊戲程式只呼叫這裡的方法;日後接真實的廣告外掛時,只改這個檔案,遊戲程式不用改。
## 接真實服務之前必讀 platform/README.md(隱私問卷、家庭政策、ATT)。

## 獎勵廣告看完(rewarded = true 才可以給獎勵)。原型一律回傳 false。
signal rewarded_finished(placement: StringName, rewarded: bool)
## 插頁廣告關閉。
signal interstitial_closed(placement: StringName)

## 原型永遠是 false。
const ENABLED: bool = false


func is_available() -> bool:
	return ENABLED


func show_rewarded(placement: StringName) -> void:
	PlatformLog.note("ads", "show_rewarded(%s) — no-op" % placement)
	rewarded_finished.emit.call_deferred(placement, false)


func show_interstitial(placement: StringName) -> void:
	PlatformLog.note("ads", "show_interstitial(%s) — no-op" % placement)
	interstitial_closed.emit.call_deferred(placement)


func show_banner(placement: StringName) -> void:
	PlatformLog.note("ads", "show_banner(%s) — no-op" % placement)


func hide_banner() -> void:
	PlatformLog.note("ads", "hide_banner() — no-op")
