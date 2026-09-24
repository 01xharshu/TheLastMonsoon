extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var actor: CharacterBody3D = load("res://tools/world/interaction_test_actor.gd").new()
	stage.add_child(actor)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	actor.add_child(ui)
	var hud := Control.new()
	hud.name = "HUDRoot"
	ui.add_child(hud)
	var overlay: Control = load("res://interaction/interaction_overlay.gd").new()
	overlay.name = "InteractionOverlay"
	hud.add_child(overlay)
	var camera := Camera3D.new()
	actor.add_child(camera)
	camera.position = Vector3(0,1.6,3)
	camera.make_current()
	var chest: Interactable = load("res://interaction/treasure_chest.gd").new()
	stage.add_child(chest)
	actor.global_position = Vector3(0,0,2)
	for i in 4: await physics_frame
	if not overlay.markers.has(chest):
		push_error("ISOLATED INTERACTION BLOCKED: marker missing")
		quit(1)
		return
	overlay.set_target(chest,.5)
	chest.interact(actor)
	if not chest.opened or actor.inventory.get_item_count("rupees") != 26 or overlay.rewards.size() != 3:
		push_error("ISOLATED INTERACTION BLOCKED: chest reward failed")
		quit(1)
		return
	chest.restore_opened()
	if chest.interaction_available() or chest.lid.rotation.x < 1.0:
		push_error("ISOLATED INTERACTION BLOCKED: restore failed")
		quit(1)
		return
	print("ISOLATED INTERACTION: PASS | marker, chest rewards, restored state")
	quit()
