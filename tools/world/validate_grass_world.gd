extends SceneTree
## Actual populated-world smoke/frame sample; stdout only, never writes saves.
const Startup=preload("res://systems/world_startup.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var expected:=OS.get_environment("TLM_EXPECT_USER_DATA")
	assert(not expected.is_empty() and OS.get_user_data_dir()==expected,"Disposable userdata required")
	var saves:=root.get_node("SaveManager")
	saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.options.vsync=false;saves.apply_options()
	var session:=Startup.start(self)
	# Match the title loader: gameplay is paused until async builders finish.
	paused=true
	saves.start_new_game();await scene_changed
	var world:Node3D=current_scene
	while not session.tasks.is_empty():await process_frame
	while saves.pending_slot>=0:await process_frame
	world.show();Startup.close(session);paused=false
	print("GRASS WORLD startup complete; checkpoints=",session.checkpoints)
	var opening:=world.get_node("OpeningSequence")
	var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
	opening._input(skip);await process_frame;opening._input(skip)
	while opening.state!="done":await process_frame
	var totals:Dictionary={"batches":0,"instances":0}
	for landscape in [world.get_node("Landscape"),world.get_node("WildernessExpansion")]:
		for batch in landscape.get_node("NatureTiles").find_children("Grass*","MultiMeshInstance3D",true,false):
			assert(batch.multimesh.mesh.surface_get_array_index_len(0)>0,"Unindexed gameplay grass")
			totals.batches+=1;totals.instances+=batch.multimesh.instance_count
	print("GRASS WORLD indexed live batches/instances ",totals)
	var actor:CharacterBody3D=world.get_node("Player");actor.set_physics_process(false)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	for spec in [["grass",Vector2(-800,-600)],["village",Vector2(-310,245)],["city",Vector2(-350,-310)]]:
		var point:Vector2=spec[1]
		actor.global_position=Vector3(point.x,world.layout.height(point.x,point.y)+1,point.y)
		camera.global_position=actor.global_position+Vector3(0,1,0);camera.look_at(camera.global_position+Vector3(20,-1.4,-20))
		for frame in 40:await process_frame
		var samples:Array[float]=[]
		var tick:=Time.get_ticks_usec()
		for frame in 120:
			await process_frame
			var now:=Time.get_ticks_usec();samples.append((now-tick)/1000.0);tick=now
		var scale:=root.scaling_3d_scale
		samples.sort()
		print("GRASS WORLD native region=",spec[0]," p50/p95ms=",[samples[60],samples[114]]," viewport=",root.size," scale=",scale," scope=live post-change sample, not A/B attribution")
	print("GRASS WORLD PASS: native actual startup/opening-skip/three regions; no save writes")
	saves.quit_game()
