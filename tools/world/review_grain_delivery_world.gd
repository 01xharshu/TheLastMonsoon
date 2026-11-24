extends SceneTree
## Ordinary-speed actual-world visual review. Output must be in an OS temporary directory.
func _initialize() -> void:
	call_deferred("run")

func capture_waist(camera: Camera3D, actor: Node3D, out: String, label: String) -> bool:
	var focus := actor.global_position+Vector3.UP
	var ok := true
	for side in [-1.0,1.0]:
		camera.global_position = focus + actor.global_basis.x*side*1.5 + actor.global_basis.z*.52 + Vector3.UP*.36
		camera.look_at(focus)
		RenderingServer.force_draw()
		var suffix := "_left" if side < 0.0 else "_right"
		if root.get_texture().get_image().save_png(out.path_join(label+suffix+".png")) != OK:
			ok = false
	return ok

func run() -> void:
	var out := OS.get_environment("TLM_GRAIN_REVIEW_DIR")
	if out.is_empty() or not out.begins_with(OS.get_environment("TMPDIR")):
		push_error("temporary review directory required")
		quit(2)
		return
	var saves: Node = root.get_node("SaveManager")
	saves.save_root = out
	saves.options.fullscreen = false
	saves.options.vsync = false
	saves.apply_options()
	root.size = Vector2i(1280,720)
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	var work: Node
	var deadline := Time.get_ticks_msec()+180000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var posts := world.get_node_or_null("CivicResidentPosts")
		if posts != null:
			var porter := posts.get_node_or_null("GrainStorePorter")
			if porter != null:
				work = porter.get_node_or_null("SupplyDelivery")
				if work != null and work.goods.size()==3 and work.waypoints.size()>=5: break
	if work==null or work.goods.size()!=3:
		push_error("grain worker not ready")
		await saves.quit_game(1)
		return
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	var waist_review := OS.get_environment("TLM_GRAIN_WAIST_REVIEW")=="1"
	var approach: Vector3 = work.institution.to_global(Vector3(-5,0,-6))
	player.global_position=approach+Vector3(0,0,65) if waist_review else approach
	var ui := player.get_node_or_null("UI")
	if ui != null: ui.hide()
	var clock: Node = world.get_node("GameTimeSystem")
	clock.total_game_minutes=600
	clock._update_readable_time(true)
	clock.clock_paused=true
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov=55
	camera.make_current()
	camera.global_position=work.institution.to_global(Vector3(-14,5.2,-15))
	camera.look_at(work.institution.to_global(Vector3(-2,1.5,0)))
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out.path_join("overview.png"))
	var waist_frames: Dictionary = {}
	if waist_review:
		waist_frames["idle"] = capture_waist(camera,work.actor,out,"waist_idle")
		player.global_position=approach
	var captured: Dictionary = {}
	var maximum := 0.0
	var deck_penetration := 0.0
	var tailboard: Node3D = work.cart.visual_root.get_node_or_null("OpenTailboard")
	var open_loading_edge := tailboard != null and tailboard.get_child_count()==1 and absf(tailboard.rotation.x)>3.0
	for child in work.cart.visual_root.get_children():
		if child.get_meta("part_label", "")=="ProduceBundle": open_loading_edge=false
	var start := Time.get_ticks_msec()
	var previous_yaw: float = work.actor.global_rotation.y
	while Time.get_ticks_msec()-start < 150000:
		await process_frame
		maximum=maxf(maximum,work.hand_error)
		var name: String = work.phase
		var yaw: float = work.actor.global_rotation.y
		var turning := absf(angle_difference(previous_yaw,yaw))>.005
		previous_yaw=yaw
		if name in ["lift","inside"]:
			var sack_at: Vector3 = work.cart.to_local(work.goods[work.delivered].global_position)
			if sack_at.z<4.14:
				deck_penetration=maxf(deck_penetration,1.185-sack_at.y)
		if waist_review:
			var waist_sample := ""
			if name=="lift" and work.progress>.48:
				waist_sample="lift"
			elif name=="inside" and work.waypoint<=3 and turning and not waist_frames.has("turn"):
				waist_sample="turn"
			elif name=="inside" and work.waypoint>=3:
				waist_sample="carry"
			elif name=="lower" and work.progress>.48:
				waist_sample="place"
			if not waist_sample.is_empty() and not waist_frames.has(waist_sample):
				waist_frames[waist_sample] = capture_waist(camera,work.actor,out,"waist_"+waist_sample)
		if name in ["lift","inside","lower"] and not captured.has(name) and ((name=="inside" and work.waypoint>=3) or (name!="inside" and work.progress>.5)):
			captured[name] = true
			var focus: Vector3 = work.actor.global_position+Vector3.UP*.9
			var direction: Vector3 = work.actor.global_basis.z * (.45 if name=="lift" else 1.65) + work.actor.global_basis.x * (1.55 if name=="lift" else .9)
			camera.global_position=focus+direction+Vector3.UP*(1.55 if name=="lift" else .45)
			camera.look_at(focus)
			await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(out.path_join(name+".png"))
			print("GRAIN_NATIVE_PHASE ",name," hand=",work.hand_error," blocked=",work.blocked)
		if work.delivered>=1: break
	var ok: bool = open_loading_edge and deck_penetration<.005 and work.delivered>=1 and maximum<.05 and captured.has("lift") and captured.has("inside") and captured.has("lower")
	if waist_review:
		for sample in ["idle","lift","turn","carry","place"]:
			ok = ok and waist_frames.get(sample,false)
		print("GRAIN_WAIST_REVIEW ",waist_frames)
	print("GRAIN_NATIVE: ","PASS" if ok else "FAIL"," delivered=",work.delivered," phase=",work.phase," blocked=",work.blocked," max_hand=",maximum," open_loading_edge=",open_loading_edge," deck_penetration=",deck_penetration," captured=",captured.keys())
	await saves.quit_game(0 if ok else 1)
