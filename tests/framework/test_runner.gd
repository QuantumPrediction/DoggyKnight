extends Node
## 測試執行器(擁有者:Phase 0 / 整合)。由 tools/run_tests.sh 以 headless 模式啟動。
## 找出 tests/ 下所有 test_*.gd,逐一執行其中 test_ 開頭的方法。
## 參數:-- --filter=<字串>  只執行路徑包含該字串的測試檔。

const TEST_ROOT := "res://tests"
const FRAMEWORK_DIR := "res://tests/framework"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")

	var files := _find_test_files(TEST_ROOT)
	files.sort()
	var total := 0
	var failed := 0
	var broken := 0

	for path in files:
		if not filter.is_empty() and not path.contains(filter):
			continue
		print("\n%s" % path)
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("  BROKEN  cannot load script (parse error?)")
			broken += 1
			continue
		var instance: Object = script.new()
		if not instance is TestCase:
			print("  BROKEN  script does not extend TestCase")
			if instance is Node:
				(instance as Node).free()
			broken += 1
			continue
		var test_case := instance as TestCase
		add_child(test_case)
		for method_name in _test_methods(script):
			total += 1
			test_case._begin_test()
			await test_case.before_each()
			await test_case.call(method_name)
			await test_case.after_each()
			var failures := test_case._end_test()
			if failures.is_empty():
				print("  ok      %s" % method_name)
			else:
				failed += 1
				print("  FAIL    %s" % method_name)
				for failure in failures:
					print("          - %s" % failure)
		test_case.queue_free()
		await get_tree().process_frame

	print("\n%d tests, %d failed, %d broken files" % [total, failed, broken])
	if total == 0:
		print("No tests found.")
	get_tree().quit(1 if failed > 0 or broken > 0 or total == 0 else 0)


func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


func _find_test_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		if not sub.begins_with(".") and dir_path.path_join(sub) != FRAMEWORK_DIR:
			found.append_array(_find_test_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found
