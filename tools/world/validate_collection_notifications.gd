extends SceneTree
const Catalog = preload("res://interaction/item_catalog.gd")
var overlay: Control
var actor: CharacterBody3D
var world: Node3D

func _initialize() -> void:
	_run.call_deferred()

func clear_feed() -> void:
	overlay.rewards.clear()
	overlay.reward_icons.clear()
	overlay.pending_rewards.clear()
	overlay.reward_timer = 0.0

func expect(item_id: String, amount: int, index: int = 0) -> void:
	assert(overlay.rewards[index] == Catalog.display_name(item_id) + "  +" + str(amount), "Wrong quantity/name: " + item_id)
	assert(overlay.reward_icons[index] == Catalog.icon(item_id), "Wrong icon: " + item_id)

func spawn(path: String) -> Node3D:
	var pickup: Node3D = load(path).new()
	world.add_child(pickup)
	pickup.global_position = actor.global_position
	return pickup

func _run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	actor = world.get_node("Player")
	for frame in 12: await physics_frame
	actor.set_physics_process(false)
	overlay = actor.interaction_overlay
	# Real inventory signal -> real HUD listener -> feed, every catalog entry and fallback.
	var ids: Array = Catalog.ITEMS.keys()
	ids.append("future_collectible")
	for item in ids:
		clear_feed()
		assert(actor.inventory.add_item(item, 2))
		assert(overlay.rewards.size() == 1)
		expect(item, 2)
		assert(not actor.inventory.add_item(item, 0))
		assert(overlay.rewards.size() == 1, "Rejected grant made a notification")
	print("COLLECTION SIGNALS: PASS | %d item IDs including medkit/bandage and unknown fallback" % ids.size())
	# Consume/remove and save-state assignment must not invent collection notices.
	clear_feed()
	actor.inventory.remove_item("mango", 1)
	assert(overlay.rewards.is_empty())
	# Every real food/container collection script.
	for pair in [["mango", "res://objects/mango.gd"], ["roti", "res://objects/roti.gd"], ["water_bag", "res://objects/water_bag.gd"]]:
		clear_feed()
		var pickup := spawn(pair[1])
		pickup.interact(actor)
		assert(overlay.rewards.size() == 1, "Duplicate/missing world pickup: " + pair[0])
		expect(pair[0], 1)
		await process_frame
	# Every ammo supply variant plus future medical supplies via existing pickup mechanism.
	for item in ["paper_cartridges", "pistol_ball", "shot_charge", "arrow", "medkit"]:
		clear_feed()
		var pickup = load("res://world/suryagarh/settlements/supply_pickup.gd").new()
		pickup.item_id = item
		pickup.count = 3
		world.add_child(pickup)
		pickup.global_position = actor.global_position
		assert(pickup.interaction_icon == Catalog.icon(item))
		pickup.interact(actor)
		pickup.interact(actor)
		assert(overlay.rewards.size() == 1, "Supply collected twice")
		expect(item, 3)
		await process_frame
	# Weapon grants include their bundled ammunition, each exactly once.
	for item in ["talwar", "enfield", "bow", "pistol", "double_gun"]:
		actor.inventory.items.erase(item)
		clear_feed()
		var pickup = load("res://world/suryagarh/settlements/weapon_pickup.gd").new()
		pickup.weapon_id = item
		world.add_child(pickup)
		pickup.global_position = actor.global_position
		assert(pickup.interaction_icon == Catalog.icon(item))
		pickup.interact(actor)
		expect(item, 1)
		var bundles := {"enfield": ["paper_cartridges",24], "bow": ["arrow",24], "pistol": ["pistol_ball",30], "double_gun": ["shot_charge",16]}
		assert(overlay.rewards.size() == (2 if bundles.has(item) else 1))
		if bundles.has(item): expect(bundles[item][0], bundles[item][1], 1)
		await process_frame
	clear_feed()
	var chest := spawn("res://interaction/treasure_chest.gd")
	chest.interact(actor)
	chest.interact(actor)
	assert(overlay.rewards.size() == 3)
	expect("paper_cartridges",6,0)
	expect("pistol_ball",4,1)
	expect("rupees",26,2)
	clear_feed()
	actor.inventory.stored_water_liters = 0.0
	var pot := spawn("res://objects/water_pot.gd")
	pot.interact(actor)
	assert(overlay.rewards.size() == 1 and overlay.reward_icons[0] == "water")
	assert(actor.inventory.stored_water_liters > 0.0)
	print("COLLECTION ROUTES: PASS | mango, roti, water bag, five supplies, five weapons + bundled ammo, chest, water pot")
	# Exercise the real river fill completion on a grounded actor.
	clear_feed()
	var floor_body := StaticBody3D.new()
	world.add_child(floor_body)
	floor_body.position = Vector3(0, 99, 0)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	actor.global_position = Vector3(0, 100, 0)
	await physics_frame
	for frame in 90:
		actor.velocity = Vector3(0,-5,0)
		actor.move_and_slide()
		await physics_frame
	assert(actor.is_on_floor())
	actor.inventory.stored_water_liters = 0.0
	actor.river_water.start_action("fill")
	actor.river_water._process(1.81)
	assert(overlay.rewards.size() == 1 and overlay.reward_icons[0] == "water")
	assert(overlay.rewards[0].begins_with("Water  +") and actor.inventory.stored_water_liters > 0.0)
	print("RIVER COLLECTION: PASS | real timed fill completion, quantity and droplet")
	# Large bursts preserve order, icons and amounts across timed pages.
	clear_feed()
	for item in ids: actor.inventory.add_item(item, 1)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = Vector3(0,102,4)
		camera.look_at(actor.global_position + Vector3.UP)
		camera.make_current()
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/tmp/tlm_all_collection_burst.png") == OK)
	var seen: int = 0
	while seen < ids.size():
		assert(overlay.rewards.size() <= 5)
		for index in range(overlay.rewards.size()):
			expect(ids[seen], 1, index)
			seen += 1
		overlay._advance_reward_feed(3.01)
	assert(overlay.pending_rewards.is_empty() and overlay.reward_timer == 0.0)
	actor.inventory.add_item("mango",1)
	assert(overlay.rewards.size() == 1)
	expect("mango",1)
	print("COLLECTION BURST: PASS | all %d notices displayed in order; expiry and fresh pickup correct" % seen)
	print("COLLECTION NOTIFICATIONS: PASS")
	quit()
