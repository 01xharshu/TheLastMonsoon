extends SceneTree
## Actual populated-world merchant acquisition and player handoff.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 120000
	var seller: Node = world.get_node_or_null("CityWeaponSeller")
	while (seller == null or not seller.configured) and Time.get_ticks_msec() < deadline:
		await process_frame
		seller = world.get_node_or_null("CityWeaponSeller")
	if seller == null or not seller.configured:
		push_error("Weapon seller did not finish configuring")
		await root.get_node("SaveManager").quit_game(1)
		return
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.global_position = seller.global_position + Vector3(0,0,2)
	actor.inventory.add_item("rupees",100)
	var money: int = actor.inventory.get_item_count("rupees")
	var index := -1
	for i in seller.STOCK.size():
		if seller.STOCK[i].id == "indian_pistol": index = i
	check(index >= 0,"Indian pistol is not listed by the merchant")
	if index >= 0:
		check(seller.request("shop",actor),"Weapon merchant did not open")
		check(seller.buy(index),"Indian pistol purchase failed")
		check(actor.inventory.has_item("indian_pistol"),"Purchased pistol missing from inventory")
		check(actor.inventory.get_item_count("rupees") == money-int(seller.STOCK[index].price),"Purchase charged incorrect amount")
		check(not seller.buy(index),"Unique pistol could be purchased twice")
		seller.close_shop()
		var gear: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
		gear.select_weapon(6)
		check(gear.selected == 6 and gear.indian_pistol_hand.visible,"Purchased pistol could not be equipped")
	check(not actor.get_meta("weapon_shop_open",false),"Shop did not release control")
	print("INDIAN PISTOL SHOP ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	await root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
