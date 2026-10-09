extends SceneTree
## Copy this check into a disposable project with only the forest core folders.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var forest := Node3D.new()
	forest.set_script(load("res://environment/forest/scripts/forest_generator.gd"))
	forest.config = load("res://environment/forest/config/benchmark.tres")
	root.add_child(forest)
	await process_frame
	assert(forest.get_meta("forest_counts").get("canopy", 0) > 0)
	assert(root.get_node_or_null("ForestWindFallback") != null)
	assert(forest.startup_provider == null)
	print("FOREST_PORTABILITY_PASS core imports/generates without world, player, systems or original texture/model folders")
	forest.queue_free()
	await process_frame
	quit()
