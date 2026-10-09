extends SceneTree
## Native review of the actual playable rig, collider and stance transitions.
var output_dir := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir = arg.trim_prefix("--output-dir=")
	if not output_dir.is_empty() and not (output_dir.begins_with(OS.get_temp_dir()) or output_dir.begins_with("/tmp/")):
		push_error("Stance review output must use an OS temporary directory")
		quit(1)
		return
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
	actor.get_node("UI").hide()
	actor.set_process_unhandled_input(false)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	for i in 30: await physics_frame
	var stance = actor.get_node("StealthStance")
	if not output_dir.is_empty(): DirAccess.make_dir_recursive_absolute(output_dir)
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
		camera.make_current()
		RenderingServer.force_draw(false)
		if not output_dir.is_empty(): root.get_texture().get_image().save_png(output_dir+"/"+mode+".png")
		print("GROUND STANCE ",mode," actual=",stance.stance," origin=",actor.global_position," speed=",Vector2(actor.velocity.x,actor.velocity.z).length())
		if mode == "recover_run" and (stance.is_low() or Vector2(actor.velocity.x,actor.velocity.z).length()<5):
			push_error("Crawl-to-run integration failed")
			quit(1)
			return
	Input.action_release("move_forward")
	Input.action_release("sprint")
	for i in 20: await physics_frame
	actor.inventory.add_item("enfield",1)
	actor.get_node("VisualRoot/CharacterVisual").equipment.select_weapon(1)
	var crate := StaticBody3D.new()
	stage.add_child(crate)
	crate.position = Vector3(actor.position.x,0,actor.position.z-1.2)
	var crate_shape := CollisionShape3D.new()
	var crate_box := BoxShape3D.new()
	crate_box.size = Vector3(1.5,1.1,.9)
	crate_shape.shape = crate_box
	crate_shape.position.y = .55
	crate.add_child(crate_shape)
	var crate_mesh := MeshInstance3D.new()
	var crate_visual := BoxMesh.new()
	crate_visual.size = crate_box.size
	crate_mesh.mesh = crate_visual
	crate_mesh.position.y = .55
	crate.add_child(crate_mesh)
	actor.get_node("CameraPivot").global_rotation = Vector3.ZERO
	for i in 4: await physics_frame
	if not stance.try_cover():
		push_error("Armed cover fixture did not acquire crate")
		quit(1)
		return
	Input.action_press("aim")
	for i in 40: await physics_frame
	camera.global_position = actor.global_position+Vector3(2.4,.65,1.4)
	camera.look_at(actor.global_position-Vector3.UP*.15)
	await RenderingServer.frame_post_draw
	camera.make_current()
	RenderingServer.force_draw(false)
	if not output_dir.is_empty(): root.get_texture().get_image().save_png(output_dir+"/armed_cover.png")
	print("ARMED COVER GRIP ",actor.get_node("VisualRoot/CharacterVisual").equipment.grip_errors())
	actor.get_node("RifleCombat").fire()
	Input.action_release("aim")
	if not stance.stand():
		push_error("Cover recovery was blocked on the review floor")
		quit(1)
		return
	actor.global_position += Vector3.BACK*3.0
	for i in 20: await physics_frame
	stance.enter_prone()
	Input.action_press("aim")
	for i in 40: await physics_frame
	camera.global_position = actor.global_position+Vector3(2.4,.65,1.4)
	camera.look_at(actor.global_position-Vector3.UP*.15)
	await RenderingServer.frame_post_draw
	camera.make_current()
	RenderingServer.force_draw(false)
	if not output_dir.is_empty(): root.get_texture().get_image().save_png(output_dir+"/armed_prone.png")
	var prone_grip: Dictionary = actor.get_node("VisualRoot/CharacterVisual").equipment.grip_errors()
	print("ARMED PRONE GRIP ",prone_grip)
	for side in ["l","r"]:
		var rig: Skeleton3D = actor.get_node("VisualRoot/CharacterVisual").skeleton
		print("PRONE FOOT ",side," ",rig.to_global(rig.get_bone_global_pose(rig.find_bone("foot_"+side)).origin))
	if stance.stance != "prone" or prone_grip.right_palm_m > .025 or prone_grip.left_palm_m > .025:
		push_error("Armed prone pose/contact failed")
		quit(1)
		return
	Input.action_release("aim")
	stage.queue_free()
	for i in 4: await process_frame
	quit()
