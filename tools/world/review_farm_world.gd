extends SceneTree
var failed:=false
func _initialize()->void:run.call_deferred()
func run()->void:
	create_timer(100).timeout.connect(func():push_error("Farm world startup timed out");quit(2))
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	var viewport:=SubViewport.new();viewport.size=Vector2i(960,540);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);root.disable_3d=true
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	for frame in 600:
		await process_frame
		if not get_nodes_in_group("household_cattle").is_empty() and root.find_child("EstateField5",true,false)!=null:break
	var yards:=get_nodes_in_group("household_cattle")
	if yards.is_empty():push_error("No cattle yard in main world");quit(1);return
	var yard:Node3D=yards[0]
	assert(yard.get_node("ShelterBatched").mesh.get_surface_count()==3)
	assert(yard.get_node("GrazingGrass") is MultiMeshInstance3D)
	var garden:Node3D=root.find_child("BhairavpurKitchenGarden0",true,false)
	assert(garden!=null and garden.get_node_or_null("FarmPlants")!=null)
	var estate:Node3D=root.find_child("EstateField5",true,false)
	assert(estate!=null and estate.get_node_or_null("FarmPlants")!=null)
	for path in ["Player","Player/UI","LandscapeUI"]:
		var node:=world.get_node_or_null(path)
		if node is Node3D or node is CanvasItem:node.hide()
	var camera:=Camera3D.new();viewport.add_child(camera);camera.make_current();camera.fov=55;camera.far=250
	var output:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
	for target:Node3D in [garden,estate,yard]:
		camera.global_position=target.global_position+Vector3(5,3.5,6)
		camera.look_at(target.global_position+Vector3.UP*.6)
		for frame in 12:await process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		if not output.is_empty():viewport.get_texture().get_image().save_png(output+"/"+str(target.name)+".png")
	print("FARM MAIN WORLD PASS: garden/estate batches, three shelter surfaces, one grazing batch; runtime care retained")
	world.queue_free();await process_frame;quit()
