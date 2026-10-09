extends SceneTree
## Full world morning handoff and room route; optional disposable native views.
var failures: Array[String]=[]
var world: Node3D
var player: CharacterBody3D
var station: Node3D
var inquiry: Node3D
var output := ""
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	if not value:failures.append(label);push_error(label)
func capture(label: String,at: Vector3,target: Vector3) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true
	camera.global_position=station.to_global(at);camera.look_at(station.to_global(target))
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
	camera.queue_free();player.get_node("CameraPivot/SpringArm3D/Camera3D").current=true
func walk(local: Vector3) -> bool:
	var target:=station.to_global(local)
	for frame in 650:
		var offset:=target-player.global_position;offset.y=0
		if offset.length()<.22:Input.action_release("move_forward");print("INQUIRY REACHED ",local);return true
		player.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.z)
		Input.action_press("move_forward");await physics_frame
	Input.action_release("move_forward");print("INQUIRY BLOCKED ",local," at ",station.to_local(player.global_position));return false
func run() -> void:
	output=OS.get_environment("TLM_INQUIRY_REVIEW_DIR")
	if not output.is_empty() and not output.begins_with(OS.get_environment("TMPDIR")):quit(2);return
	root.get_node("SaveManager").pending_slot=0
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	if OS.get_environment("TLM_INQUIRY_ISOLATE_RIVER")=="1":
		for node in world.find_children("*","Node",true,false):
			if node.get_script()!=null and node.get_script().resource_path.ends_with("village_river_routine.gd"):
				node.set_physics_process(false)
		print("INQUIRY REVIEW: river routine isolated; clean whole-world gate remains open")
	for frame in 30:await physics_frame
	player=world.get_node("Player");inquiry=world.get_node("DevInquiry");station=inquiry.station
	var opening: Node=world.get_node("OpeningSequence")
	check(inquiry.stage=="dormant","no main objective during night opening")
	var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.pressed=true;opening._input(event)
	await create_timer(.9).timeout
	check(inquiry.stage=="dormant","morning seat waits for control release")
	event.keycode=KEY_W;opening._input(event);await create_timer(1.7).timeout
	check(opening.state=="done" and inquiry.stage=="police","opening releases into police inquiry marker")
	check(world.get_node("GameTimeSystem").current_hour==6,"inquiry follows morning")
	player.global_position=station.to_global(Vector3(0,.95,24));player.velocity=Vector3.ZERO
	await capture("guarded_entrance",Vector3(8,2.4,27),Vector3(0,1.2,18))
	for point in [Vector3(0,0,16),Vector3(0,0,12),Vector3(6,0,12),Vector3(8.3,0,9)]:check(await walk(point),"normal station route "+str(point))
	check(inquiry.request("police",player),"world police conversation")
	await capture("police_question",Vector3(5.5,1.8,10),Vector3(9,1.1,7))
	inquiry._process(30)
	check(inquiry.stage=="superior","world referral")
	for point in [Vector3(8,0,7),Vector3(0,0,7),Vector3(0,0,-7),Vector3(-5,0,-7),Vector3(-7.3,0,-7),Vector3(-9.5,0,-5.2)]:
		check(await walk(point),"normal chamber route "+str(point))
	check(inquiry.request("superior",player),"world superior meeting")
	inquiry._process(11)
	await capture("three_officials",Vector3(-8,2.2,-3.7),Vector3(-9.6,1.25,-8.3))
	await capture("official_expression",Vector3(-9.6,1.6,-6.7),Vector3(-9.5,1.6,-8.3))
	inquiry._process(15)
	await capture("arjun_objection",Vector3(-11.2,1.65,-7),Vector3(-9.5,1.4,-5.2))
	inquiry._process(20)
	check(inquiry.stage=="summoning","world two-soldier summons")
	await capture("soldiers_entering",Vector3(-10.8,2,-4),Vector3(-6,1,-7))
	for frame in 1900:
		await physics_frame
		if inquiry.stage!="summoning":break
	check(inquiry.stage=="punishment","world soldiers reach Arjun and hand off custody")
	print("DEV INQUIRY WORLD: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(status: int) -> void:quit(status)
