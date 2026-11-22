extends TestCase
## Real on-disk interruption states, including the complete 1-4 build checkpoint.
const PATH := "user://replacement_recovery_test.json"
const FIXTURE := "res://tests/fixtures/archer_1_4_checkpoint.json"

class RenameFailureStore extends SaveStore:
	var fail_promotion := false
	var fail_restore := false

	func _rename_file(from: String, to: String) -> Error:
		if from == temp_path() and (FileAccess.file_exists(to) or fail_promotion):
			return ERR_FILE_CANT_WRITE
		if from == path + ".bak" and fail_restore:
			return ERR_FILE_CANT_WRITE
		return DirAccess.rename_absolute(from, to)

func before_each() -> void:
	_cleanup()

func after_each() -> void:
	_cleanup()

func _cleanup() -> void:
	for name: String in [PATH, PATH + ".tmp", PATH + ".bak"]:
		if FileAccess.file_exists(name) or DirAccess.dir_exists_absolute(name):
			DirAccess.remove_absolute(name)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(text)
		file.close()

func _old_save() -> Dictionary:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	assert_true(SaveStore.new(PATH).write_data(raw))
	return SaveStore.new(PATH).read()

func test_interruption_after_removing_primary_recovers_full_committed_checkpoint() -> void:
	var old := _old_save()
	assert_true(not old.checkpoint.is_empty())
	assert_eq(DirAccess.rename_absolute(PATH, PATH + ".bak"), OK)
	_write(PATH + ".tmp", '{"level_index":5,"snacks":999999}')
	assert_eq(SaveStore.new(PATH).read(), old, "Recover committed equipment, route, tricks and RNG; do not grant temporary rewards")
	assert_false(FileAccess.file_exists(PATH + ".tmp"))

func test_corrupt_primary_recovers_backup_and_ignores_partial_temp() -> void:
	var old := _old_save()
	assert_eq(DirAccess.copy_absolute(PATH, PATH + ".bak"), OK)
	_write(PATH, '{"version":11,"checkpoint":')
	_write(PATH + ".tmp", '{"snacks":')
	assert_eq(SaveStore.new(PATH).read(), old)

func test_valid_primary_wins_over_stale_backup() -> void:
	_old_save()
	var old_text := FileAccess.get_file_as_string(PATH)
	assert_true(SaveStore.new(PATH).write(5, 31, false))
	_write(PATH + ".bak", old_text)
	assert_true(FileAccess.file_exists(PATH + ".bak"))
	assert_eq(SaveStore.new(PATH).read().snacks, 31)

func test_uncommitted_temp_alone_is_never_promoted() -> void:
	_write(PATH + ".tmp", FileAccess.get_file_as_string(FIXTURE))
	assert_true(SaveStore.new(PATH).read().is_empty())
	assert_false(FileAccess.file_exists(PATH + ".tmp"))

func test_non_replacing_filesystem_commits_new_save() -> void:
	_old_save()
	var store := RenameFailureStore.new(PATH)
	assert_true(store.write(5, 42, false))
	assert_eq(SaveStore.new(PATH).read().snacks, 42)
	assert_false(FileAccess.file_exists(PATH + ".bak"))

func test_failed_promotion_restores_previous_save() -> void:
	var old := _old_save()
	var store := RenameFailureStore.new(PATH)
	store.fail_promotion = true
	assert_false(store.write(5, 42, false))
	assert_true(FileAccess.file_exists(PATH))
	assert_eq(SaveStore.new(PATH).read(), old)

func test_failed_promotion_and_restore_still_recovers_backup() -> void:
	var old := _old_save()
	var store := RenameFailureStore.new(PATH)
	store.fail_promotion = true
	store.fail_restore = true
	assert_false(store.write(5, 42, false))
	assert_true(FileAccess.file_exists(PATH + ".bak"))
	assert_eq(SaveStore.new(PATH).read(), old)
	assert_true(SaveStore.new(PATH).write(4, 18, true))
	assert_eq(SaveStore.new(PATH).read().snacks, 18)

func test_failed_backup_never_removes_primary() -> void:
	var old := _old_save()
	assert_eq(DirAccess.make_dir_absolute(PATH + ".bak"), OK)
	var store := RenameFailureStore.new(PATH)
	assert_false(store.write(5, 42, false))
	assert_eq(SaveStore.new(PATH).read(), old)

func test_corrupt_primary_does_not_overwrite_valid_recovery_copy_on_failure() -> void:
	var old := _old_save()
	assert_eq(DirAccess.copy_absolute(PATH, PATH + ".bak"), OK)
	_write(PATH, '{"checkpoint":')
	var store := RenameFailureStore.new(PATH)
	store.fail_promotion = true
	store.fail_restore = true
	assert_false(store.write(5, 42, false))
	assert_eq(SaveStore.new(PATH).read(), old)

func test_delete_removes_backup_without_resurrecting_progress() -> void:
	_old_save()
	assert_eq(DirAccess.copy_absolute(PATH, PATH + ".bak"), OK)
	SaveStore.new(PATH).delete()
	assert_false(FileAccess.file_exists(PATH + ".bak"))
	assert_true(SaveStore.new(PATH).read().is_empty())
