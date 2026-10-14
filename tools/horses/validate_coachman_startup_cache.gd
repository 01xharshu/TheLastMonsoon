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
	# Source-cache ownership marker for this isolated world (no running clock).
	var clock := Node.new(); clock.name = "GameTimeSystem"; world.add_child(clock)
	var bullock := "--bullock" in OS.get_cmdline_user_args()
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var cart_script := load("res://vehicles/bullock_cart.gd" if bullock else "res://vehicles/family_carriage_candidate.gd")
	var driver_name := "MPFBBullockDriver" if bullock else "CoachmanMakeHuman"
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	if "--pose-review" in OS.get_cmdline_user_args():
		await review_local_pose(world,session,cart_script,driver_name,layout)
		Startup.close(session)
		await root.get_node("SaveManager").quit_game(1 if failed else 0)
		return
	if "--runtime-fitting" in OS.get_cmdline_user_args():
		Startup.close(session)
		var results: Array = []
		var reference_arrays: Array = []
		var fitted_carts: Array[Node3D] = []
		for mode in [0,1,2]:
			var reference: bool = mode==0
			var cart: Node3D = cart_script.new()
			cart.position=Vector3(640,layout.height(640,235),235)
			cart.rotation.y=PI
			cart.set_meta("rebuild_startup_cloth",true)
			cart.set_meta("local_driver_pose",false)
			cart.set_meta("reference_cloth_queries",reference)
			cart.set_meta("reference_cloth_bounds",mode<2)
			world.add_child(cart)
			await process_frame
			await process_frame
			var driver: Node3D = cart.visual_root.get_node(driver_name)
			check(driver.has_meta("startup_cloth_usec"),"Runtime fitting did not complete")
			for piece_index in driver.seated_cloth.pieces.size():
				var mesh: ArrayMesh = driver.seated_cloth.pieces[piece_index].node.mesh
				var arrays: Array = []
				for surface in mesh.get_surface_count(): arrays.append(mesh.surface_get_arrays(surface))
				if reference: reference_arrays.append(arrays)
				else: check(arrays==reference_arrays[piece_index],"Query cache changed runtime garment arrays")
			results.append({"reference_queries":reference,"reference_bounds":mode<2,"setup_us":driver.get_meta("startup_cloth_usec",0),"phases":driver.seated_cloth.fit_timings})
			cart.hide()
			fitted_carts.append(cart)
			await process_frame
		print("COACHMAN CACHE RUNTIME FITTING ",JSON.stringify(results))
		if DisplayServer.get_name() != "headless":
			await compare_native_driver_pixels(world,fitted_carts[0],fitted_carts[2],fitted_carts[0].visual_root.get_node(driver_name))
		for cart in fitted_carts: cart.queue_free()
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
	var readbacks: int = world.get_meta("coachman_mesh_readbacks", 0)
	check(readbacks > 0, "Imported driver sources did not enter owning-world cache")
	cloth.source_signature()
	check(world.get_meta("coachman_mesh_readbacks", 0) == readbacks, "Repeated exact signature read uploaded meshes again")
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
	reference_cart.set_meta("local_driver_pose",false)
	reference_cart.set_meta("rebuild_startup_cloth",true)
	reference_cart.set_meta("reference_cloth_queries",true)
	reference_cart.set_meta("reference_cloth_bounds",true)
	world.add_child(reference_cart)
	await process_frame
	while not session.tasks.is_empty(): await process_frame
	var reference: Node3D = reference_cart.visual_root.get_node(driver_name)
	var reference_cloth = reference.seated_cloth
	# Compare the established canonical geometry under the production local pose.
	reference_cart.set_meta("local_driver_pose",true)
	reference._seat(reference,"CoachmanSeat",0.0)
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
	if DisplayServer.get_name() != "headless":
		await compare_native_driver_pixels(world, cart, reference_cart, driver)
	Startup.close(session)
	var runtime_cart: Node3D = cart_script.new()
	runtime_cart.transform = cart.transform
	world.add_child(runtime_cart)
	var runtime_driver: Node3D
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		runtime_driver = runtime_cart.visual_root.get_node_or_null(driver_name)
		if runtime_driver != null and runtime_driver.has_meta("startup_cloth_usec"): break
		await process_frame
	if runtime_driver == null or not runtime_driver.has_meta("startup_cloth_usec"):
		check(false, "Runtime driver did not finish deferred creation and fitting within 60 seconds")
		await root.get_node("SaveManager").quit_game(1)
		return
	check(runtime_driver.get_meta("startup_cloth_cache",false),"Runtime traffic rejected the exact-input cloth cache")
	print("COACHMAN CACHE PARITY ",JSON.stringify({"status":"FAIL" if failed else "PASS","bullock":bullock,"max_position_error_m":max_position_error,"retained_skinned_meshes":body_meshes.size(),"cached_setup_us":driver.get_meta("startup_cloth_usec",0),"rebuild_setup_us":reference.get_meta("startup_cloth_usec",0),"runtime_cached_setup_us":runtime_driver.get_meta("startup_cloth_usec",0)}))
	await root.get_node("SaveManager").quit_game(1 if failed else 0)

