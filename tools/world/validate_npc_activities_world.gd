extends SceneTree
const Startup=preload("res://systems/world_startup.gd")
var issues: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:issues.append(label);push_error(label)
func ready_world(saves: Node, loaded: bool) -> Node3D:
	var session:=Startup.start(self);paused=true
	if loaded:
		if not saves.start_loaded_game(1):check(false,"load real saved slot");return null
		paused=true
	else:saves.start_new_game()
	await scene_changed
	var world: Node3D=current_scene
	while not session.tasks.is_empty():await process_frame
	while saves.pending_slot>=0:await process_frame
	world.show();Startup.close(session);paused=false
	var opening:=world.get_node_or_null("OpeningSequence")
	if opening!=null:
		var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
		opening._input(event);await process_frame;opening._input(event)
		while is_instance_valid(opening) and opening.state!="done":await process_frame
	var clock:=world.get_node("GameTimeSystem");clock.clock_paused=true;clock.current_hour=9
	var jobs:=world.get_node("NamedOccupations")
	while jobs.workers.size()<3:jobs._process(1.0);await process_frame
	jobs.set_physics_process(false)
	var community:=world.get_node("StoryCommunity")
	while community.residents.size()<8:await process_frame
	for person in community.residents:
		var lesson: Node=person.get_node_or_null("CollegeActivity")
		if lesson!=null:lesson.set_process(false)
	return world

