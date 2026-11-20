class_name BuildRoutes
extends RefCounted

const IDS: Array[StringName] = [&"bulwark", &"vanguard", &"spellweaver", &"mistwalker", &"marksman", &"outrider"]

static func get_route(id: StringName) -> BuildRouteData:
	if not IDS.has(id):
		return null
	return load("res://data/routes/%s.tres" % id) as BuildRouteData

static func valid_id(value: Variant, hero: StringName = &"") -> StringName:
	if not value is String and not value is StringName:
		return &""
	var route := get_route(StringName(value))
	return route.id if route != null and (hero == &"" or route.hero == hero) else &""

static func is_route_event(id: StringName) -> bool:
	return id in [&"route_knight", &"route_mage", &"route_archer"]

static func event_for(hero: StringName) -> LevelEvent:
	hero = HeroClasses.valid_id(hero)
	var event := LevelEvent.new()
	event.id = StringName("route_%s" % HeroClasses.valid_id(hero))
	event.title = "UI_ROUTE_TITLE"
	for id in IDS:
		var route := get_route(id)
		if route.hero != hero:
			continue
		var option := EventOption.new()
		option.title = route.title
		option.desc = route.description
		option.icon = "res://assets/icons/tricks/%s.png" % route.starter
		option.tone = "route"
		option.effects = {"route": String(route.id)}
		event.options.append(option)
	return event

static func encounter_for(level_id: StringName) -> LevelEvent:
	return (load("res://data/routes/first_chapter_events.tres") as LevelEventTable).event_for_level(level_id)

static func event_title(id: StringName) -> String:
	if is_route_event(id):
		return "UI_ROUTE_TITLE"
	var table := load("res://data/routes/first_chapter_events.tres") as LevelEventTable
	var event := table.get_event(id)
	return event.title if event != null else "UI_EVENT_TITLE"

## One route-related option alongside normal draws. Evolution slots win first.
## No route means the caller keeps its original offer and RNG consumption.
static func guide_offer(offer: Array[TrickData], deck: TrickDeck, owned: Array, id: StringName) -> Array[TrickData]:
	var route := get_route(id)
	if route == null or offer.is_empty():
		return offer
	for trick in offer:
		if route.preferred.has(trick.id) or trick.is_evolution:
			return offer
	var available := deck.available(owned)
	for preferred in route.preferred:
		if available.has(preferred):
			var result: Array[TrickData] = offer.duplicate()
			result[result.size() - 1] = deck.get_trick(preferred)
			return result
	return offer
