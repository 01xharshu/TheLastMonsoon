extends Node
var failures: Array[String] = []
var contacts: Array[Dictionary] = []
var actor: CharacterBody3D
var horse: CharacterBody3D
var world: Node3D
func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Hold a phase for skin/pose inspection; traversal resumes afterward.
	var running := horse.is_physics_processing()
	horse.set_physics_process(false)
	for i in 5: await get_tree().process_frame
	RenderingServer.force_draw(false)
	check(get_tree().root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png") == OK, label+" capture")
	if actor.has_meta("mounted_vehicle"): hand_contacts(label)
	horse.set_physics_process(running)
func hand_contacts(label: String) -> void:
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	visual.skeleton.force_update_all_bone_transforms()
	for side in ["l", "r"]:
		var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side))
		var palm: Vector3 = visual.skeleton.to_global(hand * visual.equipment.palm_offsets[side])
		var gap := palm.distance_to(horse.saddle_grip_world(side))
		print(label, " palm ",side," error=",gap)
		var foot: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side))
		var rest: Transform3D = visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone("foot_"+side))
		var sole: Vector3 = visual.skeleton.to_global(foot * (rest.basis.inverse() * Vector3(0,-0.085,0.06)))
		var foot_gap := sole.distance_to(horse.stirrup_world(side))
		print(label," sole ",side," gap=",foot_gap," hip=",visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("thigh_"+side)).origin)," ankle=",visual.skeleton.to_global(foot.origin)," target=",horse.stirrup_world(side))
		if label == "horse_seated_contact": check(foot_gap < 0.03,side+" seated boot stays on stirrup tread")
		contacts.append({"phase":label,"side":side,"palm_gap_m":gap,"sole_gap_m":foot_gap})
func run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await frames(20)
	actor = world.get_node("Player")
	horse = world.get_node("VillageHorse")
	actor.set_process_unhandled_input(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var compound: Node3D = world.find_child("ColonialCompound",true,false)
	horse.global_position = compound.to_global(Vector3(-48.2,4.9,5.1))
	horse.rotation.y = 0.0
	actor.global_position = compound.to_global(Vector3(-49.7,5.75,5.1))
	actor.velocity = Vector3.ZERO
	await frames(20)
	var mask := actor.collision_mask
	var layer := actor.collision_layer
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = compound.to_global(Vector3(-52,7.6,7.2))
	camera.look_at(horse.global_position+Vector3.UP*1.3)
	camera.make_current()
	check(horse.board(actor),"mount begins on raised landing")
	await frames(7)
	await capture("horse_mount_early")
	await frames(7)
	await capture("horse_mount_lift")
	await frames(7)
	check(horse.transition == "mount" and actor.get_meta("horse_transition_progress",0.0) > 0.2,"mount has an intermediate pose")
	await capture("horse_mount_landing")
	await frames(8)
	await capture("horse_mount_cross")
	await frames(8)
	await capture("horse_mount_settle")
	await frames(24)
	check(horse.transition == "" and horse.rider == actor,"mount completes")
	await capture("horse_seated_contact")
	check(actor.interaction_overlay.ride_prompt == "Dismount horse","exit card remains visible after mount")
	check(horse.dismount(),"dismount finds raised landing surface")
	check(absf(horse.transition_to.y-compound.to_global(Vector3(0,5.74,0)).y) < 0.12,"dismount target stays on landing height")
	await frames(21)
	check(horse.transition == "dismount","dismount has an intermediate pose")
	await capture("horse_dismount_landing")
	await frames(50)
	check(horse.rider == null and actor.is_on_floor(),"dismount settles on landing")
	check(actor.collision_mask == mask and actor.collision_layer == layer,"dismount restores collision")
	check(not actor.has_meta("mounted_vehicle"),"dismount releases mounted state")
	await capture("horse_dismount_complete")
	actor.global_position = horse.global_position + horse.global_basis.x * 1.45 + Vector3.UP * 0.94
	actor.velocity = Vector3.ZERO
	await frames(10)
	check(horse.board(actor),"remount from opposite side")
	await frames(21)
	check(actor.get_meta("horse_transition_side",0.0) > 0.0,"right-side approach selects opposite leg swing")
	await capture("horse_mount_right")
	await frames(40)
	# At this height both sides are open air; no remote terrain exit is allowed.
	horse.global_position = compound.to_global(Vector3(-40,4.9,5.1))
	horse.set_physics_process(false)
	check(not horse.dismount(),"dismount refuses unsupported exits")
	var report := FileAccess.open("res://docs/world/horse_transition_validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"sampled_contacts":contacts,"visual_status":"REVIEW_FAILED"},"\t")+"\n")
	print("HORSE TRANSITIONS ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
