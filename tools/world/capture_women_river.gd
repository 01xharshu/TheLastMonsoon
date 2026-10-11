extends SceneTree
var output_dir := OS.get_environment("TLM_RIVER_TEST_OUTPUT")
var detail := "--detail" in OS.get_cmdline_user_args()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if output_dir.is_empty(): push_error("Temporary TLM_RIVER_TEST_OUTPUT required; clean in finally");quit(1);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world: Node3D
	if "--focused" in OS.get_cmdline_user_args():
		world=Node3D.new();root.add_child(world);current_scene=world
		var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
		world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
		var charpai=load("res://objects/charpai.tscn").instantiate();charpai.name="Charpai";world.add_child(charpai)
		world.add_child(load("res://tools/world/river_village_fixture.gd").new())
		var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);world.add_child(sun)
		var environment := WorldEnvironment.new();environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.3,.34,.4)
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;world.add_child(environment)
	else:
		world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	viewport.world_3d=world.get_world_3d();root.disable_3d=true
	for frame in 8:await physics_frame
	print("WORLD_RIVER_READY focused=", "--focused" in OS.get_cmdline_user_args())
	var routine=get_nodes_in_group("village_river_routine")[0]
	routine.set_physics_process(false);world.get_node("GameTimeSystem").clock_paused=true
	if world.has_node("Player"):
		var player=world.get_node("Player");player.set_physics_process(false);player.hide();player.get_node("UI").hide();world.get_node("LandscapeUI").hide()
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.fov=35 if detail else 44
	for shot in [{"name":"walk","time":1.0},{"name":"fill","time":17.0},{"name":"wash","time":29.0},{"name":"talk","time":43.0},{"name":"pickup","time":52.8}]:
		for i in routine.women.size():
			var woman=routine.women[i]
			woman.travel_position=routine.shore+Vector3(-8.0-i*.35,0,(i-1)*1.1)
			woman.travel_position.y=routine._ground_height(woman.travel_position.x,woman.travel_position.z)
			woman.travel_direction=Vector3.RIGHT;woman.travel_speed=routine.SPEED
			woman.travel_gait_time=shot.time+i*.17
			woman.sample(shot.time+i*.17 if shot.name=="walk" else shot.time-i*.7)
		camera.position=routine.shore+Vector3(4.2,2.6,5.8);camera.look_at(routine.shore+Vector3(0,.6,0))
		if shot.name=="walk":
			camera.position=routine.shore+Vector3(-3,3.4,7.5);camera.look_at(routine.shore+Vector3(-6.5,.9,0))
			routine.mode="depart";routine.departure_day=1
			for i in routine.women.size():
				var journey=routine.journeys[i]
				var start_index:int=journey.path.size()-20
				journey.position=journey.path[start_index];journey.goal=start_index+1
				journey.walk_seconds=float(i)*.31;journey.delay=0.0;journey.arrived=false
			var started := Time.get_ticks_msec()
			var last := started
			var frame := 0
			var shot_index := 0
			while Time.get_ticks_msec()-started<3000:
				await physics_frame
				var now := Time.get_ticks_msec()
				routine.tick(float(now-last)/1000.0);last=now;frame+=1
				if detail:
					camera.position=routine.women[0].global_position+Vector3(1.8,1.1,-2.0)
					camera.look_at(routine.women[0].global_position+Vector3(0,.75,0))
				if float(now-started)>float(shot_index+1)*750.0 and shot_index<3:
					RenderingServer.force_draw(false)
					viewport.get_texture().get_image().save_png(output_dir+"/river_walk_%03d.png"%shot_index)
					shot_index+=1
			print("WORLD_RIVER_WALK frames=",frame," wall_seconds=",float(last-started)/1000.0," blocked=",routine.blocked_frames)

		if detail and shot.name!="walk":
			camera.position=routine.women[0].bank+Vector3(1.4,1.2,-1.7)
			camera.look_at(routine.women[0].bank+Vector3(0,.45,0))
		await process_frame;RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png(output_dir+"/river_world_"+shot.name+".png")
		print("WORLD_RIVER_CAPTURE ",shot.name)
	if "--identities" in OS.get_cmdline_user_args():
		for i in routine.women.size():
			var woman:Node3D=routine.women[i]
			woman.travel_override=true;woman.travel_speed=0;woman.travel_direction=Vector3.FORWARD
			woman.sample(1.0)
			var head:Vector3=woman.skeleton.to_global(woman.skeleton.get_bone_global_pose(woman.skeleton.find_bone("head")).origin)+Vector3.UP*.055
			camera.fov=28
			camera.global_position=head+woman.global_basis*Vector3(.10,.08,-1.1);camera.look_at(head)
			await process_frame;RenderingServer.force_draw(false)
			viewport.get_texture().get_image().save_png(output_dir+"/river_face_%d.png"%i)
			print("WORLD_RIVER_IDENTITY ",i)
	if "--budget" in OS.get_cmdline_user_args(): await measure_budget(viewport,routine,world.get_node("GameTimeSystem"))
	world.queue_free();await process_frame;quit()

