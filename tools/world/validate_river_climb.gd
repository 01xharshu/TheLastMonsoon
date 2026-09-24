extends SceneTree
## Gameplay contact and renderer captures; requires native Forward+/Metal for pixel evidence.
var failures := 0
func _initialize() -> void: call_deferred("validate")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func capture(name: String) -> void:
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/world/captures/"+name+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)
func validate() -> void:
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	for i in 5: await physics_frame
	var actor: CharacterBody3D=world.get_node("Player")
	var boat: CharacterBody3D=world.get_node("RiverBoat")
	var fish: Node=world.get_node("RiverFish")
	check(fish.fish.size()==36,"36 fish below water")
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	camera.fov=55.0
	world.add_child(camera)
	camera.make_current()
	camera.global_position=boat.global_position+Vector3(-7,5,6)
	camera.look_at(boat.global_position+Vector3(2,-.5,0))
	if DisplayServer.get_name()!="headless": await capture("14_river_boat_water")
	if DisplayServer.get_name()!="headless":
		var fish_position: Vector3=fish.school.multimesh.get_instance_transform(0).origin
		camera.global_position=fish_position+Vector3(0,.22,1.55)
		camera.look_at(fish_position)
		await capture("14b_fish_underwater")
		camera.global_position=boat.global_position+Vector3(-7,5,6)
		camera.look_at(boat.global_position+Vector3(2,-.5,0))

	actor.global_position=boat.global_position+Vector3(-2,1.2,0)
	for i in 2: await physics_frame
	check(boat.can_board(actor),"boat within reach from landing")
	check(boat.board(actor),"F boarding contract")
	for i in 10: await physics_frame
	check(actor.has_meta("mounted_vehicle"),"mounted state remains active")
	check(actor.global_position.distance_to(boat.seat_world())<1.5,"pelvis remains on bench")
	var before_row: Vector3=boat.global_position
	Input.action_press("move_forward")
	var blade_high: float=-INF
	var blade_low: float=INF
	for i in 45:
		await physics_frame
		blade_high=maxf(blade_high,boat.paddle_blade_world().y)
		blade_low=minf(blade_low,boat.paddle_blade_world().y)
	check(boat.paddle_blend>.95 and boat.row_effort>.95,"paddle enters active rowing pose")
	for side in ["l","r"]:
		var hand_index: int=actor.get_node("VisualRoot/CharacterVisual").skeleton.find_bone("hand_"+side)
		var rig: Skeleton3D=actor.get_node("VisualRoot/CharacterVisual").skeleton
		var wrist: Vector3=rig.to_global(rig.get_bone_global_pose(hand_index).origin)
		var palm: Vector3=rig.to_global(rig.get_bone_global_pose(hand_index)*actor.get_node("VisualRoot/CharacterVisual").equipment.palm_offsets[side])
		print("ROW HAND ",side," palm error=",palm.distance_to(boat.paddle_grip_world(side)))
		check(palm.distance_to(boat.paddle_grip_world(side))<.04,"rowing "+side+" palm holds paddle grip")
	if DisplayServer.get_name()!="headless":
		camera.global_position=boat.global_position+boat.global_basis.x*3.2+Vector3.UP*1.4+boat.global_basis.z*1.3
		camera.look_at(boat.seat_world()+Vector3.UP*.55)
		await capture("15c_arjun_rowing")
		camera.global_position=boat.global_position+Vector3.UP*3.7+boat.global_basis.z*1.5
		camera.look_at(boat.seat_world())
		await capture("15d_arjun_rowing_overhead")
	for i in 45:
		await physics_frame
		blade_high=maxf(blade_high,boat.paddle_blade_world().y)
		blade_low=minf(blade_low,boat.paddle_blade_world().y)
	Input.action_release("move_forward")
	check(blade_high-blade_low>.12,"paddle blade rises and dips through rowing cycle")
	check(boat.global_position.distance_to(before_row)>1.0,"W rows boat through deep water")
	check(actor.global_position.distance_to(boat.seat_world())<1.5,"rider follows moving bench")

	if DisplayServer.get_name()!="headless": await capture("15_arjun_boat_seated")
	if DisplayServer.get_name()!="headless":
		camera.global_position=boat.global_position+boat.global_basis.x*3.2+Vector3.UP*1.4+boat.global_basis.z*1.3
		camera.look_at(boat.seat_world()+Vector3.UP*.55)
		await capture("15b_arjun_boat_seat_close")
	check(boat.dismount(),"F dismount contract")
	check(not actor.has_meta("mounted_vehicle"),"mounted state clears")
	actor.global_position=Vector3(291.3,12.95,300)
	actor.visual_root.global_rotation.y=PI/2
	for i in 3: await physics_frame
	camera.global_position=Vector3(287,15.5,304.0)
	camera.look_at(Vector3(293,15.0,300))
	var climb: Node=actor.get_node("ClimbComponent")
	check(climb.try_start(),"wall climb begins on authored masonry")
	if climb.active:
		for i in 38: await physics_frame
		if DisplayServer.get_name()!="headless": await capture("16a_climb_reach")
		for i in 16: await physics_frame
		var visual: Node=actor.get_node("VisualRoot/CharacterVisual")
		for side in ["l","r"]:
			var index: int=visual.skeleton.find_bone("hand_"+side)
			var wrist: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(index).origin)
			var target: Vector3=visual.climb_targets[side].global_position
			var elbow: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("lowerarm_"+side)).origin)
			var foot_index: int=visual.skeleton.find_bone("foot_"+side)
			var foot: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(foot_index).origin)
			print("CLIMB FOOT ",side," ",foot)
			print("ARM SEGMENTS ",side," ",visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("upperarm_"+side)).origin).distance_to(elbow)," ",elbow.distance_to(wrist))
			print("CLIMB HAND ",side," error_m=",snappedf(wrist.distance_to(target),.001)," wrist=",wrist," target=",target," shoulder=",visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("upperarm_"+side)).origin)," actor=",actor.global_position," ik=",visual.climb_ik[side].is_running()," influence=",visual.climb_ik[side].influence," iktarget=",visual.climb_ik[side].get_target_transform().origin," path=",visual.climb_ik[side].target_node," resolved=",visual.climb_ik[side].get_node_or_null(visual.climb_ik[side].target_node))
		if DisplayServer.get_name()!="headless": await capture("16_arjun_climbing")
		for i in 42: await physics_frame
		if DisplayServer.get_name()!="headless": await capture("16b_climb_pull")
		for i in 15: await physics_frame
		if DisplayServer.get_name()!="headless": await capture("16c_climb_mantle")
		for i in 63: await physics_frame
		check(not climb.active,"wall climb completes")
		check(actor.global_position.y>16,"Arjun lands on wall walk")
	print("RIVER BOAT CLIMB ","PASS" if failures==0 else "FAIL "+str(failures))
	quit(1 if failures else 0)
