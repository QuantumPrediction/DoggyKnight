class_name EquipmentInventory
extends RefCounted
## Offline prototype economy. Currency grants from real payments are deliberately absent.
const RULES: EquipmentRules = preload("res://data/equipment/catalog.tres")
const SLOTS: Array[String] = ["weapon", "armor", "treasure_a", "treasure_b"]
const HEROES: Array[String] = ["knight", "mage", "archer"]
const ELEMENTS: Array[String] = ["earth", "water", "fire", "wind"]
const LIMIT: int = 9999999

static func item(id: String) -> Dictionary:
	for entry in RULES.items:
		if entry.id == id:
			return entry
	return {}

static func cap(entry: Dictionary) -> int:
	return 5 if entry.get("quality", "common") == "common" else 9

static func defaults() -> Dictionary:
	return {"coins": RULES.starting_coins, "gems": 0, "shards": 0, "owned": {}, "elements": {},
		"loadouts": {}, "boss_misses": 0, "first_boss": {}, "reward_serial": 0, "last_reward": {}}

static func number(value: Variant, fallback: int = 0, maximum: int = LIMIT) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampi(int(value), 0, maximum)

static func sanitize(raw: Variant) -> Dictionary:
	var result := defaults()
	if not raw is Dictionary:
		return result
	for key in ["coins", "gems", "shards", "boss_misses", "reward_serial"]:
		result[key] = number(raw.get(key, result[key]))
	result.boss_misses = mini(result.boss_misses, RULES.boss_pity - 1)
	var owned: Variant = raw.get("owned", {})
	if owned is Dictionary:
		for id in owned:
			var entry := item(str(id))
			if not entry.is_empty() and number(owned[id]) > 0:
				result.owned[str(id)] = mini(number(owned[id]), cap(entry))
	for id: String in result.owned:
		var element := element_of(raw, id)
		if element != "":
			result.elements[id] = element
	var presets: Variant = raw.get("loadouts", {})
	if presets is Dictionary:
		for hero in HEROES:
			var slots: Variant = presets.get(hero, {})
			if not slots is Dictionary:
				continue
			var selected: Array[String] = []
			result.loadouts[hero] = {}
			for slot in SLOTS:
				var id := str(slots.get(slot, ""))
				if result.owned.has(id) and fits(item(id), hero, slot) and not selected.has(id):
					result.loadouts[hero][slot] = id
					selected.append(id)
	var first: Variant = raw.get("first_boss", {})
	if first is Dictionary:
		for chapter in range(1, GameState.CHAPTER_COUNT + 1):
			if first.get(str(chapter), false) == true:
				result.first_boss[str(chapter)] = true
	# Only curated reward text; no arbitrary freeform data is persisted.
	var last: Variant = raw.get("last_reward", {})
	if last is Dictionary:
		result.last_reward = {"coins": number(last.get("coins", 0)), "gems": number(last.get("gems", 0)),
			"shards": number(last.get("shards", 0)), "item": str(last.get("item", "")) if not item(str(last.get("item", ""))).is_empty() else "",
			"duplicate": last.get("duplicate", false) == true}
	return result

static func fits(entry: Dictionary, hero: String, slot: String) -> bool:
	if entry.is_empty() or not HEROES.has(hero) or not SLOTS.has(slot):
		return false
	return (entry.hero == "all" or entry.hero == hero) and (entry.slot == slot or (entry.slot == "treasure" and slot.begins_with("treasure_")))

static func element_of(profile: Dictionary, id: String) -> String:
	var entry := item(id)
	if entry.get("slot", "") not in ["weapon", "armor"]:
		return ""
	var selected: Variant = profile.get("elements", {})
	if selected is Dictionary:
		var value: Variant = selected.get(id, "")
		if (value is String or value is StringName) and ELEMENTS.has(String(value)):
			return String(value)
	var fallback := str(entry.get("element", ""))
	return fallback if ELEMENTS.has(fallback) else ""

static func resonance(profile: Dictionary, hero: String) -> String:
	var clean := loadout(profile, hero)
	var slots: Dictionary = clean.loadouts.get(hero, {})
	var weapon := element_of(clean, str(slots.get("weapon", "")))
	var armor := element_of(clean, str(slots.get("armor", "")))
	return weapon if weapon != "" and weapon == armor else ""

static func element_name(element: String) -> String:
	return str(RULES.elements.get(element, {}).get("name", "無"))

