extends SceneTree
const Startup = preload("res://systems/world_startup.gd")
var failed := false
var baseline := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error(message)
func run() -> void:
	paused = true
	var session := Startup.start(self)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var bullock := "--bullock" in OS.get_cmdline_user_args()
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var cart_script := load("res://vehicles/bullock_cart.gd" if bullock else "res://vehicles/family_carriage_candidate.gd")
	var driver_name := "MPFBBullockDriver" if bullock else "CoachmanMakeHuman"
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	if "--runtime-fitting" in OS.get_cmdline_user_args():
		Startup.close(session)
		var results: Array = []
		for legacy in [true,false]:
			var cart: Node3D = cart_script.new()
			cart.position=Vector3(640,layout.height(640,235),235)
			cart.rotation.y=PI
			cart.set_meta("rebuild_startup_cloth",true)
			cart.set_meta("reference_cloth_uploads",legacy)
			world.add_child(cart)
			await process_frame
			await process_frame
			var driver: Node3D = cart.visual_root.get_node(driver_name)
			check(driver.has_meta("startup_cloth_usec"),"Runtime fitting did not complete")
			results.append({"legacy_uploads":legacy,"setup_us":driver.get_meta("startup_cloth_usec",0)})
			cart.queue_free()
			await process_frame
		print("COACHMAN CACHE RUNTIME FITTING ",JSON.stringify(results))
		await root.get_node("SaveManager").quit_game(1 if failed else 0)
		return
	if "--locations" in OS.get_cmdline_user_args():
		await compare_locations(world,session,cart_script,driver_name,layout)
		Startup.close(session)
		await root.get_node("SaveManager").quit_game(1 if failed else 0)
		return
	var cart: Node3D = cart_script.new()
	cart.position = Vector3(-265,layout.height(-265,-18),-18)
	cart.rotation.y = PI*.5
	world.add_child(cart)
	await process_frame
	var driver: Node3D = cart.visual_root.get_node(driver_name)
	while not session.tasks.is_empty(): await process_frame
	if baseline:
		print("COACHMAN CACHE BASELINE ",JSON.stringify({"bullock":bullock,"cache_hit":driver.get_meta("startup_cloth_cache",false),"setup_us":driver.get_meta("startup_cloth_usec",0),"signature":driver.seated_cloth.source_signature()}))
		Startup.close(session)
		await root.get_node("SaveManager").quit_game()
		return
	check(driver.get_meta("startup_cloth_cache",false),"Starting pose rejected the baked garment")
	var cloth = driver.seated_cloth
	var reference_times: Array[int] = []
	var current_times: Array[int] = []
	for round_index in 5:
		for reference_query in ([true,false] if round_index%2==0 else [false,true]):
			var start := Time.get_ticks_usec()
			var signature: String = reference_signature(cloth) if reference_query else cloth.source_signature()
			(reference_times if reference_query else current_times).append(Time.get_ticks_usec()-start)
			check(signature == cloth.startup_signature,"Metadata filter changed exact-input body/garment/pose hash")
	reference_times.sort();current_times.sort()
	print("COACHMAN CACHE QUERY ",JSON.stringify({"original_signature_median_us":reference_times[2],"metadata_signature_median_us":current_times[2],"signature_equal":not failed,"scope":"signature query only; full-body inputs retained"}))
	var expected: Array = []
	var body_meshes: Array = []
	for node in driver.find_children("*","MeshInstance3D",true,false):
		if node.skin != null: body_meshes.append([node,node.mesh,node.skin])
	for piece in cloth.pieces:
		var surfaces: Array = []
		for surface in piece.node.mesh.get_surface_count(): surfaces.append(piece.node.mesh.surface_get_arrays(surface))
		expected.append(surfaces)
	cloth.startup_signature = "stale-input"
	check(not cloth._restore_startup_cache(),"Stale body/pose input was accepted")
	var rig: Skeleton3D = driver._skeleton
	var pelvis := rig.find_bone("pelvis")
	var original_position := rig.get_bone_pose_position(pelvis)
	rig.set_bone_pose_position(pelvis,original_position+Vector3.UP*.005)
	cloth.startup_signature=cloth.source_signature()
	check(not cloth._restore_startup_cache(),"Changed seated pose was accepted by rounding-tolerant cache")
	rig.set_bone_pose_position(pelvis,original_position)
	cloth.startup_signature=cloth.source_signature()
	var reference_cart: Node3D = cart_script.new()
	reference_cart.transform = cart.transform
	reference_cart.set_meta("rebuild_startup_cloth",true)
	reference_cart.set_meta("reference_cloth_uploads",true)
	world.add_child(reference_cart)
	await process_frame
	while not session.tasks.is_empty(): await process_frame
	var reference: Node3D = reference_cart.visual_root.get_node(driver_name)
	var reference_cloth = reference.seated_cloth
	var max_position_error := 0.0
	for index in cloth.pieces.size():
		var node: MeshInstance3D = reference_cloth.pieces[index].node
		for surface in node.mesh.get_surface_count():
			var actual: Array = node.mesh.surface_get_arrays(surface)
			for field in Mesh.ARRAY_MAX:
				if field == Mesh.ARRAY_VERTEX:
					for vertex in actual[field].size(): max_position_error = maxf(max_position_error,actual[field][vertex].distance_to(expected[index][surface][field][vertex]))
				else: check(actual[field] == expected[index][surface][field],"Cached garment differs in field %s" % field)
	check(max_position_error < .000001,"Cached garment position changed")
	for retained in body_meshes:
		check(retained[0].mesh == retained[1] and retained[0].skin == retained[2],"Cache replaced the retained MPFB body/foundation")
	var cpu_cart: Node3D = cart_script.new()
	cpu_cart.transform=cart.transform
	cpu_cart.set_meta("rebuild_startup_cloth",true)
	world.add_child(cpu_cart)
	await process_frame
	while not session.tasks.is_empty(): await process_frame
	var cpu_driver: Node3D = cpu_cart.visual_root.get_node(driver_name)
	for index in cloth.pieces.size():
		var cpu_mesh: ArrayMesh = cpu_driver.seated_cloth.pieces[index].node.mesh
		for surface in cpu_mesh.get_surface_count():
			var arrays: Array = cpu_mesh.surface_get_arrays(surface)
			for field in Mesh.ARRAY_MAX:
				check(arrays[field]==expected[index][surface][field],"CPU-only garment preparation differs in field %s" % field)
	print("COACHMAN CACHE CPU PREPARATION ",JSON.stringify({"legacy_setup_us":reference.get_meta("startup_cloth_usec",0),"cpu_setup_us":cpu_driver.get_meta("startup_cloth_usec",0),"arrays_equal":not failed}))
	cpu_cart.hide()
	if DisplayServer.get_name() != "headless":
		await compare_native_driver_pixels(world, cart, reference_cart, driver)
		reference_cart.hide()
		await compare_native_driver_pixels(world,cart,cpu_cart,driver)
		cpu_cart.hide()
	Startup.close(session)
	var runtime_cart: Node3D = cart_script.new()
	runtime_cart.transform = cart.transform
	world.add_child(runtime_cart)
	await process_frame
	var runtime_driver: Node3D = runtime_cart.visual_root.get_node(driver_name)
	check(runtime_driver.get_meta("startup_cloth_cache",false),"Runtime traffic rejected the exact-input cloth cache")
	print("COACHMAN CACHE PARITY ",JSON.stringify({"status":"FAIL" if failed else "PASS","bullock":bullock,"max_position_error_m":max_position_error,"retained_skinned_meshes":body_meshes.size(),"cached_setup_us":driver.get_meta("startup_cloth_usec",0),"rebuild_setup_us":reference.get_meta("startup_cloth_usec",0),"runtime_cached_setup_us":runtime_driver.get_meta("startup_cloth_usec",0)}))
	await root.get_node("SaveManager").quit_game(1 if failed else 0)

