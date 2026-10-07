extends SceneTree
## Full Suryagarh route: existing neighbouring houses, real jumping and camera collision.
var world: Node3D
var actor: CharacterBody3D
var failures: Array[String] = []
var camera: Camera3D
var frames := 0
var rendered := false
var folder := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func support(at: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*12,at-Vector3.UP*3)
	ray.exclude = [actor.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(ray)
func capture() -> void:
	frames += 1
	await physics_frame
func save_view(label: String) -> void:
	if not rendered: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
	await physics_frame
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): folder = argument.trim_prefix("--output-dir=")
	var temporary_root := OS.get_environment("TMPDIR")
	if temporary_root.is_empty(): temporary_root = "/tmp"
	temporary_root = temporary_root.simplify_path().trim_suffix("/")
	if folder.is_empty(): folder = temporary_root.path_join("tlm-roof-%d" % OS.get_process_id())
	folder = folder.simplify_path().trim_suffix("/")
	if folder.get_base_dir() != temporary_root or not (folder.get_file().begins_with("tlm-climb-review-") or folder.get_file().begins_with("tlm-roof-")):
		push_error("Review output must use a dedicated directory inside the OS temporary directory")
		folder = ""
		quit(1)
		return
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world); current_scene = world
	actor = world.get_node("Player")
	for tick in 12: await physics_frame
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	actor.camera_pitch=-.2
	var climb: Node = actor.get_node("ClimbComponent")
	climb.set_physics_process(false)
	actor.get_node("UI").hide()
	camera = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.make_current()
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(folder)
	if rendered:
		root.mode=Window.MODE_WINDOWED; root.size=Vector2i(960,540)
		root.scaling_3d_scale=.55
		root.show()
	world.get_node("GameTimeSystem").advance_hours(6)
	var source: Node3D = world.get_node("Settlement/BhairavpurHouse2")
	var target: Node3D = world.get_node("Settlement/BhairavpurHouse10")
	check(source.has_meta("climb_architecture") and target.has_meta("climb_architecture"),"neighbouring world houses preserve visible grip geometry")
	var access_house: Node3D = world.get_node("Settlement/BhairavpurHouse2")
	var street := access_house.to_global(Vector3(-5.50,0,0))
	var street_hit := support(street)
	if street_hit.is_empty(): check(false,"street support for world house access"); await finish(); return
	actor.global_position=street_hit.position+Vector3.UP*.94
	actor.visual_root.global_rotation.y=atan2(access_house.global_basis.x.x,access_house.global_basis.x.z)
	actor.get_node("CameraPivot").global_rotation.y=actor.visual_root.global_rotation.y+PI
	for tick in 10:
		actor.velocity=Vector3.DOWN; actor.move_and_slide(); await capture()
	actor.velocity=Vector3.UP*actor.jump_velocity; climb.arm_jump()
	for tick in 75:
		actor.velocity.y-=actor.gravity/60.0
		actor.move_and_slide(); climb._physics_process(1.0/60.0)
		await capture()
		if climb.active: break
	check(climb.active,"street jump catches actual village house")
	await save_view("world_reach")
	for tick in 22:
		climb._physics_process(1.0/60.0)
		await capture()
	await save_view("world_catch")
	var wait_time := 0.0
	for tick in 900:
		if not climb.active: break
		if climb.waiting_for_move:
			wait_time+=1.0/60.0
			if wait_time>.25: climb.request_move(); wait_time=0.0
		climb._physics_process(1.0/60.0)
		await capture()
	check(not climb.active and actor.global_position.y>access_house.global_position.y+3.5,"actual village house route reaches solid roof")
	await save_view("house_access")
	var start := source.global_position+Vector3(4.0,0,0)
	var floor_hit := support(start)
	if floor_hit.is_empty(): check(false,"source roof support"); await finish(); return
	actor.global_position = floor_hit.position+Vector3.UP*1.04
	actor.visual_root.global_rotation.y=PI/2
	actor.get_node("CameraPivot").global_rotation.y=-PI/2
	actor.get_node("CameraPivot").rotation.x=-.2
	for tick in 20:
		actor.velocity=Vector3.DOWN
		actor.move_and_slide()
		await capture()
	check(actor.is_on_floor(),"Arjun stands on source roof with full collider")
	actor.velocity=Vector3(4,actor.jump_velocity,0)
	climb.arm_jump()
	var airborne := 0
	var landed := false
	var smallest_camera_distance := INF
	for tick in 180:
		actor.velocity.x=4
		actor.velocity.y-=actor.gravity/60.0
		actor.move_and_slide()
		climb._physics_process(1.0/60.0)
		if not actor.is_on_floor(): airborne+=1
		await capture()
		smallest_camera_distance=minf(smallest_camera_distance,camera.global_position.distance_to(actor.global_position))
		if tick==25: await save_view("roof_gap_jump")
		if actor.is_on_floor() and airborne>3:
			landed=true;break
	check(landed and airborne>20,"roof gap requires airborne jump and returns to supported landing")
	var target_local: Vector3=target.to_local(actor.global_position)
	check(absf(target_local.x)<4.45 and absf(target_local.z)<3.5,"jump lands on neighbouring ordinary house")
	check(not climb.active and actor.global_position.y>target.global_position.y+3.0,"landing releases normal movement on neighbour roof")
	check(smallest_camera_distance>.5,"gameplay camera retains separation during roof jump")
	await save_view("roof_landing")
	await finish()
func finish() -> void:
	var result := {"result":"PASS" if failures.is_empty() else "FAIL","failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"frames":frames,"position":str(actor.global_position)}
	print("WORLD ROOF ESCAPE ",JSON.stringify(result))
	for type_name in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for voice in root.find_children("*",type_name,true,false): voice.stop(); voice.stream=null
	world.queue_free()
	for tick in 3: await process_frame
	_clear_output()
	quit(0 if failures.is_empty() else 1)

func _clear_output() -> void:
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder): return
	for filename in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)

func _finalize() -> void:
	_clear_output()