class TimedFabric:
	extends RefCounted
	var source: RefCounted
	var cost_ms := 0.0
	func update() -> void:
		var started := Time.get_ticks_usec()
		source.update()
		cost_ms += float(Time.get_ticks_usec()-started)/1000.0

func measure_budget(viewport: SubViewport, routine: Node3D, clock: Node) -> void:
	var observer := Node3D.new();routine.get_parent().add_child(observer)
	var previous_viewer: Node3D = routine.viewer
	var saved: Dictionary = routine.export_state()
	var saved_pause: bool = clock.clock_paused
	clock.set_process(false);clock.clock_paused=false
	routine.viewer=observer
	var wrappers: Array[TimedFabric]=[]
	for woman in routine.women:
		var wrapper := TimedFabric.new();wrapper.source=woman.sari_drape;woman.sari_drape=wrapper;wrappers.append(wrapper)
	var rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for remote in [false,true]:
		routine.restore_state(saved);routine.mode="visit";routine.visit_seconds=42.0;routine.physics_age=0.0
		observer.global_position=routine.shore+Vector3(500 if remote else 0,0,0)
		var callback: Array[float]=[];var cpu: Array[float]=[];var gpu: Array[float]=[];var wall: Array[float]=[]
		var fabric: Array[float]=[]
		var prior := Time.get_ticks_usec()
		for frame in 210:
			await process_frame
			var now := Time.get_ticks_usec();var elapsed := float(now-prior)/1000000.0;prior=now
			for wrapper in wrappers:wrapper.cost_ms=0.0
			var started := Time.get_ticks_usec();routine._physics_process(elapsed)
			var cost := float(Time.get_ticks_usec()-started)/1000.0
			RenderingServer.force_draw(false)
			if frame>=30:
				callback.append(cost);wall.append(elapsed*1000)
				var fabric_ms := 0.0
				for wrapper in wrappers:fabric_ms+=wrapper.cost_ms
				fabric.append(fabric_ms)
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		callback.sort();cpu.sort();gpu.sort();wall.sort();fabric.sort()
		print("RIVER_NATIVE_BUDGET ",JSON.stringify({"scope":"focused village, same camera and 1280x720 Forward+ viewport; no whole-game FPS approval","remote":remote,"samples":180,"fabric_median_ms":fabric[90],"callback_median_ms":callback[90],"callback_p95_ms":callback[171],"wall_median_ms":wall[90],"render_cpu_median_ms":cpu[90],"render_gpu_median_ms":gpu[90]}))
	for i in routine.women.size():routine.women[i].sari_drape=wrappers[i].source
	routine.restore_state(saved);routine.viewer=previous_viewer;clock.clock_paused=saved_pause;clock.set_process(true)
	observer.queue_free()
