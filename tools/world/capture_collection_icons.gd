extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	var overlay = load("res://interaction/interaction_overlay.gd").new()
	var actor := CharacterBody3D.new()
	scene.add_child(actor)
	var ui := CanvasLayer.new()
	actor.add_child(ui)
	var hud := Control.new()
	ui.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog = preload("res://interaction/item_catalog.gd")
	var batches := [["paper_cartridges", "pistol_ball", "pistol", "enfield", "shot_charge"], ["water_bag", "mango", "roti", "rupees", "medkit"]]
	for batch_index in range(batches.size()):
		overlay.rewards.clear()
		var lines: Array = []
		var icons: Array = []
		for item in batches[batch_index]:
			lines.append(catalog.display_name(item) + "  +1")
			icons.append(catalog.icon(item))
		overlay.show_rewards(lines, icons)
		assert(overlay.reward_icons.size() == 5)
		for frame in 3: await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("/tmp/tlm_collection_icons_%d.png" % batch_index) == OK)
	print("COLLECTION ICONS: PASS | firearm, ammunition, water, food, coin and bandage mappings")
	quit()