static func transact(profile: Dictionary, action: String, id: String, hero: String, slot: String = "", currency: String = "coins", unlocked: int = 1) -> Dictionary:
	var entry := item(id)
	if entry.is_empty() or not HEROES.has(hero):
		return {"ok": false, "message": "找不到裝備。"}
	var level := int(profile.owned.get(id, 0))
	match action:
		"buy":
			if level > 0:
				return {"ok": false, "message": "已收藏，請使用鍛造升級。"}
			if int(entry.chapter) > unlocked:
				return {"ok": false, "message": "抵達第 %d 章後開放購買。" % int(entry.chapter)}
			if not ["coins", "gems"].has(currency) or (currency == "gems" and entry.quality != "epic"):
				return {"ok": false, "message": "此付款方式不可用。"}
			var cost := int(entry.get(currency, 0))
			if cost <= 0 or int(profile[currency]) < cost:
				return {"ok": false, "message": "餘額不足；可繼續冒險收集。"}
			profile[currency] -= cost
			profile.owned[id] = 1
			if element_of(profile, id) != "":
				profile.elements[id] = element_of(profile, id)
		"upgrade":
			if level <= 0 or level >= cap(entry):
				return {"ok": false, "message": "尚未收藏或已達最高等級。"}
			var cost := upgrade_cost(entry, level)
			if int(profile.coins) < int(cost.coins) or int(profile.shards) < int(cost.shards):
				return {"ok": false, "message": "金幣或星鐵不足；升級不會失敗。"}
			profile.coins -= int(cost.coins)
			profile.shards -= int(cost.shards)
			profile.owned[id] = level + 1
		"equip":
			if level <= 0 or not fits(entry, hero, slot):
				return {"ok": false, "message": "此職業或欄位無法裝備。"}
			if not profile.loadouts.has(hero):
				profile.loadouts[hero] = {}
			for other in SLOTS:
				if other != slot and profile.loadouts[hero].get(other, "") == id:
					profile.loadouts[hero].erase(other)
			profile.loadouts[hero][slot] = id
		"unequip":
			if profile.loadouts.has(hero) and profile.loadouts[hero].get(slot, "") == id:
				profile.loadouts[hero].erase(slot)
			else:
				return {"ok": false, "message": "此欄位未裝備這件物品。"}
		"attune":
			# For this action slot is the requested element, never a loadout slot.
			if level <= 0 or entry.slot not in ["weapon", "armor"] or not ELEMENTS.has(slot) or not fits(entry, hero, entry.slot):
				return {"ok": false, "message": "只能為已收藏、此職業可用的武器或護甲刻印。"}
			if not profile.get("elements", {}) is Dictionary:
				return {"ok": false, "message": "裝備資料無效，請重新讀檔。"}
			if not profile.has("elements"):
				profile.elements = {}
			profile.elements[id] = slot
		_:
			return {"ok": false, "message": "無效操作。"}
	return {"ok": true, "message": "%s：%s" % [entry.name, {"buy": "已收藏", "upgrade": "升級完成", "equip": "配裝已儲存", "unequip": "已卸下", "attune": element_name(slot) + "刻印已儲存"}[action]]}

static func upgrade_cost(entry: Dictionary, level: int) -> Dictionary:
	if level < 1 or level >= cap(entry):
		return {"coins": -1, "shards": -1}
	return {"coins": RULES.common_costs[level - 1] if entry.quality == "common" else RULES.epic_costs[level - 1],
		"shards": 0 if entry.quality == "common" else RULES.epic_shards[level - 1]}

static func loadout(profile: Dictionary, hero: String) -> Dictionary:
	var out := {"owned": {}, "elements": {}, "loadouts": {hero: {}}}
	var clean := sanitize(profile)
	for slot in clean.loadouts.get(hero, {}):
		var id: String = clean.loadouts[hero][slot]
		out.owned[id] = clean.owned[id]
		out.loadouts[hero][slot] = id
		if clean.elements.has(id):
			out.elements[id] = clean.elements[id]
	return out

static func bonuses(profile: Dictionary, hero: String) -> Dictionary:
	var mods := {}
	var effects := {}
	var sets := {}
	var clean := loadout(profile, hero)
	for id: String in clean.owned:
		var entry := item(id)
		var level := int(clean.owned[id])
		var item_mods := item_modifiers(entry, level)
		for key: String in item_mods:
			mods[key] = float(mods.get(key, 0.0)) + float(item_mods[key])
		for key: String in entry.effects:
			effects[key] = float(effects.get(key, 0.0)) + float(entry.effects[key]) * effect_multiplier(level)
		sets[entry.group] = int(sets.get(entry.group, 0)) + 1
		var element := element_of(clean, id)
		if element != "":
			_add_element_bonus(mods, effects, RULES.elements[element][entry.slot])
	for group: String in sets:
		if int(sets[group]) >= 2:
			for key: String in RULES.set_bonuses.get(group, {}):
				mods[key] = float(mods.get(key, 0.0)) + float(RULES.set_bonuses[group][key])
	var active := resonance(clean, hero)
	if active != "":
		_add_element_bonus(mods, effects, RULES.elements[active].resonance)
	for key: String in RULES.effect_caps:
		if effects.has(key):
			effects[key] = minf(float(effects[key]), float(RULES.effect_caps[key]))
	return {"mods": mods, "effects": effects, "sets": sets, "resonance": active}

