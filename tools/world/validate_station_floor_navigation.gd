extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok and not failures.has(label):
		failures.append(label)
		push_error(label)
func quiet(node: Node,actor: Node,player: Node) -> void:
	if node==actor or node==player:return
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():quiet(child,actor,player)
func run() -> void:
	var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	var deadline:=Time.get_ticks_msec()+90000
	while (world.get_node_or_null("DevStory")==null or not world.get_node("DevStory").configured) and Time.get_ticks_msec()<deadline:
		await process_frame
	var station: Node3D=world.get_node("Settlement/DistrictPolice")
	var actor: Node3D=station.get_node("ThanaStaff/Burkundaz")
	var player: CharacterBody3D=world.get_node("Player")
	var opening: Node=world.get_node_or_null("OpeningSequence")
	if opening!=null:opening.skip_cinematic()
	player.set_meta("opening_active",false)
	player.set_meta("story_cinematic",false)
	player.get_node("UI/HUDRoot/MorningTutorial").restore_step(11)
	quiet(world,actor,player)
	player.set_physics_process(false)
	if OS.get_environment("TLM_STATION_WINDOW_ONLY")=="1":
		await verify_window(world,station,player)
		print("STATION WINDOW ","PASS" if failures.is_empty() else "FAIL",failures)
		await finish_review()
		return
	var crime: Node3D=world.get_node("CombatEncounters")
	actor.global_position=station.to_global(Vector3(station.stair_x,0,11))
	actor.body_collider.force_update_transform()
	var nav:=preload("res://combat/police_search_navigation.gd").new()
	actor.add_child(nav)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.global_position=station.to_global(Vector3(-7,6,13))
	camera.look_at(station.to_global(Vector3(station.stair_x,2.7,0)))
	camera.make_current()
	var destinations: Array[Vector3]=[Vector3(-3,station.floor_y,4),Vector3(-1,0,14),Vector3(6,-4,-9.5),Vector3(-1,0,14)]
	if OS.get_environment("TLM_STATION_CROSS_FLOOR")=="1":
		destinations=[Vector3(-3,station.floor_y,4),Vector3(6,-4,-9.5),Vector3(-3,station.floor_y,4),Vector3(-1,0,14)]
	for destination in destinations:
		player.global_position=station.to_global(Vector3(1,.9,16))
		var goal:=station.to_global(destination+Vector3.UP*.9)
		var arrived:=false
		var used_stairs:=false
		var captured:=false
		for frame in 1800:
			var previous:=actor.global_position
			arrived=nav.move(crime,actor,goal,2.8,.075)
			var local:=station.to_local(actor.global_position)
			check(absf(actor.global_position.y-previous.y)<.31,"officer floor height changes continuously")
			if local.y<-.5 and local.y>-3.5:
				used_stairs=true
				check(absf(local.x-12.0)<1.5,"officer enters cellar through actual staircase")
			if local.y>.5 and local.y<station.floor_y-.5:
				used_stairs=true
				check(absf(local.x-station.stair_x)<1.5,"officer changes floors inside actual staircase")
				var output:=OS.get_environment("TLM_GLOW_REVIEW")
				if not captured and local.y>2.0 and local.y<3.7 and DisplayServer.get_name()!="headless" and not output.is_empty():
					captured=true
					camera.global_position=station.to_global(Vector3(-16.2,4.8,5.0))
					camera.look_at(actor.global_position+Vector3.UP*1.1)
					camera.make_current()
					await process_frame
					RenderingServer.force_draw(false)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("station_stair_"+("up" if destination.y>0 else "down")+".png"))
			if arrived:break
			await physics_frame
		var ending:=station.to_local(actor.global_position)
		print("STATION FLOOR endpoint=",ending," goal=",destination," path=",nav.path.size()," index=",nav.path_index," next=",station.to_local(nav.path[nav.path_index]) if nav.path_index<nav.path.size() else destination," pending=",nav.pending)
		check(arrived and Vector2(ending.x,ending.z).distance_to(Vector2(destination.x,destination.z))<.25 and absf(ending.y-destination.y)<.2,"officer physically reaches floor "+str(destination.y))
		check(used_stairs,"officer uses stair flight for floor "+str(destination.y))
		if destination.y>0:
			check(not crime.move_actor(actor,actor.global_position-Vector3.UP*station.floor_y,2.8,.075),"same horizontal position on another floor is not arrival")
	await verify_security(world,station,player,crime)
	print("STATION FLOOR ", "PASS" if failures.is_empty() else "FAIL",failures)
	await finish_review()

func finish_review() -> void:
	var output:=OS.get_environment("TLM_GLOW_REVIEW")
	if DisplayServer.get_name()!="headless" and not output.is_empty():
		var review_deadline:=Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<review_deadline and not FileAccess.file_exists(output.path_join("station_floor_done")):await process_frame
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)

