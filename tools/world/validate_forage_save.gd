extends SceneTree
## Uses a disposable save directory, never the player's save slots.
const WORLD := "res://world/suryagarh/suryagarh_world.tscn"
var failures: Array[String] = []
var saves: Node

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func spawn(slot: int = 0) -> Node3D:
	saves.pending_slot = slot
	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	world.set_physics_process(false)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player/SurvivalComponent").set_process(false)
	world.get_node("GameTimeSystem").set_process(false)
	for i in 4: await physics_frame
	return world

func available(world: Node3D) -> Array[Node]:
	var fruit: Array[Node] = []
	for child in world.get_node("ForageGrove").get_children():
		if child is Interactable and not child.is_queued_for_deletion() and not child.collected:
			fruit.append(child)
	return fruit

func validate() -> void:
	saves = root.get_node("SaveManager")
	saves.save_root = "user://codex_forage_validation_%s" % Time.get_ticks_usec()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := await spawn()
	var player: CharacterBody3D = world.get_node("Player")
	var fruit := available(world)
	check(fruit.size() == 10, "New game must have ten collectible mangoes")
	var ids: Array[String] = []
	for item in fruit:
		check(not item.forage_id in ids and not item.forage_id.is_empty(), "Fruit IDs must be unique and stable")
		ids.append(item.forage_id)
	var picked_id: String = fruit[0].forage_id
	var eaten_id: String = fruit[1].forage_id
	player.survival.satiety = 50
	player.survival.hydration = 50
	fruit[0].interact(player)
	fruit[0].interact(player)
	fruit[1].interact(player)
	check(not player.consumables.eat_mango(), "Store recovery allowed overlapping eating")
	var pose = player.get_node("InteractionPoseComponent")
	var visual = player.get_node("VisualRoot/CharacterVisual")
	for frame in 45:
		visual._process(1.0/60.0)
		pose._process(1.0/60.0)
	check(player.consumables.eat_mango(), "Satchel eating failed")
	check(player.inventory.get_item_count("mango") == 1, "Repeated pickup duplicated inventory")
	check(player.survival.satiety == 62 and player.survival.hydration == 56, "Satchel eating did not restore nutrition")
	# Save immediately, before queue_free completes.
	check(saves.save_game(world, 1), "Could not save harvested fruit")
	var data: Dictionary = saves.read_slot(1)
	check(data.get("collected_forage_ids", []).size() == 2, "Immediate save lost pending collection")
	check(picked_id in data.get("collected_forage_ids", []) and eaten_id in data.get("collected_forage_ids", []), "Save lacks picked/eaten IDs")
	world.free()
	world = await spawn(1)
	player = world.get_node("Player")
	fruit = available(world)
	check(fruit.size() == 8, "Collected/eaten fruit reappeared after load")
	check(player.inventory.get_item_count("mango") == 1, "Stored mango did not restore")
	check(player.survival.satiety == 62 and player.survival.hydration == 56, "Saved nutrition changed")
	for item in fruit:
		check(item.forage_id != picked_id and item.forage_id != eaten_id, "Harvested ID is still available")
		check(item.interaction_available(), "Remaining fruit is unusable")
	# Renaming/repositioning model children must not affect persistence.
	var third_id: String = fruit[0].forage_id
	fruit[0].name = "MovedFruit"
	fruit[0].position += Vector3(1, 0, 1)
	fruit[0].interact(player)
	check(saves.save_game(world, 1), "Could not resave harvest history")
	check(saves.read_slot(1).collected_forage_ids.size() == 3, "Reload/resave forgot earlier fruit")
	world.free()
	world = await spawn(1)
	fruit = available(world)
	check(fruit.size() == 7, "Resave did not preserve all three harvested fruit")
	for item in fruit: check(item.forage_id != third_id, "Renamed/repositioned fruit respawned")
	# Old version-1 files must remain loadable without guessing fruit history.
	data = saves.read_slot(1)
	data.erase("collected_forage_ids")
	var file := FileAccess.open(saves.slot_path(2), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	world.free()
	world = await spawn(2)
	check(available(world).size() == 10, "Legacy save removed fruit without harvest history")
	check(world.get_node("Player").inventory.get_item_count("mango") == 2, "Legacy save lost satchel contents")
	world.free()
	# New game isolation: previous save history must not contaminate a fresh world.
	world = await spawn()
	check(available(world).size() == 10, "New game inherited harvested fruit")
	world.free()
	for slot in [1, 2]: DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	var report := {"passed": failures.is_empty(), "failures": failures, "new_game_fruit":10, "after_first_load":8, "after_resave":7, "legacy_compatible":true}
	FileAccess.open("res://docs/world/forage_save_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FORAGE SAVE / LOAD: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
