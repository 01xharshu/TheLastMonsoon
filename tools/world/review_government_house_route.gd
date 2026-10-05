extends SceneTree
## Continuous actual-controller route; no teleporting between rooms or stair flights.
var world: Node3D
var player: CharacterBody3D
var house: Node3D
var failures: Array[String] = []
var stages: Array[Dictionary] = []
var camera_blocks := 0
var recording := false
var capture_time := 0.0
var frame_index := 0
func _process(delta: float) -> bool:
	if not recording: return false
	capture_time+=delta
	if capture_time < .1: return false
	capture_time-=.1
	root.get_texture().get_image().save_jpg("/tmp/tlm_house_route_frames/%05d.jpg"%frame_index,.9)
	frame_index+=1
	return false
func _initialize() -> void: call_deferred("run")
func controls(direction: Vector3) -> void:
	var local := Basis(Vector3.UP,player.camera_pivot.global_rotation.y).inverse()*direction
	for action in ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
	if local.x < 0: Input.action_press("move_left",-local.x)
	else: Input.action_press("move_right",local.x)
	if local.z < 0: Input.action_press("move_forward",-local.z)
	else: Input.action_press("move_backward",local.z)
func walk(label: String, target: Vector3) -> bool:
	var started := Time.get_ticks_msec()
	var reached := false
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	for frame in 900:
		var point: Vector3 = house.to_local(player.global_position)
		var delta: Vector3 = target-point
		delta.y=0
		if delta.length()<.35:
			reached=absf(point.y-target.y)<.65
			break
		var direction := delta.normalized()
		var yaw := atan2(-direction.x,-direction.z)
		player.camera_pivot.rotation.y=lerp_angle(player.camera_pivot.rotation.y,yaw,.08)
		controls(house.global_basis*direction)
		await physics_frame
		var ray := PhysicsRayQueryParameters3D.create(camera.arm.global_position,camera.global_position)
		ray.exclude=[player.get_rid()]
		ray.collision_mask=camera.arm.collision_mask
		if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): camera_blocks+=1
	controls(Vector3.ZERO)
	for i in 8: await physics_frame
	var result := {"stage":label,"reached":reached,"target":str(target),"finish":str(house.to_local(player.global_position)),"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0}
	stages.append(result)
	print("HOUSE ROUTE ",JSON.stringify(result))
	if not reached: failures.append(label+" could not reach target")
	if DisplayServer.get_name()!="headless" and label in ["entrance","study_bay","drawing_bay","second_landing","bedroom_bay"]:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/house_route_"+label+".png")
	return reached
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size=Vector2i(1280,720)
	root.size=Vector2i(1280,720)
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	player=world.get_node("Player")
	house=world.get_node("Settlement/GovernmentHouse/MainHouse")
	player.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in 12: await physics_frame
	player.global_position=house.to_global(Vector3(0,.95,24))
	player.velocity=Vector3.ZERO
	player.camera_pivot.rotation=Vector3(-.12,0,0)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
	world.get_node("LandscapeUI").hide()
	player.get_node("UI").hide()
	for i in 12: await physics_frame
	if DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute("/tmp/tlm_house_route_frames")
		recording=true
	var route := [
		["entrance",Vector3(0,1.29,10.5)],
		["study_door",Vector3(-20,1.29,10.5)],
		["study_bay",Vector3(-20,1.29,16)],
		["study_return",Vector3(-14,1.29,10.5)],
		["cross_hall",Vector3(0,1.29,0)],
		["stair_approach",Vector3(20,1.29,13)],
		["first_landing",Vector3(20,5.55,-13)],
		["upper_cross_hall",Vector3(6,5.55,-10.5)],
		["drawing_aisle",Vector3(6,5.55,5.5)],
		["drawing_bay",Vector3(-5,5.55,5.5)],
		["drawing_return_aisle",Vector3(6,5.55,5.5)],
		["drawing_return",Vector3(6,5.55,-10.5)],
		["second_stair_approach",Vector3(28,5.55,-13)],
		["second_landing",Vector3(28,10.15,13)],
		["bedroom_cross_hall",Vector3(0,10.15,10.5)],
		["bedroom_approach",Vector3(0,10.15,-10.5)],
		["bedroom_door",Vector3(-19,10.15,-10.5)],
		["bedroom_bay",Vector3(-19,10.15,-5)]
	]
	for stage in route:
		if not await walk(stage[0],stage[1]): break
	recording=false
	if camera_blocks>0: failures.append("Camera segment hit geometry on %d physics frames"%camera_blocks)
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","stages":stages,"camera_blocked_frames":camera_blocks,"failures":failures,"limits":"Actual walk controller at default speed; endpoint views are not continuous motion/owner acceptance"}
	var file:=FileAccess.open("res://docs/world/government_house_route_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("GOVERNMENT HOUSE ROUTE ",report.status)
	world.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