func verify_security(world: Node3D,station: Node3D,player: CharacterBody3D,crime: Node3D) -> void:
	var security: Node=station.get_node("ThanaStaff/StationSecurity")
	var sentry: Node3D=station.get_node("ThanaStaff/UpperSentry")
	check(sentry._skeleton!=null and sentry.get_meta("station_bound",false),"upper sentry retains full imported rig and station identity")
	if DisplayServer.get_name()!="headless" and not OS.get_environment("TLM_GLOW_REVIEW").is_empty():
		var camera:=Camera3D.new()
		world.add_child(camera)
		camera.global_position=station.to_global(Vector3(-.5,station.floor_y+1.6,-4.2))
		camera.look_at(sentry.global_position+Vector3.UP*1.1)
		camera.make_current()
		await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_GLOW_REVIEW").path_join("station_upper_sentry.png"))
	var public_at:=station.to_global(Vector3(0,.9,12))
	var private_at:=station.to_global(Vector3(-3,station.floor_y+.9,-4.8))
	player.global_position=public_at
	security._process(.3)
	var before: int=crime.crime_score
	check(security.restricted_zone(public_at).is_empty(),"reception remains public")
	var wall:=StaticBody3D.new()
	station.add_child(wall)
	wall.position=Vector3(-3,station.floor_y+1.5,-6.3)
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(4,3,.2)
	collision.shape=box
	wall.add_child(collision)
	player.global_position=private_at
	for frame in 3:await physics_frame
	security._process(.3)
	check(crime.crime_score==before,"unseen restricted entry creates no evidence")
	wall.queue_free()
	for frame in 3:await physics_frame
	security._process(.3)
	check(crime.crime_score>before and crime.evidence[-1].get("station_zone","")=="upper_offices","real upper sentry reports seen unauthorized entry")
	var reported: int=crime.crime_score
	security._process(1.0)
	security.reported_zone=""
	security._process(.3)
	check(crime.crime_score==reported,"same entry and restored active evidence do not multiply reports")
	player.global_position=public_at
	security._process(.3)
	crime.complete_custody(player)
	var rebellion: Node=world.get_node("RebellionStory")
	rebellion.disguise=true
	player.global_position=private_at
	for frame in 3:await physics_frame
	security._process(.3)
	check(crime.crime_score>0,"disguise flag without worn uniform does not grant access")
	player.global_position=public_at
	security._process(.3)
	crime.complete_custody(player)
	var visual: Node3D=player.get_node("VisualRoot/CharacterVisual")
	var donor: Node3D=world.get_node("DevInquiry").guards[1]
	check(rebellion.outfit.wear(visual,donor),"existing uniform owner equips real disguise")
	player.global_position=private_at
	for frame in 3:await physics_frame
	security._process(.3)
	check(security.uniform_authorized() and crime.crime_score==0,"worn uniform permits guarded station access")
	rebellion.outfit.remove()
	rebellion.disguise=false
	player.global_position=public_at
	security._process(.3)


func verify_window(world: Node3D,station: Node3D,player: CharacterBody3D) -> void:
	var portal: Node3D=station.get_node("StationEscapeWindow")
	check(portal.is_in_group("climbable_windows"),"station escape uses registered window traversal")
	var climb: Node=player.get_node("ClimbComponent")
	var original_shape: Shape3D=player.get_node("CollisionShape3D").shape
	var original_mask:=player.collision_mask
	player.global_position=station.to_global(Vector3(15.1,.94,portal.position.z))
	player.velocity=Vector3.ZERO
	var outward:=station.global_basis.x
	player.camera_pivot.global_rotation.y=atan2(-outward.x,-outward.z)
	player.visual_root.global_rotation.y=atan2(outward.x,outward.z)
	player.set_meta("document_busy",false)
	player.set_physics_process(true)
	for frame in 20:await physics_frame
	check(player.is_on_floor(),"Arjun stands on real station floor before desk approach")
	Input.action_press("move_forward")
	var on_desk:=false
	for frame in 150:
		await physics_frame
		var local:=station.to_local(player.global_position)
		if player.is_on_floor() and local.y>1.50 and local.x>17.65:
			on_desk=true
			break
	Input.action_release("move_forward")
	check(on_desk,"normal movement steps from footstool onto solid desk")
	if not on_desk:
		print("STATION WINDOW desk position=",station.to_local(player.global_position))
		return
	for frame in 7:await physics_frame
	check(climb.window.try_start(player,true),"desk approach has an open sill and clear supported landing")
	await process_frame
	send_jump(true)
	var entered:=false
	var peak:=0.0
	var capture_progress: Array[float]=[.40,.57,.73]
	var captured:=0
	var camera: Camera3D
	for frame in 340:
		await physics_frame
		if frame==9:send_jump(false)
		peak=maxf(peak,station.to_local(player.global_position).y)
		if climb.window.active and climb.window.profile=="window":
			entered=true
			var output:=OS.get_environment("TLM_GLOW_REVIEW")
			if captured<capture_progress.size() and climb.window.progress>capture_progress[captured] and DisplayServer.get_name()!="headless" and not output.is_empty():
				if camera==null:
					camera=Camera3D.new()
					world.add_child(camera)
				camera.global_position=station.to_global(Vector3(16.15,2.8,portal.position.z+2.55))
				camera.look_at(portal.global_position+Vector3.UP*.42)
				camera.make_current()
				await process_frame
				RenderingServer.force_draw(false)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("station_window_crossing_%d.png"%captured))
				captured+=1
		if entered and not climb.active:break
	send_jump(false)
	check(entered and not climb.active and station.to_local(player.global_position).x>19.55,"normal jump crosses station window and releases outside")
	check(player.get_node("CollisionShape3D").shape==original_shape and player.collision_mask==original_mask,"window restores normal standing collision")
	if not entered:print("STATION WINDOW failed takeoff position=",station.to_local(player.global_position)," peak=",peak," progress=",climb.window.progress)
	Input.action_press("move_forward")
	for frame in 140:
		await physics_frame
		if station.to_local(player.global_position).x>21.6 and player.is_on_floor():break
	Input.action_release("move_forward")
	check(station.to_local(player.global_position).x>21.6 and player.is_on_floor(),"Arjun walks from supported step to exterior terrain")

func send_jump(pressed: bool) -> void:
	var event:=InputEventAction.new()
	event.action="jump"
	event.pressed=pressed
	Input.parse_input_event(event)
