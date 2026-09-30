extends SceneTree
## Internal motion diagnostic only: current Arjun appearance is owner-rejected.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.30,0.32,0.30)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.85,0.84,0.80)
	environment.environment = sky
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	world.add_child(light)
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(time)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 47.0
	camera.global_position = actor.global_position + Vector3(1.8,1.45,2.3)
	camera.look_at(actor.global_position + Vector3(0,1.05,0))
	camera.make_current()
	actor.inventory.add_item("enfield",1)
	actor.inventory.add_item("pistol",1)
	var combat: Node = actor.get_node("RifleCombat")
	combat.set_process(false)
	visual.equipment.selected = 1
	visual.equipment.stowed = false
	visual.equipment._refresh()
	visual.set_process(false)
	var maximum := 0.0
	var fps := 30.0
	var frame_count := int(combat.RELOAD_SECONDS*fps)
	for frame in frame_count+1:
		var progress := float(frame) / frame_count
		combat.reload_remaining = combat.RELOAD_SECONDS*(1-progress) if frame < frame_count else 0.001
		visual._process(1.0/fps)
		var rig: Skeleton3D = visual.skeleton
		var pinch := rig.to_global((rig.get_bone_global_pose(rig.find_bone("index_03_l")).origin+rig.get_bone_global_pose(rig.find_bone("thumb_03_l")).origin)*0.5)
		var loading: Dictionary = preload("res://player/enfield_loading_sequence.gd").state(visual.equipment.reload_progress)
		var error := pinch.distance_to(visual.equipment.enfield_hand.to_global(loading.contact))
		if error > maximum:
			maximum = error
			print("CONTACT MAX ",progress," ",error)
		if frame >= 0:
			var center := rig.to_global(Vector3(0.10,1.40,0.35))
			camera.global_position = center + Vector3(0.8,0.15,1.4)
			camera.look_at(center)
			camera.make_current()
			await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/tlm_loading_paced_%03d.png" % frame)
	print("MAX LOADING PINCH ERROR ",maximum)
	quit(0 if maximum < 0.015 else 1)
