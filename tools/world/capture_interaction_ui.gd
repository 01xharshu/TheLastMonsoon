extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("INTERACTION UI CAPTURE BLOCKED: native renderer required")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14,14)
	ground.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(.43,.37,.29)
	ground.material_override = earth
	stage.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = 1.7
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.58,.66,.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.8,.77,.7)
	environment.environment = env
	stage.add_child(environment)
	var actor: CharacterBody3D = load("res://tools/world/interaction_test_actor.gd").new()
	stage.add_child(actor)
	actor.position = Vector3(0,0,4.0)
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
	camera.position = Vector3(2.3,1.75,5.5)
	stage.add_child(camera)
	camera.look_at(Vector3(0,.55,0))
	camera.make_current()
	var chest: Interactable = load("res://interaction/treasure_chest.gd").new()
	stage.add_child(chest)
	for i in 10: await process_frame
	overlay.set_target(null)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/world/captures/interaction_chest_approach.png") == OK)
	actor.position = Vector3(0,0,2.0)
	for i in 5: await physics_frame
	await _shot(overlay,chest,.0,"interaction_chest_prompt")
	await _shot(overlay,chest,.55,"interaction_chest_hold")
	chest.interact(actor)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var reward_path := "res://docs/world/captures/interaction_chest_rewards.png"
	assert(root.get_texture().get_image().save_png(reward_path) == OK)
	print("INTERACTION CAPTURE ",reward_path)
	quit()

func _shot(overlay: Control, chest: Interactable, fraction: float, name: String) -> void:
	overlay.set_target(chest,fraction)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/world/captures/"+name+".png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("INTERACTION CAPTURE ",path)
