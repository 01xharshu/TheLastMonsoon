extends SceneTree
var failures: Array[String] = []
var actor: CharacterBody3D
var visual: Node3D
var detention: Node
var world: Node3D
var camera: Camera3D
var capture := false
var max_drift := 0.0
var wrist_gap := 0.0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func shot(label: String, offset: Vector3) -> void:
	if not capture: return
	camera.global_position = actor.global_position+world.get_node("Settlement/DistrictPolice").global_basis*offset
	camera.look_at(actor.global_position+Vector3.UP*0.15)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://docs/characters/arjun/detention_%s.png"%label)==OK,"Capture failed: "+label)
func run() -> void:
	capture = DisplayServer.get_name()!="headless"
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	actor = world.get_node("Player")
	visual = actor.get_node("VisualRoot/CharacterVisual")
	detention = actor.get_node("DetentionComponent")
	var police: Node3D = world.get_node("Settlement/DistrictPolice")
	actor.global_position = police.to_global(Vector3(0,-3.1,-6.7))
	actor.global_basis = police.global_basis
	actor.set_first_person(false)
	if capture:
		root.size = Vector2i(854,480) if "--motion-video" in OS.get_cmdline_user_args() else Vector2i(1280,720)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		actor.get_node("UI").hide()
		world.get_node("LandscapeUI").hide()
		camera = Camera3D.new()
		world.add_child(camera)
		camera.fov = 50
		camera.make_current()
		camera.global_position = actor.global_position+police.global_basis*Vector3(1.65,0.45,-1.25)
		camera.look_at(actor.global_position+Vector3.UP*0.15)
	await frames(12)
	var anchor := actor.global_position
	actor.inventory.items["paper_cartridges"] = 2
	actor.inventory.items["pistol_ball"] = 7
	actor.get_node("RifleCombat").pending_rounds = 1
	actor.get_node("RifleCombat").reload_remaining = 5.0
	actor.get_node("PistolCombat").rounds = 2
	actor.get_node("PistolCombat").reload_remaining = 1.0
	actor.get_node("CombatInput").punch_time = 0.0
	actor.get_node("CombatInput").pending_single = true
	check(detention.begin_detention("arrest"),"Arrest entry rejected")
	await frames(35)
	await shot("entry",Vector3(1.65,0.6,-1.25))
	await frames(65)
	for i in 90:
		await physics_frame
		max_drift = maxf(max_drift, actor.global_position.distance_to(anchor))
	check(actor.get_node("RifleCombat").reload_remaining == 0.0 and actor.get_node("RifleCombat").pending_rounds == 0,"Rifle reload not cancelled")
	check(actor.inventory.get_item_count("paper_cartridges") == 3,"Reserved rifle charge lost or duplicated")
	check(actor.get_node("PistolCombat").reload_remaining == 0.0 and actor.get_node("PistolCombat").rounds == 2,"Pistol reload continued during arrest")
	check(actor.inventory.get_item_count("pistol_ball") == 7,"Pistol reserve changed on arrest")
	check(not actor.get_node("CombatInput").available(),"Melee allowed in detention")
	check(actor.get_node("CombatInput").punch_time < 0 and not actor.get_node("CombatInput").pending_single,"Pending melee was not cancelled")
	check(not actor.get_node("StealthStance").can_change(),"Low stance allowed in detention")
	check(not actor.get_node("RideComponent").try_toggle(),"Mount allowed in detention")
	actor.inventory_ui.open_inventory()
	check(not actor.inventory_ui.is_open(),"Inventory opened during detention")
	for name in ["RifleCombat","DoubleGunCombat","PistolCombat","BowCombat","TalwarSlash"]:
		check(not actor.get_node(name).available(),name+" allowed in detention")
	visual.skeleton.force_update_all_bone_transforms()
	var left: Vector3 = visual.skeleton.get_bone_global_pose(visual.bones["hand_l"]).origin
	var right: Vector3 = visual.skeleton.get_bone_global_pose(visual.bones["hand_r"]).origin
	wrist_gap = left.distance_to(right)
	check(wrist_gap < 0.18,"Restrained wrists too far apart")
	var hip: Vector3 = visual.skeleton.get_bone_global_pose(visual.bones["pelvis"]).origin
	check(left.z < hip.z-0.20 and right.z < hip.z-0.20,"Wrists are not behind the body")
	await shot("arrest_back",Vector3(1.65,0.45,-1.25))
	await shot("arrest_front",Vector3(-1.65,0.45,1.25))
	check(detention.wait_in_cell(),"Waiting transition rejected")
	await frames(120)
	await shot("waiting",Vector3(-1.65,0.45,1.25))
	check(absf(float(visual.motion_tree.get("parameters/detention_pose/blend_amount")))<0.001,"Arrest pose retained in waiting")
	check(actor.get_meta("detention_action","")=="waiting","Waiting state missing")
	Input.action_press("move_forward")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("move_forward")
	Input.action_release("jump")
	check(actor.global_position.distance_to(anchor)<0.005,"Detained actor moved/jumped")
	detention.release_detention()
	await frames(30)
	await shot("release",Vector3(1.65,0.45,-1.25))
	await frames(40)
	check(actor.get_meta("detention_action","")=="","Release did not clear lock")
	check(float(visual.motion_tree.get("parameters/detention/blend_amount"))<0.001,"Pose remained after release")
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	check(actor.global_position.distance_to(anchor)>0.15,"Walking did not recover")
	check(not detention.begin_detention("invalid"),"Unknown state accepted")
	await frames(20)
	check(detention.begin_detention("arrest"),"Repeated arrest failed")
	await frames(85)
	detention.release_detention()
	await frames(65)
	check(actor.get_meta("detention_action", "")=="","Arrest release left lock")
	var report := {"passed":failures.is_empty(),"failures":failures,"max_detained_drift_m":max_drift,"restrained_wrist_gap_m":wrist_gap,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual station cell, timed arrest/wait/release, action guards and recovered locomotion; visual approval separate"}
	FileAccess.open("res://docs/characters/arjun/detention_validation%s.json"%("_metal" if capture else ""),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("ARJUN DETENTION ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
