extends "res://tests/integration/playthrough_bot.gd"
## Copies the first committed 1-4 entry. All play and random choices belong to the original bot.

const ENTRY_PATH := "user://archer_1_4_entry.json"


func _ready() -> void:
	if FileAccess.file_exists(ENTRY_PATH):
		push_error("Use a fresh user-data directory for each checkpoint capture.")
		get_tree().quit(2)
		return
	EventBus.level_started.connect(_watch_level)
	super()


func _watch_level(id: StringName) -> void:
	if id == &"1-3":
		# FlowMain connected its save callback when it created this LevelSession.
		flow.get_session().cleared.connect(_copy_entry, CONNECT_ONE_SHOT)


func _copy_entry() -> void:
	var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(ENTRY_PATH))
	if error != OK:
		push_error("Could not copy the committed archer entry: " + error_string(error))
		get_tree().quit(2)
