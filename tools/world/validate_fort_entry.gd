extends SceneTree

var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(condition:bool,label:String) -> void:
	print("PASS " if condition else "FAIL ",label)
	failed = failed or not condition

func run() -> void:
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	while world.get_node_or_null("FieldGrazing")==null:
		await process_frame
	while not world.get_node("FieldGrazing").ready_for_grazing:
		await process_frame
	var fort:Node3D=world.get_node("OldFort")
	var player:CharacterBody3D=world.get_node("Player")
	var gate:Node3D=fort.get_node("Architecture/OuterFortGate")
	check(gate.has_node("DeepStoneGateVault"),"outer wall has a physical deep stone entry")
	var outside:=ground_point(world,fort,Vector2(11.5,94.0))
	var yard:=ground_point(world,fort,Vector2(0,8.0))
	var ray:=PhysicsRayQueryParameters3D.create(outside+Vector3.UP*1.65,yard+Vector3.UP*1.4,1,[player.get_rid()])
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and fort.is_ancestor_of(hit.collider),"masonry blocks the approach sightline into the courtyard")
	player.global_position=outside+Vector3.UP*1.05
	player.velocity=Vector3.ZERO
	for frame in 12:
		await physics_frame
	for waypoint:Vector2 in [Vector2(11.5,81),Vector2(0,80),Vector2(0,73),Vector2(-9,73),Vector2(-9,67),Vector2(-9,73),Vector2(-23,73),Vector2(-37,73)]:
		var goal:=ground_point(world,fort,waypoint)
		var reached:=await walk_to(player,goal)
		check(reached,"Arjun walks the gate and inner turn to "+str(waypoint))
	var forecourt:=ground_point(world,fort,Vector2(0,66))
	var inner_ray:=PhysicsRayQueryParameters3D.create(forecourt+Vector3.UP*1.65,yard+Vector3.UP*1.4,1,[player.get_rid()])
	var inner_hit:=world.get_world_3d().direct_space_state.intersect_ray(inner_ray)
	check(not inner_hit.is_empty() and fort.is_ancestor_of(inner_hit.collider),"inner ward masonry screens the yard after the outer gate")
	player.global_position=forecourt+Vector3.UP*.96
	player.velocity=Vector3.ZERO
	for frame in 8:await physics_frame
	for waypoint:Vector2 in [Vector2(0,62.5),Vector2(-11.5,62.5),Vector2(-11.5,50),Vector2(0,50),Vector2(0,42),Vector2(-8.6,42),Vector2(-8.6,33)]:
		check(await walk_to(player,ground_point(world,fort,waypoint)),"Arjun follows offset inner ward to "+str(waypoint))
	if not OS.get_environment("TLM_TUTORIAL_OUTPUT").is_empty():
		player.hide()
		player.get_node("UI").hide()
		var camera:=Camera3D.new()
		world.add_child(camera)
		camera.far=420
		camera.make_current()
		var views:Dictionary={
			"approach":[Vector2(14,105),Vector2(11.5,86),2.1,3.8],
			"threshold":[Vector2(11.5,89),Vector2(11.5,75),1.65,2.4],
			"inside":[Vector2(0,67),Vector2(0,53),1.72,2.2],
			"gallery":[Vector2(-2,73),Vector2(-32,73),1.65,1.7],
			"chamber":[Vector2(-8,73),Vector2(-8,65.5),1.65,1.6],
		}
		for label:String in views:
			var view:Array=views[label]
			camera.position=ground_point(world,fort,view[0])+Vector3.UP*float(view[2])
			camera.look_at(ground_point(world,fort,view[1])+Vector3.UP*float(view[3]))
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT").path_join("fort_entry_"+label+".png"))
		print("HIDEOUT ENVIRONMENT ENTRY REVIEW READY")
		var deadline:=Time.get_ticks_msec()+55000
		while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT").path_join("fort_entry_done")):
			await process_frame
	await preload("res://tools/test_audio_cleanup.gd").finish(self,1 if failed else 0)

func ground_point(world:Node3D,fort:Node3D,local:Vector2) -> Vector3:
	var point:=fort.to_global(Vector3(local.x,0,local.y))
	point.y=world.layout.height(point.x,point.z)
	return point

func walk_to(player:CharacterBody3D,goal:Vector3) -> bool:
	Input.action_press("move_forward")
	var reached:=false
	for frame in 420:
		var offset:=goal-player.global_position
		offset.y=0
		if offset.length()<.55:
			reached=true
			break
		Input.action_press("move_forward")
		player.camera_pivot.global_rotation.y=atan2(-offset.x,-offset.z)
		await physics_frame
	Input.action_release("move_forward")
	if not reached:
		print("HIDEOUT ENVIRONMENT ENTRY WALK at=",player.global_position," goal=",goal," physics=",player.is_physics_processing()," floor=",player.is_on_floor()," slide hits=",player.get_slide_collision_count())
		for i in player.get_slide_collision_count():
			print("HIDEOUT ENVIRONMENT ENTRY COLLIDER ",player.get_slide_collision(i).get_collider().get_path())
	return reached