static func _add_element_bonus(mods: Dictionary, effects: Dictionary, bonus: Dictionary) -> void:
	for key: String in bonus.get("mods", {}):
		mods[key] = float(mods.get(key, 0.0)) + float(bonus.mods[key])
	for key: String in bonus.get("effects", {}):
		effects[key] = float(effects.get(key, 0.0)) + float(bonus.effects[key])

static func item_modifiers(entry: Dictionary, level: int) -> Dictionary:
	var bounded := clampi(level, 1, cap(entry))
	var growth := RULES.common_growth if entry.quality == "common" else RULES.epic_growth
	var result := {}
	for key: String in entry.mods:
		result[key] = float(entry.mods[key]) * (1.0 + growth * (bounded - 1))
	# Forging cadence is additive to the class base, never compounded per purchase.
	for key: String in entry.get("per_level_mods", {}):
		result[key] = float(result.get(key, 0.0)) + float(entry.per_level_mods[key]) * (bounded - 1)
	return result

static func effect_multiplier(level: int) -> float:
	# Preserve Lv.1/3/6/9 balance while giving intermediate forging levels a gain.
	var bounded := clampi(level, RULES.effect_levels[0], RULES.effect_levels[-1])
	for i in range(1, RULES.effect_levels.size()):
		if bounded <= RULES.effect_levels[i]:
			var fraction := float(bounded - RULES.effect_levels[i - 1]) / float(RULES.effect_levels[i] - RULES.effect_levels[i - 1])
			return lerpf(RULES.effect_steps[i - 1], RULES.effect_steps[i], fraction)
	return RULES.effect_steps[-1]

static func reward_clear(profile: Dictionary, chapter: int, boss: bool, hard: bool, rng: RandomNumberGenerator) -> Dictionary:
	var reward := {"coins": RULES.boss_coins if boss else RULES.level_coins, "gems": 0, "shards": 0, "item": "", "duplicate": false}
	if hard:
		reward.coins = roundi(float(reward.coins) * RULES.hard_coin_mult)
	if boss:
		reward.shards = RULES.boss_shards
		if not profile.first_boss.has(str(chapter)):
			profile.first_boss[str(chapter)] = true
			reward.gems = RULES.first_clear_gems
		var pool: Array[String] = []
		for entry in RULES.items:
			if entry.quality == "epic" and int(entry.chapter) <= chapter:
				pool.append(entry.id)
		# The fifth boss clear since the last epic is guaranteed. Exact item remains uniform.
		var success := rng.randf() < RULES.boss_drop_chance or int(profile.boss_misses) >= RULES.boss_pity - 1
		if success and not pool.is_empty():
			var id := pool[rng.randi_range(0, pool.size() - 1)]
			reward.item = id
			if profile.owned.has(id):
				reward.duplicate = true
				reward.shards += RULES.duplicate_shards
			else:
				profile.owned[id] = 1
			profile.boss_misses = 0
		else:
			profile.boss_misses = mini(int(profile.boss_misses) + 1, RULES.boss_pity - 1)
	for key in ["coins", "gems", "shards"]:
		profile[key] = mini(LIMIT, int(profile[key]) + int(reward[key]))
	profile.reward_serial += 1
	profile.last_reward = reward.duplicate(true)
	return reward

static func reward_text(reward: Dictionary) -> String:
	var message := "金幣 +%d" % int(reward.get("coins", 0))
	if int(reward.get("shards", 0)) > 0:
		message += "　星鐵 +%d" % int(reward.shards)
	if int(reward.get("gems", 0)) > 0:
		message += "　寶石 +%d" % int(reward.gems)
	var entry := item(str(reward.get("item", "")))
	if not entry.is_empty():
		message += "\n%s%s" % [entry.name, "（重複收藏 → 星鐵）" if reward.get("duplicate", false) else "（新收藏）"]
	return message


static func effect_text(entry: Dictionary, level: int) -> String:
	var parts: Array[String] = []
	for key: String in entry.effects:
		var value := float(entry.effects[key]) * effect_multiplier(level)
		match key:
			"counter": parts.append("反擊 +%.1f%%" % (value * 100))
			"splash": parts.append("爆炸半徑 +%.1f" % value)
			"pierce": parts.append("貫穿 +%d" % roundi(value))
			"guard": parts.append("護盾減傷 %.1f%%" % (minf(.6, value) * 100))
			"ambush": parts.append("蓄勢 +%.1f%%" % (value * 100))
			"loyalty": parts.append("忠誠 +%.1f%%" % (value * 100))
			"pack": parts.append("連攜 +%.1f%%" % (value * 100))
			"wave_heal": parts.append("清波治療 %.1f%%" % (minf(.08, value) * 100))
			"control": parts.append("震懾 %.2f 秒" % (RULES.control_time * value))
			"ult_heal": parts.append("必殺治療 %.1f%%" % (minf(.15, value) * 100))
	return "／".join(parts)
