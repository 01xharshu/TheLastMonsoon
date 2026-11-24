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
	for x in [-6.4,6.4]:
		for z in [-1.8,2.4,5.0]:
			var at: Vector3 = work.institution.to_global(Vector3(x,.16,z))
			var deck_ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.15,at-Vector3.UP*.2,1)
			await physics_frame
			var deck_hit := world.get_world_3d().direct_space_state.intersect_ray(deck_ray)
			check(not deck_hit.is_empty() and absf(deck_hit.position.y-at.y)<.03,"expanded deck is obstructed or unsupported at %s" % Vector2(x,z))
	# The delivery owner points to a receiving marker inside the actual store.
	var store: Node3D = work.institution.get_parent()
	var side_shed := store.get_node_or_null("GrainSideShed") as Node3D
	check(side_shed != null, "side shed missing")
	if side_shed != null:
		var space := world.get_world_3d().direct_space_state
		var start := side_shed.to_global(Vector3(0,1.1,-3.0))
		var end := side_shed.to_global(Vector3(0,1.1,.8))
		var entrance := PhysicsRayQueryParameters3D.create(start,end,1)
		check(space.intersect_ray(entrance).is_empty(), "side shed entrance blocked")
		check(side_shed.find_children("CoveredGrainSack*","StaticBody3D",false,false).size()==3, "covered sacks missing")
		for x in [-1.1,1.1]:
			var deck_at := side_shed.to_global(Vector3(x,.12,.4))
			var support := PhysicsRayQueryParameters3D.create(deck_at+Vector3.UP*.15,deck_at-Vector3.UP*.2,1)
			var hit := space.intersect_ray(support)
			check(not hit.is_empty() and absf(hit.position.y-deck_at.y)<.03, "side shed deck lacks support")
	var saved := false
	var max_hand := 0.0
	for frame in 7000:
		work.tick(.05)
		await physics_frame
		max_hand=maxf(max_hand,work.hand_error)
		if not saved and work.phase=="inside" and work.waypoint==2:
			await check_pedestrian_stop(world, work)
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

func check_pedestrian_stop(world: Node3D, work: Node) -> void:
	var guard: Node3D = world.get_node_or_null("CivicResidentPosts/HospitalGateGuard")
	check(guard != null, "resident for carry clearance check missing")
	if guard == null:
		return
	var guard_transform := guard.global_transform
	var guard_processing := guard.is_physics_processing()
	var start: Vector3 = work.actor.global_position
	var direction: Vector3 = work.waypoints[work.waypoint] - start
	direction.y = 0
	check(direction.length() > .9, "carry leg too short for clearance check")
	if direction.length() <= .9:
		return
	direction = direction.normalized()
	guard.set_physics_process(false)
	guard.global_position = start + direction * .9
	guard.body_collider.force_update_transform()
	await physics_frame
	var initial_blocks: int = work.blocked
	for frame in 30:
		work.tick(.05)
		await physics_frame
	check(work.blocked > initial_blocks, "porter did not stop for the resident")
	var advance: Vector3 = work.actor.global_position - start
	check(advance.dot(direction) < .65, "porter entered resident clearance")
	check(work.goods[0].get_parent() == work.actor, "porter released sack during stop")
	guard.global_transform = guard_transform
	guard.body_collider.force_update_transform()
	guard.set_physics_process(guard_processing)
	await physics_frame
	print("GRAIN_PEDESTRIAN blocked_ticks=", work.blocked - initial_blocks, " advance=", advance.dot(direction))
