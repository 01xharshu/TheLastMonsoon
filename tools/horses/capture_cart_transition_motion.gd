extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	add_child(world)
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(time)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, .2, 30)
	shape.shape = box
	floor.add_child(shape)
	var mesh := MeshInstance3D.new()
	var ground := BoxMesh.new()
	ground.size = box.size
	mesh.mesh = ground
	floor.add_child(mesh)
	world.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-.9, .4, 0)
	sun.light_energy = 1.8
	world.add_child(sun)
	var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	world.add_child(cart)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(actor)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 48
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
	actor.visual_root.show()
	cart.visual_root.get_node("Roof").hide()
	cart.visual_root.get_node("InteriorCeilingLiner").hide()
	await get_tree().create_timer(.3).timeout
	for side in [-1.0, 1.0]:
		actor.global_position = Vector3(side * 2.2, 1.06, 2.79)
		actor.velocity = Vector3.ZERO
		camera.position = Vector3(side * 4.8, 3.1, 4.5)
		camera.look_at(Vector3(side * .6, 1.6, 2.8))
		await get_tree().create_timer(.3).timeout
		assert(cart.board_at(actor, "RearPassengerLeft" if side < 0 else "RearPassengerRight", "passenger"))
		await _transition(cart, actor, "entry")
		await get_tree().create_timer(.5).timeout
		assert(cart.boarding.dismount())
		await _transition(cart, actor, "exit")
		assert(cart.rider == null and actor.collision_layer != 0)
		await get_tree().create_timer(.5).timeout
	print("CART CONTINUOUS ENTRY/EXIT: PASS | both sides")
	get_tree().quit()

func _transition(cart: Node3D, actor: CharacterBody3D, label: String) -> void:
	var saved := false
	var checked_floor := false
	while cart.boarding.transition != "":
		await RenderingServer.frame_post_draw
		var u: float = cart.boarding.transition_progress if label == "entry" else 1.0 - cart.boarding.transition_progress
		if not checked_floor and u > .74 and u < .80:
			var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
			for side in ["l", "r"]:
				var index: int = visual.skeleton.find_bone("foot_" + side)
				var rest: Transform3D = visual.skeleton.get_bone_global_rest(index)
				var offset: Vector3 = rest.basis.inverse() * Vector3(0, -.085, .06)
				var sole: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(index) * offset)
				var gap := sole.distance_to(cart.boarding.cabin_transfer_foot_world(side, u))
				assert(gap < .035, "Cabin transfer foot missed floor")
				print("CART TRANSFER SOLE ", side, " ", label, " gap=", gap)
			checked_floor = true
		if not saved and u > .48 and u < .52:
			var path := "res://docs/world/captures/cart_grip_%s_%s.png" % ["left" if cart.boarding.transition_side < 0 else "right", label]
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
			var side := "l" if cart.boarding.transition_side < 0 else "r"
			var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_" + side))
			var palm: Vector3 = visual.skeleton.to_global(hand * visual.equipment.palm_offsets[side])
			var gap := palm.distance_to(cart.boarding.transition_hand_world())
			assert(gap < .06, "Boarding palm outside grip reach")
			print("CART GRIP ", side, " ", label, " palm-to-rail=", gap)
			saved = true