func compare_locations(world: Node3D,session: RefCounted,cart_script: Script,driver_name: String,layout: RefCounted) -> void:
	var reference_pose := PackedFloat32Array()
	var reference_hash := ""
	var reference_raw := PackedFloat32Array()
	for spec in [[-265,-18,PI*.5],[-403,225,PI*.5],[-416,230,-PI*.5],[500,470,0.0],[640,235,PI]]:
		var cart: Node3D = cart_script.new()
		cart.position = Vector3(spec[0],layout.height(spec[0],spec[1]),spec[1])
		cart.rotation.y = spec[2]
		world.add_child(cart)
		await process_frame
		while not session.tasks.is_empty(): await process_frame
		var driver: Node3D = cart.visual_root.get_node(driver_name)
		var cloth = driver.seated_cloth
		var rig: Skeleton3D = driver._skeleton
		var relative: Transform3D = cart.global_transform.affine_inverse()*rig.global_transform
		var pose := PackedFloat32Array()
		var raw_pose := PackedFloat32Array()
		for index in rig.get_bone_count():
			var transform: Transform3D = relative*rig.get_bone_global_pose(index)
			for axis in [transform.basis.x,transform.basis.y,transform.basis.z,transform.origin]:
				for component in [axis.x,axis.y,axis.z]:
					raw_pose.append(component)
					pose.append(snappedf(component,.001))
		var signature: String = cloth.source_signature()
		if reference_pose.is_empty(): reference_pose=pose;reference_hash=signature;reference_raw=raw_pose.duplicate()
		var different_values := 0
		var max_difference := 0.0
		var max_raw_difference := 0.0
		for index in pose.size():
			if pose[index] != reference_pose[index]: different_values += 1
			max_difference=maxf(max_difference,absf(pose[index]-reference_pose[index]))
			max_raw_difference=maxf(max_raw_difference,absf(raw_pose[index]-reference_raw[index]))
		print("COACHMAN CACHE LOCATION ",JSON.stringify({"position":str(cart.position),"yaw":spec[2],"hit":driver.get_meta("startup_cloth_cache",false),"setup_us":driver.get_meta("startup_cloth_usec",0),"signature_equal":signature==reference_hash,"pose_bytes_equal":pose.to_byte_array()==reference_pose.to_byte_array(),"different_pose_values":different_values,"max_quantized_pose_difference":max_difference,"max_raw_pose_difference":max_raw_difference}))
		if spec[0] == 640 and driver.get_meta("startup_cloth_cache",false):
			var reference_cart: Node3D = cart_script.new()
			reference_cart.transform=cart.transform
			reference_cart.set_meta("rebuild_startup_cloth",true)
			world.add_child(reference_cart)
			await process_frame
			while not session.tasks.is_empty(): await process_frame
			var reference_driver: Node3D = reference_cart.visual_root.get_node(driver_name)
			var maximum_error := 0.0
			for piece_index in cloth.pieces.size():
				var cached_mesh: ArrayMesh = cloth.pieces[piece_index].node.mesh
				var rebuilt_mesh: ArrayMesh = reference_driver.seated_cloth.pieces[piece_index].node.mesh
				for surface in cached_mesh.get_surface_count():
					var cached_arrays: Array = cached_mesh.surface_get_arrays(surface)
					var rebuilt_arrays: Array = rebuilt_mesh.surface_get_arrays(surface)
					check(cached_arrays[Mesh.ARRAY_INDEX]==rebuilt_arrays[Mesh.ARRAY_INDEX],"Location cache changed garment topology")
					for vertex in cached_arrays[Mesh.ARRAY_VERTEX].size():
						maximum_error=maxf(maximum_error,cached_arrays[Mesh.ARRAY_VERTEX][vertex].distance_to(rebuilt_arrays[Mesh.ARRAY_VERTEX][vertex]))
			check(maximum_error<.0005,"Location cache garment differs by more than 0.5 mm")
			print("COACHMAN CACHE LOCATION GEOMETRY ",JSON.stringify({"max_position_error_m":maximum_error,"cached_setup_us":driver.get_meta("startup_cloth_usec",0),"rebuild_setup_us":reference_driver.get_meta("startup_cloth_usec",0)}))
			if DisplayServer.get_name() != "headless": await compare_native_driver_pixels(world,cart,reference_cart,driver)
			reference_cart.queue_free()
		cart.queue_free()
		await process_frame

