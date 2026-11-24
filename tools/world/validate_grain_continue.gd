extends SceneTree
## Fresh-world Continue from a disposable mid-carry slot created by validate_grain_delivery_world.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var saves: Node = root.get_node("SaveManager")
	var save_dir := OS.get_environment("TLM_GRAIN_SAVE_DIR")
	if save_dir.is_empty() or not save_dir.begins_with(OS.get_environment("TMPDIR")):
		push_error("a disposable save directory is required")
		await saves.quit_game(1)
		return
	saves.save_root = save_dir
	var pending_world := Node3D.new()
	root.add_child(pending_world)
	pending_world.set_meta("unclaimed_institution_operations",{"late_worker":{"phase":"inside"}})
	var pending_states: Dictionary = saves._institution_states(pending_world)
	var pending_ok: bool = pending_states.has("late_worker") and pending_states["late_worker"].get("phase","")=="inside"
	pending_world.queue_free()
	if not pending_ok:
		push_error("unspawned worker state is lost on re-save")
		await saves.quit_game(1)
		return
	saves.pending_slot = 1
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec()+180000
	var work: Node
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var posts := world.get_node_or_null("CivicResidentPosts")
		if posts != null:
			var porter := posts.get_node_or_null("GrainStorePorter")
			if porter != null:
				work = porter.get_node_or_null("SupplyDelivery")
				if work != null and work.goods.size()==3 and work.waypoints.size()>=5 and saves.pending_slot<0: break
	if work==null or work.goods.size()!=3:
		push_error("grain worker not ready after Continue")
		await saves.quit_game(1)
		return
	work.set_physics_process(false)
	var restored: bool = work.phase=="inside" and work.delivered==0 and work.goods[0].get_parent()==work.actor
	print("GRAIN_CONTINUE_RESTORE ",restored," phase=",work.phase," delivered=",work.delivered," pending=",saves.pending_slot)
	var peak := 0.0
	for frame in 7000:
		work.tick(.05)
		await physics_frame
		peak=maxf(peak,work.hand_error)
		if work.delivered==3 and work.phase=="rest":break
		if work.blocked>1500:break
	var ok: bool = restored and work.delivered==3 and work.phase=="rest" and peak<.05
	print("GRAIN_CONTINUE: ","PASS" if ok else "FAIL"," delivered=",work.delivered," phase=",work.phase," blocked=",work.blocked," hand=",peak)
	await saves.quit_game(0 if ok else 1)
