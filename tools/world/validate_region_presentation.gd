extends "res://tools/world/validate_crime_perception.gd"
func run() -> void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var builder:=preload("res://world/suryagarh/route_and_market_detail.gd").new()
	builder.rock_material=StandardMaterial3D.new()
	builder.rock_material.albedo_texture=load("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg")
	builder.rock_material.albedo_color=Color(.58,.53,.45)
	builder.rock_material.roughness=.96
	var a:=Vector2(380,90);var b:=Vector2(460,10);var normal:=(b-a).normalized().orthogonal()
	var reference: MeshInstance3D=builder._build_drain(a,b,normal)
	var expected: Array=reference.mesh.surface_get_arrays(0)
	var pixels:PackedByteArray=[]
	if DisplayServer.get_name()!="headless":
		world.add_child(reference)
		var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,20,0);world.add_child(light)
		var camera:=Camera3D.new();world.add_child(camera)
		var focus:Vector3=builder.ground((a+b)*.5)
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=150
		camera.global_position=focus+Vector3(0,80,.1);camera.look_at(focus);camera.make_current()
		for frame in 10:await process_frame
		await RenderingServer.frame_post_draw
		pixels=root.get_texture().get_image().get_data()
	reference.free()
	var service:=preload("res://systems/region_presentation.gd").new();world.add_child(service);service.set_process(false)
	var center:Vector3=builder.ground((a+b)*.5)
	service.register("fort_runoff_pilot",center,a.distance_to(b)*.5,builder._build_drain.bind(a,b,normal))
	service.update_viewer(center)
	var instance: MeshInstance3D=service.regions.fort_runoff_pilot.instance
	check(instance!=null and instance.mesh.surface_get_arrays(0)==expected,"near pilot builds exact original runoff geometry")
	check(instance.find_children("*","CollisionObject3D",true,false).is_empty(),"pilot owns only decorative geometry")
	var resource_ref: WeakRef=weakref(instance.mesh)
	instance=null
	service.update_viewer(center+Vector3(1000,0,1000))
	await process_frame
	check(resource_ref.get_ref()==null,"leaving region releases unique mesh resource")
	service.update_viewer(center)
	instance=service.regions.fort_runoff_pilot.instance
	check(instance.mesh.surface_get_arrays(0)==expected,"return rebuilds identical geometry from lightweight records")
	if not pixels.is_empty():
		for frame in 10:await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().get_data()==pixels,"native unloaded-return pixels match reference")
	service.unload_all();instance=null
	await process_frame
	check(service.regions.fort_runoff_pilot.instance==null,"presentation unload leaves lightweight region identity")
	world.queue_free();current_scene=null;builder.free()
	for frame in 3:await process_frame
	print("REGION PRESENTATION ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"production":"opt-in pilot; no whole-world streaming claim"}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
