extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	viewport.world_3d=world.get_world_3d();root.disable_3d=true
	for frame in 8:await physics_frame
	var routine=get_nodes_in_group("village_river_routine")[0]
	routine.set_physics_process(false);world.get_node("GameTimeSystem").clock_paused=true
	var player=world.get_node("Player");player.set_physics_process(false);player.hide();player.get_node("UI").hide();world.get_node("LandscapeUI").hide()
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.fov=44
	for shot in [{"name":"fill","time":17.0},{"name":"wash","time":29.0},{"name":"talk","time":43.0},{"name":"pickup","time":52.8}]:
		for woman in routine.women:woman.sample(shot.time)
		camera.position=routine.shore+Vector3(4.2,2.6,5.8);camera.look_at(routine.shore+Vector3(0,.6,0))
		await process_frame;RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("res://docs/characters/npcs/river_world_"+shot.name+".png")
		print("WORLD_RIVER_CAPTURE ",shot.name)
	world.queue_free();await process_frame;quit()
