extends SceneTree
## No retained output: isolated control, transition, contact and pacing checks.
const STEP := 1.0/60.0
var failed := false
var actor: CharacterBody3D
var visual: Node3D
var pistol: Node
var largest_step := 0.0
var previous_hand := Vector3.ZERO
var timed_frames := 0
var visual_microseconds := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func tick() -> void:
	pistol._process(STEP)
	var start := Time.get_ticks_usec()
	visual._process(STEP)
	visual_microseconds += Time.get_ticks_usec()-start
	timed_frames += 1
	var rig: Skeleton3D = visual.skeleton
	var hand := rig.get_bone_global_pose(rig.find_bone("hand_r"))
	if not visual.equipment.stowed:
		if previous_hand != Vector3.ZERO: largest_step = maxf(largest_step,hand.origin.distance_to(previous_hand))
		previous_hand = hand.origin
	else: previous_hand = Vector3.ZERO
	var gun: Transform3D = hand*visual.equipment.pistol_hand.transform
	var error: float = (hand*visual.equipment.palm_offsets["r"]).distance_to(gun*visual.equipment.PISTOL_GRIP)
	check(error < 0.005,"Pistol palm lost its grip during a transition")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	actor = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.set_process(false)
	visual = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	pistol = actor.get_node("PistolCombat")
	pistol.set_process(false)
	actor.inventory.add_item("pistol",1)
	actor.inventory.add_item("pistol_ball",5)
	visual.equipment.select_weapon(3)
	actor.set_meta("mounted_vehicle",null)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in 3: await process_frame
	check(pistol.available(),"Cleared mount tag blocked the pistol")
	for frame in 30: tick()
	Input.action_press("aim")
	for frame in 45: tick()
	check(visual.motion_tree.get("parameters/pistol_aim/blend_amount") > 0.98,"Aim pose did not enter the AnimationTree")
	var rig: Skeleton3D = visual.skeleton
	var gun: Transform3D = rig.get_bone_global_pose(rig.find_bone("hand_r"))*visual.equipment.pistol_hand.transform
	var thumb: Vector3 = gun.affine_inverse()*rig.get_bone_global_pose(rig.find_bone("thumb_03_r")).origin
	var index: Vector3 = gun.affine_inverse()*rig.get_bone_global_pose(rig.find_bone("index_03_r")).origin
	check(thumb.y < 0.035,"Thumb still points above the pistol frame")
	check(index.y < 0.035 and index.x > -0.11 and index.x < -0.04,"Trigger finger left the guard envelope")
	check(pistol.fire(),"Aimed pistol did not fire")
	check(pistol.rounds == 4 and pistol.recoil > 0.07,"Shot did not consume a round and start recoil")
	for frame in 30: tick()
	check(pistol.recoil == 0.0,"Recoil did not recover")
	var target := StaticBody3D.new()
	target.name = "ExistingMPFBAimTarget"
	target.add_to_group("human_npcs")
	stage.add_child(target)
	target.add_child(load("res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb").instantiate())
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	collider.shape = capsule
	collider.position.y = 1.0
	target.add_child(collider)
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	target.global_position = camera.global_position-camera.global_basis.z*8.0-Vector3.UP
	for frame in 2: await physics_frame
	var hud: Control = actor.get_node("UI/HUDRoot")
	for frame in 20: hud._update_gun_sight(STEP)
	check(hud.human_target and hud.sight_pulse > 0.98,"Existing MPFB target did not tighten the sight")
	check(hud.gun_sight_radius(true) > hud.gun_sight_radius(false),"Pistol and long-gun sights lost their different sizes")
	var settled_radius: float = hud.gun_sight_radius(true)
	visual.equipment.recoil = 0.075
	hud._update_gun_sight(0.05)
	check(hud.gun_sight_radius(true) > settled_radius+2.0,"Shot did not expand the dash spacing")
	visual.equipment.recoil = 0.0
	hud._update_gun_sight(0.1)
	check(is_equal_approx(hud.gun_sight_radius(true),settled_radius),"Shot dash spacing did not contract again")
	target.queue_free()
	for frame in 2: await physics_frame
	hud._update_gun_sight(0.3)
	check(not hud.human_target and hud.sight_pulse == 0.0,"Sight remained locked after target release")
	var manager: Node = root.get_node("SaveManager")
	var old_options: Dictionary = manager.options.duplicate(true)
	manager.options.camera_angle = 6.0
	manager.options.aim_camera_angle = -4.0
	manager.apply_options(stage)
	actor.aim_blend = 1.0
	actor._update_weapon_camera(STEP)
	check(absf(camera.rotation.x-deg_to_rad(-4.0)) < 0.001,"Aim angle setting did not reach the game camera")
	pistol.aiming = false
	actor.aim_blend = 0.0
	actor._update_weapon_camera(STEP)
	check(absf(camera.rotation.x-deg_to_rad(6.0)) < 0.001,"Normal angle setting did not reach the game camera")
	manager.options = old_options
	manager.apply_options(stage)
	pistol.aiming = true
	pistol.rounds = 0
	check(pistol.start_reload(),"Empty pistol did not start reload")
	check(pistol.reload_duration == 16.0,"Five charges did not receive per-charge pacing")
	var visible_frames := 0
	var loading_gap := 0.0
	var worst_loading: Dictionary = {}
	for frame in 961:
		tick()
		if visual.equipment.pistol_charge.visible:
			visible_frames += 1
			var pinch := (rig.get_bone_global_pose(rig.find_bone("index_03_l")).origin+rig.get_bone_global_pose(rig.find_bone("thumb_03_l")).origin)*0.5
			var gap := rig.to_global(pinch).distance_to(visual.equipment.pistol_charge.global_position)
			if gap > loading_gap:
				loading_gap = gap
				var wrist := rig.get_bone_global_pose(rig.find_bone("hand_l")).origin
				var shoulder := rig.get_bone_global_pose(rig.find_bone("upperarm_l")).origin
				var elbow := rig.get_bone_global_pose(rig.find_bone("lowerarm_l")).origin
				var goal := rig.to_local(visual.equipment.pistol_charge.global_position)-(pinch-wrist)
				worst_loading = {"frame":frame,"contact":rig.to_local(visual.equipment.pistol_charge.global_position),"goal_distance":shoulder.distance_to(goal),"arm_length":shoulder.distance_to(elbow)+elbow.distance_to(wrist),"wrist":wrist,"goal":goal}
		if frame == 239: check(pistol.rounds == 0,"Five chambers loaded at the former four-second deadline")
	check(pistol.rounds == 5 and actor.inventory.get_item_count("pistol_ball") == 0,"Reload ammunition accounting failed")
	check(pistol.reload_clicks == 5 and visible_frames > 100,"Per-charge visual/audio sequence did not run")
	check(loading_gap < 0.015,"Loading fingers lost the visible charge")
	if loading_gap >= 0.015: print("LOADING REACH ",worst_loading)
	for frame in 45: tick()
	check(visual.motion_tree.get("parameters/pistol_reload/blend_amount") < 0.001,"Reload pose did not release")
	check(not visual.equipment.pistol_charge.visible,"Charge remained visible after completion")
	pistol.rounds = 4
	actor.inventory.add_item("pistol_ball",1)
	check(pistol.start_reload() and pistol.reload_duration == 4.0,"One charge did not receive its shorter reload")
	for frame in 60: tick()
	visual.equipment.toggle_stowed()
	for frame in 300: tick()
	check(pistol.reload_remaining == 0.0 and pistol.rounds == 4 and actor.inventory.get_item_count("pistol_ball") == 1,"Cancelled reload loaded or consumed a charge")
	check(not visual.equipment.pistol_charge.visible,"Stowing left the loading charge visible")
	check(largest_step < 0.075,"Right hand snapped during aim/reload transitions")
	Input.action_release("aim")
	print("PISTOL MOTION: ","FAIL" if failed else "PASS"," | largest wrist step=",largest_step," m; loading midpoint gap=",loading_gap," m; visual average=",float(visual_microseconds)/maxi(1,timed_frames)," us; five-charge reload=16 s")
	stage.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
