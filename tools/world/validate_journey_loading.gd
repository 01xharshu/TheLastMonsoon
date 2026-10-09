extends SceneTree
## Small scene fixture exercises the actual asynchronous scene handoff on both routes.
var failures: Array[String] = []
var fixture_path: String
var save_path: String
var original_save_root: String

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _run() -> void:
	var saves := root.get_node("SaveManager")
	original_save_root = saves.save_root
	save_path = OS.get_temp_dir().path_join("tlm_loading_save_" + str(OS.get_process_id()))
	fixture_path = OS.get_temp_dir().path_join("tlm_loading_world_" + str(OS.get_process_id()) + ".tscn")
	saves.save_root = save_path
	DirAccess.make_dir_recursive_absolute(save_path)
	var file := FileAccess.open(saves.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": saves.VERSION, "position": [0,0,0], "saved_at": 1}))
	file.close()
	file = FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=2 format=3]\n[sub_resource type="GDScript" id="Fixture"]\nscript/source = "extends Node3D\nfunc _ready():\n\tfinish.call_deferred()\nfunc finish():\n\tset_meta(\\"slot\\",get_tree().root.get_node(\\"SaveManager\\").pending_slot)\n\tget_tree().root.get_node(\\"SaveManager\\").pending_slot = -1\n"\n[node name="LoadingFixture" type="Node3D"]\nscript = SubResource("Fixture")\n[node name="Camera" type="Camera3D" parent="."]\ncurrent = true\n')
	file.close()
	for slot in [0, 1]:
		change_scene_to_file("res://ui/main_menu.tscn")
		await scene_changed
		var menu := current_scene
		var overlay = load("res://ui/journey_loading.gd").new()
		overlay.world_path = fixture_path
		root.add_child(overlay)
		check(overlay.get_parent() == root and overlay.layer > 100, "Loading artwork must survive scene replacement")
		check(overlay.panel.get_child(0).texture != null, "Loading artwork missing")
		var result: bool = await overlay.begin(slot)
		check(result and current_scene != menu, "Journey did not switch scenes")
		check(current_scene.get_meta("slot", -2) == slot, "New/save route lost pending slot")
		await process_frame
		check(not is_instance_valid(overlay), "Loading overlay did not clean up")
	var rejected = load("res://ui/journey_loading.gd").new()
	root.add_child(rejected)
	var before := current_scene
	check(not await rejected.begin(3), "Missing save must fail")
	check(current_scene == before, "Missing save replaced current scene")
	var broken = load("res://ui/journey_loading.gd").new()
	broken.world_path = fixture_path + ".missing"
	root.add_child(broken)
	check(not await broken.begin(0), "Missing world must fail")
	check(current_scene == before, "Failed load replaced current scene")
	DirAccess.remove_absolute(saves.slot_path(1))
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(fixture_path)
	saves.save_root = original_save_root
	await process_frame
	print("JOURNEY LOADING VALIDATION ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "failures": failures}))
	saves.quit_game(0 if failures.is_empty() else 1)

func _finalize() -> void:
	# Also clean temporary fixture inputs when Godot exits before normal completion.
	if not save_path.is_empty():
		DirAccess.remove_absolute(save_path.path_join("slot_1.json"))
		DirAccess.remove_absolute(save_path)
	if not fixture_path.is_empty(): DirAccess.remove_absolute(fixture_path)
