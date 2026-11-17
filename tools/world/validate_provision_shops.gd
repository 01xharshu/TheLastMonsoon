extends SceneTree
## Run against the populated world. Caller supplies and cleans the temporary directory.
const WORLD = "res://world/suryagarh/suryagarh_world.tscn"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(result: bool, message: String) -> bool:
	if not result:
		failures += 1
		push_error(message)
	return result

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)

func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(file)

func run() -> void:
	var directory := OS.get_environment("TLM_SHOP_TEST_DIR")
	if directory.is_empty():
		push_error("Supply an OS temporary TLM_SHOP_TEST_DIR")
		quit(1)
		return
	var saves := root.get_node("SaveManager")
	saves.save_root = directory
	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	for i in 16:
		await process_frame
	var player := world.get_node("Player") as CharacterBody3D
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	var capsule_half := capsule.height*.5
	player.inventory.add_item("rupees",100)
	var map := player.get_node("UI/WorldMap")
	map.refresh_sites()
	check(map.site_kind("Civilian hospital") == "clinic" and map.site_kind("City market") == "trade" and map.site_kind("Bhairavpur Potter workshop") == "workshop", "Building icons collide")
	for id in ["VillageShop","CityShop"]:
		var label := "Bhairavpur provision shop" if id == "VillageShop" else "Suryagarh provision shop"
		check(map.sites.has(label) and map.site_kind(label) == "shop" and map.icons.shop != null, "Missing shop map marker: "+id)
		var shop := world.get_node("ProvisionShops/"+id) as Node3D
		var gate := shop.get_node("SideGateFrame/ProvisionGate") as Interactable
		var counter := shop.get_node("LedgerService") as Interactable
		var storage := shop.get_node("Building/ShopStorage")
		check(storage.find_children("DrawerFront*","Node3D",false,false).size() == 6, "Missing drawer cabinet: "+id)
		check(storage.find_children("*","StaticBody3D",true,false).size() >= 8, "Missing physical storage props: "+id)
		# Start on the lane outside the veranda and walk its length to the gate.
		var approach := shop.to_global(Vector3(4.9,0,4.25))
		var support_query := PhysicsRayQueryParameters3D.create(approach+Vector3.UP*1.75,approach-Vector3.UP*2)
		support_query.exclude = [player.get_rid()]
		var support := shop.get_world_3d().direct_space_state.intersect_ray(support_query)
		if not check(not support.is_empty(), "No terrain support on the approach: "+id):
			continue
		player.global_position = support.position+Vector3.UP*(capsule_half+.04)
		player.velocity = Vector3.ZERO
		print("SHOP APPROACH | ",id," | ",shop.to_local(player.global_position))
		for i in 5:
			await physics_frame
		var heading := -shop.global_basis.z
		if id == "VillageShop":
			player.get_node("CameraPivot").global_rotation.y = atan2(-heading.x,-heading.z)
			await capture(directory+"/veranda.png")
		player.get_node("CameraPivot").global_rotation.y = atan2(-heading.x,-heading.z)
		Input.action_press("move_forward")
		for i in 100:
			await physics_frame
			if shop.to_local(player.global_position).z < .35:
				break
		Input.action_release("move_forward")
		await physics_frame
		var at := shop.to_local(player.global_position)
		check(at.z < .55 and at.x > 4.3 and absf(at.y-capsule_half-.16) < .14, "Walk along covered side failed at %s: %s" % [id,at])
		var inward := -shop.global_basis.x
		player.get_node("VisualRoot").global_rotation.y = atan2(inward.x,inward.z)
		var ray := PhysicsRayQueryParameters3D.create(shop.to_global(Vector3(4.9,4,1)),shop.to_global(Vector3(4.9,1,1)))
		check(not shop.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Veranda has no solid overhead cover: "+id)
		check(gate.opened and not gate.interaction_available(), "Shop gate is not a public passage: "+id)
		# Old saves can contain a closed, manually locked shop gate.
		var saved_gate := {String(world.get_path_to(gate)): {"opened": false, "manual_locked": true, "swing_direction": 1.0}}
		saves._restore_door_states(world,saved_gate)
		check(gate.opened and not gate.manual_locked and not gate.locked, "Old gate state blocked public entry: "+id)
		player.get_node("CameraPivot").global_rotation.y = atan2(-inward.x,-inward.z)
		Input.action_press("move_forward")
		for i in 150:
			await physics_frame
			if shop.to_local(player.global_position).x < 1.05:
				break
		Input.action_release("move_forward")
		await physics_frame
		check(player._find_interactable() == counter,"Keeper is unreachable from the customer side: "+id)
		if id == "VillageShop":
			await capture(directory+"/counter.png")
		player._try_primary_interaction()
		for i in 100:
			await process_frame
			if paused:
				break
		if not check(paused and is_instance_valid(counter.view), "Shopkeeper did not present the book: "+id):
			continue
		check(counter.keeper.get_meta("hand_contact_l",INF) < .08, "Keeper missed the ledger: "+id)
		var inventory: Node = player.inventory
		var original: int = inventory.get_item_count("rupees")
		var old_bandages: int = inventory.get_item_count("bandage")
		press(KEY_DOWN)
		press(KEY_DOWN)
		press(KEY_ENTER)
		check(counter.view.selected == 2 and inventory.get_item_count("rupees") == original-6 and inventory.get_item_count("bandage") == old_bandages+1 and counter.view.balance == original-6, "Bandage purchase failed: "+id)
		await capture(directory+"/"+id+".png")
		var remaining: int = inventory.get_item_count("rupees")
		inventory.remove_item("rupees",remaining)
		press(KEY_ENTER)
		check(inventory.get_item_count("bandage") == old_bandages+1 and counter.view.receipt == "Insufficient rupees.", "Unaffordable item was not rejected")
		inventory.add_item("rupees",remaining)
		var old_arrows: int = inventory.get_item_count("arrow")
		press(KEY_RIGHT)
		check(counter.view.turning and counter.view.selected == 2, "Forward sheet did not start: "+id)
		press(KEY_ENTER)
		check(inventory.get_item_count("rupees") == remaining, "Enter charged during the page turn")
		await create_timer(.14).timeout
		if id == "VillageShop":
			await capture(directory+"/page-turn.png")
		await create_timer(.65).timeout
		check(not counter.view.turning and counter.view.selected == 4, "Second spread failed to settle: "+id)
		press(KEY_DOWN)
		press(KEY_ENTER)
		check(inventory.get_item_count("arrow") == old_arrows+6 and counter.view.balance == remaining-8, "Second spread bundle purchase failed: "+id)
		if id == "VillageShop":
			await capture(directory+"/trail-stock.png")
		press(KEY_LEFT)
		await create_timer(.7).timeout
		check(not counter.view.turning and counter.view.selected == 0, "Reverse page turn failed: "+id)
		press(KEY_RIGHT)
		press(KEY_ESCAPE)
		check(not paused and not player.get_meta("provision_shop_open",false) and not world.get_node("GameMenu").overlay.visible, "Escape did not return to the shop")
		if id == "VillageShop":
			var outward := shop.global_basis.x
			player.get_node("CameraPivot").global_rotation.y = atan2(-outward.x,-outward.z)
			Input.action_press("move_forward")
			for i in 160:
				await physics_frame
				if shop.to_local(player.global_position).x > 4.65:
					break
			Input.action_release("move_forward")
			check(shop.to_local(player.global_position).x > 4.65, "Player could not walk back out of the gate")
		print("SHOP CHECK | ",id," | keeper gap ",counter.keeper.get_meta("hand_contact_l",INF))

	var menu := world.get_node("GameMenu")
	menu.open()
	check(map.shop_sites.size() == 2 and map.icons.workshop != null, "Map did not publish both shops and the workshop icon")
	for label in map.shop_sites:
		map.select_point(map.project(map.sites[label]))
		check(map.selected_site == label and map.waypoint == map.sites[label], "Shop pin did not set its approach waypoint")
		map.zoom = 1.0
		map.map_center = Vector2.ZERO
	await capture(directory+"/field-map.png")
	menu.close()
	var money: int = player.inventory.get_item_count("rupees")
	var bandages: int = player.inventory.get_item_count("bandage")
	var arrows: int = player.inventory.get_item_count("arrow")
	if check(saves.save_game(world,1) and saves.start_loaded_game(1),"Shop save or Continue failed"):
		for i in 50:
			await process_frame
			if is_instance_valid(current_scene) and current_scene != world and saves.pending_slot == -1:
				break
		if check(is_instance_valid(current_scene) and current_scene != world and saves.pending_slot == -1,"Continue never loaded the shop save"):
			player = current_scene.get_node("Player")
			check(current_scene.get_node("ProvisionShops/CityShop/SideGateFrame/ProvisionGate").opened, "Continue lost the shop gate position")
			check(player.inventory.get_item_count("rupees") == money and player.inventory.get_item_count("bandage") == bandages and player.inventory.get_item_count("arrow") == arrows,"Continue lost balance or bought supplies")
	print("PROVISION SHOPS | ", "PASS" if failures == 0 else "%d failures" % failures)
	await saves.quit_game(1 if failures else 0)
