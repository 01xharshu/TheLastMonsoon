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
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var world: Node = load(root.get_node("SaveManager").WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await process_frame
	var player: Node = world.get_node("Player")
	var hud: Control = player.get_node("UI/HUDRoot")
	var tutorial: Control = hud.get_node("MorningTutorial")
	var map: Control = player.get_node("UI/WorldMap")
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	tutorial.set_process(false)
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
	world.get_node("GameMenu").open()
	tutorial._process(20.0)
	check(tutorial.step == 2 and tutorial.responded and tutorial.age == 0.0,"Paused map acknowledges without consuming reading time")
	world.get_node("GameMenu").close()
	tutorial._process(5.0)
	check(tutorial.step == 3 and player.get_meta("tutorial_reading"),"Map interaction advances after five seconds")
	player.velocity = Vector3(1,0,1)
	player._physics_process(.1)
	check(player.velocity == Vector3.ZERO,"Reading phase holds character movement")
	check(not player.get_node("CombatInput").available(),"Reading phase holds combat")
	for stage in range(3,10):
		check(tutorial.step == stage,"Ordered explanation")
		if stage <= 6:
			var rings := hud.get_node("SurvivalHUD").get_children()
			for i in 4: check(rings[i].visible == (i <= stage-3),"Only introduced diamonds visible")
		tutorial._process(10.0)
	check(tutorial.step == 10 and not player.get_meta("tutorial_reading"),"Reading unlocks for horse route")
	check(is_instance_valid(tutorial.horse),"Authored village horse exists")
	check(map.waypoint.is_finite(),"Horse waypoint set")
	if is_instance_valid(tutorial.horse):
		player.set_meta("mounted_vehicle",tutorial.horse)
		tutorial._process(.1)
		player.remove_meta("mounted_vehicle")
	check(tutorial.step == 11 and not player.get_meta("morning_tutorial_active"),"Mount completes tutorial")
	check(world.get_node("DevInquiry").stage == "police","Story begins after horse lesson")
	tutorial.restore_step(5)
	check(tutorial.step == 5 and player.get_meta("tutorial_reading"),"Saved intermediate lesson restores")
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
	world.queue_free()
	for i in 3: await process_frame
	quit(1 if failures else 0)
