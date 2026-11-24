extends SceneTree
## Native actual-player sidearm poses. Images must be written to OS temp storage.
var output := OS.get_environment("TLM_INDIAN_PISTOL_REVIEW")
var actor: CharacterBody3D
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func frame(label: String, offset: Vector3) -> void:
	camera.make_current()
	camera.global_position = actor.global_position + offset
	camera.look_at(actor.global_position + Vector3(0,.05,0))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("Unable to save temporary sidearm view")
	print("INDIAN PISTOL REVIEW FRAME ",path)

func close_frame(label: String, held: Node3D, offset: Vector3) -> void:
	camera.make_current()
	camera.fov = 35
	camera.global_position = held.global_position + offset
	camera.look_at(held.to_global(Vector3(.015,0,0)))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	if root.get_texture().get_image().save_png(path) != OK: push_error("Unable to save temporary close view")
	print("INDIAN PISTOL REVIEW FRAME ",path)
	camera.fov = 43

func _run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty() or not (output.begins_with(OS.get_temp_dir()) or output.begins_with("/tmp/")):
		push_error("Native sidearm review requires a temporary output directory")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.24,.27,.26)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.8,.8,.8)
	settings.ambient_light_energy = .8
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-35,0)
	stage.add_child(sun)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40,.4,40)
	var floor_collision := CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_collision.position.y = -.2
	floor.add_child(floor_collision)
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = Vector2(40,40)
	stage.add_child(mesh)
	var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	stage.add_child(clock)
	actor = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position = Vector3(0,1,0)
	actor.get_node("UI").hide()
	for i in 35: await physics_frame
	var gear: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	var gun: Node = actor.get_node("IndianPistolCombat")
	actor.inventory.add_item("indian_pistol",1)
	actor.inventory.add_item("pistol_ball",2)
	gear.select_weapon(6)
	camera = Camera3D.new()
	camera.fov = 43
	stage.add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("aim")
	for i in 45: await physics_frame
	if not gun.aiming:
		push_error("New pistol did not enter aim")
		await root.get_node("SaveManager").quit_game(1)
		return
	print("INDIAN AIM DIRECTION ",JSON.stringify({"weapon_axis":gear.indian_pistol_hand.global_basis.x.normalized(),"weapon_aim":gear.aim_direction.normalized(),"camera_forward":-gun.camera.global_basis.z.normalized(),"alignment":gear.indian_pistol_hand.global_basis.x.normalized().dot(gear.aim_direction.normalized())}))
	await frame("aim_front",Vector3(1.9,.8,-2.3))
	await frame("aim_back",Vector3(-1.9,.8,2.3))
	await close_frame("aim_hand",gear.indian_pistol_hand,Vector3(.55,.2,-.9))
	var walking_start := actor.global_position
	Input.action_press("move_forward")
	for i in 35: await physics_frame
	Input.action_release("move_forward")
	if actor.global_position.distance_to(walking_start) < .1 or not gun.aiming:
		push_error("Moving pistol aim did not preserve motion and aim")
		await root.get_node("SaveManager").quit_game(1)
		return
	await frame("walk_aim",Vector3(1.9,.8,-2.3))
	if not gun.fire() or not gun.start_reload():
		push_error("New pistol could not fire and reload")
		await root.get_node("SaveManager").quit_game(1)
		return
	for i in 240:
		await process_frame
		if gear.pistol_charge.visible: break
	if gun.reload_remaining <= 0.0 or not gear.pistol_charge.visible:
		push_error("Reload review missed the charge insertion pose")
		await root.get_node("SaveManager").quit_game(1)
		return
	print("RELOAD CHARGE REMAINING ",gun.reload_remaining," progress ",gear.reload_progress)
	await close_frame("reload_hand",gear.indian_pistol_hand,Vector3(.55,.2,-.9))
	print("RELOAD AFTER FRAME ",gun.reload_remaining," charge ",gear.pistol_charge.visible)
	await frame("reload_muzzle",Vector3(1.9,.8,-2.3))
	await frame("reload_back",Vector3(-1.9,.8,2.3))
	for i in 150: await physics_frame
	var wall := StaticBody3D.new()
	stage.add_child(wall)
	wall.global_position = Vector3(actor.global_position.x,0,actor.global_position.z-1.1)
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(1.8,1.0,.4)
	var wall_collision := CollisionShape3D.new()
	wall_collision.shape = wall_shape
	wall_collision.position.y = .5
	wall.add_child(wall_collision)
	var wall_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = wall_shape.size
	wall_mesh.mesh = box
	wall_mesh.position = wall_collision.position
	wall.add_child(wall_mesh)
	actor.get_node("CameraPivot").global_rotation = Vector3.ZERO
	for i in 8: await physics_frame
	var stance: Node = actor.get_node("StealthStance")
	if not stance.try_cover():
		push_error("Native review could not acquire the wall")
		await root.get_node("SaveManager").quit_game(1)
		return
	for i in 45: await physics_frame
	await frame("cover_front",Vector3(2,.7,-2.5))
	await frame("cover_back",Vector3(-2,.7,2.5))
	Input.action_release("aim")
	print("INDIAN PISTOL NATIVE REVIEW: PASS | aim, reload and cover frames saved temporarily")
	await root.get_node("SaveManager").quit_game(0)
