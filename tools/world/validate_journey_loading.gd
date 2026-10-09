extends SceneTree
## Small scene fixture exercises the actual asynchronous scene handoff on both routes.
var failures: Array[String] = []
var fixture_path: String
var save_path: String
var original_save_root: String
var held_frames := 0

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
	var fixture := Node3D.new()
	fixture.name = "LoadingFixture"
	var source := GDScript.new()
	source.source_code = """extends Node3D
class Opening extends Node:
 var state = "night"
 var elapsed = 0.0
 var waiting_for_reveal = false
 func _process(delta):
  if not waiting_for_reveal: elapsed += delta
func _ready():
 finish.call_deferred()
func finish():
 var saves = get_tree().root.get_node("SaveManager")
 set_meta("slot",saves.pending_slot)
 if saves.pending_slot == 0:
  var opening = Opening.new()
  opening.name = "OpeningSequence"
  add_child(opening)
 saves.pending_slot = -1
"""
	check(source.reload() == OK,"Loading fixture script failed")
	fixture.set_script(source)
	var camera := Camera3D.new()
	camera.name = "Camera"
	fixture.add_child(camera)
	camera.owner = fixture
	camera.current = true
	var packed := PackedScene.new()
	check(packed.pack(fixture) == OK,"Loading fixture pack failed")
	check(ResourceSaver.save(packed,fixture_path) == OK,"Loading fixture save failed")
	fixture.free()
	process_frame.connect(_observe_opening_hold)
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
		if slot == 0:
			var opening := current_scene.get_node("OpeningSequence")
			check(held_frames > 2,"Cinematic was not held while loading artwork cleared")
			check(not opening.waiting_for_reveal and opening.elapsed < .2,"Loading consumed the match-strike timeline")
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

func _observe_opening_hold() -> void:
	if current_scene == null: return
	var opening := current_scene.get_node_or_null("OpeningSequence")
	if opening != null and opening.waiting_for_reveal:
		held_frames += 1
		check(opening.elapsed == 0.0,"Timeline advanced behind loading artwork")
