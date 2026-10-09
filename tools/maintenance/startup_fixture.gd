extends RefCounted
## Exercise the configured startup, including any studio ident, before menu tests.
static func open_title(tree: SceneTree) -> Node:
	var startup: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if startup.is_empty() or tree.change_scene_to_file(startup) != OK:
		push_error("Configured startup scene could not be opened")
		return null
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		var scene := tree.current_scene
		if scene != null and scene.scene_file_path == "res://ui/main_menu.tscn" and scene.has_method("show_main"):
			print("STARTUP INTEGRATION PASS | ", startup, " -> title menu")
			return scene
	push_error("Configured startup did not reach the title menu within 30 seconds")
	return null
