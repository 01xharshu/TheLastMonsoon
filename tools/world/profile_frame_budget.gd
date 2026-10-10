extends SceneTree
## Native fixed-budget frame attribution. Print results; retain no artifacts.
const Snapshot = preload("res://tools/world/performance_snapshot.gd")
func _initialize() -> void: _run.call_deferred()
func median(values: Array[float]) -> float:
	values.sort()
	return values[values.size()/2]
func percentile95(values: Array[float]) -> float:
	values.sort()
	return values[int((values.size()-1)*0.95)]
func percentile99(values: Array[float]) -> float:
	values.sort()
	return values[int((values.size()-1)*0.99)]
func isolate(world: Node3D) -> void:
	var scripts: Array[Node] = []
	var trees: Array[AnimationTree] = []
	for node in world.find_children("*","Node",true,false):
		if node.is_physics_processing() and node.get_script()!=null: scripts.append(node)
		if node is AnimationTree and node.active: trees.append(node)
	# Manual animation advances in idle scripts can still run: this mode tests
	# the active flag separately and does not claim to freeze all animation.
	for mode in ["live","render_off","render_and_callbacks_off","render_callbacks_and_animation_off","live_restored"]:
		root.disable_3d = mode not in ["live","live_restored"]
		for node in scripts: node.set_physics_process(mode not in ["render_and_callbacks_off","render_callbacks_and_animation_off"])
		for tree in trees: tree.active = mode!="render_callbacks_and_animation_off"
		for frame in 60: await process_frame
		var wall: Array[float] = []
		var physics: Array[float] = []
		for frame in 240:
			var start := Time.get_ticks_usec()
			await process_frame
			wall.append((Time.get_ticks_usec()-start)/1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		print("FRAME BUDGET ISOLATION ",JSON.stringify({"mode":mode,"wall_ms":median(wall),"wall_p95_ms":percentile95(wall),"physics_ms":median(physics),"physics_p95_ms":percentile95(physics),"active_objects":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),"collision_pairs":Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),"islands":Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),"script_callbacks":scripts.size(),"animation_trees":trees.size()}))
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Frame budget attribution requires the native renderer")
		quit(1)
		return
	var saves := root.get_node("SaveManager")
	saves.options.graphics_quality = 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):saves.options.graphics_quality=clampi(argument.trim_prefix("--quality=").to_int(),0,2)
	saves.options.fullscreen = false
	saves.options.vsync = false
	saves.apply_options()
	var started := Time.get_ticks_msec()
	saves.start_new_game()
	for frame in 4: await process_frame
	var world: Node3D = current_scene
	var actor: CharacterBody3D = world.get_node("Player")
	var opening := world.get_node("OpeningSequence")
	var skip := InputEventKey.new()
	skip.keycode = KEY_ESCAPE
	skip.pressed = true
	opening._input(skip)
	for frame in 2: await process_frame
	opening._input(skip)
	while opening.state != "done": await process_frame
	actor.set_physics_process(false)
	world.get_node("GameTimeSystem").set_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	print("FRAME BUDGET START | ready_ms ",Time.get_ticks_msec()-started," viewport ",root.size," scale ",root.scaling_3d_scale)
	print("PERFORMANCE SNAPSHOT ready ",JSON.stringify(Snapshot.capture()))
	if "--isolate" in OS.get_cmdline_user_args():
		actor.global_position=Vector3(-310,9,245)
		camera.global_position=actor.global_position
		camera.look_at(Vector3(-310,9,230))
		await isolate(world)
		await saves.quit_game()
		return
	await sample_views(world, actor, camera, rid)
	print("FRAME BUDGET PROFILE: COMPLETE | static cameras, live world, selected graphics budget; diagnostic, not gameplay acceptance")
	await saves.quit_game()

func sample_views(world: Node3D, actor: CharacterBody3D, camera: Camera3D, rid: RID) -> void:
	for threshold in ([1.0,4.0] if "--lod-sweep" in OS.get_cmdline_user_args() else [root.mesh_lod_threshold]):
		root.mesh_lod_threshold = threshold
		for spec in [["village",Vector3(-310,9,245),Vector3(-310,9,230)],["civil_lines",Vector3(665,12,275),Vector3(640,12,235)],["cantonment",Vector3(500,11,510),Vector3(500,10,465)]]:
			actor.global_position = spec[1]
			camera.global_position = spec[1]
			camera.look_at(spec[2])
			for frame in 40: await process_frame
			var wall: Array[float] = []
			var render_cpu: Array[float] = []
			var render_gpu: Array[float] = []
			var setup_cpu: Array[float] = []
			var process_cpu: Array[float] = []
			var physics_cpu: Array[float] = []
			var draws: Array[float] = []
			var primitives: Array[float] = []
			for frame in 360:
				var tick := Time.get_ticks_usec()
				await process_frame
				wall.append((Time.get_ticks_usec()-tick)/1000.0)
				render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
				render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
				setup_cpu.append(RenderingServer.get_frame_setup_time_cpu())
				process_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
				physics_cpu.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var gpu_time := median(render_gpu)
			print("PERFORMANCE SNAPSHOT sampled ",spec[0]," ",JSON.stringify(Snapshot.capture()))
			print("FRAME BUDGET ",JSON.stringify({"area":spec[0],"lod_threshold":root.mesh_lod_threshold,"wall_ms":median(wall),"wall_p95_ms":percentile95(wall),"wall_p99_ms":percentile99(wall),"render_cpu_ms":median(render_cpu),"render_gpu_ms":gpu_time if gpu_time>0 else null,"setup_cpu_ms":median(setup_cpu),"process_cpu_ms":median(process_cpu),"process_p95_ms":percentile95(process_cpu),"physics_cpu_ms":median(physics_cpu),"physics_p95_ms":percentile95(physics_cpu),"draws":median(draws),"primitives":median(primitives),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}))
