extends SceneTree
## Real player rig on a small floor; no full-world settlement dependency.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var floor_collision := CollisionShape3D.new()
	var ground := BoxShape3D.new()
	ground.size = Vector3(20,.4,20)
	floor_collision.shape = ground
	floor_collision.position.y = -.2
	floor.add_child(floor_collision)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position = Vector3(0,1,0)
	for i in 20: await physics_frame
	var stance: Node = actor.get_node("StealthStance")
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	if visual.skeleton == null or visual.motion_tree == null:
		_fail("playable rig or AnimationTree missing")
		return
	stance.enter_crouch()
	for i in 30: await process_frame
	if stance.stance != "crouch" or actor.get_node("CollisionShape3D").position.y > -.2:
		_fail("crouch collider did not lower")
		return
	var crouch_foot := _lowest_foot(visual)
	stance.enter_prone()
	Input.action_press("move_forward")
	for i in 40: await physics_frame
	var crawl_speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	if stance.stance != "prone" or crawl_speed < .4 or crawl_speed > 1.4:
		_fail("prone crawl did not move at low speed")
		return
	Input.action_press("sprint")
	for i in 45: await physics_frame
	if stance.is_low() or Vector2(actor.velocity.x,actor.velocity.z).length() < 4.0:
		_fail("crawl-to-run transition did not recover")
		return
	Input.action_release("move_forward")
	Input.action_release("sprint")
	actor.inventory.add_item("enfield",1)
	visual.equipment.select_weapon(1)
	var crate := StaticBody3D.new()
	stage.add_child(crate)
	crate.position = actor.position-Vector3.FORWARD*1.2
	var crate_collision := CollisionShape3D.new()
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(1.5,1.1,.9)
	crate_collision.shape = crate_shape
	crate_collision.position.y = .55
	crate.add_child(crate_collision)
	actor.get_node("CameraPivot").global_rotation = Vector3.ZERO
	for i in 4: await physics_frame
	if not stance.try_cover():
		_fail("solid crate cover was not acquired")
		return
	Input.action_press("aim")
	for i in 25: await process_frame
	if not actor.get_node("RifleCombat").aiming or not actor.get_node("CombatInput").available():
		_fail("armed aim or attack is unavailable in cover")
		return
	var shots_before: int = actor.get_node("RifleCombat").shots_fired
	actor.get_node("RifleCombat").fire()
	if actor.get_node("RifleCombat").shots_fired != shots_before+1:
		_fail("Enfield did not fire from cover")
		return
	Input.action_release("aim")
	print("GROUND STANCE ISOLATED: PASS | crouch foot y=%.3f, prone crawl %.2f m/s, crawl-run, armed cover fire" % [crouch_foot,crawl_speed])
	quit()

func _lowest_foot(visual: Node3D) -> float:
	var lowest := INF
	for side in ["l","r"]:
		var bone: int = visual.skeleton.find_bone("foot_"+side)
		if bone >= 0:
			lowest = minf(lowest,visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(bone).origin).y)
	return lowest

func _fail(reason: String) -> void:
	push_error("GROUND STANCE ISOLATED: "+reason)
	quit(1)
