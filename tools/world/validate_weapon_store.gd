extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var gear: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	var store: Node3D = world.get_node("Settlement/CompanyArmoury")
	var builder: Node3D = world.get_node("Settlement")
	assert(not actor.inventory.has_item("talwar") and not actor.inventory.has_item("enfield"))
	assert(not gear.talwar_hand.visible and not gear.talwar_waist.visible)
	assert(not gear.enfield_hand.visible and not gear.enfield_back.visible)
	gear.toggle_stowed()
	assert(gear.stowed)
	gear.select_weapon(1)
	assert(gear.selected == 0)
	var pickups := store.find_children("*", "StaticBody3D", true, false).filter(func(node): return node.is_in_group("weapon_pickups"))
	assert(pickups.size() == 5)
	var saves: Node = root.get_node("SaveManager")
	saves.save_root = "user://codex_weapon_validation"
	var occupied: Array[AABB] = []
	if DisplayServer.get_name() != "headless":
		actor.get_node("UI").hide()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = store.to_global(Vector3(0,2.15,-2.9))
		camera.look_at(store.to_global(Vector3(0,1.35,-5.2)))
		camera.current = true
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/23_company_weapon_rack.png") == OK)
	for pickup in pickups:
		assert(pickup.position.z < -5.0)
		assert(pickup.position.y > 1.0)
		assert(pickup.global_position.distance_to(store.get_node("Desk").global_position) > 2.0)
		var model: Node3D = pickup.get_child(0)
		var bounds: AABB = builder.weapon_bounds(model,store)
		assert(absf(bounds.position.y-float(pickup.get_meta("shelf_top"))-.015) < .002)
		assert(bounds.position.x >= -2.28 and bounds.end.x <= 2.28)
		assert(bounds.position.z >= -5.81 and bounds.end.z <= -4.89)
		for previous in occupied: assert(not previous.intersects(bounds))
		occupied.append(bounds)
		actor.global_position = store.to_global(Vector3(pickup.position.x,1.15,pickup.position.z+1.7))
		await physics_frame
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP*.2,pickup.global_position)
		ray.exclude = [actor.get_rid()]
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(hit.get("collider") == pickup)
		pickup.interact(actor)
		assert(actor.inventory.has_item(pickup.weapon_id))
		assert(not gear.stowed)
		assert(gear.owns(gear.selected))
		if pickup.weapon_id == "enfield": assert(saves.save_game(world,2))
	await process_frame
	assert(gear.owns(0) and gear.owns(1))
	assert(saves.save_game(world,3))
	world.queue_free()
	await process_frame
	var restored: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(restored)
	current_scene = restored
	for i in 3: await process_frame
	saves.pending_slot = 2
	saves.apply_pending(restored)
	var restored_actor: CharacterBody3D = restored.get_node("Player")
	assert(restored_actor.inventory.has_item("enfield") and not restored_actor.inventory.has_item("talwar"))
	await process_frame
	var restored_store: Node3D = restored.get_node("Settlement/CompanyArmoury")
	var remaining := restored.get_tree().get_nodes_in_group("weapon_pickups").filter(func(node): return restored_store.is_ancestor_of(node) and not node.is_queued_for_deletion())
	assert(remaining.size() == 4)
	saves.pending_slot = 3
	saves.apply_pending(restored)
	assert(restored_actor.inventory.has_item("talwar") and restored_actor.inventory.has_item("enfield"))
	for pickup in restored.get_tree().get_nodes_in_group("weapon_pickups"):
		if restored_store.is_ancestor_of(pickup): assert(pickup.is_queued_for_deletion())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(3)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(2)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	print("WEAPON STORE: PASS | unarmed start, reachable shelf, pickup, saved ownership")
	quit()
