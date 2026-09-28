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
	for label in ["VillagePassengerEkka", "VillageGoodsCart", "GovernmentHouseFamilyCarriage"]:
		var cart: Node3D = carts.get_node(label)
		var seat: String = "CoachmanSeat" if label == "GovernmentHouseFamilyCarriage" else "DriverSeat"
		player.global_position = cart.seat_sockets[seat].global_position + cart.global_basis.x * 1.7
		assert(cart.board_at(player, seat, "driver"))
		var distance := 9.0 if label == "GovernmentHouseFamilyCarriage" else 7.0
		camera.global_position = cart.to_global(Vector3(distance * .68, 4.0, -distance))
		camera.look_at(cart.to_global(Vector3(0, 1.4, 1.1)))
		for i in 8: await get_tree().process_frame
		var path := "res://docs/world/captures/live_%s.png" % label.to_snake_case()
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("CART CAPTURE: ", path)
		assert(cart.boarding.dismount())
	get_tree().quit()
