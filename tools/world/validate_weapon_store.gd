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
	assert(not actor.inventory.has_item("talwar") and not actor.inventory.has_item("enfield"))
	assert(not gear.talwar_hand.visible and not gear.talwar_waist.visible)
	assert(not gear.enfield_hand.visible and not gear.enfield_back.visible)
	gear.toggle_stowed()
	assert(gear.stowed)
	gear.select_weapon(1)
	assert(gear.selected == 0)
	var pickups := store.find_children("*", "StaticBody3D", true, false).filter(func(node): return node.is_in_group("weapon_pickups"))
	assert(pickups.size() == 2)
	for pickup in pickups:
		assert(pickup.position.z < -5.0)
		assert(pickup.position.y > 1.0)
		assert(pickup.global_position.distance_to(store.get_node("Desk").global_position) > 2.0)
		actor.global_position = pickup.global_position + Vector3(0, -.25, 1.7)
		pickup.interact(actor)
		assert(actor.inventory.has_item(pickup.weapon_id))
		assert(not gear.stowed)
		assert(gear.owns(gear.selected))
	await process_frame
	assert(gear.talwar_hand.visible or gear.talwar_waist.visible)
	assert(gear.enfield_hand.visible or gear.enfield_back.visible)
	print("WEAPON STORE: PASS | unarmed start, guarded selection, shelf pickup, equipment")
	quit()
