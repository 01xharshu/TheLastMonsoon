extends SceneTree
const Output=preload("res://tools/animals/disposable_review.gd")
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.disable_3d=true;root.add_child(viewport)
	var display:=TextureRect.new();display.texture=viewport.get_texture();display.size=Vector2(1280,720);display.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(display)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	world.get_node("Player").hide();world.get_node("Player/UI").hide();world.get_node("LandscapeUI").hide()
	for frame in 8:await physics_frame
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var yard:Node3D=get_nodes_in_group("household_cattle")[0]
	# Local review keeps the real world/colliders but avoids distant shadow work.
	for mesh:MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		var bounds:AABB=mesh.global_transform*mesh.get_aabb()
		if not bounds.grow(35).has_point(yard.global_position):mesh.hide()
	for light:DirectionalLight3D in world.find_children("*","DirectionalLight3D",true,false):light.directional_shadow_max_distance=40
	var camera:=Camera3D.new();viewport.add_child(camera);camera.make_current();camera.fov=48
	camera.global_position=yard.global_position+Vector3(4,2.6,-6);camera.look_at(yard.global_position+Vector3(0,1,0))
	var views:Dictionary={}
	for frame in 1200:
		for substep in 3:yard.motion.tick(1.0/30);yard.caretaker.tick(1.0/30)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels:=viewport.get_texture().get_image()
		Output.save_jpg(pixels,"cattle_frames/%04d.jpg"%frame,.91)
		if frame%100==0:print("COW WORLD FRAME ",frame," state ",yard.motion.state)
		var label:String=yard.motion.state
		if label=="walk" and not views.has("walk") and frame>60:
			Output.save_png(pixels,"cow_world_oct07_walk.png");views["walk"]=true
		if label in ["graze","feed","drink"] and yard.motion.head_weight>.999 and not views.has(label):
			Output.save_png(pixels,"cow_world_oct07_"+label+".png");views[label]=true;print("WORLD COW VIEW ",label," contact ",yard.motion.contact_error)
		if yard.caretaker.stage=="offer" and yard.caretaker.elapsed>3 and not views.has("caretaker"):
			Output.save_png(pixels,"cow_world_oct07_caretaker.png");views["caretaker"]=true;print("WORLD CARETAKER CONTACT ",yard.caretaker.last_contact_error)
	print("COW WORLD MOTION: frames1200 at 10fps; views ",views," transfers ",yard.caretaker.transfers," hoof ",yard.motion.maximum_stance_error)
	world.queue_free();await process_frame;quit()
