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
		player.global_position = cart.seat_sockets[seat].global_position + cart.global_basis.x * 1.7
		assert(cart.board_at(player, seat, role))
		var distance := 9.0 if label == "GovernmentHouseFamilyCarriage" else 7.0
		camera.global_position = cart.to_global(Vector3(distance * .68, 4.0, -distance))
		camera.look_at(cart.to_global(Vector3(0, 1.4, 1.1)))
		if role == "passenger" and cart.has_method("show_coachman_blockout"):
			cart.visual_root.get_node("Roof").visible = false
			cart.visual_root.get_node("InteriorCeilingLiner").visible = false
			camera.global_position = cart.to_global(Vector3(.1, 5.2, 2.9))
			camera.look_at(cart.to_global(Vector3(0, 1.7, 2.8)))
		await get_tree().create_timer(.75).timeout
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
		if cart.has_method("show_coachman_blockout"):
			cart.visual_root.get_node("Roof").visible = true
			cart.visual_root.get_node("InteriorCeilingLiner").visible = true
	get_tree().quit()
