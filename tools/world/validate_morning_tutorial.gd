extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func press(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
func quiet_unrelated(node: Node, player: Node, horse: Node) -> void:
	if node == player or node == horse: return
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): quiet_unrelated(child,player,horse)
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var world: Node = load(root.get_node("SaveManager").WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await process_frame
	var player: Node = world.get_node("Player")
	quiet_unrelated(world,player,world.get_node("VillageHorse"))
	var hud: Control = player.get_node("UI/HUDRoot")
	var tutorial: Control = hud.get_node("MorningTutorial")
	var map: Control = player.get_node("UI/WorldMap")
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	tutorial.set_process(false)
	var opening: Node = world.get_node_or_null("OpeningSequence")
	if opening == null:
		opening = preload("res://story/opening_sequence.gd").new()
		opening.name = "OpeningSequence"
		world.add_child(opening)
		opening.start(world)
	# The separate opening validator covers the cinematic timeline. Release its
	# ownership here so this focused check measures onboarding and real boarding.
	opening.morning()
	player.global_position = opening.home.to_global(Vector3(0,.94,8.2))
	opening._release()
	opening.set_process(false)
	tutorial.begin()
	check(not map.minimap.visible and not hud.get_node("SurvivalHUD").visible,"Movement starts with HUD hidden")
	tutorial._input(press("move_left"))
	check(tutorial.step == 0,"Wrong direction cannot complete forward lesson")
	tutorial._input(press("move_forward"))
	check(tutorial.step == 1,"Forward lesson advances")
	tutorial._input(press("move_right"))
	check(tutorial.step == 2 and map.minimap.visible,"Any lateral/back direction reveals map")
	check(map.minimap.position.is_equal_approx(hud.size-Vector2(200,200)),"Map retains original bottom-right position")
	check(tutorial.prompt.position.is_equal_approx(Vector2(24,32)),"Only instructions at top left")
	check(not tutorial.has_method("_draw"),"Tutorial draws no highlight boxes")
	tutorial._input(press("move_forward"))
	check(tutorial.responded,"Movement acknowledges map introduction without opening it")
	world.get_node("GameMenu").open()
	tutorial._process(20.0)
	check(tutorial.step == 2 and tutorial.responded and tutorial.age == 0.0,"Paused map acknowledges without consuming reading time")
	world.get_node("GameMenu").close()
	tutorial._process(10.0)
	check(tutorial.step == 3 and not player.get_meta("tutorial_reading"),"Map interaction advances after ten seconds")
	var before: Vector3=player.global_position
	Input.action_press("move_forward")
	for frame in 12:player._physics_process(1.0/60);await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.distance_to(before)>.15,"Character moves while HUD explanation is active")
	for stage in range(3,10):
		check(tutorial.step == stage,"Ordered explanation")
		if stage <= 6:
			var rings := hud.get_node("SurvivalHUD").get_children()
			for i in 4: check(rings[i].visible == (i <= stage-3),"Only introduced diamonds visible")
		tutorial._process(20.0)
	check(tutorial.step == 10 and not player.get_meta("tutorial_reading"),"Reading unlocks for horse route")
	check(is_instance_valid(tutorial.horse),"Authored village horse exists")
	check(map.waypoint.is_finite(),"Horse waypoint set")
	if is_instance_valid(tutorial.horse):
		player.global_position=tutorial.horse.global_position+Vector3(1,.9,0)
		check(tutorial.horse.board(player),"Actual authored horse boarding starts")
		for frame in 20:
			tutorial.horse._physics_process(.1)
			await physics_frame
		tutorial._process(.1)
	check(tutorial.step == 11 and not player.get_meta("morning_tutorial_active"),"Mount completes tutorial")
	var story: Node=world.get_node("DevStory")
	story._process(0)
	check(story.active and story.cue=="horse_departure","Seated horse starts cinematic travel")
	story.finish()
	tutorial.restore_step(5)
	check(tutorial.step == 5 and not player.get_meta("tutorial_reading"),"Saved intermediate lesson restores")
	if DisplayServer.get_name() != "headless" and OS.get_environment("TLM_TUTORIAL_OUTPUT") != "":
		for value in [0,2,5,10]:
			tutorial.restore_step(value)
			for frame in 3: await process_frame
			check(not world.get_node("DevInquiry").objective.visible,"Story copy stays hidden during onboarding")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/tutorial_%d.png" % value)
	tutorial.restore_step(11)
	check(hud.tutorial_reveal == 99 and not tutorial.visible,"Completed/legacy saves retain full HUD")
	print("MORNING TUTORIAL: ","PASS" if failures == 0 else "FAIL", " | movement, staged HUD, paused Escape map, timing, horse, restore")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	world.queue_free()
	for i in 3: await process_frame
	await preload("res://tools/test_audio_cleanup.gd").finish(self,1 if failures else 0)