func review_local_pose(world: Node3D,session: RefCounted,cart_script: Script,driver_name: String,layout: RefCounted) -> void:
	var carts: Array[Node3D] = []
	for index in 2:
		var cart: Node3D = cart_script.new()
		cart.position=Vector3(-265,layout.height(-265,-18),-18)
		cart.rotation.y=PI*.5
		world.add_child(cart)
		await process_frame
		while not session.tasks.is_empty(): await process_frame
		check(cart.visual_root.get_node(driver_name).get_meta("startup_cloth_cache",false),"Existing cache source/pose validation failed before local-pose comparison")
		carts.append(cart)
	var original: Node3D = carts[0].visual_root.get_node(driver_name)
	var candidate: Node3D = carts[1].visual_root.get_node(driver_name)
	carts[0].set_meta("local_driver_pose",false)
	original._seat(original,"CoachmanSeat",0.0)
	var before := posed_vertices(original,carts[0])
	carts[1].set_meta("local_driver_pose",true)
	candidate._seat(candidate,"CoachmanSeat",0.0)
	var after := posed_vertices(candidate,carts[1])
	check(before.size()==after.size(),"Local pose removed body vertices")
	var maximum := 0.0
	for index in before.size(): maximum=maxf(maximum,before[index].distance_to(after[index]))
	check(maximum<.0005,"Local pose changed body position by more than 0.5 mm")
	for index in candidate.seated_cloth.pieces.size():
		check(candidate.seated_cloth.pieces[index].node.mesh==original.seated_cloth.pieces[index].node.mesh,"Local pose replaced established garment geometry")
	print("COACHMAN CACHE LOCAL BODY ",JSON.stringify({"max_posed_vertex_difference_m":maximum,"skinned_vertices":before.size(),"left_hand_gap_m":candidate.get_meta("hand_contact_l",INF),"right_hand_gap_m":candidate.get_meta("hand_contact_r",INF),"original_left_hand_gap_m":original.get_meta("hand_contact_l",INF),"original_right_hand_gap_m":original.get_meta("hand_contact_r",INF)}))
	for side in ["l","r"]:
		check(candidate.get_meta("hand_contact_"+side,INF)<=original.get_meta("hand_contact_"+side,0.0)+.0001,"Local seating worsened rein contact")
	var cache: Resource = load(candidate.seated_cloth.startup_cache_path()).duplicate()
	candidate.seated_cloth.startup_signature=candidate.seated_cloth.source_signature()
	cache.set_meta("signature",candidate.seated_cloth.startup_signature)
	carts[1].set_meta("test_cloth_cache",cache)
	for spec in [[-265,-18,PI*.5],[-403,225,PI*.5],[-416,230,-PI*.5],[500,470,0.0],[640,235,PI]]:
		carts[1].position=Vector3(spec[0],layout.height(spec[0],spec[1]),spec[1])
		carts[1].rotation.y=spec[2]
		candidate._seat(candidate,"CoachmanSeat",0.0)
		candidate.seated_cloth.startup_signature=candidate.seated_cloth.source_signature()
		check(candidate.seated_cloth._restore_startup_cache(),"Strict local-pose cache failed at "+str(carts[1].position))
		print("COACHMAN CACHE LOCAL HIT ",str(carts[1].position))
	carts[1].transform=carts[0].transform
	candidate._seat(candidate,"CoachmanSeat",0.0)
	if DisplayServer.get_name() != "headless": await compare_native_driver_pixels(world,carts[0],carts[1],original)

