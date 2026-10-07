extends "res://tools/characters/validate_combat_rescue.gd"
## Fixed 30 Hz animation review; offline frame pacing is not a hardware FPS benchmark.
func run() -> void:
	world=Node3D.new();root.add_child(world);current_scene=world
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,.2,80);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var fm:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;fm.mesh=mesh;fm.position.y=-.1;floor.add_child(fm)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.shadow_enabled=true;world.add_child(light)
	player=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player);player.position=Vector3(0,.9,0)
	visual=player.get_node("VisualRoot/CharacterVisual")
	british=make_actor("Enemy","res://characters/npcs/british/private_man.glb",Vector3(0,0,1),"british")
	indian=make_actor("Peasant","res://characters/npcs/rescue_peasant.glb",Vector3(1.7,0,1),"indian")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	camera=Camera3D.new();camera.fov=45;world.add_child(camera);camera.position=Vector3(-2.7,1.6,4.2);camera.look_at(Vector3(.6,.9,.7));camera.make_current();player.get_node("UI").hide()
	player.set_process_input(false);player.set_process_unhandled_input(false)
	player.get_node("CameraPivot").rotation=Vector3(0,PI,0)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").rotation=Vector3.ZERO
	var folder:="/tmp/tlm_combat_motion_frames_2026-10-05"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 8:await physics_frame
	var combat:=player.get_node("CombatInput")
	british.get_node("Vitality").health=200
	player.inventory.add_item("utility_knife",1);player.inventory.add_item("talwar",1)
	var feet:=visual.get_node("LocomotionFootContact")
	var jump_airborne:=false
	var jump_contacts_released:=false
	var dodge_contacts_released:=false
	for frame in 600:
		match frame:
			15:combat.punch()
			40:combat.punch()
			65:combat.kick()
			95:
				visual.equipment.selected=4;visual.equipment.stowed=false;visual.equipment._refresh()
				player.get_node("KnifeStrike").strike()
			125:
				visual.equipment.selected=0;visual.equipment._refresh();player.get_node("TalwarSlash").strike()
			155:
				visual.equipment.stowed=true;visual.equipment._refresh();player.velocity.y=5;combat.kick_cooldown=0
			159:combat.kick()
			195:
				british.get_node("Vitality").health=75
				player.position=Vector3(0,.9,.25);player.get_node("RearGrapple").begin()
			255:indian.get_node("Vitality").receive_hit(100,british,"abuse")
			305:
				player.position=Vector3(-2,.9,-2)
				Input.action_press("move_forward");Input.action_press("sprint")
			425:
				Input.action_release("move_forward");Input.action_release("sprint");Input.action_press("jump")
			427:Input.action_release("jump")
			550:combat.dodge()
		if frame>=305:
			camera.position=player.position+Vector3(-2.7,1.1,4.2)
			camera.look_at(player.position+Vector3.UP*.2)
		await process_frame
		if frame==430:
			jump_airborne=not player.is_on_floor()
			jump_contacts_released=feet.contacts.is_empty()
		if frame==552:dodge_contacts_released=feet.contacts.is_empty()
		if DisplayServer.get_name()!="headless":
			RenderingServer.force_draw(false,1.0/30.0)
			root.get_texture().get_image().save_png(folder+"/%04d.png"%frame)
	var report={"fps":30,"frames":600,"playback_seconds":20,"offline_render":true,"hardware_fps_verified":false,"stance_contact_samples":feet.contact_samples,"stance_target_max_error_m":feet.contact_error,"arjun_sha256":FileAccess.get_sha256("res://characters/arjun/arjun.glb"),"yoke_sha256":FileAccess.get_sha256("res://characters/arjun/combat_trouser_yoke.glb"),"rescue_peasant_sha256":FileAccess.get_sha256("res://characters/npcs/rescue_peasant.glb"),"jump_airborne":jump_airborne,"jump_contacts_released":jump_contacts_released,"dodge_contacts_released":dodge_contacts_released,"rear_hold_script_sha256":FileAccess.get_sha256("res://player/rear_grapple.gd"),"stance_script_sha256":FileAccess.get_sha256("res://player/locomotion_foot_contact.gd"),"npc_motion_script_sha256":FileAccess.get_sha256("res://combat/npc_combat_motion.gd"),"visual_approved":false}
	var file:=FileAccess.open("res://docs/characters/arjun/combat_motion_review_2026-10-06.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT MOTION FRAMES ",folder," 600 frames at fixed 30 Hz; visual approval open")
	quit()
