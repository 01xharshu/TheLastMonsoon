extends SceneTree
## Distinct single-shot sidearm and existing Adams share controls, not state.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	stage.add_child(clock)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var ground := BoxShape3D.new()
	ground.size = Vector3(30,.4,30)
	var collision := CollisionShape3D.new()
	collision.shape = ground
	collision.position.y = -.2
	floor.add_child(collision)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position = Vector3(0,1,0)
	for frame in 30: await physics_frame
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var gear: Node3D = visual.equipment
	var adams: Node = actor.get_node("PistolCombat")
	var indian: Node = actor.get_node("IndianPistolCombat")
	actor.inventory.add_item("pistol",1)
	actor.inventory.add_item("indian_pistol",1)
	actor.inventory.add_item("pistol_ball",3)
	gear.select_weapon(6)
	for frame in 10: await process_frame
	check(gear.owns(6) and gear.selected == 6 and gear.indian_pistol_hand.visible and not gear.pistol_hand.visible,"New pistol did not equip independently")
	var wheel: Control = actor.get_node("UI/WeaponWheel")
	check(wheel.owns_slot(9) and wheel.owns_slot(3),"Both pistol choices must be available in the wheel")
	Input.action_press("aim")
	for frame in 40: await physics_frame
	check(indian.aiming and visual.motion_tree.get("parameters/pistol_aim/blend_amount") > .95,"Indian pistol aim pose did not enter the AnimationTree")
	var skeleton: Skeleton3D = visual.skeleton
	var palm: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*gear.palm_offsets["r"])
	var grip_error: float = palm.distance_to(gear.indian_pistol_hand.to_global(gear.INDIAN_PISTOL_GRIP))
	check(grip_error < .025,"Indian pistol grip missed the palm: " + str(grip_error))
	var barrel_alignment: float = gear.indian_pistol_hand.global_basis.x.normalized().dot(gear.aim_direction.normalized())
	check(barrel_alignment > .98,"Indian pistol barrel does not follow aim: " + str(barrel_alignment))
	check(indian.fire() and indian.rounds == 0,"Single-shot pistol did not fire its one charge")
	check(not indian.fire() and adams.rounds == 5,"Empty single-shot pistol fired or changed Adams rounds")
	check(indian.start_reload() and is_equal_approx(indian.reload_duration,4.0),"Single-shot reload did not start")
	var loading_gap := 0.0
	var reload_grip_gap := 0.0
	var muzzle_head_gap := INF
	var worst_loading := {}
	var visible_frames := 0
	for frame in 245:
		await physics_frame
		var right_palm: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*gear.palm_offsets["r"])
		reload_grip_gap = maxf(reload_grip_gap,right_palm.distance_to(gear.indian_pistol_hand.to_global(gear.INDIAN_PISTOL_GRIP)))
		var head: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin)
		muzzle_head_gap = minf(muzzle_head_gap,head.distance_to(gear.indian_pistol_hand.to_global(indian.MUZZLE)))
		if gear.pistol_charge.visible:
			visible_frames += 1
			var pinch: Vector3 = (skeleton.get_bone_global_pose(skeleton.find_bone("index_03_l")).origin+skeleton.get_bone_global_pose(skeleton.find_bone("thumb_03_l")).origin)*.5
			var gap: float = skeleton.to_global(pinch).distance_to(gear.pistol_charge.global_position)
			if gap > loading_gap:
				loading_gap = gap
				var wrist: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin
				var shoulder: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_l")).origin
				var elbow: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("lowerarm_l")).origin
				var goal: Vector3 = skeleton.to_local(gear.pistol_charge.global_position)-(pinch-wrist)
				worst_loading = {"frame":frame,"goal":goal,"shoulder":shoulder,"distance":shoulder.distance_to(goal),"arm_length":shoulder.distance_to(elbow)+elbow.distance_to(wrist),"remaining":indian.reload_remaining}
	if loading_gap >= .025: print("INDIAN LOAD REACH ",worst_loading)
	check(visible_frames > 0 and loading_gap < .025,"Loading hand missed the charge: " + str(loading_gap))
	check(reload_grip_gap < .025,"Firing hand lost pistol during reload: " + str(reload_grip_gap))
	check(muzzle_head_gap > .16,"Pistol muzzle is too close to the head: " + str(muzzle_head_gap))
	check(indian.rounds == 1 and actor.inventory.get_item_count("pistol_ball") == 2,"Single-shot reload did not consume exactly one ball")
	gear.select_weapon(3)
	for frame in 10: await process_frame
	check(gear.pistol_hand.visible and not gear.indian_pistol_hand.visible and adams.rounds == 5,"Returning to Adams lost independent state")
	wheel.open()
	wheel.selected = 9
	wheel.close(true)
	check(gear.selected == 6,"Wheel did not select the Indian pistol")
	gear.stowed = true
	gear._refresh()
	check(gear.indian_pistol_hip.visible and not gear.indian_pistol_hand.visible,"Indian pistol did not stow")
	Input.action_release("aim")
	print("INDIAN PISTOL ",JSON.stringify({"passed":failures.is_empty(),"grip_error_m":grip_error,"barrel_alignment":barrel_alignment,"loading_gap_m":loading_gap,"reload_grip_m":reload_grip_gap,"muzzle_head_m":muzzle_head_gap,"loading_visible_frames":visible_frames,"failures":failures}))
	await root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
