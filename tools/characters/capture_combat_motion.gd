extends "res://tools/characters/validate_combat_rescue.gd"
## Fixed 30 Hz animation review; offline frame pacing is not a hardware FPS benchmark.
func run() -> void:
	world=Node3D.new();root.add_child(world);current_scene=world
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var fm:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;fm.mesh=mesh;fm.position.y=-.1;floor.add_child(fm)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);world.add_child(light)
	player=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player);player.position=Vector3(0,.9,0)
	visual=player.get_node("VisualRoot/CharacterVisual")
	british=make_actor("Enemy","res://characters/npcs/british/private_man.glb",Vector3(0,0,1),"british")
	indian=make_actor("Peasant","res://characters/npcs/rescue_peasant.glb",Vector3(1.7,0,1),"indian")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	camera=Camera3D.new();camera.fov=45;world.add_child(camera);camera.position=Vector3(-2.7,1.6,4.2);camera.look_at(Vector3(.6,.9,.7));camera.make_current();player.get_node("UI").hide()
	player.set_process_input(false);player.set_process_unhandled_input(false)
	player.get_node("CameraPivot").rotation=Vector3(0,PI,0)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").rotation=Vector3.ZERO
	var folder:="/tmp/tlm_combat_motion_frames_2026-10-05"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 8:await physics_frame
	var combat:=player.get_node("CombatInput")
	for frame in 240:
		match frame:
			15:combat.punch()
			40:combat.punch()
			65:combat.kick()
			95:player.velocity.y=5;combat.kick_cooldown=0
			99:combat.kick()
			130:player.position=Vector3(0,.9,.25);player.get_node("RearGrapple").begin()
			190:indian.get_node("Vitality").receive_hit(100,british,"abuse")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/%04d.png"%frame)
	print("COMBAT MOTION FRAMES ",folder," 240 frames at fixed 30 Hz; visual approval open")
	quit()
