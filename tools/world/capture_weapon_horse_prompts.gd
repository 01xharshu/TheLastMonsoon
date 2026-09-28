extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Metal renderer required")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var actor: CharacterBody3D = load("res://tools/world/interaction_test_actor.gd").new()
	stage.add_child(actor)
	actor.position = Vector3(0, 0, 2)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	actor.add_child(ui)
	var hud := Control.new()
	hud.name = "HUDRoot"
	ui.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay: Control = load("res://interaction/interaction_overlay.gd").new()
	overlay.name = "InteractionOverlay"
	hud.add_child(overlay)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.3, 1.75, 5.5)
	camera.look_at(Vector3(0, 0.55, 0))
	camera.make_current()
	var weapon: Interactable = load("res://world/suryagarh/settlements/weapon_pickup.gd").new()
	weapon.weapon_id = "enfield"
	stage.add_child(weapon)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.2, 0.7)
	collider.shape = box
	weapon.add_child(collider)
	for i in 8: await physics_frame
	overlay.set_target(weapon, 0.42)
	for i in 2: await physics_frame
	assert(overlay.marker_world_positions.has(weapon), "Weapon card has no visible anchor")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/tlm_weapon_equip_prompt.png") == OK)
	weapon.hide()
	overlay.set_target(null)
	overlay.set_ride_prompt("Dismount horse")
	for i in 8: await physics_frame
	assert(overlay.ride_prompt == "Dismount horse")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/tlm_horse_exit_prompt.png") == OK)
	print("WEAPON / HORSE PROMPT CAPTURE PASS")
	quit()
