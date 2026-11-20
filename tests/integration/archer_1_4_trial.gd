extends Node
## Opens the captured level entry through the normal Continue flow, with human input.
## Each launch has its own save and play log. DirAccess removes them on normal exit.

const FIXTURE := "res://tests/fixtures/archer_1_4_checkpoint.json"

var flow: FlowMain
var _profile: DirAccess
var _previous_log_path: String

func _ready() -> void:
	var entry := SaveStore.new(FIXTURE).read()
	_profile = DirAccess.create_temp("doggyknight-archer-")
	if entry.is_empty() or _profile == null:
		push_error("Could not open the archer trial checkpoint or create its temporary profile.")
		get_tree().quit(2)
		return
	var path := _profile.get_current_dir().path_join("save.json")
	if not SaveStore.new(path).write_data(entry):
		get_tree().quit(2)
		return
	_previous_log_path = PlayLog.log_path
	PlayLog.log_path = _profile.get_current_dir().path_join("playlog.jsonl")
	flow = preload("res://game/flow/main.tscn").instantiate() as FlowMain
	flow.save_path = path
	flow.rng_seed = 19
	add_child(flow)
	flow.continue_game()

func _exit_tree() -> void:
	if not _previous_log_path.is_empty():
		PlayLog.log_path = _previous_log_path
