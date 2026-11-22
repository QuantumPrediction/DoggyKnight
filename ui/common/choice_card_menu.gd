extends Control
## Shared input for mandatory, single-column offers. Each menu owns its choices.

var cards: Array[Button] = []
var _accept_at: float = 0.0


func _open_card_input(delay: float) -> void:
	_accept_at = Time.get_ticks_msec() / 1000.0 + delay
	for i in cards.size():
		var card := cards[i]
		# Follow data order even while the entrance tween moves the cards.
		var previous := card.get_path_to(cards[posmod(i - 1, cards.size())])
		var next := card.get_path_to(cards[(i + 1) % cards.size()])
		card.focus_previous = previous
		card.focus_next = next
		card.focus_neighbor_top = previous
		card.focus_neighbor_bottom = next
		card.focus_neighbor_left = ^"."
		card.focus_neighbor_right = ^"."
	if not cards.is_empty():
		cards[0].grab_focus(OS.has_feature("mobile"))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# This project's ui_accept has keyboard bindings only. Translate the pad's
	# south button locally so the focused card uses the same native press/release.
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and not event.is_action(&"ui_accept"):
		var viewport := get_viewport()
		if cards.has(viewport.gui_get_focus_owner()):
			var accept := InputEventAction.new()
			accept.action = &"ui_accept"
			accept.pressed = event.pressed
			viewport.push_input(accept)
			viewport.set_input_as_handled()
		return
	# A key pressed during the entrance must not arm a button for a later release.
	if event.is_action_pressed(&"ui_accept", true) and (event.is_echo() or Time.get_ticks_msec() / 1000.0 < _accept_at):
		get_viewport().set_input_as_handled()
