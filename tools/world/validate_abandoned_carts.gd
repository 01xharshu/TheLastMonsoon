extends SceneTree

const Startup = preload("res://systems/world_startup.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(valid: bool, label: String) -> void:
	checks += 1
	if not valid:
		failures.append(label)
		push_error(label)

func run() -> void:
	var folder := OS.get_environment("TLM_ACTIVITY_REVIEW")
	check(not folder.is_empty() and OS.get_user_data_dir() == OS.get_environment("TLM_EXPECT_USER_DATA"), "disposable saves")
	if not failures.is_empty(): quit(2); return
	var saves := root.get_node("SaveManager")
	saves.save_root = folder
	var loaded := "--load" in OS.get_cmdline_user_args()
	var session := Startup.start(self)
	paused = true
	if loaded:
		if not saves.start_loaded_game(1): quit(2); return
	else:
		saves.start_new_game()
	paused = true
	await scene_changed
	var world := current_scene as Node3D
	while not session.tasks.is_empty() or saves.pending_slot >= 0: await process_frame
	Startup.close(session)
	world.show()
	var player := world.get_node("Player") as CharacterBody3D
	var inventory := player.get_node("InventoryComponent")
	var wrecks = load("res://world/suryagarh/abandoned_carts.gd")
	var salvage = load("res://world/suryagarh/cart_salvage.gd")
	var group := world.get_node_or_null("AbandonedCarts") as Node3D
	check(group != null and group.get_child_count() == 3, "three isolated roadside wrecks")
	if group == null or group.get_child_count() == 0: quit(1); return
	var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
	var cache: Interactable = group.get_child(0).get_node("CargoBox")
	for site in group.get_children():
		var point: Vector3 = site.global_position
		print("CART_SITE ", site.name, " ", point)
		check(layout.road_distance(point.x, point.z) >= 2.95, "wreck leaves room beside it on the road: " + str(site.name))
		check(wrecks.isolated(layout, Vector2(point.x, point.z)), "wreck clear of landmarks and busy plots")
		check(site.has_node("DisusedCartTrack"), "wreck rests on a disused track")
		var lane: Vector3 = site.get_meta("road_center")
		check(absf(lane.y - point.y) <= .55, "wreck sits at roadbed height")
		var space := world.get_world_3d().direct_space_state
		var clear := true
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.1, 1.5, 7.0) if site.name == &"NorthTrunk" else Vector3(7.0, 1.5, 2.1)
		var corridor := PhysicsShapeQueryParameters3D.new()
		corridor.shape = shape
		corridor.transform = Transform3D(Basis.IDENTITY, lane + Vector3.UP * .85)
		for hit in space.intersect_shape(corridor, 32):
			if site.is_ancestor_of(hit.collider): clear = false
		check(clear, "center travel strip stays clear of wreck collision")
		var grounded: Dictionary = wrecks.support(world.get_world_3d().direct_space_state, point)
		check(not grounded.is_empty() and grounded.position.distance_to(point) < .025, "wreck has terrain support")
	if loaded:
		var disk: Dictionary = saves.read_slot(1)
		check(cache.opened and not cache.interaction_available(), "Continue preserves searched cart")
		check(is_equal_approx(cache.lid.rotation.x, 1.15), "Continue restores opened crate lid")
		check(inventory.items == disk.items, "Continue preserves the loot and coins in inventory")
		var before: Dictionary = inventory.items.duplicate()
		player.global_position = cache.global_position
		cache.interact(player)
		check(inventory.items == before, "reloaded cache cannot pay twice")
	else:
		var random := RandomNumberGenerator.new()
		random.seed = 736
		var kinds := {}
		for i in 80:
			for item in salvage.roll(random): kinds[item] = true
		for item in ["roti", "mango", "rupees", "salvaged_brass", "salvaged_cloth"]:
			check(kinds.has(item), "roll supports " + item)
		var before: Dictionary = inventory.items.duplicate()
		player.global_position = cache.global_position + Vector3.RIGHT * 8
		cache.interact(player)
		check(inventory.items == before and not cache.opened, "cache requires nearby Arjun")
		player.global_position = cache.global_position + Vector3.BACK
		cache.interact(player)
		check(cache.opened and inventory.items != before, "search transfers loot to player")
		before = inventory.items.duplicate()
		cache.interact(player)
		check(inventory.items == before, "cache cannot pay twice")
		var merchant: Node
		for service in get_nodes_in_group("household_role_services"):
			if service.role == "merchant": merchant = service; break
		check(merchant != null, "existing merchant available for salvage")
		if merchant != null:
			world.get_node("GameTimeSystem").current_hour = 11
			merchant.person.set_meta("household_action", "work")
			player.global_position = merchant.global_position + Vector3.BACK
			inventory.add_item("salvaged_brass", 1)
			var brass: int = inventory.get_item_count("salvaged_brass")
			var money: int = inventory.get_item_count("rupees")
			merchant.has_secondary_interaction()
			check(merchant.secondary_interaction_text.contains("Brass fittings"), "merchant offers salvage sale")
			merchant.secondary_interact(player)
			check(inventory.get_item_count("rupees") == money + 5 and inventory.get_item_count("salvaged_brass") == brass - 1, "merchant exchanges one fitting for five rupees")
		player.set_meta("story_cinematic", false)
		check(saves.save_game(world, 1), "writes real save after search")
	if not loaded and DisplayServer.get_name() != "headless":
		cache.restore_opened()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.make_current()
		camera.fov = 55
		player.hide()
		for layer in world.find_children("*", "CanvasLayer", true, false):
			layer.hide()
		world.get_node("GameTimeSystem").total_game_minutes = 660.0
		world.get_node("Sun")._update_day_night_lighting()
		for site in group.get_children():
			camera.global_position = site.to_global(Vector3(4.2, 2.1, -4.9))
			camera.look_at(site.global_position + Vector3.UP * .65)
			for frame in 4: await process_frame
			RenderingServer.force_draw(false)
			var preview := root.get_texture().get_image()
			check(preview.get_pixel(preview.get_width() / 2, preview.get_height() / 2).get_luminance() > .012,
				"native review is visible at " + str(site.name))
			preview.save_png(folder.path_join(str(site.name) + ".png"))
	print("ABANDONED CARTS ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "continue": loaded}))
	saves.quit_game(0 if failures.is_empty() else 1)
