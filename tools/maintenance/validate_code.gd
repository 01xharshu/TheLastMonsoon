extends SceneTree
## Load every GDScript without running test scenes or asset-building commands.
var failures: Array[String] = []
var checked := 0
var shaders := 0
func _initialize() -> void:
	_run.call_deferred()
func _scan(path: String) -> void:
	if FileAccess.file_exists(path.path_join(".gdignore")): return
	var directory := DirAccess.open(path)
	if directory == null: return
	for name in directory.get_files():
		if name.ends_with(".gd"):
			var file := path.path_join(name)
			var script := ResourceLoader.load(file, "GDScript") as GDScript
			checked += 1
			if script == null or not script.can_instantiate(): failures.append(file)
		elif name.ends_with(".gdshader"):
			var shader := ResourceLoader.load(path.path_join(name), "Shader") as Shader
			shaders += 1
			if shader == null: failures.append(path.path_join(name))
			else: shader.get_shader_uniform_list()
	for name in directory.get_directories():
		if not name.begins_with("."): _scan(path.path_join(name))
func _run() -> void:
	var expected := OS.get_environment("TLM_EXPECT_USER_DATA")
	if not expected.is_empty() and OS.get_user_data_dir() != expected:
		push_error("Code-check user-data directory differs from the disposable runner directory")
		root.get_node("SaveManager").quit_game(1)
		return
	_scan("res://")
	print("CODE AUDIT scripts=", checked, " shaders=", shaders, " failures=", failures)
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
