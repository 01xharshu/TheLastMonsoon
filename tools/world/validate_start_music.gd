extends SceneTree
## The first title screen and opening world load must not start score music.

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	var menu: PackedScene = load("res://ui/main_menu.tscn")
	var title := menu.instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	for child in root.find_children("*", "AudioStreamPlayer", true, false):
		assert(not child.playing or child.bus != "Music", "Title screen started score music")
	title.queue_free()
	await process_frame
	var world: PackedScene = load("res://world/suryagarh/suryagarh_world.tscn")
	var state := world.get_state()
	var found := false
	for node_index in state.get_node_count():
		if state.get_node_name(node_index) != "BackgroundMusic": continue
		found = true
		var autoplays := false
		for property_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == "autoplay":
				autoplays = bool(state.get_node_property_value(node_index, property_index))
		assert(not autoplays, "World score will autoplay during the opening")
	assert(found, "World score node missing")
	print("START MUSIC: PASS | title and world score silent at launch")
	quit()
