extends SceneTree
var submitted := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(OS.get_user_data_dir()==OS.get_environment("TLM_EXPECT_USER_DATA"))
	RenderingServer.frame_post_draw.connect(func():submitted+=1)
	var world:=Node3D.new();root.add_child(world)
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();world.add_child(mesh)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(2,2,3);camera.look_at(Vector3.ZERO);camera.make_current()
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
	root.always_on_top=true;root.grab_focus()
	print("RENDER SAMPLING CONTEXT visible=",root.visible," mode=",root.mode," low_processor=",OS.low_processor_usage_mode," loop=",RenderingServer.render_loop_enabled)
	for mode in ["live","paused","forced"]:
		paused=mode!="live"
		var start:=Engine.get_frames_drawn();var before:=submitted
		for frame in 60:
			await process_frame
			if mode=="forced":RenderingServer.force_draw()
		print("RENDER SAMPLING ",mode," engine_frames=",Engine.get_frames_drawn()-start," submissions=",submitted-before)
	print("RENDER SAMPLING PASS")
	await root.get_node("SaveManager").quit_game()
