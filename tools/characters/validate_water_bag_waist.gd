extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	host.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	host.add_child(actor)
	for i in 3: await process_frame
	var visual: Node3D = actor.get_node("VisualRoot/EquipmentVisuals")
	var bag: Node3D = visual.get_node("WaterBagVisual")
	var cord: MeshInstance3D = bag.cord
	var rig: Skeleton3D = actor.get_node("VisualRoot/CharacterVisual").skeleton
	var waist := rig.global_transform * rig.get_bone_global_pose(rig.find_bone("pelvis"))
	if not bag.visible or not cord.visible or bag.global_position.distance_to(waist.origin) > 0.35:
		push_error("WATER BAG WAIST: pouch or cord not secured near pelvis")
		quit(1)
		return
	actor.set_physics_process(false)
	bag.set_process(false)
	actor.inventory.consume_water(2.0)
	bag._process(1.0)
	var empty_depth := _section_depth(bag)
	actor.inventory.add_water(2.0)
	bag._process(1.0)
	var full_depth := _section_depth(bag)
	if bag.fullness != 1.0 or full_depth.y - full_depth.x < (empty_depth.y - empty_depth.x) * 2.5 or absf(full_depth.x - empty_depth.x) > 0.005:
		push_error("WATER BAG WAIST: full bag must expand outward while its inward face stays on the coat")
		quit(1)
		return
	actor.inventory.consume_water(1.0)
	bag._process(1.0)
	if not is_equal_approx(bag.fullness, 0.5):
		push_error("WATER BAG WAIST: visible fill level did not follow consumption")
		quit(1)
		return
	actor.get_node("VisualRoot").rotation.y = 1.2
	var pelvis := rig.find_bone("pelvis")
	rig.set_bone_pose_rotation(pelvis, rig.get_bone_pose_rotation(pelvis) * Quaternion(Vector3.FORWARD, 0.15))
	actor.velocity = Vector3(4, 0, 0)
	for i in 8: visual._process(0.1)
	var expected: Transform3D = rig.global_transform * rig.get_bone_global_pose(pelvis) * visual.bag_offset
	if bag.global_position.distance_to(expected.origin) > 0.00001 or bag.belt_pin_world().distance_to(bag.global_position) > 0.00001 or absf(visual.bag_sway_x) > 0.031 or absf(visual.bag_sway_z) > 0.021:
		push_error("WATER BAG WAIST: turning/sway detached the carry loop from the animated sash")
		quit(1)
		return
	actor.inventory.consume_water(2.0)
	bag._process(1.0)
	actor.inventory.remove_item("water_bag", 1)
	if bag.fullness != 0.0 or bag.visible:
		push_error("WATER BAG WAIST: empty or removed inventory state not reflected")
		quit(1)
		return
	print("WATER BAG WAIST: PASS | pinned sash/turn, coat contact, empty/half/full inventory response, bounded sway, removal")
	quit()

func _section_depth(bag: Node3D) -> Vector2:
	var vertices: PackedVector3Array = bag.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var result := Vector2(INF, -INF)
	for vertex in vertices:
		if absf(vertex.y - 0.12) > 0.001: continue
		result.x = minf(result.x, vertex.z)
		result.y = maxf(result.y, vertex.z)
	return result
