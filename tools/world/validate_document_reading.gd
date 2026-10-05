extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw(false)
	var path := "res://docs/world/captures/document_"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Capture "+label)
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var watchdog := create_timer(240)
	var on_timeout := func(): push_error("Document validation timeout"); quit(2)
	watchdog.timeout.connect(on_timeout)
	var actor: CharacterBody3D = world.get_node("Player")
	for i in 12: await process_frame
	var scroll: Control = actor.get_node("UI/IdentityScroll")
	var motion: Node3D = actor.get_node("DocumentMotion")
	var board: Node3D = world.get_node("Settlement/MarketNoticeBoard")
	var notice: Node3D = board.get_node("MarketNews")
	check(get_nodes_in_group("public_notice_boards").size()==1,"One playable market notice board")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	actor.global_position = notice.global_position + Vector3(0,-.51,.50)
	actor.rotation.y = 0
	actor.get_node("VisualRoot").rotation.y = PI
	camera.global_position = actor.global_position + Vector3(1.2,1.4,1.9)
	camera.look_at(actor.global_position+Vector3(0,1.15,0))
	for i in 12: await physics_frame
	actor.set_physics_process(false)
	# The review camera owns this staged view; the inactive player camera must
	# not hide Arjun based on an obstruction outside the camera being rendered.
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
	actor.visual_root.show()
	check(absf(board.global_position.y - actor.global_position.y + .90)<.15,"Board and actor ground support")
	await capture("market_board")
	var stowed: bool = actor.get_node("VisualRoot/CharacterVisual").equipment.stowed
	var points: int = actor.get_node("FameComponent").points
	var key := InputEventKey.new()
	key.physical_keycode = KEY_O
	key.keycode = KEY_O
	key.pressed = true
	scroll._input(key)
	check(scroll.opening,"O-key opens record")
	for i in 18: await process_frame
	await capture("unroll")
	await create_timer(1.0).timeout
	check(scroll.grid.get_child_count()==6,"Six cards")
	check(scroll.content.visible,"Cards visible")
	check(motion.active and motion.sheet.visible,"Physical scroll visible")
	await capture("cards")
	var draws: int = scroll.redraw_count
	await create_timer(.4).timeout
	check(scroll.redraw_count==draws,"Settled parchment does not redraw every frame")
	scroll.set_open(false)
	await create_timer(1.0).timeout
	check(not motion.active and not actor.get_meta("document_busy",true),"Close releases document lock")
	check(actor.get_node("VisualRoot/CharacterVisual").equipment.stowed==stowed,"Weapon restored")
	notice.interact(actor)
	await create_timer(.4).timeout
	check(not notice.paper.visible,"Wall sheet detached")
	await capture("wall_lift")
	await create_timer(.9).timeout
	check(scroll.opening and notice.reading,"Notice reading")
	await capture("notice_cards")
	scroll.hide()
	camera.global_position = actor.global_position + Vector3(1.8,1.1,.5)
	camera.look_at(motion.global_position)
	print("DOCUMENT CONTACT world=",motion.global_position," mesh=",motion.sheet.global_position," visible=",motion.sheet.is_visible_in_tree()," size=",motion.sheet.mesh.size)
	var rig: Skeleton3D = actor.get_node("VisualRoot/CharacterVisual").skeleton
	for side in ["l","r"]:
		var palm: Vector3 = rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_"+side)) * actor.get_node("VisualRoot/CharacterVisual").equipment.palm_offsets[side])
		var gap := palm.distance_to(motion.edge_targets[side])
		print("DOCUMENT PALM ",side," gap=",gap)
		check(gap<.02,"Reading palm contact "+side)
	await capture("hand_contact")
	scroll.show()
	camera.global_position = actor.global_position + Vector3(1.2,1.4,1.9)
	camera.look_at(actor.global_position+Vector3(0,1.15,0))
	scroll.set_open(false)
	await create_timer(.45).timeout
	await capture("repost")
	await create_timer(.5).timeout
	check(not notice.reading and notice.paper.visible,"Sheet reposted")
	check(actor.get_node("FameComponent").points==points,"Reading gives no fame")
	# Repeated inputs during recovery cannot restart the action.
	scroll.set_open(true)
	scroll.set_open(false)
	scroll.set_open(true)
	check(not scroll.opening,"Recovery prevents overlapping documents")
	await create_timer(1.0).timeout
	# Early close must reverse from the current pose instead of jumping fully open.
	scroll.set_open(true)
	await create_timer(.10).timeout
	var before_close: Vector3 = motion.global_position
	var before_amount: float = motion.open_amount
	scroll.set_open(false)
	await process_frame
	check(motion.open_amount <= before_amount+.01,"Early close does not jump to a fully open pose")
	check(motion.global_position.distance_to(before_close)<.10,"Early close paper continuity")
	await create_timer(1.0).timeout
	# Both rollers retain their round cross section while the paper shortens.
	scroll.set_open(true)
	await create_timer(.35).timeout
	for roller in motion.rollers:
		check(roller.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Rollers stay round")
	await capture("partial_unroll")
	scroll.set_open(false)
	await create_timer(1.0).timeout
	root.size = Vector2i(800,600)
	root.content_scale_size = Vector2i(800,600)
	for i in 3: await process_frame
	scroll.set_open(true)
	await create_timer(1.2).timeout
	check(scroll.grid.columns==1,"Narrow window uses one scrollable card column")
	await capture("narrow")
	scroll.set_open(false)
	await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
		for i in 3: await process_frame
		camera.global_position = actor.global_position + Vector3(1.0,.85,.10)
		camera.look_at(actor.global_position + Vector3(0,.55,-.2))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://document_review_frames"))
		scroll.set_open(true)
		var times: Array[int] = []
		for i in 40:
			if i == 23: scroll.set_open(false)
			await create_timer(1.0/15.0).timeout
			await process_frame
			RenderingServer.force_draw(false)
			times.append(Time.get_ticks_usec())
			root.get_texture().get_image().save_png("user://document_review_frames/%03d.png" % i)
		var timing := FileAccess.open("user://document_review_frames/times.json",FileAccess.WRITE)
		timing.store_string(JSON.stringify(times))
	print("DOCUMENT READING: ", "PASS" if failures.is_empty() else "FAIL", " | cards, unroll, remove/repost, recovery, weapon, redraw, narrow layout")
	watchdog.timeout.disconnect(on_timeout)
	world.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
