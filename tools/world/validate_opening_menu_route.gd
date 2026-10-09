extends SceneTree
## Actual main-menu loader → Suryagarh → cinematic → morning control handoff.
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func run() -> void:
	var saves := root.get_node("SaveManager")
	saves.options.fullscreen = false
	saves.options.graphics_quality = 0
	saves.apply_options()
	change_scene_to_file("res://ui/main_menu.tscn")
	await scene_changed
	print("OPENING MENU: entering real new-game loader")
	current_scene._begin_journey(0)
	var loading: Node
	for child in root.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://ui/journey_loading.gd": loading = child; break
	await scene_changed
	# The menu is freed by scene replacement; observe the root-owned overlay.
	while is_instance_valid(loading): await process_frame
	var world := current_scene
	var opening := world.get_node_or_null("OpeningSequence")
	check(opening != null,"New Journey did not create the live opening")
	if opening != null:
		check(opening.elapsed < .2,"Loading artwork consumed the match-strike timeline")
		check(opening.state == "prologue" and opening.prologue_elapsed < .2,"Loading artwork consumed the story cards")
		check(not opening.waiting_for_reveal,"Loading left the cinematic frozen")
		check(root.get_node("WorldAudio").is_opening_quiet(),"New Journey leaked night ambience")
		check(opening.lamp.scale.is_equal_approx(Vector3.ONE*.35),"New Journey uses the old lamp")
		check(world.is_ancestor_of(opening.home),"Opening home is outside the live world")
		opening.morning()
		check(world.get_node("WorldEnvironment").environment.ambient_light_energy >= .3,"Main-menu morning remains dark")
		check(not root.get_node("WorldAudio").is_opening_quiet(),"Main-menu morning remains muted")
		while opening.state != "done": await process_frame
		check(opening.state == "done" and world.player.is_physics_processing(),"Main-menu opening did not restore gameplay")
	print("OPENING MENU: ","FAIL" if failed else "PASS"," | real loading route, full ignition timeline, shared world, dawn and controls")
	saves.quit_game(1 if failed else 0)
