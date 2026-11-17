extends SceneTree
## Real title -> loading -> populated world -> opening -> player idle ownership.
var failures := 0
var review_dir := OS.get_environment("TLM_IDLE_WORLD_REVIEW")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var expected := OS.get_environment("TLM_EXPECT_USER_DATA")
	if expected.is_empty() or OS.get_user_data_dir() != expected:
		push_error("Integration requires an isolated user-data directory")
		quit(2)
		return
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	for i in 4: await process_frame
	current_scene._finish()
	await create_timer(.75).timeout
	current_scene.play_button.pressed.emit()
	if current_scene != null and current_scene.page == "new_game":
		var confirm: Button
		for button in current_scene.column.find_children("*", "Button", true, false):
			if button.text in ["Confirm", "Begin New Journey"]:
				confirm = button
				break
		if confirm == null:
			push_error("New journey confirmation button not found")
			quit(1)
			return
		confirm.pressed.emit()
	await scene_changed
	var deadline := Time.get_ticks_msec()+240000
	while preload("res://systems/world_startup.gd").current != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(preload("res://systems/world_startup.gd").current == null,"Normal game loading completes")
	for i in 5: await process_frame
	var world: Node3D = current_scene
	var actor: CharacterBody3D = world.get_node("Player")
	var idle: Node = actor.get_node("LongIdle")
	check(idle.look_after == 45 and idle.scratch_after == 58 and idle.sit_after == 120,"Normal world player contains configured idle routine")
	var opening: Node = world.get_node_or_null("OpeningSequence")
	if opening != null and opening.state != "done":
		check(not idle.eligible(),"Opening suppresses idle")
		var skip := InputEventKey.new()
		skip.pressed = true
		skip.keycode = KEY_ESCAPE
		opening._input(skip)
		skip.keycode = KEY_SPACE
		opening._input(skip)
		opening._update_morning(20.36)
	for i in 12: await physics_frame
	check(not actor.get_meta("opening_active",false) and actor.is_physics_processing(),"Opening releases normal player controls")
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	check(visual.model.get_meta("opening_clothing_fitted",0) >= 4,"Opening complete-body fit reaches gameplay")
	# Find supported clear ground near the real village gate, using world collision.
	var start := actor.global_position
	var supported := false
	for offset in [Vector3.ZERO,Vector3(0,0,4),Vector3(4,0,4),Vector3(-4,0,4),Vector3(0,0,8),Vector3(8,0,8),Vector3(-8,0,8)]:
		var p: Vector3 = start+offset
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*8,p-Vector3.UP*8,actor.collision_mask,[actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		actor.global_position = hit.position+Vector3.UP*.91
		actor.velocity = Vector3.ZERO
		idle.cancel(true)
		for i in 10: await physics_frame
		if idle.eligible() and idle.safe_ground():
			supported = true
			break
	check(supported,"Real village terrain supports a clear ground sit")
	if supported:
		idle.set_process_input(false) # Automated fixture is not affected by real mouse activity.
		idle.idle_ui.set_process_input(false)
		for beat in [{"time":45.0,"name":"look"},{"time":58.0,"name":"scratch"},{"time":70.0,"name":"clothes"},{"time":95.0,"name":"stretch"}]:
			idle.cancel(true)
			idle.elapsed = beat.time-.02
			for i in 6: await physics_frame
			check(idle.action == beat.name,"World timer selects "+beat.name)
			for i in 20: await process_frame
			check(visual.motion_tree.ambient_action == beat.name and visual.motion_tree.ambient_blend > .9,"World AnimationTree renders "+beat.name)
			await create_timer(idle.ui_fade_seconds*idle.idle_ui.opacity+.1).timeout
			check(idle.idle_ui.opacity < .01,"World gameplay HUD fades during "+beat.name)
			check(not idle.idle_ui.layers.has(world.get_node("GameMenu")),"Idle fade excludes pause-menu canvas")
			await capture(beat.name)
			if beat.name == "look":
				var menu: Node = world.get_node("GameMenu")
				menu.open()
				for i in 3: await process_frame
				check(paused and idle.idle_ui.opacity == 1 and idle.elapsed == 0,"Pause/map UI restores and resets idle without changing owner visibility")
				idle.idle_ui.set_process_input(true)
				var menu_key := InputEventKey.new()
				menu_key.pressed = true
				menu_key.physical_keycode = KEY_F10
				root.push_input(menu_key)
				check(idle.elapsed == 0,"Paused keyboard input resets idle state")
				var menu_release := menu_key.duplicate() as InputEventKey
				menu_release.pressed = false
				root.push_input(menu_release)
				menu.close()
				idle.idle_ui.set_process_input(false)
				await process_frame
				check(not paused and idle.idle_ui.opacity == 1,"Returning from pause retains restored gameplay UI")
		idle.cancel(true)
		idle.elapsed = idle.sit_after
		for i in 400:
			await process_frame
			if idle.seat >= 1.0: break
		check(idle.seat >= 1.0,"World player completes supported ground entry")
		await capture("sit")
		check(root.get_node("SaveManager").save_game(world,1),"Normal save succeeds while seated")
		var permissions: Node = actor.get_node("ActionPermissions")
		check(not permissions.domain_free(&"attack") and not permissions.domain_free(&"board"),"World seat owns combat/boarding")
		idle.set_process_input(true)
		var draw := InputEventAction.new()
		draw.action = "stow_weapon"
		draw.pressed = true
		root.push_input(draw)
		await process_frame
		check(idle.rising and visual.equipment.stowed,"Actual input stands before drawing a weapon")
		check(idle.idle_ui.opacity == 1,"Seated input immediately restores gameplay HUD")
		var release := draw.duplicate() as InputEventAction
		release.pressed = false
		root.push_input(release)
		Input.action_press("move_backward")
		var before := actor.global_position
		for i in 400:
			await process_frame
			if idle.seat <= 0.0: break
		for i in 30: await physics_frame
		Input.action_release("move_backward")
		check(idle.seat == 0.0 and actor.global_position.distance_to(before) > .2,"World rise hands back movement")
		check(permissions.domain_free(&"attack") and permissions.domain_free(&"board"),"World rise releases action leases")
		await capture("standing")
		check(root.get_node("SaveManager").start_loaded_game(1),"Continue accepts seated save")
		await scene_changed
		deadline = Time.get_ticks_msec()+240000
		while preload("res://systems/world_startup.gd").current != null and Time.get_ticks_msec() < deadline:
			await process_frame
		for i in 15: await physics_frame
		var restored: CharacterBody3D = current_scene.get_node("Player")
		var restored_idle: Node = restored.get_node("LongIdle")
		check(restored_idle.seat == 0 and restored_idle.action == "" and restored_idle.lease < 0,"Continue restores standing with no transient idle lease")
		check(restored_idle.elapsed < 10,"Loading does not count toward unattended idle")
		check(restored_idle.idle_ui.opacity == 1,"Continue restores visible gameplay UI")
		check(restored.get_node("VisualRoot/CharacterVisual").model.get_meta("opening_clothing_fitted",0) >= 4,"Continue retains the same complete body/outfit fit")
		check(restored.get_node("ActionPermissions").domain_free(&"attack"),"Continue restores normal action permissions")
		await capture("continue")
	print("LONG IDLE WORLD INTEGRATION: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL",failures])
	preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures == 0 else 1)

func capture(label: String) -> void:
	if review_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(review_dir.path_join("world_"+label+".png"))
