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
	if stance.low_waist.size() != 6:
		_fail("stance garment assets are missing or stale; rebuild the retained body fit")
		return
	stance.enter_crouch()
	for i in 30: await process_frame
	if stance.stance != "crouch" or actor.get_node("CollisionShape3D").position.y > -.2:
		_fail("crouch collider did not lower")
		return
	var crouch_foot := _lowest_foot(visual)
	if not stance.stand():
		_fail("free crouch could not stand")
		return
	for i in 3: await physics_frame
	if stance.prone_blend > .001:
		_fail("crouch recovery accidentally entered prone blend")
		return
	stance.enter_prone()
	Input.action_press("move_forward")
	for i in 40: await physics_frame
	var crawl_speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	if stance.stance != "prone" or crawl_speed < .4 or crawl_speed > 1.4:
		_fail("prone crawl did not move at low speed")
		return
	var pouch: Node3D = actor.get_node("VisualRoot/EquipmentVisuals/WaterBagVisual")
	var hip: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("pelvis")).origin)
	if pouch.belt_pin_world().distance_to(hip) > .35:
		_fail("prone pouch detached from the waist")
		return
	var crawl_foot := _lowest_foot(visual)
	if crawl_foot < .07 or crawl_foot > .13:
		_fail("prone feet lost their support height")
		return
	for side in ["l","r"]:
		var wrist: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side)).origin)
		if wrist.y < .01 or wrist.y > .15:
			_fail("unarmed crawl wrist did not stay near the supporting floor")
			return
	Input.action_press("sprint")
	for i in 45: await physics_frame
	if stance.is_low() or Vector2(actor.velocity.x,actor.velocity.z).length() < 4.0:
		_fail("crawl-to-run transition did not recover")
		return
	for record in stance.low_waist:
		if record.node.mesh != record.normal:
			_fail("standing recovery retained a low-stance garment")
			return
	Input.action_release("move_forward")
	Input.action_release("sprint")
	actor.inventory.add_item("enfield",1)
	visual.equipment.select_weapon(1)
	var crate := StaticBody3D.new()
	stage.add_child(crate)
	crate.position = Vector3(actor.position.x,0,actor.position.z-1.2)
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
	for i in 30: await physics_frame
	if not actor.get_node("RifleCombat").aiming or not actor.get_node("CombatInput").available():
		_fail("armed aim or attack is unavailable in cover")
		return
	var shots_before: int = actor.get_node("RifleCombat").shots_fired
	actor.get_node("RifleCombat").fire()
	if actor.get_node("RifleCombat").shots_fired != shots_before+1:
		_fail("Enfield did not fire from cover")
		return
	Input.action_release("aim")
	var grip: Dictionary = visual.equipment.grip_errors()
	if float(grip.right_palm_m) > .025 or float(grip.left_palm_m) > .025:
		_fail("stance pulled palms off the rifle")
		return
	var original_cover_point: Vector3 = stance.cover_point
	crate.position.x += .5
	for i in 3: await physics_frame
	if stance.stance != "cover" or stance.cover_point.distance_to(original_cover_point+Vector3.RIGHT*.5) > .001:
		_fail("cover contact did not follow the moving cart collider")
		return
	crate.position.x += 4.0
	for i in 3: await physics_frame
	if stance.stance != "crouch" or stance.cover_body != null:
		_fail("departing cart cover exposed Arjun instead of leaving him crouched")
		return
	crate.position.x -= 4.5
	for i in 3: await physics_frame
	if not stance.try_cover():
		_fail("returned cart cover could not be reacquired")
		return
	crate.queue_free()
	for i in 3: await physics_frame
	if stance.stance != "crouch" or stance.cover_body != null:
		_fail("removed cover left a stale cover state")
		return
	var total_usec := 0
	var peak_usec := 0
	for i in 60:
		var started := Time.get_ticks_usec()
		stance._process(1.0/60.0)
		var elapsed := Time.get_ticks_usec()-started
		total_usec += elapsed
		peak_usec = maxi(peak_usec,elapsed)
	print("GROUND STANCE ISOLATED: PASS | crouch foot y=%.3f, prone crawl %.2f m/s, crawl-run, armed cover fire, moving/removed cover recovery" % [crouch_foot,crawl_speed])
	print("STANCE SOLVE COST | armed layer mean %.3f ms, peak %.3f ms; palm errors %.4f / %.4f m" % [float(total_usec)/60000.0,float(peak_usec)/1000.0,grip.right_palm_m,grip.left_palm_m])
	stage.queue_free()
	for i in 4: await physics_frame
	quit.call_deferred()

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
