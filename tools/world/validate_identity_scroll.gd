extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	var scroll: Control = player.get_node("UI/IdentityScroll")
	var fame: Node = player.get_node("FameComponent")
	for i in 8: await process_frame
	assert(fame.points == 0)
	scroll.set_open(true)
	assert(player.get_meta("scroll_open", false))
	scroll._process(1.0)
	for i in 3: await process_frame
	assert(scroll.visible and scroll.progress > 0.96)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := "res://docs/world/captures/17_identity_scroll.png"
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("SCROLL CAPTURE ", path)
	fame.award_flag_cut()
	assert(fame.points == 1)
	fame.award_help()
	assert(fame.points == 5)
	scroll.set_open(false)
	scroll._process(1.0)
	assert(not player.get_meta("scroll_open", true))
	for i in 3: await physics_frame
	var flags := get_nodes_in_group("cuttable_flags")
	assert(not flags.is_empty())
	var flag: Node3D = flags[0]
	assert(flag.cloth != null and flag.rope != null)
	var flag_visual: Node3D = flag.get_child(0)
	assert(is_equal_approx(flag_visual.scale.x, 0.55))
	player.global_position = flag.global_position + Vector3(0, 0, 1.15)
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	for i in 3: await process_frame
	camera.look_at(flag.global_position + Vector3.UP * 1.25)
	var visual: Node3D = player.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = false
	visual.equipment.selected = 0
	visual.equipment._refresh()
	var slash: Node = player.get_node("TalwarSlash")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	slash._unhandled_input(click)
	slash._process(0.4)
	for i in 3: await process_frame
	print("SWORD TIP DISTANCE ", visual.equipment.talwar_hand.to_global(Vector3(0.78, 0, 0)).distance_to(flag.global_position + Vector3.UP * 1.25))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var flag_path := "res://docs/world/captures/18_flag_slash.png"
		assert(root.get_texture().get_image().save_png(flag_path) == OK)
		print("FLAG CAPTURE ", flag_path)
	assert(flag.cut)
	assert(fame.points == 6)
	await create_timer(0.85).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var fallen_path := "res://docs/world/captures/19_flag_fallen.png"
		assert(root.get_texture().get_image().save_png(fallen_path) == OK)
	slash._process(0.4)
	slash._unhandled_input(click)
	slash._process(0.4)
	assert(fame.points == 6)
	print("IDENTITY SCROLL: PASS | open, fame awards, close, one flag cut")
	quit()
