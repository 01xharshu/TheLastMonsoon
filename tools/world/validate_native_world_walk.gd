extends SceneTree
## Native, normal-time controller play pass. Use an isolated user directory.
var failures: Array[String] = []
var world: Node3D
var actor: CharacterBody3D
var output := OS.get_environment("TLM_TEST_OUTPUT_DIR")
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PLAY ","PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label);push_error(label)
func button(action: String,down: bool) -> void:
	var event := InputEventAction.new();event.action=action;event.pressed=down
	Input.parse_input_event(event)
func face(direction: Vector3) -> void:
	direction.y=0;direction=direction.normalized()
	actor.camera_pivot.global_rotation=Vector3(deg_to_rad(-10),atan2(-direction.x,-direction.z),0)
	actor.camera_pitch=deg_to_rad(-10)
	actor.visual_root.global_rotation=Vector3(0,atan2(direction.x,direction.z),0)
func place(point: Vector2,direction: Vector2) -> void:
	actor.global_position=Vector3(point.x,world.layout.height(point.x,point.y)+.95,point.y)
	actor.velocity=Vector3.ZERO
	face(Vector3(direction.x,0,direction.y))
	for frame in 8:await physics_frame
func capture(label: String) -> void:
	if output.is_empty():return
	RenderingServer.force_draw()
	var pixels := root.get_texture().get_image()
	print("PLAY VIEW ",label," physical_texture=",pixels.get_size()," scale=",root.scaling_3d_scale)
	pixels.resize(960,540,Image.INTERPOLATE_LANCZOS)
	check(pixels.save_png(output.path_join(label+".png"))==OK,"temporary view "+label)
func travel(label: String,point: Vector2,direction: Vector2) -> void:
	await place(point,direction)
	for frame in 24:await process_frame
	# Let the world's amortised nearby population settle before timing input.
	for frame in 180:await physics_frame
	await capture(label+"_start")
	var start := actor.global_position
	var tick := Time.get_ticks_msec();var frames := 0;var floor_frames := 0;var simulation := 0.0
	var blockers: Dictionary = {}
	face(Vector3(direction.x,0,direction.y))
	button("move_forward",true)
	var middle_taken := false
	while simulation<3.0 and Time.get_ticks_msec()-tick<30000:
		await physics_frame;frames+=1;simulation+=actor.get_physics_process_delta_time()
		face(Vector3(direction.x,0,direction.y))
		if actor.is_on_floor():floor_frames+=1
		for index in actor.get_slide_collision_count():
			var collision := actor.get_slide_collision(index)
			if absf(collision.get_normal().y)<.6:
				var collider: Object=collision.get_collider()
				if collider is Node:blockers[str(collider.get_path())]=true
		if not middle_taken and simulation>1.5:
			await capture(label+"_moving");middle_taken=true
	button("move_forward",false)
	check(simulation>=3.0,label+" completes the full walking sample")
	var distance := Vector2(actor.global_position.x-start.x,actor.global_position.z-start.z).length()
	check(distance>2.0,label+" forward walking "+str(snappedf(distance,.01))+"m")
	var displacement := Vector2(actor.global_position.x-start.x,actor.global_position.z-start.z)
	check(displacement.dot(direction.normalized())>2.0 and absf(displacement.cross(direction.normalized()))<1.0,label+" stays on intended walking line")
	check(actor.global_position.is_finite() and actor.health>0,label+" remains alive on terrain")
	print("PLAY MOTION ",JSON.stringify({"area":label,"distance_m":distance,"physics_frames":frames,"simulation_seconds":simulation,"blockers":blockers.keys(),"floor_frames":floor_frames,"end":str(actor.global_position),"wall_seconds":(Time.get_ticks_msec()-tick)/1000.0}))
	await capture(label+"_end")
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("This play pass requires rendering");quit(2);return
	var saves := root.get_node("SaveManager")
	saves.options.fullscreen=false;saves.options.graphics_quality=0;saves.options.vsync=false;saves.apply_options()
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	root.title="The Last Monsoon — Integration Play Check"
	root.disable_3d=true
	saves.start_new_game()
	for frame in 4:await process_frame
	world=current_scene;actor=world.get_node("Player")
	var opening := world.get_node("OpeningSequence")
	# Owner-authorized intro bypass: retain the real world/player/controllers.
	opening.morning();opening._release()
	check(opening.state=="done" and actor.is_physics_processing(),"intro bypass releases normal controls")
	root.disable_3d=false
	# Review gameplay beyond onboarding, matching a completed tutorial save.
	actor.get_node("UI/HUDRoot/MorningTutorial").restore_step(11)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;root.grab_focus()
	print("NATIVE PLAY READY viewport=",root.size," scale=",root.scaling_3d_scale)
	await travel("village",Vector2(-340,231),Vector2(1,0))
	if "--village-only" in OS.get_cmdline_user_args():
		print("NATIVE VILLAGE PLAY ","PASS" if failures.is_empty() else "FAIL"," | ",JSON.stringify(failures))
		saves.quit_game(0 if failures.is_empty() else 1);return
	await travel("market",Vector2(-346,275),Vector2(1,0))
	await travel("mountain",Vector2(520,-170),Vector2(1,0))
	await travel("bazaar",Vector2(605,470),Vector2(1,0))
	await place(Vector2(-346,275),Vector2(1,0))
	var stamina_start: float=actor.survival.stamina
	var start := actor.global_position
	button("move_forward",true);button("sprint",true)
	for frame in 150:await physics_frame
	button("sprint",false);button("move_forward",false)
	check(actor.global_position.distance_to(start)>3.0 and actor.survival.stamina<stamina_start,"sprint moves and consumes stamina")
	await create_timer(.5).timeout
	var base_y := actor.global_position.y;var high_y := base_y
	button("jump",true)
	for frame in 2:await physics_frame
	button("jump",false)
	var jump_stop:=Time.get_ticks_msec()+2500
	while Time.get_ticks_msec()<jump_stop:
		await physics_frame;high_y=maxf(high_y,actor.global_position.y)
	check(high_y-base_y>.2,"jump leaves the ground")
	check(actor.is_on_floor(),"jump lands on market lane")
	await capture("jump_landed")
	var well: Interactable=world.get_node("Settlement/BhairavpurVillageWell/WellBody")
	var point:=Vector2(well.global_position.x,well.global_position.z+1.95)
	await place(point,Vector2(0,-1))
	var inventory: Node=actor.get_node("InventoryComponent")
	inventory.stored_water_liters=0.0
	check(actor._find_interactable()==well,"ordinary targeting selects the village well")
	button("interact",true);await create_timer(1.5).timeout;button("interact",false)
	check(inventory.get_stored_water_liters()>0.0,"interaction input fills the water bag")
	await capture("well_interaction")
	print("NATIVE WORLD PLAY ","PASS" if failures.is_empty() else "FAIL"," | ",JSON.stringify(failures))
	saves.quit_game(0 if failures.is_empty() else 1)
