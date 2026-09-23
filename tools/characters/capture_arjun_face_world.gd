extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	var actor: CharacterBody3D=world.get_node("Player")
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	actor.global_position=Vector3(-230,world.layout.height(-230,180)+.94,180)
	actor.visual_root.global_rotation.y=0
	var cam:=Camera3D.new()
	cam.fov=42
	world.add_child(cam)
	cam.global_position=actor.global_position+Vector3(0,1.07,3.1)
	cam.look_at(actor.global_position+Vector3(0,.42,0))
	cam.make_current()
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	var path="res://docs/characters/arjun/runtime_skin_close.png"
	var err=root.get_texture().get_image().save_png(path)
	print("ARJUN CLOSE CAPTURE ",err," ",path)
	cam.global_position=actor.global_position+Vector3(0,.72,1.22)
	cam.look_at(actor.global_position+Vector3(0,.43,0))
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var face_path="res://docs/characters/arjun/runtime_face_detail.png"
	var face_error=root.get_texture().get_image().save_png(face_path)
	print("ARJUN FACE CAPTURE ",face_error," ",face_path)
	quit(1 if err!=OK or face_error!=OK else 0)
