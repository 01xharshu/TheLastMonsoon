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
	world.queue_free();await process_frame;quit()
