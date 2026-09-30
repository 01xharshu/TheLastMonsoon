extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: return
	failed = true
	push_error(message)
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var police: Node3D = world.get_node("Settlement/DistrictPolice")
	for i in 5: await physics_frame
	check(police.width >= 38 and police.depth >= 36, "Police expansion absent")
	check(int(police.get_meta("cellar_excavated_vertices", 0)) > 0, "Resident terrain not excavated for lower detention")
	# Traverse the real capsule through the descending stairs and back up.
	player.global_position = police.to_global(Vector3(12,0.95,9))
	player.velocity = Vector3.ZERO
	for i in 295:
		player.velocity = Vector3(0,player.velocity.y-9.8/60,-4)
		player.move_and_slide()
		await physics_frame
	var local: Vector3 = police.to_local(player.global_position)
	check(local.y < -2.7 and local.z < -8, "Cellar descent blocked: " + str(local))
	for i in 360:
		player.velocity = Vector3(0,player.velocity.y-9.8/60,4)
		player.move_and_slide()
		await physics_frame
	local = police.to_local(player.global_position)
	check(local.y > 0.7 and local.z > 8, "Cellar ascent blocked: " + str(local))
	# The new side offices must be entered through their doorway, not a teleport.
	player.global_position = police.to_global(Vector3(-3,0.95,4))
	player.velocity = Vector3.ZERO
	for i in 100:
		player.velocity = Vector3(-4,player.velocity.y-9.8/60,0)
		player.move_and_slide()
		await physics_frame
	check(police.to_local(player.global_position).x < -7.5, "New office doorway blocks the player: " + str(police.to_local(player.global_position)))
	var supplies: Array = get_nodes_in_group("ammunition_pickups")
	check(supplies.size() == 6, "Both gun locations need all three ammunition supplies")
	for pickup in supplies:
		check(pickup.find_children("*","MeshInstance3D",true,false).size() >= 9, "Ammunition supply lacks 3D meshes")
		player.global_position = pickup.global_position + Vector3(0,0,1)
		var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.55,pickup.global_position+Vector3.UP*0.06)
		ray.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider") == pickup, "Ammo supply is hidden behind furniture collision")
		var before: int = player.inventory.get_item_count(pickup.item_id)
		pickup.interact(player)
		check(player.inventory.get_item_count(pickup.item_id) == before + pickup.count, "Ammunition pickup did not award reserve")
		pickup.interact(player)
		check(player.inventory.get_item_count(pickup.item_id) == before + pickup.count, "Ammunition pickup awarded twice")
	await process_frame
	var gun: Node3D = world.get_node("Settlement/CompanyArmoury/StoreWeapon_enfield")
	player.global_position = gun.global_position + Vector3(0,0,1)
	var spare_before: int = player.inventory.get_item_count("paper_cartridges")
	gun.interact(player)
	check(player.inventory.get_item_count("paper_cartridges") == spare_before+24, "New rifle did not grant 24 spare cartridges")
	check(player.get_node("RifleCombat").rounds == 1, "New rifle must have one loaded chamber")
	var saves: Node = root.get_node("SaveManager")
	saves.save_root = "user://codex_police_ammo_test"
	player.get_node("RifleCombat").rounds = 0
	player.get_node("RifleCombat").loaded = false
	player.inventory.remove_item("paper_cartridges",1)
	player.get_node("RifleCombat").pending_rounds = 1
	player.get_node("RifleCombat").reload_remaining = 2.5
	var reserve_saved: int = player.inventory.get_item_count("paper_cartridges")
	check(saves.save_game(world, 1), "Could not save ammunition state")
	world.queue_free()
	await process_frame
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 3: await process_frame
	world.get_node("Player/RifleCombat").set_process(false)
	saves.pending_slot = 1
	saves.apply_pending(world)
	await process_frame
	check(get_nodes_in_group("ammunition_pickups").is_empty(), "Collected ammunition respawned on load")
	check(world.get_node("Player/RifleCombat").rounds == 0, "Empty rifle became loaded on save restoration")
	check(world.get_node("Player/RifleCombat").pending_rounds == 1 and is_equal_approx(world.get_node("Player/RifleCombat").reload_remaining,2.5), "In-progress reload lost its reserved cartridge")
	check(world.get_node("Player/InventoryComponent").get_item_count("paper_cartridges") == reserve_saved,"Reserve changed during reload save restoration")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	print("POLICE AMMUNITION ", "FAIL" if failed else "PASS", " | cellar traversal, 3D supplies, reserves, save restoration")
	quit(1 if failed else 0)
