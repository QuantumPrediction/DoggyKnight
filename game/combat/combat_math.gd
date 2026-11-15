class_name CombatMath
extends RefCounted
## 戰鬥的計算公式(A 線)。全部是純函式,方便測試。DEV_PLAN 4.9「數值由誰套用」。


## 金毛造成的傷害 = attack_damage × (1 + next_level_bonus) × 倍數(握手、迴旋斬、必殺技)。
## 四捨五入,最少 1。
static func player_damage(stats: StatBlock, level_bonus: float, multiplier: float = 1.0) -> int:
	return maxi(1, roundi(float(stats.attack_damage) * (1.0 + level_bonus) * multiplier))


## 金毛實際受到的傷害 = 原始傷害 × damage_taken_mult(「坐下」把戲會降低)。四捨五入,最少 1。
static func damage_taken(amount: int, stats: StatBlock) -> int:
	if amount <= 0:
		return 0
	return maxi(1, roundi(float(amount) * stats.damage_taken_mult))


## point 是否在以 origin 為圓心、朝 direction、半徑 radius、半角 half_angle(弧度)的扇形內。
## 距離 close_distance 以內一律算命中(貼身時不必計較角度)。
static func in_sector(origin: Vector2, direction: Vector2, point: Vector2, radius: float,
		half_angle: float, close_distance: float = 0.0) -> bool:
	var offset := point - origin
	var dist := offset.length()
	if dist > radius:
		return false
	if dist <= close_distance or dist < 0.001:
		return true
	return absf(direction.angle_to(offset)) <= half_angle


## 把經驗值分成最多 max_orbs 顆經驗珠,總和不變。例:20 分成 5 顆 → [4, 4, 4, 4, 4]。
static func split_exp(total: int, max_orbs: int) -> Array[int]:
	var result: Array[int] = []
	if total <= 0:
		return result
	var count := clampi(total, 1, maxi(1, max_orbs))
	@warning_ignore("integer_division")
	var base := total / count
	var extra := total % count
	for i in count:
		result.append(base + (1 if i < extra else 0))
	return result


## 從 origin 沿 direction 射出,到 rect 邊界為止的距離(origin 在 rect 內)。
static func distance_to_rect_edge(origin: Vector2, direction: Vector2, rect: Rect2) -> float:
	var best := INF
	if direction.x > 0.0001:
		best = minf(best, (rect.end.x - origin.x) / direction.x)
	elif direction.x < -0.0001:
		best = minf(best, (rect.position.x - origin.x) / direction.x)
	if direction.y > 0.0001:
		best = minf(best, (rect.end.y - origin.y) / direction.y)
	elif direction.y < -0.0001:
		best = minf(best, (rect.position.y - origin.y) / direction.y)
	return maxf(0.0, best) if best != INF else 0.0


## 把位置限制在戰鬥區之內(扣掉身體半徑)。戰鬥場地放在世界原點(DEV_PLAN 4.8 座標約定)。
static func clamp_to_arena(pos: Vector2, radius: float) -> Vector2:
	var rect := Layout.ARENA_RECT.grow(-radius)
	return pos.clamp(rect.position, rect.end)


## 角色中心可以到的範圍:整張角色圖都留在戰鬥區內。half_extents = 圖的一半寬高(至少身體半徑)。
static func arena_bounds(half_extents: Vector2) -> Rect2:
	return Layout.ARENA_RECT.grow_individual(-half_extents.x, -half_extents.y, -half_extents.x, -half_extents.y)


static func clamp_to_bounds(pos: Vector2, half_extents: Vector2) -> Vector2:
	var rect := arena_bounds(half_extents)
	return pos.clamp(rect.position, rect.end)


## 由角色圖大小與身體半徑算出 half_extents(圖邊可以稍微超出 2 像素)。
static func sprite_margin(frame_size: Vector2, radius: float) -> Vector2:
	return Vector2(maxf(radius, frame_size.x * 0.5 - 2.0), maxf(radius, frame_size.y * 0.5 - 2.0))
