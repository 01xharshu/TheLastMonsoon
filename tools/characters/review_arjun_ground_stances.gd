extends SceneTree
## Native review of the actual playable rig, collider and stance transitions.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.18,.20,.22)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = .8
	env.environment = settings
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	stage.add_child(sun)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,.4,60)
	collision.shape = box
	collision.position.y = -.2
	floor.add_child(collision)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60,60)
	mesh.mesh = plane
	floor.add_child(mesh)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position = Vector3(0,1,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	for i in 30: await physics_frame
	var stance = actor.get_node("StealthStance")
	DirAccess.make_dir_recursive_absolute("res://docs/characters/arjun/ground_stances_2026-10-05")
	for mode in ["stand","crouch","crawl","recover_run"]:
		if mode == "crouch": stance.enter_crouch()
		if mode == "crawl":
			stance.enter_prone()
			Input.action_press("move_forward")
		if mode == "recover_run": Input.action_press("sprint")
		for i in 40:
			await physics_frame
			camera.make_current()
			camera.global_position = actor.global_position+Vector3(2.4,.65,1.4)
			camera.look_at(actor.global_position-Vector3.UP*.15)
			camera.fov = 42
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/characters/arjun/ground_stances_2026-10-05/"+mode+".png")
		print("GROUND STANCE ",mode," actual=",stance.stance," origin=",actor.global_position," speed=",Vector2(actor.velocity.x,actor.velocity.z).length())
		if mode == "recover_run" and (stance.is_low() or Vector2(actor.velocity.x,actor.velocity.z).length()<5):
			push_error("Crawl-to-run integration failed")
			quit(1)
			return
	Input.action_release("move_forward")
	Input.action_release("sprint")
	quit()
