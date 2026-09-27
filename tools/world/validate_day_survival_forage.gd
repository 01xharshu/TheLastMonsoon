extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("validate")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func capture(path: String) -> void:
	for i in 8: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
func exercise_movement(world: Node3D, player: CharacterBody3D) -> void:
	print("CHECK: actual sprint and blocked movement")
	# Exercise collision and the actual controller on an isolated flat fixture.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 1, 40)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.position = Vector3(5000, -0.5, 5000)
	player.global_position = Vector3(5000, 0.92, 5008)
	player.velocity = Vector3.ZERO
	player.is_swimming = false
	player.camera_pivot.global_rotation.y = 0.0
	player.survival.stamina = 100.0
	player.survival.is_exhausted = false
	for i in 15:
		await physics_frame
		player._physics_process(1.0 / 60.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var start: Vector3 = player.global_position
	for i in 120:
		await physics_frame
		player._physics_process(1.0 / 60.0)
		player.survival._update_stamina(1.0 / 60.0)
	var distance := Vector2(player.global_position.x-start.x,player.global_position.z-start.z).length()
	check(distance > 10.0, "Actual controller did not sprint")
	var expected: float = 100.0 - distance / player.sprint_speed * player.survival.sprint_stamina_loss_per_second
	check(absf(player.survival.stamina - expected) < 0.1, "Sprint drain does not match distance travelled")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(5, 3, 0.1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.global_position = player.global_position + Vector3(0,0,-0.6)
	for i in 60:
		await physics_frame
		player._physics_process(1.0 / 60.0)
		player.survival._update_stamina(1.0 / 60.0)
	var blocked_stamina: float = player.survival.stamina
	for i in 30:
		await physics_frame
		player._physics_process(1.0 / 60.0)
		player.survival._update_stamina(1.0 / 60.0)
	check(not player.survival.is_sprinting, "Wall-blocked player still sprints")
	check(player.survival.stamina >= blocked_stamina, "Wall-blocked sprint drained stamina")
	print("CHECK: movement fixture complete")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	wall.queue_free()
	floor_body.queue_free()
	player.velocity = Vector3.ZERO

func validate() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player = world.get_node("Player")
	var clock = world.get_node("GameTimeSystem")
	var sun = world.get_node("Sun")
	var moon = world.get_node("Moon")
	player.set_physics_process(false)
	world.set_physics_process(false)
	clock.set_process(false)
	player.survival.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 5: await physics_frame
	check(world.get_node_or_null("GameTimeSystem2") == null, "Duplicate clock")
	check(world.get_node_or_null("Sun2") == null, "Duplicate sun")
	var start: float = clock.total_game_minutes
	clock._process(600.0)
	check(is_equal_approx(clock.total_game_minutes - start, 1440.0), "600 seconds must advance exactly one day")
	check(clock.current_day == 2 and clock.current_hour == 9, "Day rollover failed")
	# Real playback advances in many small frames, not one 600-second jump.
	clock.total_game_minutes = 540.0
	for i in 36000: clock._process(1.0 / 60.0)
	check(clock.current_day == 2 and clock.current_hour == 9 and clock.current_minute == 0, "Frame-by-frame day ends at wrong clock minute")
	clock.clock_paused = true
	start = clock.total_game_minutes
	clock._process(60)
	check(clock.total_game_minutes == start, "Paused clock advanced")
	clock.clock_paused = false
	var survival = player.survival
	survival.stamina = 100
	survival.set_sprinting(true)
	survival._update_stamina(10)
	check(is_equal_approx(survival.stamina, 50), "Ten seconds of sprint must use 50 stamina")
	survival._update_stamina(10)
	check(survival.is_exhausted and survival.stamina == 0, "Continuous running must exhaust stamina")
	survival._update_stamina(2.5)
	check(not survival.is_exhausted and is_equal_approx(survival.stamina,25), "Recovery failed")
	survival.set_sprinting(false)
	survival._update_stamina(1)
	check(is_equal_approx(survival.stamina,35), "Walking/idle should recover")
	world.hide()
	await exercise_movement(world, player)
	world.show()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-225, world.layout.height(-225, 176) + 6, 190)
	camera.look_at(Vector3(-240, world.layout.height(-240,176) + 2,176))
	camera.make_current()
	player.get_node("UI").hide()
	for hour in [12, 18, 0]:
		clock.total_game_minutes = hour * 60.0
		clock._update_readable_time(true)
		sun._update_day_night_lighting()
		if hour == 12: check(sun.light_energy > 1 and moon.light_energy < 0.01, "Noon lights incorrect")
		if hour == 0: check(sun.light_energy < 0.01 and moon.light_energy > 0.1 and sun.environment.ambient_light_energy < 0.2, "Night lights incorrect")
		await capture("res://docs/world/captures/forage_%s.png" % hour)
	clock.total_game_minutes = 720
	clock._update_readable_time(true)
	sun._update_day_night_lighting()
	var fruit: Node3D
	for child in world.get_node("ForageGrove").get_children():
		if child is Interactable:
			fruit = child
			break
	check(fruit != null, "No reachable fruit spawned")
	player.position = fruit.position + Vector3(0,0.8,0.65)
	player.rotation = Vector3.ZERO
	player.visual_root.rotation.y = PI
	player.camera_pivot.rotation = Vector3(-0.3,0,0)
	player.velocity = Vector3.ZERO
	for i in 3: await physics_frame
	player._update_interaction()
	check(player.current_interactable == fruit, "Facing fruit did not show prompt")
	player.get_node("UI").show()
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
	await capture("res://docs/world/captures/forage_prompt.png")
	player.visual_root.rotation.y = 0
	player._update_interaction()
	check(player.current_interactable == null, "Fruit behind player was targeted")
	player.visual_root.rotation.y = PI
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,2,0.1)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = player.position + Vector3(0,0,-0.325)
	for i in 3: await physics_frame
	check(player._find_interactable() == null, "Pickup through wall")
	wall.queue_free()
	for i in 3: await physics_frame
	# First-person uses view direction rather than the independently facing body.
	player.first_person = true
	player.visual_root.rotation.y = 0
	check(player._find_interactable() == fruit, "First-person facing did not select fruit")
	player.first_person = false
	player.visual_root.rotation.y = PI
	var before: Vector3 = player.position
	player.position += Vector3(0,0,5)
	check(player._find_interactable() == null, "Distant fruit was reachable")
	player.position = before
	# Drive the held input path used by the live game, including early release.
	Input.action_press("interact")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	player._unhandled_input(press)
	player._update_interaction()
	player._advance_interaction_hold(0.2)
	Input.action_release("interact")
	player._advance_interaction_hold(0.1)
	check(not fruit.collected and player.hold_target == null, "Released pickup still collected fruit")
	Input.action_press("interact")
	player._unhandled_input(press)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	player._physics_process(1.0 / 60.0)
	check(not survival.is_sprinting, "Held pickup drained sprint stamina")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	player._update_interaction()
	player._advance_interaction_hold(0.7)
	Input.action_release("interact")
	check(fruit.collected and player.hold_target == null, "Held pickup did not complete")
	fruit.interact(player)
	check(player.inventory.get_item_count("mango") == 1, "Pickup was duplicated")
	survival.satiety = 50
	survival.hydration = 50
	check(player.consumables.eat_mango(), "Satchel eating failed")
	check(survival.satiety == 62 and survival.hydration == 56, "Mango nutrition incorrect")
	check(player.inventory.get_item_count("mango") == 0, "Eating did not consume fruit")
	var fresh = load("res://objects/mango.gd").new()
	world.add_child(fresh)
	fresh.secondary_interact(player)
	check(fresh.collected and survival.satiety == 74, "Eat on spot failed")
	var full_fruit = load("res://objects/mango.gd").new()
	world.add_child(full_fruit)
	survival.satiety = 100
	survival.hydration = 100
	full_fruit.secondary_interact(player)
	check(not full_fruit.collected, "Eating while full destroyed fruit")
	var report := {"passed": failures.is_empty(), "failures": failures, "real_seconds_per_day":600, "full_sprint_seconds":20, "rendered":DisplayServer.get_name() != "headless", "movement_and_hold_checked":true, "frame_clock_checked":true}
	FileAccess.open("res://docs/world/day_survival_forage_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DAY / STAMINA / FORAGE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
