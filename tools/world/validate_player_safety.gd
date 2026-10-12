extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(('PASS ' if ok else 'FAIL ')+label)
	if not ok: failures.append(label)
func run() -> void:
	var out := ''
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--output='): out = arg.trim_prefix('--output=')
	if out.is_empty(): quit(2); return
	var saves: Node = root.get_node('SaveManager')
	saves.save_root = out+'/saves'
	saves.settings_path = out+'/settings.cfg'
	DirAccess.make_dir_recursive_absolute(saves.save_root)
	var menu: Node = load('res://ui/main_menu.tscn').instantiate()
	root.add_child(menu); current_scene = menu
	menu.show_settings(); await process_frame
	var panel: Node = menu.column.find_child('SettingsPanel',true,false)
	panel.show_category('Display'); await process_frame
	var preview: Node = panel.find_child('NightPreview',true,false)
	var slider: HSlider = panel.find_child('night_brightness_slider',true,false)
	check(preview != null and slider != null,'Display has character road preview and brightness bar')
	slider.value = 0.0; await process_frame
	var dark: float = preview.environment.ambient_light_energy
	slider.value = 1.0; await process_frame
	check(preview.environment.ambient_light_energy > dark*5,'preview responds across brightness range')
	if DisplayServer.get_name() != 'headless':
		await RenderingServer.frame_post_draw
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+'/display.png')
	saves.options.night_brightness = .2; saves.load_options()
	check(is_equal_approx(float(saves.options.night_brightness),1.0),'night brightness persists')
	if "--preview-only" in OS.get_cmdline_user_args():
		preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1); return
	menu._begin_journey(0)
	while current_scene == null or current_scene.scene_file_path != saves.WORLD: await process_frame
	while preload('res://systems/world_startup.gd').current != null: await process_frame
	for i in 5: await physics_frame
	var world: Node3D = current_scene
	var actor: CharacterBody3D = world.get_node('Player')
	var safety: Node = actor.get_node('PlayerSafety')
	safety.set_physics_process(false)
	actor.set_meta('story_cinematic',false)
	var opening: Node = world.get_node_or_null('OpeningSequence')
	if opening != null: opening.queue_free()
	for i in 2: await process_frame
	# Avoid fixture story/tutor movement while verifying the same live player.
	actor.set_physics_process(false)
	var clock: Node = world.get_node('GameTimeSystem')
	clock.total_game_minutes = 0
	var sun: Node = world.get_node('Sun')
	saves.options.night_brightness = 0.0; sun._update_day_night_lighting()
	dark = sun.environment.ambient_light_energy
	saves.options.night_brightness = 1.0; sun._update_day_night_lighting()
	check(is_equal_approx(sun.environment.ambient_light_energy,preload('res://world/suryagarh/systems/sun_controller.gd').night_ambient(1.0)) if is_instance_valid(preview) else sun.environment.ambient_light_energy > dark*5,'world night responds to same brightness curve')
	check(saves.save_game(world,4),'actual world writes checkpoint separately from manual slots')
	check(not saves.read_slot(4).is_empty() and saves.newest_slot()==0,'checkpoint is readable and does not consume a manual slot')
	var horse: Node3D = world.get_node('VillageHorse')
	horse.set_physics_process(false)
	horse.rider = actor; horse.saved_layer = actor.collision_layer; horse.saved_mask = actor.collision_mask
	actor.set_meta('mounted_vehicle',horse)
	horse.global_position = Vector3(safety.layout.river_x(0),-.1,0)
	actor.global_position = horse.global_position+Vector3.UP*1.5
	safety._physics_process(1.0/60.0)
	check(horse.vitality.dead and horse.rider==null,'river kills horse and releases its rider')
	check(actor.health>0 and (actor.get_meta('mounted_vehicle') if actor.has_meta('mounted_vehicle') else null)==null and actor.velocity.y>0 and actor.velocity.length()>4,'Arjun survives with jump velocity into river')
	var escape_start: Vector3 = actor.global_position
	actor.set_physics_process(true)
	for i in 100: await physics_frame
	check(actor.health>0 and actor.is_swimming and actor.global_position.distance_to(escape_start)>1.5,'river jump physically clears horse and resumes swimming')
	actor.set_physics_process(false)
	var cart: Node3D = load('res://vehicles/horse_cart_candidate.gd').new()
	world.add_child(cart)
	for i in 3: await physics_frame
	cart.boarding.set_physics_process(false)
	cart.boarding.rider = actor
	cart.boarding.seat_name = 'DriverSeat'; cart.boarding.role = 'driver'
	cart.boarding.saved_layer = actor.collision_layer; cart.boarding.saved_mask = actor.collision_mask
	actor.set_meta('mounted_vehicle',cart.boarding)
	cart.global_position = Vector3(safety.layout.river_x(20),-.1,20)
	actor.global_position = cart.global_position+Vector3.UP*1.5
	safety._physics_process(1.0/60.0)
	check(not cart.can_move() and cart.boarding.rider==null and actor.health>0,'river kills cart horse, stops cart and releases living Arjun')
	# Both carriage passenger seats must clear the actual cabin, steps and obstacles.
	var carriage: Node3D = load('res://vehicles/family_carriage_candidate.gd').new()
	carriage.add_to_group('household_coach') # Existing occupied-coach path; no duplicate driver.
	world.add_child(carriage)
	carriage.boarding.set_physics_process(false)
	carriage.global_position = Vector3(safety.layout.river_x(50),-.1,50)
	for i in 3: await physics_frame
	for seat in ['RearPassengerRight','RearPassengerLeft','CoachmanSeat']:
		safety.finish_river_escape()
		carriage.boarding.rider = actor; carriage.boarding.seat_name = seat
		carriage.boarding.role = 'driver' if seat=='CoachmanSeat' else 'passenger'
		carriage.boarding.saved_layer = actor.collision_layer; carriage.boarding.saved_mask = actor.collision_mask
		actor.set_meta('mounted_vehicle',carriage.boarding); actor.set_meta('cart_role',carriage.boarding.role)
		actor.global_position = carriage.seat_sockets[seat].global_position
		carriage.boarding._sync_rider()
		var exit_pose: Dictionary = safety.river_escape_pose(carriage.boarding,carriage)
		check(not exit_pose.is_empty(),seat+': clear deep-water escape available')
		check(safety.escape_river(carriage.boarding,carriage),seat+': released from actual carriage')
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = actor.get_node('CollisionShape3D').shape
		clearance.transform = Transform3D(actor.global_basis,exit_pose.position)*actor.get_node('CollisionShape3D').transform
		clearance.collision_mask = actor.collision_mask; clearance.exclude = [actor.get_rid()]
		check(actor.get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty(),seat+': rider capsule clears cabin and steps')
		check(not carriage.can_move() and actor.health>0,seat+': both horses dead and player alive')
		check(actor.global_position.distance_to(exit_pose.start)<0.01,seat+': jump starts at seat without sideways teleport')
		actor.set_physics_process(true)
		for i in 100: await physics_frame
		check(safety.escape_colliders.is_empty() and actor.is_swimming and actor.health>0,seat+': jump clears cabin, restores vehicle collision and swims')
		actor.set_physics_process(false)
	# A blocked exit kills the horses but retains the live rider for a later clear retry.
	carriage.boarding.rider = actor; actor.set_meta('mounted_vehicle',carriage.boarding)
	actor.global_position = carriage.seat_sockets.RearPassengerRight.global_position
	var blocker := StaticBody3D.new(); world.add_child(blocker)
	var block_shape := CollisionShape3D.new(); var block_box := BoxShape3D.new()
	block_box.size = Vector3(20,10,20); block_shape.shape = block_box; blocker.add_child(block_shape)
	blocker.global_position = actor.global_position
	for i in 2: await physics_frame
	check(not safety.escape_river(carriage.boarding,carriage) and carriage.boarding.rider==actor and actor.health>0,'blocked river exit retains living rider instead of placing inside obstacle')
	blocker.queue_free()
	for i in 2: await physics_frame
	check(safety.escape_river(carriage.boarding,carriage),'river escape retries once obstacle clears')
	var landing := StaticBody3D.new(); world.add_child(landing)
	var floor_shape := CollisionShape3D.new(); var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20,1,20); floor_shape.shape = floor_box; landing.add_child(floor_shape)
	landing.global_position = Vector3(700,100,700)
	cart.global_position = landing.global_position+Vector3.UP*13.5
	cart.boarding.rider = actor; actor.set_meta('mounted_vehicle',cart.boarding)
	var wall := StaticBody3D.new(); world.add_child(wall)
	var wall_shape := CollisionShape3D.new(); var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(8,8,1); wall_shape.shape = wall_box; wall.add_child(wall_shape)
	wall.global_position = cart.global_position-cart.global_basis.z*8.0
	for i in 2: await physics_frame
	cart.boarding.speed = 15.0
	var swept: Vector3 = cart.boarding._fall_horizontal_motion(1.0)
	check(swept.length()<8.0 and cart.boarding.speed==0.0,'falling cart sweeps its full volumes and stops before a wall')
	wall.queue_free()
	safety.tracked_vehicle = cart; safety.peak = cart.global_position.y
	for i in 130:
		await physics_frame
		cart.boarding._fall_step(1.0/60.0)
		safety._physics_process(1.0/60.0)
		if actor.health<=0: break
	check(actor.health==0.0,'large mounted land drop kills Arjun')
	actor.health = 0.0
	safety._physics_process(1.0/60.0)
	check(safety.death_open and paused,'zero health opens death screen and pauses gameplay')
	var labels: Array[String] = []
	for button in safety.find_children('*','Button',true,false): labels.append(button.text)
	check(labels==['Load from last checkpoint','Back to Main Menu'],'death has exactly the requested choices')
	if DisplayServer.get_name() != 'headless':
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+'/death.png')
	var expected: Array = saves.read_slot(4).position
	var reload_button: Button = safety.find_children('*','Button',true,false)[0]
	reload_button.pressed.emit()
	while current_scene == world or current_scene==null: await process_frame
	for i in 90: await physics_frame
	var restored: Node = current_scene.get_node('Player')
	check(restored.health>0 and not restored.get_meta('dead',false),'death checkpoint reload restores a living player')
	check(restored.global_position.distance_to(Vector3(expected[0],expected[1],expected[2]))<2.0,'death checkpoint restores saved world position')
	restored.set_physics_process(false)
	var restored_safety: Node = restored.get_node('PlayerSafety')
	restored_safety.set_physics_process(false)
	var foot_floor := StaticBody3D.new(); current_scene.add_child(foot_floor)
	var foot_shape := CollisionShape3D.new(); var foot_box := BoxShape3D.new()
	foot_box.size = Vector3(20,1,20); foot_shape.shape = foot_box; foot_floor.add_child(foot_shape)
	foot_floor.global_position = Vector3(700,100,700)
	restored.global_position = Vector3(700,114,700); restored.velocity = Vector3.ZERO
	restored.is_swimming = false
	for i in 140:
		await physics_frame
		restored.velocity.y -= 9.8/60.0
		restored._move_with_fall_damage()
		if restored.health<=0: break
	check(restored.health==0.0,'large on-foot land impact also kills Arjun')
	await process_frame
	check(restored_safety.death_open,'on-foot impact opens the same death menu')
	var back_button: Button = restored_safety.find_children('*','Button',true,false)[1]
	back_button.pressed.emit()
	while current_scene==null or current_scene.scene_file_path!='res://ui/main_menu.tscn': await process_frame
	check(not paused,'Back to Main Menu opens title and clears death pause')
	print('PLAYER SAFETY: '+('PASS' if failures.is_empty() else 'FAIL'))
	preload('res://tools/test_audio_cleanup.gd').finish(self,0 if failures.is_empty() else 1)
