extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Forward+/Metal renderer required")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var actor: CharacterBody3D = world.get_node("Player")
	var store: Node3D = world.get_node("Settlement/CompanyArmoury")
	var pickup: Interactable = store.find_child("StoreWeapon_bow", true, false)
	var gear: Node = actor.get_node("VisualRoot/CharacterVisual").equipment
	assert(pickup != null and not actor.inventory.has_item("bow"))
	for i in 8: await physics_frame
	actor.global_position = pickup.to_global(Vector3(.35, 0, 1.8))
	actor.global_position.y = store.global_position.y + .3
	var toward: Vector3 = pickup.global_position - actor.global_position
	actor.get_node("VisualRoot").global_rotation.y = atan2(toward.x, toward.z)
	for i in 6: await physics_frame
	actor.camera_pivot.look_at(pickup.global_position)
	actor.camera_pitch = actor.camera_pivot.rotation.x
	for i in 3: await physics_frame
	assert(actor._find_interactable() == pickup, "Bow cannot be focused from aisle")
	await _capture("/tmp/tlm_upper_shelf_bow_prompt.png")
	Input.action_press("interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	actor._unhandled_input(key)
	assert(actor.hold_target == pickup, "E did not start bow hold")
	for i in 90:
		if actor.hold_elapsed >= 0.35: break
		await physics_frame
	assert(actor.hold_target == pickup and actor.hold_elapsed >= 0.35, "Bow hold lost its target")
	await _capture("/tmp/tlm_upper_shelf_bow_hold.png")
	for i in 120:
		if actor.inventory.has_item("bow"): break
		await physics_frame
	Input.action_release("interact")
	assert(actor.inventory.has_item("bow") and gear.selected == 2 and not gear.stowed, "Bow was not equipped")
	await _capture("/tmp/tlm_upper_shelf_bow_equipped.png")
	print("UPPER SHELF LIVE E EQUIP: PASS")
	quit()

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK, path)
