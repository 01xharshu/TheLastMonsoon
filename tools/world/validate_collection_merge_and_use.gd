extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var stage := Node3D.new()
	root.add_child(stage)
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(time)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.set_physics_process(false)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.18,0.19,0.18)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.8,0.8,0.8)
	environment.environment = settings
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2,1.7,2.6)
	camera.look_at(Vector3(0,1.2,0))
	camera.make_current()
	for frame in 6: await process_frame
	var overlay = actor.interaction_overlay
	overlay.set_physics_process(false)
	overlay.rewards.clear()
	overlay.reward_icons.clear()
	overlay.pending_rewards.clear()
	overlay.reward_timer = 0.0
	for amount in [1,1,1]:
		actor.inventory.add_item("mango",amount)
		assert(overlay.rewards.size() == 1)
	assert(overlay.rewards[0] == "Mango  +3")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/collection_merged.png") == OK)
	actor.inventory.add_item("paper_cartridges",6)
	actor.inventory.add_item("paper_cartridges",4)
	assert(overlay.rewards.size() == 2 and overlay.rewards[1] == "Paper Cartridges  +10")
	for item in ["roti","pistol_ball","shot_charge","medkit"]: actor.inventory.add_item(item,1)
	actor.inventory.add_item("medkit",2)
	assert(overlay.pending_rewards.size() == 1 and overlay.pending_rewards[0].amount == 3)
	actor.inventory.add_item("mango",1)
	assert(overlay.rewards.size() == 5 and overlay.rewards[0] == "Mango  +4")
	overlay._advance_reward_feed(3.01)
	assert(overlay.rewards.size() == 1 and overlay.rewards[0] == "Bandage  +3")
	overlay._advance_reward_feed(3.01)
	actor.inventory.add_item("mango",1)
	assert(overlay.rewards.size() == 1 and overlay.rewards[0] == "Mango  +1")
	print("COLLECTION MERGE: PASS | +1/+2/+3, mixed amounts, active/queued merges, expiry reset")
	var consumables: Node = actor.get_node("ConsumableComponent")
	var animation: Node = consumables.get_node("ItemUseAnimation")
	var survival: Node = actor.get_node("SurvivalComponent")
	actor.inventory.add_water(0.5)
	actor.inventory.add_water(0.5)
	assert(overlay.rewards.count("Water  +1.00 L") == 1)
	for action in ["roti","water","bandage"]:
		survival.satiety = 30.0
		survival.hydration = 30.0
		actor.health = 50.0
		var method: String = {"roti":"eat_roti","water":"drink_from_water_bag","bandage":"use_bandage"}[action]
		assert(consumables.call(method))
		assert(animation.kind == action and actor.get_meta("item_use") == action)
		assert(not consumables.call(method), "Repeated use overlapped")
		var rig: Skeleton3D = actor.get_node("VisualRoot/CharacterVisual").skeleton
		var first: Vector3 = rig.get_bone_global_pose(rig.find_bone("hand_r")).origin
		for frame in 50: await process_frame
		# Advance deterministically to the manipulation phase, then render actual posed bones.
		animation.elapsed = 0.9
		animation._process(0.05)
		var next: Vector3 = rig.get_bone_global_pose(rig.find_bone("hand_r")).origin
		assert(first.distance_to(next) > 0.01 and animation.prop.visible)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://docs/world/captures/use_%s.png" % action) == OK)
		animation._process(3.0)
		assert(animation.kind == "" and not animation.prop.visible and actor.get_meta("item_use") == "")
	print("ITEM USE MOTION: PASS | roti, drinking, bandage props + hand movement; duplicate-use guards and cleanup")
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,0.2,20)
	collider.shape = box
	collider.position.y = -0.1
	floor_body.add_child(collider)
	actor.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in 6: await physics_frame
	for entry in [["enfield",1,"RifleCombat","paper_cartridges"],["pistol",3,"PistolCombat","pistol_ball"],["double_gun",5,"DoubleGunCombat","shot_charge"]]:
		actor.inventory.add_item(entry[0],1)
		actor.inventory.add_item(entry[3],12)
		visual.equipment.select_weapon(entry[1])
		visual.equipment.stowed = false
		visual.equipment._refresh()
		var combat: Node = actor.get_node(entry[2])
		combat.rounds = 0
		combat.start_reload()
		assert(combat.reload_remaining > 0.0)
		assert(not consumables.use_bandage(), "Item use overlapped reload")
		var captured := false
		var frames := 0
		while combat.reload_remaining > 0.0 and frames < 1200:
			await process_frame
			frames += 1
			if not captured and visual.equipment.reload_progress > 0.35:
				assert(visual.equipment.reload_progress < 1.0)
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					assert(root.get_texture().get_image().save_png("res://docs/world/captures/use_reload_%s.png" % entry[0]) == OK)
				captured = true
		assert(captured and combat.reload_remaining == 0.0 and combat.rounds > 0)
	print("RELOAD USE: PASS | actual rifle/pistol/double-gun timers drive visual progress, complete, and block overlapping consumables")
	quit()
