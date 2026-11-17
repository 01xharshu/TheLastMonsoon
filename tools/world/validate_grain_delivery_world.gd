extends SceneTree
## Actual populated world: worker, wagon, opening and saved carried sack.
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and not errors.has(message): errors.append(message)
func run() -> void:
	var saves: Node = root.get_node("SaveManager")
	var save_dir := OS.get_environment("TLM_GRAIN_SAVE_DIR")
	if save_dir.is_empty() or not save_dir.begins_with(OS.get_environment("TMPDIR")):
		push_error("a disposable save directory is required")
		await saves.quit_game(1)
		return
	saves.save_root=save_dir
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
	var clock: Node = world.get_node("GameTimeSystem")
	clock.clock_paused=true;clock.current_hour=10
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	player.global_position=work.institution.to_global(Vector3(-5,0,-6))
	work.set_physics_process(false)
	check(work.sack_delivery,"sack mode not active")
	check(work.cart.boarding._clearance_at(work.cart.global_position),"cart footprint blocked")
	var saved := false
	var max_hand := 0.0
	for frame in 7000:
		work.tick(.05)
		await physics_frame
		max_hand=maxf(max_hand,work.hand_error)
		if not saved and work.phase=="inside":
			var saved_ok: bool=saves.save_game(world,1)
			check(saved_ok,"disk save failed: "+saves.last_error)
			var slot: Dictionary=saves.read_slot(1) if saved_ok else {}
			var operations: Dictionary=slot.get("institution_operations",{})
			var key:=str(world.get_path_to(work))
			check(operations.has(key),"saved operation missing from disk")
			work.restore_state(operations.get(key,{}))
			saved=true
			check(work.goods[0].get_parent()==work.actor,"carried sack did not restore")
		if frame%800==0: print("GRAIN_WORLD_PROGRESS ",work.phase," delivered=",work.delivered," blocked=",work.blocked," local=",work.institution.to_local(work.actor.global_position))
		if work.delivered==3 and work.phase=="rest":break
		if work.blocked>1500:break
	check(saved,"did not reach carrying phase")
	check(work.delivered==3 and work.phase=="rest","three sacks were not delivered")
	check(max_hand<.05,"hand-to-sack error exceeds 50 mm")
	for item in work.goods:
		if item.get_parent()!=work.institution:continue
		var q:=PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP*.1,item.global_position-Vector3.UP*.15,1,[item.get_node("ConsignmentBody").get_rid()])
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(q)
		check(not hit.is_empty() and absf(hit.position.y-item.global_position.y)<.025,"stored sack lacks platform support")
	print("GRAIN_WORLD: ","PASS" if errors.is_empty() else "FAIL"," delivered=",work.delivered," blocked=",work.blocked," hand=",max_hand," errors=",errors)
	await saves.quit_game(0 if errors.is_empty() else 1)
