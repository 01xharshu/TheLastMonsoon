extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	var actor: CharacterBody3D = world.get_node("Player")
	for frame in 12: await physics_frame
	actor.set_physics_process(false)
	var supplies: Array[Node] = get_nodes_in_group("medical_supplies")
	assert(supplies.size() == 2, "Missing building supplies")
	var pickup = supplies[0]
	var id: String = pickup.persistence_id()
	assert(not id.is_empty() and id != supplies[1].persistence_id())
	actor.global_position = pickup.global_position + Vector3(0,0,1.5)
	actor.inventory.items.erase("medkit")
	actor.inventory.items.erase("bandage")
	var overlay = actor.interaction_overlay
	overlay.rewards.clear()
	overlay.reward_icons.clear()
	overlay.pending_rewards.clear()
	overlay.reward_timer = 0.0
	overlay.set_target(pickup,0.5)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = pickup.global_position + Vector3(0.25,0.4,0.45)
		camera.look_at(pickup.global_position)
		camera.make_current()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/bandage_supply.png") == OK)
	pickup.interact(actor)
	pickup.interact(actor)
	assert(actor.inventory.get_item_count("medkit") == 1)
	assert(overlay.rewards.size() == 1 and overlay.reward_icons[0] == "medicine")
	assert(overlay.rewards[0] == "Bandage  +1")
	await process_frame
	var consumables: Node = actor.get_node("ConsumableComponent")
	actor.health = 100.0
	assert(not consumables.use_bandage())
	assert(actor.inventory.get_item_count("medkit") == 1)
	actor.take_damage(40.0)
	assert(consumables.use_bandage())
	assert(actor.health == 85.0 and not actor.inventory.has_item("medkit"))
	assert(not consumables.use_bandage())
	consumables.get_node("ItemUseAnimation").finish()
	actor.inventory.add_item("medkit",2)
	actor.health = 95.0
	assert(consumables.use_bandage() and actor.health == 100.0)
	assert(actor.inventory.get_item_count("medkit") == 1)
	consumables.get_node("ItemUseAnimation").finish()
	actor.health = 0.0
	assert(not consumables.use_bandage() and actor.inventory.get_item_count("medkit") == 1)
	actor.health = 60.0
	var ui: Node = actor.get_node("UI/HUDRoot/InventoryUI") if actor.has_node("UI/HUDRoot/InventoryUI") else null
	# Find the inventory panel by its behavior so the fixture follows authored node names.
	if ui == null:
		for node in actor.find_children("*","PanelContainer",true,false):
			if node.has_method("_refresh_inventory"): ui = node
	assert(ui != null)
	ui._refresh_inventory()
	assert(ui.bandage_label.text.contains("1") and not ui.bandage_button.disabled)
	ui.bandage_button.pressed.emit()
	assert(actor.health == 85.0 and not actor.inventory.has_item("medkit"))
	consumables.get_node("ItemUseAnimation").finish()
	actor.inventory.add_item("medkit",2)
	actor.health = 65.0
	var saves: Node = root.get_node("SaveManager")
	saves.save_root = "user://codex_medical_validation"
	assert(saves.save_game(world,1))
	var data: Dictionary = saves.read_slot(1)
	assert(data.health == 65.0 and not id in data.remaining_medical_ids)
	# Recreate a collected pickup as a fresh-load proxy: restore must remove it.
	var restored_pickup = load("res://world/suryagarh/settlements/medical_supply.gd").new()
	restored_pickup.supply_id = id
	world.add_child(restored_pickup)
	actor.health = 99.0
	actor.inventory.items.erase("medkit")
	saves.pending_slot = 1
	saves.apply_pending(world)
	assert(actor.health == 65.0 and actor.inventory.get_item_count("medkit") == 2)
	assert(restored_pickup.is_queued_for_deletion())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	print("MEDICAL SUPPLIES: PASS | two buildings, one-time icon reward, healing/cap/full/dead/empty guards, inventory button, wounds/items/pickup persistence")
	quit()
