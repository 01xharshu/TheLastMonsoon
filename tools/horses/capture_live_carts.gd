extends Node

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 54.0
	camera.current = true
	var carts: Node3D = world.get_node("LiveCarts")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for spec in [
		["VillagePassengerEkka", "DriverSeat", "driver"],
		["VillageGoodsCart", "DriverSeat", "driver"],
		["GovernmentHouseFamilyCarriage", "CoachmanSeat", "driver"],
		["VillagePassengerEkka", "PassengerSeat", "passenger"],
		["GovernmentHouseFamilyCarriage", "RearPassengerRight", "passenger"],
		["GovernmentHouseFamilyCarriage", "RearPassengerLeft", "passenger"]
	]:
		var label: String = spec[0]
		var cart: Node3D = carts.get_node(label)
		var seat: String = spec[1]
		var role: String = spec[2]
		var boarding_side := -1.0 if seat.ends_with("Left") else 1.0
		var beside: Vector3 = cart.seat_sockets[seat].global_position + cart.global_basis.x * boarding_side * 1.9
		var ground := PhysicsRayQueryParameters3D.create(beside + Vector3.UP * 2.0, beside - Vector3.UP * 5.0)
		ground.exclude = cart.boarding._cart_handle_exclusions() + [cart.boarding.collision_body.get_rid(), player.get_rid()]
		var hit := cart.get_world_3d().direct_space_state.intersect_ray(ground)
		assert(not hit.is_empty(), "No boarding ground")
		player.global_position = hit.position + Vector3.UP * .96
		player.velocity = Vector3.ZERO
		assert(cart.board_at(player, seat, role))
		var distance := 9.0 if label == "GovernmentHouseFamilyCarriage" else 7.0
		camera.global_position = cart.to_global(Vector3(distance * .68, 4.0, -distance))
		camera.look_at(cart.to_global(Vector3(0, 1.4, 1.1)))
		if role == "passenger" and cart.has_method("show_coachman_blockout"):
			cart.visual_root.get_node("Roof").visible = false
			cart.visual_root.get_node("InteriorCeilingLiner").visible = false
			camera.global_position = cart.to_global(Vector3(boarding_side * 4.5, 3.5, 3.0))
			camera.look_at(cart.to_global(Vector3(0, 1.7, 2.8)))
		for sample in 2:
			await get_tree().create_timer(.35).timeout
			await RenderingServer.frame_post_draw
			var frame_path := "res://docs/world/captures/cart_entry_%s_%s_%d.png" % [label.to_snake_case(), seat.to_snake_case(), sample]
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(frame_path))
		if role == "passenger" and cart.has_method("show_coachman_blockout"):
			camera.global_position = cart.to_global(Vector3(.1, 5.2, 2.9))
			camera.look_at(cart.to_global(Vector3(0, 1.7, 2.8)))
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var visual: Node3D = player.get_node("VisualRoot/CharacterVisual")
		for side in ["l", "r"]:
			var index: int = visual.skeleton.find_bone("foot_" + side)
			var rest: Transform3D = visual.skeleton.get_bone_global_rest(index)
			var offset: Vector3 = rest.basis.inverse() * Vector3(0, -.085, .06)
			var sole: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(index) * offset)
			var gap: float = sole.distance_to(cart.boarding.foot_support_world(side))
			print("CART SOLE: ", label, " ", seat, " ", side, " gap=", gap)
			assert(gap < .03, "Cart foot contact failed")
		var suffix: String = "_" + seat.to_snake_case() if role == "passenger" else ""
		var path := "res://docs/world/captures/live_%s%s.png" % [label.to_snake_case(), suffix]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("CART CAPTURE: ", path)
		assert(cart.boarding.dismount())
		camera.global_position = cart.to_global(Vector3(-4.5, 3.5, 1.8 if role == "driver" else 3.0))
		camera.look_at(cart.to_global(Vector3(0, 1.5, 1.8 if role == "driver" else 2.8)))
		await get_tree().create_timer(.55).timeout
		await RenderingServer.frame_post_draw
		var exit_path := "res://docs/world/captures/cart_exit_%s_%s.png" % [label.to_snake_case(), seat.to_snake_case()]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(exit_path))
		await get_tree().create_timer(.75).timeout
		assert(cart.rider == null and player.collision_layer != 0, "Exit did not restore player")
		if cart.has_method("show_coachman_blockout"):
			cart.visual_root.get_node("Roof").visible = true
			cart.visual_root.get_node("InteriorCeilingLiner").visible = true
	get_tree().quit()
