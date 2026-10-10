extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("TLM_CART_OUTPUT") == "": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TLM_CART_OUTPUT")+"/"+name+".png")
func quiet_unrelated(node: Node, retained: Array[Node]) -> void:
	if node in retained: return
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): quiet_unrelated(child,retained)
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var saves: Node = root.get_node("SaveManager")
	var options: Dictionary = saves.options.duplicate(true)
	saves.options.fullscreen = false
	saves.options.graphics_quality = 0
	saves.apply_options()
	var world: Node = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await process_frame
	var opening: Node3D = preload("res://story/opening_sequence.gd").new()
	world.add_child(opening)
	opening.start(world)
	opening.set_process(false)
	var cart: Node3D = world.get_node("LiveCarts/VillageBullockCart")
	var saved_transform := cart.global_transform
	check(opening.titles.CARDS[6][0] == "HeyaHarshu Creative Studio Presents","Studio credit must match exact requested spelling")
	# Seek the card boundary; the passage stages existing residents under black.
	opening.prologue_elapsed = opening.Titles.DURATION
	opening._process(.01)
	check(opening.state == "cart_passage","Cards must lead to cart, not room")
	var passage = opening.cart_passage
	check(passage.active and cart.global_position.is_equal_approx(passage.position_at(0)),"Real cart starts on village lane")
	# Focus the visual check on the borrowed actors, cart and night lighting.
	# Other world actors remain authored/visible but their simulation is suspended.
	var retained: Array[Node] = [opening,cart,world.find_child("VillageNightLife",true,false)]
	for record in passage.people: retained.append(record.actor)
	quiet_unrelated(world,retained)
	check(cart.get_meta("public_passenger_service",false),"Opening uses the public passenger cart")
	check(cart.get_meta("npc_occupied_seats",[]).size()==2,"Opening carries two existing MPFB passengers")
	var previous := cart.global_position
	var wheel_rotation: float = cart.wheels[0].rotation.x
	check(passage.people.size() >= 2,"Existing people are staged before reveal")
	var fixed_camera := Vector3.INF
	var photographed: Dictionary = {}
	var gathering: Node = world.find_child("FireGatheringResidents",true,false)
	check(gathering != null,"Existing night gathering is integrated")
	if DisplayServer.get_name() == "headless":
		for frame in range(1,230):
			opening._process(.1)
			check(cart.global_position.z > previous.z,"Cart moves forward without stopping during fades")
			previous = cart.global_position
			if passage.age>=8.5 and passage.age<12.7:
				check("Bhairavpur" in opening.subtitle.text and passage.arrival_called,"Driver arrival dialogue is integrated")
			if passage.age >= 13:
				if not fixed_camera.is_finite(): fixed_camera = opening.camera.global_position
				check(opening.camera.global_position.is_equal_approx(fixed_camera),"Wheel camera must hold still")
	else:
		var start := Time.get_ticks_msec()
		var last := start
		while opening.state == "cart_passage":
			var now := Time.get_ticks_msec()
			var delta := minf(float(now-last)/1000.0,.1)
			last = now
			opening._process(delta)
			if passage.active:
				check(cart.global_position.z >= previous.z,"Native cart advances through fades")
				previous = cart.global_position
				if passage.age >= 13:
					if not fixed_camera.is_finite(): fixed_camera = opening.camera.global_position
					check(opening.camera.global_position.is_equal_approx(fixed_camera),"Native fixed wheel camera")
				var beat := floori(passage.age)
				if beat in [3,9,12,17,22] and not photographed.has(beat):
					photographed[beat] = true
					if beat == 17 and gathering != null:
						var present := 0
						for member in gathering.members:
							if member.actor.global_position.distance_to(gathering.fire.global_position) < 4.0: present += 1
						check(present >= 2,"Cart passes an actual night gathering")
					await capture("cart_%02d" % beat)
			await process_frame
			if now-start > 90000: check(false,"Cart passage timeout"); break
	check(absf(cart.wheels[0].rotation.x-wheel_rotation)>1 or not passage.active,"Wheels rotate during journey")
	if passage.active: opening._process(.2)
	check(opening.state == "night","Cart fades into room")
	check(cart.global_transform.is_equal_approx(saved_transform),"Borrowed cart restores gameplay placement")
	check(not passage.active and passage.gathering_sound == null,"Transient passage/audio cleaned")
	check(not cart.has_meta("opening_cart_passage") and not passage.passenger_service.caption.visible,"Arrival dialogue cancels after the cut")
	opening._process(.7)
	check(opening.elapsed < 1.0,"Diya timeline starts fresh after cart passage")
	await capture("cart_room_handoff")
	# Skip from a second passage must restore the cart and proceed to dawn.
	opening.state = "cart_passage"
	passage.begin(opening)
	opening.morning()
	check(opening.state == "dawn" and not passage.active,"Skip from cart goes safely to dawn")
	check(cart.global_transform.is_equal_approx(saved_transform),"Skip restores borrowed cart")
	print("OPENING CART PASSAGE: ","PASS" if failures == 0 else "FAIL"," | live cart, uninterrupted travel, aerial/fixed wheels, fades, room handoff, skip/restore; art separate")
	saves.options = options
	passage = null
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	world.queue_free()
	for i in 3: await process_frame
	await preload("res://tools/test_audio_cleanup.gd").finish(self,1 if failures else 0)
