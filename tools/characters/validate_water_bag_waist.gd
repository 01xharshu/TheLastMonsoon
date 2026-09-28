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
	var cord: MeshInstance3D = bag.get_node("BagCord")
	var rig: Skeleton3D = actor.get_node("VisualRoot/CharacterVisual").skeleton
	var waist := rig.global_transform * rig.get_bone_global_pose(rig.find_bone("pelvis"))
	if not bag.visible or not cord.visible or bag.global_position.distance_to(waist.origin) > 0.5:
		push_error("WATER BAG WAIST: pouch or cord not secured near pelvis")
		quit(1)
		return
	actor.velocity = Vector3(4, 0, 0)
	for i in 8: visual._process(0.1)
	if absf(visual.bag_sway_z) < 0.03 or absf(visual.bag_sway_z) > 0.25:
		push_error("WATER BAG WAIST: loose sway absent or excessive")
		quit(1)
		return
	print("WATER BAG WAIST: PASS | pelvis attachment, cord, bounded movement sway")
	quit()