func run() -> void:
	check(OS.get_user_data_dir()==OS.get_environment("TLM_EXPECT_USER_DATA"),"isolated real saves")
	var saves:=root.get_node("SaveManager");saves.save_root=OS.get_environment("TLM_ACTIVITY_REVIEW")
	saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.options.vsync=false;saves.apply_options()
	var loaded: bool="--load" in OS.get_cmdline_user_args()
	var world:=await ready_world(saves,loaded)
	var cart_maker: Node3D = world.get_node("NamedOccupations").workers[0]
	check(cart_maker.outfit_correctives != null and is_equal_approx(cart_maker.seat_height, .45),
		"cart maker loads the fitted repair outfit and supported seat")
	if loaded:
		var bank: Node = world.get_node("BankService")
		check(bank.balance_paise == 10005 and bank.interest_earned_paise == 5, "bank account and interest restored on Continue")
		var visitor_data: Array = saves.read_slot(1).get("bank_account", {}).get("visitors", [])
		check(visitor_data.size() == 2, "both customer accounts saved")
		for index in mini(visitor_data.size(), bank.customers.size()):
			check(bank.customers[index].wallet == int(visitor_data[index].wallet) and bank.customers[index].account == int(visitor_data[index].account), "customer account restored")
		var disk: Dictionary=saves.read_slot(1)
		var expected: Dictionary=disk.get("npc_activities",{}).get("NamedOccupations",{})
		var actual: Dictionary=world.get_node("NamedOccupations").export_state()
		print("ACTIVITY_CONTINUE ",JSON.stringify({"expected":expected,"actual":actual}))
		for label in ["CartMaker","Milkman","Potter"]:
			check(absf(float(actual[label].elapsed)-float(expected[label].elapsed))<.2,"fresh Continue restores "+label+" phase")
			check(absf(float(actual[label].travel)-float(expected[label].travel))<.05,"fresh Continue restores "+label+" cart position")
		var lessons:=0
		for person in world.get_node("StoryCommunity").residents:
			var lesson: Node=person.get_node_or_null("CollegeActivity")
			if lesson!=null:check(lesson.elapsed>=17.3,"late-spawn Continue study phase");lessons+=1
		check(lessons==4,"Continue keeps four academics")
		print("NPC ACTIVITIES ",JSON.stringify({"passed":issues.is_empty(),"checks":checks,"issues":issues,"fresh_continue":true}))
		saves.quit_game(0 if issues.is_empty() else 1);return

	var jobs: Node=world.get_node("NamedOccupations")
	check(jobs.workers.size()==3,"all named workers in actual New Journey")
	check(world.has_node("CivilianAwareness"),"actual world awareness owner")
	var encounter: Node=world.get_node("CombatEncounters")
	encounter.set_physics_process(false);encounter.set_process(false)
	var defender: Node3D=jobs.workers[0];var enemy: Node3D=encounter.aggressor
	var defender_transform:=defender.global_transform;var enemy_transform:=enemy.global_transform
	var defender_health: float=defender.get_node("Vitality").health;var enemy_health: float=enemy.get_node("Vitality").health
	enemy.global_position=defender.global_position-defender.global_basis.z*.75;enemy.body_collider.force_update_transform()
	defender.get_node("Vitality").receive_hit(2.0,enemy,"punch")
	var reaction: Node=defender.get_node("CivilianReaction");reaction.set_physics_process(false)
	var motion: Node=defender.get_node("CombatMotion");motion.set_process(false)
	for frame in 210:
		reaction._physics_process(1.0/60.0);motion.set_process(false);motion._process(1.0/60.0)
		enemy.get_node("Vitality")._physics_process(0)
		if frame%3==0:await physics_frame
	check(enemy.get_node("Vitality").health<enemy_health,"guarded civilian counterstrike makes actual contact")
	check(enemy.get_meta("last_attacker",null)==defender,"counterstrike preserves attacker identity")
	reaction.finish();reaction.set_physics_process(false);motion.state="";motion.set_process(false);defender.animation_tree.set("parameters/combat/blend_amount",0.0)
	defender.global_transform=defender_transform;enemy.global_transform=enemy_transform;defender.body_collider.force_update_transform();enemy.body_collider.force_update_transform()
	defender.get_node("Vitality").health=defender_health;enemy.get_node("Vitality").health=enemy_health
	var river: Node=get_first_node_in_group("village_river_routine")
	check(world.get_node("CivilianAwareness").activity_observers.has(river),"actual river group receives civilian threat events")
	check(river.has_node("RiverAccessFootpath"),"actual world river path")
	check(river.get_node("RiverAccessFootpath").get_meta("grass_cleared",false),"actual saved grass cleared along footpath")
	for record in jobs.records:
		for tick in 90:jobs.tick_worker(record,1.0/30.0)
		check(record.actor.has_node("CivilianReaction"),"work interruption on "+str(record.actor.name))
	var college: Node=world.get_node("StoryCommunity")
	var academic_count:=0
	for person in college.residents:
		var lesson: Node=person.get_node_or_null("CollegeActivity")
		if lesson==null:continue
		check(person.get_meta("occupation_fabric_role", "")==person.get_meta("world_role"),"academic receives its role's fabric")
		var garment_count:=0
		var textured_body:=false
		for part: MeshInstance3D in person.find_children("*", "MeshInstance3D", true, false):
			var label:=str(part.name).to_lower().replace("_", " ")
			if (label.begins_with("activity cotton shirt") or label.begins_with("activity cotton trousers")) and part.get_surface_override_material(0)!=null: garment_count+=1
			if "complete makehuman body" in label:
				var skin:=part.get_surface_override_material(0) as StandardMaterial3D
				textured_body=skin!=null and skin.albedo_texture!=null
		check(garment_count==2,"academic has two individual garment materials")
		check(textured_body,"academic retains textured full body")
		lesson.elapsed=17.3+academic_count;lesson.tick(.1);academic_count+=1
	check(academic_count==4,"existing college residents integrated")
	var bank: Node = world.get_node("BankService")
	var player: CharacterBody3D = world.get_node("Player")
	var old_position := player.global_position
	player.global_position = bank.prompt.global_position + Vector3(0, -.9, 1.25)
	player.visual_root.global_rotation.y = PI
	for frame in 3: await physics_frame
	var selected: Interactable = player._find_interactable()
	check(selected == bank.prompt, "bank clerk is reachable through normal interaction selection")
	player.inventory.add_item("rupees", 110)
	var money_before: int = player.inventory.get_item_count("rupees")
	if selected == bank.prompt:
		player._try_primary_interaction()
	check(bank.panel.visible, "bank opens through its clerk")
	if DisplayServer.get_name() != "headless":
		for frame in 4: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(OS.get_environment("TLM_ACTIVITY_REVIEW").path_join("BankPanel.png"))
	bank.amount.value = 100
	bank.teller.set_meta("knocked_out", true)
	bank.deposit()
	check(bank.balance_paise == 0 and player.inventory.get_item_count("rupees") == money_before, "unavailable teller cannot accept a deposit")
	bank.teller.set_meta("knocked_out", false)
	bank.deposit()
	check(bank.balance_paise == 10000 and player.inventory.get_item_count("rupees") == money_before - 100, "deposit transfers carried rupees")
	bank.amount.value = 10
	bank.withdraw()
	check(bank.balance_paise == 9000 and player.inventory.get_item_count("rupees") == money_before - 90, "withdraw transfers bank balance")
	bank.close_bank()
	var shop: Node3D = world.get_node("CityWeaponSeller")
	player.global_position = shop.global_position + Vector3(2, 0, 1)
	var charges_before: int = player.inventory.get_item_count("shot_charge")
	check(shop.request("shop", player), "open merchant with withdrawn money")
	check(shop.buy(6), "purchase ammunition with withdrawn money")
	check(player.inventory.get_item_count("shot_charge") == charges_before + 8 and player.inventory.get_item_count("rupees") == money_before - 100, "merchant takes carried rupees and provides goods")
	shop.close_shop()
	player.global_position = bank.prompt.global_position + Vector3(0, -.9, 1.25)
	check(bank.request("bank", player), "return to bank after shopping")
	bank.amount.value = 10
	bank.deposit()
	bank.close_bank()
	world.get_node("GameTimeSystem").total_game_minutes += 1440
	bank.accrue()
	check(bank.balance_paise == 10005 and bank.interest_earned_paise == 5, "interest accrues after one game day")
	var clock: Node = world.get_node("GameTimeSystem")
	var original_minutes: float = clock.total_game_minutes
	var account: Node = load("res://world/suryagarh/settlements/bank_service.gd").new()
	account.clock = clock
	account.configured = true
	account.balance_paise = 1000
	account.last_day = account.current_day()
	clock.total_game_minutes += 100 * 1440
	account.accrue()
	check(account.balance_paise == 1051 and account.interest_remainder == 2360, "small balances compound with fractional interest")
	clock.total_game_minutes -= 1440
	account.accrue()
	clock.total_game_minutes += 1440
	account.accrue()
	check(account.balance_paise == 1051, "clock rewind cannot repeat accrued interest")
	account.free()
	clock.total_game_minutes = original_minutes
	var customer_starts := []
	var visitor_money := []
	for customer in bank.customers:
		customer_starts.append(customer.actor.global_position)
		visitor_money.append(customer.wallet + customer.account)
	var customer_progress := [0.0, 0.0]
	for tick in 600:
		bank._physics_process(1.0 / 30.0)
		if tick % 3 == 0: await physics_frame
		for index in bank.customers.size():
			customer_progress[index] = maxf(customer_progress[index], bank.customers[index].actor.global_position.distance_to(customer_starts[index]))
	print("BANK_CUSTOMER_PROGRESS ",customer_progress)
	check(bank.customers.any(func(visitor): return visitor.account > 0), "customer deposits money at the counter")
	for index in bank.customers.size():
		check(customer_progress[index] > .2,
			"bank customer reaches the service area")
		check(bank.customers[index].wallet + bank.customers[index].account == visitor_money[index],
			"customer deposits conserve money")
	player.global_position = old_position
	var before: Dictionary=jobs.export_state()
	check(saves.save_game(world,1),"actual disk save")
	var disk: Dictionary=saves.read_slot(1)
	check(disk.get("npc_activities",{}).has("NamedOccupations"),"disk has independent workplace identities")

	print("NPC ACTIVITIES ",JSON.stringify({"passed":issues.is_empty(),"checks":checks,"issues":issues,"actual_world_save":true}))
	saves.quit_game(0 if issues.is_empty() else 1)
