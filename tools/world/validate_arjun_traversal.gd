extends SceneTree

var failures := 0
var actor: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures += 1

func box(parent: Node3D, at: Vector3, size: Vector3, angle := 0.0) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = at
	body.rotation.x = angle
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	body.add_child(visual)

func walk(frames: int) -> void:
	Input.action_press("move_forward")
	for i in frames: await physics_frame
	Input.action_release("move_forward")
	for i in 5: await physics_frame

func run() -> void:
	var course := Node3D.new()
	root.add_child(course)
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	course.add_child(clock)
	box(course, Vector3(0,-0.1,0),Vector3(12,0.2,20))
	actor = preload("res://player/player.tscn").instantiate()
	course.add_child(actor)
	actor.global_position = Vector3(0,0.9,2)
	actor.visual_root.rotation.y = 0.0
	actor.camera_pivot.rotation.y = 0.0
	for i in 10: await physics_frame
	check(actor.is_on_floor(),"starts grounded")
	box(course,Vector3(0,0.16,-1),Vector3(3,0.32,2))
	await walk(65)
	check(actor.global_position.z < -0.45 and actor.global_position.y > 1.1,"walks onto 0.32 m step")
	box(course,Vector3(0,0.55,-3.5),Vector3(3,1.1,0.5))
	await walk(50)
	check(actor.global_position.z > -3.0,"high obstacle blocks walking")
	actor.visual_root.rotation.y = PI
	var climb := actor.get_node("ClimbComponent")
	check(climb.try_start(),"reachable untagged ledge starts climb")
	if climb.active:
		for i in 160: await physics_frame
		check(not climb.active and actor.global_position.y > 1.8,"reachable ledge climb lands above wall")
	actor.global_position = Vector3(-3,0.9,0)
	actor.camera_pivot.rotation.y = -PI/2
	box(course,Vector3(-1.1,0.17,0),Vector3(3,0.2,2),0.12)
	for i in 8: await physics_frame
	await walk(70)
	check(actor.global_position.x > -0.5,"walks up shallow raised road")
	for index in 3:
		var height := 0.24 * (index + 1)
		box(course, Vector3(3, height * 0.5, 0.8 - index * 1.2), Vector3(1.8, height, 1.2))
	actor.global_position = Vector3(3, 0.9, 2.0)
	actor.camera_pivot.rotation.y = 0.0
	for i in 8: await physics_frame
	await walk(95)
	check(actor.global_position.z < -1.0 and actor.global_position.y > 1.5,"keeps walking up three consecutive stairs")
	if DisplayServer.get_name() != "headless":
		var light := DirectionalLight3D.new()
		course.add_child(light)
		light.rotation_degrees = Vector3(-55, -30, 0)
		light.light_energy = 2.0
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color(0.55, 0.7, 0.8)
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color(0.8, 0.8, 0.8)
		settings.ambient_light_energy = 1.5
		environment.environment = settings
		course.add_child(environment)
		var camera := Camera3D.new()
		course.add_child(camera)
		camera.make_current()
		camera.global_position = Vector3(7, 3.4, 2.7)
		camera.look_at(Vector3(3, 1.1, -0.5))
		actor.get_node("UI").hide()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://docs/world/captures/23_arjun_stair_traversal.png") == OK,"stair traversal capture")
	print("ARJUN TRAVERSAL ","PASS" if failures==0 else "FAIL "+str(failures))
	quit(1 if failures else 0)
