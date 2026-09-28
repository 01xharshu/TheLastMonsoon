extends SceneTree
var failures: Array[String] = []
var samples: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("validate")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://docs/world/captures/mango_reach_" + name + ".png")
func validate() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(clock)
	clock.set_process(false)
	var player = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.global_position = Vector3(0,0.9,0)
	player.set_physics_process(false)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
	player.set_process_unhandled_input(false)
	var visual = player.get_node("VisualRoot/CharacterVisual")
	var component = player.get_node("InteractionPoseComponent")
	var carried = player.get_node("VisualRoot/EquipmentVisuals")
	carried.set_process(false)
	visual.set_process(false)
	component.set_process(false)
	player.get_node("UI").hide()
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6,6)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20,0.25,0.17)
	plane.material_override = material
	world.add_child(plane)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45,-35,0)
	light.light_energy = 2.0
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-1.7,1.25,1.8)
	camera.look_at(Vector3(0,0.65,0.15))
	camera.make_current()
	player.get_node("CameraPivot/SpringArm3D/Camera3D").global_transform = camera.global_transform
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in 10:
		visual._process(1.0/60.0)
		carried._process(1.0/60.0)
		await process_frame
	player.inventory.add_item("talwar",1)
	visual.equipment.select_weapon(0)
	for offset in [Vector3(-0.15,0.135,0.45), Vector3(0.15,0.135,0.65), Vector3(0,0.135,0.8)]:
		var fruit = load("res://objects/mango.gd").new()
		world.add_child(fruit)
		fruit.position = offset
		player.get_node("CameraPivot/SpringArm3D/Camera3D").global_transform = camera.global_transform
		player._update_interaction()
		if offset.z > 0.7:
			check(player.current_interactable != fruit, "Unreachable fruit should require closer approach")
			if is_instance_valid(fruit): fruit.queue_free()
			await process_frame
			continue
		check(player.current_interactable == fruit, "Reachable fruit did not prompt")
		player._begin_interaction_hold(fruit,"interact")
		Input.action_press("interact")
		var initial_palm: Vector3
		var max_step := 0.0
		for frame in 30:
			visual._process(1.0/60.0)
			component._process(1.0/60.0)
			carried._process(1.0/60.0)
			var palm: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_r"))*visual.equipment.palm_offsets["r"])
			if frame > 0: max_step = maxf(max_step,palm.distance_to(initial_palm))
			initial_palm = palm
			if offset.z < 0.5 and frame in [0,5,11,29]: await capture(str(frame))
		check(visual.equipment.stowed,"Pickup did not free the weapon hand")
		var error: float = initial_palm.distance_to(fruit.global_position+Vector3.UP*0.025)
		var foot_error := 0.0
		for side in ["l","r"]:
			var actual: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side)).origin)
			foot_error = maxf(foot_error, actual.distance_to(component.foot_anchors[side]))
		print("REACH ", offset, " palm error=",error," foot drift=",foot_error," step=",max_step)
		check(error < 0.06,"Palm did not reach fruit")
		check(foot_error < 0.015,"Pickup moved feet off their anchors")
		check(max_step < 0.14,"Pickup transition jumped")
		samples.append({"fruit":str(offset),"palm_error_m":error,"foot_drift_m":foot_error,"largest_frame_palm_step_m":max_step})
		Input.action_release("interact")
		player._hide_interaction_labels()
		if offset.z > 0.5:
			player.survival.satiety = 40.0
			fruit.secondary_interact(player)
			check(not fruit.collected,"World eating bypassed the Satchel")
		fruit.interact(player)
		check(component.carried_mango.visible,"Completed ground pickup did not show hand fruit")
		for frame in 110:
			visual._process(1.0/60.0)
			component._process(1.0/60.0)
			carried._process(1.0/60.0)
			if offset.z > 0.5 and frame in [15,44,59]: await capture("ground_eat_" + str(frame))
		check(not visual.equipment.stowed,"Pickup did not restore the drawn weapon")
		check(not component.ground_pickup and component.amount <= 0.001,"Pickup pose did not release")
		check(is_equal_approx(visual.model.position.y,-0.9-visual.motion_tree.foot_contact_offset),"Pickup left model crouched")
		if is_instance_valid(fruit): fruit.queue_free()
		await process_frame
	await capture("released")
	var interrupted_fruit = load("res://objects/mango.gd").new()
	world.add_child(interrupted_fruit)
	interrupted_fruit.position = Vector3(0,0.135,0.45)
	player._begin_interaction_hold(interrupted_fruit,"interact")
	visual._process(1.0/60.0)
	component._process(1.0/60.0)
	player.set_meta("rest_action","sit")
	component._process(1.0/60.0)
	check(not component.ground_pickup and component.amount == 0.0,"Rest left a stale pickup pose")
	check(not visual.equipment.stowed,"Interrupted pickup left weapon stowed")
	player.remove_meta("rest_action")
	player._hide_interaction_labels()
	interrupted_fruit.queue_free()
	await process_frame
	for mode in ["eat","store"]:
		player.survival.satiety = 40.0
		if mode == "eat":
			check(player.consumables.eat_fresh_mango(),"Fresh eating failed")
		else:
			var stored = load("res://objects/mango.gd").new()
			world.add_child(stored)
			stored.interact(player)
		check(component.carried_mango.visible,"Successful action has no held fruit")
		var largest_step := 0.0
		var previous_palm: Vector3 = component.carried_start
		var bite_head_rotation := Quaternion.IDENTITY
		for frame in 110:
			visual._process(1.0/60.0)
			component._process(1.0/60.0)
			carried._process(1.0/60.0)
			var palm: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_r"))*visual.equipment.palm_offsets["r"])
			if component.ground_pickup: largest_step = maxf(largest_step,previous_palm.distance_to(palm))
			previous_palm = palm
			if frame in [15,44,59]: await capture(mode + "_" + str(frame))
			if frame == 54 and mode == "eat": bite_head_rotation = visual.skeleton.get_bone_pose_rotation(visual.skeleton.find_bone("head"))
			if frame == 59 and mode == "eat":
				check(bite_head_rotation.angle_to(visual.skeleton.get_bone_pose_rotation(visual.skeleton.find_bone("head"))) > 0.006,"Eating head did not react to bite")
				check(component.carried_mango.mesh == component.bitten_mango_mesh,"Eating showed no bite")
				var head: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("head")).origin)
				check(palm.distance_to(head+visual.global_basis*Vector3(0,-0.085,0.15)) < 0.06,"Eating hand missed mouth target")
		check(not component.ground_pickup and not component.carried_mango.visible,"Action left fruit/pose active")
		check(not visual.equipment.stowed,"Action did not restore weapon")
		check(largest_step < 0.15,"Carried action snapped hand")
		samples.append({"mode":mode,"largest_frame_palm_step_m":largest_step})
	player.set_first_person(true)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
	player.first_person_view.set_process(false)
	player.survival.satiety = 40.0
	player.consumables.eat_fresh_mango()
	for frame in 60:
		visual._process(1.0/60.0)
		component._process(1.0/60.0)
		player.first_person_view._process(1.0/60.0)
		if frame in [15,44,59]: await capture("first_person_eat_" + str(frame))
	check(player.first_person_view.carried_mango.visible,"First-person fruit missing")
	check(player.first_person_view.carried_mango.mesh == component.bitten_mango_mesh,"First-person bite did not sync")
	check(not component.carried_root.visible,"First-person rendered duplicate world fruit")
	player.set_meta("rest_action","sit")
	component._process(1.0/60.0)
	player.first_person_view._process(1.0/60.0)
	check(not player.first_person_view.carried_mango.visible,"Interrupted first-person fruit remained")
	player.remove_meta("rest_action")
	player.set_first_person(false)
	camera.make_current()
	var slope := StaticBody3D.new()
	var slope_shape := CollisionShape3D.new()
	var slope_box := BoxShape3D.new()
	slope_box.size = Vector3(3,0.1,3)
	slope_shape.shape = slope_box
	slope.add_child(slope_shape)
	var slope_visual := MeshInstance3D.new()
	var slope_mesh := BoxMesh.new()
	slope_mesh.size = slope_box.size
	slope_visual.mesh = slope_mesh
	slope_visual.material_override = material
	slope.add_child(slope_visual)
	world.add_child(slope)
	plane.hide()
	slope.position.y = -0.05
	slope.rotation.z = 0.18
	await physics_frame
	var slope_fruit = load("res://objects/mango.gd").new()
	world.add_child(slope_fruit)
	slope_fruit.position = Vector3(0.15,0.16,0.45)
	player._begin_interaction_hold(slope_fruit,"interact")
	for frame in 30:
		visual._process(1.0/60.0)
		component._process(1.0/60.0)
		carried._process(1.0/60.0)
	var max_ground_error := 0.0
	for side in ["l","r"]:
		var ankle: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side)).origin)
		var query := PhysicsRayQueryParameters3D.create(ankle+Vector3.UP*0.35,ankle+Vector3.DOWN*0.45)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),"Slope foot has no ground")
		if not hit.is_empty(): max_ground_error = maxf(max_ground_error,absf((ankle.y-hit.position.y)-0.07))
	check(max_ground_error < 0.015,"Slope boot ankle did not follow ground")
	samples.append({"mode":"slope","boot_sole_error_m":max_ground_error})
	await capture("slope")
	player._hide_interaction_labels()
	for frame in 30:
		visual._process(1.0/60.0)
		component._process(1.0/60.0)
	slope_fruit.queue_free()
	slope.queue_free()
	plane.show()
	player.survival.satiety = 100.0
	player.survival.hydration = 100.0
	check(not player.consumables.eat_fresh_mango(),"Full player ate fruit")
	check(not component.carried_mango.visible,"Rejected eating showed fruit")
	FileAccess.open("res://docs/world/mango_reach_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"samples":samples,"rendered":DisplayServer.get_name() != "headless"},"\t"))
	print("MANGO REACH: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