func compare_native_driver_pixels(world: Node3D, cart: Node3D, reference_cart: Node3D, driver: Node3D) -> void:
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = driver.global_position + cart.global_basis*Vector3(2,1.3,2)
	camera.look_at(driver.global_position + Vector3.UP*.45)
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	world.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.18,.23,.28)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .5
	world.add_child(environment)
	cart.hide();reference_cart.show()
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	reference_cart.hide();cart.show()
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	check(before.get_data()==after.get_data(),"Cached versus rebuilt driver pixels changed")
	print("COACHMAN CACHE PIXEL PARITY | equal ",before.get_data()==after.get_data())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-dir="):
			var directory := argument.trim_prefix("--review-dir=")
			check(directory.is_absolute_path() and directory.get_file().begins_with("tlm-performance-"),"Review needs temporary runner directory")
			if not failed: after.save_png(directory.path_join("coachman_cache.png"))

func reference_signature(cloth: RefCounted) -> String:
	# Previous full readback filter retained as the exact-input reference.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for piece in cloth.pieces:
		digest.update(var_to_bytes(piece.node.transform))
		for surface in piece.surfaces: digest.update(var_to_bytes(surface.arrays))
	for node in cloth.actor.find_children("*","MeshInstance3D",true,false):
		if node.skin == null: continue
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_VERTEX].size() >= 14000: digest.update(var_to_bytes(arrays))
	var rig: Skeleton3D = cloth.actor._skeleton
	var pose := PackedFloat32Array()
	var relative: Transform3D = cloth.coach.global_transform.affine_inverse()*rig.global_transform
	for index in rig.get_bone_count():
		var transform: Transform3D = relative*rig.get_bone_global_pose(index)
		for axis in [transform.basis.x,transform.basis.y,transform.basis.z,transform.origin]:
			for component in [axis.x,axis.y,axis.z]: pose.append(snappedf(component,.001))
	digest.update(var_to_bytes(pose))
	return digest.finish().hex_encode()