static func posed_vertices(driver: Node3D,cart: Node3D) -> PackedVector3Array:
	var output := PackedVector3Array()
	var rig: Skeleton3D = driver._skeleton
	var relative: Transform3D = cart.global_transform.affine_inverse()*rig.global_transform
	for node in driver.find_children("*","MeshInstance3D",true,false):
		if node.skin==null: continue
		var binds: Array[Transform3D] = []
		for bind in node.skin.get_bind_count():
			var bone: int = node.skin.get_bind_bone(bind)
			if bone<0: bone=rig.find_bone(node.skin.get_bind_name(bind))
			binds.append(relative*rig.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int = bones.size()/vertices.size()
			for index in vertices.size():
				var point := Vector3.ZERO
				for slot in stride:
					var offset: int=index*stride+slot
					if weights[offset]>0: point+=(binds[bones[offset]]*vertices[index])*weights[offset]
				output.append(point)
	return output

func compare_locations(world: Node3D,session: RefCounted,cart_script: Script,driver_name: String,layout: RefCounted) -> void:
	var reference_pose := PackedFloat32Array()
	var reference_hash := ""
	var reference_raw := PackedFloat32Array()
	for spec in [[-265,-18,PI*.5],[-403,225,PI*.5],[-416,230,-PI*.5],[500,470,0.0],[640,235,PI]]:
		var cart: Node3D = cart_script.new()
		cart.set_meta("local_driver_pose",true)
		cart.position = Vector3(spec[0],layout.height(spec[0],spec[1]),spec[1])
		cart.rotation.y = spec[2]
		world.add_child(cart)
		await process_frame
		while not session.tasks.is_empty(): await process_frame
		var driver: Node3D = cart.visual_root.get_node(driver_name)
		var cloth = driver.seated_cloth
		var rig: Skeleton3D = driver._skeleton
		var relative: Transform3D = cart.global_transform.affine_inverse()*rig.global_transform
		if cart.get_meta("local_driver_pose",false): relative=preload("res://vehicles/seated_driver_coordinates.gd").relative(rig,cart)
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
		check(signature==reference_hash,"Local driver pose changed with world coordinates")
		check(driver.get_meta("startup_cloth_cache",false),"Production cache missed at world location")
		var different_values := 0
		var max_difference := 0.0
		var max_raw_difference := 0.0
		for index in pose.size():
			if pose[index] != reference_pose[index]: different_values += 1
			max_difference=maxf(max_difference,absf(pose[index]-reference_pose[index]))
			max_raw_difference=maxf(max_raw_difference,absf(raw_pose[index]-reference_raw[index]))
		print("COACHMAN CACHE LOCATION ",JSON.stringify({"position":str(cart.position),"yaw":spec[2],"hit":driver.get_meta("startup_cloth_cache",false),"setup_us":driver.get_meta("startup_cloth_usec",0),"signature_equal":signature==reference_hash,"pose_bytes_equal":pose.to_byte_array()==reference_pose.to_byte_array(),"different_pose_values":different_values,"max_quantized_pose_difference":max_difference,"max_raw_pose_difference":max_raw_difference}))
		var original_updates: int = cloth.updates
		for step in 12:
			cart.position+=Vector3(.03,0,.02)
			cart.rotation.y+=.01
			await driver._process(1.0/60.0)
		check(cloth.updates==original_updates,"Moving driver unnecessarily rebuilt cached clothing")
		cart.queue_free()
		await process_frame

func compare_native_driver_pixels(world: Node3D, cart: Node3D, reference_cart: Node3D, driver: Node3D) -> void:
	var camera := Camera3D.new()
	world.add_child(camera)
	# View the driver from the footboard side; the carriage cabin occludes +Z.
	camera.global_position = driver.global_position + cart.global_basis*Vector3(2,1.3,-2)
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
	var pose_review := "--pose-review" in OS.get_cmdline_user_args()
	var before: Image
	var after: Image
	if pose_review:
		cart.hide(); reference_cart.show()
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		before = root.get_texture().get_image()
		reference_cart.hide(); cart.show()
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		after = root.get_texture().get_image()
	else:
		var images: Array[Image] = await matched_driver_pixels(cart, reference_cart, driver)
		before = images[0]; after = images[1]
	if not pose_review: check(before.get_data()==after.get_data(),"Cached versus rebuilt driver pixels changed")
	print("COACHMAN CACHE PIXEL PARITY | equal ",before.get_data()==after.get_data())
	if pose_review:
		print("COACHMAN CACHE POSE PIXELS ",JSON.stringify(before.compute_image_metrics(after,false))," | quantified visual review; strict fit/cache pixel test unchanged")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-dir="):
			var directory := argument.trim_prefix("--review-dir=")
			check(directory.is_absolute_path() and directory.get_file().begins_with("tlm-performance-"),"Review needs temporary runner directory")
			if not failed:
				after.save_png(directory.path_join("coachman_cache.png"))
				if pose_review: before.save_png(directory.path_join("local_driver.png"))

func matched_driver_pixels(cart: Node3D, reference_cart: Node3D, driver: Node3D) -> Array[Image]:
	# Hold the carriage/horse scene and body pose constant. Switching complete
	# vehicle instances also switches independently initialized draft-team rigs.
	var reference_driver: Node3D = reference_cart.visual_root.get_node(str(driver.name))
	var reference_parent := reference_driver.get_parent()
	var reference_transform := reference_driver.transform
	var reference_rig: Skeleton3D = reference_driver._skeleton
	var reference_rig_transform := reference_rig.transform
	var saved_poses: Array[Dictionary] = []
	for index in reference_rig.get_bone_count():
		saved_poses.append({"position":reference_rig.get_bone_pose_position(index), "rotation":reference_rig.get_bone_pose_rotation(index), "scale":reference_rig.get_bone_pose_scale(index)})
	reference_driver.reparent(cart.visual_root, false)
	reference_driver.transform = driver.transform
	reference_rig.transform = driver._skeleton.transform
	for index in reference_rig.get_bone_count():
		reference_rig.set_bone_pose_position(index, driver._skeleton.get_bone_pose_position(index))
		reference_rig.set_bone_pose_rotation(index, driver._skeleton.get_bone_pose_rotation(index))
		reference_rig.set_bone_pose_scale(index, driver._skeleton.get_bone_pose_scale(index))
	reference_rig.force_update_all_bone_transforms()
	driver._skeleton.force_update_all_bone_transforms()
	cart.show(); reference_cart.hide(); driver.hide(); reference_driver.show()
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var reference_repeat := root.get_texture().get_image()
	reference_driver.hide(); driver.show()
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var cached_repeat := root.get_texture().get_image()
	print("COACHMAN PIXEL STABILITY ", JSON.stringify({"reference_stable": before.get_data() == reference_repeat.get_data(), "cached_stable": after.get_data() == cached_repeat.get_data(), "metrics": before.compute_image_metrics(after, false)}))
	reference_driver.reparent(reference_parent, false)
	reference_driver.transform = reference_transform
	reference_rig.transform = reference_rig_transform
	for index in saved_poses.size():
		var pose: Dictionary = saved_poses[index]
		reference_rig.set_bone_pose_position(index, pose.position)
		reference_rig.set_bone_pose_rotation(index, pose.rotation)
		reference_rig.set_bone_pose_scale(index, pose.scale)
	reference_rig.force_update_all_bone_transforms()
	return [before, after]

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
	var relative: Transform3D = preload("res://vehicles/seated_driver_coordinates.gd").relative(rig,cloth.coach) if cloth.coach.get_meta("local_driver_pose",true) else cloth.coach.global_transform.affine_inverse()*rig.global_transform
	for index in rig.get_bone_count():
		var transform: Transform3D = relative*rig.get_bone_global_pose(index)
		for axis in [transform.basis.x,transform.basis.y,transform.basis.z,transform.origin]:
			for component in [axis.x,axis.y,axis.z]: pose.append(snappedf(component,.001))
	digest.update(var_to_bytes(pose))
	return digest.finish().hex_encode()
