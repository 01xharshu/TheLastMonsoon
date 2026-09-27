extends SceneTree
var actor: CharacterBody3D
var failures: Array[String] = []
var routes: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func walk(store: Node3D, target: Vector3) -> bool:
	var reached := false
	var fall := 0.0
	for i in 240:
		var delta := store.to_global(target)-actor.global_position
		delta.y=0
		if delta.length()<.22:
			reached=true
			break
		actor.get_node("CameraPivot").global_rotation.y=atan2(-delta.x,-delta.z)
		Input.action_press("move_forward")
		await physics_frame
		fall=minf(fall,actor.velocity.y)
	Input.action_release("move_forward")
	routes.append({"building":store.name,"target":str(target),"finish":str(store.to_local(actor.global_position)),"reached":reached,"max_fall_speed":fall})
	if not reached or fall < -3: failures.append("%s route to %s" % [store.name,target])
	return reached
func run() -> void:
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	actor=world.get_node("Player")
	actor.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in 10: await physics_frame
	for label in ["TownHall","DistrictPolice"]:
		var store=world.get_node("Settlement/"+label)
		var x: float=store.width*.5-3
		var rear: float=-store.depth*.5
		actor.global_position=store.to_global(Vector3(x,.95,rear+9.5))
		actor.velocity=Vector3.ZERO
		for i in 10: await physics_frame
		await walk(store,Vector3(x,.95,rear+7))
		await walk(store,Vector3(x-1.85,.95,rear+7))
		for i in 3:
			await walk(store,Vector3(x-1.85,.95,rear+2+i*1.5))
			var pickup=store.get_node("CivicWeapon%d" % i)
			var id: String=pickup.persistence_id()
			pickup.interact(actor)
			if not actor.inventory.has_item(pickup.weapon_id): failures.append(label+" acquisition")
			if i!=1 and not pickup.taken and label=="TownHall": failures.append(label+" first acquisition")
			await process_frame
			var remaining: Array=root.get_node("SaveManager")._remaining_weapon_pickup_ids(world)
			if i==1 and not id in remaining: failures.append(label+" duplicate rack removed")
	var saves=root.get_node("SaveManager")
	saves.save_root="user://codex_civic_weapon_walk"
	if not saves.save_game(world,2): failures.append("save failed")
	world.queue_free()
	await process_frame
	var restored=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(restored)
	current_scene=restored
	for i in 5: await physics_frame
	saves.pending_slot=2
	saves.apply_pending(restored)
	await process_frame
	for label in ["TownHall","DistrictPolice"]:
		var store=restored.get_node("Settlement/"+label)
		var remaining=store.find_children("*","StaticBody3D",true,false).filter(func(n): return n.is_in_group("weapon_pickups") and not n.is_queued_for_deletion())
		if remaining.size()!=(1 if label=="TownHall" else 3): failures.append(label+" save restoration")
	var inventory=restored.get_node("Player").inventory
	if not inventory.has_item("enfield") or not inventory.has_item("talwar"): failures.append("saved ownership")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(2)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	var file=FileAccess.open("res://docs/world/civic_weapon_walk_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","routes":routes,"failures":failures},"\t")+"\n")
	print("CIVIC WEAPON WALK ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
