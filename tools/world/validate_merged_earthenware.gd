extends SceneTree
## Damage integration uses the real water source and retained MPFB Player.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(100, 0, 100)
	var inventory: Node = player.get_node("InventoryComponent")
	inventory.add_item("water_bag", 1)
	inventory.stored_water_liters = 0
	var pot: Node = load("res://objects/water_pot.tscn").instantiate()
	world.add_child(pot)
	await process_frame
	check(pot.breakage != null, "earthen source installs its fracture component")
	if pot.breakage == null:
		root.get_node("SaveManager").quit_game(1)
		return
	check(not pot.breakage.is_broken and pot.collision_layer != 0,
		"undamaged earthen pot remains intact and solid")
	pot.interact(player)
	check(inventory.stored_water_liters > 0, "intact pot supplies water through existing interaction")
	inventory.stored_water_liters = 0
	var component: Node = pot.breakage
	pot.take_damage(38)
	for frame in 50:
		await physics_frame
	check(component.is_broken and pot.water_available_per_fill == 0,
		"damage fractures pot and retires its water source")
	check(pot.collision_layer == 0 and component.collision_layer == 0,
		"broken pot and fragment owner release blocking collision")
	pot.interact(player)
	check(inventory.stored_water_liters == 0, "broken pot cannot refill water")
	var fragments: int = component.fragments.size()
	pot.take_damage(38)
	await process_frame
	check(fragments > 0 and component.fragments.size() == fragments,
		"repeated damage does not duplicate fracture pieces")
	check(not component.is_physics_processing(), "broken pot stops impact polling")
	# The village masonry well uses this source script without an EarthenShell.
	var masonry: Node = load("res://objects/water_pot.gd").new()
	world.add_child(masonry)
	masonry.take_damage(60)
	await process_frame
	check(masonry.breakage == null and masonry.water_available_per_fill > 0,
		"non-earthen source retains its water and does not fracture")
	masonry.interact(player)
	check(inventory.stored_water_liters > 0, "protected source still fills the original water bag")
	for index in 13:
		var extra: Node3D = load("res://objects/water_pot.tscn").instantiate()
		extra.position = Vector3(index * 3, 0, -10)
		world.add_child(extra)
		extra.take_damage(38)
	for frame in 50:
		await physics_frame
	var retained := 0
	for reference in component.debris_sets:
		if is_instance_valid(reference.get_ref()):
			retained += 1
	check(retained == 12, "fourteen fractures retain at most twelve debris sets")
	print("MERGED EARTHENWARE ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	world.queue_free()
	await process_frame
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
