class_name AttackTechniques
extends RefCounted

const IDS: Array[StringName] = [&"arc_rune", &"starfall", &"gale_disc"]
const MARKS := preload("res://assets/illustrated/techniques/combination_marks.webp")
const PAIR_IDS: Array[StringName] = [&"arc_gale", &"arc_star", &"gale_star"]
const PAIRS := [
	[&"arc_rune", &"gale_disc", "TECH_ARC_GALE"],
	[&"arc_rune", &"starfall", "TECH_ARC_STAR"],
	[&"gale_disc", &"starfall", "TECH_GALE_STAR"],
]


static func mark_region(id: StringName) -> Rect2:
	return Rect2(PAIR_IDS.find(id) * 96, 0, 96, 96)


static func pair_hints(candidate: StringName, owned: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for pair: Array in PAIRS:
		if candidate == pair[0] and owned.has(pair[1]) or candidate == pair[1] and owned.has(pair[0]):
			result.append(TranslationServer.translate(pair[2]))
	return result


static func card_description(card: TrickData, owned: Array) -> String:
	var base := String(TranslationServer.translate(card.description))
	if not IDS.has(card.id):
		return base
	var partners := pair_hints(card.id, owned)
	if partners.is_empty():
		var clue: String = {&"arc_rune": "TECH_HINT_ARC", &"starfall": "TECH_HINT_STAR", &"gale_disc": "TECH_HINT_GALE"}[card.id]
		partners.append(TranslationServer.translate(clue))
	return base + "\n" + "、".join(partners)


## Reserve a spare ordinary slot at the first level-up, and a partner at odd levels
## when the player has chosen a technique. Evolution and route choices take priority.
static func guide_offer(offer: Array[TrickData], deck: TrickDeck, owned: Array, hero: StringName,
		level: int, route_id: StringName) -> Array[TrickData]:
	var learned: Array[StringName] = []
	for id in IDS:
		if owned.has(id):
			learned.append(id)
	if offer.size() < 2 or learned.size() == IDS.size():
		return offer
	if learned.is_empty() and level != 2 or not learned.is_empty() and level % 2 == 0:
		return offer
	for card in offer:
		if IDS.has(card.id) and not learned.has(card.id):
			return offer
	var start := IDS.find({&"mage": &"starfall", &"archer": &"arc_rune"}.get(hero, &"gale_disc"))
	var route := BuildRoutes.get_route(route_id)
	for step in IDS.size():
		var id := IDS[(start + step) % IDS.size()]
		if learned.has(id) or not deck.has_trick(id) or deck.is_maxed(id, owned):
			continue
		for slot in range(offer.size() - 1, -1, -1):
			var card := offer[slot]
			if card.is_evolution or route != null and route.preferred.has(card.id):
				continue
			var result := offer.duplicate()
			result[slot] = deck.get_trick(id)
			return result
	return offer
