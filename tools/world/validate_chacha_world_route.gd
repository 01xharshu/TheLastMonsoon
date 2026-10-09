extends SceneTree
var player: CharacterBody3D
var house: Node3D
func _initialize() -> void:call_deferred("run")
func walk(point: Vector3) -> bool:
	var target:=house.to_global(point)
	for frame in 500:
		var offset:=target-player.global_position;offset.y=0
		if offset.length()<.25:
			Input.action_release("move_forward");print("REACHED ",point," actual ",house.to_local(player.global_position));return true
		player.get_node("CameraPivot").global_rotation.y=atan2(-offset.x,-offset.z)
		Input.action_press("move_forward");await physics_frame
	Input.action_release("move_forward");print("BLOCKED ",point," actual ",house.to_local(player.global_position))
	for j in player.get_slide_collision_count():print("COLLIDER ",player.get_slide_collision(j).get_collider().get_path())
	return false
func run() -> void:
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	for i in 15:await physics_frame
	house=get_first_node_in_group("chacha_house");player=world.get_node("Player")
	if DisplayServer.get_name() != "headless" and not OS.get_environment("TLM_CHACHA_REVIEW_DIR").is_empty():
		var camera:=Camera3D.new();world.add_child(camera);camera.current=true
		camera.global_position=house.to_global(Vector3(17,11,23));camera.look_at(house.to_global(Vector3(0,1.6,2)))
		await create_timer(.6).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_CHACHA_REVIEW_DIR")+"/world.png")
		camera.queue_free();player.get_node("CameraPivot/SpringArm3D/Camera3D").current=true
	player.global_position=house.to_global(Vector3(0,1.1,15));player.velocity=Vector3.ZERO
	var ok:=true
	for point in [Vector3(0,0,7),Vector3(0,0,3),Vector3(0,0,-2),Vector3(0,0,-3.2),Vector3(0,0,1),Vector3(3,0,1),Vector3(5,0,3.4),Vector3(5,0,-4.1),Vector3(5,0,3.4),Vector3(3,0,1),Vector3(0,0,1),Vector3(0,0,15)]:
		if not await walk(point):ok=false;break
		if point == Vector3(0,0,-3.2):
			for id in ["talwar","utility_knife","smoke_bomb","spear"]:
				var rack: Node3D=house.get_node(id.capitalize()+"Rack")
				var station:=house.to_local(rack.global_position);station.z=-3.6
				if not await walk(station):ok=false;break
				player.set_first_person(true)
				var toward:=rack.global_position-player.global_position
				player.get_node("CameraPivot").global_rotation.y=atan2(-toward.x,-toward.z)
				for i in 8:await physics_frame
				for aim_step in 8:
					var sight_delta: Vector3=rack.global_position-player.get_node("CameraPivot/SpringArm3D/Camera3D").global_position
					player.get_node("CameraPivot").global_rotation.y=atan2(-sight_delta.x,-sight_delta.z)
					player.camera_pitch=atan2(sight_delta.y,Vector2(sight_delta.x,sight_delta.z).length())
					player.get_node("CameraPivot").rotation.x=player.camera_pitch
					await physics_frame
				var found: Node=player._find_interactable()
				if found != rack:
					var cam: Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
					print("TARGET FAIL ",id," found ",found," screen ",cam.unproject_position(rack.global_position)," rect ",root.get_visible_rect()," pitch ",player.camera_pitch," camera ",house.to_local(cam.global_position))
					ok=false;break
				var press:=InputEventAction.new();press.action="interact";press.pressed=true;Input.parse_input_event(press);Input.action_press("interact")
				for i in 55:await physics_frame
				Input.action_release("interact");press.pressed=false;Input.parse_input_event(press)
				if not player.inventory.has_item(id):print("COLLECTION FAIL ",id);ok=false;break
				print("TARGETED COLLECTION PASS ",id)
			if not ok:break
			player.set_first_person(false)
			if not await walk(Vector3(0,0,-3.1)):ok=false;break
	print("CHACHA ADVICE ",house.get_meta("advice_given",false)," actor ",house.get_node("Chacha").position)
	print("CHACHA WORLD CONTROLLER: ","PASS" if ok else "FAIL")
	world.queue_free();await process_frame;call_deferred("finish",0 if ok else 1)

func finish(status: int) -> void:
	quit(status)
