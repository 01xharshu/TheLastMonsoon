extends SceneTree
var errors: Array[String]=[]
var phases: Array[String]=[]
var world: Node3D
var actor: CharacterBody3D
var police: Node3D
var coordinator: Node
var camera: Camera3D
var captures := false
var max_contact := 0.0
var max_step := 0.0
var last_position := Vector3.ZERO
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: errors.append(message)
func snap(label: String) -> void:
	if not captures:return
	camera.global_position=actor.global_position+police.global_basis*Vector3(-2.2,1.1,2.4)
	camera.look_at(actor.global_position)
	for i in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/characters/arjun/arrest_sequence_%s.png"%label)
	if label in ["restraint","escort"]:
		camera.global_position=actor.global_position+police.global_basis*Vector3(2.0,.8,-2.5)
		camera.look_at(actor.global_position)
		for i in 2: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/characters/arjun/arrest_sequence_%s_back.png"%label+"")
func run() -> void:
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	actor=world.get_node("Player")
	police=world.get_node("Settlement/DistrictPolice")
	coordinator=police.get_node_or_null("ThanaStaff/ArrestCoordinator")
	if coordinator==null: print("POLICE ARREST FAIL missing coordinator");quit(1);return
	captures=DisplayServer.get_name()!="headless"
	if captures:
		root.size=Vector2i(1280,720)
		root.content_scale_size=root.size
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		actor.get_node("UI").hide()
		world.get_node("LandscapeUI").hide()
		camera=Camera3D.new()
		camera.fov=62
		world.add_child(camera)
		camera.make_current()
	actor.global_position=police.to_global(Vector3(9.5,.9,9))
	actor.global_basis=police.global_basis
	actor.get_node("VisualRoot").rotation.y=0
	for i in 12:await physics_frame
	coordinator.custody_seconds=3.0
	coordinator.phase_changed.connect(func(value: String): phases.append(value); print("ARREST PHASE ",value))
	check(not coordinator.report_crime(actor,"unknown",actor.global_position),"Unknown offence accepted")
	# A real damage receiver forwards the witnessed offence, rather than a test-only arrest call.
	police.get_node("ThanaStaff/Daroga").take_damage(1.0)
	await process_frame
	check(coordinator.phase=="approach","Witnessed assault failed to trigger")
	if coordinator.phase!="approach":print("POLICE ARREST FAIL ",errors);quit(1);return
	last_position=actor.global_position
	var captured: Array[String]=[]
	for tick in 5400:
		await physics_frame
		var step: float=actor.global_position.distance_to(last_position)
		if step>.15: print("ARREST POSITION JUMP ",coordinator.phase," ",last_position," -> ",actor.global_position)
		max_step=maxf(max_step,step)
		last_position=actor.global_position
		if coordinator.phase=="restraint" and coordinator.phase_age>1.7:
			max_contact=maxf(max_contact,coordinator.officer.hand_contact_error)
			if tick%30==0: print("ARREST CONTACT ",coordinator.officer.hand_contact_error," officer ",police.to_local(coordinator.officer.global_position)," player ",police.to_local(actor.global_position))
		if coordinator.phase=="custody" and coordinator.phase_age>1.5:
			check(police.get_node("GroundCell0Gate").locked,"Cell gate failed to lock")
		if coordinator.phase in ["restraint","escort","custody","stand","leave_cell"] and coordinator.phase_age>(.6 if coordinator.phase=="stand" else 1.7) and coordinator.phase not in captured:
			captured.append(coordinator.phase)
			await snap(coordinator.phase)
		if coordinator.phase=="idle" and "custody" in phases:break
		if coordinator.phase=="idle" and tick>20:break
	check("escort" in phases and "custody" in phases and "stand" in phases and "leave_cell" in phases,"Sequence incomplete")
	check(coordinator.phase=="idle","Arrest did not finish")
	check(actor.get_meta("detention_action","")=="","Release left player locked")
	check(not police.get_node("GroundCell0Gate").locked,"Release left cell locked")
	check(max_contact<.055,"Officer restraint palm misses wrist")
	check(max_step<.16,"Escort teleported instead of walking")
	check(not coordinator.route_blocked,"Escort formation intersected solids")
	var report: Dictionary={"passed":errors.is_empty(),"errors":errors,"phases":phases,"escort_distance_m":coordinator.escort_distance,"max_player_step_m":max_step,"officer_palm_error_m":max_contact,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open("res://docs/characters/arjun/arrest_sequence_validation%s.json"%("_metal" if captures else ""),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("POLICE ARREST ","PASS" if errors.is_empty() else "FAIL"," ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
