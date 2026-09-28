extends Node3D
## Small Metal fixture for close side inspection of climb knees and the mantle.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node3D = self
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	scene.add_child(clock)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 2.0
	scene.add_child(light)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(.28, 5.5, 4.0)
	wall.mesh = wall_mesh
	wall.position = Vector3(.14, 2.75, 0)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(.44, .32, .25)
	wall.material_override = wall_material
	scene.add_child(wall)
	wall.visible = false
	var actor: CharacterBody3D = preload("res://player/player.tscn").instantiate()
	scene.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("ClimbComponent").set_physics_process(false)
	actor.get_node("UI").hide()
	actor.global_position = Vector3(-.26, 1.35, 0)
	actor.visual_root.global_rotation.y = -PI/2
	var climb: Node = actor.get_node("ClimbComponent")
	climb.active = true
	climb.has_holds = true
	climb.wall_normal = Vector3.LEFT
	climb.wall_point = Vector3.ZERO
	climb.hold_base_y = .55
	climb.landing = Vector3(.8, 5.5, 0)
	actor.set_meta("climbing", true)
	var camera := Camera3D.new()
	camera.fov = 42.0
	scene.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(-3.5, 2.4, 3.5)
	camera.look_at(Vector3(0, 2.3, 0))
	for beat in [{"name":"pull", "at":.35, "height":1.85}, {"name":"upper", "at":.68, "height":3.45}, {"name":"mantle", "at":.85, "height":4.65}]:
		climb.progress = beat.at
		actor.global_position.y = beat.height
		camera.global_position = Vector3(-2.7, beat.height + .3, 2.4)
		camera.look_at(Vector3(-.1, beat.height + .2, 0))
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/characters/arjun/climb_leg_" + beat.name + ".png"
		print("CLIMB LEG CAPTURE ", beat.name, " ", get_viewport().get_texture().get_image().save_png(path), " ", path)
		camera.global_position = Vector3(-1.4, beat.height + 1.1, 1.25)
		camera.look_at(Vector3(-.05, beat.height + 1.05, 0))
		for frame in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var hand_path: String = "res://docs/characters/arjun/climb_hand_" + beat.name + ".png"
		print("CLIMB HAND CAPTURE ", beat.name, " ", get_viewport().get_texture().get_image().save_png(hand_path), " ", hand_path)
	get_tree().quit()
