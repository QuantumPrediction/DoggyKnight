extends Node2D
## 測試用的能力宿主替身(代替金毛)。記錄能力對它做了甚麼,讓測試用模擬時間計算觸發次數。

var targets: Array[Node2D] = []
var hits: Array = []           ## [目標, 傷害, 擊退]
var stuns: Array = []          ## [目標, 秒數]
var visuals: Array = []        ## [種類, 半徑]
var base_damage: int = 10


func ability_targets(_radius: float) -> Array[Node2D]:
	return targets


func ability_base_damage(multiplier: float) -> int:
	return roundi(base_damage * multiplier)


func ability_hit(target: Node2D, damage: int, knockback: float) -> void:
	hits.append([target, damage, knockback])


func ability_stun(target: Node2D, duration: float) -> void:
	stuns.append([target, duration])


func ability_visual(kind: StringName, radius: float) -> void:
	visuals.append([kind, radius])


var projectiles: Array = []    ## [種類, 傷害](v2.4 擊掌連打)


func ability_projectile(kind: StringName, damage: int) -> void:
	projectiles.append([kind, damage])
